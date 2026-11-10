#if os(macOS)
    import AppKit
    import SwiftUI

    @MainActor
    struct LocalActionsMenu: View {
        let pullRequest: PullRequest
        var viewerLogin: String?

        @ObservedObject private var localActions = LocalActionsController.shared
        @Environment(\.externalActionCompleted) private var externalActionCompleted

        private var defaultAgentAction: LocalAgentAction? {
            let isOwnPullRequest = viewerLogin.map {
                $0.caseInsensitiveCompare(pullRequest.author.login) == .orderedSame
            } ?? false
            return localActions.agentActions.first { $0.kind == (isOwnPullRequest ? .address : .review) }
        }

        var body: some View {
            if !pullRequest.isClosed {
                HStack(spacing: 0) {
                    if localActions.isPreparing(pullRequest) {
                        preparationIndicator
                    } else {
                        editorButton
                        separator
                        agentButton
                        separator
                        agentActionsMenu
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .fixedSize()
                .disabled(localActions.isPreparing(pullRequest))
            }
        }

        private var preparationIndicator: some View {
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Preparing…").font(.caption)
            }
            .padding(.horizontal, 5)
            .frame(height: 18)
        }

        private var editorButton: some View {
            Button {
                launch(.editor)
            } label: {
                Group {
                    if let editor = localActions.selectedEditor {
                        Image(nsImage: editor.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "macwindow")
                    }
                }
                .frame(width: 21, height: 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(localActions.selectedEditor == nil)
            .help(localActions.editorActionTitle)
            .accessibilityLabel(localActions.editorActionTitle)
        }

        private var agentButton: some View {
            Button {
                if let action = defaultAgentAction {
                    launch(.agent(action))
                }
            } label: {
                Image("AgentRobot")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .frame(width: 21, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(defaultAgentAction?.hasPrompt != true)
            .help(defaultAgentAction?.displayName ?? "Local agent")
            .accessibilityLabel(defaultAgentAction?.displayName ?? "Local agent")
        }

        private var agentActionsMenu: some View {
            Menu {
                ForEach(localActions.agentActions) { action in
                    Button(action.displayName) { launch(.agent(action)) }
                        .disabled(!action.hasPrompt)
                }
                Divider()
                Button("Custom prompt…") {
                    LocalAgentPromptWindowController.present(for: pullRequest, actionCompleted: externalActionCompleted)
                }
            } label: {
                Image(systemName: "chevron.down").frame(width: 13, height: 18)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More local agent actions")
            .help("More local agent actions")
        }

        private var separator: some View {
            Rectangle()
                .fill(Color.primary.opacity(0.22))
                .frame(width: 1, height: 18)
        }

        private func launch(_ destination: LocalActionsController.Destination) {
            let modifierPressed = NSEvent.modifierFlags.contains(.command)
            Task {
                if await localActions.launch(destination, for: pullRequest) {
                    externalActionCompleted(modifierPressed)
                }
            }
        }
    }
#endif
