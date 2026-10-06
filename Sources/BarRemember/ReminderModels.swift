import Foundation

struct ReminderSection: Codable, Identifiable, Hashable, Sendable {
  static let defaultsKey = "selectedReminderSection"
  static let tasksID = "tasks"
  static let legacyJobsID = "jobs"
  static let tasks = ReminderSection(id: tasksID, title: "할 일")
  static let legacyJobs = ReminderSection(id: legacyJobsID, title: "지원 공고")

  let id: String
  var title: String

  init(id: String = "section-\(UUID().uuidString)", title: String) {
    self.id = id
    self.title = title
  }

  var isDefault: Bool { id == Self.tasksID }

  var displayTitle: String {
    switch id {
    case Self.tasksID:
      AppLanguage.localized(korean: "할 일", english: "Tasks")
    case Self.legacyJobsID:
      AppLanguage.localized(korean: "지원 공고", english: "Applications")
    default:
      title
    }
  }
}

struct ReminderSectionConfiguration: Codable, Equatable, Sendable {
  var sections: [ReminderSection]
  var listSectionAssignments: [String: String]
}

enum ReminderSectionPolicy {
  static func normalizedTitle(_ title: String) -> String? {
    let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? nil : normalized
  }

  static func adding(
    title: String,
    to sections: [ReminderSection],
    id: String = "section-\(UUID().uuidString)"
  ) -> [ReminderSection]? {
    guard let normalizedTitle = normalizedTitle(title) else { return nil }
    guard !containsTitle(normalizedTitle, in: sections) else { return nil }
    return sections + [ReminderSection(id: id, title: normalizedTitle)]
  }

  static func renaming(
    sectionID: String,
    to title: String,
    in sections: [ReminderSection]
  ) -> [ReminderSection]? {
    guard let normalizedTitle = normalizedTitle(title) else { return nil }
    guard sections.contains(where: { $0.id == sectionID }) else { return nil }
    guard !containsTitle(normalizedTitle, in: sections, excluding: sectionID) else { return nil }

    return sections.map { section in
      guard section.id == sectionID else { return section }
      return ReminderSection(id: section.id, title: normalizedTitle)
    }
  }

  static func deleting(
    sectionID: String,
    from configuration: ReminderSectionConfiguration
  ) -> ReminderSectionConfiguration? {
    guard sectionID != ReminderSection.tasksID else { return nil }
    guard configuration.sections.contains(where: { $0.id == sectionID }) else { return nil }

    return ReminderSectionConfiguration(
      sections: configuration.sections.filter { $0.id != sectionID },
      listSectionAssignments: configuration.listSectionAssignments.filter {
        $0.value != sectionID
      }
    )
  }

  static func migratedConfiguration(
    legacyTaskListIDs: Set<String>,
    legacyJobListIDs: Set<String>
  ) -> ReminderSectionConfiguration {
    var sections: [ReminderSection] = [.tasks]
    var assignments = Dictionary(
      uniqueKeysWithValues: legacyTaskListIDs.map { ($0, ReminderSection.tasksID) }
    )

    if !legacyJobListIDs.isEmpty {
      sections.append(.legacyJobs)
      for listID in legacyJobListIDs where assignments[listID] == nil {
        assignments[listID] = ReminderSection.legacyJobsID
      }
    }

    return ReminderSectionConfiguration(
      sections: sections,
      listSectionAssignments: assignments
    )
  }

  private static func containsTitle(
    _ title: String,
    in sections: [ReminderSection],
    excluding sectionID: String? = nil
  ) -> Bool {
    sections.contains {
      $0.id != sectionID && $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
    }
  }
}

struct ListTint: Hashable, Sendable {
  let red: Double
  let green: Double
  let blue: Double
  let opacity: Double

  static let accent = ListTint(red: 0.30, green: 0.48, blue: 0.95, opacity: 1)
}

struct ReminderListInfo: Identifiable, Hashable, Sendable {
  let id: String
  let title: String
  let tint: ListTint
  let canModify: Bool
}

enum ReminderListAssignmentPolicy {
  static func migratedHiddenListIDs(
    current assignments: [String: String],
    availableLists: [ReminderListInfo],
    hasConfiguredSelection: Bool
  ) -> Set<String> {
    guard hasConfiguredSelection else { return [] }
    return Set(availableLists.map(\.id)).subtracting(assignments.keys)
  }

