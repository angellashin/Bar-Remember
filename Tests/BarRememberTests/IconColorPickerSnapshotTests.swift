import AppKit
import SwiftUI
import Testing

@testable import BarRemember

struct IconColorPickerSnapshotTests {
  @Test @MainActor func pinnedMenuBarDemoRendersBeforeAndAfterWithFixtureData() throws {
    let longTitle = "Read SwiftUI notes and prepare a detailed design review for the team"
    let item = ReminderItemSnapshot(
      id: "demo-pinned",
      title: longTitle,
      notes: nil,
      dueDate: nil,
      hasTime: false,
      priority: 0,
      listID: "demo-work",
      listTitle: "Work",
      listTint: .accent
    )
    let row: (Bool) -> ReminderRow = { isPinned in
      ReminderRow(
        item: item,
        isCompleting: false,
        iconColor: ReminderIconColor.indigo.color,
        itemKindLabel: "Task",
        completionActionTitle: "Complete",
        allowsDragging: false,
        isPinned: isPinned,
        onComplete: {},
        onMove: { _ in false },
        onMoveUp: {},
        onMoveDown: {},
        onTogglePin: {}
      )
    }
    let view = HStack(spacing: 16) {
      pinnedDemoCard(label: "Before pinning", menuTitle: nil, row: row(false))
      pinnedDemoCard(
        label: "Pinned to menu bar",
        menuTitle: MenuBarPinnedReminderPolicy.displayTitle(longTitle),
        row: row(true)
      )
    }
    .padding(16)
    .frame(width: 760, height: 240)
    .background(Color(nsColor: .windowBackgroundColor))
    .environment(\.locale, Locale(identifier: "en_US"))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)
    #expect(image.size.width == 760)
    #expect(image.size.height == 240)

