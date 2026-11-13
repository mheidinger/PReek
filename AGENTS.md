# AGENTS.md

This file provides guidance to coding agents working in this repository.

## Project Overview

PReek is a macOS/iOS SwiftUI application that brings GitHub Pull Request notifications directly into the macOS MenuBar. It fetches pull requests based on GitHub notifications and displays them in a clean, organized interface.

## Editing and Verification Rules

- Preserve unrelated user changes. Scope edits and verification to the task; do not run repository-wide formatters or broad suites by default.
- Do not create, modify, rename, or delete any README or changelog file unless the user explicitly requests it, regardless of filename casing or variant.
- Follow existing SwiftUI platform guards, Swift Testing conventions, and injected side-effect boundaries. UI strings are maintained in `Localizable.xcstrings`.
- Build/test in agent-owned DerivedData directories; do not overwrite the user's builds. Avoid `clean` for routine incremental verification.
- Use the narrowest behavioral test or off-screen render that covers the change. A build proves compilation, not UI behavior. Report unverified behavior explicitly.

## Development Commands

### Building

Use a disposable build directory. Reuse it for related checks during the task, then remove only your own artifacts.

```bash
BUILD_DIR="$(mktemp -d /tmp/preek-build.XXXXXX)"

# Build for macOS
xcodebuild build -scheme PReek -project PReek.xcodeproj \
  -destination 'platform=macOS,arch=arm64' -configuration Debug \
  -derivedDataPath "$BUILD_DIR" CODE_SIGNING_ALLOWED=NO

# Build for iOS (no simulator or device launch)
xcodebuild build -scheme PReek -project PReek.xcodeproj \
  -destination 'generic/platform=iOS' -configuration Debug \
  -derivedDataPath "$BUILD_DIR" CODE_SIGNING_ALLOWED=NO

# Static analysis, when relevant to the change
xcodebuild build analyze -scheme PReek -project PReek.xcodeproj \
  -destination 'platform=macOS,arch=arm64' -configuration Debug \
  -derivedDataPath "$BUILD_DIR" CODE_SIGNING_ALLOWED=NO
```

### Testing

`PReekTests` is a hostless unit-test bundle using Swift Testing (`import Testing`, `@Test`, `#expect`). It compiles selected app sources directly; new test dependencies may need membership in the test target's synchronized-folder exception list in `PReek.xcodeproj/project.pbxproj`.

```bash
TEST_BUILD_DIR="$(mktemp -d /tmp/preek-tests.XXXXXX)"

# Run the relevant suite; replace the selector with the suite covering your change
xcodebuild test -scheme PReek -project PReek.xcodeproj \
  -destination 'platform=macOS,arch=arm64' -configuration Debug \
  -derivedDataPath "$TEST_BUILD_DIR" \
  -only-testing:PReekTests/PullRequestUnreadTests CODE_SIGNING_ALLOWED=NO

# Full suite only when the scope warrants it or the user requests it
xcodebuild test -scheme PReek -project PReek.xcodeproj \
  -destination 'platform=macOS,arch=arm64' -configuration Debug \
  -derivedDataPath "$TEST_BUILD_DIR" CODE_SIGNING_ALLOWED=NO
```

When piping output through `xcpretty`, preserve the `xcodebuild` exit status (for example, with `set -o pipefail`). CI builds/analyzes macOS and iOS, runs macOS tests, and separately runs `swiftformat --lint . --reporter github-actions-log`. For local formatting checks, scope `swiftformat --lint` to touched Swift files.

### UI Verification (Agents)

**Do not interrupt the user's desktop.** Unless explicitly authorized, never launch PReek normally, activate a host application, open Xcode or Simulator/Device Hub, automate global mouse/keyboard input, or capture the desktop or a window from the user's session. Headless `simctl` operation of a dedicated agent-owned iOS simulator is permitted as described below. Do not kill, replace, or manipulate the user's running PReek instance. `open -g` and another Space are not isolation.

