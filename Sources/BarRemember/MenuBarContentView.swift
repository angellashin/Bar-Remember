import AppKit
import SwiftUI

enum QuitConfirmationAction {
  case request
  case cancel
  case confirm
}

struct QuitConfirmationDecision: Equatable {
  let isConfirming: Bool
  let shouldTerminate: Bool
}

enum QuitConfirmationPolicy {
  static func decision(
    for action: QuitConfirmationAction,
    isConfirming: Bool
  ) -> QuitConfirmationDecision {
    switch action {
    case .request:
      QuitConfirmationDecision(isConfirming: true, shouldTerminate: false)
    case .cancel:
      QuitConfirmationDecision(isConfirming: false, shouldTerminate: false)
    case .confirm:
      QuitConfirmationDecision(isConfirming: false, shouldTerminate: isConfirming)
    }
  }
}

struct MenuBarContentView: View {
  @EnvironmentObject private var store: ReminderStore
  @EnvironmentObject private var loginItemController: LoginItemController
  @AppStorage(ReminderIconColor.defaultsKey) private var iconColorRawValue =
    ReminderIconColor.indigo.rawValue
  @AppStorage(BarRememberTheme.defaultsKey) private var themeRawValue =
    BarRememberTheme.system.rawValue
  @AppStorage(ReminderSection.defaultsKey) private var selectedSectionRawValue =
    ReminderSection.tasks.id
  @State private var isShowingListSelection = false
  @State private var isShowingAddSection = false
  @State private var newSectionTitle = ""
  @State private var newReminderTitle = ""
  @State private var newReminderHasDueDate = false
  @State private var newReminderDueDate = Date()
  @State private var editingReminderID: ReminderItemSnapshot.ID?
  @State private var isConfirmingQuit = false

  var body: some View {
    Group {
      if isShowingListSelection {
        ListSelectionView(
          isPresented: $isShowingListSelection,
          iconColorRawValue: $iconColorRawValue,
          themeRawValue: $themeRawValue
        )
      } else {
        mainContent
      }
    }
    .frame(width: 380, height: 520)
    .background(BarRememberPalette.popoverOverlay)
    .background(.ultraThinMaterial)
    .overlay {
      if BarRememberTheme.resolve(themeRawValue) == .glass {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(.white.opacity(0.28), lineWidth: 0.8)
          .allowsHitTesting(false)
      }
    }
    .task {
      if store.section(withID: selectedSectionRawValue) == nil {
        selectedSectionRawValue = store.sections.first?.id ?? ReminderSection.tasksID
      }
      await store.reload()
      loginItemController.refresh()
    }
    .onChange(of: store.reminders.map(\.id)) { _, visibleReminderIDs in
      guard let editingReminderID else { return }
      if !visibleReminderIDs.contains(editingReminderID) {
        self.editingReminderID = nil
      }
    }
    .onChange(of: selectedSectionRawValue) {
      resetQuickAdd()
      editingReminderID = nil
      isConfirmingQuit = false
    }
    .onChange(of: store.sections.map(\.id)) { _, sectionIDs in
      if !sectionIDs.contains(selectedSectionRawValue) {
        selectedSectionRawValue = store.sections.first?.id ?? ReminderSection.tasksID
      }
    }
    .alert("새 공간 추가", isPresented: $isShowingAddSection) {
      TextField("예: 공부, 장보기, 지원 공고", text: $newSectionTitle)
      Button("취소", role: .cancel) {
        newSectionTitle = ""
      }
      Button("추가") {
        if let section = store.addSection(title: newSectionTitle) {
          selectedSectionRawValue = section.id
          newSectionTitle = ""
        }
      }
    } message: {
      Text("원하는 이름으로 항목을 분리해 관리할 수 있습니다.")
    }
    .alert("BarRemember", isPresented: errorIsPresented) {
      Button("확인", role: .cancel) {
        store.errorMessage = nil
        loginItemController.errorMessage = nil
      }
    } message: {
      Text(store.errorMessage ?? loginItemController.errorMessage ?? "알 수 없는 오류")
    }
    .onDisappear {
      isConfirmingQuit = false
    }
  }

