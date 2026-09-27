import SwiftUI

@main
struct BarRememberApp: App {
  @StateObject private var reminderStore = ReminderStore()
  @StateObject private var loginItemController = LoginItemController()

  var body: some Scene {
    MenuBarExtra {
      MenuBarContentView()
        .environmentObject(reminderStore)
        .environmentObject(loginItemController)
    } label: {
      MenuBarLabelView(count: reminderStore.reminders.count)
    }
    .menuBarExtraStyle(.window)
  }
}

private struct MenuBarLabelView: View {
  let count: Int

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: count == 0 ? "checkmark.circle" : "checklist")
      if count > 0 {
        Text("\(count)")
          .monospacedDigit()
      }
    }
    .accessibilityLabel(count == 0 ? "남은 리마인더 없음" : "남은 리마인더 \(count)개")
  }
}
