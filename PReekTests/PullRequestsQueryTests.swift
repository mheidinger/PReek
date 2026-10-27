import Testing

struct PullRequestsQueryTests {
    @Test func defaultBatchSizeIsTen() {
        let batches = PullRequestsQueryBuilder.chunkRepoMap([
            "org/repo": Array(1 ... 21),
        ])

        #expect(batches.map { $0.values.reduce(0) { $0 + $1.count } } == [10, 10, 1])
    }

    @Test func splitRepoMapPreservesEveryPullRequest() {
        let repoMap = [
            "org/one": [1, 2, 3],
            "org/two": [4, 5, 6, 7],
        ]
        let splitBatches = PullRequestsQueryBuilder.splitRepoMap(repoMap)

        #expect(splitBatches.count == 2)
        #expect(splitBatches.map { $0.values.reduce(0) { $0 + $1.count } }.sorted() == [3, 4])

        let actual = splitBatches
            .flatMap { batch in
                batch.flatMap { repo, pullRequests in
                    pullRequests.map { "\(repo)#\($0)" }
                }
            }
            .sorted()
        let expected = repoMap
            .flatMap { repo, pullRequests in
                pullRequests.map { "\(repo)#\($0)" }
            }
            .sorted()

        #expect(actual == expected)
    }

    @Test func splitRepoMapReturnsNoSplitForSinglePullRequest() {
        #expect(PullRequestsQueryBuilder.splitRepoMap(["org/repo": [1]]).isEmpty)
    }
}
