//
//  SignatureGenerator.swift
//  SpreedlySDKExample
//
//  Created by Vinay Naikade on 24/06/25.
//

import Foundation
import Security
import CryptoKit

/// Utility for generating certificate-based signatures for enhanced iFrame security
public class SignatureGenerator {
    
    /// Configuration for certificate-based signature generation
    public struct SignatureConfig {
        public let privateKeyPEM: String
        public let certificateToken: String
        
        public init(privateKeyPEM: String, certificateToken: String) {
            self.privateKeyPEM = privateKeyPEM
            self.certificateToken = certificateToken
        }
    }
    
    /// Signature parameters required for the request
    public struct SignatureParameters {
        public let nonce: String
        public let timestamp: Int
        public let certificateToken: String
        public let signature: String
        
        public init(nonce: String, timestamp: Int, certificateToken: String, signature: String) {
            self.nonce = nonce
            self.timestamp = timestamp
            self.certificateToken = certificateToken
            self.signature = signature
        }
    }
    
    /// Generates signature parameters for enhanced iFrame security
    /// - Parameter config: The signature configuration containing private key and certificate token
    /// - Returns: Signature parameters including nonce, timestamp, certificate token, and signature
    /// - Throws: SignatureError if signature generation fails
    public static func generateSignatureParameters(config: SignatureConfig) throws -> SignatureParameters {
        // Generate nonce (UUID)
        let nonce = UUID().uuidString
        
        // Generate timestamp (Unix timestamp)
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Create the data to sign: nonce + timestamp + certificateToken
        let dataToSign = nonce + String(timestamp) + config.certificateToken
        
        // Generate signature using private key
        let signature = try generateSignature(data: dataToSign, privateKeyPEM: config.privateKeyPEM)
        
        return SignatureParameters(
            nonce: nonce,
            timestamp: Int(timestamp),
            certificateToken: config.certificateToken,
            signature: signature
        )
    }
    
    /// Generates a signature for the given data using the provided private key
    /// - Parameters:
    ///   - data: The data to sign
    ///   - privateKeyPEM: The private key in PEM format
    /// - Returns: Base64 encoded signature
    /// - Throws: SignatureError if signature generation fails
    private static func generateSignature(data: String, privateKeyPEM: String) throws -> String {
        guard let dataToSign = data.data(using: .utf8) else {
            throw SignatureError.invalidData
        }
        
        // Parse the private key from PEM format
        let privateKey = try parsePrivateKey(from: privateKeyPEM)
        
        // Create signature using SHA256
        let signature = try createSignature(data: dataToSign, privateKey: privateKey)
        
        // Encode signature as Base64
        return signature.base64EncodedString()
    }
    
    /// Parses a private key from PEM format
    /// - Parameter pemString: The private key in PEM format
    /// - Returns: SecKey representing the private key
    /// - Throws: SignatureError if parsing fails
    private static func parsePrivateKey(from pemString: String) throws -> SecKey {
        // Remove PEM headers and footers
        let cleanPEM = pemString
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        
        guard let keyData = Data(base64Encoded: cleanPEM) else {
            throw SignatureError.invalidPrivateKey
        }
        
        // Create key attributes
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 3072
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            throw SignatureError.privateKeyCreationFailed(error?.takeRetainedValue())
        }
        
        return privateKey
    }
    
    /// Creates a signature for the given data using the private key
    /// - Parameters:
    ///   - data: The data to sign
    ///   - privateKey: The private key to use for signing
    /// - Returns: The signature data
    /// - Throws: SignatureError if signing fails
    private static func createSignature(data: Data, privateKey: SecKey) throws -> Data {
        let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, algorithm, data as CFData, &error) else {
            throw SignatureError.signatureCreationFailed(error?.takeRetainedValue())
        }
        
        return signature as Data
    }
}

// MARK: - Signature Errors
public enum SignatureError: Error, LocalizedError {
    case invalidData
    case invalidPrivateKey
    case privateKeyCreationFailed(CFError?)
    case signatureCreationFailed(CFError?)
    
    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data provided for signature generation"
        case .invalidPrivateKey:
            return "Invalid private key format"
        case .privateKeyCreationFailed(let error):
            return "Failed to create private key: \(error?.localizedDescription ?? "Unknown error")"
        case .signatureCreationFailed(let error):
            return "Failed to create signature: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
} 
