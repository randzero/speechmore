import Foundation

final class LLMClient {
    var onToken: ((String) -> Void)?
    var onComplete: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var task: URLSessionDataTask?
    private var session: URLSession?
    private var buffer = ""
    private var accumulated = ""
    private var completed = false

    func streamChat(systemPrompt: String, userMessage: String) {
        guard !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            onError?("Empty transcript")
            return
        }

        guard let url = URL(string: Constants.llmBaseURL) else {
            onError?("Invalid LLM URL")
            return
        }

        let body: [String: Any] = [
            "model": Constants.llmModel,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Settings.shared.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        buffer = ""
        accumulated = ""
        completed = false

        let delegate = StreamDelegate(
            onData: { [weak self] data in self?.handleData(data) },
            onComplete: { [weak self] in self?.handleStreamEnd() },
            onError: { [weak self] error in self?.onError?(error) }
        )

        let urlSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        self.session = urlSession
        let dataTask = urlSession.dataTask(with: request)
        self.task = dataTask
        dataTask.resume()

        print("[LLM] Stream started")
    }

    func cancel() {
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        print("[LLM] Stream cancelled")
    }

    private func handleData(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text

        // Process SSE lines
        while let lineEnd = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<lineEnd.lowerBound])
            buffer = String(buffer[lineEnd.upperBound...])

            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))

            if jsonStr.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                // Stream finished — trigger completion immediately
                finishStream()
                return
            }

            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            accumulated += content
            onToken?(content)
        }
    }

    private func finishStream() {
        guard !completed else { return }
        completed = true
        print("[LLM] Stream completed, result length: \(accumulated.count)")
        onComplete?(accumulated)
        // Clean up
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func handleStreamEnd() {
        // Connection closed — finish if not already done
        finishStream()
    }
}

// MARK: - URLSession Stream Delegate

private final class StreamDelegate: NSObject, URLSessionDataDelegate {
    let onData: (Data) -> Void
    let onComplete: () -> Void
    let onError: (String) -> Void

    init(onData: @escaping (Data) -> Void, onComplete: @escaping () -> Void, onError: @escaping (String) -> Void) {
        self.onData = onData
        self.onComplete = onComplete
        self.onError = onError
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        onData(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled { return }
            onError(error.localizedDescription)
        } else {
            onComplete()
        }
    }
}
