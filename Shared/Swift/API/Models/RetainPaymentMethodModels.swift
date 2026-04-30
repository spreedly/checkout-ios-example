//
//  RetainPaymentMethodModels.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import Foundation

// MARK: - Metadata Model
public struct RetainPaymentMethodMetadata: Codable {
    public let cardType: String?
    
    private enum CodingKeys: String, CodingKey {
        case cardType = "card_type"
    }
}

// MARK: - Response Models
public struct RetainPaymentMethodResponse: Codable {
    public let transaction: RetainPaymentMethodTransaction
}

public struct RetainPaymentMethodTransaction: Codable {
    public let token: String
    public let createdAt: String
    public let updatedAt: String
    public let succeeded: Bool
    public let transactionType: String
    public let state: String
    public let messageKey: String
    public let message: String
    public let paymentMethod: RetainPaymentMethod
    
    private enum CodingKeys: String, CodingKey {
        case token
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case succeeded
        case transactionType = "transaction_type"
        case state
        case messageKey = "message_key"
        case message
        case paymentMethod = "payment_method"
    }
}

public struct RetainPaymentMethod: Codable {
    public let token: String
    public let createdAt: String
    public let updatedAt: String
    public let email: String?
    public let data: String?
    public let storageState: String
    public let test: Bool
    public let metadata: RetainPaymentMethodMetadata?
    public let callbackUrl: String?
    public let lastFourDigits: String
    public let firstSixDigits: String
    public let cardType: String
    public let firstName: String?
    public let lastName: String?
    public let month: Int?
    public let year: Int?
    public let address1: String?
    public let address2: String?
    public let city: String?
    public let state: String?
    public let zip: String?
    public let country: String?
    public let phoneNumber: String?
    public let company: String?
    public let fullName: String?
    public let eligibleForCardUpdater: Bool
    public let shippingAddress1: String?
    public let shippingAddress2: String?
    public let shippingCity: String?
    public let shippingState: String?
    public let shippingZip: String?
    public let shippingCountry: String?
    public let shippingPhoneNumber: String?
    public let issuerIdentificationNumber: String?
    public let clickToPay: Bool
    public let managed: Bool
    public let binMetadata: RetainPaymentMethodBinMetadata?
    public let subscribedToMastercardAbu: Bool
    public let paymentMethodType: String
    public let errors: [String]
    public let fingerprint: String?
    public let verificationValue: String
    public let number: String
    
    private enum CodingKeys: String, CodingKey {
        case token
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case email
        case data
        case storageState = "storage_state"
        case test
        case metadata
        case callbackUrl = "callback_url"
        case lastFourDigits = "last_four_digits"
        case firstSixDigits = "first_six_digits"
        case cardType = "card_type"
        case firstName = "first_name"
        case lastName = "last_name"
        case month
        case year
        case address1
        case address2
        case city
        case state
        case zip
        case country
        case phoneNumber = "phone_number"
        case company
        case fullName = "full_name"
        case eligibleForCardUpdater = "eligible_for_card_updater"
        case shippingAddress1 = "shipping_address1"
        case shippingAddress2 = "shipping_address2"
        case shippingCity = "shipping_city"
        case shippingState = "shipping_state"
        case shippingZip = "shipping_zip"
        case shippingCountry = "shipping_country"
        case shippingPhoneNumber = "shipping_phone_number"
        case issuerIdentificationNumber = "issuer_identification_number"
        case clickToPay = "click_to_pay"
        case managed
        case binMetadata = "bin_metadata"
        case subscribedToMastercardAbu = "subscribed_to_mastercard_abu"
        case paymentMethodType = "payment_method_type"
        case errors
        case fingerprint
        case verificationValue = "verification_value"
        case number
    }
}

public struct RetainPaymentMethodBinMetadata: Codable {
    public let cardBrand: String?
    public let issuingBank: String?
    public let cardType: String?
    public let cardCategory: String?
    public let issuingCountryIsoNumber: String?
    public let issuingBankWebsite: String?
    public let issuingBankPhoneNumber: String?
    public let maxPanLength: Int?
    public let binType: String?
    public let regulated: String?
    public let issuingCountryIsoA2Code: String?
    public let issuingCountryIsoA3Code: String?
    public let issuingCountryIsoName: String?
    
    private enum CodingKeys: String, CodingKey {
        case cardBrand = "card_brand"
        case issuingBank = "issuing_bank"
        case cardType = "card_type"
        case cardCategory = "card_category"
        case issuingCountryIsoNumber = "issuing_country_iso_number"
        case issuingBankWebsite = "issuing_bank_website"
        case issuingBankPhoneNumber = "issuing_bank_phone_number"
        case maxPanLength = "max_pan_length"
        case binType = "bin_type"
        case regulated
        case issuingCountryIsoA2Code = "issuing_country_iso_a2_code"
        case issuingCountryIsoA3Code = "issuing_country_iso_a3_code"
        case issuingCountryIsoName = "issuing_country_iso_name"
    }
}

