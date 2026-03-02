import Foundation
import AppKit

@MainActor
final class FeatureCoordinator {
    private let audioRecorder = AudioRecorder()
    private var asrClient: ASRWebSocketClient?
    private var llmClient: LLMClient?
    private var currentMode: FeatureMode?
    private var accumulatedResult = ""
    private var accumulatedTranscript = ""
    private var hasReceivedFirstToken = false

    func start(mode: FeatureMode) {
        guard Settings.shared.hasAPIKey else {
            AppState.shared.phase = .error("请先设置 API Key")
            AppState.shared.overlayStyle = .expanded
            return
        }

        currentMode = mode
        accumulatedResult = ""
        accumulatedTranscript = ""
        hasReceivedFirstToken = false
        let state = AppState.shared
        state.reset()
        state.currentMode = mode
        state.phase = .recording
        state.overlayStyle = .compact

        appLog("[Coordinator] Start mode: \(mode.displayName)")

        // Setup ASR
        let asr = ASRWebSocketClient()
        self.asrClient = asr

        asr.onPartialTranscript = { [weak self] text in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.accumulatedTranscript += text
                AppState.shared.partialTranscript = self.accumulatedTranscript
            }
        }

        asr.onFinalTranscript = { [weak self] text in
            DispatchQueue.main.async {
                guard let self = self else { return }
                AppState.shared.finalTranscript = text
                appLog("[Coordinator] Final transcript: \(text.prefix(50))...")
                self.handleTranscriptComplete(transcript: text)
            }
        }

        asr.onError = { error in
            DispatchQueue.main.async {
                appLog("[Coordinator] ASR error: \(error)")
                AppState.shared.phase = .error(error)
                AppState.shared.overlayStyle = .expanded
            }
        }

        audioRecorder.onAudioChunk = { [weak asr] data in
            asr?.sendAudio(data)
        }

        asr.connect()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.audioRecorder.startRecording()
        }
    }

    /// Update mode mid-session (e.g. voiceInput → askAnything)
    func updateMode(_ mode: FeatureMode) {
        currentMode = mode
        AppState.shared.currentMode = mode
        appLog("[Coordinator] Mode upgraded to: \(mode.displayName)")
    }

    func stop() {
        audioRecorder.stopRecording()
        asrClient?.sendCommit()

        let state = AppState.shared
        if state.partialTranscript.isEmpty && state.finalTranscript.isEmpty {
            state.phase = .transcribing
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.asrClient?.disconnect()
            self?.asrClient = nil
        }
    }

    // MARK: - Processing

    private func handleTranscriptComplete(transcript: String) {
        guard let mode = currentMode else { return }

        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            AppState.shared.phase = .error("未检测到语音")
            AppState.shared.overlayStyle = .expanded
            dismissAfterDelay()
            return
        }

        asrClient?.disconnect()
        asrClient = nil

        if mode == .voiceInput {
            // voiceInput: ASR only, no LLM — show result directly
            appLog("[Coordinator] voiceInput: showing ASR result directly")
            let state = AppState.shared
            state.llmResult = text
            state.phase = .done
            state.overlayStyle = .expanded
            dismissAfterDelay(seconds: 10)
        } else {
            // askAnything / translate: send to LLM
            AppState.shared.phase = .processing
            startLLM(transcript: text)
        }
    }

    private func startLLM(transcript: String) {
        guard let mode = currentMode else { return }

        let llm = LLMClient()
        self.llmClient = llm
        accumulatedResult = ""
        hasReceivedFirstToken = false

        llm.onToken = { [weak self] token in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.accumulatedResult += token
                AppState.shared.llmResult = self.accumulatedResult

                if !self.hasReceivedFirstToken {
                    self.hasReceivedFirstToken = true
                    AppState.shared.overlayStyle = .expanded
                }
            }
        }

        llm.onComplete = { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleLLMComplete()
            }
        }

        llm.onError = { error in
            DispatchQueue.main.async {
                appLog("[Coordinator] LLM error: \(error)")
                AppState.shared.phase = .error(error)
                AppState.shared.overlayStyle = .expanded
            }
        }

        appLog("[Coordinator] Starting LLM for mode: \(mode.displayName)")
        llm.streamChat(systemPrompt: mode.systemPrompt, userMessage: transcript)
    }

    private func handleLLMComplete() {
        let state = AppState.shared
        state.phase = .done
        appLog("[Coordinator] LLM complete")
        // Keep expanded, user can manually copy
        dismissAfterDelay(seconds: 10)
        llmClient = nil
    }

    private func dismissAfterDelay(seconds: Double = 2.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            if case .done = AppState.shared.phase {
                AppState.shared.overlayStyle = .hidden
            }
            if case .error = AppState.shared.phase {
                AppState.shared.overlayStyle = .hidden
            }
        }
    }
}
