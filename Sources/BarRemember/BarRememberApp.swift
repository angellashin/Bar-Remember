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
  private var statusItemLength: CGFloat?
  private var isPopoverRepositionScheduled = false

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
    updateStatusItem(
      count: reminderStore.reminders.count,
      pinnedReminder: reminderStore.pinnedReminder,
      hidesPinnedTitle: reminderStore.hidesPinnedReminderTitle
    )
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
    remindersSubscription = Publishers.CombineLatest3(
      reminderStore.$reminders,
      reminderStore.$pinnedReminderID,
      reminderStore.$hidesPinnedReminderTitle
    )
      .receive(on: RunLoop.main)
      .sink { [weak self] reminders, _, hidesPinnedTitle in
        self?.updateStatusItem(
          count: reminders.count,
          pinnedReminder: self?.reminderStore.pinnedReminder,
          hidesPinnedTitle: hidesPinnedTitle
        )
      }
  }

  private func updateStatusItem(
    count: Int,
    pinnedReminder: ReminderItemSnapshot?,
    hidesPinnedTitle: Bool
  ) {
    guard let statusItem, let button = statusItem.button else { return }
    let pinnedTitle = pinnedReminder.map { MenuBarPinnedReminderPolicy.displayTitle($0.title) }
    button.image = NSImage(
      systemSymbolName: pinnedReminder == nil ? (count == 0 ? "checkmark.circle" : "checklist") : "pin.fill",
      accessibilityDescription: "BarRemember"
    )
    button.title = pinnedTitle.map { hidesPinnedTitle ? "" : " \($0)" } ?? (count > 0 ? " \(count)" : "")
    let newStatusItemLength = pinnedTitle == nil || hidesPinnedTitle ? NSStatusItem.squareLength : 190
    let shouldRepositionPopover = MenuBarPopoverAnchorPolicy.shouldReposition(
      popoverIsShown: popover?.isShown == true,
      previousStatusItemLength: statusItemLength,
      newStatusItemLength: newStatusItemLength
    )
    statusItem.length = newStatusItemLength
    statusItemLength = newStatusItemLength
    button.setAccessibilityLabel(
      pinnedReminder.map { $0.title }
        ?? (count == 0
        ? AppLanguage.localized(korean: "남은 리마인더 없음", english: "No remaining reminders")
        : AppLanguage.localized(
          korean: "남은 리마인더 \(count)개",
          english: "\(count) remaining reminders"
        ))
    )

    if shouldRepositionPopover {
      schedulePopoverReposition()
    }
  }

  @objc private func togglePopover(_ sender: Any?) {
    guard let panel = popover, let button = statusItem?.button else { return }

    if panel.isShown {
      panel.performClose(sender)
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    showPopover(panel, relativeTo: button)
    configurePopoverWindow(panel)
    panel.contentViewController?.view.window?.becomeKey()
  }

  private func schedulePopoverReposition() {
    guard !isPopoverRepositionScheduled else { return }
    isPopoverRepositionScheduled = true

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.isPopoverRepositionScheduled = false
      guard let panel = self.popover, panel.isShown, let button = self.statusItem?.button else { return }

      // NSStatusBar lays out an item's new width on the next main-loop turn. Re-showing an
      // already visible popover updates its positioning rect without closing its content.
      button.superview?.layoutSubtreeIfNeeded()
      button.layoutSubtreeIfNeeded()
      self.showPopover(panel, relativeTo: button)
      self.configurePopoverWindow(panel)
      // Repositioning an already-visible NSPopover can resign its window. Restore
      // key-window status without closing it so the in-place title editor keeps
      // accepting keyboard input and preserves its draft/selection.
      panel.contentViewController?.view.window?.becomeKey()
    }
  }

  private func showPopover(_ panel: NSPopover, relativeTo button: NSStatusBarButton) {
    panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
  }

  private func configurePopoverWindow(_ panel: NSPopover) {
    guard let window = panel.contentViewController?.view.window else { return }
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    panel.contentViewController?.view.wantsLayer = true
    panel.contentViewController?.view.layer?.backgroundColor = NSColor.clear.cgColor
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

enum MenuBarPopoverAnchorPolicy {
  static func shouldReposition(
    popoverIsShown: Bool,
    previousStatusItemLength: CGFloat?,
    newStatusItemLength: CGFloat
  ) -> Bool {
    popoverIsShown && previousStatusItemLength != newStatusItemLength
  }
}