    guard let outputPath = ProcessInfo.processInfo.environment[
      "BARREMEMBER_PINNED_DEMO_SCREENSHOT_PATH"
    ] else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }

  @MainActor private func pinnedDemoCard(
    label: String,
    menuTitle: String?,
    row: ReminderRow
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(label).font(.headline)
      HStack {
        Image(systemName: menuTitle == nil ? "checklist" : "pin.fill")
        Text(menuTitle ?? "BarRemember")
          .lineLimit(1)
        Spacer()
      }
      .padding(8)
      .background(BarRememberPalette.controlFill, in: RoundedRectangle(cornerRadius: 8))
      row
    }
    .frame(width: 348, alignment: .leading)
  }

  @Test @MainActor func englishDemoRendersOnlyIsolatedSampleData() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let today = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 9))
    )
    let tomorrow = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 10, day: 7))
    )
    let items = [
      ReminderItemSnapshot(
        id: "demo-landing-page",
        title: "Review landing page",
        notes: nil,
        dueDate: today,
        hasTime: false,
        priority: 0,
        listID: "demo-work",
        listTitle: "Work",
        listTint: .accent
      ),
      ReminderItemSnapshot(
        id: "demo-design-feedback",
        title: "Send design feedback",
        notes: nil,
        dueDate: tomorrow,
        hasTime: false,
        priority: 0,
        listID: "demo-work",
        listTitle: "Work",
        listTint: .accent
      ),
      ReminderItemSnapshot(
        id: "demo-swiftui-notes",
        title: "Read SwiftUI notes",
        notes: nil,
        dueDate: nil,
        hasTime: false,
        priority: 0,
        listID: "demo-work",
        listTitle: "Work",
        listTint: .accent
      ),
    ]
    let view = VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("Tuesday, October 6")
            .font(.headline)
            .foregroundStyle(BarRememberPalette.primaryText)
          Text("3 remaining in Tasks")
            .font(.caption)
            .foregroundStyle(BarRememberPalette.secondaryText)
        }
        Spacer()
        Image(systemName: "arrow.clockwise")
          .foregroundStyle(BarRememberPalette.accent)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 14)

      Divider().opacity(0.55)
      ReminderSectionPicker(
        sections: [ReminderSection(id: "demo-tasks", title: "Tasks")],
        selection: .constant("demo-tasks"),
        rendersStaticPreview: true,
        countForSection: { _ in items.count },
        addSection: {}
      )
      .padding(.horizontal, 14)
      .padding(.vertical, 10)

      Divider().opacity(0.45)
      QuickAddReminderView(
        title: .constant("Plan launch retrospective 10/8"),
        hasDueDate: .constant(false),
        dueDate: .constant(today),
        placeholder: "Add a task",
        lists: [ReminderListInfo(id: "demo-work", title: "Work", tint: .accent, canModify: true)],
        activeListID: "demo-work",
        rendersStaticTitlePreview: true,
        rendersStaticDatePreview: true,
        currentDate: { today },
        submit: {}
      )
      .padding(.horizontal, 14)
      .padding(.vertical, 12)

      ForEach(items) { item in
        ReminderRow(
          item: item,
          isCompleting: false,
          iconColor: ReminderIconColor.indigo.color,
          itemKindLabel: "Task",
          completionActionTitle: "Complete",
          allowsDragging: false,
          onComplete: {},
          onMove: { _ in false },
          onMoveUp: {},
          onMoveDown: {}
        )
      }

      Spacer(minLength: 0)
      Divider().opacity(0.55)
      HStack {
        Label("Settings", systemImage: "slider.horizontal.3")
        Spacer()
        Text("Reminders")
        Spacer()
        Text("Quit…")
      }
      .font(.caption)
      .foregroundStyle(BarRememberPalette.accent)
      .padding(.horizontal, 16)
      .frame(height: 44)
    }
    .frame(width: 380, height: 520)
    .background(Color(nsColor: .windowBackgroundColor))
    .environment(\.locale, Locale(identifier: "en_US"))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)
    #expect(image.size.width == 380)
    #expect(image.size.height == 520)

    guard let outputPath = ProcessInfo.processInfo.environment[
      "BARREMEMBER_DEMO_SCREENSHOT_PATH"
    ] else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }

  @Test @MainActor func typedDateDetectionFitsQuickAddCard() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
    let now = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 14))
    )
    let view = QuickAddReminderView(
      title: .constant("CJ 지원서 마감 9/28"),
      hasDueDate: .constant(false),
      dueDate: .constant(now),
      placeholder: "새 항목 추가",
      rendersStaticTitlePreview: true,
      rendersStaticDatePreview: true,
      currentDate: { now },
      submit: {}
    )
    .padding(10)
    .frame(width: 380, height: 92)
    .background(Color(nsColor: .windowBackgroundColor))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)

    #expect(image.size.width == 380)
    #expect(image.size.height == 92)

    guard
      let outputPath = ProcessInfo.processInfo.environment[
        "BARREMEMBER_DATE_DETECTION_SNAPSHOT_PATH"
      ]
    else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }

  @Test @MainActor func quickAddDateAndReminderRowFitMenuBarWidth() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 9 * 60 * 60))
    let dueDate = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 21))
    )
    let item = ReminderItemSnapshot(
      id: "dated-preview",
      title: "지원서 제출",
      notes: nil,
      dueDate: dueDate,
      hasTime: false,
      priority: 0,
      listID: "applications",
      listTitle: "공고",
      listTint: .accent
    )
    let view = VStack(spacing: 8) {
      QuickAddReminderView(
        title: .constant("지원서 작성"),
        hasDueDate: .constant(true),
        dueDate: .constant(dueDate),
        placeholder: "새 항목 추가",
        rendersStaticTitlePreview: true,
        rendersStaticDatePreview: true,
        submit: {}
      )

      ReminderRow(
        item: item,
        isCompleting: false,
        iconColor: ReminderIconColor.indigo.color,
        allowsDragging: false,
        onComplete: {},
        onMove: { _ in false },
        onMoveUp: {},
        onMoveDown: {}
      )
    }
    .padding(10)
    .frame(width: 380, height: 150)
    .background(Color(nsColor: .windowBackgroundColor))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)

    #expect(image.size.width == 380)
    #expect(image.size.height == 150)

    guard
      let outputPath = ProcessInfo.processInfo.environment[
        "BARREMEMBER_DATE_ADD_SNAPSHOT_PATH"
      ]
    else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }

  @Test @MainActor func sectionPickerRendersCustomSpacesAtMenuBarWidth() throws {
    let view = VStack(spacing: 0) {
      ReminderSectionPicker(
        sections: [
          .tasks,
          ReminderSection(id: "study", title: "공부"),
          ReminderSection(id: "shopping", title: "장보기"),
        ],
        selection: .constant("study"),
        rendersStaticPreview: true,
        countForSection: { section in
          ["tasks": 5, "study": 3, "shopping": 2][section.id, default: 0]
        },
        addSection: {}
      )
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
    .frame(width: 380, height: 56)
    .background(Color(nsColor: .windowBackgroundColor))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)

    #expect(image.size.width == 380)
    #expect(image.size.height == 56)

    guard
      let outputPath = ProcessInfo.processInfo.environment[
        "BARREMEMBER_SECTION_SNAPSHOT_PATH"
      ]
    else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }

  @Test @MainActor func pickerRendersWithinMenuBarSettingsWidth() throws {
    let view = VStack(alignment: .leading, spacing: 8) {
      Text("아이콘 색상")
        .font(.caption)
        .foregroundStyle(BarRememberPalette.secondaryText)
      IconColorPicker(selection: .constant(ReminderIconColor.indigo.rawValue))
      Text("완료 원에 적용됩니다.")
        .font(.caption2)
        .foregroundStyle(BarRememberPalette.mutedText)
    }
    .padding(16)
    .frame(width: 380, height: 112, alignment: .leading)
    .background(Color(nsColor: .windowBackgroundColor))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)

    #expect(image.size.width == 380)
    #expect(image.size.height == 112)

    guard let outputPath = ProcessInfo.processInfo.environment["BARREMEMBER_SNAPSHOT_PATH"]
    else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }

  @Test @MainActor func themePickerRendersWithinMenuBarSettingsWidth() throws {
    let view = VStack(alignment: .leading, spacing: 8) {
      Text("앱 테마")
        .font(.caption)
        .foregroundStyle(BarRememberPalette.secondaryText)
      ThemePicker(selection: .constant(BarRememberTheme.glass.rawValue))
      Text("Glass와 미드나이트는 반투명 material 위에 색을 더합니다.")
        .font(.caption2)
        .foregroundStyle(BarRememberPalette.mutedText)
    }
    .padding(16)
    .frame(width: 380, height: 112, alignment: .leading)
    .background(Color(nsColor: .windowBackgroundColor))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)

    #expect(image.size.width == 380)
    #expect(image.size.height == 112)

    guard let outputPath = ProcessInfo.processInfo.environment["BARREMEMBER_THEME_SNAPSHOT_PATH"]
    else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }

  @Test @MainActor func reminderRowRendersWithLargeCompletionTarget() throws {
    let item = ReminderItemSnapshot(
      id: "preview",
      title: "회의 자료 정리",
      notes: nil,
      dueDate: Date(),
      hasTime: false,
      priority: 0,
      listID: "work",
      listTitle: "업무",
      listTint: .accent
    )
    let view = ReminderRow(
      item: item,
      isCompleting: false,
      iconColor: ReminderIconColor.indigo.color,
      allowsDragging: false,
      onComplete: {},
      onMove: { _ in false },
      onMoveUp: {},
      onMoveDown: {}
    )
    .padding(10)
    .frame(width: 380, height: 76)
    .background(Color(nsColor: .windowBackgroundColor))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)

    #expect(image.size.width == 380)
    #expect(image.size.height == 76)

    guard let outputPath = ProcessInfo.processInfo.environment["BARREMEMBER_ROW_SNAPSHOT_PATH"]
    else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }

  @Test @MainActor func undoCompletionBannerFitsMenuBarWidth() throws {
    let view = UndoCompletionBanner(
      itemTitle: "회의 자료 정리",
      isUndoing: false,
      onUndo: {}
    )
    .padding(10)
    .frame(width: 380, height: 76)
    .background(Color(nsColor: .windowBackgroundColor))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)

    #expect(image.size.width == 380)
    #expect(image.size.height == 76)

    guard let outputPath = ProcessInfo.processInfo.environment["BARREMEMBER_UNDO_SNAPSHOT_PATH"]
    else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }

  @Test @MainActor func reminderRowInlineEditorFitsMenuBarWidth() throws {
    let item = ReminderItemSnapshot(
      id: "edit-preview",
      title: "회의 자료 정리",
      notes: nil,
      dueDate: Date(),
      hasTime: false,
      priority: 0,
      listID: "work",
      listTitle: "업무",
      listTint: .accent
    )
    let view = ReminderRow(
      item: item,
      isCompleting: false,
      iconColor: ReminderIconColor.indigo.color,
      allowsDragging: false,
      automaticallyFocusEditor: false,
      rendersStaticEditorPreview: true,
      interactionsDisabled: true,
      isEditing: true,
      isSavingChanges: false,
      onComplete: {},
      onMove: { _ in false },
      onMoveUp: {},
      onMoveDown: {},
      onBeginEditing: {},
      onCancelEditing: {},
      onSaveChanges: { _, _ in true }
    )
    .padding(10)
    .frame(width: 380, height: 100)
    .background(Color(nsColor: .windowBackgroundColor))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    let image = try #require(renderer.nsImage)

    #expect(image.size.width == 380)
    #expect(image.size.height == 100)

    guard let outputPath = ProcessInfo.processInfo.environment["BARREMEMBER_EDIT_SNAPSHOT_PATH"]
    else { return }
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
  }
}
