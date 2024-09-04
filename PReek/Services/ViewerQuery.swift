import Foundation

struct ViewerResponse: Decodable {
    struct Data: Decodable {
        let viewer: PullRequestDto.Actor
    }

    let data: Data?
    let errors: [GitHubGraphQLError]?
}

let ViewerQuery = """
fragment ActorFragment on Actor {
  login
  url
  ... on User {
    name
  }
}

query currentUser {
  viewer {
    ...ActorFragment
   }
}
"""
