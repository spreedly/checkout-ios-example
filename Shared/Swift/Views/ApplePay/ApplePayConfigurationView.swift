//
//  ApplePayConfigurationView.swift
//  SpreedlySDKExample
//
//  Every ApplePayConfiguration option the SDK supports today, plus the processPayment demo switches.
//  Try them two ways at the top: the Apple Pay button on its own, or inside the card drop-in.
//  Settings live only on this screen and reset when you go back.
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if canImport(SpreedlyApplePay)

import PassKit
import SpreedlyApplePay
import SpreedlyCore
import SwiftUI

struct ApplePayConfigurationView: View {
    @StateObject private var settings = ApplePayDemoSettings()

    var body: some View {
        Form {
            Section(header: Text("Order"),
                    footer: Text("Amount for this one-time payment, in the currency below. Your server should charge the same amount.")) {
                LabeledTextField(
                    title: "Amount (\(settings.currencyCode.uppercased()))",
                    text: $settings.oneTimeAmountText,
                    identifier: "applePayConfigAmount",
                    keyboard: .decimalPad
                )
            }

            Section(header: Text("Merchant"),
                    footer: Text("Merchant ID comes from SpreedlyKeys.xcconfig and must match the app's Apple Pay entitlement.")) {
                HStack {
                    Text("Merchant ID")
                    Spacer()
                    Text(SpreedlyConfigManager.shared.applePayMerchantId.isEmpty
                         ? "Not set" : SpreedlyConfigManager.shared.applePayMerchantId)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityElement(children: .combine)
                LabeledTextField(title: "Country (ISO 3166)", text: $settings.countryCode, identifier: "applePayConfigCountry")
                LabeledTextField(title: "Currency (ISO 4217)", text: $settings.currencyCode, identifier: "applePayConfigCurrency")
            }

            Section(header: Text("Card networks"),
                    footer: Text("Only the selected networks can pay. Default: every network Spreedly accepts; turn off the ones your gateway doesn't support. At least one is required.")) {
                if settings.networks.isEmpty {
                    Text("No network selected. Apple Pay won't open: the checkout fails with \"needs at least one supported network\".")
                        .font(.footnote)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("applePayConfigNoNetworkWarning")
                }
                ForEach(ApplePayDemoCatalog.networks) { network in
                    Toggle(network.label, isOn: membership(of: network.value, in: $settings.networks))
                        .accessibilityIdentifier("applePayConfigNetwork-\(network.value.rawValue)")
                }
            }

            Section(header: Text("Card types"),
                    footer: Text("Other card types are greyed out in the Apple Pay sheet. The SDK always keeps .threeDSecure (Apple Pay's payment format, not a 3-D Secure challenge).")) {
                Picker("Accept", selection: $settings.cardTypes) {
                    ForEach(ApplePayCardTypeRestriction.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityIdentifier("applePayConfigCardTypes")
            }

            Section(header: Text("Billing contact"),
                    footer: Text("For billing, Apple only collects the postal address and the name with it. "
                                 + "Ask for phone or email under Shipping contact fields.")) {
                Toggle("Postal address (includes name)", isOn: billingAddressBinding)
                    .accessibilityIdentifier("applePayConfigBilling-PostalAddress")
                Toggle("Prefill a saved billing address", isOn: $settings.prefillBillingContact)
                    .disabled(!settings.canPrefillBilling)
                    .accessibilityIdentifier("applePayConfigPrefillBilling")
                optionDetail("Passes a synthetic saved address as billingContact; the sheet shows it as the default. Turn on Postal address above to use it: Apple only shows a saved billing address when the sheet asks for one.")
            }

            Section(header: Text("Shipping contact fields")) {
                ForEach(ApplePayDemoCatalog.contactFields) { field in
                    Toggle(field.label, isOn: membership(of: field.value, in: $settings.shippingContactFields))
                        .accessibilityIdentifier("applePayConfigShipping-\(field.label)")
                }
                Toggle("Prefill a saved shipping contact", isOn: $settings.prefillShippingContact)
                    .disabled(!settings.canPrefillShipping)
                    .accessibilityIdentifier("applePayConfigPrefillShipping")
                optionDetail("Passes a synthetic saved contact as shippingContact. Turn on at least one shipping field above to use it: Apple only shows the saved details the sheet asks for.")
                Picker("Shipping type", selection: $settings.shippingType) {
                    Text("Shipping").tag(PKShippingType.shipping)
                    Text("Delivery").tag(PKShippingType.delivery)
                    Text("Store pickup").tag(PKShippingType.storePickup)
                    Text("Service pickup").tag(PKShippingType.servicePickup)
                }
                .accessibilityIdentifier("applePayConfigShippingType")
                optionDetail("Changes only how the sheet labels the address, e.g. \"Delivery Address\". Turn on Postal address to see it.")
            }

            Section(header: Text("Card-issuing countries"),
                    footer: Text("Only cards issued in the selected countries can pay. None selected means any country (no restriction).")) {
                NavigationLink(destination: countryPicker) {
                    HStack {
                        Text("Countries")
                        Spacer()
                        Text(countriesSummary).foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier("applePayConfigSupportedCountries")
            }

            Section(header: Text("Payment method metadata"),
                    footer: Text("Stored on the Spreedly payment method, not shown on the sheet. The ID appears in the status above after payment.")) {
                Toggle("Attach demo order ID", isOn: $settings.includeMetadata)
                    .accessibilityHint("Stores a synthetic order ID on the Spreedly payment method")
                    .accessibilityIdentifier("applePayConfigMetadata")
            }

            Section(header: Text("When Wallet has no card"),
                    footer: Text("Pay button: Apple's sheet helps the shopper add a card. Hide: no Apple Pay button until a card is added.")) {
                Picker("Empty Wallet", selection: $settings.emptyWalletBehavior) {
                    Text("Pay button").tag(ApplePayEmptyWalletBehavior.showPayButton)
                    Text("Hide").tag(ApplePayEmptyWalletBehavior.hide)
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityIdentifier("applePayConfigEmptyWalletPicker")
            }

            Section(header: Text("Server timing"),
                    footer: Text("After Face ID, Apple's sheet waits while the demo backend charges the card, and shows success only if the charge works. Apple closes the sheet after about 30 s; the SDK keeps waiting for the backend's answer.")) {
                Toggle("Simulate slow server (\(ApplePayDemoSettings.slowServerDelaySeconds) s)",
                       isOn: $settings.simulateSlowServer)
                    .accessibilityIdentifier("applePayConfigSlowServerToggle")
                optionDetail("Makes the demo charge take 40 s, longer than Apple's ~30 s. You'll see the sheet close, then \"Your payment is still being processed. Please don't pay again.\", then the real result.")
                Toggle("Decline: address not deliverable", isOn: $settings.simulateUndeliverableAddress)
                    .accessibilityIdentifier("applePayConfigUndeliverableToggle")
                optionDetail("The demo backend answers .declined(message:errors:) with a shipping-address error instead of charging. Turn on the shipping Postal address: the sheet marks the address. Every attempt is declined while this is on; turn it off to pay.")
                VStack(alignment: .leading) {
                    Text("processPaymentTimeout: \(Int(settings.processPaymentTimeout)) s")
                    Slider(value: $settings.processPaymentTimeout, in: 30...300, step: 10)
                        .accessibilityIdentifier("applePayConfigTimeoutSlider")
                    optionDetail("How long the SDK waits for your server's answer (at least 30 s). No answer by then gives \"status unknown\": the charge may still go through, so check the order on your server before the shopper pays again.\n\nTry it:\n• Slow server off: normal success or failure on Apple's sheet.\n• Slow server on, timeout above 40 s (e.g. 120): the sheet closes, then \"Your payment is still being processed. Please don't pay again.\", then success.\n• Slow server on, timeout below 40 s (e.g. 30): \"status unknown\" failure, while the charge may still go through.")
                }
            }

            Section(header: Text("Try this configuration"),
                    footer: Text("The amount and settings above: networks, card types, contact fields, metadata and "
                                 + "server timing. The same ApplePayConfiguration goes to the button on your screen "
                                 + "and to SpreedlyApplePayWallet in the checkout sheet.")) {
                SpreedlyApplePayButton(
                    configuration: settings.makeConfiguration(mode: .oneTime),
                    order: settings.makeOrder(mode: .oneTime),
                    prepareForPresentation: { await ApplePayDemoSettings.prepareForPresentation() },
                    signedAuth: { try await ApplePayDemoSettings.signedAuth() },
                    processPayment: { authorization in try await settings.charge(authorization, mode: .oneTime) }
                )
                .frame(height: CGFloat(settings.buttonHeight))
                .id(configurationKey)
                .accessibilityIdentifier("applePayConfigTryButton")

                ApplePayDropInLauncher(settings: settings, mode: .oneTime, identifier: "applePayConfigOpenDropIn")
                ApplePayResultStatus(
                    identifier: "applePayConfigStatus",
                    successDetail: { [settings] in settings.includeMetadata ? "order ID \(settings.demoOrderId)" : nil }
                )
            }
        }
        .navigationTitle("Configure & Try")
        .applePayDemoKeyboardDismissal()
    }

    /// The button reads its configuration once, so rebuild it whenever a setting changes.
    private var configurationKey: String {
        let networks = settings.networks.map(\.rawValue).sorted().joined(separator: ",")
        let billing = settings.billingContactFields.map(\.rawValue).sorted().joined(separator: ",")
        let shipping = settings.shippingContactFields.map(\.rawValue).sorted().joined(separator: ",")
        return [settings.countryCode, settings.currencyCode, networks, settings.cardTypes.rawValue, billing, shipping,
                "\(settings.includeMetadata)", countriesSummary, "\(settings.processPaymentTimeout)",
                settings.oneTimeAmountText, "\(settings.emptyWalletBehavior.rawValue)",
                "\(settings.prefillBillingContact)", "\(settings.prefillShippingContact)",
                "\(settings.shippingType.rawValue)"]
            .joined(separator: "|")
    }

    private func optionDetail(_ text: String) -> some View {
        Text(text).font(.caption).foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var countriesSummary: String {
        settings.supportedCountries.isEmpty ? "Any" : settings.supportedCountries.sorted().joined(separator: ", ")
    }

    private var countryPicker: some View {
        List {
            ForEach(ApplePayDemoCatalog.countries) { country in
                Button {
                    if settings.supportedCountries.contains(country.value) {
                        settings.supportedCountries.remove(country.value)
                    } else {
                        settings.supportedCountries.insert(country.value)
                    }
                } label: {
                    HStack {
                        Text(country.label).foregroundColor(.primary)
                        Spacer()
                        if settings.supportedCountries.contains(country.value) {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                }
                .accessibilityAddTraits(settings.supportedCountries.contains(country.value) ? .isSelected : [])
                .accessibilityIdentifier("applePayConfigCountry-\(country.value)")
            }
        }
        .navigationTitle("Card-issuing countries")
    }

    private var billingAddressBinding: Binding<Bool> {
        Binding(
            get: { settings.billingContactFields.contains(.postalAddress) },
            set: { settings.billingContactFields = $0 ? [.postalAddress, .name] : [] }
        )
    }

    private func membership<Value: Hashable>(of value: Value, in set: Binding<Set<Value>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(value) },
            set: { isOn in
                if isOn { set.wrappedValue.insert(value) } else { set.wrappedValue.remove(value) }
            }
        )
    }
}

#endif
