import SwiftUI
import AppKit

struct URLBarView: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = "Enter URL"
        field.bezelStyle = .roundedBezel
        field.stringValue = text
        field.delegate = context.coordinator
        field.isBordered = true
        field.isBezeled = true
        field.isEditable = true
        field.isSelectable = true
        field.focusRingType = .exterior
        field.font = .systemFont(ofSize: 13)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if !context.coordinator.isEditing {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var onSubmit: () -> Void
        var isEditing = false

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if let field = control as? NSTextField {
                    text = field.stringValue
                }
                isEditing = false
                onSubmit()
                // Resign focus back to the window so WKWebView can be interactive
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}
