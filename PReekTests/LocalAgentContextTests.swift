#if os(macOS)
    import Foundation
    import Testing

    struct LocalAgentContextTests {
        @Test(arguments: ["LEFT", "RIGHT"])
        func retainsDiffSidesAndBothLocationSnapshots(_ side: String) throws {
            let thread = LocalAgentSession.ThreadAttachment(
                path: "Sources/Example.swift", outdated: false,
                currentLine: 20, currentStartLine: 18,
                originalLine: 12, originalStartLine: 10,
                diffSide: side, startDiffSide: side,
                url: "https://github.com/owner/repo/pull/1#discussion_r42",
                comments: [["author": "reviewer", "body": "Check this range."]]
            )
            let value = try json(thread)
            #expect(value["diffSide"] as? String == side)
            #expect(value["startDiffSide"] as? String == side)
            #expect(value["line"] as? Int == 20)
            #expect(value["startLine"] as? Int == 18)
            #expect(value["currentLine"] as? Int == 20)
            #expect(value["currentStartLine"] as? Int == 18)
            #expect(value["originalLine"] as? Int == 12)
            #expect(value["originalStartLine"] as? Int == 10)
            #expect(value["outdated"] as? Bool == false)
            #expect(value["url"] as? String == thread.url)
        }

        @Test
        func outdatedFallbackDoesNotMasqueradeAsCurrentLocation() throws {
            let thread = LocalAgentSession.ThreadAttachment(
                path: "removed.swift", outdated: true,
                currentLine: nil, currentStartLine: nil,
                originalLine: 20, originalStartLine: 18,
                diffSide: "LEFT", startDiffSide: "LEFT", url: nil, comments: []
            )
            let value = try json(thread)
            #expect(value["line"] as? Int == 20)
            #expect(value["startLine"] as? Int == 18)
            #expect(value["originalLine"] as? Int == 20)
            #expect(value["originalStartLine"] as? Int == 18)
            #expect(value["currentLine"] == nil)
            #expect(value["currentStartLine"] == nil)
            #expect(value["outdated"] as? Bool == true)
            #expect(value["url"] == nil)
        }

        @Test
        func omitsAbsentLocationsAndPreservesCompleteCommentBodies() throws {
            let body = String(repeating: "reply with \"quotes\", \\ and 雪\n", count: 10000)
            let comments = [
                ["author": "ghost", "body": "Original comment"],
                ["author": "reply-author", "body": body],
            ]
            let thread = LocalAgentSession.ThreadAttachment(
                path: "file.swift", outdated: false,
                currentLine: nil, currentStartLine: nil,
                originalLine: nil, originalStartLine: nil,
                diffSide: "RIGHT", startDiffSide: nil, url: nil, comments: comments
            )
            let value = try json(thread)
            #expect(Set(value.keys) == ["path", "outdated", "comments", "diffSide"])
            #expect(value["comments"] as? [[String: String]] == comments)
        }

        private func json(_ thread: LocalAgentSession.ThreadAttachment) throws -> [String: Any] {
            let data = try JSONEncoder().encode(thread)
            return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
    }
#endif
