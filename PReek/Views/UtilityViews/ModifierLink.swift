import SwiftUI

private func convertToNSEventModifierFlags(_ modifiers: EventModifiers) -> NSEvent.ModifierFlags {
    var flags = NSEvent.ModifierFlags()

    if modifiers.contains(.shift) { flags.insert(.shift) }
    if modifiers.contains(.control) { flags.insert(.control) }
    if modifiers.contains(.option) { flags.insert(.option) }
    if modifiers.contains(.command) { flags.insert(.command) }
    if modifiers.contains(.capsLock) { flags.insert(.capsLock) }
    if modifiers.contains(.numericPad) { flags.insert(.numericPad) }

    return flags
}

struct ModifierLink<Label: View>: View {
    typealias AdditionalActionProcessor = (_ modifierPressed: Bool) -> Void

    let destination: URL
    let modifiers: EventModifiers = .command
    let label: () -> Label

    @Environment(\.modifierLinkAction) var additionalAction
    @Environment(\.openURL) private var openURL

    init(destination: URL, label: @escaping () -> Label) {
        self.destination = destination
        self.label = label
    }

    var body: some View {
        Button(action: {
            openURL(destination)
            additionalAction(NSEvent.modifierFlags.contains(convertToNSEventModifierFlags(modifiers)))
        }, label: label)
            .buttonStyle(PlainButtonStyle())
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
    }
}

private struct ModifierLinkActionKey: EnvironmentKey {
    static let defaultValue: ModifierLink.AdditionalActionProcessor = { _ in }
}

extension EnvironmentValues {
    var modifierLinkAction: ModifierLink.AdditionalActionProcessor {
        get { self[ModifierLinkActionKey.self] }
        set { self[ModifierLinkActionKey.self] = newValue }
    }
}

#Preview {
    ModifierLink(destination: URL(string: "https://example.com")!) {
        Text("Click Me!")
    }
    .environment(\.modifierLinkAction) { modifierPressed in
        print("Action! Modifier Pressed: \(modifierPressed)")
    }
    .padding()
}