Use the Debug/macOS off-screen renderer for routine layout checks. Build into a disposable directory so the user's builds are not overwritten, then invoke the executable directly with `--render-ui` (not `open`):

```bash
UI_BUILD_DIR="$(mktemp -d /tmp/preek-ui.XXXXXX)"
export LLVM_PROFILE_FILE="$UI_BUILD_DIR/profile-%p.profraw"
xcodebuild build -scheme PReek -project PReek.xcodeproj \
  -destination 'platform=macOS,arch=arm64' -configuration Debug \
  -derivedDataPath "$UI_BUILD_DIR/DerivedData" CODE_SIGNING_ALLOWED=NO -quiet
"$UI_BUILD_DIR/DerivedData/Build/Products/Debug/PReek.app/Contents/MacOS/PReek" \
  --render-ui settings --section github --appearance dark \
  --output "$UI_BUILD_DIR/settings-github-dark.png"
"$UI_BUILD_DIR/DerivedData/Build/Products/Debug/PReek.app/Contents/MacOS/PReek" \
  --render-ui main --state loaded --appearance light \
  --output "$UI_BUILD_DIR/main-loaded-light.png"
```

- Settings sections: `general`, `github`, `pull-requests`, `local-actions`, `about`.
- Main states: `loaded`, `empty`, `loading`, `error`.
- Use `--width`, `--height`, and `--scale` for size checks; settings minimum is 780×560 points. A taller local-actions render (e.g. `--height 1200`) exposes the repository mappings below the initial viewport. `--render-ui --help` lists the complete contract.
- The renderer dispatches before `PReekApp` construction and shares `DebugOfflineSession` / `DebugOfflineRoot` with the interactive offline debug mode below. It uses synthetic data, an in-memory configuration store, process-unique preferences and a disposable TipKit datastore. External URLs and local launches are disabled; injected local-action dependencies also reject external operations. No real GitHub token, Keychain access, installed editor, startup setting, or workspace is needed. Invalid render requests and Release-build render requests fail instead of launching the normal app.
- Inspect the generated view-only PNG with an image-reading tool. A successful command or nonempty file is not visual verification: check the requested state, text wrapping, clipping, and controls. Check light/dark and relevant sizes for changed surfaces; do not generate every scenario routinely.
- JSON output must report `visibleWindows: 0`, `applicationActive: false`, and `activationProhibited: true`. `foregroundUnchanged` is observational: a user switching applications during the render can change it without the renderer activating anything.
- **Fidelity limit:** these are native view bitmaps, not WindowServer screenshots. On macOS 27 the sidebar selection can render black (hiding its light-mode label), and native switch tint can differ. Do not approve selection contrast, translucency/glass, animation timing, or active-window appearance from these images. Do not modify production styling just to hide a capture artifact.
- Focus, shortcuts, menu tracking, popover/sheet presentation and dismissal, and compositor effects require a separately provisioned macOS graphical session (VM or dedicated test Mac). If that is unavailable, report the specific unverified behavior; do not fall back to the user's desktop.
- Existing Xcode previews and the preview environment variable are not isolation guarantees; some previews construct live services or initiate fetching. The supported agent path is `--render-ui`.
- Remove only your own disposable build/render files after inspection. Never commit generated PNGs or introduce pixel baselines without a specific need.

### Offline Debug Mode (iOS and macOS)

**A Debug build alone is not isolated.** Pass `--debug-offline` explicitly. The entry point validates this request before constructing the live app, menu bar delegate, credential storage, or GitHub services. Invalid requests and Release-build requests exit with an error, never fall back to a live launch.

```text
PReek --debug-offline [--screen main|settings|welcome] [--state loaded|empty|loading|error]
PReek --debug-offline --help
```

