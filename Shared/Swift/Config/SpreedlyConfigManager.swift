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
    let c2pSandboxSrcDpaId: String = infoPlistValue(forKey: "SpreedlyC2PSandboxSrcDpaId")
    /// Must match a merchant ID in the app's Apple Pay entitlement (`SPREEDLY_APPLE_PAY_MERCHANT_ID` in SpreedlyKeys.xcconfig).
    let applePayMerchantId: String = infoPlistValue(forKey: "SpreedlyApplePayMerchantId")

    /// Template-only placeholders from `SpreedlyKeys.xcconfig.example` (not real Apple Merchant IDs).
    /// Real IDs may contain the word "example" (e.g. `merchant.com.spreedly.example`) — those are allowed.
    private static let applePayMerchantIdTemplatePlaceholders: Set<String> = [
        "merchant.com.your.example",
        "merchant.com.example"
    ]

    /// `nil` when the configured Merchant ID looks usable; otherwise a merchant-facing fix message.
    var applePayMerchantIdConfigurationError: String? {
        let trimmed = applePayMerchantId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Apple Pay Merchant ID is empty. Set SPREEDLY_APPLE_PAY_MERCHANT_ID in SpreedlyKeys.xcconfig to your real Merchant ID from Apple Developer, enable Apple Pay on the app target with the same ID, then rebuild."
        }
        if Self.applePayMerchantIdTemplatePlaceholders.contains(trimmed.lowercased()) {
            return "Apple Pay Merchant ID is still the template value (\(trimmed)). Set SPREEDLY_APPLE_PAY_MERCHANT_ID in SpreedlyKeys.xcconfig to the Merchant ID you created in Apple Developer (must match the Apple Pay entitlement), then rebuild."
        }
        return nil
    }

    /// Whether Example Apple Pay can reasonably attempt a device token (does not prove Apple Developer setup).
    var isApplePayMerchantIdConfigured: Bool {
        applePayMerchantIdConfigurationError == nil
    }
    
    private init() {
        Spreedly.initializeSDK()
        if let error = applePayMerchantIdConfigurationError {
            print("[SpreedlyExample] Apple Pay config: \(error)")
        }
    }
    
    static func setup() {
        shared = SpreedlyConfigManager()
    }
    
    /// Fresh signed auth from the demo backend, without applying it. Signed auth works for one
    /// request only, so Apple Pay asks for a new one on every payment attempt.
    func fetchSignedAuth() async throws -> SpreedlyConfig {
        let config = SignatureSecurityService.ServerSecurityConfig(
            serverURL: serverURL,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            environmentKey: environmentKey
        )
        let result = await SignatureSecurityService.setupServerBasedSecurity(config: config)
        guard let signatureParams = result.signatureParams else {
            throw result.error ?? NSError(
                domain: "SpreedlyConfigManager",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Failed to generate signature parameters"]
            )
        }
        return SpreedlyConfig(
            environmentKey: environmentKey,
            forterSiteId: forterSiteId,
            certificateToken: signatureParams.certificateToken,
            nonce: signatureParams.nonce,
            signature: signatureParams.signature,
            timestamp: String(signatureParams.timestamp)
        )
    }

    @discardableResult
    func generateSignature() async -> Result<Bool, Error> {
        let spreedlyConfig: SpreedlyConfig
        do {
            spreedlyConfig = try await fetchSignedAuth()
        } catch {
            return .failure(error)
        }
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
