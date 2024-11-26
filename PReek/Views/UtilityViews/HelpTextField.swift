import SwiftUI

struct HelpTextField<HelpContent: View>: View {
    enum FieldType {
        case secureField
        case revealSecureField
        case textField
    }

    let type: FieldType
    @Binding var text: String
    let label: LocalizedStringKey
    // Only available on macOS
    let helpContent: () -> HelpContent

    @State private var showPopover = false

    var body: some View {
        switch type {
        case .secureField:
            secureField
        case .revealSecureField:
            revealSecureField
        case .textField:
            textField
        }
    }

    var secureField: some View {
        SecureField(text: $text) {
            labelContent
        }
    }

    var revealSecureField: some View {
        RevealSecureField(text: $text) {
            labelContent
        }
    }

    var textField: some View {
        TextField(text: $text) {
            labelContent
        }
    }

    #if os(macOS)
        var labelContent: some View {
            HStack(spacing: 3) {
                Text(label)
                Button(action: { showPopover.toggle() }) {
                    Image(systemName: "questionmark.circle.fill")
                        .popover(isPresented: $showPopover, content: helpContent)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Quick help")
            }
        }
    #else
        var labelContent: some View {
            Text(label)
        }
    #endif
}

#Preview {
    Form {
        HelpTextField(type: .secureField, text: .constant("My entered secure value"), label: "Some secure value") {
            Text("Some helpful secure help")
                .padding()
        }
        HelpTextField(type: .revealSecureField, text: .constant("My entered secure value"), label: "Some secure value") {
            Text("Some helpful secure help")
                .padding()
        }
        HelpTextField(type: .textField, text: .constant("My entered value"), label: "Some value") {
            Text("Some helpful help")
                .padding()
        }
    }
    .padding()
}
