#if os(macOS)
    import Foundation

    /// Resolve initial API endpoints and pagination links before attaching credentials.
    enum LocalActionURL {
        static func resolve(base: URL, path: String, pageURL: URL? = nil) throws -> URL {
            // appending an empty path adds a slash; URL.path hides that difference,
            // but URL equality does not. GraphQL must use its exact endpoint.
            let url = pageURL ?? (path.isEmpty ? base : base.appending(path: path))
            guard url.scheme == base.scheme, url.host == base.host, url.port == base.port,
                  url.path.hasPrefix(base.path.isEmpty ? "/" : base.path + "/") || url == base
            else {
                throw LocalActionError(message: "GitHub returned an unexpected API or pagination URL.")
            }
            return url
        }
    }
#endif
