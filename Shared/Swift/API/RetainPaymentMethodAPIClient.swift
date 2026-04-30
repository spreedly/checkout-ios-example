//
//  RetainPaymentMethodAPIClient.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import Foundation

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
    
    public init(config: ServerConfig) {
        self.config = config
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeoutInterval
        sessionConfig.timeoutIntervalForResource = config.timeoutInterval
        
        self.session = URLSession(configuration: sessionConfig)
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
        case .serverError(let statusCode, let data):
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            return "Payment method API error (\(statusCode)): \(errorMessage)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

