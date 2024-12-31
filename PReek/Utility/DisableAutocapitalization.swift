import SwiftUI

// Add `disableAutoCapitalization` to view builder that only applies on iOS where this is available
extension View {
    @ViewBuilder func disableAutoCapitalization() -> some View {
        #if os(iOS)
            textInputAutocapitalization(.never)
        #else
            self
        #endif
    }
}
