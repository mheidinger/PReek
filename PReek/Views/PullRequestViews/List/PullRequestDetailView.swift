import SwiftUI

struct PullRequestDetailView: View {
    var pullRequest: PullRequest
    var setRead: (PullRequest.ID, Bool) -> Void

    @Binding private var setUnreadOnChange: Bool

    @Environment(\.dismiss) private var dismiss
    
    @State var showNavigationHeader: Bool = false
    
    init(_ pullRequest: PullRequest, setRead: @escaping (PullRequest.ID, Bool) -> Void, setUnreadOnChange: Binding<Bool>) {
        self.pullRequest = pullRequest
        self.setRead = setRead
        _setUnreadOnChange = setUnreadOnChange
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack {
                    header

                    Divider()
                    
                    LazyVStack {
                        DividedView(pullRequest.events) { event in
                            EventView(event)
                        } shouldHighlight: { event in
                            event.id == pullRequest.oldestUnreadEvent?.id ? String(localized: "New") : nil
                        }
                    }
                    .padding([.leading, .trailing, .bottom])
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading) {
                        Text(pullRequest.repository.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(pullRequest.title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .opacity(showNavigationHeader ? 1 : 0)
                    .frame(maxWidth: geometry.size.width * 0.5)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Mark unread") {
                        setUnreadOnChange = true
                        dismiss()
                    }
                }
            }
        }
    }
    
    var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pullRequest.repository.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(pullRequest.numberFormatted)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                StatusLabel(pullRequest.status)
            }
            
            Text(pullRequest.title)
                .font(.title3)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .onScrollVisibilityChange { isVisible in
                    withAnimation {
                        showNavigationHeader = !isVisible
                    }
                }
            
            HStack {
                Text("by \(pullRequest.author.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                TimeSensitiveText(getText: { pullRequest.lastUpdatedFormatted })
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                HStack {
                    Text(pullRequest.additionsFormatted)
                        .foregroundColor(.green)
                    Text(pullRequest.deletionsFormatted)
                        .foregroundColor(.red)
                }
                .font(.subheadline)
                
                Spacer()
                
                HoverableLink(destination: pullRequest.url) {
                    Image(systemName: "arrow.up.forward.square")
                }
            }
        }
        .padding([.top, .leading, .trailing])
    }
}

#Preview {
    NavigationStack {
        PullRequestDetailView(PullRequest.preview(id: "1", title: "long long long long long long long long long"), setRead: { _, _ in }, setUnreadOnChange: .constant(false))
    }
}
