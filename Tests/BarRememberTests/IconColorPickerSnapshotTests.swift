import AppKit
import SwiftUI
import Testing

@testable import BarRemember

struct IconColorPickerSnapshotTests {
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
