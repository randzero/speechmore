import Foundation

enum Constants {
    // MARK: - API
    static let asrWebSocketURL = "wss://api.stepfun.com/v1/realtime/asr/stream"
    static let llmBaseURL = "https://api.stepfun.com/v1/chat/completions"
    static let llmModel = "step-2-16k"

    // MARK: - Audio
    static let sampleRate: Double = 16000
    static let channels: UInt32 = 1
    static let bitsPerSample: UInt32 = 16
    static let chunkDurationMs: Int = 100
    static let chunkSizeBytes: Int = Int(sampleRate) * Int(channels) * Int(bitsPerSample / 8) * chunkDurationMs / 1000  // 3200

    // MARK: - Key Codes
    static let fnKeyCode: UInt16 = 63
    static let rightOptionKeyCode: UInt16 = 61
    static let spaceKeyCode: UInt16 = 49
    static let leftShiftKeyCode: UInt16 = 56

    // MARK: - UserDefaults Keys
    static let apiKeyKey = "speechmore_api_key"
    static let targetLanguageKey = "speechmore_target_language"
    static let triggerKeyKey = "speechmore_trigger_key"

    // MARK: - UI (expanded panel)
    static let overlayWidth: CGFloat = 360
    static let overlayHeight: CGFloat = 200
    static let overlayCornerRadius: CGFloat = 12

    // MARK: - UI (compact pill)
    static let compactWidth: CGFloat = 280
    static let compactHeight: CGFloat = 36
    static let compactCornerRadius: CGFloat = 18

    // MARK: - Timing
    static let modeEvalDelayMs: Int = 200
}
