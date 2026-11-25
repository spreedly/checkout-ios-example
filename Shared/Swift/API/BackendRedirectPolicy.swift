//
//  BackendRedirectPolicy.swift
//  SpreedlySDKExample
//

import Foundation

/// Decides whether offsite purchase requests send the app's own `redirect_url`.
///
/// The sample app backend only accepts a `redirect_url` on its own origin, so it refuses the
/// app's deep links (`spreedlyApp://…`). When it gets no `redirect_url`, it uses its own return page.
///
/// Reads `SpreedlyOmitRedirectURL` from Info.plist, which comes from `SPREEDLY_OMIT_REDIRECT_URL` in
/// `SpreedlyKeys.xcconfig`. Set it to `YES` for that backend; leave it empty to send the deep links.
enum BackendRedirectPolicy {
    static let omitKey = "SpreedlyOmitRedirectURL"

    /// The `redirect_url` to send: `appRedirectURL`, or `nil` to leave the field out.
    static func redirectURL(
        _ appRedirectURL: String,
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> String? {
        omitsRedirectURL(infoDictionary: infoDictionary) ? nil : appRedirectURL
    }

    /// `true` when `SpreedlyOmitRedirectURL` is `YES`, `true` or `1` (any case).
    static func omitsRedirectURL(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> Bool {
        let value = (infoDictionary?[omitKey] as? String)?
            .trimmingCharacters(in: .whitespaces)
            .lowercased() ?? ""
        return ["yes", "true", "1"].contains(value)
    }
}
