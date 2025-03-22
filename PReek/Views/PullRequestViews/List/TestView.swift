import SwiftUI

struct PRHeader: View {
    let repository: String
    let title: String
    let prNumber: String
    let author: String
    let updatedTime: String
    let additions: Int
    let deletions: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(repository)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(prNumber)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("Open", image: .prOpen)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(12)
            }
            
            Text(title)
                .font(.title3)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text("by \(author)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(updatedTime)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                HStack {
                    Text("+\(additions)")
                        .foregroundColor(.green)
                    Text("-\(deletions)")
                        .foregroundColor(.red)
                }
                .font(.subheadline)
                
                Spacer()
                
                Button(action: {
                    // Open in browser action
                }) {
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.bottom, 8)
    }
}

struct ActivityItem: View {
    enum ActionType {
        case closed, pushed, merged, requested, commented
        
        var icon: String {
            switch self {
            case .closed: return "xmark.circle"
            case .pushed: return "arrow.up.circle"
            case .merged: return "arrow.triangle.merge"
            case .requested: return "exclamationmark.bubble"
            case .commented: return "text.bubble"
            }
        }
        
        var color: Color {
            switch self {
            case .closed: return .red
            case .pushed: return .blue
            case .merged: return .purple
            case .requested: return .orange
            case .commented: return .gray
            }
        }
    }
    
    let person: String
    let action: ActionType
    let timestamp: Date
    let comment: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text(person)
                        .fontWeight(.medium)
                    
                    Text(actionText)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: action.icon)
                        .foregroundColor(action.color)
                }
                
                Spacer()
                
                Text(timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    // Open in browser action
                }) {
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            
            if let comment = comment {
                Text(comment)
                    .font(.subheadline)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Divider()
        }
        .padding(.vertical, 4)
    }
    
    private var actionText: String {
        switch action {
        case .closed: return "closed this"
        case .pushed: return "pushed to this"
        case .merged: return "merged this"
        case .requested: return "requested changes"
        case .commented: return "commented"
        }
    }
}

struct PullRequestTestView: View {
    let pr: PullRequest // Your model
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PRHeader(
                    repository: pr.repository.name,
                    title: pr.title,
                    prNumber: pr.numberFormatted,
                    author: pr.author.displayName,
                    updatedTime: pr.lastUpdatedFormatted,
                    additions: pr.additions,
                    deletions: pr.deletions
                )
                
                Divider()
                
                ActivityItem(
                    person: "Person 1",
                    action: .commented,
                    timestamp: Date(),
                    comment: "my comment"
                )
            }
            .padding()
        }
        .navigationTitle("Pull Request")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {}) {
                        Label("Approve", systemImage: "checkmark.circle")
                    }
                    Button(action: {}) {
                        Label("Request Changes", systemImage: "exclamationmark.circle")
                    }
                    Button(action: {}) {
                        Label("Comment", systemImage: "text.bubble")
                    }
                    Divider()
                    Button(action: {}) {
                        Label("Open in Browser", systemImage: "safari")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

#Preview {
    PullRequestTestView(pr: PullRequest.preview(id: "1", title: "long long long long long long long long long"))
}
