#if os(macOS)
    import Foundation

    /// A user-facing failure while preparing or opening a local action.
    struct LocalActionError: LocalizedError {
        let message: String

        var errorDescription: String? {
            message
        }
    }
#endif
