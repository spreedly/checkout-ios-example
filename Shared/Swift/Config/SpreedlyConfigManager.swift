//
//  SpreedlyConfigManager.swift
//  SpreedlySDKExample
//
//  Created by Vinay Naikade on 23/07/25.
//

import Foundation
import SpreedlyCore

class SpreedlyConfigManager {
    static var shared: SpreedlyConfigManager!

    private static func infoPlistValue(forKey key: String) -> String {
        Bundle.main.infoDictionary?[key] as? String ?? ""
    }
    
    private let environmentKey: String = infoPlistValue(forKey: "SpreedlyEnvironmentKey")
    private let forterSiteId: String = infoPlistValue(forKey: "SpreedlyForterSiteId")
    private let serverURL: String = infoPlistValue(forKey: "SpreedlyServerURL")
    private let baseURL: String = infoPlistValue(forKey: "SpreedlyBaseURL")
    let stripePublishableKey: String = infoPlistValue(forKey: "StripePublishableKey")
    private let apiKey: String = infoPlistValue(forKey: "SpreedlyApiKey")
    
    private init() {
        Spreedly.initializeSDK()
    }
    
    static func setup() {
        shared = SpreedlyConfigManager()
    }
    
    @discardableResult
    func generateSignature() async -> Result<Bool, Error> {
        let config = SignatureSecurityService.ServerSecurityConfig(
            serverURL: serverURL,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            environmentKey: environmentKey
        )
        let result = await SignatureSecurityService.setupServerBasedSecurity(config: config)
        guard let signatureParams = result.signatureParams else {
            return .failure(result.error ?? NSError(domain: "SpreedlyConfigManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to generate signature parameters"]))
        }
        let spreedlyConfig = SpreedlyConfig(
            environmentKey: environmentKey,
            forterSiteId: forterSiteId,
            certificateToken: signatureParams.certificateToken,
            nonce: signatureParams.nonce,
            signature: signatureParams.signature,
            timestamp: String(signatureParams.timestamp)
        )
        Spreedly.setup(config: spreedlyConfig)
        if let error = Spreedly.initializationError {
            return .failure(NSError(
                domain: "SpreedlyConfigManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "SDK blocked: \(error.message)"]
            ))
        }
        return .success(true)
    }
    
    /// Creates a RetainPaymentMethodAPIClient with configured settings
    func createRetainPaymentMethodAPIClient() -> RetainPaymentMethodAPIClient {
        let config = RetainPaymentMethodAPIClient.ServerConfig(
            baseURL: baseURL,
            timeoutInterval: 30.0,
            apiKey: apiKey.isEmpty ? nil : apiKey
        )
        return RetainPaymentMethodAPIClient(config: config)
    }
    
    /// Creates a FetchPaymentMethodsAPIClient with configured settings
    func createFetchPaymentMethodsAPIClient() -> FetchPaymentMethodsAPIClient {
        let config = FetchPaymentMethodsAPIClient.ServerConfig(
            baseURL: baseURL,
            timeoutInterval: 30.0,
            apiKey: apiKey.isEmpty ? nil : apiKey
        )
        return FetchPaymentMethodsAPIClient(config: config)
    }
    
    /// Creates a PurchaseAPIClient with configured settings (Heroku base URL only; no gateway tokens).
    func createPurchaseAPIClient() -> PurchaseAPIClient {
        let config = PurchaseAPIClient.ServerConfig(
            baseURL: baseURL,
            timeoutInterval: 30.0
        )
        return PurchaseAPIClient(config: config)
    }
}
