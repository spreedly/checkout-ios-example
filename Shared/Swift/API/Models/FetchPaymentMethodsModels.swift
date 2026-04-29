//
//  FetchPaymentMethodsModels.swift
//  MerchantExample
//
//
//

import Foundation

// MARK: - Response Models
public struct FetchPaymentMethodsResponse: Codable {
    public let paymentMethods: [PaymentMethod]?
    
    private enum CodingKeys: String, CodingKey {
        case paymentMethods = "payment_methods"
    }
}

// MARK: - Payment Method Error
public struct PaymentMethodError: Codable {
    public let attribute: String?
    public let key: String?
    public let message: String?
}

// MARK: - Payment Method Model
public struct PaymentMethod: Codable {
    public let token: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let email: String?
    public let storageState: String?
    public let test: Bool?
    public let callbackUrl: String?
    
    // Credit card specific fields
    public let lastFourDigits: String?
    public let firstSixDigits: String?
    public let cardType: String?
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
    public let eligibleForCardUpdater: Bool?
    public let shippingAddress1: String?
    public let shippingAddress2: String?
    public let shippingCity: String?
    public let shippingState: String?
    public let shippingZip: String?
    public let shippingCountry: String?
    public let shippingPhoneNumber: String?
    public let issuerIdentificationNumber: String?
    public let clickToPay: Bool?
    public let managed: Bool?
    public let binMetadata: BinMetadata?
    public let subscribedToMastercardAbu: Bool?
    public let fingerprint: String?
    public let verificationValue: String?
    public let number: String?
    
    // Bank account specific fields
    public let bankName: String?
    public let accountType: String?
    public let accountHolderType: String?
    public let routingNumberDisplayDigits: String?
    public let accountNumberDisplayDigits: String?
    public let routingNumber: String?
    public let accountNumber: String?
    
    // Common fields
    public let paymentMethodType: String?
    public let storedCredentialUsage: StoredCredentialUsage?
    
    private enum CodingKeys: String, CodingKey {
        case token
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case email
        case storageState = "storage_state"
        case test
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
        case fingerprint
        case verificationValue = "verification_value"
        case number
        case bankName = "bank_name"
        case accountType = "account_type"
        case accountHolderType = "account_holder_type"
        case routingNumberDisplayDigits = "routing_number_display_digits"
        case accountNumberDisplayDigits = "account_number_display_digits"
        case routingNumber = "routing_number"
        case accountNumber = "account_number"
        case storedCredentialUsage = "stored_credential_usage"
    }
}

// MARK: - Payment Method Data
public struct PaymentMethodData: Codable {
    // This can contain any JSON structure, so we'll use a flexible approach
    public let extraStuff: ExtraStuff?
    public let myPaymentMethodIdentifier: Int?
    
    private enum CodingKeys: String, CodingKey {
        case extraStuff = "extra_stuff"
        case myPaymentMethodIdentifier = "my_payment_method_identifier"
    }
}

public struct ExtraStuff: Codable {
    public let someOtherThings: String?
    
    private enum CodingKeys: String, CodingKey {
        case someOtherThings = "some_other_things"
    }
}

// MARK: - Payment Method Metadata
public struct PaymentMethodMetadata: Codable {
    public let cardType: String?
    public let anotherKey: String?
    public let finalKey: String?
    public let key: String?
    
    private enum CodingKeys: String, CodingKey {
        case cardType = "card_type"
        case anotherKey = "another_key"
        case finalKey = "final_key"
        case key
    }
}

// MARK: - Bin Metadata
public struct BinMetadata: Codable {
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

// MARK: - Stored Credential Usage
public struct StoredCredentialUsage: Codable {
    public let test: StoredCredentialTest?
    
    private enum CodingKeys: String, CodingKey {
        case test
    }
}

public struct StoredCredentialTest: Codable {
    public let originalNetworkTransactionId: String?
    public let networkTransactionId: String?
    
    private enum CodingKeys: String, CodingKey {
        case originalNetworkTransactionId = "original_network_transaction_id"
        case networkTransactionId = "network_transaction_id"
    }
}

