import Foundation

final class ASRWebSocketClient: NSObject, URLSessionWebSocketDelegate {
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnected = false
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func connect() {
        guard let url = URL(string: Constants.asrWebSocketURL) else {
            onError?("Invalid ASR WebSocket URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(Settings.shared.apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.urlSession = session

        let task = session.webSocketTask(with: request)
        self.webSocket = task
        task.resume()

        appLog("[ASR] Connecting to \(Constants.asrWebSocketURL)")
    }

    func sendSessionUpdate() {
        let msg = ASRSessionUpdate.defaultUpdate()
        sendJSON(msg)
        appLog("[ASR] Sent session.update")
    }

    func sendAudio(_ pcmData: Data) {
        let base64 = pcmData.base64EncodedString()
        let msg = ASRAudioAppend(
            event_id: "evt_\(UUID().uuidString.prefix(8))",
            audio: base64
        )
        sendJSON(msg)
    }

    func sendCommit() {
        let msg = ASRBufferCommit.create()
        sendJSON(msg)
        appLog("[ASR] Sent input_audio_buffer.commit")
    }

    func disconnect() {
        isConnected = false
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        appLog("[ASR] Disconnected")
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        appLog("[ASR] WebSocket connected")
        isConnected = true
        sendSessionUpdate()
        receiveMessage()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        appLog("[ASR] WebSocket closed: \(closeCode)")
        isConnected = false
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        let nsErr = error as NSError
        if nsErr.code == NSURLErrorCancelled || nsErr.code == 57 { return }
        appLog("[ASR] Connection error: \(error.localizedDescription)")
        isConnected = false
        onError?(error.localizedDescription)
    }

    // MARK: - Private

    private func sendJSON<T: Encodable>(_ message: T) {
        guard isConnected else {
            appLog("[ASR] Send skipped: not connected")
            return
        }
        guard let data = try? encoder.encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(text)) { error in
            if let error = error {
                let nsErr = error as NSError
                // Ignore cancellation errors
                if nsErr.code == NSURLErrorCancelled || nsErr.code == 57 { return }
                appLog("[ASR] Send error: \(error)")
            }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleServerMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleServerMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage()

            case .failure(let error):
                let nsErr = error as NSError
                // Ignore cancellation / socket-not-connected during teardown
                if nsErr.code == NSURLErrorCancelled || nsErr.code == 57 { return }
                appLog("[ASR] Receive error: \(error)")
                self.onError?(error.localizedDescription)
            }
        }
    }

    private func handleServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        // Parse type first
        guard let envelope = try? decoder.decode(ASRServerEnvelope.self, from: data) else {
            appLog("[ASR] Failed to decode message: \(text.prefix(200))")
            return
        }

        switch envelope.type {
        case "session.created":
            appLog("[ASR] Session created")

        case "session.updated":
            appLog("[ASR] Session updated")

        case "input_audio_buffer.speech_started":
            appLog("[ASR] Speech started")

        case "input_audio_buffer.speech_stopped":
            appLog("[ASR] Speech stopped")

        case "input_audio_buffer.committed":
            appLog("[ASR] Buffer committed")

        case "conversation.item.created":
            appLog("[ASR] Conversation item created")

        case "conversation.item.input_audio_transcription.delta":
            if let delta = try? decoder.decode(ASRTranscriptionDelta.self, from: data),
               let partialText = delta.text {
                onPartialTranscript?(partialText)
            }

        case "conversation.item.input_audio_transcription.completed":
            if let completed = try? decoder.decode(ASRTranscriptionCompleted.self, from: data),
               let transcript = completed.transcript {
                appLog("[ASR] Final transcript: \(transcript)")
                onFinalTranscript?(transcript)
            }

        case "error":
            if let errMsg = try? decoder.decode(ASRError.self, from: data) {
                let message = errMsg.error?.message ?? "Unknown ASR error"
                appLog("[ASR] Error: \(message)")
                onError?(message)
            }

        default:
            appLog("[ASR] Unknown message type: \(envelope.type)")
        }
    }
}
