import AppKit
import SwiftUI

enum ReminderIconColor: String, CaseIterable, Identifiable {
  static let defaultsKey = "reminderIconColor"

  case indigo
  case blue
  case teal
  case green
  case orange
  case rose

  var id: String { rawValue }

  var title: String {
    switch self {
    case .indigo: "인디고"
    case .blue: "블루"
    case .teal: "틸"
    case .green: "그린"
    case .orange: "오렌지"
    case .rose: "로즈"
    }
  }

  var color: Color {
    BarRememberPalette.reminderIcon(self)
  }

  static func resolve(_ rawValue: String) -> ReminderIconColor {
    ReminderIconColor(rawValue: rawValue) ?? .indigo
  }
}

enum BarRememberTheme: String, CaseIterable, Identifiable {
  static let defaultsKey = "barRememberTheme"

  case system
  case frost
  case midnight
  case paper

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: "시스템"
    case .frost: "프로스트"
    case .midnight: "미드나이트"
    case .paper: "페이퍼"
    }
  }

  var description: String {
    switch self {
    case .system: "기본 macOS material"
    case .frost: "맑은 블루 글래스"
    case .midnight: "어두운 네이비 글래스"
    case .paper: "따뜻하고 불투명한 표면"
    }
  }

  var swatch: Color {
    switch self {
    case .system: Color(nsColor: .controlAccentColor)
    case .frost: Color(nsColor: BarRememberPalette.color(0x7BC4FF))
    case .midnight: Color(nsColor: BarRememberPalette.color(0x344B9A))
    case .paper: Color(nsColor: BarRememberPalette.color(0xD69A56))
    }
  }

  static func resolve(_ rawValue: String) -> BarRememberTheme {
    BarRememberTheme(rawValue: rawValue) ?? .system
  }
}

enum BarRememberPalette {
  static var primaryText: Color { themedColor(primaryTextColors) }
  static var secondaryText: Color { themedColor(secondaryTextColors) }
  static var mutedText: Color { themedColor(mutedTextColors) }
  static var accent: Color { themedColor(accentColors) }
  static var positive: Color { themedColor(positiveColors) }

  static var popoverOverlay: Color {
    themedColor { theme in
      switch theme {
      case .system: (0x000000, 0x000000, 0, 0)
      case .frost: (0xE5F4FF, 0x15263F, 0.36, 0.28)
      case .midnight: (0x111B2B, 0x101522, 0.74, 0.78)
      case .paper: (0xFFF9F0, 0x28231D, 0.92, 0.88)
      }
    }
  }

  static var controlFill: Color {
    themedColor { theme in
      switch theme {
      case .system: (0x1F2937, 0xF3F5F8, 0.055, 0.09)
      case .frost: (0x6B9CC6, 0xD4E9FF, 0.15, 0.14)
      case .midnight: (0x7E9DDE, 0xC6D7FF, 0.16, 0.13)
      case .paper: (0x9B754C, 0xE7CBA8, 0.11, 0.12)
      }
    }
  }

  static let overdue = Color(nsColor: .systemRed)
  static let today = Color(nsColor: .systemOrange)

  private static func primaryTextColors(_ theme: BarRememberTheme) -> (UInt32, UInt32, CGFloat, CGFloat) {
    switch theme {
    case .system, .frost: (0x1F2937, 0xF3F5F8, 1, 1)
    case .midnight: (0xEAF0FF, 0xEAF0FF, 1, 1)
    case .paper: (0x2F2923, 0xF8F1E7, 1, 1)
    }
  }

  private static func secondaryTextColors(_ theme: BarRememberTheme) -> (UInt32, UInt32, CGFloat, CGFloat) {
    switch theme {
    case .system, .frost: (0x5B6778, 0xB8C1CF, 1, 1)
    case .midnight: (0xB5C2DE, 0xB5C2DE, 1, 1)
    case .paper: (0x6F6255, 0xDCCFC0, 1, 1)
    }
  }

  private static func mutedTextColors(_ theme: BarRememberTheme) -> (UInt32, UInt32, CGFloat, CGFloat) {
    switch theme {
    case .system, .frost: (0x667386, 0xA6B0BE, 1, 1)
    case .midnight: (0x96A4C0, 0x96A4C0, 1, 1)
    case .paper: (0x857769, 0xC8B9A8, 1, 1)
    }
  }

  private static func accentColors(_ theme: BarRememberTheme) -> (UInt32, UInt32, CGFloat, CGFloat) {
    switch theme {
    case .system: (0x5267E9, 0x91A0FF, 1, 1)
    case .frost: (0x1769B0, 0x8CCBFF, 1, 1)
    case .midnight: (0x95AEFF, 0xA9BDFF, 1, 1)
    case .paper: (0xA45C22, 0xF1B77D, 1, 1)
    }
  }

  private static func positiveColors(_ theme: BarRememberTheme) -> (UInt32, UInt32, CGFloat, CGFloat) {
    switch theme {
    case .midnight: (0x71DCA5, 0x71DCA5, 1, 1)
    default: (0x23875A, 0x58D597, 1, 1)
    }
  }

  static func reminderIcon(_ colorChoice: ReminderIconColor) -> Color {
    let colors: (light: UInt32, dark: UInt32) =
      switch colorChoice {
      case .indigo: (0x5267E9, 0x91A0FF)
      case .blue: (0x1268C4, 0x70B7FF)
      case .teal: (0x007A78, 0x55D4D0)
      case .green: (0x237A50, 0x62D89B)
      case .orange: (0xB75212, 0xFFAD6B)
      case .rose: (0xB83B62, 0xFF89AB)
      }

    return Color(
      nsColor: dynamic(
        light: color(colors.light),
        dark: color(colors.dark)
      )
    )
  }

  private static func themedColor(
    _ colors: (BarRememberTheme) -> (UInt32, UInt32, CGFloat, CGFloat)
  ) -> Color {
    let theme = BarRememberTheme.resolve(
      UserDefaults.standard.string(forKey: BarRememberTheme.defaultsKey) ?? BarRememberTheme.system.rawValue
    )
    let colors = colors(theme)
    return Color(nsColor: dynamic(
      light: color(colors.0, alpha: colors.2),
      dark: color(colors.1, alpha: colors.3)
    ))
  }

  private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
      let match = appearance.bestMatch(from: [.darkAqua, .aqua])
      return match == .darkAqua ? dark : light
    }
  }

  static func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: alpha
    )
  }
}
