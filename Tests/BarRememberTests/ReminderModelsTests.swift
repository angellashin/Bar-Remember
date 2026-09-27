import Foundation
import Testing

@testable import BarRemember

struct ReminderModelsTests {
  @Test func cancelNeverTerminatesAndQuitRequiresConfirmation() {
    let requested = QuitConfirmationPolicy.decision(for: .request, isConfirming: false)
    let canceled = QuitConfirmationPolicy.decision(
      for: .cancel,
      isConfirming: requested.isConfirming
    )
    let unconfirmedQuit = QuitConfirmationPolicy.decision(for: .confirm, isConfirming: false)
    let confirmedQuit = QuitConfirmationPolicy.decision(for: .confirm, isConfirming: true)

    #expect(requested == QuitConfirmationDecision(isConfirming: true, shouldTerminate: false))
    #expect(canceled == QuitConfirmationDecision(isConfirming: false, shouldTerminate: false))
    #expect(
      unconfirmedQuit == QuitConfirmationDecision(isConfirming: false, shouldTerminate: false)
    )
    #expect(confirmedQuit == QuitConfirmationDecision(isConfirming: false, shouldTerminate: true))
  }

  @Test func customSectionTrimsItsNameAndRejectsDuplicates() throws {
    let added = try #require(
      ReminderSectionPolicy.adding(
        title: "  공부  ",
        to: [.tasks],
        id: "study"
      )
    )

    #expect(added.map(\.title) == ["할 일", "공부"])
    #expect(ReminderSectionPolicy.adding(title: "공부", to: added) == nil)
    #expect(ReminderSectionPolicy.adding(title: "   ", to: added) == nil)
  }

  @Test func sectionCanBeRenamedUnlessTheNameAlreadyExists() throws {
    let sections = [.tasks, ReminderSection(id: "study", title: "공부")]
    let renamed = try #require(
      ReminderSectionPolicy.renaming(
        sectionID: "study",
        to: "자격증",
        in: sections
      )
    )

    #expect(renamed.map(\.title) == ["할 일", "자격증"])
    #expect(
      ReminderSectionPolicy.renaming(
        sectionID: "study",
        to: "할 일",
        in: sections
      ) == nil
    )
  }

  @Test func deletingSectionHidesItsListsWithoutDeletingOtherAssignments() throws {
    let configuration = ReminderSectionConfiguration(
      sections: [.tasks, ReminderSection(id: "study", title: "공부")],
      listSectionAssignments: ["inbox": "tasks", "exam": "study"]
    )
    let deleted = try #require(
      ReminderSectionPolicy.deleting(sectionID: "study", from: configuration)
    )

    #expect(deleted.sections == [.tasks])
    #expect(deleted.listSectionAssignments == ["inbox": "tasks"])
    #expect(ReminderSectionPolicy.deleting(sectionID: "tasks", from: configuration) == nil)
  }

  @Test func legacyTaskAndJobListsMigrateIntoSeparateSpaces() {
    let configuration = ReminderSectionPolicy.migratedConfiguration(
      legacyTaskListIDs: ["inbox", "shared"],
      legacyJobListIDs: ["applications", "shared"]
    )

    #expect(configuration.sections == [.tasks, .legacyJobs])
    #expect(configuration.listSectionAssignments["inbox"] == "tasks")
    #expect(configuration.listSectionAssignments["applications"] == "jobs")
    #expect(configuration.listSectionAssignments["shared"] == "tasks")
  }

  @Test func emptySectionAssignmentsRecoverLegacyTaskSelection() {
    let lists = [
      ReminderListInfo(id: "legacy-inbox", title: "미리 알림", tint: .accent, canModify: true),
      ReminderListInfo(id: "applications", title: "공고", tint: .accent, canModify: true),
    ]

    let assignments = ReminderListAssignmentPolicy.reconciledAssignments(
      current: [:],
      sections: [.tasks, ReminderSection(id: "jobs", title: "공고")],
      availableLists: lists,
      legacyTaskListIDs: ["legacy-inbox"],
      defaultID: nil,
      hasConfiguredSelection: true
    )

    #expect(assignments["legacy-inbox"] == ReminderSection.tasksID)
    #expect(assignments["applications"] == "jobs")
  }

  @Test func staleListIdentifiersReconnectByMatchingSectionTitle() {
    let lists = [
      ReminderListInfo(id: "new-tasks-id", title: "할 일", tint: .accent, canModify: true),
      ReminderListInfo(id: "new-jobs-id", title: "공고", tint: .accent, canModify: true),
    ]

    let assignments = ReminderListAssignmentPolicy.reconciledAssignments(
      current: ["old-tasks-id": ReminderSection.tasksID, "old-jobs-id": "jobs"],
      sections: [.tasks, ReminderSection(id: "jobs", title: "공고")],
      availableLists: lists,
      legacyTaskListIDs: [],
      defaultID: nil,
      hasConfiguredSelection: true
    )

    #expect(assignments["new-tasks-id"] == ReminderSection.tasksID)
    #expect(assignments["new-jobs-id"] == "jobs")
    #expect(assignments["old-tasks-id"] == nil)
    #expect(assignments["old-jobs-id"] == nil)
  }

  @Test func staleLegacyTaskSelectionFallsBackToTheDefaultList() {
    let lists = [
      ReminderListInfo(id: "default-list", title: "미리 알림", tint: .accent, canModify: true),
      ReminderListInfo(id: "other-list", title: "업무", tint: .accent, canModify: true),
    ]

    let assignments = ReminderListAssignmentPolicy.reconciledAssignments(
      current: [:],
      sections: [.tasks],
      availableLists: lists,
      legacyTaskListIDs: ["stale-legacy-id"],
      defaultID: "default-list",
      hasConfiguredSelection: true
    )

    #expect(assignments == ["default-list": ReminderSection.tasksID])
  }

  @Test func reminderTitleTrimsOuterWhitespace() {
    #expect(ReminderTitlePolicy.normalized("  회의 자료 정리  \n") == "회의 자료 정리")
  }

  @Test func reminderTitleRejectsWhitespaceOnlyText() {
    #expect(ReminderTitlePolicy.normalized(" \n\t ") == nil)
  }

  @Test func themeOptionsHaveStableIdentifiersAndFallback() {
    #expect(BarRememberTheme.allCases.map(\.rawValue) == [
      "system", "frost", "midnight", "paper",
    ])
    #expect(BarRememberTheme.resolve("frost") == .frost)
    #expect(BarRememberTheme.resolve("unknown") == .system)
  }

  @Test func trailingMonthAndDayBecomeTheDueDateAndLeaveACleanTitle() throws {
    let calendar = try seoulCalendar()
    let now = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 14))
    )

    let parsed = try #require(
      ReminderNaturalLanguageDateParser.parse(
        "CJ 지원서 마감 9/28",
        now: now,
        calendar: calendar
      )
    )

    #expect(parsed.title == "CJ 지원서 마감")
    #expect(parsed.matchedText == "9/28")
    #expect(calendar.dateComponents([.year, .month, .day], from: parsed.dueDate)
      == DateComponents(year: 2026, month: 9, day: 28))
  }

  @Test func dateParserUnderstandsKoreanFullDatesAndRelativeDays() throws {
    let calendar = try seoulCalendar()
    let now = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 14))
    )
    let cases = [
      ("서류 제출 2027년 2월 14일", 2027, 2, 14),
      ("면접 준비 2027-03-02", 2027, 3, 2),
      ("장보기 10월 1일", 2026, 10, 1),
      ("자료 보내기 내일", 2026, 9, 24),
      ("운동 모레", 2026, 9, 25),
    ]

    for (input, year, month, day) in cases {
      let parsed = try #require(
        ReminderNaturalLanguageDateParser.parse(input, now: now, calendar: calendar)
      )
      #expect(
        calendar.dateComponents([.year, .month, .day], from: parsed.dueDate)
          == DateComponents(year: year, month: month, day: day)
      )
    }
  }

  @Test func yearlessPastDateMovesToTheNextCalendarYear() throws {
    let calendar = try seoulCalendar()
    let now = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 14))
    )
    let parsed = try #require(
      ReminderNaturalLanguageDateParser.parse(
        "새해 계획 1/3",
        now: now,
        calendar: calendar
      )
    )

    #expect(calendar.component(.year, from: parsed.dueDate) == 2027)
    #expect(calendar.component(.month, from: parsed.dueDate) == 1)
    #expect(calendar.component(.day, from: parsed.dueDate) == 3)
  }

  @Test func dateParserRejectsInvalidOrAmbiguousDateText() throws {
    let calendar = try seoulCalendar()
    let now = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 14))
    )

    #expect(
      ReminderNaturalLanguageDateParser.parse(
        "잘못된 날짜 2/30",
        now: now,
        calendar: calendar
      ) == nil
    )
    #expect(
      ReminderNaturalLanguageDateParser.parse(
        "9/28 회의 자료",
        now: now,
        calendar: calendar
      ) == nil
    )
    #expect(
      ReminderNaturalLanguageDateParser.parse(
        "9/28",
        now: now,
        calendar: calendar
      ) == nil
    )
  }

  @Test func manualDueDateWinsWhileDetectedTextIsRemovedFromTheTitle() throws {
    let calendar = try seoulCalendar()
    let now = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 14))
    )
    let manualDate = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 10, day: 4))
    )
    let resolved = try #require(
      ReminderCreationDraftPolicy.resolve(
        title: "CJ 지원서 마감 9/28",
        manuallySelectedDueDate: manualDate,
        now: now,
        calendar: calendar
      )
    )

    #expect(resolved.title == "CJ 지원서 마감")
    #expect(resolved.dueDate == manualDate)
  }

  @Test func newReminderDueDateUsesDateOnlyComponents() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
    let date = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 17, minute: 45))
    )

    let components = ReminderDueDatePolicy.dateOnlyComponents(for: date, calendar: calendar)

    #expect(components.year == 2026)
    #expect(components.month == 8)
    #expect(components.day == 21)
    #expect(components.hour == nil)
    #expect(components.minute == nil)
    #expect(components.calendar?.identifier == .gregorian)
    #expect(components.timeZone == calendar.timeZone)
  }

  @Test func existingReminderDateUpdatePreservesTimeUntilTheDayChanges() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
    let original = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 17, minute: 45))
    )
    let sameDayDraft = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 21))
    )
    let nextDayDraft = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 22))
    )

    #expect(
      ReminderDueDatePolicy.update(
        originalDate: original,
        hasDraftDate: true,
        draftDate: sameDayDraft,
        calendar: calendar
      ) == .unchanged
    )
    #expect(
      ReminderDueDatePolicy.update(
        originalDate: original,
        hasDraftDate: true,
        draftDate: nextDayDraft,
        calendar: calendar
      ) == .set(nextDayDraft)
    )
  }

  @Test func existingReminderDateCanBeAddedOrRemoved() throws {
    let date = Date(timeIntervalSince1970: 1_787_238_000)

    #expect(
      ReminderDueDatePolicy.update(
        originalDate: nil,
        hasDraftDate: false,
        draftDate: date
      ) == .unchanged
    )
    #expect(
      ReminderDueDatePolicy.update(
        originalDate: nil,
        hasDraftDate: true,
        draftDate: date
      ) == .set(date)
    )
    #expect(
      ReminderDueDatePolicy.update(
        originalDate: date,
        hasDraftDate: false,
        draftDate: date
      ) == .remove
    )
  }

  @Test func datedItemsSortBeforeUndatedItems() {
    let now = Date()
    let dated = item(id: "dated", title: "Dated", dueDate: now)
    let undated = item(id: "undated", title: "Undated", dueDate: nil)

    let sorted = [undated, dated].sorted(by: ReminderItemSnapshot.displayOrder)

    #expect(sorted.map(\.id) == ["dated", "undated"])
  }

  @Test func earlierItemsSortFirst() {
    let now = Date()
    let later = item(id: "later", title: "Later", dueDate: now.addingTimeInterval(120))
    let earlier = item(id: "earlier", title: "Earlier", dueDate: now.addingTimeInterval(60))

    let sorted = [later, earlier].sorted(by: ReminderItemSnapshot.displayOrder)

    #expect(sorted.map(\.id) == ["earlier", "later"])
  }

  @Test func storedManualOrderOverridesNaturalOrder() {
    let now = Date()
    let earlier = item(id: "earlier", title: "Earlier", dueDate: now)
    let later = item(id: "later", title: "Later", dueDate: now.addingTimeInterval(60))

    let ordered = ReminderOrderPolicy.applying(
      storedIDs: [later.id, earlier.id],
      to: [earlier, later]
    )

    #expect(ordered.map(\.id) == ["later", "earlier"])
  }

  @Test func newItemsAppendInNaturalOrderAfterStoredItems() {
    let now = Date()
    let manual = item(id: "manual", title: "Manual", dueDate: nil)
    let earlier = item(id: "earlier", title: "Earlier", dueDate: now)
    let later = item(id: "later", title: "Later", dueDate: now.addingTimeInterval(60))

    let ordered = ReminderOrderPolicy.applying(
      storedIDs: [manual.id, "deleted"],
      to: [later, manual, earlier]
    )

    #expect(ordered.map(\.id) == ["manual", "earlier", "later"])
  }

  @Test func remindersMoveUpAndDownToTheTargetPosition() {
    let first = item(id: "first", title: "First", dueDate: nil)
    let second = item(id: "second", title: "Second", dueDate: nil)
    let third = item(id: "third", title: "Third", dueDate: nil)

    let movedDown = ReminderOrderPolicy.moving(
      itemID: first.id,
      toPositionOf: third.id,
      in: [first, second, third]
    )
    let movedUp = ReminderOrderPolicy.moving(
      itemID: third.id,
      toPositionOf: first.id,
      in: [first, second, third]
    )

    #expect(movedDown.map(\.id) == ["second", "third", "first"])
    #expect(movedUp.map(\.id) == ["third", "first", "second"])
  }

  @Test func savingVisibleOrderPreservesHiddenListItems() {
    let storedIDs = ReminderOrderPolicy.storedIDs(
      visibleIDs: ["visible-b", "visible-a"],
      preserving: ["visible-a", "hidden", "visible-b"]
    )

    #expect(storedIDs == ["visible-b", "visible-a", "hidden"])
  }

  @Test func configuredSelectionOnlyKeepsAvailableLists() {
    let selection = ListSelectionPolicy.reconciledSelection(
      savedIDs: ["personal", "deleted"],
      availableIDs: ["personal", "work"],
      defaultID: "work",
      hasConfiguredSelection: true
    )

    #expect(selection == ["personal"])
  }

  @Test func firstRunSelectsDefaultList() {
    let selection = ListSelectionPolicy.reconciledSelection(
      savedIDs: [],
      availableIDs: ["personal", "work"],
      defaultID: "work",
      hasConfiguredSelection: false
    )

    #expect(selection == ["work"])
  }

  @Test func dueDateClassificationDistinguishesPastAndToday() {
    let calendar = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    #expect(
      ReminderDateKind.classify(now.addingTimeInterval(-1), now: now, calendar: calendar)
        == .overdue)
    #expect(
      ReminderDateKind.classify(now.addingTimeInterval(60), now: now, calendar: calendar) == .today)
  }

  @Test func allDayReminderStaysTodayAfterMidnight() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let startOfDay = Date(timeIntervalSince1970: 1_699_920_000)
    let noon = startOfDay.addingTimeInterval(12 * 60 * 60)

    #expect(
      ReminderDateKind.classify(startOfDay, hasTime: false, now: noon, calendar: calendar) == .today
    )
  }

  @Test func iconColorFallsBackToIndigoForUnknownSavedValue() {
    #expect(ReminderIconColor.resolve("missing") == .indigo)
  }

  @Test func iconColorOptionsHaveStableIdentifiers() {
    #expect(
      ReminderIconColor.allCases.map(\.rawValue)
        == ["indigo", "blue", "teal", "green", "orange", "rose"])
  }

  @Test func completingReminderHidesOnlyTheSelectedItem() {
    let first = item(id: "first", title: "First", dueDate: nil)
    let second = item(id: "second", title: "Second", dueDate: nil)

    let visible = ReminderCompletionPolicy.hiding(
      itemID: first.id,
      from: [first, second]
    )

    #expect(visible == [second])
  }

  @Test func undoingCompletionRestoresTheItemInDisplayOrder() {
    let now = Date()
    let restored = item(id: "restored", title: "Restored", dueDate: now)
    let later = item(id: "later", title: "Later", dueDate: now.addingTimeInterval(60))

    let visible = ReminderCompletionPolicy.restoring(
      restored,
      to: [later],
      selectedListIDs: [restored.listID]
    )

    #expect(visible.map(\.id) == ["restored", "later"])
  }

  @Test func undoingCompletionDoesNotDuplicateOrRestoreHiddenLists() {
    let restored = item(id: "restored", title: "Restored", dueDate: nil)

    #expect(
      ReminderCompletionPolicy.restoring(
        restored,
        to: [restored],
        selectedListIDs: [restored.listID]
      ) == [restored])
    #expect(
      ReminderCompletionPolicy.restoring(
        restored,
        to: [],
        selectedListIDs: []
      ).isEmpty)
  }

  @Test func undoingCompletionCanReturnToItsManualPosition() {
    let first = item(id: "first", title: "First", dueDate: nil)
    let restored = item(id: "restored", title: "Restored", dueDate: nil)
    let last = item(id: "last", title: "Last", dueDate: nil)

    let naturallyRestored = ReminderCompletionPolicy.restoring(
      restored,
      to: [first, last],
      selectedListIDs: [restored.listID]
    )
    let manuallyRestored = ReminderOrderPolicy.applying(
      storedIDs: [first.id, restored.id, last.id],
      to: naturallyRestored
    )

    #expect(manuallyRestored.map(\.id) == ["first", "restored", "last"])
  }

  private func item(id: String, title: String, dueDate: Date?) -> ReminderItemSnapshot {
    ReminderItemSnapshot(
      id: id,
      title: title,
      notes: nil,
      dueDate: dueDate,
      hasTime: dueDate != nil,
      priority: 0,
      listID: "list",
      listTitle: "List",
      listTint: .accent
    )
  }

  private func seoulCalendar() throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
    return calendar
  }
}
