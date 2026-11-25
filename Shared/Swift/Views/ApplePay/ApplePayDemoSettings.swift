//
//  ApplePayDemoSettings.swift
//  SpreedlySDKExample
//
//  Every Apple Pay option the demo screens can change. Each screen makes its own copy, so its
//  changes reset when you go back and never leak into other screens.
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if canImport(SpreedlyApplePay)

import Combine
import Contacts
import Foundation
import PassKit
import SpreedlyApplePay
import SpreedlyCore

/// Which Apple Pay checkout a demo screen runs.
enum ApplePayDemoMode {
    /// Fixed $1.00 payment from the card drop-in.
    case oneTime
    /// Subscription sheet from the card drop-in.
    case recurring
}

enum ApplePayCardTypeRestriction: String, CaseIterable, Identifiable {
    case any = "Any"
    case debit = "Debit only"
    case credit = "Credit only"

    var id: String { rawValue }

    var capabilities: PKMerchantCapability {
        switch self {
        case .any: return .threeDSecure
        case .debit: return [.threeDSecure, .debit]
        case .credit: return [.threeDSecure, .credit]
        }
    }
}

enum ApplePayBillingInterval: String, CaseIterable, Identifiable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"
    case year = "Yearly"

    var id: String { rawValue }

    /// Apple Pay rejects week units, so a week is sent as 7 days (see `intervalCount`).
    var calendarUnit: NSCalendar.Unit {
        switch self {
        case .day, .week: return .day
        case .month: return .month
        case .year: return .year
        }
    }

    var intervalCount: Int { self == .week ? 7 : 1 }

    var shortLabel: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }
}

/// A labelled PassKit value for pickers.
struct ApplePayDemoOption<Value: Hashable>: Identifiable, Hashable {
    let label: String
    let value: Value
    var id: String { label }
}

enum ApplePayDemoCatalog {
    static let buttonTypes: [ApplePayDemoOption<PKPaymentButtonType>] = [
        .init(label: "Plain", value: .plain),
        .init(label: "Buy", value: .buy),
        .init(label: "Check Out", value: .checkout),
        .init(label: "Book", value: .book),
        .init(label: "Subscribe", value: .subscribe),
        .init(label: "Donate", value: .donate),
        .init(label: "Order", value: .order),
        .init(label: "Reload", value: .reload),
        .init(label: "Add Money", value: .addMoney),
        .init(label: "Top Up", value: .topUp),
        .init(label: "Rent", value: .rent),
        .init(label: "Support", value: .support),
        .init(label: "Contribute", value: .contribute),
        .init(label: "Tip", value: .tip),
        .init(label: "Continue", value: .continue),
        .init(label: "In Store", value: .inStore)
    ]

    static let buttonStyles: [ApplePayDemoOption<PKPaymentButtonStyle>] = [
        .init(label: "Automatic", value: .automatic),
        .init(label: "Black", value: .black),
        .init(label: "White", value: .white),
        .init(label: "Outline", value: .whiteOutline)
    ]

    /// Every network the SDK offers by default. Turn off networks your gateway does not accept.
    static let networks: [ApplePayDemoOption<PKPaymentNetwork>] = [
        .init(label: "Visa", value: .visa),
        .init(label: "Mastercard", value: .masterCard),
        .init(label: "American Express", value: .amex),
        .init(label: "Discover", value: .discover),
        .init(label: "JCB (Japan)", value: .JCB),
        .init(label: "Maestro", value: .maestro),
        .init(label: "Cartes Bancaires (France)", value: .cartesBancaires),
        .init(label: "Interac (Canada)", value: .interac),
        .init(label: "mada (Saudi Arabia)", value: .mada),
        .init(label: "Elo (Brazil)", value: .elo),
        .init(label: "Bancontact (Belgium)", value: .bancontact),
        .init(label: "Dankort (Denmark)", value: .dankort)
    ]

    /// Card-issuing countries offered in the demo (ISO 3166-1 alpha-2).
    static let countries: [ApplePayDemoOption<String>] = [
        .init(label: "United States", value: "US"),
        .init(label: "Canada", value: "CA"),
        .init(label: "United Kingdom", value: "GB"),
        .init(label: "Australia", value: "AU"),
        .init(label: "Germany", value: "DE"),
        .init(label: "France", value: "FR"),
        .init(label: "India", value: "IN"),
        .init(label: "Japan", value: "JP")
    ]

    static let contactFields: [ApplePayDemoOption<PKContactField>] = [
        .init(label: "Name", value: .name),
        .init(label: "Postal address", value: .postalAddress),
        .init(label: "Email", value: .emailAddress),
        .init(label: "Phone", value: .phoneNumber)
    ]
}

