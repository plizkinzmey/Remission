import SwiftUI

#if os(iOS)
    import UIKit

    struct LeadingCursorTextField: UIViewRepresentable {
        @Binding var text: String
        let placeholder: String
        let keyboardType: UIKeyboardType
        let textAlignment: NSTextAlignment

        init(
            text: Binding<String>,
            placeholder: String = "",
            keyboardType: UIKeyboardType = .default,
            textAlignment: NSTextAlignment = .left
        ) {
            _text = text
            self.placeholder = placeholder
            self.keyboardType = keyboardType
            self.textAlignment = textAlignment
        }

        func makeUIView(context: Context) -> UITextField {
            let textField = UITextField()
            textField.delegate = context.coordinator
            textField.text = text
            textField.placeholder = placeholder
            textField.keyboardType = keyboardType
            textField.textAlignment = textAlignment
            textField.addTarget(
                context.coordinator,
                action: #selector(Coordinator.textDidChange(_:)),
                for: .editingChanged
            )
            return textField
        }

        func updateUIView(_ uiView: UITextField, context: Context) {
            if uiView.text != text {
                uiView.text = text
            }
            if uiView.placeholder != placeholder {
                uiView.placeholder = placeholder
            }
            if uiView.keyboardType != keyboardType {
                uiView.keyboardType = keyboardType
            }
            if uiView.textAlignment != textAlignment {
                uiView.textAlignment = textAlignment
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(text: $text)
        }

        final class Coordinator: NSObject, UITextFieldDelegate {
            @Binding var text: String
            private var didSelectAllOnFocus = false

            init(text: Binding<String>) {
                _text = text
            }

            @objc func textDidChange(_ sender: UITextField) {
                text = sender.text ?? ""
            }

            func textFieldDidBeginEditing(_ textField: UITextField) {
                guard didSelectAllOnFocus == false else { return }
                didSelectAllOnFocus = true
                DispatchQueue.main.async {
                    let start = textField.beginningOfDocument
                    let end = textField.endOfDocument
                    textField.selectedTextRange = textField.textRange(from: start, to: end)
                }
            }

            func textFieldDidEndEditing(_ textField: UITextField) {
                didSelectAllOnFocus = false
            }
        }
    }
#endif
