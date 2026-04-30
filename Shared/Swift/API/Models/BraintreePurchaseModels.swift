//
//  BraintreePurchaseModels.swift
//  SpreedlySDKExample
//
//  Request/response models for creating a Braintree purchase via Spreedly API.
//  POST /v1/gateways/{braintree_gateway_token}/purchase.json
//

import Foundation

// MARK: - Braintree Purchase Request

struct BraintreePurchaseRequest: Codable {
    let transaction: BraintreePurchaseTransaction
}

struct BraintreePurchaseTransaction: Codable {
    let amount: Double
    let currencyCode: String
    let paymentMethod: BraintreeOffsitePaymentMethod
    let gatewaySpecificFields: BraintreeGatewaySpecificFields?

    private enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode = "currency_code"
        case paymentMethod = "payment_method"
        case gatewaySpecificFields = "gateway_specific_fields"
    }

    init(
        amount: Decimal,
        currencyCode: String,
        paymentMethod: BraintreeOffsitePaymentMethod,
        gatewaySpecificFields: BraintreeGatewaySpecificFields? = nil
    ) {
        self.amount = NSDecimalNumber(decimal: amount).doubleValue
        self.currencyCode = currencyCode
        self.paymentMethod = paymentMethod
        self.gatewaySpecificFields = gatewaySpecificFields
    }
}

struct BraintreeOffsitePaymentMethod: Codable {
    let paymentMethodType: String
    let offsiteSync: Bool

    private enum CodingKeys: String, CodingKey {
        case paymentMethodType = "payment_method_type"
        case offsiteSync = "offsite_sync"
    }

    init(paymentMethodType: String) {
        self.paymentMethodType = paymentMethodType
        self.offsiteSync = true
    }
}

// MARK: - Gateway specific fields

struct BraintreeGatewaySpecificFields: Codable {
    let braintree: BraintreeFields

    struct BraintreeFields: Codable {
        let paypalFlowType: String?
        let venmoFlowType: String?
        let venmoProfileId: String?

        private enum CodingKeys: String, CodingKey {
            case paypalFlowType = "paypal_flow_type"
            case venmoFlowType = "venmo_flow_type"
            case venmoProfileId = "venmo_profile_id"
        }
    }
}

// MARK: - Braintree-specific response fields

public struct BraintreeResponseFields: Codable {
    public let clientToken: String?

    private enum CodingKeys: String, CodingKey {
        case clientToken = "client_token"
    }
}

// MARK: - Confirm request (merchant backend calls this)

struct BraintreeConfirmRequest: Codable {
    let state: String
    let nonce: String
    let deviceData: String?
    let paymentMethod: BraintreeConfirmPaymentMethod

    private enum CodingKeys: String, CodingKey {
        case state
        case nonce
        case deviceData = "device_data"
        case paymentMethod = "payment_method"
    }
}

struct BraintreeConfirmPaymentMethod: Codable {
    let paymentMethodType: String

    private enum CodingKeys: String, CodingKey {
        case paymentMethodType = "payment_method_type"
    }
}
