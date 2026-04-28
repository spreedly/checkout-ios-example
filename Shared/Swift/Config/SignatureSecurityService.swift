//
//  SignatureSecurityService.swift
//  MerchantExample
//
//
//

import Foundation
import SpreedlyCore

/// Service class for handling signature generation and security setup
public class SignatureSecurityService {
    
    /// Configuration for server-based security
    public struct ServerSecurityConfig {
        public let serverURL: String
        public let apiKey: String?
        public let environmentKey: String
        
        public init(
            serverURL: String,
            apiKey: String? = nil,
            environmentKey: String
        ) {
            self.serverURL = serverURL
            self.apiKey = apiKey
            self.environmentKey = environmentKey
        }
    }
    
    /// Result of security setup
    public struct SecuritySetupResult {
        public let success: Bool
        public let message: String?
        public let error: Error?
        public let signatureParams: SignatureGenerator.SignatureParameters?
        
        public init(success: Bool, message: String? = nil, error: Error? = nil, signatureParams: SignatureGenerator.SignatureParameters? = nil) {
            self.success = success
            self.message = message
            self.error = error
            self.signatureParams = signatureParams
        }
    }
    
    // MARK: - Server-Based Security
    
    /// Sets up server-based security and tests payment processing
    /// - Parameter config: Server security configuration
    /// - Returns: Combined setup and test result
    public static func setupServerBasedSecurity(config: ServerSecurityConfig) async -> SecuritySetupResult {
        do {
            // Create server configuration
            let serverConfig = SignatureServerClient.ServerConfig(
                baseURL: config.serverURL,
                timeoutInterval: 30.0,
                apiKey: config.apiKey
            )
            
            // Create server client and request signature
            let serverClient = SignatureServerClient(config: serverConfig)
            
            // Request signature from server
            let signatureParams = try await serverClient.requestSignature()
            
            return SecuritySetupResult(
                success: true,
                message: "Server-based security setup successful",
                signatureParams: signatureParams
            )
            
        } catch let serverError as SignatureServerError {
            return SecuritySetupResult(
                success: false,
                error: serverError
            )
        } catch {
            return SecuritySetupResult(
                success: false,
                error: error
            )
        }
    }
    
} 
