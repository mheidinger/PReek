import Foundation

func toNotifications(dtos: [NotificationDto]) -> [Notification] {
    return dtos.reduce(into: [Notification]()) { notifications, notificationDto in
        guard notificationDto.subject.type == "PullRequest",
              let url = notificationDto.subject.url,
              let prNumberStr = url.split(separator: "/").last,
              let prNumber = Int(prNumberStr)
        else {
            return
        }

        notifications.append(Notification(
            repo: "\(notificationDto.repository.owner.login)/\(notificationDto.repository.name)",
            prNumber: prNumber
        ))
    }
}
