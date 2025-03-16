enum ShareConfig: Codable {
    case v1(ShareConfigDataV1)

    private enum CodingKeys: String, CodingKey {
        case version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)

        switch version {
        case 1:
            self = try .v1(ShareConfigDataV1(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported version: \(version)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .v1(config):
            try config.encode(to: encoder)
        }
    }
}

struct ShareConfigDataV1: Codable {
    let version: Int
    let token: String
    let gitHubEnterpriseUrl: String?

    private enum CodingKeys: String, CodingKey {
        case version, token, gitHubEnterpriseUrl
    }

    init(token: String, gitHubEnterpriseUrl: String?) {
        version = 1
        self.token = token
        self.gitHubEnterpriseUrl = gitHubEnterpriseUrl
    }

    // Custom decoder implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Verify the version is correct
        let version = try container.decode(Int.self, forKey: .version)
        guard version == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Expected version 1, but found \(version)"
            )
        }

        self.version = version
        token = try container.decode(String.self, forKey: .token)
        gitHubEnterpriseUrl = try container.decodeIfPresent(String.self, forKey: .gitHubEnterpriseUrl)
    }
}
