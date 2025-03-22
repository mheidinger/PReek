import SwiftUI

struct TimeSensitiveText: View {
    let getText: () -> String
    @State private var currentText: String
    
    init(getText: @escaping () -> String) {
        self.getText = getText
        currentText = getText()
    }
    
    private let timer = Timer.publish(
        every: 30,
        on: .main,
        in: .common
    ).autoconnect()
    
    var body: some View {
        Text(currentText)
            .onReceive(timer) { _ in
                currentText = getText()
            }
    }
}
