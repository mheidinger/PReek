import Foundation

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
