//
//  ApplePayHubView.swift
//  SpreedlySDKExample
//
//  Apple Pay entry point: device status, checkout flows and customization screens.
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if canImport(SpreedlyApplePay)

import SpreedlyApplePay
import SwiftUI

struct ApplePayHubView: View {
    @State private var availability = SpreedlyApplePayWallet.availability()
    @ObservedObject private var testCard = ApplePayTestCardSettings.shared
    /// Hidden while the number is being typed, so a half-entered number doesn't show an error.
    @State private var isEditingTestCard = false

    var body: some View {
        List {
            statusSection

            testCardSection

            Section(header: Text("Checkout")) {
                NavigationLink(destination: ApplePayDropInCheckoutView(mode: .oneTime)) {
                    ApplePayHubRow(
                        title: "One-time Payment",
                        detail: "Pay USD 1.00 from the checkout sheet, with Apple Pay above the card fields."
                    )
                }
                .accessibilityIdentifier("applePayHubOneTimeLink")

                NavigationLink(destination: ApplePayButtonOnlyView()) {
                    ApplePayHubRow(
                        title: "Button Only",
                        detail: "Just the Apple Pay button on your own screen. No card form."
                    )
                }
                .accessibilityIdentifier("applePayHubButtonOnlyLink")

                NavigationLink(destination: ApplePayDropInCheckoutView(mode: .recurring)) {
                    ApplePayHubRow(
                        title: "Recurring Payment",
                        detail: "Subscription sheet with billing interval, free trial and merchant token."
                    )
                }
                .accessibilityIdentifier("applePayHubRecurringLink")
            }

            Section(header: Text("Customize"),
                    footer: Text("Try options here; they reset when you go back and do not change the checkouts above.")) {
                NavigationLink(destination: ApplePayButtonDesignerView()) {
                    ApplePayHubRow(
                        title: "Button & Theme",
                        detail: "Button type, style, corner radius, height, empty-Wallet behavior, divider text."
                    )
                }
                .accessibilityIdentifier("applePayHubButtonLink")

                NavigationLink(destination: ApplePayConfigurationView()) {
                    ApplePayHubRow(
                        title: "Configure & Try",
                        detail: "Networks, card types, contact fields, metadata, charge-first, timeout."
                    )
                }
                .accessibilityIdentifier("applePayHubConfigurationLink")
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Apple Pay")
        .applePayDemoKeyboardDismissal()
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            availability = SpreedlyApplePayWallet.availability()
        }
    }

    private var testCardSection: some View {
        Section(header: Text("Spreedly Test gateway"),
                footer: Text("Apple Pay can't produce test cards, so a Spreedly Test gateway declines every Apple Pay purchase unless a Spreedly test card number is sent with the token. Applies to every Apple Pay demo until the app quits. Turn it off to pay with the real card against a real gateway. Works in Xcode and TestFlight builds only.")) {
            Toggle("Send Spreedly test card", isOn: $testCard.isEnabled)
                .accessibilityHint("Sends a Spreedly test card number with the Apple Pay token in every demo")
                .accessibilityIdentifier("applePayHubTestCardToggle")
            if testCard.isEnabled {
                LabeledTextField(
                    title: "Test card number",
                    text: $testCard.cardNumber,
                    identifier: "applePayHubTestCardNumber",
                    keyboard: .numberPad,
                    onEditingChanged: { isEditingTestCard = $0 }
                )
                if !isEditingTestCard, let problem = testCard.cardNumberProblem {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("applePayHubTestCardProblem")
                }
                Text("4111 1111 1111 1111 succeeds; 4012 8888 8888 1881 is declined. Any number on Spreedly's test card list works.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if testCard.cardNumber != ApplePayTestCardSettings.defaultCardNumber {
                    Button("Reset to \(ApplePayTestCardSettings.defaultCardNumber)") {
                        testCard.cardNumber = ApplePayTestCardSettings.defaultCardNumber
                    }
                    .accessibilityIdentifier("applePayHubTestCardReset")
                }
            }
        }
    }

    private var statusSection: some View {
        Section(header: Text("This device")) {
            HStack {
                Text("Apple Pay")
                Spacer()
                Text(availabilityText).foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            if let error = SpreedlyConfigManager.shared.applePayMerchantIdConfigurationError {
                Text(error).font(.footnote).foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("applePayHubMerchantIdError")
            }
            if availability == .needsSetup {
                SpreedlyApplePaySetUpButton().frame(height: 44)
            }
        }
    }

    private var availabilityText: String {
        switch availability {
        case .ready: return "Ready"
        case .needsSetup: return "No card in Wallet"
        case .unsupported: return "Not supported"
        @unknown default: return "Unknown"
        }
    }
}

struct ApplePayHubRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.footnote).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#endif
