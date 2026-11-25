//
//  FetchPaymentMethodsAPIClient.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import Foundation

/// API client for fetching payment methods
public class FetchPaymentMethodsAPIClient {
    
    /// Configuration for the payment method API server
    public struct ServerConfig {
        public let baseURL: String
        public let timeoutInterval: TimeInterval
        public let apiKey: String?
        
        public init(
            baseURL: String,
            timeoutInterval: TimeInterval = 30.0,
            apiKey: String? = nil
        ) {
            self.baseURL = baseURL
            self.timeoutInterval = timeoutInterval
            self.apiKey = apiKey
        }
    }
    
    private let config: ServerConfig

    /// Kept with its signature so `SpreedlyConfigManager` needs no change; the list is read from the device, so
    /// no network session is created.
    public init(config: ServerConfig) {
        self.config = config
    }

    /// The cards this app retained, newest first.
    ///
    /// The sample backend no longer lists payment methods (a shared list would show every visitor's
    /// cards), so this reads the list kept on the device by `SavedPaymentMethodsStore`.
    /// - Returns: FetchPaymentMethodsResponse with the saved payment methods
    /// - Throws: FetchPaymentMethodsAPIError if the stored list cannot be read
    public func fetchPaymentMethods() async throws -> FetchPaymentMethodsResponse {
        do {
            return try SavedPaymentMethodsStore.response()
        } catch {
            throw FetchPaymentMethodsAPIError.storageError(error)
        }
    }
}

// MARK: - Error Handling
/// The saved cards are read from the device, so the only failure is reading that list.
public enum FetchPaymentMethodsAPIError: Error, LocalizedError {
    case storageError(Error)

    public var errorDescription: String? {
        switch self {
        case .storageError:
            return "Couldn't read the saved cards on this device"
        }
    }
}
