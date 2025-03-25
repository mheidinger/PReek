import Foundation

let relativeFormatter = RelativeDateTimeFormatter()

func isDateInLastMinuteOrFuture(_ date: Date) -> Bool {
    let calendar = Calendar.current
    let now = Date()
    let oneMinuteAgo = calendar.date(byAdding: .minute, value: -1, to: now)!
    return date >= oneMinuteAgo
}

func isDateInLastSevenDays(_ date: Date) -> Bool {
    let calendar = Calendar.current
    let now = Date()
    let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
    return date >= sevenDaysAgo && date <= now
}

extension Date {
    var formatRelative: String {
        if isDateInLastMinuteOrFuture(self) {
            return String(localized: "now")
        }
        return relativeFormatter.localizedString(for: self, relativeTo: Date.now)
    }
}
