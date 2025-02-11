import SwiftUI

struct RevealSecureField<Label: View>: View {
    @Binding var text: String
    var prompt: Text? = nil
    @ViewBuilder var label: () -> Label

    @State private var show: Bool = false

    var body: some View {
        Group {
            if show {
                TextField(text: $text, prompt: prompt, label: label)
            } else {
                SecureField(text: $text, prompt: prompt, label: label)
            }
        }
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
    }
}

#Preview {
    Form {
        Section {
            RevealSecureField(text: .constant("My entered secure value")) {
                Text("Some helpful secure help")
            }
            RevealSecureField(text: .constant(""), prompt: Text("Password")) {
                Text("Some helpful secure help")
            }
        }
    }
    .formStyle(.grouped)
}
