import XCTest
import AppKit
import SwiftUI
@testable import NewsDaily

@MainActor
final class MacTextFieldTests: XCTestCase {
    func testTextFieldChangeUpdatesBinding() {
        var value = "deepseek-chat"
        let binding = Binding<String>(
            get: { value },
            set: { value = $0 }
        )
        let view = MacTextField(placeholder: "Model ID", text: binding)
        let coordinator = MacTextField.Coordinator(view)
        let field = EditableNSTextField()

        field.stringValue = "deepseek-reasoner"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))

        XCTAssertEqual(value, "deepseek-reasoner")
    }

    func testTextFieldCommitUpdatesBinding() {
        var value = "glm-4-flash"
        let binding = Binding<String>(
            get: { value },
            set: { value = $0 }
        )
        let view = MacTextField(placeholder: "Model ID", text: binding)
        let coordinator = MacTextField.Coordinator(view)
        let field = EditableNSTextField()

        field.stringValue = "glm-4-plus"
        coordinator.commit(field)

        XCTAssertEqual(value, "glm-4-plus")
    }

    func testTextFieldEndEditingUpdatesBinding() {
        var value = "mimo-7b"
        let binding = Binding<String>(
            get: { value },
            set: { value = $0 }
        )
        let view = MacTextField(placeholder: "Model ID", text: binding)
        let coordinator = MacTextField.Coordinator(view)
        let field = EditableNSTextField()

        field.stringValue = "mimo-latest"
        coordinator.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))

        XCTAssertEqual(value, "mimo-latest")
    }

    func testProviderFormModelIDAndAPIKeyFieldsAcceptKeyboardInsertion() {
        let provider = AIProviderConfig(
            displayName: "小米 MiMo",
            kindRawValue: AIProviderKind.openAICompatibleChat.rawValue,
            baseURLString: "https://mimo.xiaomi.com/api/v1",
            modelID: "mimo-7b",
            apiKey: "test-api-key-existing"
        )
        let root = AIProviderFormView(provider: provider) { _ in }
        let host = NSHostingView(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        defer { close(window) }
        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()

        let fields = findSubviews(of: host, type: NSTextField.self)
        guard let modelIDField = fields.first(where: { $0.placeholderString == "Model ID" }) else {
            XCTFail("Expected AIProviderFormView to contain a Model ID text field")
            return
        }

        XCTAssertTrue(modelIDField.isEnabled)
        XCTAssertTrue(modelIDField.isEditable)
        XCTAssertTrue(modelIDField.isSelectable)
        XCTAssertTrue(window.makeFirstResponder(modelIDField))

        guard let editor = modelIDField.currentEditor() else {
            XCTFail("Expected Model ID field to install a field editor")
            return
        }

        (editor as? NSTextView)?.setSelectedRange(NSRange(location: 0, length: editor.string.count))
        editor.insertText("mimo-latest")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(modelIDField.stringValue, "mimo-latest")

        guard let apiKeyField = fields.first(where: { $0.placeholderString == "API Key" }) else {
            XCTFail("Expected AIProviderFormView to contain an API Key text field")
            return
        }

        XCTAssertFalse(apiKeyField is NSSecureTextField)
        XCTAssertTrue(apiKeyField.isEnabled)
        XCTAssertTrue(apiKeyField.isEditable)
        XCTAssertTrue(apiKeyField.isSelectable)
        XCTAssertTrue(window.makeFirstResponder(apiKeyField))

        guard let editor = apiKeyField.currentEditor() else {
            XCTFail("Expected API Key field to install a field editor")
            return
        }

        (editor as? NSTextView)?.setSelectedRange(NSRange(location: 0, length: editor.string.count))
        editor.insertText("test-api-key-local")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(apiKeyField.stringValue, "test-api-key-local")
    }

    func testSecureFieldChangeUpdatesBinding() {
        var value = ""
        let binding = Binding<String>(
            get: { value },
            set: { value = $0 }
        )
        let view = MacSecureField(placeholder: "API Key", text: binding)
        let coordinator = MacSecureField.Coordinator(view)
        let field = EditableNSSecureTextField()

        field.stringValue = "test-api-key"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))

        XCTAssertEqual(value, "test-api-key")
    }

    func testSearchFieldChangeUpdatesBinding() {
        var value = ""
        let binding = Binding<String>(
            get: { value },
            set: { value = $0 }
        )
        let view = MacSearchField(placeholder: "搜索", text: binding)
        let coordinator = MacSearchField.Coordinator(view)
        let field = NSSearchField()

        field.stringValue = "bbc"
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))

        XCTAssertEqual(value, "bbc")
    }

    private func findSubview<T: NSView>(of view: NSView, type: T.Type) -> T? {
        if let typed = view as? T { return typed }
        for subview in view.subviews {
            if let found = findSubview(of: subview, type: type) {
                return found
            }
        }
        return nil
    }

    private func findSubviews<T: NSView>(of view: NSView, type: T.Type) -> [T] {
        var result: [T] = []
        if let typed = view as? T { result.append(typed) }
        for subview in view.subviews {
            result.append(contentsOf: findSubviews(of: subview, type: type))
        }
        return result
    }

    private func close(_ window: NSWindow) {
        window.makeFirstResponder(nil)
        window.orderOut(nil)
        window.contentView = nil
        window.close()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}
