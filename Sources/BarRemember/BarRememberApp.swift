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
  private var statusItemFrameObserver: NSObjectProtocol?
  private var statusWindowMoveObserver: NSObjectProtocol?
  private weak var observedStatusWindow: NSWindow?
  private var statusItemLength: CGFloat?
  private var isPopoverRepositionScheduled = false
  private var popoverRepositionAttempts = 0
  private var stableAnchorObservationCount = 0
  private var lastObservedStatusItemScreenRect: NSRect?
  private var lastPopoverAnchorScreenRect: NSRect?

  private let maximumPopoverRepositionAttempts = 3

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
    if let statusItemFrameObserver {
      NotificationCenter.default.removeObserver(statusItemFrameObserver)
    }
    statusItemFrameObserver = nil
    if let statusWindowMoveObserver {
      NotificationCenter.default.removeObserver(statusWindowMoveObserver)
    }
    statusWindowMoveObserver = nil
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
    installStatusItemPositionObservers(for: button)
    updateStatusItem(
      count: reminderStore.reminders.count,
      pinnedReminder: reminderStore.pinnedReminder,
      displayMode: reminderStore.pinnedReminderTitleDisplayMode
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
      reminderStore.$pinnedReminderTitleDisplayMode
    )
      .receive(on: RunLoop.main)
      .sink { [weak self] reminders, _, displayMode in
        self?.updateStatusItem(
          count: reminders.count,
          pinnedReminder: self?.reminderStore.pinnedReminder,
          displayMode: displayMode
        )
      }
  }

  private func updateStatusItem(
    count: Int,
    pinnedReminder: ReminderItemSnapshot?,
    displayMode: MenuBarPinnedTitleDisplayMode
  ) {
    guard let statusItem, let button = statusItem.button else { return }
    button.image = NSImage(
      systemSymbolName: pinnedReminder == nil ? (count == 0 ? "checkmark.circle" : "checklist") : "pin.fill",
      accessibilityDescription: "BarRemember"
    )
    let pinnedTitlePresentation = pinnedReminder.map {
      MenuBarPinnedTitlePresentationPolicy.presentation(
        for: $0.title,
        displayMode: displayMode,
        font: button.font ?? NSFont.menuBarFont(ofSize: 0),
        imageWidth: button.image?.size.width ?? 0,
        squareLength: NSStatusItem.squareLength
      )
    }
    button.title = pinnedTitlePresentation?.displayTitle ?? (count > 0 ? " \(count)" : "")
    let newStatusItemLength = pinnedTitlePresentation?.statusItemLength ?? NSStatusItem.squareLength
    let shouldRepositionPopover = MenuBarPopoverAnchorPolicy.shouldReposition(
      popoverIsShown: popover?.isShown == true,
      previousStatusItemLength: statusItemLength,
      newStatusItemLength: newStatusItemLength
    )
    statusItem.length = newStatusItemLength
    statusItemLength = newStatusItemLength
    installStatusWindowMoveObserver(for: button)
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
    beginPopoverRepositionObservation()
  }

  private func beginPopoverRepositionObservation() {
    guard let panel = popover, panel.isShown, let button = statusItem?.button else { return }
    installStatusWindowMoveObserver(for: button)
    popoverRepositionAttempts = 0
    stableAnchorObservationCount = 0
    lastObservedStatusItemScreenRect = statusItemScreenRect(for: button)
    schedulePopoverRepositionObservation()
  }

  private func schedulePopoverRepositionObservation() {
    guard !isPopoverRepositionScheduled else { return }
    isPopoverRepositionScheduled = true

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.isPopoverRepositionScheduled = false
      guard let panel = self.popover, panel.isShown, let button = self.statusItem?.button else { return }
      guard let currentScreenRect = self.statusItemScreenRect(for: button) else { return }

      self.popoverRepositionAttempts += 1
      if self.lastObservedStatusItemScreenRect == currentScreenRect {
        self.stableAnchorObservationCount += 1
      } else {
        self.lastObservedStatusItemScreenRect = currentScreenRect
        self.stableAnchorObservationCount = 0
      }

      // Require two consecutive deferred observations before updating the popover. The
      // status-bar host can move after its button has received the new width.
      let isStable = self.stableAnchorObservationCount >= 2
      if isStable && MenuBarPopoverAnchorPolicy.shouldReanchor(
          lastAnchoredScreenRect: self.lastPopoverAnchorScreenRect,
          currentScreenRect: currentScreenRect
      )
      {
        self.reanchorPopover(panel, relativeTo: button, screenRect: currentScreenRect)
        return
      }

      if self.popoverRepositionAttempts < self.maximumPopoverRepositionAttempts {
        self.schedulePopoverRepositionObservation()
      }
    }
  }

  private func showPopover(_ panel: NSPopover, relativeTo button: NSStatusBarButton) {
    panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    lastPopoverAnchorScreenRect = statusItemScreenRect(for: button)
  }

  private func reanchorPopover(
    _ panel: NSPopover,
    relativeTo button: NSStatusBarButton,
    screenRect: NSRect
  ) {
    let previousFirstResponder = panel.contentViewController?.view.window?.firstResponder
    // Re-showing an already-visible popover updates its positioning rect without closing the
    // SwiftUI hierarchy. This preserves the Quick Add and editor drafts.
    showPopover(panel, relativeTo: button)
    configurePopoverWindow(panel)
    if let window = panel.contentViewController?.view.window {
      window.makeKey()
      if let previousFirstResponder {
        window.makeFirstResponder(previousFirstResponder)
      }
    }
    lastPopoverAnchorScreenRect = screenRect
  }

  private func installStatusItemPositionObservers(for button: NSStatusBarButton) {
    button.postsFrameChangedNotifications = true
    statusItemFrameObserver = NotificationCenter.default.addObserver(
      forName: NSView.frameDidChangeNotification,
      object: button,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.beginPopoverRepositionObservation()
      }
    }
    installStatusWindowMoveObserver(for: button)
  }

  private func installStatusWindowMoveObserver(for button: NSStatusBarButton) {
    guard let window = button.window, observedStatusWindow !== window else { return }
    if let statusWindowMoveObserver {
      NotificationCenter.default.removeObserver(statusWindowMoveObserver)
    }
    observedStatusWindow = window
    statusWindowMoveObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didMoveNotification,
      object: window,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.beginPopoverRepositionObservation()
      }
    }
  }

  private func statusItemScreenRect(for button: NSStatusBarButton) -> NSRect? {
    guard let window = button.window, window.isVisible else { return nil }
    let rectInWindow = button.convert(button.bounds, to: nil)
    return window.convertToScreen(rectInWindow)
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

  static func shouldReanchor(
    lastAnchoredScreenRect: NSRect?,
    currentScreenRect: NSRect
  ) -> Bool {
    lastAnchoredScreenRect != currentScreenRect
  }
}

