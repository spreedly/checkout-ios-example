//
//  EbanxPurchaseModels.swift
//  MerchantExample
//

import Foundation

// MARK: - EBANX Purchase Request (wraps transaction in "transaction" key)

public struct EbanxPurchaseRequest: Codable {
    public let transaction: EbanxPurchaseTransaction

    public init(transaction: EbanxPurchaseTransaction) {
        self.transaction = transaction
    }
}

// MARK: - EBANX Purchase Transaction

public struct EbanxPurchaseTransaction: Codable {
    public let amount: Double
    public let currencyCode: String
    public let paymentMethodToken: String
    public let redirectUrl: String
    public let callbackUrl: String
    public let channel: String
    public let gatewaySpecificFields: EbanxGatewaySpecificFields?

    private enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case paymentMethodToken = "payment_method_token"
        case redirectUrl = "redirect_url"
        case callbackUrl = "callback_url"
        case channel
        case gatewaySpecificFields = "gateway_specific_fields"
    }

    public init(
        amount: Decimal,
        currencyCode: String,
        paymentMethodToken: String,
        redirectUrl: String,
        callbackUrl: String,
        channel: String = "app",
        gatewaySpecificFields: EbanxGatewaySpecificFields? = nil
    ) {
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.currencyCode = currencyCode
        self.paymentMethodToken = paymentMethodToken
        self.redirectUrl = redirectUrl
        self.callbackUrl = callbackUrl
        self.channel = channel
        self.gatewaySpecificFields = gatewaySpecificFields
    }
}

// MARK: - Gateway-Specific Fields

public struct EbanxGatewaySpecificFields: Codable {
    public let ebanx: EbanxFields

    public init(ebanx: EbanxFields) {
        self.ebanx = ebanx
    }
}

public struct EbanxFields: Codable {
    public let document: String?

    public init(document: String? = nil) {
        self.document = document
    }
}
