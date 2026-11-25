//
//  ApplePayRecurringOptionsCard.swift
//  SpreedlySDKExample
//
//  Subscription controls for the recurring Apple Pay checkout.
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if canImport(SpreedlyApplePay)

import SwiftUI

struct ApplePayRecurringOptionsCard: View {
    @ObservedObject var settings: ApplePayDemoSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subscription")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Picker("Billing", selection: $settings.recurringInterval) {
                ForEach(ApplePayBillingInterval.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accessibilityIdentifier("applePayRecurringIntervalPicker")

            LabeledTextField(
                title: "Amount per \(settings.recurringInterval.shortLabel)",
                text: $settings.recurringAmount,
                identifier: "applePayRecurringAmountField",
                keyboard: .decimalPad
            )

            Toggle("Free trial first", isOn: $settings.freeTrial)
                .accessibilityIdentifier("applePayRecurringTrialToggle")
            if settings.freeTrial {
                Picker("Trial length", selection: $settings.trialInterval) {
                    ForEach(ApplePayBillingInterval.allCases) { Text("1 \($0.shortLabel)").tag($0) }
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityIdentifier("applePayRecurringTrialPicker")
            }

            Divider()

            optionHeader("Subscription terms",
                         detail: "Shown on Apple's subscription sheet before the shopper pays. Optional.")
            TextField("e.g. You'll be charged USD 9.99 every month until you cancel.",
                      text: $settings.billingAgreement, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Subscription terms")
                .accessibilityIdentifier("applePayRecurringAgreementField")
            HStack(spacing: 16) {
                Button("Use suggested terms") { settings.billingAgreement = settings.suggestedBillingTerms }
                    .accessibilityHint("Fills in terms from the amount, interval and trial above")
                    .accessibilityIdentifier("applePayRecurringAgreementSuggest")
                if !settings.billingAgreement.isEmpty {
                    Button("Clear", role: .destructive) { settings.billingAgreement = "" }
                        .accessibilityIdentifier("applePayRecurringAgreementClear")
                }
            }
            .font(.footnote)
            .buttonStyle(.borderless)

            optionHeader("Manage subscription link",
                         detail: "Required. A page on your site where the shopper manages the subscription: view it, change the plan or payment method, or cancel. Apple links to it from the sheet and from Wallet.")
            TextField("https://example.com/account/subscription", text: $settings.managementURL)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .accessibilityLabel("Manage subscription link")
                .accessibilityIdentifier("applePayRecurringManagementURLField")

            Text("Renewals need a merchant token. The result screen shows which token Apple issued; "
                 + "Apple's sandbox may only issue device tokens.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
        .accessibilityIdentifier("basicCheckoutApplePayRecurringCard")
    }

    private func optionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#endif