struct MenuBarPinnedTitlePresentation: Equatable {
  let displayTitle: String
  let statusItemLength: CGFloat
}

enum MenuBarPinnedTitlePresentationPolicy {
  static let shortTitleMaximumLength: CGFloat = 120
  static let longTitleMaximumLength: CGFloat = 160
  static let imageAndPaddingWidth: CGFloat = 28

  static func presentation(
    for title: String,
    displayMode: MenuBarPinnedTitleDisplayMode,
    font: NSFont,
    imageWidth: CGFloat,
    squareLength: CGFloat
  ) -> MenuBarPinnedTitlePresentation {
    guard displayMode != .iconOnly else {
      return MenuBarPinnedTitlePresentation(displayTitle: "", statusItemLength: squareLength)
    }

    let maximumLength = displayMode == .shortTitle
      ? shortTitleMaximumLength
      : longTitleMaximumLength
    let titleBudget = max(
      1,
      maximumLength
        - max(imageWidth, font.capHeight)
        - imageAndPaddingWidth
        - measuredWidth(of: " ", font: font)
    )
    let displayTitle = ellipsized(title, toFit: titleBudget, font: font)
    let requiredLength = max(
      squareLength,
      ceil(measuredWidth(of: " \(displayTitle)", font: font) + max(imageWidth, font.capHeight) + imageAndPaddingWidth)
    )
    return MenuBarPinnedTitlePresentation(
      displayTitle: " \(displayTitle)",
      statusItemLength: min(maximumLength, requiredLength)
    )
  }

  static func ellipsized(_ title: String, toFit maximumWidth: CGFloat, font: NSFont) -> String {
    guard measuredWidth(of: title, font: font) > maximumWidth else { return title }
    let ellipsis = "…"
    guard measuredWidth(of: ellipsis, font: font) <= maximumWidth else { return ellipsis }

    var prefix = ""
    for character in title {
      let candidate = prefix + String(character) + ellipsis
      guard measuredWidth(of: candidate, font: font) <= maximumWidth else { break }
      prefix += String(character)
    }
    return prefix + ellipsis
  }

  static func measuredWidth(of title: String, font: NSFont) -> CGFloat {
    (title as NSString).size(withAttributes: [.font: font]).width
  }
}
