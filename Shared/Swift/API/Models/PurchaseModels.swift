//
//  PurchaseModels.swift
//  MerchantExample
//
//
//

import Foundation
import SpreedlyCore

// MARK: - Purchase Transaction Request (3DS Global)
public struct PurchaseTransactionRequest: Codable {
    public let amount: Double // Use Double for JSON encoding (Decimal doesn't encode directly)
    public let currencyCode: String
    public let paymentMethodToken: String
    
    private enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case paymentMethodToken = "payment_method_token"
    }
    
    public init(
        amount: Decimal,
        currencyCode: String,
        paymentMethodToken: String
    ) {
        // Convert Decimal to Double for JSON encoding
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.currencyCode = currencyCode
        self.paymentMethodToken = paymentMethodToken
    }
}

// MARK: - Purchase Transaction Request (Gateway-Specific 3DS)
public struct GatewaySpecificPurchaseTransactionRequest: Codable {
    public let amount: Double
    public let currencyCode: String
    public let paymentMethodToken: String
    public let attempt3DSecure: Bool

    private enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case paymentMethodToken = "payment_method_token"
        case attempt3DSecure = "attempt_3dsecure"
    }

    public init(
        amount: Decimal,
        currencyCode: String,
        paymentMethodToken: String,
        attempt3DSecure: Bool = true
    ) {
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.currencyCode = currencyCode
        self.paymentMethodToken = paymentMethodToken
        self.attempt3DSecure = attempt3DSecure
    }
}

// MARK: - Offsite Purchase Request (merchant backend POST /offsite-purchase; gateway, redirect_url, callback_url, channel)
public struct OffsitePurchaseRequest: Codable {
    public let gateway: String
    public let amount: Double
    public let currencyCode: String
    public let paymentMethodToken: String
    public let redirectUrl: String
    public let callbackUrl: String
    public let channel: String

    private enum CodingKeys: String, CodingKey {
        case gateway
        case amount
        case currencyCode = "currency_code"
        case paymentMethodToken = "payment_method_token"
        case redirectUrl = "redirect_url"
        case callbackUrl = "callback_url"
        case channel
    }

    public init(
        gateway: String,
        amount: Decimal,
        currencyCode: String,
        paymentMethodToken: String,
        redirectUrl: String,
        callbackUrl: String,
        channel: String = "app"
    ) {
        self.gateway = gateway
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.currencyCode = currencyCode
        self.paymentMethodToken = paymentMethodToken
        self.redirectUrl = redirectUrl
        self.callbackUrl = callbackUrl
        self.channel = channel
    }
}

// MARK: - Heroku create-purchase (Stripe / EBANX): gateway + transaction
public struct HerokuCreatePurchaseRequest: Codable {
    public let gateway: String
    public let transaction: HerokuCreatePurchaseTransaction

    public init(gateway: String, transaction: HerokuCreatePurchaseTransaction) {
        self.gateway = gateway
        self.transaction = transaction
    }
}

public struct HerokuCreatePurchaseTransaction: Codable {
    public let paymentMethodToken: String?
    public let amount: Double
    public let currencyCode: String
    public let redirectUrl: String
    public let callbackUrl: String
    public let channel: String
    /// Stripe only: payment_method with payment_method_type "stripe_apm" and apm_types; omitted for EBANX.
    public let paymentMethod: StripeAPMPaymentMethod?

    private enum CodingKeys: String, CodingKey {
        case paymentMethodToken = "payment_method_token"
        case amount
        case currencyCode = "currency_code"
        case redirectUrl = "redirect_url"
        case callbackUrl = "callback_url"
        case channel
        case paymentMethod = "payment_method"
    }

