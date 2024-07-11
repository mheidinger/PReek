//
//  PullRequestsView.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 26.05.24.
//

import SwiftUI

struct PullRequestsView: View {
    var pullRequests: [PullRequest]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                DividedView {
                    ForEach(sortedPullRequests) { pullRequest in
                        PullRequestView(pullRequest: pullRequest)
                    }
                }
            }
            .padding([.horizontal, .top])
        }
    }
    
    var sortedPullRequests: [PullRequest] {
        pullRequests.map { $0 }.sorted {
            $0.lastUpdated > $1.lastUpdated
        }
    }
}

#Preview {
    PullRequestsView(pullRequests: [
        PullRequest.preview(title: "short"),
        PullRequest.preview(title: "asdsadasdasdaaaaaaasssssssssssssssssssssssssssaaaaaaa"),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview(),
        PullRequest.preview()
    ])
}
