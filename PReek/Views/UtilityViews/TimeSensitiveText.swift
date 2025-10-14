import SwiftUI

private class TimeSensitiveTextTimer: ObservableObject {
    static let shared = TimeSensitiveTextTimer()

    @Published private(set) var tick = Date()

    private init() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.tick = Date()
        }
    }
}

struct TimeSensitiveText: View {
    let getText: () -> String
    @State private var currentText: String
    @ObservedObject private var timer = TimeSensitiveTextTimer.shared

    init(getText: @escaping () -> String) {
        self.getText = getText
        _currentText = State(initialValue: getText())
    }

    var body: some View {
        Text(currentText)
            .onReceive(timer.$tick) { _ in
                let newText = getText()
                if newText != currentText {
                    currentText = newText
                }
            }
    }
}
