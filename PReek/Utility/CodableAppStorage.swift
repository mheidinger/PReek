import Foundation

/// Allow to store any `Codable` in AppStorage.
///
/// The decoded value is cached in memory so repeated reads (e.g. filtering the PR list on every
/// invalidation) don't re-decode the whole blob from UserDefaults each access. The cache is only
/// kept coherent for a single owning instance; do not share the same key across multiple live
/// instances that each write to it.
@propertyWrapper
struct CodableAppStorage<T: Codable> {
    private let key: String
    private let defaultValue: T
    private let cache = Cache()

    private final class Cache {
        var value: T?
    }

    init(wrappedValue: T, _ key: String) {
        self.key = key
        defaultValue = wrappedValue
    }

    var wrappedValue: T {
        get {
            if let cached = cache.value {
                return cached
            }

            let value: T
            if let data = UserDefaults.standard.data(forKey: key) {
                value = (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
            } else {
                value = defaultValue
            }
            cache.value = value
            return value
        }
        nonmutating set {
            cache.value = newValue
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
}
