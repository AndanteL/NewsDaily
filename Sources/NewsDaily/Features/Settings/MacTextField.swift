import SwiftUI
import AppKit

final class EditableNSTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isEditable = true
        isSelectable = true
        return super.becomeFirstResponder()
    }
}

final class EditableNSSecureTextField: NSSecureTextField {
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        isEditable = true
        isSelectable = true
        return super.becomeFirstResponder()
    }
}

struct MacTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = EditableNSTextField()
        field.placeholderString = placeholder
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .default
        field.drawsBackground = true
        field.isEnabled = true
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.commit(_:))
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTextField
        init(_ parent: MacTextField) { self.parent = parent }

        @objc @MainActor func commit(_ sender: NSTextField) {
            parent.text = sender.stringValue
        }

        @MainActor
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        @MainActor
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

struct MacSecureField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSSecureTextField {
        let field = EditableNSSecureTextField()
        field.placeholderString = placeholder
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .default
        field.drawsBackground = true
        field.isEnabled = true
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.commit(_:))
        return field
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacSecureField
        init(_ parent: MacSecureField) { self.parent = parent }

        @objc @MainActor func commit(_ sender: NSTextField) {
            parent.text = sender.stringValue
        }

        @MainActor
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        @MainActor
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

struct MacSearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var focusNotification: Notification.Name? = nil

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchAction(_:))
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = false
        context.coordinator.field = field
        context.coordinator.installFocusObserver()
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.installFocusObserver()
    }

    static func dismantleNSView(_ nsView: NSSearchField, coordinator: Coordinator) {
        coordinator.removeFocusObserver()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: MacSearchField
        weak var field: NSSearchField?
        private var observedNotification: Notification.Name?

        init(_ parent: MacSearchField) {
            self.parent = parent
        }

        func installFocusObserver() {
            guard observedNotification != parent.focusNotification else { return }
            removeFocusObserver()
            guard let name = parent.focusNotification else { return }
            observedNotification = name
            NotificationCenter.default.addObserver(self, selector: #selector(focusField), name: name, object: nil)
        }

        func removeFocusObserver() {
            NotificationCenter.default.removeObserver(self)
            observedNotification = nil
        }

        @objc @MainActor func focusField() {
            field?.window?.makeFirstResponder(field)
        }

        @objc @MainActor func searchAction(_ sender: NSSearchField) {
            parent.text = sender.stringValue
        }

        @MainActor
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }
    }
}
