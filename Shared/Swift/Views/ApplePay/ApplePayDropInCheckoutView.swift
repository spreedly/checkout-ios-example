//
//  ApplePayDropInCheckoutView.swift
//  SpreedlySDKExample
//
//  Apple Pay at the top of the card drop-in: one-time ($1.00) or a subscription. Only the Apple Pay
//  options are shown here; values reset when you go back.
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if canImport(SpreedlyApplePay)

import PassKit
import SpreedlyApplePay
import SwiftUI

struct ApplePayDropInCheckoutView: View {
    let mode: ApplePayDemoMode
    @StateObject private var settings = ApplePayDemoSettings()

    var body: some View {
        List {
            Section(header: Text("Your order")) {
                if mode == .recurring {
                    ApplePayRecurringOptionsCard(settings: settings)
                } else {
                    HStack {
                        Text(ApplePayDemoSettings.merchantLabel)
                        Spacer()
                        Text(settings.displayAmount(settings.oneTimeAmount)).fontWeight(.semibold)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section(header: Text("Checkout sheet"),
                    footer: Text("Pass SpreedlyApplePayWallet in CardFormDropIn(walletButtons:). Apple Pay and the "
                                 + "\"or pay with card\" divider appear above the card fields; both hide when Apple Pay is unavailable. "
                                 + "To try what shoppers see when Wallet has no card, use Customize → Configure & Try.")) {
                ApplePayDropInLauncher(settings: settings, mode: mode, identifier: "applePayDropInOpen")
                ApplePayResultStatus(identifier: "applePayDropInStatus")
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(mode == .recurring ? "Recurring Payment" : "One-time Payment")
        .applePayDemoKeyboardDismissal()
    }
}

#endif
