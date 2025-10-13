# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PReek is a macOS/iOS SwiftUI application that brings GitHub Pull Request notifications directly into the macOS MenuBar. It fetches pull requests based on GitHub notifications and displays them in a clean, organized interface with vim-like keyboard shortcuts.

## Development Commands

### Building
```bash
# Build for macOS
xcodebuild clean build -scheme "PReek" -project "PReek.xcodeproj" -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO

# Build for iOS
xcodebuild clean build -scheme "PReek" -project "PReek.xcodeproj" -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO

# Build with analysis
xcodebuild clean build analyze -scheme "PReek" -project "PReek.xcodeproj" -destination "generic/platform=macOS" CODE_SIGNING_ALLOWED=NO
```

### Testing
```bash
# Run tests
xcodebuild test -scheme "PReek" -project "PReek.xcodeproj" -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO

# Run tests with pretty output (requires xcpretty)
xcodebuild test -scheme "PReek" -project "PReek.xcodeproj" -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO | xcpretty
```

### Opening in Xcode
```bash
open PReek.xcodeproj
```

## Architecture Overview

### Core Components

**App Structure:**
- `PReekApp.swift` - Main app entry point, handles MenuBarExtra setup and lifecycle
- `ContentView.swift` - Root content view with navigation logic, handles macOS/iOS platform differences

**Data Flow:**
- `PullRequestsViewModel.swift` - Central view model managing pull request state, GitHub API calls, and UI updates
- `ConfigViewModel.swift` - Manages app configuration and GitHub authentication
- `GitHubService.swift` - API service layer for GitHub REST and GraphQL APIs

**Models:**
- `PullRequest.swift` - Core data model with status tracking and unread calculation
- `Event.swift`, `Comment.swift`, `User.swift`, `Repository.swift` - Supporting GitHub data models
- `Notification.swift` - GitHub notification model

**Services:**
- GraphQL queries in `PullRequestsQuery.swift` and `ViewerQuery.swift`
- DTO mapping layer in `Services/DtoModelMapper/` for converting API responses to domain models
- `ConfigService.swift` - Configuration management with UserDefaults

### Key Architectural Patterns

**Cross-Platform Support:**
- Platform-specific UI code using `#if os(macOS)` / `#else` blocks
- macOS uses MenuBarExtra with NavigationStack, iOS uses TabView
- Shared view models and business logic across platforms

**State Management:**
- SwiftUI `@ObservedObject` and `@StateObject` for reactive UI updates
- Combine publishers for filtering and data transformation
- `@AppStorage` for persistent user preferences

**API Integration:**
- Dual GitHub API support (REST for notifications, GraphQL for pull request details)
- Enterprise GitHub support via configurable base URLs
- JWT-style token authentication

**Unread State Calculation:**
- Complex logic in `PullRequest.calculateUnread()` comparing notification timestamps with event timestamps
- Tracks oldest unread events for each pull request

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
- `ResourceIcon.swift` - GitHub status icons (open, closed, merged, draft)
- `TimeSensitiveText.swift` - Relative time display
- Keyboard navigation handler for vim-like shortcuts (j/k/g/G/space)

## Testing

Tests are located in `PReekTests/` and focus on:
- Data transformation logic (`ReviewThreadsCommentsToEventsTests.swift`)
- Unread state calculation (`PullRequestUnreadTests.swift`)

## Dependencies

Key external dependencies managed via Swift Package Manager:
- `MenuBarExtraAccess` - Enhanced MenuBar control
- `KeychainAccess` - Secure token storage
- `MarkdownUI` - Markdown rendering for comments
- `LinkHeaderParser` - GitHub API pagination support

## Notable Implementation Details

**GitHub API Integration:**
- Uses GitHub's notification API to determine which PRs to show (notifications-based approach)
- Requires `notifications` scope for basic functionality, `repo` scope for private repositories
- GraphQL queries fetch comprehensive PR data including timeline events and review comments

**MenuBar Behavior:**
- Dynamic icon changes based on unread status (`MenuBarIcon` vs `MenuBarIconUnread`)
- Auto-focus and keyboard shortcut handling when menu opens
- 5-second delay before resetting navigation state when menu closes

**Keyboard Navigation:**
- Vim-like navigation: j (down), k (up), g (top), G (bottom), space (toggle)
- Focus management across different UI states and screens

**Release Process:**
- Automated DMG creation with signing and notarization in Xcode scheme post-actions
- Uses `create-dmg` npm package for DMG generation
- Full notarization workflow integrated into build process