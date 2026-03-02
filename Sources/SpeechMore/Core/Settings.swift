import Foundation
import Combine

final class Settings: ObservableObject {
    static let shared = Settings()

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Constants.apiKeyKey) }
    }

    @Published var targetLanguage: String {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: Constants.targetLanguageKey) }
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
    }
}
