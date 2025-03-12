import SwiftUI

struct DateSensitiveText: View {
    let getText: () -> String
    @State private var currentDate = Date()

    private let timer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        Text(getText())
            .onReceive(timer) { _ in
                let newDate = Date()
                if !Calendar.current.isDate(currentDate, inSameDayAs: newDate) {
                    currentDate = newDate
                }
            }
    }
}
