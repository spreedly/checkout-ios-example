//
//  ApplePayButtonDesignerView.swift
//  SpreedlySDKExample
//
//  Live Apple Pay button preview. Apple only allows its official button, so customization is limited
//  to type, style, corner radius and size. Changes stay on this screen and reset when you go back.
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if canImport(SpreedlyApplePay)

import PassKit
import SpreedlyApplePay
import SwiftUI

struct ApplePayButtonDesignerView: View {
    @StateObject private var settings = ApplePayDemoSettings()

    var body: some View {
        Form {
            Section(header: Text("Preview"),
                    footer: Text("The SDK hides the button when Apple Pay is unavailable on this device.")) {
                SpreedlyApplePayButton(
                    configuration: settings.makeConfiguration(mode: .oneTime),
                    order: settings.makeOrder(mode: .oneTime),
                    prepareForPresentation: { await ApplePayDemoSettings.prepareForPresentation() },
                    signedAuth: { try await ApplePayDemoSettings.signedAuth() },
                    processPayment: settings.processPayment(mode: .oneTime)
                )
                .frame(height: CGFloat(settings.buttonHeight))
                .id(previewKey)
                .accessibilityIdentifier("applePayDesignerPreview")
            }

            Section(header: Text("Button")) {
                Picker("Type", selection: $settings.buttonType) {
                    ForEach(ApplePayDemoCatalog.buttonTypes) { Text($0.label).tag($0.value) }
                }
                .accessibilityIdentifier("applePayDesignerTypePicker")

                Picker("Style", selection: $settings.buttonStyle) {
                    ForEach(ApplePayDemoCatalog.buttonStyles) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityIdentifier("applePayDesignerStylePicker")

                VStack(alignment: .leading) {
                    Text("Corner radius: \(Int(settings.cornerRadius)) pt")
                    Slider(value: $settings.cornerRadius, in: 0...24, step: 1)
                        .accessibilityIdentifier("applePayDesignerRadiusSlider")
                }
                VStack(alignment: .leading) {
                    Text("Height: \(Int(settings.buttonHeight)) pt")
                    Slider(value: $settings.buttonHeight, in: 44...64, step: 1)   // 44 pt tap-target minimum
                        .accessibilityIdentifier("applePayDesignerHeightSlider")
                }
            }

            Section(header: Text("Checkout sheet"),
                    footer: Text("Apple Pay sits above the card fields with this divider text. Empty uses the localized default.")) {
                TextField("or pay with card", text: $settings.dividerText)
                    .accessibilityIdentifier("applePayDesignerDividerField")
                VStack(spacing: 10) {
                    PassKitButtonPreview(
                        type: settings.buttonType,
                        style: settings.buttonStyle,
                        cornerRadius: CGFloat(settings.cornerRadius)
                    )
                    .frame(height: CGFloat(settings.buttonHeight))
                    .id("dropin-\(previewKey)")
                    HStack {
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                        Text(settings.dividerText.isEmpty ? "or pay with card" : settings.dividerText)
                            .font(.caption).foregroundColor(.secondary).fixedSize()
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                    }
                    ForEach(["Card number", "MM/YY   ·   CVC"], id: \.self) { placeholder in
                        Text(placeholder)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                            .padding(.horizontal, 10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    }
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Checkout sheet preview")
                ApplePayDropInLauncher(settings: settings, mode: .oneTime, identifier: "applePayDesignerOpenDropIn")
            }

            Section(header: Text("Set Up Apple Pay button"),
                    footer: Text("Preview only. In checkout, SpreedlyApplePaySetUpButton shows this when the device "
                                 + "supports Apple Pay but Wallet has no eligible card; tapping it opens Wallet setup.")) {
                PassKitButtonPreview(type: .setUp, style: settings.buttonStyle, cornerRadius: CGFloat(settings.cornerRadius))
                    .frame(height: CGFloat(settings.buttonHeight))
                    .id("setup-\(previewKey)")
                    .accessibilityIdentifier("applePayDesignerSetUpPreview")
            }
        }
        .navigationTitle("Button & Theme")
        .applePayDemoKeyboardDismissal()
    }

    /// Rebuilds the PassKit views whenever an option changes (PassKit buttons are immutable).
    private var previewKey: String {
        "\(settings.buttonType.rawValue)-\(settings.buttonStyle.rawValue)-\(Int(settings.cornerRadius))-\(settings.emptyWalletBehavior.rawValue)"
    }
}

/// Plain PassKit button for previews; not wired to a checkout.
private struct PassKitButtonPreview: UIViewRepresentable {
    let type: PKPaymentButtonType
    let style: PKPaymentButtonStyle
    let cornerRadius: CGFloat

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
        button.cornerRadius = cornerRadius
        button.isUserInteractionEnabled = false
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
}

#endif
