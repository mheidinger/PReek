import Foundation

func toNotifications(dtos: [NotificationDto]) -> [Notification] {
    return dtos.reduce([Notification]()) { notificationArray, notificationDto in
        if notificationDto.subject.type != "PullRequest" {
            return notificationArray
        }
        
        guard let url = notificationDto.subject.url else {
            return notificationArray
        }
        
        let prNumberStr = url.split(separator: "/").last
        if prNumberStr == nil {
            return notificationArray
        }
        let prNumber = Int(String(prNumberStr!))
        if prNumber == nil {
            return notificationArray
        }
        
        return notificationArray + [Notification(
            repo: "\(notificationDto.repository.owner.login)/\(notificationDto.repository.name)",
            prNumber: prNumber!
        )]
    }
}
