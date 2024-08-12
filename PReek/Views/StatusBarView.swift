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

private struct PopoverFilterOption: View {
    var label: LocalizedStringKey
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle(isOn: $isOn) {
                Text(label)
            }
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle())
        }
    }
}

struct StatusBarView<ViewModel: PullRequestsViewModelProtocol>: View {
    @ObservedObject var pullRequestsViewModel: ViewModel
    @Binding var settingsOpen: Bool
    
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
            
            if pullRequestsViewModel.hasError {
                Text("Failed to fetch notifications")
                    .foregroundStyle(.red)
            } else {
                Text("Last updated at \(pullRequestsViewModel.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "...")")
                    .foregroundStyle(.secondary)
            }
            Group {
                if pullRequestsViewModel.isRefreshing && !pullRequestsViewModel.hasError {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.leading, -4)
                } else {
                    StatusBarButton(imageSystemName: "arrow.clockwise.circle", action: pullRequestsViewModel.triggerUpdatePullRequests)
                        .help("Refresh")
                }
            }
            .frame(width: 25, alignment: .leading)
            
            StatusBarButton(imageSystemName: "gear", action: {
                settingsOpen = true
            })
            .help("Settings")
        }
        .padding(.horizontal)
        .background(.background.opacity(0.5))
    }
    
    var filterPopover: some View {
        VStack(alignment: .leading) {
            PopoverFilterOption(label: "Hide closed", isOn: $pullRequestsViewModel.hideClosed)
            PopoverFilterOption(label: "Hide read", isOn: $pullRequestsViewModel.hideRead)
        }
        .padding()
    }
}

#Preview {
    StatusBarView(
        pullRequestsViewModel: MockPullRequestsViewModel(),
        settingsOpen: .constant(false)
    )
}
