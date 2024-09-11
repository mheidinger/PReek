import Foundation

// During JSON deserialize default to last enum value
protocol CaseIterableDefaultsLast: Decodable & CaseIterable & RawRepresentable
    where RawValue: Decodable, AllCases: BidirectionalCollection {}

extension CaseIterableDefaultsLast {
    init(from decoder: Decoder) throws {
        self = try Self(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? Self.allCases.last!
    }
}