- Defaults: `--screen main --state loaded`. The main screen uses the real platform-specific content, including the iOS tab/list navigation.
- `welcome` starts without a token; other screens use an explicitly synthetic token and `.invalid` enterprise URL. Never enter real credentials into fixtures or screenshots.
- Configuration edits, filters, exclusions, read/unread state, and import/share operate on isolated data. QR import uses a sample-configuration button instead of requesting camera access.
- Refresh and connection checks use the selected synthetic snapshot, not GitHub. No fetch timer, retention, or live workspace cleanup runs. `loading` initially shows progress; an explicit refresh resolves to loaded data. `error` retains the synthetic failure; `empty` stays empty.
- External URLs, local editor/agent launches, and repository pickers are disabled. Local settings use synthetic editor/repository data; launch-at-login changes only an in-memory binding.
- Preferences use a fresh `de.max-heidinger.PReek.DebugOffline.<UUID>` domain per session; TipKit and the local workspace registry use a disposable directory. Off-screen rendering removes these on completion; interactive macOS removes them on normal termination. Force-killed sessions may leave disposable files/domains, not changes to live settings.
- When invoking a coverage-instrumented macOS executable directly, set `LLVM_PROFILE_FILE` to an agent-owned temporary path, as in the render example, so it does not write `default.profraw` into the checkout.
- On macOS, interactive offline mode opens a separate debug window; it does not create the production menu bar item. Use it only with explicit desktop authorization or in a dedicated graphical session. It does not prove production popover/menu behavior.
- For unattended macOS verification, keep using `--render-ui` above: it exercises the same offline session and views without showing a window. Do not use `open`, even with `-g`, as a substitute.

### iOS Simulator Verification (Agents)

The workstation has Xcode 27.2 and iOS 27.2 runtimes. This is an inventory, not a version requirement: rediscover installed versions and device types with `xcodebuild -version`, `xcrun simctl list runtimes`, and `xcrun simctl list devicetypes`. The app currently targets iOS 26.0+ and supports both iPhone and iPad.

- Do not download runtimes, install automation software, change global Xcode selection, or alter signing/accounts without authorization.
- Create a dedicated agent-owned simulator; use its explicit UDID for every command, never the ambiguous `booted` alias. Do not reuse, erase, terminate apps on, shut down, or delete a user's simulator or physical device.
- Boot and launch through `simctl`, directly or through the headless MCP workflow below, without opening Simulator/Device Hub or Xcode. Input and captures must target the simulator, not global host input or desktop screenshots. If a tool requires foreground UI or host permissions, stop that verification path and report the limitation.
- A typical isolated run, using an installed compatible runtime/device type:

```bash
IOS_BUILD_DIR="$(mktemp -d /tmp/preek-ios.XXXXXX)"
SIM_ID="$(xcrun simctl create "PReek Agent $(date +%s)" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17 \
  com.apple.CoreSimulator.SimRuntime.iOS-27-2)"
xcrun simctl boot "$SIM_ID"
xcrun simctl bootstatus "$SIM_ID" -b
xcodebuild build -scheme PReek -project PReek.xcodeproj \
  -destination "platform=iOS Simulator,id=$SIM_ID" -configuration Debug \
  -derivedDataPath "$IOS_BUILD_DIR/DerivedData" CODE_SIGNING_ALLOWED=NO -quiet
xcrun simctl install "$SIM_ID" \
  "$IOS_BUILD_DIR/DerivedData/Build/Products/Debug-iphonesimulator/PReek.app"
xcrun simctl launch --terminate-running-process "$SIM_ID" de.max-heidinger.PReek \
  --debug-offline --screen main --state loaded
xcrun simctl io "$SIM_ID" screenshot "$IOS_BUILD_DIR/main-loaded.png"

# Only after inspecting the captured evidence:
xcrun simctl shutdown "$SIM_ID"
xcrun simctl delete "$SIM_ID"
rm -rf "$IOS_BUILD_DIR"
```

