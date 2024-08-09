//
//  extensions.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 30.05.24.
//

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

// Allow Dictionary [String: Date] to be annotated with @AppStorage by providing string/JSON serialize and deserialize
extension Dictionary: RawRepresentable where Key == String, Value == Date {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8), // convert from String to Data
              let result = try? JSONDecoder().decode([String:Date].self, from: data)
        else {
            return nil
        }
        self = result
    }
    
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self), // data is Data type
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"  // empty Dictionary represented as String
        }
        return result
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
