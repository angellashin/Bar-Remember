import XCTest
@testable import BarRemember

final class LocalizationTests: XCTestCase {
  func testLanguageResolutionFallsBackToKorean() {
    XCTAssertEqual(AppLanguage.resolve("unknown"), .korean)
    XCTAssertEqual(AppLanguage.resolve(AppLanguage.english.rawValue), .english)
  }

  func testLanguageLocaleIdentifiersAreStable() {
    XCTAssertEqual(AppLanguage.korean.localeIdentifier, "ko_KR")
    XCTAssertEqual(AppLanguage.english.localeIdentifier, "en_US")
  }

  func testLocalizedMessagesFollowTheStoredLanguage() {
    let defaults = UserDefaults(suiteName: "LocalizationTests")!
    defer { defaults.removePersistentDomain(forName: "LocalizationTests") }

    defaults.set(AppLanguage.english.rawValue, forKey: AppLanguage.defaultsKey)
    XCTAssertEqual(
      AppLanguage.localized(korean: "한국어", english: "English", defaults: defaults),
      "English"
    )

    defaults.set(AppLanguage.korean.rawValue, forKey: AppLanguage.defaultsKey)
    XCTAssertEqual(
      AppLanguage.localized(korean: "한국어", english: "English", defaults: defaults),
      "한국어"
    )
  }
}
