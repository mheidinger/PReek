import SwiftUI

struct RevealSecureField<Label: View>: View {
    @Binding var text: String
    @ViewBuilder var label: () -> Label

    @State private var show: Bool = false

    var body: some View {
        Group {
            if show {
                TextField(text: $text, label: label)
            } else {
                SecureField(text: $text, label: label)
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
            .padding(.trailing)
        }
    }
}

#Preview {
    Form {
        Section {
            RevealSecureField(text: .constant("My entered secure value")) {
                Text("Some helpful secure help")
            }
        }
    }
    .formStyle(.grouped)
}
