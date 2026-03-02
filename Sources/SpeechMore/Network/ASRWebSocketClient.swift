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

        print("[ASR] Connecting to \(Constants.asrWebSocketURL)")
    }

    func sendSessionUpdate() {
        let msg = ASRSessionUpdate.defaultUpdate()
        sendJSON(msg)
        print("[ASR] Sent session.update")
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
        print("[ASR] Sent input_audio_buffer.commit")
    }

    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
        print("[ASR] Disconnected")
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[ASR] WebSocket connected")
        isConnected = true
        sendSessionUpdate()
        receiveMessage()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[ASR] WebSocket closed: \(closeCode)")
        isConnected = false
    }

    // MARK: - Private

    private func sendJSON<T: Encodable>(_ message: T) {
        guard let data = try? encoder.encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(text)) { error in
            if let error = error {
                print("[ASR] Send error: \(error)")
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
                print("[ASR] Receive error: \(error)")
                self.onError?(error.localizedDescription)
            }
        }
    }

    private func handleServerMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        // Parse type first
        guard let envelope = try? decoder.decode(ASRServerEnvelope.self, from: data) else {
            print("[ASR] Failed to decode message: \(text.prefix(200))")
            return
        }

        switch envelope.type {
        case "session.created":
            print("[ASR] Session created")

        case "session.updated":
            print("[ASR] Session updated")

        case "input_audio_buffer.speech_started":
            print("[ASR] Speech started")

        case "input_audio_buffer.speech_stopped":
            print("[ASR] Speech stopped")

        case "input_audio_buffer.committed":
            print("[ASR] Buffer committed")

        case "conversation.item.created":
            print("[ASR] Conversation item created")

        case "conversation.item.input_audio_transcription.delta":
            if let delta = try? decoder.decode(ASRTranscriptionDelta.self, from: data),
               let partialText = delta.text {
                onPartialTranscript?(partialText)
            }

        case "conversation.item.input_audio_transcription.completed":
            if let completed = try? decoder.decode(ASRTranscriptionCompleted.self, from: data),
               let transcript = completed.transcript {
                print("[ASR] Final transcript: \(transcript)")
                onFinalTranscript?(transcript)
            }

        case "error":
            if let errMsg = try? decoder.decode(ASRError.self, from: data) {
                let message = errMsg.error?.message ?? "Unknown ASR error"
                print("[ASR] Error: \(message)")
                onError?(message)
            }

        default:
            print("[ASR] Unknown message type: \(envelope.type)")
        }
    }
}
