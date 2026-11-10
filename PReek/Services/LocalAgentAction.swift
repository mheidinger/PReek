#if os(macOS)
    import Foundation

    /// A saved prompt for an interactive agent session, not an editor action.
    struct LocalAgentAction: Codable, Identifiable, Equatable {
        enum Kind: String, Codable {
            case review
            case address
            case custom
        }

        var id: UUID = .init()
        var name: String
        var prompt: String
        var kind: Kind

        var hasPrompt: Bool {
            !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var displayName: String {
            name.isEmpty ? "Untitled action" : name
        }

        static let defaults: [LocalAgentAction] = [
            LocalAgentAction(name: "Review PR", prompt: """
            Review the PR diff and relevant surrounding code for defects, maintainability, and unnecessary complexity. Prefer simple, robust solutions. Report actionable findings by severity with file/line references and impact; say if none. Do not modify files.
            """, kind: .review),
            LocalAgentAction(name: "Address comments", prompt: """
            Address actionable unresolved feedback in the local worktree. Read unresolved threads with their replies; consult review/discussion files listed in the PR context as needed. Check whether outdated feedback still applies. Run relevant checks; summarize changes, verification, and anything needing a human decision.
            """, kind: .address),
        ]
    }
#endif
