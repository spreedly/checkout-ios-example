//
//  AppConstants.swift
//  MerchantExample
//
//
//

import Foundation
import SpreedlyCore

/// ISO 4217 currency codes supported by the merchant.
/// Pass `rawValue` to the SDK which always expects a plain `String`.
enum CurrencyCode: String, CaseIterable {
    case usd = "USD"
    case brl = "BRL"
    case mxn = "MXN"
    case ars = "ARS"
    case eur = "EUR"
    case gbp = "GBP"
    case cad = "CAD"
    case clp = "CLP"
    case cop = "COP"
    case pen = "PEN"
}

/// Common constants used across the example app.
enum AppConstants {
    /// Maximum number of payment cards to display
    static let maxCardsToDisplay = 6
    
    /// Conversion factor from dollars to cents
    /// Used when converting product price to API amount
    static let centsPerDollar: Decimal = 100
    
    /// Default currency code for transactions
    static let defaultCurrencyCode = CurrencyCode.usd
    
    /// Payment method type filter for credit cards
    static let creditCardPaymentMethodType = "credit_card"

    // MARK: - Example URLs (for demo only)

    /// Callback URL used in purchase API calls (server-to-server).
    static let exampleCallbackURL = "https://www.google.com/"

    /// Redirect URL for EBANX checkout (app deep link).
    static let ebanxRedirectURL = "merchantExampleApp://merchant-example/ebanx/checkout"

    /// Redirect URL for Stripe APM pending purchase API (where Spreedly redirects after payment).
    static let stripeAPMRedirectURL = "https://merchant-example.test/stripe-apm/redirect"

    /// Return URL for Stripe PaymentSheet (app deep link for redirect-based APMs).
    static let stripeAPMReturnURL = "merchantExampleApp://stripe-redirect"

    /// Redirect URL for offsite (e.g. Sprel) checkout (app deep link).
    static let offsiteRedirectURL = "merchantExampleApp://merchant-example/sprel/checkout"

    /// Redirect URL for Braintree return (app deep link).
    static let braintreeRedirectURL = "merchantExampleApp://merchant-example/braintree/return"

}