  static func reconciledAssignments(
    current assignments: [String: String],
    sections: [ReminderSection],
    availableLists: [ReminderListInfo],
    legacyTaskListIDs: Set<String>,
    defaultID: String?,
    hasConfiguredSelection: Bool,
    intentionallyHiddenListIDs: Set<String> = []
  ) -> [String: String] {
    let validSectionIDs = Set(sections.map(\.id))
    let visibleLists = availableLists.filter { !intentionallyHiddenListIDs.contains($0.id) }
    let availableIDs = Set(visibleLists.map(\.id))
    var reconciledAssignments = assignments.filter {
      availableIDs.contains($0.key) && validSectionIDs.contains($0.value)
    }

    let savedTaskListIDs = Set(
      assignments.compactMap { listID, sectionID in
        sectionID == ReminderSection.tasksID ? listID : nil
      }
    ).union(legacyTaskListIDs)
    var reconciledTaskListIDs = ListSelectionPolicy.reconciledSelection(
      savedIDs: savedTaskListIDs,
      availableIDs: availableIDs,
      defaultID: defaultID,
      hasConfiguredSelection: hasConfiguredSelection || !legacyTaskListIDs.isEmpty
    )
    if reconciledTaskListIDs.isEmpty && !legacyTaskListIDs.isEmpty {
      reconciledTaskListIDs = ListSelectionPolicy.reconciledSelection(
        savedIDs: [],
        availableIDs: availableIDs,
        defaultID: defaultID,
        hasConfiguredSelection: false
      )
    }

    reconciledAssignments = reconciledAssignments.filter {
      $0.value != ReminderSection.tasksID
    }
    for listID in reconciledTaskListIDs {
      reconciledAssignments[listID] = ReminderSection.tasksID
    }

    for section in sections where !reconciledAssignments.values.contains(section.id) {
      guard let matchingList = firstUnassignedList(
        matching: section.title,
        in: visibleLists,
        assignedIDs: Set(reconciledAssignments.keys)
      ) else {
        continue
      }
      reconciledAssignments[matchingList.id] = section.id
    }

    return reconciledAssignments
  }

  private static func firstUnassignedList(
    matching title: String,
    in lists: [ReminderListInfo],
    assignedIDs: Set<String>
  ) -> ReminderListInfo? {
    lists.first {
      !assignedIDs.contains($0.id)
        && $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
    }
  }
}

struct ReminderItemSnapshot: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let notes: String?
  let dueDate: Date?
  let hasTime: Bool
  let priority: Int
  let listID: String
  let listTitle: String
  let listTint: ListTint

  static func displayOrder(_ lhs: Self, _ rhs: Self) -> Bool {
    switch (lhs.dueDate, rhs.dueDate) {
    case (let left?, let right?) where left != right:
      return left < right
    case (_?, nil):
      return true
    case (nil, _?):
      return false
    default:
      let leftPriority = priorityRank(lhs.priority)
      let rightPriority = priorityRank(rhs.priority)
      if leftPriority != rightPriority {
        return leftPriority < rightPriority
      }
      return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
  }

  private static func priorityRank(_ priority: Int) -> Int {
    priority == 0 ? Int.max : priority
  }
}

enum ReminderTitlePolicy {
  static func normalized(_ title: String) -> String? {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedTitle.isEmpty ? nil : trimmedTitle
  }
}

struct ParsedReminderDate: Equatable, Sendable {
  let title: String
  let dueDate: Date
  let matchedText: String
}

