//
//  FetchPaymentMethodsAPIClient.swift
//  MerchantExample
//
//
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
    private let session: URLSession
    
    public init(config: ServerConfig) {
        self.config = config
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeoutInterval
        sessionConfig.timeoutIntervalForResource = config.timeoutInterval
        
        self.session = URLSession(configuration: sessionConfig)
    }

    /// Fetches all payment methods
    /// - Returns: FetchPaymentMethodsResponse with array of payment methods
    /// - Throws: FetchPaymentMethodsAPIError if the request fails
    public func fetchPaymentMethods() async throws -> FetchPaymentMethodsResponse {
        let baseURLString = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        guard let url = URL(string: "\(baseURLString)/payment_methods") else {
            throw FetchPaymentMethodsAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("*/*", forHTTPHeaderField: "accept")
        
        // Add API key if provided
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FetchPaymentMethodsAPIError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                throw FetchPaymentMethodsAPIError.serverError(httpResponse.statusCode, data)
            }
            
            let decoder = JSONDecoder()
            let fetchResponse = try decoder.decode(FetchPaymentMethodsResponse.self, from: data)
            
            return fetchResponse
            
        } catch let error as FetchPaymentMethodsAPIError {
            throw error
        } catch {
            throw FetchPaymentMethodsAPIError.networkError(error)
        }
    }
}

// MARK: - Error Handling
public enum FetchPaymentMethodsAPIError: Error, LocalizedError {
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

