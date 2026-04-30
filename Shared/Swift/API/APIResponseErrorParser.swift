//
//  APIResponseErrorParser.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import Foundation

/// Extracts human-readable error messages from raw Spreedly API response data.
///
/// Uses JSONSerialization directly (not Codable) so it works even when the
/// response doesn't fully match the `PurchaseResponse` model — which is common
/// in error responses where required fields like `succeeded` or `token` are absent.
enum APIResponseErrorParser {

    /// Priority:
    /// 1. `transaction.message` — most specific (transaction-level failure)
    /// 2. `errors[].message` — validation errors (all joined)
    /// 3. Top-level `message` — generic (auth failures, 404s, etc.)
    static func extractMessage(from data: Data) -> String? {
        guard
            !data.isEmpty,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let transaction = json["transaction"] as? [String: Any],
           let message = transaction["message"] as? String,
           !message.isEmpty {
            return message
        }

        if let errors = json["errors"] as? [[String: Any]] {
            let messages = errors.compactMap { $0["message"] as? String }
                                 .filter { !$0.isEmpty }
            if !messages.isEmpty {
                return messages.joined(separator: ", ")
            }
        }

        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }

        return nil
    }
}