- Wait for the requested screen to finish appearing before capture; inspect the PNG with an image-reading tool. Command success, an installed app, or a passing build is not behavioral/visual proof.
- A fresh runtime's first boot and installation can take several minutes. If an install command times out, inspect `xcrun simctl appinfo "$SIM_ID" de.max-heidinger.PReek` before deciding whether installation failed; the app may already be installed. Do not open the host frontend as a workaround.
- Relaunch with `--screen settings` or `--screen welcome`, or a different `--state`, to inspect that scenario without live credentials. Each launch gets a fresh isolated session.
- Cover relevant iPhone/iPad sizes, light/dark appearance, larger Dynamic Type, and English/German when affected; do not generate every combination routinely. Keyboard/focus behavior, live GitHub integration, and physical camera scanning require separate verification; report what was not exercised.
- Preserve useful failure evidence until reported. Remove only your own simulator and disposable build/render artifacts. Never commit generated captures.

### MobileBuildMCP and Local AXe

#### Project configuration and activation

- `.omp/mcp.json` registers MobileBuildMCP **2.7.1** for this project only, using `npx`. It is not a user-global registration. `cwd` is omitted intentionally: OMP defaults it to the project directory. Start OMP in this checkout with Node/npm on PATH; the npm path requires Node 18+. First connection may download/cache the pinned package.
- `.mobilebuildmcp/config.yaml` enables only simulator, UI-automation and debugging workflows, with project `./PReek.xcodeproj`, scheme `PReek`, configuration `Debug`. These paths resolve from the project root.
- The server environment sets `MOBILEBUILDMCP_HEADLESS_LAUNCH=1` and `MOBILEBUILDMCP_SENTRY_DISABLED=true`; project configuration also sets `sentryDisabled: true`. Preserve these settings. Headless suppresses Simulator/Device Hub opening; it does not isolate app data, networking, Keychain or app-initiated effects. Always use `--debug-offline`.
- After changing the project config or AXe path, use `/mcp reconnect MobileBuildMCP` (or `/mcp reload`). The server caches configuration at startup; an already-connected server can still use the old executable. `/mcp list` and `/mcp test MobileBuildMCP` check discovery/connectivity, not UI compatibility.
- Xcode's `mcpbridge` and an open Xcode project are not required. The simulator accessibility/input tools are not general-purpose automation for native macOS windows; keep using the macOS off-screen renderer.
- MobileBuildMCP 2.7.1 appends `-skipMacroValidation` to builds. This bypasses Swift macro trust validation, not app isolation. Do not introduce or trust new macro dependencies merely because this tool builds them successfully.

#### Local AXe installation and updates

- The configured override is `axePath: ./.local-tools/axe-2.0.4/axe`. It uses the official **AXe 2.0.4** manual distribution, not the MCP's bundled AXe 1.8.0. It does not change a global AXe installation.
- `/.local-tools/` is ignored by `.gitignore`; keep executables, frameworks, resource bundles and downloaded archives under that directory. Never force-add them to Git. A fresh clone will not contain the local tool: check `test -x .local-tools/axe-2.0.4/axe` before relying on automation. Missing/non-executable overrides can silently fall back to bundled AXe.
- Run `.local-tools/axe-2.0.4/axe --version` to inspect the local binary. To check which version the MCP resolves, run its doctor from the project directory with the same environment. For the pinned npm package:

  ```bash
  MOBILEBUILDMCP_HEADLESS_LAUNCH=1 MOBILEBUILDMCP_SENTRY_DISABLED=true \
    npx --yes --package=mobilebuildmcp@2.7.1 mobilebuildmcp-doctor
  ```

  Doctor/version output alone is not an interaction check. If the configured override is missing, do not accept a successful doctor running bundled 1.8.0 as proof of this setup.
