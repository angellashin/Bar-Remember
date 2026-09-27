import AppKit
import Combine
import SwiftUI

@main
@MainActor
final class BarRememberAppDelegate: NSObject, NSApplicationDelegate {
  let reminderStore = ReminderStore()
  let loginItemController = LoginItemController()

  private var statusItem: NSStatusItem?
  private var popover: NSPopover?
  private var remindersSubscription: AnyCancellable?
  private var outsideClickMonitor: Any?

  static func main() {
    let application = NSApplication.shared
    let delegate = BarRememberAppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureStatusItem()
    configurePopover()
    observeReminderCount()
    installOutsideClickMonitor()
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let outsideClickMonitor {
      NSEvent.removeMonitor(outsideClickMonitor)
    }
    outsideClickMonitor = nil
    remindersSubscription?.cancel()
  }

  private func configureStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    guard let button = item.button else { return }

    button.target = self
    button.action = #selector(togglePopover(_:))
    button.imagePosition = .imageLeading
    button.image = NSImage(
      systemSymbolName: "checklist",
      accessibilityDescription: "BarRemember"
    )
    button.title = ""
    button.toolTip = "BarRemember"
    statusItem = item
    updateStatusItem(count: reminderStore.reminders.count)
  }

  private func configurePopover() {
    let panel = NSPopover()
    panel.behavior = .applicationDefined
    panel.animates = true
    panel.contentSize = NSSize(width: 380, height: 520)
    panel.contentViewController = NSHostingController(
      rootView: MenuBarContentView()
        .environmentObject(reminderStore)
        .environmentObject(loginItemController)
    )
    popover = panel
  }

  private func observeReminderCount() {
    remindersSubscription = reminderStore.$reminders
      .map(\.count)
      .removeDuplicates()
      .receive(on: RunLoop.main)
      .sink { [weak self] count in
        self?.updateStatusItem(count: count)
      }
  }

  private func updateStatusItem(count: Int) {
    guard let button = statusItem?.button else { return }
    button.image = NSImage(
      systemSymbolName: count == 0 ? "checkmark.circle" : "checklist",
      accessibilityDescription: "BarRemember"
    )
    button.title = count > 0 ? " \(count)" : ""
    button.setAccessibilityLabel(count == 0
      ? "남은 리마인더 없음"
      : "남은 리마인더 \(count)개")
  }

  @objc private func togglePopover(_ sender: Any?) {
    guard let panel = popover, let button = statusItem?.button else { return }

    if panel.isShown {
      panel.performClose(sender)
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    panel.contentViewController?.view.window?.becomeKey()
  }

  private func installOutsideClickMonitor() {
    outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] event in
      Task { @MainActor [weak self] in
        guard let self, let panel = self.popover, panel.isShown else { return }
        let popoverWindow = panel.contentViewController?.view.window
        let statusWindow = self.statusItem?.button?.window
        guard event.window !== popoverWindow, event.window !== statusWindow else { return }
        panel.performClose(nil)
      }
    }
  }
}
