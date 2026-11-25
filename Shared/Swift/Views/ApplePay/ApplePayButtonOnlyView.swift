//
//  ApplePayButtonOnlyView.swift
//  SpreedlySDKExample
//
//  The Apple Pay button on its own, inside your own screen: no drop-in, no card fields.
//  Pick one-time or recurring and type an amount; both reset when you go back.
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if canImport(SpreedlyApplePay)

import SpreedlyApplePay
import SwiftUI

struct ApplePayButtonOnlyView: View {
    @StateObject private var settings = ApplePayDemoSettings()
    @State private var mode: ApplePayDemoMode = .oneTime

    var body: some View {
        List {
            Section(header: Text("Payment")) {
                Picker("Type", selection: $mode) {
                    Text("One-time").tag(ApplePayDemoMode.oneTime)
                    Text("Recurring").tag(ApplePayDemoMode.recurring)
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityIdentifier("applePayButtonOnlyMode")

                if mode == .recurring {
                    Picker("Every", selection: $settings.recurringInterval) {
                        ForEach(ApplePayBillingInterval.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("applePayButtonOnlyInterval")
                }

                LabeledTextField(
                    title: mode == .recurring ? "Amount per \(settings.recurringInterval.shortLabel)" : "Amount",
                    text: mode == .recurring ? $settings.recurringAmount : $settings.oneTimeAmountText,
                    identifier: "applePayButtonOnlyAmount",
                    keyboard: .decimalPad
                )
            }

            Section(footer: Text("Place SpreedlyApplePayButton anywhere in your layout. "
                                 + "Results arrive on subscribeToPaymentResults.")) {
                SpreedlyApplePayButton(
                    configuration: settings.makeConfiguration(mode: mode),
                    order: settings.makeOrder(mode: mode),
                    prepareForPresentation: { await ApplePayDemoSettings.prepareForPresentation() },
                    signedAuth: { try await ApplePayDemoSettings.signedAuth() },
                    processPayment: settings.processPayment(mode: mode)
                )
                .frame(height: CGFloat(settings.buttonHeight))
                .id(mode == .recurring ? "recurring-\(settings.recurringInterval.rawValue)" : "oneTime")
                .accessibilityIdentifier("applePayButtonOnlyButton")

                ApplePayResultStatus(identifier: "applePayButtonOnlyStatus")
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Button Only")
        .applePayDemoKeyboardDismissal()
    }
}

#endif
