import SwiftUI

// Allow `if` during string interpolation
extension String.StringInterpolation {
    /// Provides Boolean-guided interpolation that succeeds only when the condition
    /// evaluates to true.
    mutating func appendInterpolation(if condition: @autoclosure () -> Bool, _ literal: StringLiteralType) {
        guard condition() else { return }
        appendLiteral(literal)
    }
}
