//
//  ApplePayTestCardSettings.swift
//  SpreedlySDKExample
//
//  One test-card switch for every Apple Pay demo, kept in memory for this launch only.
//  Not saved to disk: a card number (even a test one) has no place in UserDefaults, and the public
//  sample shouldn't show that pattern.
//
//  The demo backend charges on a Spreedly Test gateway, which declines every Apple Pay card unless
//  a Spreedly test card number is sent with the token (Apple Pay can't produce test cards). Turn it
//  off to run a real payment against a real gateway.
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if canImport(SpreedlyApplePay)

import Combine
import Foundation
import SpreedlyUI

final class ApplePayTestCardSettings: ObservableObject {
    static let shared = ApplePayTestCardSettings()

    /// Spreedly's Visa test card that succeeds on the Test gateway.
    static let defaultCardNumber = "4111 1111 1111 1111"

    /// On by default, so every launch works against the demo backend's Test gateway.
    @Published var isEnabled = true

    @Published var cardNumber = ApplePayTestCardSettings.defaultCardNumber

    private init() {}

    /// Shown under the field when the number isn't a valid card number, or `nil`. Same check as the card
    /// form; the SDK checks again when Apple Pay is tapped and fails the checkout before the sheet opens.
    var cardNumberProblem: String? {
        let digits = cardNumber.filter { !$0.isWhitespace }
        let isValid = (12...19).contains(digits.count)
            && digits.allSatisfy { $0.isASCII && $0.isNumber }
            && CardTypeDetector.validateCard(digits).isValid
        return isValid ? nil : "Not a valid card number. Use a Spreedly test card such as \(Self.defaultCardNumber)."
    }

    /// The number to put on `ApplePayConfiguration.testCardNumber`, or `nil` when the switch is off.
    var numberForCheckout: String? { isEnabled ? cardNumber : nil }

    /// One line for the debug log, so test runs can be told apart from real ones.
    var summary: String {
        isEnabled ? "on, sending \(cardNumber)" : "off, real card details are used"
    }
}

#endif
