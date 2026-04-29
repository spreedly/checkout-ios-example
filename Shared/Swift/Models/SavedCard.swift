//
//  SavedCard.swift
//  MerchantExample
//
//
//

import Foundation

// MARK: - Saved Card Model
// Example model for SwiftUI demo. Similar SavedCard class exists in Objective-C example.
// In production, fetch saved payment methods from your backend or local storage.
// Used by both CVVRecachingView and ThreeDSPaymentFlowView
struct SavedCard: Identifiable {
    let id: String
    let paymentMethodToken: String
    let lastFourDigits: String
    let cardType: String
    let cardBrand: String?
    let expiryMonth: String?
    let expiryYear: String?

    var displayName: String {
        return "\(cardType)\n •••• \(lastFourDigits)"
    }
}
