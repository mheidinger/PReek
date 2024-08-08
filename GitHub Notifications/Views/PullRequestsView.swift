//
//  PullRequestsView.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 26.05.24.
//

import SwiftUI

struct PullRequestsView: View {
    var pullRequests: [PullRequest]
    var modifierLinkAction: ModifierLink.AdditionalActionProcessor?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                DividedView {
                    ForEach(pullRequests) { pullRequest in
                        PullRequestView(pullRequest: pullRequest, modifierLinkAction: modifierLinkAction)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 5)
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
