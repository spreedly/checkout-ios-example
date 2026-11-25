//
//  BackendBasicAuth.swift
//  SpreedlySDKExample
//

import Foundation

/// Login for a merchant backend that sits behind an HTTP Basic login.
///
/// Reads `SpreedlyBackendBasicAuthUser` and `SpreedlyBackendBasicAuthPassword` from Info.plist,
/// which come from `SpreedlyKeys.xcconfig`. When either is empty, requests are left unchanged.
/// The login is only attached to HTTPS requests for the origin (host and port) of `SpreedlyBaseURL`, and sessions made
/// with `makeSession` refuse any redirect that leaves the original request's origin.
enum BackendBasicAuth {
    static let userKey = "SpreedlyBackendBasicAuthUser"
    static let passwordKey = "SpreedlyBackendBasicAuthPassword"
    static let backendURLKey = "SpreedlyBaseURL"

    /// Adds the backend login to `request` when one is configured and the request goes to the backend origin.
    /// The login replaces any `Authorization` header already set, since a request carries only one.
    static func apply(to request: inout URLRequest, infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        guard isBackendRequest(request, backendURL: infoDictionary?[backendURLKey] as? String),
              let header = authorizationHeader(
                user: infoDictionary?[userKey] as? String,
                password: infoDictionary?[passwordKey] as? String
              ) else { return }
        request.setValue(header, forHTTPHeaderField: "Authorization")
    }

    /// Whether `request` goes over HTTPS to the same origin as `backendURL`, also HTTPS: host (case-insensitive)
    /// and port, a missing port meaning 443. No backend URL, or plain HTTP on either side, means no match.
    static func isBackendRequest(_ request: URLRequest, backendURL: String?) -> Bool {
        guard let backend = backendURL.flatMap({ URL(string: $0) }),
              let requestURL = request.url,
              let backendOrigin = origin(of: backend),
              let requestOrigin = origin(of: requestURL) else { return false }
        return backendOrigin == requestOrigin
    }

    private static func origin(of url: URL) -> String? {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        return "https://\(host):\(url.port ?? 443)"
    }

    /// The `Authorization` value for a Basic login, or `nil` when the user or password is missing or blank,
    /// or the user contains a colon (Basic auth can't carry one). Values are not trimmed here:
    /// spaces in a password are part of it (xcconfig itself strips surrounding whitespace).
    static func authorizationHeader(user: String?, password: String?) -> String? {
        guard let user, let password,
              !isBlank(user), !isBlank(password),
              !user.contains(":") else { return nil }
        return "Basic " + Data("\(user):\(password)".utf8).base64EncodedString()
    }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The request to follow for a redirect, or `nil` to refuse it. Only a redirect to the same origin (scheme,
    /// host and port) as the request that started it is followed. Anything else, including a move from HTTPS to
    /// HTTP, is refused: a 307 or 308 redirect re-sends the body (the retain owner secret, purchase tokens) as well
    /// as headers, so stripping `Authorization` alone wouldn't be enough. The task then ends with the redirect
    /// response, which the clients report as an error.
    static func redirectRequest(_ redirect: URLRequest, from original: URLRequest?) -> URLRequest? {
        guard let target = anyOrigin(of: redirect.url), target == anyOrigin(of: original?.url) else { return nil }
        return redirect
    }

    /// A session whose redirects go through `redirectRequest`. Use it for every backend request.
    static func makeSession(configuration: URLSessionConfiguration) -> URLSession {
        URLSession(configuration: configuration, delegate: BackendRedirectGuard.shared, delegateQueue: nil)
    }

    /// The session the backend clients share for a timeout: one per timeout for the life of the app, rather than a
    /// new delegated session per client that is never invalidated.
    static func sharedSession(timeoutInterval: TimeInterval) -> URLSession {
        sessionCache.session(for: timeoutInterval) {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = timeoutInterval
            configuration.timeoutIntervalForResource = timeoutInterval
            return makeSession(configuration: configuration)
        }
    }

    private static let sessionCache = SessionCache()

    private final class SessionCache: @unchecked Sendable {
        private let lock = NSLock()
        private var sessions: [TimeInterval: URLSession] = [:]

        func session(for timeout: TimeInterval, make: () -> URLSession) -> URLSession {
            lock.withLock {
                if let session = sessions[timeout] { return session }
                let session = make()
                sessions[timeout] = session
                return session
            }
        }
    }

    private static func anyOrigin(of url: URL?) -> String? {
        guard let url, let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        let port = url.port ?? (scheme == "https" ? 443 : scheme == "http" ? 80 : -1)
        return "\(scheme)://\(host):\(port)"
    }
}

/// Session delegate that applies `BackendBasicAuth.redirectRequest` to every redirect.
final class BackendRedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    static let shared = BackendRedirectGuard()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        BackendBasicAuth.redirectRequest(request, from: task.originalRequest)
    }
}
