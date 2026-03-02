import Foundation

enum FeatureMode: String, CaseIterable {
    case voiceInput    // Fn only
    case askAnything   // Fn + Space
    case translate     // Fn + Left Shift

    var displayName: String {
        switch self {
        case .voiceInput:  return "语音输入"
        case .askAnything: return "随便问"
        case .translate:   return "翻译"
        }
    }

    var systemPrompt: String {
        switch self {
        case .voiceInput:
            return """
            你是一个文本润色助手。用户会给你一段语音转写的文字，可能有错别字或口语化表达。
            请你修正错别字、调整标点，使文字更通顺自然，但保持原意不变。
            只输出润色后的文字，不要解释。
            """
        case .askAnything:
            return """
            你是一个智能助手。用户会用语音向你提问，请简洁、准确地回答。
            回答要简明扼要，适合快速阅读。
            """
        case .translate:
            return """
            你是一个翻译助手。用户会给你一段文字，请将其翻译成\(Settings.shared.targetLanguage)。
            只输出翻译结果，不要解释。
            """
        }
    }

    /// Whether the result should be injected into the active app
    var shouldInjectText: Bool {
        switch self {
        case .voiceInput, .translate: return true
        case .askAnything: return false
        }
    }
}