    public init(
        paymentMethodToken: String? = nil,
        amount: Decimal,
        currencyCode: String,
        redirectUrl: String,
        callbackUrl: String,
        channel: String = "app",
        paymentMethod: StripeAPMPaymentMethod? = nil
    ) {
        self.paymentMethodToken = paymentMethodToken
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.currencyCode = currencyCode
        self.redirectUrl = redirectUrl
        self.callbackUrl = callbackUrl
        self.channel = channel
        self.paymentMethod = paymentMethod
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(paymentMethodToken, forKey: .paymentMethodToken)
        try container.encode(amount, forKey: .amount)
        try container.encode(currencyCode, forKey: .currencyCode)
        try container.encode(redirectUrl, forKey: .redirectUrl)
        try container.encode(callbackUrl, forKey: .callbackUrl)
        try container.encode(channel, forKey: .channel)
        try container.encodeIfPresent(paymentMethod, forKey: .paymentMethod)
    }
}

// MARK: - Heroku Braintree purchase (flat body + channel)
public struct HerokuBraintreePurchaseRequest: Codable {
    public let amount: Double
    public let currencyCode: String
    public let redirectUrl: String
    public let callbackUrl: String
    public let channel: String
    public let paymentMethodType: String

    private enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case redirectUrl = "redirect_url"
        case callbackUrl = "callback_url"
        case channel
        case paymentMethodType = "payment_method_type"
    }

    public init(
        amount: Decimal,
        currencyCode: String,
        redirectUrl: String,
        callbackUrl: String,
        channel: String = "app",
        paymentMethodType: String
    ) {
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.currencyCode = currencyCode
        self.redirectUrl = redirectUrl
        self.callbackUrl = callbackUrl
        self.channel = channel
        self.paymentMethodType = paymentMethodType
    }
}

// MARK: - Heroku confirm (Stripe / Braintree): state, nonce, payment_method_type
public struct HerokuConfirmRequest: Codable {
    public let state: String
    public let nonce: String
    public let paymentMethodType: String

    private enum CodingKeys: String, CodingKey {
        case state
        case nonce
        case paymentMethodType = "payment_method_type"
    }

    public init(state: String, nonce: String, paymentMethodType: String) {
        self.state = state
        self.nonce = nonce
        self.paymentMethodType = paymentMethodType
    }
}

// MARK: - Purchase Response Model
public struct PurchaseResponse: Codable {
    public let transaction: PurchaseTransaction?
    public let errors: [PurchaseError]?
}

// MARK: - Purchase Transaction (Response)
public struct PurchaseTransaction: Codable {
    public let onTestGateway: Bool?
    public let createdAt: String?
    public let updatedAt: String?
    public let succeeded: Bool
    public let state: String?
    public let token: String
    public let transactionType: String?
    public let orderId: String?
    public let ip: String?
    public let description: String?
    public let email: String?
    public let merchantNameDescriptor: String?
    public let merchantLocationDescriptor: String?
    public let merchantProfileKey: String?
    public let gatewayTransactionId: String?
    public let subMerchantKey: String?
    public let gatewayLatencyMs: Int?
    public let warning: String?
    public let applicationId: String?
    public let amount: Int?
    public let localAmount: Int?
    public let currencyCode: String?
    public let retainOnSuccess: Bool?
    public let paymentMethodAdded: Bool?
    public let smartRouted: Bool?
    public let storedCredentialInitiator: String?
    public let storedCredentialReasonType: String?
    public let storedCredentialAlternateGateway: String?
    public let storedCredentialFinalPayment: Bool?
    public let messageKey: String?
    public let message: String?
    public let gatewayToken: String?
    public let gatewayType: String?
    public let shippingAddress: ShippingAddress?
    public let apiUrls: [ApiUrl]?
    public let attempt3dsecure: Bool?
    public let paymentMethod: PaymentMethod?
    public let scaAuthentication: SCAAuthentication?
    public let gatewaySpecificResponseFields: GatewaySpecificResponseFields?
    
