import AppKit
import Combine
@preconcurrency import EventKit
import Foundation

@MainActor
final class ReminderStore: ObservableObject {
  @Published private(set) var authorizationState: ReminderAuthorizationState = .unknown
  @Published private(set) var lists: [ReminderListInfo] = []
  @Published private(set) var reminders: [ReminderItemSnapshot] = []
  @Published private(set) var sections: [ReminderSection]
  @Published private(set) var listSectionAssignments: [String: String]
  @Published private(set) var completingIDs: Set<String> = []
  @Published private(set) var updatingReminderIDs: Set<String> = []
  @Published private(set) var undoableCompletion: UndoableCompletion?
  @Published private(set) var isUndoingCompletion = false
  @Published private(set) var isLoading = false
  @Published private var activeAddListIDs: [String: String] = [:]
  @Published var errorMessage: String?

  private let eventStore: EKEventStore
  private let defaults: UserDefaults
  private static let configurationKey = "reminderSectionConfigurationV2"
  private static let legacySelectedListIDsKey = "selectedReminderListIDs"
  private static let legacyJobListIDsKey = "jobReminderListIDs"
  private let hasConfiguredSelectionKey = "hasConfiguredReminderListSelection"
  private let reminderOrderIDsKey = "manualReminderOrderIDs"
  private var eventStoreObserver: NSObjectProtocol?
  private var undoDismissTask: Task<Void, Never>?
  private var manualReminderOrderIDs: [ReminderItemSnapshot.ID]
  private var reloadGeneration = 0

