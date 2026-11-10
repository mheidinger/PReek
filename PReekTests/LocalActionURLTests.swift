#if os(macOS)
    import Foundation
    import Testing

    struct LocalActionURLTests {
        @Test(arguments: ["https://api.github.com/graphql", "https://github.concur.com/api/graphql"])
        func graphQLRequestsUseTheEndpointWithoutAppendingASlash(_ endpoint: String) throws {
            let base = try #require(URL(string: endpoint))
            let request = try LocalActionURL.resolve(base: base, path: "")
            #expect(request.absoluteString == endpoint)
        }

        @Test func enterpriseDiscussionPaginationPreservesItsQuery() throws {
            let base = try #require(URL(string: "https://github.concur.com/api/v3"))
            let first = try LocalActionURL.resolve(base: base, path: "repos/t2/t2-ui-trip/pulls/3680/reviews")
            #expect(first.path == "/api/v3/repos/t2/t2-ui-trip/pulls/3680/reviews")
            let next = try #require(URL(string: "https://github.concur.com/api/v3/repositories/123/pulls/3680/reviews?page=2&per_page=30"))
            #expect(try LocalActionURL.resolve(base: base, path: "unused", pageURL: next) == next)
        }

        @Test(arguments: [
            "https://other.example/api/v3/repos/t2/t2-ui-trip/issues/3680/comments?page=2",
            "http://github.concur.com/api/v3/repos/t2/t2-ui-trip/issues/3680/comments?page=2",
            "https://github.concur.com:8443/api/v3/repos/t2/t2-ui-trip/issues/3680/comments?page=2",
            "https://github.concur.com/api/v30/repos/t2/t2-ui-trip/issues/3680/comments?page=2",
        ])
        func rejectsPaginationOutsideTheConfiguredAPI(_ value: String) throws {
            let base = try #require(URL(string: "https://github.concur.com/api/v3"))
            #expect(throws: (any Error).self) {
                try LocalActionURL.resolve(base: base, path: "", pageURL: #require(URL(string: value)))
            }
        }
    }
#endif