final class ApplePayDemoSettings: ObservableObject {

    // MARK: Button & theme
    @Published var buttonType: PKPaymentButtonType = .buy
    @Published var buttonStyle: PKPaymentButtonStyle = .automatic
    @Published var cornerRadius: Double = 8
    @Published var buttonHeight: Double = 48
    /// Demo offers Show Pay button or Hide when Wallet has no eligible card.
    @Published var emptyWalletBehavior: ApplePayEmptyWalletBehavior = .showPayButton
    @Published var dividerText: String = ""

    // MARK: Configuration
    @Published var countryCode = "US"
    @Published var currencyCode = "USD"
    @Published var networks: Set<PKPaymentNetwork> = Set(ApplePayConfiguration.defaultSupportedNetworks)
    @Published var cardTypes: ApplePayCardTypeRestriction = .any
    // Apple ignores a saved contact the sheet doesn't ask for, and the SDK rejects that setup, so a
    // prefill switches off with the field it needs.
    @Published var billingContactFields: Set<PKContactField> = [] {
        didSet { if !canPrefillBilling { prefillBillingContact = false } }
    }
    @Published var shippingContactFields: Set<PKContactField> = [] {
        didSet { if !canPrefillShipping { prefillShippingContact = false } }
    }
    @Published var includeMetadata = false
    /// Card-issuing countries (ISO codes). Empty accepts any country.
    @Published var supportedCountries: Set<String> = []
    /// Prefill the sheet with `syntheticSavedContact()` as the saved billing / shipping contact.
    @Published var prefillBillingContact = false
    @Published var prefillShippingContact = false
    var canPrefillBilling: Bool { billingContactFields.contains(.postalAddress) }
    var canPrefillShipping: Bool { !shippingContactFields.isEmpty }
    /// How the sheet labels the shipping address.
    @Published var shippingType: PKShippingType = .shipping
    @Published var simulateSlowServer = false
    /// The demo backend declines with a field error that marks the shipping address in the sheet.
    @Published var simulateUndeliverableAddress = false
    @Published var processPaymentTimeout: Double = ApplePayConfiguration.defaultProcessPaymentTimeout

    /// Name on the sheet's total line ("PAY SPREEDLY DEMO").
    static let merchantLabel = "Spreedly Demo"
    /// The one-time demo always charges this amount.
    static let oneTimeAmount = NSDecimalNumber(string: "1.00")

    /// Synthetic order ID sent as payment method metadata; fixed for this settings copy.
    let demoOrderId = "synthetic-\(Int(Date().timeIntervalSince1970))"

    /// Amount for one-time checkouts that let the shopper type one (Button Only).
    @Published var oneTimeAmountText = "1.00"

    // MARK: Recurring
    @Published var recurringInterval: ApplePayBillingInterval = .month
    @Published var recurringAmount = "1.00"
    @Published var freeTrial = false
    @Published var trialInterval: ApplePayBillingInterval = .week
    @Published var billingAgreement = ""
    @Published var managementURL = "https://example.com/account/subscription"

    /// Example subscription terms built from the current amount, interval and trial, for the
    /// sheet's billing agreement.
    var suggestedBillingTerms: String {
        let charge = "\(currencyCode.uppercased()) \(recurringAmount) every \(recurringInterval.shortLabel)"
        let start = freeTrial
            ? "Free for 1 \(trialInterval.shortLabel), then you'll be charged \(charge)"
            : "You'll be charged \(charge)"
        return start + " until you cancel. Cancel anytime from the manage subscription link."
    }

    /// Delay added to the demo purchase so Apple's ~30 s sheet timeout and the pending flow can be seen.
    static let slowServerDelaySeconds: UInt64 = 40

    // MARK: - Building SDK objects

    func makeConfiguration(mode: ApplePayDemoMode) -> ApplePayConfiguration {
        let configuration = ApplePayConfiguration(
            merchantIdentifier: SpreedlyConfigManager.shared.applePayMerchantId,
            countryCode: countryCode,
            currencyCode: currencyCode
        )
        let ordered = ApplePayDemoCatalog.networks.map(\.value).filter { networks.contains($0) }
        // Passed as is: with none selected the SDK fails the checkout ("needs at least one supported network").
        configuration.supportedNetworks = ordered
        configuration.merchantCapabilities = cardTypes.capabilities
        configuration.requiredBillingContactFields = billingContactFields
        configuration.requiredShippingContactFields = shippingContactFields
        // Passed as is: without the matching contact fields the SDK fails the checkout and says which to add.
        configuration.billingContact = prefillBillingContact ? Self.syntheticSavedContact() : nil
        configuration.shippingContact = prefillShippingContact ? Self.syntheticSavedContact() : nil
        configuration.shippingType = shippingType
        // Default Buy becomes Subscribe where that reads better; a picked type is kept.
        switch (mode, buttonType) {
        case (.recurring, .buy): configuration.buttonType = .subscribe
        default: configuration.buttonType = buttonType
        }
        configuration.buttonStyle = buttonStyle
        configuration.cornerRadius = CGFloat(cornerRadius)
        configuration.emptyWalletBehavior = emptyWalletBehavior
        configuration.processPaymentTimeout = processPaymentTimeout
        configuration.supportedCountries = supportedCountries.isEmpty ? nil : supportedCountries
        if includeMetadata {
            configuration.metadata = ["demo_order_id": demoOrderId]
        }
        configuration.testCardNumber = ApplePayTestCardSettings.shared.numberForCheckout
        return configuration
    }

