import SwiftUI

struct PullRequestsList<Footer: View>: View {
    @ObservedObject var pullRequestsViewModel: PullRequestsViewModel
    @ViewBuilder let footer: () -> Footer

    #if os(iOS)
        @EnvironmentObject private var configViewModel: ConfigViewModel
        @State private var showSettings = false
    #endif

    var pullRequests: [PullRequest] {
        pullRequestsViewModel.pullRequests
    }

    // Retain the displayed snapshot if a filter or refresh removes its row.
    @State private var selectedPullRequest: PullRequest?
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    @State private var explicitlyUnreadID: PullRequest.ID?
    @State private var showFilterSheet = false

    init(pullRequestsViewModel: PullRequestsViewModel, @ViewBuilder footer: @escaping () -> Footer) {
        self.pullRequestsViewModel = pullRequestsViewModel
        self.footer = footer
    }

    private var selection: Binding<PullRequest.ID?> {
        Binding(
            get: { selectedPullRequest?.id },
            set: { id in
                selectedPullRequest = pullRequests.first { $0.id == id }
            }
        )
    }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
            List(selection: selection) {
                if let error = pullRequestsViewModel.error, !pullRequests.isEmpty {
                    Section {
                        Label("No Connection", systemImage: "icloud.slash")
                        Text(error.localizedDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(pullRequests) { pullRequest in
                        NavigationLink(value: pullRequest.id) {
                            PullRequestListItem(pullRequest)
                                .equatable()
                        }
                        .contextMenu {
                            readButton(for: pullRequest)
                        }
                        .swipeActions {
                            readButton(for: pullRequest)
                                .tint(.accentColor)
                        }
                    }
                } footer: {
                    if !pullRequests.isEmpty {
                        footer()
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .overlay {
                if pullRequests.isEmpty {
                    emptyContent
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if pullRequests.isEmpty {
                    footer()
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .navigationTitle("Pull Requests")
            #if os(iOS)
                .toolbarTitleDisplayMode(.inlineLarge)
                .navigationDestination(isPresented: $showSettings) {
                    SettingsScreen(configViewModel: configViewModel)
                }
                .navigationDestination(for: Screen.self) { _ in
                    ExcludedUsersScreen(configViewModel: configViewModel)
                }
            #endif
                .refreshable {
                    await pullRequestsViewModel.updatePullRequestsAndApply()
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Filters", systemImage: "line.3.horizontal.decrease.circle") {
                                showFilterSheet = true
                            }

                            Button("Mark all as read", systemImage: "checkmark.circle") {
                                pullRequestsViewModel.markAllAsRead()
                            }
                            .disabled(!pullRequestsViewModel.hasUnread)

                            #if os(iOS)
                                Divider()
                                Button("Settings", systemImage: "gear") {
                                    showSettings = true
                                }
                            #endif
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showFilterSheet) {
                    NavigationStack {
                        Form {
                            Toggle("Show closed", isOn: $pullRequestsViewModel.showClosed)
                            Toggle("Show read", isOn: $pullRequestsViewModel.showRead)
                        }
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .navigationTitle("Filters")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showFilterSheet = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
        } detail: {
            if let selectedPullRequest {
                PullRequestDetailView(
                    selectedPullRequest,
                    onMarkUnread: {
                        markUnread(selectedPullRequest.id)
                    }
                )
                .id(selectedPullRequest.id)
                .onDisappear {
                    // Compact Back and tab changes can hide detail without changing selection.
                    if self.selectedPullRequest?.id == selectedPullRequest.id,
                       explicitlyUnreadID != selectedPullRequest.id
                    {
                        pullRequestsViewModel.setRead(selectedPullRequest.id, read: true)
                    }
                }
            } else {
                ContentUnavailableView("Select a pull request", systemImage: "arrow.triangle.pull")
            }
        }
        .onChange(of: selectedPullRequest?.id) { previousID, _ in
            // A regular-width split updates detail in place; it need not disappear.
            guard let previousID else { return }
            if explicitlyUnreadID != previousID {
                pullRequestsViewModel.setRead(previousID, read: true)
            }
            explicitlyUnreadID = nil
        }
    }

    private func readButton(for pullRequest: PullRequest) -> some View {
        Button(pullRequest.unread ? String(localized: "Mark read") : String(localized: "Mark unread"), systemImage: pullRequest.unread ? "envelope.open" : "envelope.badge") {
            if selectedPullRequest?.id == pullRequest.id, !pullRequest.unread {
                markUnread(pullRequest.id)
            } else {
                pullRequestsViewModel.setRead(pullRequest.id, read: pullRequest.unread)
            }
        }
    }

    private func markUnread(_ id: PullRequest.ID) {
        explicitlyUnreadID = id
        pullRequestsViewModel.setRead(id, read: false)
        selectedPullRequest = nil
        preferredCompactColumn = .sidebar
    }

    @ViewBuilder
    private var emptyContent: some View {
        if let error = pullRequestsViewModel.error {
            ContentUnavailableView {
                Label("No Connection", systemImage: "icloud.slash")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Refresh") {
                    pullRequestsViewModel.triggerManualUpdatePullRequests()
                }
                .disabled(pullRequestsViewModel.isRefreshing)
            }
        } else if pullRequestsViewModel.isRefreshing {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading Pull Requests...")
                    .foregroundStyle(.secondary)
            }
        } else {
            ContentUnavailableView {
                Label("You are done for today! 🎉", systemImage: "checkmark.circle")
            } description: {
                Text("No pull requests match your filters.")
            }
        }
    }
}

#Preview {
    @ObservedObject var pullRequestsViewModel = PullRequestsViewModel(initialPullRequests: [
        PullRequest.preview(id: "1", title: "short"),
        PullRequest.preview(id: "2", title: "long long long long long long long long long long long long long long long long long long long"),
        PullRequest.preview(id: "3", lastUpdated: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
        PullRequest.preview(id: "4", lastUpdated: Calendar.current.date(byAdding: .day, value: -3, to: Date())!),
        PullRequest.preview(id: "5"),
        PullRequest.preview(id: "6"),
        PullRequest.preview(id: "7"),
        PullRequest.preview(id: "8"),
        PullRequest.preview(id: "9"),
        PullRequest.preview(id: "10"),
        PullRequest.preview(id: "11"),
        PullRequest.preview(id: "12"),
        PullRequest.preview(id: "13"),
        PullRequest.preview(id: "14"),
        PullRequest.preview(id: "15"),
        PullRequest.preview(id: "16"),
        PullRequest.preview(id: "17"),
        PullRequest.preview(id: "18"),
    ])
    return PullRequestsList(pullRequestsViewModel: pullRequestsViewModel, footer: { Text("Footer") })
        .environmentObject(ConfigViewModel())
}
