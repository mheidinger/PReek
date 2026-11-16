import SwiftUI

struct RevealSecureField<Label: View>: View {
    @Binding var text: String
    var prompt: Text? = nil
    var accessibilityLabel: Text
    @ViewBuilder var label: () -> Label

    @State private var show: Bool = false
    #if os(iOS)
        @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        #if os(iOS)
            HStack(spacing: 8) {
                fieldContent
                    .accessibilityLabel(accessibilityLabel)
                    .focused($isFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .privacySensitive()

                Button {
                    show.toggle()
                    isFocused = true
                } label: {
                    Image(systemName: show ? "eye.slash" : "eye")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(show ? Text("Hide value") : Text("Show value"))
            }
        #else
            fieldContent
                .safeAreaInset(edge: .trailing, spacing: 0) {
                    Button(action: {
                        show.toggle()
                    }) {
                        Image(systemName: show ? "eye" : "eye.slash")
                    }
                    .foregroundStyle(.primary)
                    .buttonStyle(.borderless)
                    .padding(.leading, 5)
                }
        #endif
    }

    @ViewBuilder
    private var fieldContent: some View {
        if show {
            TextField(text: $text, prompt: prompt, label: label)
        } else {
            SecureField(text: $text, prompt: prompt, label: label)
        }
    }
}

#Preview {
    Form {
        Section {
            RevealSecureField(text: .constant("My entered secure value"), accessibilityLabel: Text("Some helpful secure help")) {
                Text("Some helpful secure help")
            }
            RevealSecureField(text: .constant(""), prompt: Text("Password"), accessibilityLabel: Text("Some helpful secure help")) {
                Text("Some helpful secure help")
            }
        }
    }
    .formStyle(.grouped)
}