enum ReminderNaturalLanguageDateParser {
  static func parse(
    _ input: String,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> ParsedReminderDate? {
    guard let normalizedInput = ReminderTitlePolicy.normalized(input) else { return nil }

    if let match = firstMatch(
      pattern: #"(?:^|\s)(오늘|내일|모레|today|tomorrow|day after tomorrow)$"#,
      in: normalizedInput
    ), let relativeText = capture(1, from: match, in: normalizedInput) {
      let dayOffset: Int
      switch relativeText.lowercased() {
      case "오늘": dayOffset = 0
      case "내일": dayOffset = 1
      case "모레": dayOffset = 2
      case "today": dayOffset = 0
      case "tomorrow": dayOffset = 1
      case "day after tomorrow": dayOffset = 2
      default: return nil
      }
      let today = calendar.startOfDay(for: now)
      guard let dueDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
        return nil
      }
      return parsedResult(
        input: normalizedInput,
        match: match,
        dueDate: dueDate
      )
    }

    if let match = firstMatch(
      pattern: #"(?:^|\s)([0-9]{4})년\s*([0-9]{1,2})월\s*([0-9]{1,2})일$"#,
      in: normalizedInput
    ),
      let year = capturedInteger(1, from: match, in: normalizedInput),
      let month = capturedInteger(2, from: match, in: normalizedInput),
      let day = capturedInteger(3, from: match, in: normalizedInput),
      let dueDate = validDate(year: year, month: month, day: day, calendar: calendar)
    {
      return parsedResult(input: normalizedInput, match: match, dueDate: dueDate)
    }

    if let match = firstMatch(
      pattern: #"(?:^|\s)([0-9]{4})\s*(?:/|\.|-)\s*([0-9]{1,2})\s*(?:/|\.|-)\s*([0-9]{1,2})$"#,
      in: normalizedInput
    ),
      let year = capturedInteger(1, from: match, in: normalizedInput),
      let month = capturedInteger(2, from: match, in: normalizedInput),
      let day = capturedInteger(3, from: match, in: normalizedInput),
      let dueDate = validDate(year: year, month: month, day: day, calendar: calendar)
    {
      return parsedResult(input: normalizedInput, match: match, dueDate: dueDate)
    }

    if let match = firstMatch(
      pattern: #"(?:^|\s)([0-9]{1,2})월\s*([0-9]{1,2})일$"#,
      in: normalizedInput
    ),
      let month = capturedInteger(1, from: match, in: normalizedInput),
      let day = capturedInteger(2, from: match, in: normalizedInput),
      let dueDate = nextOccurrence(
        month: month,
        day: day,
        now: now,
        calendar: calendar
      )
    {
      return parsedResult(input: normalizedInput, match: match, dueDate: dueDate)
    }

    if let match = firstMatch(
      pattern: #"(?:^|\s)([0-9]{1,2})\s*(?:/|\.|-)\s*([0-9]{1,2})$"#,
      in: normalizedInput
    ),
      let month = capturedInteger(1, from: match, in: normalizedInput),
      let day = capturedInteger(2, from: match, in: normalizedInput),
      let dueDate = nextOccurrence(
        month: month,
        day: day,
        now: now,
        calendar: calendar
      )
    {
      return parsedResult(input: normalizedInput, match: match, dueDate: dueDate)
    }

    return nil
  }

  private static func firstMatch(
    pattern: String,
    in input: String
  ) -> NSTextCheckingResult? {
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
    return expression.firstMatch(
      in: input,
      range: NSRange(input.startIndex..<input.endIndex, in: input)
    )
  }

  private static func capture(
    _ index: Int,
    from match: NSTextCheckingResult,
    in input: String
  ) -> String? {
    guard index < match.numberOfRanges,
      let range = Range(match.range(at: index), in: input)
    else {
      return nil
    }
    return String(input[range])
  }

  private static func capturedInteger(
    _ index: Int,
    from match: NSTextCheckingResult,
    in input: String
  ) -> Int? {
    capture(index, from: match, in: input).flatMap(Int.init)
  }

  private static func parsedResult(
    input: String,
    match: NSTextCheckingResult,
    dueDate: Date
  ) -> ParsedReminderDate? {
    guard let matchRange = Range(match.range, in: input),
      let title = ReminderTitlePolicy.normalized(String(input[..<matchRange.lowerBound]))
    else {
      return nil
    }
    let matchedText = input[matchRange].trimmingCharacters(in: .whitespacesAndNewlines)
    return ParsedReminderDate(title: title, dueDate: dueDate, matchedText: matchedText)
  }

  private static func nextOccurrence(
    month: Int,
    day: Int,
    now: Date,
    calendar: Calendar
  ) -> Date? {
    let today = calendar.startOfDay(for: now)
    let currentYear = calendar.component(.year, from: today)

    for yearOffset in 0...8 {
      guard let candidate = validDate(
        year: currentYear + yearOffset,
        month: month,
        day: day,
        calendar: calendar
      ) else {
        continue
      }
      if candidate >= today {
        return candidate
      }
    }
    return nil
  }

  private static func validDate(
    year: Int,
    month: Int,
    day: Int,
    calendar: Calendar
  ) -> Date? {
    guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else {
      return nil
    }

    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = calendar.timeZone
    components.year = year
    components.month = month
    components.day = day

    guard let date = calendar.date(from: components) else { return nil }
    let verified = calendar.dateComponents([.year, .month, .day], from: date)
    guard verified.year == year, verified.month == month, verified.day == day else { return nil }
    return calendar.startOfDay(for: date)
  }
}