- Official newest AXe release: https://github.com/cameroncooke/AXe/releases/latest . Release catalogue: https://github.com/cameroncooke/AXe/releases . Machine-readable latest metadata, including asset SHA-256 digests: https://api.github.com/repos/cameroncooke/AXe/releases/latest .
- Current pinned release: https://github.com/cameroncooke/AXe/releases/tag/v2.0.4 . Manual archive: `AXe-macOS-v2.0.4-universal.tar.gz`. Its published SHA-256 is `3178ec66d9ff46455fec737debad719c41cab16edb1435b2c721e07760a208c3`.
- Install/update only when authorized. Download the selected version's **manual universal** archive from its official release assets into `.local-tools/`, verify its SHA-256 against that asset's published digest before extraction, and extract into a new versioned directory. Do not reuse the 2.0.4 digest for another release or overwrite a working installation.
- Keep the extracted `axe`, `Frameworks/` and `AXe_AXe.bundle/` together. Verify the executable with `codesign --verify --deep --strict --verbose=2 <versioned-directory>/axe`, then run its `--version`. Do not copy only the executable, mix frameworks from different releases, or change global signing/security settings to make it launch.
- Update `axePath` to the verified executable, reconnect the MCP, and repeat the focused compatibility check below. AXe and MobileBuildMCP are independently pinned; do not automatically upgrade both or switch to `@latest`. To roll back, restore the previous verified versioned path and reconnect. Removing the override restores bundled 1.8.0, with its known limitations.
- Upstream MCP releases and configuration: https://github.com/getsentry/MobileBuildMCP/releases and https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/configuration.mdx .

#### Headless operation and compatibility checks

- Use a dedicated agent-owned simulator and explicit UDID as above. Wait for `simctl bootstatus "$SIM_ID" -b`; with local AXe, check `axe displays --udid "$SIM_ID"` before accessibility reads. A visible app or `Booted` state alone does not establish accessibility readiness.
- Call `session_show_defaults` before the first MCP build/run/test. Set `simulatorId`, an agent-owned temporary `derivedDataPath`, and `bundleId: "de.max-heidinger.PReek"` with `persist: false`. Do not persist machine-local UDIDs or temporary paths into project config.
- For MCP build-and-run, explicitly pass `extraArgs: ["CODE_SIGNING_ALLOWED=NO"]` and `launchArgs: ["--debug-offline", "--screen", "main", "--state", "loaded"]`. Runtime flags belong in `launchArgs`, not `extraArgs`. Ignore tool suggestions to call `open_sim`; repository desktop-isolation rules take precedence.
- Inspect `snapshot_ui` before input. Use current semantic `elementRef` targets for taps/text, and `withinElementRef` for swipes. Refresh after navigation, layout changes, or stale/settling warnings. Do not guess coordinates, reuse old refs, or replay uncertain input automatically.
- Verify each effect: a changed selected tab/screen after a tap, the **complete actual value** after typing, and changed content after scrolling. Use native field readback and simulator-only screenshots when necessary. Successful transport receipts, reported character counts and screenshots alone do not prove a complete workflow.
- On failure, preserve the error, version pair, UDID/runtime build, native readback and simulator screenshot. Export relevant guest logs **before deleting the owned simulator**; retain useful evidence while removing disposable builds. MCP logs live under `~/Library/Developer/MobileBuildMCP/workspaces/*/logs/`; simulator logs under `~/Library/Logs/CoreSimulator/<UDID>/`; crash reports under `~/Library/Logs/DiagnosticReports/`.
- Stop owned apps/logging/debug sessions before simulator cleanup. Clear temporary simulator selectors and DerivedData from MCP session defaults, or close an agent-owned verification connection. Never stop another agent's or the user's MCP process.

#### Observed limitations (2026-11-13)

The tested host used Xcode **27.2 / 27B52**, iOS **27.2 / 24B8117**, and MobileBuildMCP **2.7.1**. These findings are not blanket approval for other runtimes or future versions:

- Bundled AXe **1.8.0** connected to `testmanagerd` but hit a hardcoded five-second remote-session bootstrap timeout before reading the tree. Increasing the MCP request timeout does not fix that inner timeout. The same version combination has a transient-startup report: https://github.com/getsentry/MobileBuildMCP/issues/570 .
- Local AXe **2.0.4** passed archive/signature checks and was resolved by a fresh MCP process. Its first MCP capture still failed with **“No translation object”** despite a usable display. A subsequent native AXe agent-mode read succeeded, followed by successful MCP capture and a verified Settings-tab tap. This is a warmed-session result, **not a clean cold-start pass or a guaranteed recovery recipe**.
- MCP text entry reported success for **29 characters**, but native readback and the screenshot showed only **18**, `https://smoke.examp`, instead of `https://smoke.example.invalid`. Treat text entry as unreliable until the full value is observed. Do not silently accept truncated data, pad arbitrary delays, or add retries to hide it.
- Tap/text actions also reported post-action snapshot settling timeouts. A fresh capture was required to observe the result; do not reuse the preceding element refs.
- AXe 2.x contains display-readiness/direct-read-first changes and an upstream fix for dropped Xcode 27 taps, but that does not prove this MCP/version pairing fully reliable: https://github.com/cameroncooke/AXe/issues/71 .
- Apple simulator services crashed during earlier checks: display-query aborts in `dtdeviceinfod`, `com.apple.datamigrator` and `replicatord`, and XPC assertions in App Intents/intelligence services. The reports did not establish a PReek crash or prove that these crashes caused the accessibility timeout. Do not modify PReek or grant host desktop-control permissions merely to suppress toolchain failures.


### Opening in Xcode

Only open `PReek.xcodeproj` when the user explicitly requests it; building, unit testing, and off-screen UI verification do not require opening Xcode.

## Architecture Overview

### Core Components

**App Structure:**
- `PReekApp.swift` - `PReekEntryPoint` dispatches offline debug and render requests before normal SwiftUI app construction; `MenuBarAppDelegate` owns the macOS `NSStatusItem` and transient `NSPopover`
- `ContentView.swift` - Root content view with navigation logic, handles macOS/iOS platform differences
- `SettingsWindowController.swift` - Presents/reuses the separate macOS settings window; its presentation method activates the app, so it is not an agent verification entry point
- `UIRenderer.swift` / `UIRenderOptions.swift` - Debug-only rendering execution and fail-closed command parsing
- `DebugOfflineSession.swift` / `DebugOfflineApp.swift` - Shared Debug-only synthetic models, isolated configuration/preferences/TipKit, and real platform views; separate interactive entry point bypasses all live app bootstrap

**Data Flow:**
- `PullRequestsViewModel.swift` - Central view model managing pull request state, GitHub API calls, and UI updates
- `ConfigViewModel.swift` - Manages configuration, automatic saves, and configuration sharing/import through an injected `ConfigStore`
- `GitHubService.swift` - API service layer for GitHub REST and GraphQL APIs

**Models:**
- `PullRequest.swift` - Core pull request data, status, participants, and presentation fields
- `Event.swift`, `Comment.swift`, `User.swift`, `Repository.swift` - Supporting GitHub data models
- `Notification.swift` - GitHub notification model

**Services:**
- GraphQL queries in `PullRequestsQuery.swift` and `ViewerQuery.swift`
- DTO mapping layer in `Services/DtoModelMapper/` for converting API responses to domain models
- `ConfigService.swift` / `ConfigStore.swift` - Live configuration uses UserDefaults and Keychain; `PersistentConfigStore` adapts it, while `MemoryConfigStore` owns isolated mutable values
- `LocalActionsController.swift` / `LocalActionsController+Live.swift` - Preferences and injected boundaries for selecting existing clones, preparing worktrees, and opening editors/agents
- `LocalWorkspaceService.swift`, `LocalWorkspaceSafety.swift`, `LocalActionsCleanup.swift`, and `LocalWorkspaceRegistry.swift` - Worktree management, safety checks, and conservative cleanup tracking

### Key Architectural Patterns

**Cross-Platform Support:**
- Platform-specific UI code using `#if os(macOS)` / `#else` blocks
- macOS uses an AppKit status item/popover plus a separate settings window; iOS uses a SwiftUI `WindowGroup` with `TabView`
- Shared view models and business logic across platforms

