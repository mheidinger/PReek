import SwiftUI

private let statusToIcon: [PullRequest.Status: ImageResource] = [
    PullRequest.Status.draft: .prDraft,
    PullRequest.Status.open: .prOpen,
    PullRequest.Status.merged: .prMerged,
    PullRequest.Status.closed: .prClosed
]

struct PullRequestHeaderView: View {
    @Environment(\.closeMenuBarWindowModifierLinkAction) var modifierLinkAction
    
    var pullRequest: PullRequest
    var toggleRead: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(statusToIcon[pullRequest.status] ?? .prOpen)
                .foregroundStyle(.primary)
                .imageScale(.large)
            
            HStack(alignment: .top) {
                VStack(alignment:.leading, spacing: 3) {
                    HStack {
                        ModifierLink(destination: pullRequest.repository.url, additionalAction: modifierLinkAction) {
                            Text(pullRequest.repository.name)
                        }
                        ModifierLink(destination: pullRequest.url, additionalAction: modifierLinkAction){
                            Text(pullRequest.numberFormatted)
                        }
                        .foregroundColor(.secondary)
                    }
                    HStack {
                        ModifierLink(destination: pullRequest.url, additionalAction: modifierLinkAction) {
                            Text(pullRequest.title)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }
                        .font(.headline)
                    }
                    HStack(spacing: 5) {
                        if let authorUrl = pullRequest.author.url {
                            ModifierLink(destination: authorUrl, additionalAction: modifierLinkAction) {
                                Text("by \(pullRequest.author.displayName)")
                            }
                        } else {
                            Text("by \(pullRequest.author.displayName)")
                        }
                        Text("·")
                        Text("\(pullRequest.lastUpdatedFormatted)")
                        Text("·")
                        
                        ModifierLink(destination: pullRequest.filesUrl, additionalAction: modifierLinkAction) {
                            HStack(spacing: 2) {
                                Text(pullRequest.additionsFormatted)
                                    .foregroundStyle(.green)
                                Text(pullRequest.deletionsFormatted)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                    }
                    .foregroundStyle(.secondary)
                    .textScale(.secondary)
                    .padding(.top, -3)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: pullRequest.markedAsRead ? "circle" : "circle.fill")
                .imageScale(.medium)
                .foregroundStyle(.blue)
                .onTapGesture(perform: toggleRead)
        }
        .padding(.leading)
        .frame(maxWidth: .infinity)
    }
}

struct PullRequestContentView: View {
    @State var eventLimit = 0;
    
    var pullRequest: PullRequest
    
    init(pullRequest: PullRequest) {
        self.eventLimit =  min(pullRequest.events.count, 5)
        self.pullRequest = pullRequest
    }
    
    func loadMore() {
        self.eventLimit = min(pullRequest.events.count, eventLimit + 5)
    }
    
    @ViewBuilder var noEventsBody: some View {
        Text("No Events")
            .foregroundStyle(.secondary)
    }
    
    @ViewBuilder var eventsBody: some View {
        VStack {
            DividedView {
                ForEach(pullRequest.events[0..<eventLimit]) { event in
                    PullRequestEventView(pullRequestEvent: event)
                }
                if self.eventLimit < pullRequest.events.count {
                    Button(action: loadMore) {
                        Label("Load More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .padding(.leading, 30)
        .padding(.vertical, 5)
    }
    
    var body: some View {
        if pullRequest.events.isEmpty {
            noEventsBody
        }
        eventsBody
    }
}

struct PullRequestView: View {
    var pullRequest: PullRequest
    var toggleRead: () -> Void
    
    @State var sectionExpanded: Bool = false
    
    var body: some View {
        VStack {
            DisclosureGroup(isExpanded: $sectionExpanded) {
                PullRequestContentView(pullRequest: pullRequest)
            } label: {
                PullRequestHeaderView(pullRequest: pullRequest, toggleRead: toggleRead)
            }
        }
    }
}

#Preview {
    ScrollView {
        PullRequestView(
            pullRequest: PullRequest.preview(),
            toggleRead: {},
            sectionExpanded: true
        )
    }
    .padding()
}
