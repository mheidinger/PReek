import Foundation

func toOptionalUrl(_ url: String?) -> URL? {
    guard let url = url else {
        return nil
    }
    return URL(string: url)
}
