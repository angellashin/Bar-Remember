import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
  static let defaultsKey = "appLanguage"

  case korean
  case english

  var id: String { rawValue }

  var localeIdentifier: String {
    switch self {
    case .korean: "ko_KR"
    case .english: "en_US"
    }
  }

  var locale: Locale {
    Locale(identifier: localeIdentifier)
  }

  var displayName: String {
    switch self {
    case .korean: "한국어"
    case .english: "English"
    }
  }

  static func resolve(_ rawValue: String) -> AppLanguage {
    AppLanguage(rawValue: rawValue) ?? .korean
  }

  static func localized(
    korean: String,
    english: String,
    defaults: UserDefaults = .standard
  ) -> String {
    let language = resolve(defaults.string(forKey: defaultsKey) ?? Self.korean.rawValue)
    return language == .english ? english : korean
  }
}
