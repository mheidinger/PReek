#if os(macOS)
    import Foundation

    /// The only app-owned files written into a local-agent session directory.
    enum LocalAgentSession {
        enum File: String, CaseIterable {
            case actionPrompt = "action-prompt.txt"
            case pullRequest = "pull-request.json"
            case issueComments = "issue-comments.json"
            case reviews = "reviews.json"
            case reviewThreads = "review-threads.json"
            case instructions = "local-only-instructions.txt"
        }

        /// Only the task and PR snapshot are included in the agent's initial message.
        static let eagerAttachments: [File] = [.actionPrompt, .pullRequest]

        struct ThreadAttachment: Encodable {
            let path: String
            let outdated: Bool
            let comments: [[String: String]]
            // Keep the historical fallback fields, but label each actual location explicitly.
            let line: Int?
            let startLine: Int?
            let currentLine: Int?
            let currentStartLine: Int?
            let originalLine: Int?
            let originalStartLine: Int?
            let diffSide: String
            let startDiffSide: String?
            let url: String?

            init(
                path: String,
                outdated: Bool,
                currentLine: Int?,
                currentStartLine: Int?,
                originalLine: Int?,
                originalStartLine: Int?,
                diffSide: String,
                startDiffSide: String?,
                url: String?,
                comments: [[String: String]]
            ) {
                self.path = path
                self.outdated = outdated
                self.comments = comments
                line = currentLine ?? originalLine
                startLine = currentStartLine ?? originalStartLine
                self.currentLine = currentLine
                self.currentStartLine = currentStartLine
                self.originalLine = originalLine
                self.originalStartLine = originalStartLine
                self.diffSide = diffSide
                self.startDiffSide = startDiffSide
                self.url = url
            }
        }
    }
#endif