    func makeOrder(mode: ApplePayDemoMode) -> ApplePayOrder {
        switch mode {
        case .oneTime: return ApplePayOrder(label: Self.merchantLabel, amount: oneTimeAmount)
        case .recurring: return makeRecurringOrder()
        }
    }

    /// Typed one-time amount; falls back to USD 1.00 when empty or not positive.
    var oneTimeAmount: NSDecimalNumber {
        let value = decimal(oneTimeAmountText)
        return value.compare(NSDecimalNumber.zero) == .orderedDescending ? value : Self.oneTimeAmount
    }

    /// `processPayment` for a checkout: the demo backend charges the card before the sheet shows success.
    func processPayment(mode: ApplePayDemoMode) -> ApplePayProcessPayment {
        { [self] authorization in try await charge(authorization, mode: mode) }
    }

    /// Wallet for the card drop-in, built from these settings.
    func makeWallet(mode: ApplePayDemoMode) -> SpreedlyApplePayWallet {
        let wallet = SpreedlyApplePayWallet(
            configuration: makeConfiguration(mode: mode),
            order: makeOrder(mode: mode),
            signedAuth: { try await ApplePayDemoSettings.signedAuth() },
            processPayment: processPayment(mode: mode)
        )
        wallet.prepareForPresentation = { await ApplePayDemoSettings.prepareForPresentation() }
        return wallet
    }

