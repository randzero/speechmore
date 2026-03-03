import Foundation
import Combine
import AppKit

/// Supported trigger keys for starting voice sessions
enum TriggerKey: String, CaseIterable, Identifiable {
    case fn = "fn"
    case rightOption = "rightOption"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fn: return "Fn"
        case .rightOption: return "右⌥ (Right Option)"
        }
    }

    var shortLabel: String {
        switch self {
        case .fn: return "Fn"
        case .rightOption: return "右⌥"
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .fn: return Constants.fnKeyCode
        case .rightOption: return Constants.rightOptionKeyCode
        }
    }

    var modifierFlag: UInt {
        switch self {
        case .fn: return NSEvent.ModifierFlags.function.rawValue
        case .rightOption: return NSEvent.ModifierFlags.option.rawValue
        }
    }

    var hint: String? {
        switch self {
        case .fn: return "需在 系统设置 → 键盘 中将 \"按下 fn 键\" 设为 \"不执行任何操作\""
        case .rightOption: return nil
        }
    }
}

final class Settings: ObservableObject {
    static let shared = Settings()

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Constants.apiKeyKey) }
    }

    @Published var targetLanguage: String {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: Constants.targetLanguageKey) }
    }

    @Published var triggerKey: TriggerKey {
        didSet {
            UserDefaults.standard.set(triggerKey.rawValue, forKey: Constants.triggerKeyKey)
            NotificationCenter.default.post(name: .triggerKeyChanged, object: nil)
        }
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    static let supportedLanguages = [
        "English",
        "中文",
        "日本語",
        "한국어",
        "Français",
        "Deutsch",
        "Español",
        "Русский",
    ]

    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: Constants.apiKeyKey) ?? ""
        self.targetLanguage = UserDefaults.standard.string(forKey: Constants.targetLanguageKey) ?? "English"
        let keyRaw = UserDefaults.standard.string(forKey: Constants.triggerKeyKey) ?? TriggerKey.fn.rawValue
        self.triggerKey = TriggerKey(rawValue: keyRaw) ?? .fn
    }
}

extension Notification.Name {
    static let triggerKeyChanged = Notification.Name("triggerKeyChanged")
}
