import Foundation

public struct URLSanitizer: Sendable {
    public static let `default` = URLSanitizer()

    public init() {}

    public func sanitize(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        if let query = components.percentEncodedQuery {
            var safeSegments: [Substring] = []

            for segment in query.split(separator: "&", omittingEmptySubsequences: false) where !segment.isEmpty {
                let rawName = segment.prefix { $0 != "=" }
                guard let decodedName = String(rawName).removingPercentEncoding else {
                    return nil
                }

                if !isSensitiveQueryName(decodedName) {
                    safeSegments.append(segment)
                }
            }

            components.percentEncodedQuery = safeSegments.isEmpty
                ? nil
                : safeSegments.map(String.init).joined(separator: "&")
        }

        if components.scheme?.lowercased() == "http" || components.scheme?.lowercased() == "https" {
            components.user = nil
            components.password = nil
        }
        components.fragment = nil
        return components.url
    }

    private func isSensitiveQueryName(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        if Self.sensitiveNames.contains(lowercased) || lowercased.hasPrefix("utm_") {
            return true
        }
        return Self.splitIdentifierSegments(name).contains { Self.sensitiveNameSegments.contains($0) }
    }

    private static func splitIdentifierSegments(_ name: String) -> [String] {
        var segments: [String] = []
        var current = ""
        let characters = Array(name)
        for index in characters.indices {
            let character = characters[index]
            if character == "_" || character == "-" {
                if !current.isEmpty {
                    segments.append(current.lowercased())
                    current.removeAll(keepingCapacity: true)
                }
                continue
            }
            if !current.isEmpty, character.isUppercase {
                let previous = characters[index - 1]
                let nextIsLowercase = index + 1 < characters.count && characters[index + 1].isLowercase
                if previous.isLowercase || (previous.isUppercase && nextIsLowercase) {
                    segments.append(current.lowercased())
                    current.removeAll(keepingCapacity: true)
                }
            }
            current.append(character)
        }
        if !current.isEmpty {
            segments.append(current.lowercased())
        }
        return segments
    }

    private static let sensitiveNames: Set<String> = [
        "token",
        "access_token",
        "refresh_token",
        "id_token",
        "oauth_token",
        "oauth_verifier",
        "auth",
        "authorization",
        "bearer",
        "jwt",
        "code",
        "state",
        "session",
        "session_id",
        "signature",
        "password",
        "pass",
        "passwd",
        "pwd",
        "secret",
        "client_secret",
        "client-secret",
        "api_key",
        "api-key",
        "apikey",
        "key",
        "private_key",
        "secret_key",
        "access_key",
        "credential",
        "credentials",
        "assertion",
        "saml_response",
        "samlresponse",
        "saml_request",
        "samlrequest",
        "gclid",
        "fbclid"
    ]

    private static let sensitiveNameSegments: Set<String> = [
        "token",
        "auth",
        "authorization",
        "bearer",
        "jwt",
        "code",
        "state",
        "session",
        "signature",
        "password",
        "pass",
        "passwd",
        "pwd",
        "secret",
        "key",
        "credential",
        "credentials",
        "assertion",
        "saml"
    ]
}
