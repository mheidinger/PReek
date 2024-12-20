import Foundation

struct ReadData: Codable {
    let date: Date
    let eventId: String? // Optional in case of inconsistent state
}
