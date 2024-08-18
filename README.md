<p align="center">
 <img alt="PReek Logo" width="200" height="200" margin-right="100%" src="https://github.com/mheidinger/PReek/blob/main/icons/logo.png?raw=true">
</p>

# PReek

PReek brings a quick peek into relevant GitHub Pull Requests directly into your MacOS MenuBar!

<p align="center">
 <img alt="Screenshot of PReek" width="400" src="img/screenshot-1.png">
 <img alt="Screenshot of PReek" width="400" src="img/screenshot-2.png">
</p>

## Install

Currently PReek can only be installed by locally building the project.

GitHub Releases with signed installer, Brew and maybe an App Store installation will come soon!

## FAQ

### Why is the notification scope required for the GitHub PAT?

PReek shows Pull Requests for which you got notifications for.
To be able to fetch your notifications, the notifications scope is required.

### Why is a given Pull Request not shown?

As PReek shows Pull Requests for which you got notifications for, please check whether you received a notification for the missing Pull Request in the [Notifications Inbox](https://github.com/notifications).
If you did not get a notification, verify that you have not disabled them for a given repository.
See the [GitHub documentation](https://docs.github.com/en/account-and-profile/managing-subscriptions-and-notifications-on-github/setting-up-notifications/configuring-notifications) for more information.
