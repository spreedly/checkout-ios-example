//
//  StripeAPMPurchaseModels.swift
//  MerchantExample
//
//  Request models for creating a Stripe APM pending purchase via Spreedly API.
//  Matches the API at: POST /v1/gateways/{gateway_token}/purchase.json
//  Ref: https://developer.spreedly.com/docs/stripe-apm-offsite-payments
//

import Foundation

// MARK: - Stripe APM Purchase Request

public struct StripeAPMPurchaseRequest: Codable {
    public let transaction: StripeAPMPurchaseTransaction

    public init(transaction: StripeAPMPurchaseTransaction) {
        self.transaction = transaction
    }
}

// MARK: - Stripe APM Purchase Transaction

public struct StripeAPMPurchaseTransaction: Codable {
    public let amount: Double
    public let currencyCode: String
    public let redirectUrl: String
    public let callbackUrl: String
    public let channel: String
    public let paymentMethod: StripeAPMPaymentMethod

    private enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case redirectUrl = "redirect_url"
        case callbackUrl = "callback_url"
        case channel
        case paymentMethod = "payment_method"
    }

    public init(
        amount: Decimal,
        currencyCode: String,
        redirectUrl: String,
        callbackUrl: String,
        channel: String = "app",
        paymentMethod: StripeAPMPaymentMethod
    ) {
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.currencyCode = currencyCode
        self.redirectUrl = redirectUrl
        self.callbackUrl = callbackUrl
        self.channel = channel
        self.paymentMethod = paymentMethod
    }
}

// MARK: - Stripe APM Payment Method

public struct StripeAPMPaymentMethod: Codable {
    public let paymentMethodType: String
    public let apmTypes: [String]

    private enum CodingKeys: String, CodingKey {
        case paymentMethodType = "payment_method_type"
        case apmTypes = "apm_types"
    }

    public init(apmTypes: [String]) {
        self.paymentMethodType = "stripe_apm"
        self.apmTypes = apmTypes
    }
}
