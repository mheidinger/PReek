//
//  HelpTextField.swift
//  PReek
//
//  Created by Max Heidinger on 13.08.24.
//

import SwiftUI

struct HelpTextField<HelpContent: View>: View {
    enum FieldType {
        case secureField
        case textField
    }
    
    let type: FieldType
    @Binding var text: String
    let label: LocalizedStringKey
    let helpContent: () -> HelpContent
    
    @State private var showPopover = false
    
    var body: some View {
        switch type {
        case .secureField:
            secureField
        case .textField:
            textField
        }
    }
    
    var secureField: some View {
        SecureField(text: $text) {
            labelContent
        }
    }
    
    var textField: some View {
        TextField(text: $text) {
            labelContent
        }
    }
    
    var labelContent: some View {
        HStack(spacing: 3) {
            Text(label)
            Button(action: { showPopover = true }) {
                Image(systemName: "questionmark.circle.fill")
                    .popover(isPresented: $showPopover, content: helpContent)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    Form {
        HelpTextField(type: .secureField, text: .constant("My entered secure value"), label: "Some secure value") {
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
