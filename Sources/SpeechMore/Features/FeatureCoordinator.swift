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
    private var transcriptReceived = false
    private var dismissTimer: DispatchWorkItem?
    private var timeoutTimer: DispatchWorkItem?

    func start(mode: FeatureMode) {
        guard Settings.shared.hasAPIKey else {
            AppState.shared.phase = .error("请先设置 API Key")
            AppState.shared.overlayStyle = .expanded
            return
        }

        // Cancel any pending timers from previous session
        dismissTimer?.cancel()
        timeoutTimer?.cancel()

        currentMode = mode
        accumulatedResult = ""
        accumulatedTranscript = ""
        hasReceivedFirstToken = false
        transcriptReceived = false
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
                self.transcriptReceived = true
                AppState.shared.finalTranscript = text
                appLog("[Coordinator] Final transcript: \(text.prefix(50))...")
                self.handleTranscriptComplete(transcript: text)
            }
        }

        asr.onError = { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                appLog("[Coordinator] ASR error: \(error)")
                // If we haven't received any transcript yet, this is likely
                // a quick press-and-release — handle gracefully
                if !self.transcriptReceived {
                    self.cleanup()
                    if self.accumulatedTranscript.isEmpty {
                        // No speech at all — just dismiss quietly
                        AppState.shared.overlayStyle = .hidden
                    } else {
                        // Had partial transcript — show it as result
                        self.showPartialAsResult()
                    }
                } else {
                    AppState.shared.phase = .error(error)
                    AppState.shared.overlayStyle = .expanded
                    self.dismissAfterDelay()
                }
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

        // If no transcript received and no partial text, it's a quick tap — cancel immediately
        if accumulatedTranscript.isEmpty && !transcriptReceived {
            appLog("[Coordinator] Quick release with no speech — cancelling")
            cleanup()
            AppState.shared.overlayStyle = .hidden
            return
        }

        // Only send commit if ASR is still alive
        if asrClient != nil {
            asrClient?.sendCommit()
        }

        let state = AppState.shared
        if !transcriptReceived {
            state.phase = .transcribing
        }

        // Timeout: if no final transcript arrives within 6s, use partial or dismiss
        let timeout = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !self.transcriptReceived else { return }
            appLog("[Coordinator] Timeout waiting for final transcript")
            self.cleanup()
            if self.accumulatedTranscript.isEmpty {
                AppState.shared.overlayStyle = .hidden
            } else {
                self.showPartialAsResult()
            }
        }
        self.timeoutTimer = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: timeout)
    }

    // MARK: - Processing

    private func handleTranscriptComplete(transcript: String) {
        timeoutTimer?.cancel()
        guard let mode = currentMode else { return }

        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            appLog("[Coordinator] Empty transcript — dismissing")
            cleanup()
            AppState.shared.overlayStyle = .hidden
            return
        }

        asrClient?.disconnect()
        asrClient = nil

        if mode == .voiceInput {
            appLog("[Coordinator] voiceInput: showing ASR result directly")
            let state = AppState.shared
            state.llmResult = text
            state.phase = .done
            state.overlayStyle = .expanded
            dismissAfterDelay(seconds: 10)
        } else {
            AppState.shared.phase = .processing
            startLLM(transcript: text)
        }
    }

    /// Use accumulated partial transcript as the final result
    private func showPartialAsResult() {
        let text = accumulatedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            AppState.shared.overlayStyle = .hidden
            return
        }
        appLog("[Coordinator] Using partial transcript as result")
        let state = AppState.shared

        if currentMode == .voiceInput {
            state.llmResult = text
            state.phase = .done
            state.overlayStyle = .expanded
            dismissAfterDelay(seconds: 10)
        } else {
            state.finalTranscript = text
            state.phase = .processing
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
        dismissAfterDelay(seconds: 10)
        llmClient = nil
    }

    private func cleanup() {
        timeoutTimer?.cancel()
        asrClient?.disconnect()
        asrClient = nil
        llmClient?.cancel()
        llmClient = nil
    }

    private func dismissAfterDelay(seconds: Double = 2.0) {
        dismissTimer?.cancel()
        let work = DispatchWorkItem {
            let phase = AppState.shared.phase
            if case .done = phase {
                AppState.shared.overlayStyle = .hidden
            }
            if case .error = phase {
                AppState.shared.overlayStyle = .hidden
            }
        }
        dismissTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
