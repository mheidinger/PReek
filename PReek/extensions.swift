import Foundation
import SwiftUI

// During JSON deserialize default to last enum value
protocol CaseIterableDefaultsLast: Decodable & CaseIterable & RawRepresentable
where RawValue: Decodable, AllCases: BidirectionalCollection { }

extension CaseIterableDefaultsLast {
    init(from decoder: Decoder) throws {
        self = try Self(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? Self.allCases.last!
    }
}

// Allow to store any `Codable` in AppStorage
@propertyWrapper
struct CodableAppStorage<T: Codable> {
    private let key: String
    private let defaultValue: T

    init(wrappedValue: T, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }

    var wrappedValue: T {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return defaultValue }
            return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
}

// Allow strings to be thrown as error
extension String: Error {}

// Add changing cursor to hand and background higlight on link hover
extension Link {
    func pointingHandCursor() -> some View {
        self.onHover { inside in
            if inside {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

// Add function to close the menu bar window into the global environment
private struct CloseMenuBarWindowModifierLinkActionKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    var closeMenuBarWindowModifierLinkAction: (Bool) -> Void {
        get { self[CloseMenuBarWindowModifierLinkActionKey.self] }
        set { self[CloseMenuBarWindowModifierLinkActionKey.self] = newValue }
    }
}