    private enum CodingKeys: String, CodingKey {
        case onTestGateway = "on_test_gateway"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case succeeded
        case state
        case token
        case transactionType = "transaction_type"
        case orderId = "order_id"
        case ip
        case description
        case email
        case merchantNameDescriptor = "merchant_name_descriptor"
        case merchantLocationDescriptor = "merchant_location_descriptor"
        case merchantProfileKey = "merchant_profile_key"
        case gatewayTransactionId = "gateway_transaction_id"
        case subMerchantKey = "sub_merchant_key"
        case gatewayLatencyMs = "gateway_latency_ms"
        case warning
        case applicationId = "application_id"
        case amount
        case localAmount = "local_amount"
        case currencyCode = "currency_code"
        case retainOnSuccess = "retain_on_success"
        case paymentMethodAdded = "payment_method_added"
        case smartRouted = "smart_routed"
        case storedCredentialInitiator = "stored_credential_initiator"
        case storedCredentialReasonType = "stored_credential_reason_type"
        case storedCredentialAlternateGateway = "stored_credential_alternate_gateway"
        case storedCredentialFinalPayment = "stored_credential_final_payment"
        case messageKey = "message_key"
        case message
        case gatewayToken = "gateway_token"
        case gatewayType = "gateway_type"
        case shippingAddress = "shipping_address"
        case apiUrls = "api_urls"
        case attempt3dsecure = "attempt_3dsecure"
        case paymentMethod = "payment_method"
        case scaAuthentication = "sca_authentication"
        case gatewaySpecificResponseFields = "gateway_specific_response_fields"
    }
}

// MARK: - Gateway Specific Response Fields (Stripe APM)

public struct GatewaySpecificResponseFields: Codable {
    public let stripePaymentIntents: StripePaymentIntentsResponseFields?
    public let braintree: BraintreeResponseFields?

    private enum CodingKeys: String, CodingKey {
        case stripePaymentIntents = "stripe_payment_intents"
        case braintree
    }
}

public struct StripePaymentIntentsResponseFields: Codable {
    public let clientSecret: String?

    private enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
    }
}

// MARK: - SCA Authentication
public struct SCAAuthentication: Codable {
    public let createdAt: String?
    public let updatedAt: String?
    public let succeeded: Bool?
    public let state: String?
    public let token: String?
    public let flowPerformed: String?
    public let message: String?
    public let scaProviderKey: String?
    public let amount: Int?
    public let currencyCode: String?
    public let ip: String?
    public let email: String?
    public let orderId: String?
    public let threeDsVersion: String?
    public let ecommerceIndicator: String?
    public let authenticationValue: String?
    public let directoryServerTransactionId: String?
    public let authenticationValueAlgorithm: String?
    public let directoryResponseStatus: String?
    public let authenticationResponseStatus: String?
    public let requiredAction: String?
    public let acsReferenceNumber: String?
    public let acsRenderingType: String?
    public let acsSignedContent: String?
    public let acsTransactionId: String?
    public let sdkTransactionId: String?
    public let challengeForm: String?
    public let challengeFormEmbedUrl: String?
    public let threeDsServerTransId: String?
    public let xid: String?
    public let enrolled: String?
    public let transactionType: String?
    public let gatewayTransactionKey: String?
    public let callbackUrl: String?
    public let testScenario: String?
    public let threeDsRequestorChallengeInd: String?
    public let transStatusReason: String?
    public let exemptionType: String?
    public let acquiringBankFraudRate: String?
    public let warning: String?
    public let daf: Bool?
    public let forceDaf: Bool?
    public let managedOrderToken: String?
    public let paymentMethodKey: String?
    