  private var mainContent: some View {
    VStack(spacing: 0) {
      header
      Divider().opacity(0.55)

      switch store.authorizationState {
      case .granted:
        authorizedContent
      case .unknown, .requesting:
        PermissionView(isRequesting: store.authorizationState == .requesting) {
          Task { await store.requestAccess() }
        }
      case .denied, .restricted, .failed:
        PermissionDeniedView {
          store.openReminderPrivacySettings()
        }
      }

      if let completion = store.undoableCompletion {
        UndoCompletionBanner(
          itemTitle: completion.item.title,
          isUndoing: store.isUndoingCompletion
        ) {
          Task { await store.undoLastCompletion() }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      Divider().opacity(0.55)
      footer
    }
    .animation(.easeInOut(duration: 0.18), value: store.undoableCompletion?.id)
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(
          Date.now.formatted(
            .dateTime.locale(Locale(identifier: "ko_KR")).month().day().weekday(.wide))
        )
        .font(.headline)
        .foregroundStyle(BarRememberPalette.primaryText)
        Text(summaryText)
          .font(.caption)
          .foregroundStyle(BarRememberPalette.secondaryText)
      }

      Spacer()

      if store.isLoading {
        ProgressView()
          .controlSize(.small)
      }

      Button {
        Task { await store.reload() }
      } label: {
        Image(systemName: "arrow.clockwise")
          .foregroundStyle(BarRememberPalette.accent)
      }
      .buttonStyle(.borderless)
      .help("새로고침")
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
  }

  @ViewBuilder
  private var authorizedContent: some View {
    VStack(spacing: 0) {
      ReminderSectionPicker(
        sections: store.sections,
        selection: sectionBinding,
        countForSection: { store.reminders(for: $0).count },
        addSection: { isShowingAddSection = true }
      )
      .padding(.horizontal, 14)
      .padding(.vertical, 10)

      Divider().opacity(0.45)

      if currentSelectedListIDs.isEmpty {
        EmptySelectionView(
          section: selectedSection,
          createReminderList: { await store.createReminderList(for: selectedSection) },
          chooseLists: { isShowingListSelection = true }
        )
      } else {
        quickAdd
          .padding(.horizontal, 14)
          .padding(.vertical, 12)

        if visibleReminders.isEmpty && !store.isLoading {
          EmptyRemindersView(section: selectedSection)
        } else {
          ScrollView {
            LazyVStack(spacing: 5) {
              ForEach(visibleReminders) { item in
                ReminderRow(
                  item: item,
                  isCompleting: store.completingIDs.contains(item.id),
                  iconColor: selectedIconColor.color,
                  itemKindLabel: selectedSection.title,
                  completionActionTitle: "완료",
                  interactionsDisabled: editingReminderID != nil
                    || !store.updatingReminderIDs.isEmpty,
                  isEditing: editingReminderID == item.id,
                  isSavingChanges: store.updatingReminderIDs.contains(item.id),
                  onComplete: {
                    Task { await store.complete(item) }
                  },
                  onMove: { sourceID in
                    store.moveReminder(sourceID, toPositionOf: item.id)
                  },
                  onMoveUp: {
                    store.moveReminder(item.id, offset: -1, in: selectedSection)
                  },
                  onMoveDown: {
                    store.moveReminder(item.id, offset: 1, in: selectedSection)
                  },
                  onBeginEditing: {
                    editingReminderID = item.id
                  },
                  onCancelEditing: {
                    if editingReminderID == item.id {
                      editingReminderID = nil
                    }
                  },
                  onSaveChanges: { title, dueDateUpdate in
                    let didUpdate = await store.updateReminder(
                      item,
                      title: title,
                      dueDateUpdate: dueDateUpdate
                    )
                    if didUpdate, editingReminderID == item.id {
                      editingReminderID = nil
                    }
                    return didUpdate
                  }
                )
              }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .animation(.easeInOut(duration: 0.18), value: visibleReminders.map(\.id))
          }
        }
      }
    }
  }

  private var quickAdd: some View {
    QuickAddReminderView(
      title: $newReminderTitle,
      hasDueDate: $newReminderHasDueDate,
      dueDate: $newReminderDueDate,
      placeholder: quickAddPlaceholder,
      lists: currentSelectedLists,
      activeListID: currentActiveAddList?.id,
      selectList: { store.setActiveAddList($0, for: selectedSection) },
      submit: addReminder
    )
  }

  private var footer: some View {
    HStack(spacing: 10) {
      if isConfirmingQuit {
        Text("앱을 종료할까요?")
          .foregroundStyle(BarRememberPalette.primaryText)

        Spacer()

        Button("계속 사용") {
          handleQuitAction(.cancel)
        }
        .foregroundStyle(BarRememberPalette.secondaryText)
        .accessibilityHint("BarRemember를 종료하지 않고 계속 사용합니다.")

        Button("앱 종료") {
          handleQuitAction(.confirm)
        }
        .foregroundStyle(BarRememberPalette.overdue)
        .accessibilityHint("BarRemember를 완전히 종료합니다.")
      } else {
        Button {
          isShowingListSelection = true
        } label: {
          Label("설정", systemImage: "slider.horizontal.3")
            .foregroundStyle(BarRememberPalette.accent)
        }

        Button {
          store.openReminders()
        } label: {
          Label("Reminders", systemImage: "arrow.up.forward.app")
            .foregroundStyle(BarRememberPalette.accent)
        }

        Spacer()

        Button("종료…") {
          handleQuitAction(.request)
        }
        .foregroundStyle(BarRememberPalette.secondaryText)
        .accessibilityHint("한 번 더 확인한 뒤 BarRemember를 종료합니다.")
      }
    }
    .font(.caption)
    .buttonStyle(.borderless)
    .padding(.horizontal, 16)
    .frame(height: 44)
    .animation(.easeInOut(duration: 0.12), value: isConfirmingQuit)
  }

  private var summaryText: String {
    guard store.authorizationState == .granted else { return "리마인더 연결 필요" }
    if currentSelectedListIDs.isEmpty {
      return "\(selectedSection.title)에 연결할 목록을 선택해주세요"
    }
    return visibleReminders.isEmpty
      ? "\(selectedSection.title)에 남은 항목 없음"
      : "\(selectedSection.title) \(visibleReminders.count)개"
  }

  private var selectedSection: ReminderSection {
    store.section(withID: selectedSectionRawValue) ?? store.sections.first ?? .tasks
  }

  private var sectionBinding: Binding<String> {
    Binding(
      get: { selectedSection.id },
      set: { selectedSectionRawValue = $0 }
    )
  }

  private var currentSelectedListIDs: Set<String> {
    store.selectedListIDs(for: selectedSection)
  }

  private var currentSelectedLists: [ReminderListInfo] {
    store.selectedLists(for: selectedSection)
  }

  private var currentActiveAddList: ReminderListInfo? {
    store.activeAddList(for: selectedSection)
  }

  private var visibleReminders: [ReminderItemSnapshot] {
    store.reminders(for: selectedSection)
  }

  private var quickAddPlaceholder: String {
    selectedSection.isDefault ? "새 할 일 추가" : "새 \(selectedSection.title) 항목 추가"
  }

  private var selectedIconColor: ReminderIconColor {
    ReminderIconColor.resolve(iconColorRawValue)
  }

  private var errorIsPresented: Binding<Bool> {
    Binding(
      get: { store.errorMessage != nil || loginItemController.errorMessage != nil },
      set: { isPresented in
        if !isPresented {
          store.errorMessage = nil
          loginItemController.errorMessage = nil
        }
      }
    )
  }

  private func addReminder() {
    guard let draft = ReminderCreationDraftPolicy.resolve(
      title: newReminderTitle,
      manuallySelectedDueDate: newReminderHasDueDate ? newReminderDueDate : nil
    ) else {
      return
    }
    Task {
      if await store.addReminder(
        title: draft.title,
        dueDate: draft.dueDate,
        in: selectedSection
      ) {
        resetQuickAdd()
      }
    }
  }

  private func resetQuickAdd() {
    newReminderTitle = ""
    newReminderHasDueDate = false
    newReminderDueDate = Date()
  }

  private func handleQuitAction(_ action: QuitConfirmationAction) {
    let decision = QuitConfirmationPolicy.decision(
      for: action,
      isConfirming: isConfirmingQuit
    )
    isConfirmingQuit = decision.isConfirming
    if decision.shouldTerminate {
      NSApplication.shared.terminate(nil)
    }
  }
}

struct QuickAddReminderView: View {
  @Binding var title: String
  @Binding var hasDueDate: Bool
  @Binding var dueDate: Date
  let placeholder: String
  let lists: [ReminderListInfo]
  let activeListID: String?
  let rendersStaticTitlePreview: Bool
  let rendersStaticDatePreview: Bool
  let currentDate: () -> Date
  let selectList: (String) -> Void
  let submit: () -> Void

  init(
    title: Binding<String>,
    hasDueDate: Binding<Bool>,
    dueDate: Binding<Date>,
    placeholder: String,
    lists: [ReminderListInfo] = [],
    activeListID: String? = nil,
    rendersStaticTitlePreview: Bool = false,
    rendersStaticDatePreview: Bool = false,
    currentDate: @escaping () -> Date = Date.init,
    selectList: @escaping (String) -> Void = { _ in },
    submit: @escaping () -> Void
  ) {
    _title = title
    _hasDueDate = hasDueDate
    _dueDate = dueDate
    self.placeholder = placeholder
    self.lists = lists
    self.activeListID = activeListID
    self.rendersStaticTitlePreview = rendersStaticTitlePreview
    self.rendersStaticDatePreview = rendersStaticDatePreview
    self.currentDate = currentDate
    self.selectList = selectList
    self.submit = submit
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: "plus.circle.fill")
          .foregroundStyle(BarRememberPalette.accent)
          .font(.title3)

        if rendersStaticTitlePreview {
          Text(title.isEmpty ? placeholder : title)
            .foregroundStyle(
              title.isEmpty ? BarRememberPalette.mutedText : BarRememberPalette.primaryText
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          TextField(placeholder, text: $title)
            .textFieldStyle(.plain)
            .foregroundStyle(BarRememberPalette.primaryText)
            .tint(BarRememberPalette.accent)
            .onSubmit(submit)
        }

        if lists.count > 1 {
          Menu {
            ForEach(lists) { list in
              Button {
                selectList(list.id)
              } label: {
                if activeListID == list.id {
                  Label(list.title, systemImage: "checkmark")
                } else {
                  Text(list.title)
                }
              }
            }
          } label: {
            Text(activeList?.title ?? "목록")
              .font(.caption)
              .foregroundStyle(BarRememberPalette.secondaryText)
              .lineLimit(1)
          }
          .menuStyle(.borderlessButton)
          .fixedSize()
        }

        Button(action: submit) {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title3)
            .frame(width: 24, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(BarRememberPalette.accent)
        .disabled(ReminderTitlePolicy.normalized(title) == nil)
        .help("항목 추가")
        .accessibilityLabel("새 항목 추가")
      }
      .padding(.horizontal, 12)
      .frame(height: 38)

      Divider()
        .opacity(0.35)
        .padding(.leading, 40)

      Group {
        if let detectedDate {
          DetectedReminderDateControl(detectedDate: detectedDate) {
            dueDate = detectedDate.dueDate
            withAnimation(.easeInOut(duration: 0.12)) {
              hasDueDate = true
            }
          }
        } else {
          OptionalReminderDateControl(
            hasDueDate: $hasDueDate,
            dueDate: $dueDate,
            rendersStaticPreview: rendersStaticDatePreview,
            defaultDate: currentDate
          )
        }
      }
      .padding(.horizontal, 12)
      .frame(height: 32)
    }
    .background(
      BarRememberPalette.controlFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
  }

  private var activeList: ReminderListInfo? {
    lists.first { $0.id == activeListID } ?? lists.first
  }

  private var detectedDate: ParsedReminderDate? {
    guard !hasDueDate else { return nil }
    return ReminderNaturalLanguageDateParser.parse(title, now: currentDate())
  }
}

struct DetectedReminderDateControl: View {
  let detectedDate: ParsedReminderDate
  let selectDate: () -> Void

  var body: some View {
    Button(action: selectDate) {
      HStack(spacing: 7) {
        Image(systemName: "wand.and.stars")
          .foregroundStyle(BarRememberPalette.accent)

        Text("\(detectedDate.matchedText) 감지")
          .foregroundStyle(BarRememberPalette.secondaryText)

        Spacer(minLength: 8)

        Text(
          detectedDate.dueDate.formatted(
            .dateTime.locale(Locale(identifier: "ko_KR")).year().month().day()
          )
        )
        .foregroundStyle(BarRememberPalette.primaryText)

        Image(systemName: "chevron.right")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(BarRememberPalette.mutedText)
      }
      .font(.caption)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("자동 감지된 마감 날짜를 직접 수정")
    .accessibilityLabel(
      "\(detectedDate.dueDate.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).year().month().day())) 마감 날짜 자동 감지됨"
    )
    .accessibilityHint("눌러서 날짜를 직접 수정합니다.")
  }
}

struct OptionalReminderDateControl: View {
  @Binding var hasDueDate: Bool
  @Binding var dueDate: Date
  let rendersStaticPreview: Bool
  let defaultDate: () -> Date

  init(
    hasDueDate: Binding<Bool>,
    dueDate: Binding<Date>,
    rendersStaticPreview: Bool = false,
    defaultDate: @escaping () -> Date = Date.init
  ) {
    _hasDueDate = hasDueDate
    _dueDate = dueDate
    self.rendersStaticPreview = rendersStaticPreview
    self.defaultDate = defaultDate
  }

  var body: some View {
    HStack(spacing: 8) {
      if hasDueDate {
        Label("마감일", systemImage: "calendar")
          .font(.caption)
          .foregroundStyle(BarRememberPalette.secondaryText)

        Spacer(minLength: 8)

        if rendersStaticPreview {
          Text(
            dueDate.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).year().month().day())
          )
          .font(.caption)
          .foregroundStyle(BarRememberPalette.primaryText)
        } else {
          DatePicker(
            "마감 날짜",
            selection: $dueDate,
            displayedComponents: .date
          )
          .labelsHidden()
          .datePickerStyle(.field)
          .controlSize(.small)
          .environment(\.locale, Locale(identifier: "ko_KR"))
        }

        if rendersStaticPreview {
          Image(systemName: "xmark.circle.fill")
            .frame(width: 24, height: 26)
            .foregroundStyle(BarRememberPalette.mutedText)
        } else {
          Button {
            withAnimation(.easeInOut(duration: 0.12)) {
              hasDueDate = false
            }
          } label: {
            Image(systemName: "xmark.circle.fill")
              .frame(width: 24, height: 26)
              .contentShape(Rectangle())
          }
          .buttonStyle(.borderless)
          .controlSize(.small)
          .foregroundStyle(BarRememberPalette.mutedText)
          .help("날짜 제거")
          .accessibilityLabel("마감 날짜 제거")
        }
      } else {
        Button {
          dueDate = defaultDate()
          withAnimation(.easeInOut(duration: 0.12)) {
            hasDueDate = true
          }
        } label: {
          Label("날짜 추가", systemImage: "calendar.badge.plus")
            .font(.caption)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .foregroundStyle(BarRememberPalette.secondaryText)
        .help("새 항목에 마감 날짜 추가")
        .accessibilityLabel("마감 날짜 추가")

        Spacer()
      }
    }
  }
}

struct ReminderSectionPicker: View {
  let sections: [ReminderSection]
  @Binding var selection: String
  let rendersStaticPreview: Bool
  let countForSection: (ReminderSection) -> Int
  let addSection: () -> Void

  init(
    sections: [ReminderSection],
    selection: Binding<String>,
    rendersStaticPreview: Bool = false,
    countForSection: @escaping (ReminderSection) -> Int,
    addSection: @escaping () -> Void
  ) {
    self.sections = sections
    _selection = selection
    self.rendersStaticPreview = rendersStaticPreview
    self.countForSection = countForSection
    self.addSection = addSection
  }

  var body: some View {
    HStack(spacing: 7) {
      sectionSelector

      Button(action: addSection) {
        Image(systemName: "plus")
          .font(.system(size: 13, weight: .semibold))
          .frame(width: 34, height: 34)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(BarRememberPalette.accent)
      .background(
        Color.primary.opacity(0.07),
        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )
      .help("새 공간 추가")
      .accessibilityLabel("새 공간 추가")
    }
  }

  @ViewBuilder
  private var sectionSelector: some View {
    if rendersStaticPreview {
      HStack(spacing: 6) {
        ForEach(sections) { section in
          sectionButton(section)
        }
      }
    } else {
      ScrollViewReader { proxy in
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(sections) { section in
              sectionButton(section)
                .id(section.id)
            }
          }
        }
        .scrollIndicators(.hidden)
        .frame(height: 36)
        .onAppear {
          proxy.scrollTo(selection, anchor: .center)
        }
        .onChange(of: selection) { _, selectedID in
          withAnimation(.easeInOut(duration: 0.16)) {
            proxy.scrollTo(selectedID, anchor: .center)
          }
        }
      }
    }
  }

  private func sectionButton(_ section: ReminderSection) -> some View {
    let isSelected = selection == section.id

    return Button {
      withAnimation(.easeInOut(duration: 0.12)) {
        selection = section.id
      }
    } label: {
      HStack(spacing: 6) {
        Text(section.title)
          .font(.callout.weight(isSelected ? .semibold : .medium))
          .foregroundStyle(
            isSelected ? BarRememberPalette.primaryText : BarRememberPalette.secondaryText
          )
          .lineLimit(1)
        Text("\(countForSection(section))")
          .font(.caption.monospacedDigit())
          .foregroundStyle(isSelected ? BarRememberPalette.accent : BarRememberPalette.mutedText)
      }
      .padding(.horizontal, 13)
      .frame(height: 34)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      isSelected ? BarRememberPalette.accent.opacity(0.14) : BarRememberPalette.controlFill,
      in: RoundedRectangle(cornerRadius: 10, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(
          isSelected ? BarRememberPalette.accent.opacity(0.38) : Color.clear,
          lineWidth: 1
        )
    }
    .fixedSize(horizontal: true, vertical: false)
    .help("\(section.title) 공간으로 전환")
    .accessibilityLabel("\(section.title), \(countForSection(section))개")
    .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
  }

}

struct ReminderRow: View {
  let item: ReminderItemSnapshot
  let isCompleting: Bool
  let iconColor: Color
  let itemKindLabel: String
  let completionActionTitle: String
  let allowsDragging: Bool
  let automaticallyFocusEditor: Bool
  let rendersStaticEditorPreview: Bool
  let interactionsDisabled: Bool
  let isEditing: Bool
  let isSavingChanges: Bool
  let onComplete: () -> Void
  let onMove: (ReminderItemSnapshot.ID) -> Bool
  let onMoveUp: () -> Void
  let onMoveDown: () -> Void
  let onBeginEditing: () -> Void
  let onCancelEditing: () -> Void
  let onSaveChanges: (String, ReminderDueDateUpdate) async -> Bool

  @State private var isDropTarget = false
  @State private var titleDraft: String
  @State private var hasDueDateDraft: Bool
  @State private var dueDateDraft: Date
  @FocusState private var isTitleFieldFocused: Bool

  init(
    item: ReminderItemSnapshot,
    isCompleting: Bool,
    iconColor: Color,
    itemKindLabel: String = "할 일",
    completionActionTitle: String = "완료",
    allowsDragging: Bool = true,
    automaticallyFocusEditor: Bool = true,
    rendersStaticEditorPreview: Bool = false,
    interactionsDisabled: Bool = false,
    isEditing: Bool = false,
    isSavingChanges: Bool = false,
    onComplete: @escaping () -> Void,
    onMove: @escaping (ReminderItemSnapshot.ID) -> Bool,
    onMoveUp: @escaping () -> Void,
    onMoveDown: @escaping () -> Void,
    onBeginEditing: @escaping () -> Void = {},
    onCancelEditing: @escaping () -> Void = {},
    onSaveChanges: @escaping (String, ReminderDueDateUpdate) async -> Bool = { _, _ in false }
  ) {
    self.item = item
    self.isCompleting = isCompleting
    self.iconColor = iconColor
    self.itemKindLabel = itemKindLabel
    self.completionActionTitle = completionActionTitle
    self.allowsDragging = allowsDragging
    self.automaticallyFocusEditor = automaticallyFocusEditor
    self.rendersStaticEditorPreview = rendersStaticEditorPreview
    self.interactionsDisabled = interactionsDisabled
    self.isEditing = isEditing
    self.isSavingChanges = isSavingChanges
    self.onComplete = onComplete
    self.onMove = onMove
    self.onMoveUp = onMoveUp
    self.onMoveDown = onMoveDown
    self.onBeginEditing = onBeginEditing
    self.onCancelEditing = onCancelEditing
    self.onSaveChanges = onSaveChanges
    _titleDraft = State(initialValue: item.title)
    _hasDueDateDraft = State(initialValue: item.dueDate != nil)
    _dueDateDraft = State(initialValue: item.dueDate ?? Date())
  }

  var body: some View {
    Group {
      if dragIsEnabled {
        rowContent
          .dropDestination(for: String.self) { reminderIDs, _ in
            guard let sourceID = reminderIDs.first, sourceID != item.id else { return false }
            return onMove(sourceID)
          } isTargeted: { isTargeted in
            isDropTarget = isTargeted
          }
      } else {
        rowContent
      }
    }
    .onChange(of: isEditing) { _, isNowEditing in
      if isNowEditing {
        resetDrafts()
        if automaticallyFocusEditor {
          Task { @MainActor in
            isTitleFieldFocused = true
          }
        }
      } else {
        isTitleFieldFocused = false
      }
    }
    .onChange(of: item.title) { _, newTitle in
      if !isEditing {
        titleDraft = newTitle
      }
    }
    .onChange(of: item.dueDate) { _, newDueDate in
      if !isEditing {
        hasDueDateDraft = newDueDate != nil
        dueDateDraft = newDueDate ?? Date()
      }
    }
    .onAppear {
      if isEditing && automaticallyFocusEditor {
        isTitleFieldFocused = true
      }
    }
  }

  private var rowContent: some View {
    HStack(alignment: .top, spacing: 10) {
      Button(action: onComplete) {
        ZStack {
          Circle()
            .stroke(iconColor, lineWidth: 1.7)
            .frame(width: 20, height: 20)
          if isCompleting {
            Image(systemName: "checkmark")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(iconColor)
          }
        }
        .frame(width: 30, height: 30)
        .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(isCompleting || interactionsDisabled)
      .help("\(completionActionTitle)로 표시")
      .accessibilityLabel("\(completionActionTitle): \(item.title)")
      .accessibilityHint("누르면 완료 처리 후 목록에서 사라집니다.")

      VStack(alignment: .leading, spacing: 5) {
        titleContent

        if isEditing {
          OptionalReminderDateControl(
            hasDueDate: $hasDueDateDraft,
            dueDate: $dueDateDraft,
            rendersStaticPreview: rendersStaticEditorPreview
          )
          .frame(height: 28)
        } else if let dueDate = item.dueDate {
          Label(dueLabel(dueDate), systemImage: "calendar")
            .font(.caption2)
            .foregroundStyle(dueColor(dueDate))
            .lineLimit(1)
        }
      }

      rowActions
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 10)
    .background(
      isDropTarget ? BarRememberPalette.accent.opacity(0.09) : Color.clear,
      in: RoundedRectangle(cornerRadius: 10, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(
          isDropTarget ? BarRememberPalette.accent.opacity(0.7) : Color.clear,
          lineWidth: 1.3
        )
    }
    .overlay(alignment: .bottom) {
      if !isDropTarget {
        Rectangle()
          .fill(Color(nsColor: .separatorColor).opacity(0.72))
          .frame(height: 0.5)
          .padding(.leading, 48)
      }
    }
    .contentShape(Rectangle())
    .animation(.easeInOut(duration: 0.12), value: isDropTarget)
  }

  @ViewBuilder
  private var titleContent: some View {
    if isEditing {
      if rendersStaticEditorPreview {
        Text(titleDraft)
          .font(.system(size: 13.5, weight: .medium))
          .foregroundStyle(BarRememberPalette.primaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 6)
          .frame(height: 22)
          .background(.background, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .stroke(Color.primary.opacity(0.16), lineWidth: 1)
          }
      } else {
        TextField("\(itemKindLabel) 제목", text: $titleDraft)
          .textFieldStyle(.roundedBorder)
          .controlSize(.small)
          .font(.system(size: 13.5, weight: .medium))
          .foregroundStyle(BarRememberPalette.primaryText)
          .tint(BarRememberPalette.accent)
          .focused($isTitleFieldFocused)
          .disabled(isSavingChanges)
          .onSubmit(saveChanges)
          .onExitCommand(perform: cancelEditing)
          .accessibilityLabel("\(itemKindLabel) 제목 수정")
      }
    } else {
      Text(item.title)
        .font(.system(size: 13.5, weight: .medium))
        .foregroundStyle(BarRememberPalette.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: beginEditing)
        .help("더블 클릭하여 수정")
    }
  }

  @ViewBuilder
  private var rowActions: some View {
    if isEditing {
      HStack(spacing: 0) {
        Button(action: cancelEditing) {
          Image(systemName: "xmark")
            .frame(width: 24, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(BarRememberPalette.secondaryText)
        .disabled(isSavingChanges)
        .help("수정 취소 (Esc)")
        .accessibilityLabel("수정 취소")

        Button(action: saveChanges) {
          Group {
            if isSavingChanges {
              ProgressView()
                .controlSize(.mini)
            } else {
              Image(systemName: "checkmark")
            }
          }
          .frame(width: 24, height: 30)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(BarRememberPalette.accent)
        .disabled(normalizedTitleDraft == nil || isSavingChanges)
        .help("수정 저장 (Enter)")
        .accessibilityLabel(isSavingChanges ? "수정 저장 중" : "수정 저장")
      }
    } else {
      HStack(spacing: 0) {
        Button(action: beginEditing) {
          Image(systemName: "pencil")
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 24, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(BarRememberPalette.mutedText)
        .disabled(interactionsDisabled)
        .help("\(itemKindLabel) 수정")
        .accessibilityLabel("수정: \(item.title)")

        dragHandle
      }
    }
  }

  private var dragHandle: some View {
    Group {
      if dragIsEnabled {
        dragHandleImage.draggable(item.id)
      } else {
        dragHandleImage
      }
    }
    .help("드래그하여 순서 변경")
    .accessibilityElement()
    .accessibilityLabel("순서 변경: \(item.title)")
    .accessibilityHint("드래그하거나 위로 이동 또는 아래로 이동 동작을 사용합니다.")
    .accessibilityAction(named: Text("위로 이동")) {
      guard dragIsEnabled else { return }
      onMoveUp()
    }
    .accessibilityAction(named: Text("아래로 이동")) {
      guard dragIsEnabled else { return }
      onMoveDown()
    }
  }

  private var dragIsEnabled: Bool {
    allowsDragging && !interactionsDisabled && !isEditing && !isSavingChanges
  }

  private var normalizedTitleDraft: String? {
    ReminderTitlePolicy.normalized(titleDraft)
  }

  private func beginEditing() {
    guard !interactionsDisabled else { return }
    resetDrafts()
    onBeginEditing()
  }

  private func cancelEditing() {
    guard !isSavingChanges else { return }
    resetDrafts()
    onCancelEditing()
  }

  private func saveChanges() {
    guard normalizedTitleDraft != nil, !isSavingChanges else { return }
    let dueDateUpdate = ReminderDueDatePolicy.update(
      originalDate: item.dueDate,
      hasDraftDate: hasDueDateDraft,
      draftDate: dueDateDraft
    )
    Task {
      _ = await onSaveChanges(titleDraft, dueDateUpdate)
    }
  }

  private func resetDrafts() {
    titleDraft = item.title
    hasDueDateDraft = item.dueDate != nil
    dueDateDraft = item.dueDate ?? Date()
  }

  private var dragHandleImage: some View {
    Image(systemName: "line.3.horizontal")
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(
        isDropTarget ? BarRememberPalette.accent : BarRememberPalette.mutedText
      )
      .frame(width: 24, height: 30)
      .contentShape(Rectangle())
  }

  private func dueLabel(_ date: Date) -> String {
    let calendar = Calendar.current
    let time = date.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).hour().minute())
    if calendar.isDateInToday(date) {
      return item.hasTime ? "오늘 \(time)" : "오늘"
    }
    if calendar.isDateInTomorrow(date) {
      return item.hasTime ? "내일 \(time)" : "내일"
    }
    let day = date.formatted(.dateTime.locale(Locale(identifier: "ko_KR")).month().day())
    return item.hasTime ? "\(day) \(time)" : day
  }

  private func dueColor(_ date: Date) -> Color {
    switch ReminderDateKind.classify(date, hasTime: item.hasTime) {
    case .overdue: BarRememberPalette.overdue
    case .today: BarRememberPalette.today
    case .upcoming: BarRememberPalette.secondaryText
    }
  }
}

struct UndoCompletionBanner: View {
  let itemTitle: String
  let isUndoing: Bool
  let onUndo: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.title3)
        .foregroundStyle(BarRememberPalette.positive)

      VStack(alignment: .leading, spacing: 2) {
        Text("완료했어요")
          .font(.caption.weight(.semibold))
          .foregroundStyle(BarRememberPalette.primaryText)
        Text(itemTitle)
          .font(.caption2)
          .foregroundStyle(BarRememberPalette.secondaryText)
          .lineLimit(1)
      }

      Spacer(minLength: 6)

      Button(action: onUndo) {
        HStack(spacing: 5) {
          if isUndoing {
            ProgressView()
              .controlSize(.mini)
          }
          Text(isUndoing ? "복구 중…" : "되돌리기")
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .tint(BarRememberPalette.accent)
      .disabled(isUndoing)
      .keyboardShortcut("z", modifiers: .command)
      .accessibilityHint("방금 완료한 할 일을 다시 목록에 표시합니다.")
    }
    .padding(.horizontal, 12)
    .frame(height: 52)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 11, style: .continuous)
        .stroke(BarRememberPalette.accent.opacity(0.22), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    .accessibilityElement(children: .contain)
  }
}

private struct PermissionView: View {
  let isRequesting: Bool
  let requestAccess: () -> Void

  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: "checklist")
        .font(.system(size: 36, weight: .light))
        .foregroundStyle(BarRememberPalette.accent)
      Text("리마인더를 메뉴 막대로")
        .font(.headline)
        .foregroundStyle(BarRememberPalette.primaryText)
      Text("선택한 목록만 모아보고, 이 창에서 바로 완료하거나 새 할 일을 추가할 수 있습니다.")
        .multilineTextAlignment(.center)
        .font(.callout)
        .foregroundStyle(BarRememberPalette.secondaryText)
        .frame(maxWidth: 285)
      Button(isRequesting ? "연결 중…" : "리마인더 연결") {
        requestAccess()
      }
      .buttonStyle(.borderedProminent)
      .disabled(isRequesting)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(30)
  }
}

private struct PermissionDeniedView: View {
  let openSettings: () -> Void

  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: "lock.shield")
        .font(.system(size: 34, weight: .light))
        .foregroundStyle(BarRememberPalette.mutedText)
      Text("리마인더 접근이 꺼져 있습니다")
        .font(.headline)
        .foregroundStyle(BarRememberPalette.primaryText)
      Text("시스템 설정의 개인정보 보호 및 보안에서 BarRemember의 리마인더 접근을 허용해주세요.")
        .multilineTextAlignment(.center)
        .font(.callout)
        .foregroundStyle(BarRememberPalette.secondaryText)
        .frame(maxWidth: 290)
      Button("시스템 설정 열기", action: openSettings)
        .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(30)
  }
}

private struct EmptySelectionView: View {
  let section: ReminderSection
  let createReminderList: () async -> Bool
  let chooseLists: () -> Void
  @State private var isCreatingList = false

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "folder.badge.plus")
        .font(.system(size: 32, weight: .light))
        .foregroundStyle(BarRememberPalette.mutedText)
      Text("\(section.title)에 연결된 목록이 없어요")
        .font(.headline)
        .foregroundStyle(BarRememberPalette.primaryText)
      Text("같은 이름의 Reminders 목록을 만들거나 기존 목록을 연결할 수 있습니다.")
        .font(.callout)
        .foregroundStyle(BarRememberPalette.secondaryText)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 280)

      Button {
        isCreatingList = true
        Task {
          _ = await createReminderList()
          isCreatingList = false
        }
      } label: {
        if isCreatingList {
          HStack(spacing: 6) {
            ProgressView()
              .controlSize(.small)
            Text("목록 만드는 중…")
          }
        } else {
          Text("\(section.title) 목록 만들기")
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(isCreatingList)

      Button("기존 목록 연결", action: chooseLists)
        .buttonStyle(.borderless)
        .foregroundStyle(BarRememberPalette.accent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(30)
  }
}

private struct EmptyRemindersView: View {
  let section: ReminderSection

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 34, weight: .light))
        .foregroundStyle(BarRememberPalette.positive)
      Text("\(section.title)에 남은 항목이 없어요")
        .font(.headline)
        .foregroundStyle(BarRememberPalette.primaryText)
      Text("위 입력창에서 새 항목을 바로 추가할 수 있습니다.")
        .font(.caption)
        .foregroundStyle(BarRememberPalette.secondaryText)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct ListSelectionView: View {
  @EnvironmentObject private var store: ReminderStore
  @EnvironmentObject private var loginItemController: LoginItemController
  @Binding var isPresented: Bool
  @Binding var iconColorRawValue: String
  @Binding var themeRawValue: String
  @State private var isShowingAddSection = false
  @State private var newSectionTitle = ""
  @State private var sectionBeingRenamed: ReminderSection?
  @State private var renamedSectionTitle = ""
  @State private var sectionPendingDeletion: ReminderSection?

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button {
          isPresented = false
        } label: {
          Label("뒤로", systemImage: "chevron.left")
            .foregroundStyle(BarRememberPalette.accent)
        }
        .buttonStyle(.borderless)

        Spacer()
        Text("설정")
          .font(.headline)
          .foregroundStyle(BarRememberPalette.primaryText)
        Spacer()

        Button("완료") {
          isPresented = false
        }
        .foregroundStyle(BarRememberPalette.accent)
        .buttonStyle(.borderless)
      }
      .padding(.horizontal, 16)
      .frame(height: 52)

      Divider().opacity(0.55)

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            Text("공간")
              .font(.caption)
              .foregroundStyle(BarRememberPalette.secondaryText)

            ForEach(store.sections) { section in
              HStack(spacing: 9) {
                Image(systemName: section.isDefault ? "checklist" : "folder")
                  .foregroundStyle(BarRememberPalette.accent)
                  .frame(width: 16)
                Text(section.title)
                  .foregroundStyle(BarRememberPalette.primaryText)
                  .lineLimit(1)
                if section.isDefault {
                  Text("기본")
                    .font(.caption2)
                    .foregroundStyle(BarRememberPalette.mutedText)
                }
                Spacer(minLength: 8)

                Button {
                  sectionBeingRenamed = section
                  renamedSectionTitle = section.title
                } label: {
                  Image(systemName: "pencil")
                    .frame(width: 24, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BarRememberPalette.secondaryText)
                .help("공간 이름 변경")
                .accessibilityLabel("\(section.title) 이름 변경")

                if !section.isDefault {
                  Button {
                    sectionPendingDeletion = section
                  } label: {
                    Image(systemName: "trash")
                      .frame(width: 24, height: 26)
                  }
                  .buttonStyle(.plain)
                  .foregroundStyle(BarRememberPalette.overdue)
                  .help("공간 삭제")
                  .accessibilityLabel("\(section.title) 공간 삭제")
                }
              }
              .padding(.horizontal, 12)
              .frame(height: 36)
              .background(
                BarRememberPalette.controlFill,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
              )
            }

            Button {
              isShowingAddSection = true
            } label: {
              Label("새 공간 추가", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(BarRememberPalette.accent)
          }

          Divider()

          VStack(alignment: .leading, spacing: 8) {
            Text("Reminders 목록 연결")
              .font(.caption)
              .foregroundStyle(BarRememberPalette.secondaryText)

            ForEach(store.lists) { list in
              HStack(spacing: 10) {
                Circle()
                  .fill(color(for: list.tint))
                  .frame(width: 10, height: 10)
                Text(list.title)
                  .foregroundStyle(BarRememberPalette.primaryText)
                  .lineLimit(1)
                Spacer(minLength: 8)

                Picker("\(list.title) 표시 위치", selection: destinationBinding(for: list.id)) {
                  Text("숨김")
                    .tag(String?.none)
                  ForEach(store.sections) { section in
                    Text(section.title)
                      .tag(Optional(section.id))
                  }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
                .accessibilityLabel("\(list.title) 표시 위치")
              }
              .padding(.horizontal, 12)
              .frame(height: 36)
              .background(
                BarRememberPalette.controlFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            Text("각 목록은 한 공간에만 표시됩니다.")
              .font(.caption2)
              .foregroundStyle(BarRememberPalette.mutedText)
          }

          Divider()

          VStack(alignment: .leading, spacing: 9) {
            Text("앱 테마")
              .font(.caption)
              .foregroundStyle(BarRememberPalette.secondaryText)
            ThemePicker(selection: $themeRawValue)
              Text("Glass와 미드나이트는 반투명 material 위에 색을 더합니다.")
              .font(.caption2)
              .foregroundStyle(BarRememberPalette.mutedText)
          }

          Divider()

          VStack(alignment: .leading, spacing: 8) {
            Text("아이콘 색상")
              .font(.caption)
              .foregroundStyle(BarRememberPalette.secondaryText)
            IconColorPicker(selection: $iconColorRawValue)
            Text("완료 원에 적용됩니다.")
              .font(.caption2)
              .foregroundStyle(BarRememberPalette.mutedText)
          }

          Divider()

          VStack(alignment: .leading, spacing: 10) {
            Text("앱")
              .font(.caption)
              .foregroundStyle(BarRememberPalette.secondaryText)
            Toggle("로그인 시 자동 실행", isOn: loginItemBinding)
              .toggleStyle(.switch)
              .foregroundStyle(BarRememberPalette.primaryText)
            if loginItemController.state == .requiresApproval {
              Label("시스템 설정에서 승인이 필요합니다", systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(BarRememberPalette.today)
            }
            if loginItemController.state == .requiresApproval
              || loginItemController.errorMessage != nil
            {
              Button("로그인 항목 설정 열기") {
                loginItemController.openSystemSettings()
              }
              .font(.caption)
              .foregroundStyle(BarRememberPalette.accent)
            }
          }
        }
        .padding(16)
      }

      Divider().opacity(0.55)
      Text("각 Reminders 목록은 한 공간에만 연결됩니다.")
        .font(.caption2)
        .foregroundStyle(BarRememberPalette.mutedText)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
    }
    .alert("새 공간 추가", isPresented: $isShowingAddSection) {
      TextField("공간 이름", text: $newSectionTitle)
      Button("취소", role: .cancel) {
        newSectionTitle = ""
      }
      Button("추가") {
        if store.addSection(title: newSectionTitle) != nil {
          newSectionTitle = ""
        }
      }
    } message: {
      Text("예: 공부, 장보기, 지원 공고")
    }
    .alert("공간 이름 변경", isPresented: renameIsPresented) {
      TextField("공간 이름", text: $renamedSectionTitle)
      Button("취소", role: .cancel) {
        sectionBeingRenamed = nil
        renamedSectionTitle = ""
      }
      Button("저장") {
        if let sectionBeingRenamed,
          store.renameSection(sectionBeingRenamed.id, title: renamedSectionTitle)
        {
          self.sectionBeingRenamed = nil
          renamedSectionTitle = ""
        }
      }
    } message: {
      Text("연결된 Reminders 목록 이름은 바뀌지 않습니다.")
    }
    .alert("공간을 삭제할까요?", isPresented: deletionIsPresented) {
      Button("취소", role: .cancel) {
        sectionPendingDeletion = nil
      }
      Button("삭제", role: .destructive) {
        if let sectionPendingDeletion {
          _ = store.deleteSection(sectionPendingDeletion.id)
        }
        self.sectionPendingDeletion = nil
      }
    } message: {
      Text("Reminders 목록과 항목은 삭제되지 않고 BarRemember 연결만 해제됩니다.")
    }
  }

  private func destinationBinding(for listID: String) -> Binding<String?> {
    Binding(
      get: { store.assignedSectionID(for: listID) },
      set: { store.setList(listID, sectionID: $0) }
    )
  }

  private var renameIsPresented: Binding<Bool> {
    Binding(
      get: { sectionBeingRenamed != nil },
      set: { isPresented in
        if !isPresented {
          sectionBeingRenamed = nil
          renamedSectionTitle = ""
        }
      }
    )
  }

  private var deletionIsPresented: Binding<Bool> {
    Binding(
      get: { sectionPendingDeletion != nil },
      set: { isPresented in
        if !isPresented {
          sectionPendingDeletion = nil
        }
      }
    )
  }

  private var loginItemBinding: Binding<Bool> {
    Binding(
      get: { loginItemController.state == .enabled },
      set: { loginItemController.setEnabled($0) }
    )
  }

  private func color(for tint: ListTint) -> Color {
    Color(red: tint.red, green: tint.green, blue: tint.blue, opacity: tint.opacity)
  }
}

struct IconColorPicker: View {
  @Binding var selection: String

  var body: some View {
    HStack(spacing: 8) {
      ForEach(ReminderIconColor.allCases) { colorChoice in
        let isSelected = colorChoice.rawValue == selection

        Button {
          selection = colorChoice.rawValue
        } label: {
          ZStack {
            Circle()
              .fill(colorChoice.color)
              .frame(width: 24, height: 24)

            if isSelected {
              Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
            }

            Circle()
              .strokeBorder(
                isSelected ? BarRememberPalette.primaryText.opacity(0.7) : .clear,
                lineWidth: 1.5
              )
              .frame(width: 31, height: 31)
          }
          .frame(width: 36, height: 36)
          .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(colorChoice.title)
        .accessibilityLabel(colorChoice.title)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
      }
    }
  }
}

struct ThemePicker: View {
  @Binding var selection: String

  var body: some View {
    HStack(spacing: 8) {
      ForEach(BarRememberTheme.allCases) { theme in
        let isSelected = theme == BarRememberTheme.resolve(selection)

        Button {
          selection = theme.rawValue
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Circle()
              .fill(theme.swatch)
              .frame(width: 18, height: 18)
              .overlay {
                if isSelected {
                  Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                }
              }
            Text(theme.title)
              .font(.caption2.weight(isSelected ? .semibold : .regular))
              .foregroundStyle(
                isSelected ? BarRememberPalette.primaryText : BarRememberPalette.secondaryText
              )
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
          .background(
            isSelected ? BarRememberPalette.accent.opacity(0.14) : BarRememberPalette.controlFill,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
              .stroke(
                isSelected ? BarRememberPalette.accent.opacity(0.5) : .clear,
                lineWidth: 1
              )
          }
        }
        .buttonStyle(.plain)
        .help("\(theme.title): \(theme.description)")
        .accessibilityLabel(theme.title)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
      }
    }
  }
}
