import SwiftUI

struct CommitsView: View {
    let commits: [Commit]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(commits) { commit in
                if let url = commit.url {
                    ModifierLink(destination: url) {
                        BulletPoint(commit.messageHeadline)
                    }
                } else {
                    BulletPoint(commit.messageHeadline)
                }
            }
        }
    }
}

#Preview {
    CommitsView(commits: [
        Commit(id: "1", messageHeadline: "my first commit!", url: URL(string: "https://example.com")!),
        Commit(id: "2", messageHeadline: "my second commit!", url: URL(string: "https://example.com")!),
        Commit(id: "3", messageHeadline: "my third commit!", url: nil),
    ])
    .padding()
}
