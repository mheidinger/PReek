<p align="center">
 <img width="200" height="200" margin-right="100%" src="https://github.com/mheidinger/PReek/blob/main/icons/logo.png?raw=true">
</p>

# PReek

PReek brings a quick peek into relevant GitHub Pull Requests directly into your MacOS MenuBar!

*Project is very much in progress, use with caution!*

## TODOs

- [x] Proper Name!
- [x] Error Handling
- [x] Menu Bar Icon
  - [x] Unread Indicator
- [x] Read / Unread Tracking + Updates
  - [x] Only requests notifications since last update
  - [x] Only fetch PRs for which updates should be there
  - [x] Mark PRs with updates as unread
- [x] Get correct PRs
- [x] PR Icons
- [x] Squash / Filter Events
  - [x] Multiple Commits into one Event
  - [x] Multiple Commits + Force Push into one Event
- [x] Figure out proper "Review Requested" Event Stuff
  - Seems like it only returns `null` for requested team reviews? => adapted display
- [x] Status Bar?
  - [x] Last Updated
  - [x] Button to update
  - [x] Settings Button
  - [x] Errors
- [ ] Push / Force Push Commit Messages?
- [ ] Settings Page
  - [x] GitHub URL
  - [x] Token
  - [x] Quit Button
  - [x] Exclude author list
  - [x] Fetch and delete time windows
  - [ ] Improve layout?
- [x] Links / Buttons to open in Browser
  - [x] Repository
  - [x] PR itself
  - [x] Events
  - [x] Changes
- [x] Data loading optimization
- [x] Get rid of old data
  - [x] Marked as read information older than X days + no longer in PR list
  - [x] Closed / Merged PRs older than X days
- [x] Filters on `PullRequestsView`
  - [x] Read
  - [x] Closed
- [x] Mark all as read (all currently displayed)
- [x] Don't mark as unread if last modification is from user
- [ ] Better link placement for events?
- [ ] Link commits (and maybe force pushed?) not to commit directly but filtered files page
- [x] Update PRs also w/o new notifications: you don't get notifications e.g. if you yourself merged a PR
- [ ] Start Screen
  - [x] Logo + Welcome
  - [x] Basic settings? PAT + URLs?
  - [ ] Notice around notification usage + PAT permissions?
  - [x] Button to check settings and dismiss screen
- [ ] Rate Limiting?
