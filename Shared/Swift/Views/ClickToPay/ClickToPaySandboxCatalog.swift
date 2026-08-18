//
//  ClickToPaySandboxCatalog.swift
//  SpreedlySDKExample
//
//  MC sandbox defaults for merchant-reference checkout.
//

import Foundation
import SpreedlyClickToPay

/// Non-PCI merchant checkout prefill — maps to `ClickToPayCheckoutConfig.tokenizeBilling` on present.
struct ClickToPayMerchantPrefill: Equatable {
    var firstName: String
    var lastName: String
    var phoneCountryCode: String
    var phoneNumber: String
    var addressLine1: String
    var addressLine2: String
    var city: String
    var state: String
    var zip: String
    var country: String
    /// When true, copies billing street fields onto shipping fields for tokenize QA.
    var copyBillingToShipping: Bool

    /// MC sandbox-style contact + shipping (Lee Cardholder / 123 Main St, New York).
    static let qaDefault = ClickToPayMerchantPrefill(
        firstName: "Lee",
        lastName: "Cardholder",
        phoneCountryCode: "1",
        phoneNumber: "",
        addressLine1: "123 Main St.",
        addressLine2: "",
        city: "New York",
        state: "NY",
        zip: "10011",
        country: "US",
        copyBillingToShipping: true
    )

    func makeTokenizeBilling(email: String) -> ClickToPayTokenizeBilling {
        let billing = ClickToPayTokenizeBilling()
        billing.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        billing.firstName = firstName.nilIfBlank
        billing.lastName = lastName.nilIfBlank
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPhone.isEmpty {
            billing.phoneNumber = trimmedPhone
        }
        billing.addressLine1 = addressLine1.nilIfBlank
        billing.addressLine2 = addressLine2.nilIfBlank
        billing.city = city.nilIfBlank
        billing.state = state.nilIfBlank
        billing.zip = zip.nilIfBlank
        billing.country = country.nilIfBlank

        if copyBillingToShipping {
            billing.shippingAddressLine1 = billing.addressLine1
            billing.shippingAddressLine2 = billing.addressLine2
            billing.shippingCity = billing.city
            billing.shippingState = billing.state
            billing.shippingZip = billing.zip
            billing.shippingCountry = billing.country
            billing.shippingPhoneNumber = billing.phoneNumber
        }
        return billing
    }
}

enum ClickToPaySandboxCatalog {
    static let locale = "en_US"
    static let dpaPresentationName = "Spreedly C2P Sandbox" // MC init dpaData only — not the sheet nav title
    static let dpaName = "SpreedlyC2PSandbox"
    static let scenario1Hint =
        "Email or phone with country code is required for lookup. Billing name and address prefill tokenize; cardholder name is prefilled in the Click to Pay sheet when provided. Card PAN/CVV stay in the sheet."

    /// Stable sandbox email for Remember-me / repeat-checkout QA (same identity across app launches).
    static let stableScenario1Email = "ybhatt@spreedly.com"

    static func freshScenario1Email() -> String {
        "c2p.scenario1.\(String(UUID().uuidString.prefix(8).lowercased()))@mailinator.com"
    }

    static func buildCheckoutConfig(
        email: String,
        doLookup: Bool,
        transactionAmount: Double,
        merchantPrefill: ClickToPayMerchantPrefill = .qaDefault,
        otpRememberMe: Bool = false,
        currencyCode: String = "USD"
    ) -> ClickToPayCheckoutConfig {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = merchantPrefill.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let countryCode = merchantPrefill.phoneCountryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let customer = ClickToPayCustomer(
            email: trimmedEmail.isEmpty ? nil : trimmedEmail,
            phoneNumber: trimmedPhone.isEmpty ? nil : trimmedPhone,
            countryCode: countryCode.isEmpty ? nil : countryCode
        )

        let cents = Int((transactionAmount * 100).rounded())
        let config = ClickToPayCheckoutConfig(
            initConfig: ClickToPayInitConfig(amountCents: cents, transactionCurrencyCode: currencyCode),
            srcDpaId: SpreedlyConfigManager.shared.c2pSandboxSrcDpaId,
            locale: locale,
            isSandbox: true,
            dpaPresentationName: dpaPresentationName,
            dpaName: dpaName,
            customer: customer,
            doLookup: doLookup
        )
        config.tokenizeBilling = merchantPrefill.makeTokenizeBilling(email: trimmedEmail)
        config.otp.rememberMe = otpRememberMe
        return config
    }

    static func buildDeviceDetectorConfig(
        transactionAmount: Double,
        currencyCode: String = "USD"
    ) -> ClickToPayCheckoutConfig {
        buildCheckoutConfig(
            email: "",
            doLookup: true,
            transactionAmount: transactionAmount,
            merchantPrefill: .qaDefault
        ).asSavedCardsDetectorConfig()
    }

    static func label(for card: ClickToPayMaskedCard) -> String {
        let brand = card.cardBrand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Card"
        let lastFour = card.panLastFour?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "••••"
        return "\(brand) •••• \(lastFour)"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
