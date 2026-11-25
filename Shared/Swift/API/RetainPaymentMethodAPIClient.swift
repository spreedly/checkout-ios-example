//
//  RetainPaymentMethodAPIClient.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import Foundation
import SpreedlyCore

/// API client for retaining payment methods
public class RetainPaymentMethodAPIClient {
    
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
    private let session: URLSession
    private let savedCardsDefaults: UserDefaults
    
    public convenience init(config: ServerConfig) {
        self.init(
            config: config,
            session: BackendBasicAuth.sharedSession(timeoutInterval: config.timeoutInterval),
            savedCardsDefaults: .standard
        )
    }

    /// Lets tests supply the network session and where saved cards are written.
    init(config: ServerConfig, session: URLSession, savedCardsDefaults: UserDefaults) {
        self.config = config
        self.session = session
        self.savedCardsDefaults = savedCardsDefaults
    }
    
    /// Retains a payment method
    /// - Parameter token: The payment method token to retain
    /// - Returns: RetainPaymentMethodResponse with transaction details
    /// - Throws: RetainPaymentMethodAPIError if the request fails
    public func retainPaymentMethod(token: String) async throws -> RetainPaymentMethodResponse {
        let baseURLString = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        guard let url = URL(string: "\(baseURLString)/payment_methods/\(token)/retain") else {
            throw RetainPaymentMethodAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("*/*", forHTTPHeaderField: "accept")
        
        // Add API key if provided
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        BackendBasicAuth.apply(to: &urlRequest)
        urlRequest.httpBody = SampleAppOwner.retainBody

        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RetainPaymentMethodAPIError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                throw RetainPaymentMethodAPIError.serverError(httpResponse.statusCode, data)
            }
            
            let decoder = JSONDecoder()
            let retainResponse = try decoder.decode(RetainPaymentMethodResponse.self, from: data)

            let retained = SavedPaymentMethodsStore.SavedCard(retainResponse.transaction.paymentMethod)
            if retainResponse.transaction.succeeded,
               !SavedPaymentMethodsStore.remember(retained, defaults: savedCardsDefaults) {
                // The retain succeeded on the backend, but this device's list couldn't take the card (no token,
                // or the Keychain key isn't available yet). Fixed text: no token or card data.
                logWarn(tag: "SpreedlyExample", message: "Retained card was not saved to this device's list")
            }

            return retainResponse
            
        } catch let error as RetainPaymentMethodAPIError {
            throw error
        } catch {
            throw RetainPaymentMethodAPIError.networkError(error)
        }
    }
}

// MARK: - Error Handling
public enum RetainPaymentMethodAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, Data)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid payment method API URL"
        case .invalidResponse:
            return "Invalid response from payment method API"
        // The backend's response body is kept out of the description, which is shown and logged; it can echo
        // request data. The body is still on `.serverError` for code that needs it.
        case .serverError(let statusCode, _):
            return "Payment method API error (\(statusCode))"
        case .networkError:
            return "Network error"
        }
    }

    /// A fixed summary that is safe to log: status code or error kind, no response text, URL or token.
    public var logSummary: String {
        switch self {
        case .invalidURL: return "invalid URL"
        case .invalidResponse: return "invalid response"
        case .serverError(let statusCode, _): return "HTTP \(statusCode)"
        case .networkError: return "network error"
        }
    }
}