  init(eventStore: EKEventStore = EKEventStore(), defaults: UserDefaults = .standard) {
    let configuration = Self.loadSectionConfiguration(from: defaults)
    self.eventStore = eventStore
    self.defaults = defaults
    self.sections = configuration.sections
    self.listSectionAssignments = configuration.listSectionAssignments
    self.manualReminderOrderIDs = defaults.stringArray(forKey: reminderOrderIDsKey) ?? []

    persistSectionConfiguration()
    updateAuthorizationState()
    eventStoreObserver = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged,
      object: eventStore,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        await self?.reload()
      }
    }

    Task {
      await reload()
    }
  }

  isolated deinit {
    undoDismissTask?.cancel()
    if let eventStoreObserver {
      NotificationCenter.default.removeObserver(eventStoreObserver)
    }
  }

  var configuredListIDs: Set<String> {
    Set(listSectionAssignments.keys)
  }

  func selectedListIDs(for section: ReminderSection) -> Set<String> {
    Set(
      listSectionAssignments.compactMap { listID, sectionID in
        sectionID == section.id ? listID : nil
      }
    )
  }

  func selectedLists(for section: ReminderSection) -> [ReminderListInfo] {
    let selectedIDs = selectedListIDs(for: section)
    return lists.filter { selectedIDs.contains($0.id) }
  }

  func reminders(for section: ReminderSection) -> [ReminderItemSnapshot] {
    let selectedIDs = selectedListIDs(for: section)
    return reminders.filter { selectedIDs.contains($0.listID) }
  }

  func activeAddList(for section: ReminderSection) -> ReminderListInfo? {
    let selectedLists = selectedLists(for: section)
    let activeID = activeAddListIDs[section.id]
    guard let activeID else { return selectedLists.first }
    return selectedLists.first { $0.id == activeID }
  }

  func section(withID sectionID: String) -> ReminderSection? {
    sections.first { $0.id == sectionID }
  }

  func requestAccess() async {
    authorizationState = .requesting
    errorMessage = nil

    do {
      let granted = try await eventStore.requestFullAccessToReminders()
      authorizationState = granted ? .granted : .denied
      if granted {
        await reload()
      }
    } catch {
      authorizationState = .failed(error.localizedDescription)
      errorMessage = "리마인더 접근 권한을 요청하지 못했습니다."
    }
  }

  func reload() async {
    reloadGeneration &+= 1
    let generation = reloadGeneration
    updateAuthorizationState()
    guard authorizationState == .granted else {
      lists = []
      reminders = []
      return
    }

    isLoading = true
    defer {
      if generation == reloadGeneration {
        isLoading = false
      }
    }

    let eventCalendars = eventStore.calendars(for: .reminder)
      .filter(\.allowsContentModifications)
      .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

    let snapshots = eventCalendars.map {
      ReminderListInfo(
        id: $0.calendarIdentifier,
        title: $0.title,
        tint: Self.tint(from: $0.cgColor),
        canModify: $0.allowsContentModifications
      )
    }
    lists = snapshots

    let availableIDs = Set(snapshots.map(\.id))
    let defaultID = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
    let hasConfiguredSelection = defaults.bool(forKey: hasConfiguredSelectionKey)
    let taskListIDs = selectedListIDs(for: .tasks)
    let reconciledTaskListIDs = ListSelectionPolicy.reconciledSelection(
      savedIDs: taskListIDs,
      availableIDs: availableIDs,
      defaultID: defaultID,
      hasConfiguredSelection: hasConfiguredSelection
    )

    let validSectionIDs = Set(sections.map(\.id))
    var reconciledAssignments = listSectionAssignments.filter {
      availableIDs.contains($0.key) && validSectionIDs.contains($0.value)
    }
    for listID in taskListIDs {
      reconciledAssignments.removeValue(forKey: listID)
    }
    for listID in reconciledTaskListIDs {
      reconciledAssignments[listID] = ReminderSection.tasksID
    }

    if reconciledAssignments != listSectionAssignments {
      listSectionAssignments = reconciledAssignments
      persistSectionConfiguration()
    }
    reconcileActiveAddLists()

    let selectedCalendars = eventCalendars.filter {
      configuredListIDs.contains($0.calendarIdentifier)
    }
    let requestedListIDs = Set(selectedCalendars.map(\.calendarIdentifier))
    guard !selectedCalendars.isEmpty else {
      reminders = []
      return
    }

    let predicate = eventStore.predicateForIncompleteReminders(
      withDueDateStarting: nil,
      ending: nil,
      calendars: selectedCalendars
    )
    let fetched = await fetchReminderSnapshots(matching: predicate)
    guard generation == reloadGeneration,
      requestedListIDs == configuredListIDs
    else {
      return
    }
    reminders = ReminderOrderPolicy.applying(
      storedIDs: manualReminderOrderIDs,
      to: fetched
    )
  }

  func assignedSectionID(for listID: String) -> String? {
    listSectionAssignments[listID]
  }

  func setList(_ listID: String, sectionID: String?) {
    guard sectionID == nil || sections.contains(where: { $0.id == sectionID }) else { return }

    if let sectionID {
      listSectionAssignments[listID] = sectionID
    } else {
      listSectionAssignments.removeValue(forKey: listID)
    }
    defaults.set(true, forKey: hasConfiguredSelectionKey)
    persistSectionConfiguration()
    reconcileActiveAddLists()

    Task {
      await reload()
    }
  }

  func setActiveAddList(_ listID: String, for section: ReminderSection) {
    guard selectedListIDs(for: section).contains(listID) else { return }
    activeAddListIDs[section.id] = listID
  }

  @discardableResult
  func addSection(title: String) -> ReminderSection? {
    guard ReminderSectionPolicy.normalizedTitle(title) != nil else {
      errorMessage = "공간 이름을 입력해주세요."
      return nil
    }
    guard let updatedSections = ReminderSectionPolicy.adding(title: title, to: sections),
      let addedSection = updatedSections.last
    else {
      errorMessage = "같은 이름의 공간이 이미 있습니다."
      return nil
    }

    sections = updatedSections
    persistSectionConfiguration()
    return addedSection
  }

  @discardableResult
  func renameSection(_ sectionID: String, title: String) -> Bool {
    guard ReminderSectionPolicy.normalizedTitle(title) != nil else {
      errorMessage = "공간 이름을 입력해주세요."
      return false
    }
    guard
      let updatedSections = ReminderSectionPolicy.renaming(
        sectionID: sectionID,
        to: title,
        in: sections
      )
    else {
      errorMessage = "같은 이름의 공간이 이미 있습니다."
      return false
    }

    sections = updatedSections
    persistSectionConfiguration()
    return true
  }

  @discardableResult
  func deleteSection(_ sectionID: String) -> Bool {
    let configuration = ReminderSectionConfiguration(
      sections: sections,
      listSectionAssignments: listSectionAssignments
    )
    guard
      let updated = ReminderSectionPolicy.deleting(
        sectionID: sectionID,
        from: configuration
      )
    else {
      errorMessage = "기본 공간은 삭제할 수 없습니다."
      return false
    }

    sections = updated.sections
    listSectionAssignments = updated.listSectionAssignments
    activeAddListIDs.removeValue(forKey: sectionID)
    persistSectionConfiguration()

    Task {
      await reload()
    }
    return true
  }

  @discardableResult
  func moveReminder(_ itemID: String, toPositionOf targetID: String) -> Bool {
    let reordered = ReminderOrderPolicy.moving(
      itemID: itemID,
      toPositionOf: targetID,
      in: reminders
    )
    guard reordered != reminders else { return false }

    reminders = reordered
    persistManualOrder()
    return true
  }

  func moveReminder(_ itemID: String, offset: Int, in section: ReminderSection) {
    let visibleReminders = reminders(for: section)
    guard let sourceIndex = visibleReminders.firstIndex(where: { $0.id == itemID }) else { return }
    let targetIndex = sourceIndex + offset
    guard visibleReminders.indices.contains(targetIndex) else { return }
    _ = moveReminder(itemID, toPositionOf: visibleReminders[targetIndex].id)
  }

  func addReminder(
    title: String,
    dueDate: Date? = nil,
    in section: ReminderSection
  ) async -> Bool {
    guard let trimmedTitle = ReminderTitlePolicy.normalized(title) else { return false }
    guard let listID = activeAddList(for: section)?.id,
      let calendar = eventStore.calendar(withIdentifier: listID)
    else {
      errorMessage = "\(section.title)에 항목을 추가할 목록을 선택해주세요."
      return false
    }

    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = trimmedTitle
    reminder.calendar = calendar
    if let dueDate {
      reminder.dueDateComponents = ReminderDueDatePolicy.dateOnlyComponents(for: dueDate)
    }

    do {
      try eventStore.save(reminder, commit: true)
      await reload()
      return true
    } catch {
      errorMessage = "\(section.title)에 항목을 추가하지 못했습니다: \(error.localizedDescription)"
      return false
    }
  }

  func createReminderList(for section: ReminderSection) async -> Bool {
    errorMessage = nil

    let source =
      eventStore.defaultCalendarForNewReminders()?.source
      ?? eventStore.calendars(for: .reminder)
      .first(where: \.allowsContentModifications)?.source

    guard let source else {
      errorMessage = "\(section.title) 목록을 만들 Reminders 계정을 찾지 못했습니다."
      return false
    }

    let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
    calendar.title = section.title
    calendar.source = source

    do {
      try eventStore.saveCalendar(calendar, commit: true)
      setList(calendar.calendarIdentifier, sectionID: section.id)
      await reload()
      return true
    } catch {
      errorMessage = "\(section.title) 목록을 만들지 못했습니다: \(error.localizedDescription)"
      return false
    }
  }

  func updateReminder(
    _ item: ReminderItemSnapshot,
    title: String,
    dueDateUpdate: ReminderDueDateUpdate
  ) async -> Bool {
    guard let normalizedTitle = ReminderTitlePolicy.normalized(title) else {
      errorMessage = "할 일 제목을 입력해주세요."
      return false
    }
    let titleChanged = normalizedTitle != item.title
    guard titleChanged || dueDateUpdate != .unchanged else { return true }
    guard !updatingReminderIDs.contains(item.id) else { return false }

    updatingReminderIDs.insert(item.id)
    defer { updatingReminderIDs.remove(item.id) }

    guard let reminder = eventStore.calendarItem(withIdentifier: item.id) as? EKReminder else {
      errorMessage = "이 할 일을 다시 찾지 못했습니다. 목록을 새로고침합니다."
      await reload()
      return false
    }

    let previousTitle = reminder.title
    let previousDueDateComponents = reminder.dueDateComponents
    if titleChanged {
      reminder.title = normalizedTitle
    }
    switch dueDateUpdate {
    case .unchanged:
      break
    case .remove:
      reminder.dueDateComponents = nil
    case .set(let date):
      reminder.dueDateComponents = ReminderDueDatePolicy.dateOnlyComponents(for: date)
    }

    do {
      try eventStore.save(reminder, commit: true)
      await reload()
      return true
    } catch {
      reminder.title = previousTitle
      reminder.dueDateComponents = previousDueDateComponents
      let errorDescription = error.localizedDescription
      await reload()
      errorMessage = "할 일 변경 사항을 저장하지 못했습니다: \(errorDescription)"
      return false
    }
  }

  func complete(_ item: ReminderItemSnapshot) async {
    guard !completingIDs.contains(item.id) else { return }
    completingIDs.insert(item.id)
    defer { completingIDs.remove(item.id) }

    guard let reminder = eventStore.calendarItem(withIdentifier: item.id) as? EKReminder else {
      errorMessage = "이 할 일을 다시 찾지 못했습니다. 목록을 새로고침합니다."
      await reload()
      return
    }

    let wasCompleted = reminder.isCompleted
    let previousCompletionDate = reminder.completionDate
    reminder.isCompleted = true
    reminder.completionDate = Date()
    reminders = ReminderCompletionPolicy.hiding(itemID: item.id, from: reminders)
    await Task.yield()

    do {
      try eventStore.save(reminder, commit: true)
      offerUndo(for: item)
    } catch {
      reminder.isCompleted = wasCompleted
      reminder.completionDate = previousCompletionDate
      let errorDescription = error.localizedDescription
      await reload()
      errorMessage = "완료 상태를 저장하지 못했습니다: \(errorDescription)"
    }
  }

  func undoLastCompletion() async {
    guard !isUndoingCompletion, let completion = undoableCompletion else { return }

    undoDismissTask?.cancel()
    undoDismissTask = nil
    isUndoingCompletion = true
    defer { isUndoingCompletion = false }

    guard
      let reminder = eventStore.calendarItem(withIdentifier: completion.item.id) as? EKReminder
    else {
      undoableCompletion = nil
      await reload()
      errorMessage = "되돌릴 할 일을 다시 찾지 못했습니다."
      return
    }

    let wasCompleted = reminder.isCompleted
    let previousCompletionDate = reminder.completionDate
    reminder.isCompleted = false
    reminder.completionDate = nil
    let restored = ReminderCompletionPolicy.restoring(
      completion.item,
      to: reminders,
      selectedListIDs: configuredListIDs
    )
    reminders = ReminderOrderPolicy.applying(
      storedIDs: manualReminderOrderIDs,
      to: restored
    )
    undoableCompletion = nil
    await Task.yield()

    do {
      try eventStore.save(reminder, commit: true)
    } catch {
      reminder.isCompleted = wasCompleted
      reminder.completionDate = previousCompletionDate
      let errorDescription = error.localizedDescription
      await reload()
      errorMessage = "완료 상태를 되돌리지 못했습니다: \(errorDescription)"
    }
  }

  func dismissUndo() {
    undoDismissTask?.cancel()
    undoDismissTask = nil
    undoableCompletion = nil
  }

  func openReminders() {
    guard
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders")
    else {
      return
    }
    NSWorkspace.shared.openApplication(at: url, configuration: .init())
  }

  func openReminderPrivacySettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")
    else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  private func updateAuthorizationState() {
    switch EKEventStore.authorizationStatus(for: .reminder) {
    case .notDetermined:
      authorizationState = .unknown
    case .restricted:
      authorizationState = .restricted
    case .denied:
      authorizationState = .denied
    case .authorized, .fullAccess:
      authorizationState = .granted
    case .writeOnly:
      authorizationState = .denied
    @unknown default:
      authorizationState = .failed("알 수 없는 권한 상태")
    }
  }

  private func fetchReminderSnapshots(matching predicate: NSPredicate) async
    -> [ReminderItemSnapshot]
  {
    await withCheckedContinuation { continuation in
      eventStore.fetchReminders(matching: predicate) { reminders in
        let snapshots = (reminders ?? []).compactMap(Self.snapshot(from:))
        continuation.resume(returning: snapshots)
      }
    }
  }

  private func persistSectionConfiguration() {
    let configuration = ReminderSectionConfiguration(
      sections: sections,
      listSectionAssignments: listSectionAssignments
    )
    guard let data = try? JSONEncoder().encode(configuration) else { return }
    defaults.set(data, forKey: Self.configurationKey)
  }

  private func persistManualOrder() {
    manualReminderOrderIDs = ReminderOrderPolicy.storedIDs(
      visibleIDs: reminders.map(\.id),
      preserving: manualReminderOrderIDs
    )
    defaults.set(manualReminderOrderIDs, forKey: reminderOrderIDsKey)
  }

  private func reconcileActiveAddLists() {
    let validSectionIDs = Set(sections.map(\.id))
    activeAddListIDs = activeAddListIDs.filter { validSectionIDs.contains($0.key) }

    for section in sections {
      let selectedLists = selectedLists(for: section)
      if let activeID = activeAddListIDs[section.id],
        selectedLists.contains(where: { $0.id == activeID })
      {
        continue
      }
      activeAddListIDs[section.id] = selectedLists.first?.id
    }
  }

  private static func loadSectionConfiguration(
    from defaults: UserDefaults
  ) -> ReminderSectionConfiguration {
    if let data = defaults.data(forKey: configurationKey),
      var configuration = try? JSONDecoder().decode(
        ReminderSectionConfiguration.self,
        from: data
      )
    {
      if !configuration.sections.contains(where: { $0.id == ReminderSection.tasksID }) {
        configuration.sections.insert(.tasks, at: 0)
      }
      let validSectionIDs = Set(configuration.sections.map(\.id))
      configuration.listSectionAssignments = configuration.listSectionAssignments.filter {
        validSectionIDs.contains($0.value)
      }
      return configuration
    }

    let legacyTaskListIDs = Set(
      defaults.stringArray(forKey: legacySelectedListIDsKey) ?? []
    )
    let legacyJobListIDs = Set(
      defaults.stringArray(forKey: legacyJobListIDsKey) ?? []
    )
    return ReminderSectionPolicy.migratedConfiguration(
      legacyTaskListIDs: legacyTaskListIDs,
      legacyJobListIDs: legacyJobListIDs
    )
  }

  private func offerUndo(for item: ReminderItemSnapshot) {
    undoDismissTask?.cancel()

    let completion = UndoableCompletion(item: item)
    undoableCompletion = completion
    undoDismissTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(8))
      guard !Task.isCancelled else { return }
      guard self?.undoableCompletion?.id == completion.id else { return }
      self?.undoableCompletion = nil
      self?.undoDismissTask = nil
    }
  }

  nonisolated private static func snapshot(from reminder: EKReminder) -> ReminderItemSnapshot? {
    guard !reminder.isCompleted else { return nil }
    guard let calendar = reminder.calendar else { return nil }
    let components = reminder.dueDateComponents
    let dueDate = components.flatMap { value -> Date? in
      var value = value
      value.calendar = value.calendar ?? Calendar.current
      return value.date
    }
    let hasTime = components?.hour != nil || components?.minute != nil
    let trimmedNotes = reminder.notes?.trimmingCharacters(in: .whitespacesAndNewlines)

    return ReminderItemSnapshot(
      id: reminder.calendarItemIdentifier,
      title: reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        ?? "제목 없는 할 일",
      notes: trimmedNotes?.nilIfEmpty,
      dueDate: dueDate,
      hasTime: hasTime,
      priority: reminder.priority,
      listID: calendar.calendarIdentifier,
      listTitle: calendar.title,
      listTint: tint(from: calendar.cgColor)
    )
  }

  nonisolated private static func tint(from cgColor: CGColor) -> ListTint {
    let color = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB) ?? .controlAccentColor
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 1
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return ListTint(
      red: Double(red),
      green: Double(green),
      blue: Double(blue),
      opacity: Double(alpha)
    )
  }
}

extension String {
  fileprivate var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
