# GitHub Notifications MacOS Menu Bar Widget

*Project is very much in progress, use with caution!*

## TODOs

- [ ] Proper Name!
- [x] Error Handling
- [ ] Menu Bar Icon (size, customization?)
- [ ] Menu Bar Icon w/ Unread Notification
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
  - [ ] Filters
    - [ ] Only `participating` notifications
    - [x] Exclude author list
- [x] Links / Buttons to open in Browser
  - [x] Repository
  - [x] PR itself
  - [x] Events
  - [x] Changes
- [x] Data loading optimization
- [ ] Get rid of old data?
  - [ ] Marked as read information older than X days + no longer in PR list
  - [ ] Closed / Merged PRs older than X days
- [ ] Filters on `PullRequestsView`
- [ ] Mark all as read (all, selection, all closed, ?)
- [x] Don't mark as unread if last modification is from user
- [ ] Better link placement for events?
- [ ] Link commits (and maybe force pushed?) not to commit directly but filtered files page