struct ReminderCreationDraft: Equatable, Sendable {
  let title: String
  let dueDate: Date?
}

struct ReminderEditDraft: Equatable, Sendable {
  let title: String
  let dueDateUpdate: ReminderDueDateUpdate
}

struct ReminderEditWrite: Equatable, Sendable {
  let title: String?
  let dueDateUpdate: ReminderDueDateUpdate

  var isEmpty: Bool {
    title == nil && dueDateUpdate == .unchanged
  }
}

enum ReminderEditWritePolicy {
  /// Only the fields that changed while this editor was open are written back.
  /// This preserves a newer EventKit title or due date when the person edited
  /// the other field in BarRemember.
  static func changes(
    original: ReminderItemSnapshot,
    resolvedTitle: String,
    dueDateUpdate: ReminderDueDateUpdate
  ) -> ReminderEditWrite {
    ReminderEditWrite(
      title: resolvedTitle == original.title ? nil : resolvedTitle,
      dueDateUpdate: dueDateUpdate
    )
  }
}

enum ReminderCreationDraftPolicy {
  static func resolve(
    title: String,
    manuallySelectedDueDate: Date?,
    allowsDetectedDueDate: Bool = true,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> ReminderCreationDraft? {
    guard let normalizedTitle = ReminderTitlePolicy.normalized(title) else { return nil }
    let parsedDate = allowsDetectedDueDate
      ? ReminderNaturalLanguageDateParser.parse(
        normalizedTitle,
        now: now,
        calendar: calendar
      )
      : nil
    return ReminderCreationDraft(
      title: parsedDate?.title ?? normalizedTitle,
      dueDate: manuallySelectedDueDate ?? parsedDate?.dueDate
    )
  }
}

enum ReminderEditDraftPolicy {
  static func resolve(
    title: String,
    dueDateUpdate: ReminderDueDateUpdate,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> ReminderEditDraft? {
    guard let normalizedTitle = ReminderTitlePolicy.normalized(title) else { return nil }
    let parsedDate = ReminderNaturalLanguageDateParser.parse(
      normalizedTitle,
      now: now,
      calendar: calendar
    )
    let resolvedDueDateUpdate: ReminderDueDateUpdate
    if let parsedDate, dueDateUpdate == .unchanged {
      resolvedDueDateUpdate = .set(parsedDate.dueDate)
    } else {
      resolvedDueDateUpdate = dueDateUpdate
    }
    return ReminderEditDraft(
      title: parsedDate?.title ?? normalizedTitle,
      dueDateUpdate: resolvedDueDateUpdate
    )
  }
}

enum ReminderDueDatePolicy {
  static func update(
    originalDate: Date?,
    hasDraftDate: Bool,
    draftDate: Date,
    calendar: Calendar = .current
  ) -> ReminderDueDateUpdate {
    switch (originalDate, hasDraftDate) {
    case (nil, false):
      return .unchanged
    case (nil, true):
      return .set(draftDate)
    case (_?, false):
      return .remove
    case (let originalDate?, true):
      return calendar.isDate(originalDate, inSameDayAs: draftDate)
        ? .unchanged
        : .set(draftDate)
    }
  }

  static func dateOnlyComponents(
    for date: Date,
    timeZone: TimeZone = .current
  ) -> DateComponents {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.calendar = calendar
    components.timeZone = timeZone
    return components
  }
}

enum ReminderDateDetectionPolicy {
  static func detectedDate(
    in title: String,
    hasManuallySelectedDueDate: Bool,
    isDetectionSuppressed: Bool,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> ParsedReminderDate? {
    guard !hasManuallySelectedDueDate, !isDetectionSuppressed else { return nil }
    return ReminderNaturalLanguageDateParser.parse(title, now: now, calendar: calendar)
  }
}

enum QuickAddSubmissionPolicy {
  static func shouldResetDraft(
    submittedTitle: String,
    submittedHasDueDate: Bool,
    submittedDueDate: Date,
    currentTitle: String,
    currentHasDueDate: Bool,
    currentDueDate: Date
  ) -> Bool {
    submittedTitle == currentTitle
      && submittedHasDueDate == currentHasDueDate
      && submittedDueDate == currentDueDate
  }
}

enum MenuBarPinnedReminderPolicy {
  static let maximumDisplayCharacters = 28

