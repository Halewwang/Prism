import Foundation
import PrismCore

extension AppLanguage {
    var interfaceLocalizationCode: String? {
        switch self {
        case .system:
            nil
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }

    func applySystemLanguagePreference() {
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        #endif
        if let code = interfaceLocalizationCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}
