import SwiftUI

// During JSON deserialize default to last enum value
protocol CaseIterableDefaultsLast: Decodable & CaseIterable & RawRepresentable
    where RawValue: Decodable, AllCases: BidirectionalCollection {}

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
        defaultValue = wrappedValue
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

// Add `if` to view builder that only applies modifiers if the condition is true
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
