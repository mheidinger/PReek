//
//  ModifierLink.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 12.07.24.
//

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
    let additionalAction: AdditionalActionProcessor?
    
    @Environment(\.openURL) private var openURL
    
    init(destination: URL, additionalAction: AdditionalActionProcessor?, label: @escaping () -> Label) {
        self.destination = destination
        self.label = label
        self.additionalAction = additionalAction
    }
    
    var body: some View {
        Button(action: {
            openURL(destination)
            additionalAction?(NSEvent.modifierFlags.contains(convertToNSEventModifierFlags(modifiers)))
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

#Preview {
    ModifierLink(destination: URL(string: "https://example.com")!, additionalAction: { modifierPressed in
        print("Action! Modifier Pressed: \(modifierPressed)")
    }) {
        Text("Click Me!")
    }
        .padding()
}
