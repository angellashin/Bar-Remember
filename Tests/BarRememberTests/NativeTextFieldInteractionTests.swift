import AppKit
import Combine
import SwiftUI
import Testing

@testable import BarRemember

@MainActor
struct NativeTextFieldInteractionTests {
  @Test func swiftUITextFieldAcceptsPasteFromTheSystemPasteboard() throws {
    let model = TitleEditorHarnessModel()
    let host = NSHostingController(rootView: TitleEditorHarness(model: model))
    let window = NSWindow(
      contentRect: NSRect(x: -10_000, y: -10_000, width: 280, height: 48),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.contentViewController = host
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }

    let pasteboard = NSPasteboard.general
    let originalItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
      let copy = NSPasteboardItem()
      for type in item.types {
        if let data = item.data(forType: type) {
          copy.setData(data, forType: type)
        }
      }
      return copy.types.isEmpty ? nil : copy
    } ?? []
    defer {
      pasteboard.clearContents()
      if !originalItems.isEmpty {
        pasteboard.writeObjects(originalItems)
      }
    }

    pasteboard.clearContents()
    pasteboard.setString("Pasted from clipboard", forType: .string)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    let field = try #require(firstTextField(in: host.view))
    window.makeFirstResponder(field)
    let editor = try #require(field.currentEditor() as? NSTextView)
    editor.selectAll(nil)
    editor.paste(nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))

    #expect(model.title == "Pasted from clipboard")
  }

  @Test func swiftUITextFieldAcceptsReplacementDeletionAndKoreanComposition() throws {
    let model = TitleEditorHarnessModel()
    let host = NSHostingController(rootView: TitleEditorHarness(model: model))
    let window = NSWindow(
      contentRect: NSRect(x: -10_000, y: -10_000, width: 280, height: 48),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.contentViewController = host
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }

    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    let field = try #require(firstTextField(in: host.view))
    window.makeFirstResponder(field)
    let editor = try #require(field.currentEditor() as? NSTextView)

    editor.selectAll(nil)
    editor.insertText(
      "Edited title",
      replacementRange: NSRange(location: 0, length: editor.string.utf16.count)
    )
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    #expect(model.title == "Edited title")

    editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
    editor.deleteBackward(nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    #expect(model.title == "Edited titl")

    editor.setMarkedText(
      "한",
      selectedRange: NSRange(location: 1, length: 0),
      replacementRange: NSRange(location: editor.string.utf16.count, length: 0)
    )
    #expect(editor.hasMarkedText())
    editor.unmarkText()
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    #expect(model.title == "Edited titl한")

    editor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    #expect(model.submitCount == 1)

    editor.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    #expect(model.cancelCount == 1)
  }

  private func firstTextField(in view: NSView) -> NSTextField? {
    if let textField = view as? NSTextField {
      return textField
    }
    for child in view.subviews {
      if let textField = firstTextField(in: child) {
        return textField
      }
    }
    return nil
  }
}

@MainActor
private final class TitleEditorHarnessModel: ObservableObject {
  @Published var title = "Original title"
  @Published var submitCount = 0
  @Published var cancelCount = 0
}

private struct TitleEditorHarness: View {
  @ObservedObject var model: TitleEditorHarnessModel

  var body: some View {
    TextField("할 일 제목", text: $model.title)
      .textFieldStyle(.roundedBorder)
      .onSubmit { model.submitCount += 1 }
      .onExitCommand { model.cancelCount += 1 }
      .padding(8)
  }
}