  static func displayTitle(_ title: String, maximumCharacters: Int = maximumDisplayCharacters) -> String {
    guard title.count > maximumCharacters, maximumCharacters > 1 else { return title }
    return String(title.prefix(maximumCharacters - 1)) + "…"
  }

  static func reconciledPinnedID(_ pinnedID: String?, availableIDs: Set<String>) -> String? {
    guard let pinnedID, availableIDs.contains(pinnedID) else { return nil }
    return pinnedID
  }
}

enum ReminderDueDateUpdate: Equatable, Sendable {
  case unchanged
  case remove
  case set(Date)
}

enum ReminderOrderPolicy {
  static func applying(
    storedIDs: [ReminderItemSnapshot.ID],
    to reminders: [ReminderItemSnapshot]
  ) -> [ReminderItemSnapshot] {
    let naturallySorted = reminders.sorted(by: ReminderItemSnapshot.displayOrder)
    guard !storedIDs.isEmpty else { return naturallySorted }

    var remindersByID = Dictionary(
      uniqueKeysWithValues: naturallySorted.map { ($0.id, $0) }
    )
    var ordered: [ReminderItemSnapshot] = []

    for id in storedIDs {
      guard let reminder = remindersByID.removeValue(forKey: id) else { continue }
      ordered.append(reminder)
    }

    ordered.append(
      contentsOf: remindersByID.values.sorted(by: ReminderItemSnapshot.displayOrder)
    )
    return ordered
  }

  static func moving(
    itemID: ReminderItemSnapshot.ID,
    toPositionOf targetID: ReminderItemSnapshot.ID,
    in reminders: [ReminderItemSnapshot]
  ) -> [ReminderItemSnapshot] {
    guard itemID != targetID,
      let sourceIndex = reminders.firstIndex(where: { $0.id == itemID }),
      let targetIndex = reminders.firstIndex(where: { $0.id == targetID })
    else {
      return reminders
    }

    var reordered = reminders
    let item = reordered.remove(at: sourceIndex)
    reordered.insert(item, at: min(targetIndex, reordered.endIndex))
    return reordered
  }

  static func storedIDs(
    visibleIDs: [ReminderItemSnapshot.ID],
    preserving previousIDs: [ReminderItemSnapshot.ID]
  ) -> [ReminderItemSnapshot.ID] {
    var seen: Set<ReminderItemSnapshot.ID> = []
    return (visibleIDs + previousIDs).filter { seen.insert($0).inserted }
  }
}

struct UndoableCompletion: Identifiable, Equatable, Sendable {
  let id: UUID
  let item: ReminderItemSnapshot

  init(id: UUID = UUID(), item: ReminderItemSnapshot) {
    self.id = id
    self.item = item
  }
}

enum ReminderAuthorizationState: Equatable, Sendable {
  case unknown
  case requesting
  case granted
  case denied
  case restricted
  case failed(String)
}

enum ListSelectionPolicy {
  static func reconciledSelection(
    savedIDs: Set<String>,
    availableIDs: Set<String>,
    defaultID: String?,
    hasConfiguredSelection: Bool
  ) -> Set<String> {
    if hasConfiguredSelection {
      return savedIDs.intersection(availableIDs)
    }

    if let defaultID, availableIDs.contains(defaultID) {
      return [defaultID]
    }

    if let firstID = availableIDs.sorted().first {
      return [firstID]
    }

    return []
  }
}

enum ReminderCompletionPolicy {
  static func hiding(
    itemID: ReminderItemSnapshot.ID,
    from reminders: [ReminderItemSnapshot]
  ) -> [ReminderItemSnapshot] {
    reminders.filter { $0.id != itemID }
  }

  static func restoring(
    _ item: ReminderItemSnapshot,
    to reminders: [ReminderItemSnapshot],
    selectedListIDs: Set<String>
  ) -> [ReminderItemSnapshot] {
    guard selectedListIDs.contains(item.listID) else { return reminders }
    guard !reminders.contains(where: { $0.id == item.id }) else { return reminders }
    return (reminders + [item]).sorted(by: ReminderItemSnapshot.displayOrder)
  }
}

enum ReminderDateKind: Equatable {
  case overdue
  case today
  case upcoming

  static func classify(
    _ date: Date,
    hasTime: Bool = true,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> Self {
    if !hasTime && calendar.isDate(date, inSameDayAs: now) {
      return .today
    }
    if date < now {
      return .overdue
    }
    if calendar.isDate(date, inSameDayAs: now) {
      return .today
    }
    return .upcoming
  }
}
