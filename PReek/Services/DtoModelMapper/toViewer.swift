import Foundation

func toViewer(_ actor: PullRequestDto.Actor?, scopesHeader: String?) -> Viewer {
    guard let actor = actor else {
        return Viewer(login: "Unknown", scopes: nil)
    }

    let scopes = scopesHeader?.split(separator: ",").compactMap { rawScope in
        Scope(rawValue: rawScope.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return Viewer(
        login: actor.login,
        scopes: scopes
    )
}
