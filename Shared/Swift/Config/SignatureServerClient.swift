//
//  SignatureServerClient.swift
//  SpreedlySDKExample
//
//  Created by Vinay Naikade on 24/06/25.
//

import Foundation

/// Client for communicating with a local signature server
public class SignatureServerClient {
    
    /// Configuration for the signature server
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
    
    /// Request model for signature generation
    public struct SignatureRequest: Codable {
        public let certificateToken: String
        public let nonce: String?
        public let timestamp: String?
        
        public init(
            certificateToken: String,
            nonce: String? = nil,
            timestamp: String? = nil
        ) {
            self.certificateToken = certificateToken
            self.nonce = nonce
            self.timestamp = timestamp
        }
    }
    
    /// Response model from signature server
    public struct SignatureResponse: Codable {
        public let nonce: String
        public let timestamp: Int
        public let certificateToken: String
        public let signature: String
        
        public init(
            nonce: String,
            timestamp: Int,
            certificateToken: String,
            signature: String,
        ) {
            self.nonce = nonce
            self.timestamp = timestamp
            self.certificateToken = certificateToken
            self.signature = signature
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
    
    /// Requests a signature from the local signature server
    /// - Parameter certificateToken: The certificate token to use for signature generation
    /// - Returns: Signature parameters including nonce, timestamp, certificate token, and signature
    /// - Throws: SignatureServerError if the request fails
    public func requestSignature() async throws -> SignatureGenerator.SignatureParameters {
        
        guard let url = URL(string: "\(config.baseURL)") else {
            throw SignatureServerError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add API key if provided
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SignatureServerError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                throw SignatureServerError.serverError(httpResponse.statusCode, data)
            }
            
            let decoder = JSONDecoder()
            let signatureResponse = try decoder.decode(SignatureResponse.self, from: data)
            
            if signatureResponse.signature.isEmpty {
                throw SignatureServerError.signatureGenerationFailed("Unknown error")
            }
            
            return SignatureGenerator.SignatureParameters(
                nonce: signatureResponse.nonce,
                timestamp: signatureResponse.timestamp,
                certificateToken: signatureResponse.certificateToken,
                signature: signatureResponse.signature
            )
            
        } catch let error as SignatureServerError {
            throw error
        } catch {
            throw SignatureServerError.networkError(error)
        }
    }
}

// MARK: - Signature Server Errors
public enum SignatureServerError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, Data)
    case signatureGenerationFailed(String)
    case networkError(Error)
    case serverUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid signature server URL"
        case .invalidResponse:
            return "Invalid response from signature server"
        case .serverError(let statusCode, let data):
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            return "Signature server error (\(statusCode)): \(errorMessage)"
        case .signatureGenerationFailed(let message):
            return "Signature generation failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverUnavailable:
            return "Signature server is unavailable"
        }
    }
}
