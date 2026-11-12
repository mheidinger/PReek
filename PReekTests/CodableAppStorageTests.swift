import Foundation
import Testing

struct CodableAppStorageTests {
    private struct Value: Codable, Equatable {
        var unreadCount: Int
    }

    @Test func keepsReadAndWriteDomainsIsolated() throws {
        let firstDomain = "PReekTests.CodableAppStorage.\(UUID().uuidString)"
        let secondDomain = "PReekTests.CodableAppStorage.\(UUID().uuidString)"
        let first = try #require(UserDefaults(suiteName: firstDomain))
        let second = try #require(UserDefaults(suiteName: secondDomain))
        defer {
            first.removePersistentDomain(forName: firstDomain)
            second.removePersistentDomain(forName: secondDomain)
        }
        try first.set(JSONEncoder().encode(Value(unreadCount: 3)), forKey: "readState")
        try second.set(JSONEncoder().encode(Value(unreadCount: 7)), forKey: "readState")
        let firstStorage = CodableAppStorage(wrappedValue: Value(unreadCount: 0), "readState", store: first)
        let secondStorage = CodableAppStorage(wrappedValue: Value(unreadCount: 0), "readState", store: second)

        #expect(firstStorage.wrappedValue.unreadCount == 3)
        #expect(secondStorage.wrappedValue.unreadCount == 7)
        firstStorage.wrappedValue = Value(unreadCount: 11)

        let reloaded = CodableAppStorage(wrappedValue: Value(unreadCount: 0), "readState", store: first)
        #expect(reloaded.wrappedValue.unreadCount == 11)
        #expect(try JSONDecoder().decode(Value.self, from: #require(second.data(forKey: "readState"))).unreadCount == 7)
    }

    @Test func malformedInjectedDataUsesTheOwnersFallback() throws {
        let domain = "PReekTests.CodableAppStorage.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(Data("not JSON".utf8), forKey: "readState")
        let storage = CodableAppStorage(wrappedValue: Value(unreadCount: 5), "readState", store: defaults)
        #expect(storage.wrappedValue.unreadCount == 5)
        storage.wrappedValue = Value(unreadCount: 2)
        #expect(try JSONDecoder().decode(Value.self, from: #require(defaults.data(forKey: "readState"))).unreadCount == 2)
    }
}
