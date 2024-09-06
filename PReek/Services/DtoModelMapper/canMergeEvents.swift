import Foundation

func canMergeEvents(_ firstItem: PullRequestDto.MergeableDto, _ secondItem: PullRequestDto.MergeableDto?) -> Bool {
    guard let secondItem = secondItem else {
        return false
    }

    let sameAuthor = firstItem.resolvedActor?.login == secondItem.resolvedActor?.login
    // Check if times are within 5 minutes of each other
    let closeInTime = abs(firstItem.resolvedTime.timeIntervalSince(secondItem.resolvedTime)) < 5 * 60

    return sameAuthor && closeInTime
}
