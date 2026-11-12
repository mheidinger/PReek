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

**Do not interrupt the user's desktop.** Unless explicitly authorized, never launch PReek normally, activate an application, open Xcode or Simulator, automate global mouse/keyboard input, or capture the desktop or a window from the user's session. Do not kill, replace, or manipulate the user's running PReek instance. `open -g` and another Space are not isolation.

Use the Debug/macOS off-screen renderer for routine layout checks. Build into a disposable directory so the user's builds are not overwritten, then invoke the executable directly with `--render-ui` (not `open`):

```bash
UI_BUILD_DIR="$(mktemp -d /tmp/preek-ui.XXXXXX)"
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
- The renderer dispatches before `PReekApp` construction, uses synthetic data and isolated configuration/preferences, and rejects external actions. No real GitHub token, installed editor, startup setting, or workspace is needed. Invalid render requests and Release-build render requests fail instead of launching the normal app.
- Inspect the generated view-only PNG with an image-reading tool. A successful command or nonempty file is not visual verification: check the requested state, text wrapping, clipping, and controls. Check light/dark and relevant sizes for changed surfaces; do not generate every scenario routinely.
- JSON output must report `visibleWindows: 0`, `applicationActive: false`, and `activationProhibited: true`. `foregroundUnchanged` is observational: a user switching applications during the render can change it without the renderer activating anything.
- **Fidelity limit:** these are native view bitmaps, not WindowServer screenshots. On macOS 27 the sidebar selection can render black (hiding its light-mode label), and native switch tint can differ. Do not approve selection contrast, translucency/glass, animation timing, or active-window appearance from these images. Do not modify production styling just to hide a capture artifact.
- Focus, shortcuts, menu tracking, popover/sheet presentation and dismissal, and compositor effects require a separately provisioned macOS graphical session (VM or dedicated test Mac). If that is unavailable, report the specific unverified behavior; do not fall back to the user's desktop.
- Existing Xcode previews and the preview environment variable are not isolation guarantees; some previews construct live services or initiate fetching. The supported agent path is `--render-ui`.
- Remove only your own disposable build/render files after inspection. Never commit generated PNGs or introduce pixel baselines without a specific need.

### Opening in Xcode

Only open `PReek.xcodeproj` when the user explicitly requests it; building, unit testing, and off-screen UI verification do not require opening Xcode.

## Architecture Overview

### Core Components

**App Structure:**
- `PReekApp.swift` - `PReekEntryPoint` dispatches render requests before normal SwiftUI app construction; `MenuBarAppDelegate` owns the macOS `NSStatusItem` and transient `NSPopover`
- `ContentView.swift` - Root content view with navigation logic, handles macOS/iOS platform differences
- `SettingsWindowController.swift` - Presents/reuses the separate macOS settings window; its presentation method activates the app, so it is not an agent verification entry point
- `UIRenderer.swift` / `UIRenderOptions.swift` - Debug-only rendering execution and fail-closed command parsing

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