import SwiftUI
import TipKit

struct MarkAllAsReadTip: Tip {
    @Parameter
    static var triggerTip: Bool = false

    var rules: [Rule] {
        [
            #Rule(Self.$triggerTip) {
                $0 == true
            },
        ]
    }

    var title: Text {
        Text("Mark All as Read")
    }

    var message: Text? {
        Text("Click the icon again to confirm the action.")
    }
}

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

private struct StatusBarNavigationLink<Destination: Hashable>: View {
    var imageSystemName: String
    var destination: Destination

    var body: some View {
        NavigationLink(value: destination) {
            Image(systemName: imageSystemName)
                .font(.title)
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding(.vertical, 3)
    }
}

struct StatusBarView: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel

    @State private var showFilterPopover: Bool = false
    @State private var markAllAsReadClickedOnce = false
    @State private var markAllAsReadClickedOnceResetTask: Task<Void, Never>?

    var markAllAsReadTip = MarkAllAsReadTip()

    private func markAllAsRead() {
        if markAllAsReadClickedOnce {
            pullRequestsViewModel.markAllAsRead()
            markAllAsReadClickedOnce = false
            markAllAsReadTip.invalidate(reason: .actionPerformed)
        } else {
            MarkAllAsReadTip.triggerTip = true
            markAllAsReadClickedOnce = true
        }
    }

    var body: some View {
        HStack {
            StatusBarButton(imageSystemName: "line.3.horizontal.decrease.circle", action: { showFilterPopover = true })
                .help("Filters")
                .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
                    filterPopover
                }
            StatusBarButton(imageSystemName: "eye.circle", action: markAllAsRead)
                .if(markAllAsReadClickedOnce) { view in
                    view
                        .foregroundStyle(.accent)
                }
                .help("Mark all as read")
                .popoverTip(markAllAsReadTip)
                .onChange(of: markAllAsReadClickedOnce) {
                    markAllAsReadClickedOnceResetTask?.cancel()

                    if markAllAsReadClickedOnce {
                        markAllAsReadClickedOnceResetTask = Task {
                            try? await Task.sleep(for: .seconds(2))

                            if markAllAsReadClickedOnce {
                                markAllAsReadClickedOnce = false
                            }
                        }
                    }
                }

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

            StatusBarNavigationLink(imageSystemName: "gear", destination: Screen.settings)
                .help("Settings")
                .keyboardShortcut(",")
        }
        .padding(.horizontal)
    }

    var filterPopover: some View {
        Form {
            Toggle(isOn: $pullRequestsViewModel.showClosed) {
                Text("Show closed")
            }
            Toggle(isOn: $pullRequestsViewModel.showRead) {
                Text("Show read")
            }
        }
        .toggleStyle(.switch)
        .padding()
    }
}

#Preview {
    StatusBarView(pullRequestsViewModel: PullRequestsViewModel())
        .onAppear {
            try? Tips.resetDatastore()
            try? Tips.configure()
        }
}