    /// "USD 12.50" — always two decimals for the demo display.
    func displayAmount(_ amount: NSDecimalNumber) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        return "\(currencyCode.uppercased()) \(formatter.string(from: amount) ?? amount.stringValue)"
    }

    /// Amount the backend charges in `processPayment`: today's charge (0 during a free trial).
    func chargeAmount(mode: ApplePayDemoMode) -> NSDecimalNumber {
        switch mode {
        case .oneTime: return oneTimeAmount
        case .recurring: return freeTrial ? .zero : decimal(recurringAmount)
        }
    }

    // MARK: - processPayment

    /// Demo `processPayment`: charges the token on the demo backend while the sheet is open, so
    /// Apple's success check means the money moved. A production backend takes the amount from its
    /// own order, sends an idempotency key, and for subscriptions sends stored-credential fields.
    /// Uses the backend's purchase without Spreedly 3DS: Apple Pay already authenticated the shopper.
    /// A 4xx reply means the backend answered and did not charge, so it is a decline the shopper can
    /// retry with another card. A network error or 5xx throws: the charge may have gone through, so
    /// the SDK reports "status unknown" instead of letting the shopper pay again.
    func charge(_ authorization: ApplePayPaymentAuthorization, mode: ApplePayDemoMode) async throws -> ApplePayPaymentDecision {
        if simulateSlowServer {
            try? await Task.sleep(nanoseconds: Self.slowServerDelaySeconds * 1_000_000_000)
        }
        if simulateUndeliverableAddress {
            // A real backend would check the shipping address before charging. The sheet marks the
            // address so the shopper can change it.
            let reason = Self.unserviceableAddressMessage(for: shippingType)
            return .declined(
                message: reason + ".",
                errors: [PKPaymentRequest.paymentShippingAddressUnserviceableError(withLocalizedDescription: reason)]
            )
        }
        let amount = chargeAmount(mode: mode)
        // Free trial: nothing to charge today; the token is retained for the first renewal.
        guard amount.compare(NSDecimalNumber.zero) == .orderedDescending else { return .approved }
        let currency = currencyCode.uppercased()
        let response: PurchaseResponse
        do {
            response = try await SpreedlyConfigManager.shared.createPurchaseAPIClient().simplePurchase(
                paymentMethodToken: authorization.paymentMethodToken,
                amount: Self.minorUnits(amount, currencyCode: currency),
                currencyCode: currency
            )
        } catch PurchaseAPIError.serverError(let status, _, let message) where (400..<500).contains(status) {
            return .declined(message: (message?.isEmpty ?? true) ? "Payment was declined" : message)
        }
        if let transaction = response.transaction, transaction.succeeded {
            return .approved
        }
        let reason = response.errors?.compactMap(\.message).joined(separator: ", ")
        return .declined(message: (reason?.isEmpty ?? true) ? "Payment was declined" : reason)
    }

    /// Synthetic saved contact for the prefill demo. Not a real person or address.
    /// Address error shown under Apple's heading on the sheet, worded to match the shipping type.
    static func unserviceableAddressMessage(for shippingType: PKShippingType) -> String {
        switch shippingType {
        case .delivery: return "We don't deliver to this address"
        case .storePickup: return "Store pickup isn't available for this address"
        case .servicePickup: return "Service isn't available at this address"
        default: return "We don't ship to this address"
        }
    }

    static func syntheticSavedContact() -> PKContact {
        let contact = PKContact()
        var name = PersonNameComponents()
        name.givenName = "Test"
        name.familyName = "Shopper"
        contact.name = name
        let address = CNMutablePostalAddress()
        address.street = "1 Example Street"
        address.city = "Springfield"
        address.state = "IL"
        address.postalCode = "62701"
        address.isoCountryCode = "US"
        address.country = "United States"
        contact.postalAddress = address
        contact.emailAddress = "test.shopper@example.com"
        // 555-01xx numbers are reserved for fiction.
        contact.phoneNumber = CNPhoneNumber(stringValue: "+1 555 010 0123")
        return contact
    }

    /// Amount in the currency's minor units (cents for USD, yen for JPY), as the demo backend expects.
    static func minorUnits(_ amount: NSDecimalNumber, currencyCode: String) -> Decimal {
        var digits: Int32 = 2
        var rounding: Double = 0
        if !CFNumberFormatterGetDecimalInfoForCurrencyCode(currencyCode as CFString, &digits, &rounding) {
            digits = 2
        }
        return amount.multiplying(byPowerOf10: Int16(digits)).decimalValue
    }

    private func makeRecurringOrder() -> ApplePayOrder {
        let label = "\(Self.merchantLabel) Plan"
        let regular = PKRecurringPaymentSummaryItem(label: label, amount: decimal(recurringAmount))
        regular.intervalUnit = recurringInterval.calendarUnit
        regular.intervalCount = recurringInterval.intervalCount
        guard let url = URL(string: managementURL) ?? URL(string: "https://example.com/account/subscription") else {
            return ApplePayOrder(label: label, amount: regular.amount)
        }
        let request = PKRecurringPaymentRequest(
            paymentDescription: "\(label) – \(recurringInterval.rawValue.lowercased())",
            regularBilling: regular,
            managementURL: url
        )
        if freeTrial {
            let trial = PKRecurringPaymentSummaryItem(label: "Free trial", amount: .zero)
            trial.intervalUnit = trialInterval.calendarUnit
            trial.intervalCount = trialInterval.intervalCount
            let trialEnd = Calendar.current.date(byAdding: trialInterval.dateComponent, value: 1, to: Date()) ?? Date()
            trial.endDate = trialEnd
            regular.startDate = trialEnd
            request.trialBilling = trial
        }
        if !billingAgreement.isEmpty { request.billingAgreement = billingAgreement }
        return ApplePayOrder(recurringPaymentRequest: request)
    }

    private func decimal(_ text: String) -> NSDecimalNumber {
        let value = NSDecimalNumber(string: text.trimmingCharacters(in: .whitespaces))
        return value == .notANumber ? .zero : value
    }
}

extension ApplePayDemoSettings {
    /// Signed auth for the card fields before a checkout screen opens, as a merchant app would.
    static func refreshAuth() async -> Bool {
        guard SpreedlyConfigManager.shared.applePayMerchantIdConfigurationError == nil else { return false }
        if case .success = await SpreedlyConfigManager.shared.generateSignature() { return true }
        return false
    }

    /// Runs on tap: the sheet opens only when the Merchant ID is set and the SDK has been set up.
    static func prepareForPresentation() async -> Bool {
        guard SpreedlyConfigManager.shared.applePayMerchantIdConfigurationError == nil else { return false }
        if Spreedly.isInitialized { return true }
        return await refreshAuth()
    }

    /// Fresh signed auth for each Apple Pay payment attempt. It signs that Apple Pay request only, so
    /// the card form keeps its own unused auth.
    static func signedAuth() async throws -> SpreedlyConfig {
        try await SpreedlyConfigManager.shared.fetchSignedAuth()
    }
}

private extension ApplePayBillingInterval {
    var dateComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

#endif
