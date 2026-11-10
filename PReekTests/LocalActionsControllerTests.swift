#if os(macOS)
    import Foundation
    import Testing

    @MainActor
    struct LocalActionsControllerTests {
        private final class Preparation {
            var continuation: CheckedContinuation<LocalWorkspaceService.PreparedWorkspace, Error>?
            var started: CheckedContinuation<Void, Never>?

            func suspend() async throws -> LocalWorkspaceService.PreparedWorkspace {
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                    started?.resume()
                    started = nil
                }
            }

            func waitUntilStarted() async {
                if continuation != nil {
                    return
                }
                await withCheckedContinuation { started = $0 }
            }
        }

        @MainActor
        private final class Fixture {
            let suite = "LocalActionsControllerTests.\(UUID().uuidString)"
            let defaults: UserDefaults
            let request = PullRequest(
                id: "pr", repository: Repository(name: "owner/repo", url: URL(string: "https://github.com/owner/repo")!),
                author: User(login: "author"), title: "PR", number: 1, status: .open, lastUpdated: Date(), events: [],
                url: URL(string: "https://github.com/owner/repo/pull/1")!, additions: 0, deletions: 0, approvalFrom: [], changesRequestedFrom: []
            )
            let action = LocalAgentAction(name: "Review", prompt: "Review locally", kind: .review)
            let workspace: LocalWorkspaceService.PreparedWorkspace
            let forcedWorkspace: LocalWorkspaceService.PreparedWorkspace
            var registrations: [LocalWorkspaceService.PreparedWorkspace] = []
            var handoffs: [LocalWorkspaceService.PreparedWorkspace] = []
            var errors: [Error] = []
            var warnings = 0
            var confirmations = 0
            var destructiveCalls = 0

            init() throws {
                defaults = try #require(UserDefaults(suiteName: suite))
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let root = directory.appendingPathComponent("worktrees")
                let clone = directory.appendingPathComponent("clone")
                let identity = try LocalWorkspaceService.identity(for: request.url)
                let layout = LocalWorkspaceSafety.Layout(root: root, identity: identity)
                workspace = LocalWorkspaceService.PreparedWorkspace(
                    layout: layout, clone: clone,
                    headSHA: String(repeating: "a", count: 40), baseSHA: String(repeating: "b", count: 40),
                    updateWarning: "Local changes prevented updating the PR worktree."
                )
                forcedWorkspace = LocalWorkspaceService.PreparedWorkspace(
                    layout: layout, clone: clone,
                    headSHA: String(repeating: "c", count: 40), baseSHA: String(repeating: "d", count: 40)
                )
            }

            func removePreferences() {
                defaults.removePersistentDomain(forName: suite)
            }

            func dependencies() -> LocalActionsController.Dependencies {
                .init(
                    discoverEditors: { [] },
                    chooseRepository: { _, _, _ in self.workspace.clone },
                    prepareWorkspace: { _, _, _ in self.workspace },
                    registerWorkspace: { request, workspace in
                        #expect(request.url == self.request.url)
                        self.registrations.append(workspace)
                    },
                    openEditor: { _, _ in Issue.record("An agent action opened an editor") },
                    launchAgent: { action, pullRequestURL, workspace, executable in
                        #expect(action.id == self.action.id)
                        #expect(pullRequestURL == self.request.url)
                        #expect(executable == "/opt/homebrew/bin/omp")
                        self.handoffs.append(workspace)
                    },
                    showError: { self.errors.append($0) },
                    chooseWorkspaceUpdate: { warning in
                        #expect(warning == self.workspace.updateWarning)
                        self.warnings += 1
                        return .openUnchanged
                    },
                    confirmForceUpdate: { url in
                        #expect(url == self.workspace.url)
                        self.confirmations += 1
                        return true
                    },
                    forceUpdateWorkspace: { pullRequestURL, workspace in
                        // Confirmation must precede the destructive operation.
                        #expect(self.confirmations == 1)
                        #expect(pullRequestURL == self.request.url)
                        #expect(workspace.headSHA == self.workspace.headSHA)
                        self.destructiveCalls += 1
                        return self.forcedWorkspace
                    }
                )
            }

            func controller(
                _ configure: (inout LocalActionsController.Dependencies) -> Void = { _ in }
            ) -> LocalActionsController {
                var dependencies = dependencies()
                configure(&dependencies)
                return LocalActionsController(defaults: defaults, dependencies: dependencies)
            }
        }

        @Test(arguments: [false, true])
        func cancellationDuringPreparationPreventsHandoffAndClearsBusyState(transportThrows: Bool) async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let preparation = Preparation()
            let controller = fixture.controller {
                $0.prepareWorkspace = { _, _, _ in try await preparation.suspend() }
            }
            let task = Task { await controller.launch(.agent(fixture.action), for: fixture.request) }
            await preparation.waitUntilStarted()
            #expect(controller.isPreparing(fixture.request))
            task.cancel()
            let continuation = try #require(preparation.continuation)
            if transportThrows {
                continuation.resume(throwing: URLError(.cancelled))
            } else {
                continuation.resume(returning: fixture.workspace)
            }
            #expect(await task.value == false)
            #expect(!controller.isPreparing(fixture.request))
            #expect(fixture.registrations.isEmpty)
            #expect(fixture.handoffs.isEmpty)
            #expect(fixture.errors.isEmpty)
            #expect(fixture.warnings == 0)
            #expect(fixture.confirmations == 0)
            #expect(fixture.destructiveCalls == 0)
        }

        @Test
        func openUnchangedHandsOffThePreparedSnapshotWithoutDestruction() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let controller = fixture.controller()

            #expect(await controller.launch(.agent(fixture.action), for: fixture.request))
            let actual = try #require(fixture.handoffs.first)
            #expect(fixture.handoffs.count == 1)
            #expect(actual.headSHA == fixture.workspace.headSHA)
            #expect(actual.baseSHA == fixture.workspace.baseSHA)
            #expect(actual.updateWarning == fixture.workspace.updateWarning)
            #expect(fixture.registrations.count == 1)
            #expect(fixture.warnings == 1)
            #expect(fixture.confirmations == 0)
            #expect(fixture.destructiveCalls == 0)
            #expect(fixture.errors.isEmpty)
            #expect(!controller.isPreparing(fixture.request))
        }

        @Test
        func cancelUpdateChoiceDoesNotConfirmDestroyOrHandOff() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let controller = fixture.controller { $0.chooseWorkspaceUpdate = { _ in .cancel } }

            #expect(await controller.launch(.agent(fixture.action), for: fixture.request) == false)
            #expect(fixture.registrations.count == 1)
            #expect(fixture.confirmations == 0)
            #expect(fixture.destructiveCalls == 0)
            #expect(fixture.handoffs.isEmpty)
            #expect(fixture.errors.isEmpty)
            #expect(!controller.isPreparing(fixture.request))
        }

        @Test
        func confirmedForceUpdateHandsOffItsNewSnapshotWithoutRegisteringAgain() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let controller = fixture.controller { $0.chooseWorkspaceUpdate = { _ in .forceUpdate } }

            #expect(await controller.launch(.agent(fixture.action), for: fixture.request))
            let actual = try #require(fixture.handoffs.first)
            #expect(fixture.handoffs.count == 1)
            #expect(actual.headSHA == fixture.forcedWorkspace.headSHA)
            #expect(actual.baseSHA == fixture.forcedWorkspace.baseSHA)
            #expect(actual.url == fixture.forcedWorkspace.url)
            #expect(actual.clone == fixture.forcedWorkspace.clone)
            #expect(actual.updateWarning == nil)
            #expect(fixture.registrations.count == 1)
            #expect(fixture.registrations.first?.headSHA == fixture.workspace.headSHA)
            #expect(fixture.confirmations == 1)
            #expect(fixture.destructiveCalls == 1)
            #expect(fixture.errors.isEmpty)
            #expect(!controller.isPreparing(fixture.request))
        }

        @Test
        func declinedForceConfirmationDoesNotDestroyOrHandOff() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let controller = fixture.controller {
                $0.chooseWorkspaceUpdate = { _ in .forceUpdate }
                $0.confirmForceUpdate = { _ in fixture.confirmations += 1; return false }
            }

            #expect(await controller.launch(.agent(fixture.action), for: fixture.request) == false)
            #expect(fixture.registrations.count == 1)
            #expect(fixture.confirmations == 1)
            #expect(fixture.destructiveCalls == 0)
            #expect(fixture.handoffs.isEmpty)
            #expect(fixture.errors.isEmpty)
            #expect(!controller.isPreparing(fixture.request))
        }

        @Test
        func forceUpdateFailureIsDisplayedWithoutHandoffOrSecondRegistration() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let controller = fixture.controller {
                $0.chooseWorkspaceUpdate = { _ in .forceUpdate }
                $0.forceUpdateWorkspace = { _, _ in
                    #expect(fixture.confirmations == 1)
                    fixture.destructiveCalls += 1
                    throw LocalActionError(message: "Fetch failed")
                }
            }

            #expect(await controller.launch(.agent(fixture.action), for: fixture.request) == false)
            #expect(fixture.registrations.count == 1)
            #expect(fixture.destructiveCalls == 1)
            #expect(fixture.handoffs.isEmpty)
            #expect(fixture.errors.count == 1)
            #expect(fixture.errors.first?.localizedDescription == "Fetch failed")
            #expect(!controller.isPreparing(fixture.request))
        }

        @Test
        func cancellationInUpdateDialogPreventsConfirmationAndDestruction() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let controller = fixture.controller {
                $0.chooseWorkspaceUpdate = { _ in
                    withUnsafeCurrentTask { $0?.cancel() }
                    return .forceUpdate
                }
            }
            let task = Task { await controller.launch(.agent(fixture.action), for: fixture.request) }

            #expect(await task.value == false)
            #expect(fixture.registrations.count == 1)
            #expect(fixture.confirmations == 0)
            #expect(fixture.destructiveCalls == 0)
            #expect(fixture.handoffs.isEmpty)
            #expect(fixture.errors.isEmpty)
            #expect(!controller.isPreparing(fixture.request))
        }

        @Test
        func cancellationInForceConfirmationPreventsDestruction() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let controller = fixture.controller {
                $0.chooseWorkspaceUpdate = { _ in .forceUpdate }
                $0.confirmForceUpdate = { _ in
                    fixture.confirmations += 1
                    withUnsafeCurrentTask { $0?.cancel() }
                    return true
                }
            }
            let task = Task { await controller.launch(.agent(fixture.action), for: fixture.request) }

            #expect(await task.value == false)
            #expect(fixture.registrations.count == 1)
            #expect(fixture.confirmations == 1)
            #expect(fixture.destructiveCalls == 0)
            #expect(fixture.handoffs.isEmpty)
            #expect(fixture.errors.isEmpty)
            #expect(!controller.isPreparing(fixture.request))
        }

        @Test
        func registrationFailureStopsLaunchAndDisplaysTheError() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let controller = fixture.controller {
                $0.registerWorkspace = { _, _ in throw LocalActionError(message: "Registry unavailable") }
            }

            #expect(await controller.launch(.agent(fixture.action), for: fixture.request) == false)
            #expect(fixture.handoffs.isEmpty)
            #expect(fixture.errors.count == 1)
            #expect(fixture.errors.first?.localizedDescription == "Registry unavailable")
            #expect(fixture.warnings == 0)
            #expect(fixture.confirmations == 0)
            #expect(fixture.destructiveCalls == 0)
            #expect(!controller.isPreparing(fixture.request))
        }

        @Test
        func invalidRepositoryIsReplacedByTheCanonicalPickerSelection() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let key = "github.com/owner/repo"
            let invalidClone = fixture.workspace.clone
            let selectedClone = invalidClone.appendingPathComponent("../replacement", isDirectory: true)
            let canonicalClone = selectedClone.resolvingSymlinksInPath()
            try fixture.defaults.set(
                JSONEncoder().encode([LocalRepositoryMapping(id: key, path: invalidClone.path)]),
                forKey: LocalActionsController.Preference.repositoryMappings.key
            )
            var attempts: [URL] = []
            var pickerReasons: [String?] = []
            let controller = fixture.controller {
                $0.chooseRepository = { actualKey, reason, _ in
                    #expect(actualKey == key)
                    pickerReasons.append(reason)
                    return selectedClone
                }
                $0.prepareWorkspace = { _, clone, _ in
                    attempts.append(clone)
                    if clone.path == invalidClone.path {
                        throw LocalWorkspaceService.InvalidRepository(message: "The saved clone has the wrong origin")
                    }
                    return fixture.workspace
                }
            }

            #expect(await controller.launch(.agent(fixture.action), for: fixture.request))
            #expect(attempts.map(\.path) == [invalidClone.path, canonicalClone.path])
            #expect(pickerReasons.count == 1)
            #expect(pickerReasons.first == "The saved clone has the wrong origin")
            #expect(controller.repositoryMappings == [LocalRepositoryMapping(id: key, path: canonicalClone.path)])
            #expect(fixture.registrations.count == 1)
            #expect(fixture.handoffs.count == 1)
            #expect(fixture.errors.isEmpty)
        }

        @Test
        func cancelingReplacementPickerStillForgetsTheInvalidRepository() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let key = "github.com/owner/repo"
            try fixture.defaults.set(
                JSONEncoder().encode([LocalRepositoryMapping(id: key, path: fixture.workspace.clone.path)]),
                forKey: LocalActionsController.Preference.repositoryMappings.key
            )
            var pickerReasons: [String?] = []
            let controller = fixture.controller {
                $0.chooseRepository = { _, reason, _ in pickerReasons.append(reason); return nil }
                $0.prepareWorkspace = { _, _, _ in
                    throw LocalWorkspaceService.InvalidRepository(message: "The clone was removed")
                }
            }

            #expect(await controller.launch(.agent(fixture.action), for: fixture.request) == false)
            #expect(controller.repositoryMappings.isEmpty)
            #expect(pickerReasons.count == 1)
            #expect(pickerReasons.first == "The clone was removed")
            let storedMappings = try JSONDecoder().decode(
                [LocalRepositoryMapping].self,
                from: #require(fixture.defaults.data(forKey: LocalActionsController.Preference.repositoryMappings.key))
            )
            #expect(storedMappings.isEmpty)
            #expect(fixture.registrations.isEmpty)
            #expect(fixture.handoffs.isEmpty)
            #expect(fixture.errors.isEmpty)
            #expect(!controller.isPreparing(fixture.request))
        }

        @Test
        func cancellationDuringRegistrationPreventsDialogsAndHandoff() async throws {
            let fixture = try Fixture()
            defer { fixture.removePreferences() }
            let controller = fixture.controller {
                $0.registerWorkspace = { _, workspace in
                    fixture.registrations.append(workspace)
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
            let task = Task { await controller.launch(.agent(fixture.action), for: fixture.request) }

            #expect(await task.value == false)
            #expect(fixture.registrations.count == 1)
            #expect(fixture.warnings == 0)
            #expect(fixture.confirmations == 0)
            #expect(fixture.destructiveCalls == 0)
            #expect(fixture.handoffs.isEmpty)
            #expect(fixture.errors.isEmpty)
            #expect(!controller.isPreparing(fixture.request))
        }
    }
#endif
