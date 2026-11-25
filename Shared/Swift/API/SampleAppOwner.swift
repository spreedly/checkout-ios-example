//
//  SampleAppOwner.swift
//  SpreedlySDKExample
//

import CryptoKit
import Foundation

/// Proves to the sample app backend that this app created a payment method, so it may retain it.
///
/// The sample backend is designed to retain a payment method only when the request carries a secret whose
/// hash matches the `sample_app_owner` metadata stored on that payment method. The app makes one secret
/// per launch, tags cards tokenized on the screens that retain them with the hash, and sends the secret on
/// retain. Cards created before a relaunch, or by another app or page, can't be retained from here.
enum SampleAppOwner {
    static let metadataKey = "sample_app_owner"
    static let secretBodyKey = "owner_secret"

    /// One secret per app launch. A UUID string fits the backend's accepted format.
    static let secret: String = UUID().uuidString

    /// Metadata to add when tokenizing a card that may be retained.
    static var metadata: [String: String] { [metadataKey: tag(for: secret)] }

    /// Retain request body as JSON. Built directly because a UUID string needs no escaping,
    /// so there is no encoding failure to handle.
    static var retainBody: Data { Data(#"{"\#(secretBodyKey)":"\#(secret)"}"#.utf8) }

    /// `metadata` with the owner tag added. The tag wins if the key is already present.
    static func merged(into metadata: [String: String]) -> [String: String] {
        metadata.merging(Self.metadata) { _, owner in owner }
    }

    /// The tag for `secret`, the value the backend compares against.
    static func tag(for secret: String) -> String {
        SHA256.hash(data: Data(secret.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