    private enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case succeeded
        case state
        case token
        case flowPerformed = "flow_performed"
        case message
        case scaProviderKey = "sca_provider_key"
        case amount
        case currencyCode = "currency_code"
        case ip
        case email
        case orderId = "order_id"
        case threeDsVersion = "three_ds_version"
        case ecommerceIndicator = "ecommerce_indicator"
        case authenticationValue = "authentication_value"
        case directoryServerTransactionId = "directory_server_transaction_id"
        case authenticationValueAlgorithm = "authentication_value_algorithm"
        case directoryResponseStatus = "directory_response_status"
        case authenticationResponseStatus = "authentication_response_status"
        case requiredAction = "required_action"
        case acsReferenceNumber = "acs_reference_number"
        case acsRenderingType = "acs_rendering_type"
        case acsSignedContent = "acs_signed_content"
        case acsTransactionId = "acs_transaction_id"
        case sdkTransactionId = "sdk_transaction_id"
        case challengeForm = "challenge_form"
        case challengeFormEmbedUrl = "challenge_form_embed_url"
        case threeDsServerTransId = "three_ds_server_trans_id"
        case xid
        case enrolled
        case transactionType = "transaction_type"
        case gatewayTransactionKey = "gateway_transaction_key"
        case callbackUrl = "callback_url"
        case testScenario = "test_scenario"
        case threeDsRequestorChallengeInd = "three_ds_requestor_challenge_ind"
        case transStatusReason = "trans_status_reason"
        case exemptionType = "exemption_type"
        case acquiringBankFraudRate = "acquiring_bank_fraud_rate"
        case warning
        case daf
        case forceDaf = "force_daf"
        case managedOrderToken = "managed_order_token"
        case paymentMethodKey = "payment_method_key"
    }
}

// MARK: - Shipping Address
public struct ShippingAddress: Codable {
    public let name: String?
    public let address1: String?
    public let address2: String?
    public let city: String?
    public let state: String?
    public let zip: String?
    public let country: String?
    public let phoneNumber: String?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case address1
        case address2
        case city
        case state
        case zip
        case country
        case phoneNumber = "phone_number"
    }
}

// MARK: - API URL
public struct ApiUrl: Codable {
    public let referencingTransaction: [String]?
    public let failoverTransaction: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case referencingTransaction = "referencing_transaction"
        case failoverTransaction = "failover_transaction"
    }
}

// MARK: - Purchase Error
public struct PurchaseError: Codable {
    public let attribute: String?
    public let key: String?
    public let message: String?
}

// MARK: - Spreedly Direct Purchase Request (wraps transaction in "transaction" key)
public struct SpreedlyPurchaseTransactionRequest: Codable {
    public let transaction: SpreedlyPurchaseTransaction

    public init(transaction: SpreedlyPurchaseTransaction) {
        self.transaction = transaction
    }
}

public struct SpreedlyPurchaseTransaction: Codable {
    public let amount: Double
    public let browserInfo: String
    public let currencyCode: String
    public let paymentMethodToken: String
    public let ip: String
    public let redirectUrl: String
    public let channel: String
    public let callbackUrl: String
    public let scaProviderKey: String?

    private enum CodingKeys: String, CodingKey {
        case amount
        case browserInfo = "browser_info"
        case currencyCode = "currency_code"
        case paymentMethodToken = "payment_method_token"
        case ip
        case redirectUrl = "redirect_url"
        case channel
        case callbackUrl = "callback_url"
        case scaProviderKey = "sca_provider_key"
    }

    public init(
        amount: Decimal,
        browserInfo: String,
        currencyCode: String,
        paymentMethodToken: String,
        ip: String,
        redirectUrl: String,
        channel: String = "app",
        callbackUrl: String,
        scaProviderKey: String? = nil
    ) {
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.browserInfo = browserInfo
        self.currencyCode = currencyCode
        self.paymentMethodToken = paymentMethodToken
        self.ip = ip
        self.redirectUrl = redirectUrl
        self.channel = channel
        self.callbackUrl = callbackUrl
        self.scaProviderKey = scaProviderKey
    }
}

// MARK: - Transaction Complete Response
/// Response model for Complete API endpoint (POST /v1/transactions/{token}/complete.json)
/// This wrapper is used by merchants to decode the complete API response
/// The transaction object can then be passed to the SDK's finalizeTransaction() method
public struct TransactionCompleteResponse: Codable {
    public let transaction: TransactionStatus?
    public let errors: [TransactionStatusError]?
    
    public init(transaction: TransactionStatus? = nil, errors: [TransactionStatusError]? = nil) {
        self.transaction = transaction
        self.errors = errors
    }
}