**State Management:**
- SwiftUI `@ObservedObject` and `@StateObject` for reactive UI updates
- Combine publishers for filtering and data transformation
- `@AppStorage` for persistent user preferences
- Injected `UserDefaults`, `ConfigStore`, and local-action dependencies keep fixtures isolated from live credentials, preferences, editors, and workspaces
- `PullRequestPresentationState` separates latest fetched data from the currently presented snapshot

**API Integration:**
- Dual GitHub API support (REST for notifications, GraphQL for pull request details)
- Enterprise GitHub support via configurable base URLs
- Personal access token authentication via the HTTP `Authorization: Bearer ...` header; the token is not a JWT

**Unread State Calculation:**
- `PullRequestUnreadCalculator.calculateUnread(for:viewer:readData:)` prefers event-ID comparison and falls back to timestamps, excluding the viewer's own events
- `PullRequestListFilter` computes filtered lists and memoizes unread results by PR update version; fixtures need timeline participants to pass the excluded-user filter

### View Architecture

**Main Screens:**
- `MainScreen.swift` - Primary pull request list interface
- `WelcomeScreen.swift` - Initial setup and authentication
- `SettingsScreen.swift` - Configuration management

**Pull Request Views:**
- Two main list styles: `PullRequestsList.swift` (iOS-style) and `PullRequestsDisclosureGroupList.swift` (macOS-style)
- `PullRequestDetailView.swift` - Detailed view with comments, commits, and events
- Event display in `EventView.swift` and `CommentsView.swift`

**Utility Components:**
- `ResourceIcon.swift` - Resizable template rendering for bundled icons
- `StatusViews.swift` - Pull request status icons and labels
- `TimeSensitiveText.swift` / `TimeRefreshClock` - Time-derived labels refreshed by one shared clock

## Testing

Tests are located in `PReekTests/`. Relevant suites include:
- DTO/event mapping and unread calculation: `ReviewThreadsCommentsToEventsTests`, `PullRequestUnreadTests`
- Query batching, list filtering, and staged presentation updates: `PullRequestsQueryTests`, `PullRequestListFilterTests`, `PullRequestPresentationStateTests`
- Local actions, editors, agent commands/context, workspaces, and cleanup: `Local*Tests`
- Render command boundaries and preference-domain isolation: `UIRenderOptionsTests`, `CodableAppStorageTests`

## Dependencies

Key external dependencies managed via Swift Package Manager:
- `LaunchAtLogin` (LaunchAtLogin-Modern) - macOS login-item integration
- `KeychainAccess` - Secure token storage
- `MarkdownUI` - Markdown rendering for comments
- `LinkHeaderParser` - GitHub API pagination support
- `CodeScanner` - iOS QR-code scanning for configuration import

Package declarations live in `PReek.xcodeproj/project.pbxproj`; do not infer current dependencies from older architecture descriptions.

## Notable Implementation Details

**GitHub API Integration:**
- Uses GitHub's notification API to determine which PRs to show (notifications-based approach)
- Requires `notifications` scope for basic functionality, `repo` scope for private repositories
- GraphQL queries fetch comprehensive PR data including timeline events and review comments

**MenuBar Behavior:**
- Dynamic icon changes based on unread status (`MenuBarIcon` vs `MenuBarIconUnread`)
- A cancellable focus task follows popover appearance; disappearance clears focus and ends active presentation
- Remote updates are staged while presentation is active and applied explicitly or when presentation ends; there is no five-second navigation-reset mechanism

**Release Process:**
- `build-dmg.sh` is the explicit release workflow; the shared Xcode scheme has no release post-actions
- The script archives/exports a signed Release app, replaces the gitignored `dSYMs/` contents, uses `fnm` with Node 22 and a global npm installation of `create-dmg`, submits the DMG with `notarytool`, and staples the ticket
- It requires signing/provisioning and stored notarization credentials, opens Finder, and uploads to Apple. Run it only for an explicitly requested release, never as a build or UI-verification shortcut