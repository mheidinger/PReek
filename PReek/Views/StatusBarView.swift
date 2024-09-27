import SwiftUI

private struct StatusBarButton: View {
    var imageSystemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: imageSystemName)
                .font(.title)
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding(.vertical, 3)
    }
}

struct StatusBarView: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    let openSettings: () -> Void

    @State private var showFilterPopover: Bool = false

    var body: some View {
        HStack {
            StatusBarButton(imageSystemName: "line.3.horizontal.decrease.circle", action: { showFilterPopover = true })
                .help("Filters")
                .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
                    filterPopover
                }
            StatusBarButton(imageSystemName: "eye.circle", action: pullRequestsViewModel.markAllAsRead)
                .help("Mark all as read")

            Spacer()

            if let error = pullRequestsViewModel.error {
                Text("Failed to fetch notifications")
                    .foregroundStyle(.red)
                    .help(error.localizedDescription)
            } else {
                Text("Last updated at \(pullRequestsViewModel.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "...")")
                    .foregroundStyle(.secondary)
            }
            Group {
                if pullRequestsViewModel.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.leading, -4)
                } else {
                    StatusBarButton(imageSystemName: "arrow.clockwise.circle", action: pullRequestsViewModel.triggerUpdatePullRequests)
                        .help("Refresh")
                        .keyboardShortcut("r")
                }
            }
            .frame(width: 25, alignment: .leading)

            StatusBarButton(imageSystemName: "gear", action: openSettings)
                .help("Settings")
                .keyboardShortcut(",")
        }
        .padding(.horizontal)
    }

    var filterPopover: some View {
        Form {
            Toggle(isOn: $pullRequestsViewModel.hideClosed) {
                Text("Hide closed")
            }
            Toggle(isOn: $pullRequestsViewModel.hideRead) {
                Text("Hide read")
            }
        }
        .toggleStyle(.switch)
        .padding()
    }
}

#Preview {
    StatusBarView(
        pullRequestsViewModel: PullRequestsViewModel(), openSettings: {}
    )
}
