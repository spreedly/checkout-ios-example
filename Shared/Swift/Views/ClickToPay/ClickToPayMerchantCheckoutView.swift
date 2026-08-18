//
//  ClickToPayMerchantCheckoutView.swift
//  SpreedlySDKExample
//

import SwiftUI
import SpreedlyCore
import SpreedlyUI
import SpreedlyClickToPay
import SpreedlySecurity

/// Merchant-reference checkout — product + shopper email; card entry stays in the Click to Pay sheet.
struct ClickToPayMerchantCheckoutView: View {
    @Environment(\.spreedlyTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = ClickToPayPaymentViewModel()

    @State private var useCustomTheme = false
    @State private var lightTheme: SpreedlyTheme?
    @State private var darkTheme: SpreedlyTheme?
    @State private var selectedTheme: ThemeOption = .default

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: theme.spacing.lg) {
                    headerSection
                    stageIndicator
                    statusSection
                    ProductSelectionView(products: viewModel.products, selectedProduct: Binding(
                        get: { viewModel.selectedProduct },
                        set: { if let product = $0 { viewModel.selectProduct(product) } }
                    ))
                    themeConfigurationSection
                    customerSection
                    billingPrefillSection
                    cardCollectionNote
                    paySection
                    outcomeSection
                }
                .padding()
            }
            deviceDetectorHost
        }
        .navigationTitle("Click to Pay")
        .spreedlyAdaptiveGlobalTheme()
        .onAppear {
            syncGlobalTheme()
            viewModel.onMerchantScreenDisplayed()
        }
    }

    @ViewBuilder
    private var deviceDetectorHost: some View {
        if viewModel.deviceDetectorKey >= 0, viewModel.stage == .idle {
            ClickToPaySavedCardsDetector(
                config: viewModel.deviceDetectorConfig,
                detectorKey: viewModel.deviceDetectorKey,
                onResult: viewModel.onDeviceDetectionResult,
                onControllerReady: viewModel.onDetectorControllerReady
            )
            .id(viewModel.deviceDetectorKey)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

    private var themeConfigurationSection: some View {
        MerchantThemeConfigurationCard(
            useCustomTheme: $useCustomTheme,
            lightTheme: $lightTheme,
            darkTheme: $darkTheme,
            selectedTheme: $selectedTheme,
            titleAccessibilityIdentifier: "c2p_merchant_theme_title",
            toggleAccessibilityIdentifier: "c2p_merchant_use_custom_theme_toggle",
            onThemeChanged: { syncGlobalTheme() }
        )
    }

    private func syncGlobalTheme() {
        MerchantThemePresets.applyGlobalTheme(
            useCustomTheme: useCustomTheme,
            lightTheme: lightTheme,
            darkTheme: darkTheme
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("Checkout with Click to Pay")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
            Text("Select a product, contact, and billing address. Card PAN/CVV are collected inside the Click to Pay sheet only.")
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stageIndicator: some View {
        let steps = ["Idle", "Checkout", "Tokenize"]
        let currentIndex: Int = {
            switch viewModel.stage {
            case .idle: return 0
            case .checkout: return 1
            case .tokenizing: return 2
            }
        }()
        return HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(index <= currentIndex ? theme.colors.primary : theme.colors.disabled)
                            .frame(width: 24, height: 24)
                        if index < currentIndex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    Text(steps[index])
                        .font(theme.typography.captionFont)
                        .foregroundColor(index <= currentIndex ? theme.colors.primary : theme.colors.textSecondary)
                }
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentIndex ? theme.colors.primary : theme.colors.disabled)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                }
            }
        }
        .padding(theme.spacing.md)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.borderRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: theme.borderRadius.xl).stroke(theme.colors.border, lineWidth: 1))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SDK status")
                .font(theme.typography.captionFont)
                .foregroundColor(theme.colors.textSecondary)
            Text("SDK phase: \(viewModel.flowPhase.rawValue)")
                .font(theme.typography.captionFont)
                .foregroundColor(theme.colors.textSecondary)
            Text(viewModel.flowMessage)
                .font(theme.typography.captionFont)
                .foregroundColor(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(theme.colors.surface)
        .cornerRadius(theme.borderRadius.md)
    }

    private var customerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Contact information")
                .font(theme.typography.subtitleFont)

            Text(viewModel.contactHint)
                .font(theme.typography.captionFont)
                .foregroundColor(theme.colors.textSecondary)

            switch viewModel.deviceRecognition {
            case .checking:
                ClickToPayRecognizedDevicePanel(
                    title: "Checking this device",
                    bodyText: "Looking for saved Click to Pay cards on this device…",
                    showProgress: true
                )
            case .recognized:
                ClickToPayRecognizedDevicePanel(
                    title: "Welcome back",
                    bodyText: viewModel.recognizedCardLabels.isEmpty
                        ? "This device has saved Click to Pay cards."
                        : "Use your saved cards to check out faster.",
                    cardLabels: viewModel.recognizedCardLabels,
                    linkText: "Not you? Use a different email",
                    onLinkTap: viewModel.useDifferentEmail,
                    linkEnabled: viewModel.isPayEnabled
                )
            case .notRecognized, .usingDifferentEmail:
                EmptyView()
            }

            if viewModel.showContactIdentityFields {
                TextField("Email address", text: Binding(
                    get: { viewModel.email },
                    set: { viewModel.updateEmail($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .accessibilityIdentifier("c2p_merchant_email")

                if viewModel.contactValidationAttempted, let emailError = viewModel.emailError {
                    Text(emailError)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                HStack(spacing: theme.spacing.sm) {
                    TextField("Country code", text: viewModel.phoneCountryCodeBinding)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)
                        .frame(maxWidth: 100)
                        .accessibilityIdentifier("c2p_merchant_phone_country")
                    TextField("Mobile number", text: viewModel.phoneNumberBinding)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)
                        .accessibilityIdentifier("c2p_merchant_phone")
                }

                if viewModel.contactValidationAttempted, let phoneError = viewModel.phoneError {
                    Text(phoneError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var billingPrefillSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Billing / shipping address")
                .font(theme.typography.subtitleFont)

            Text("First and last name are required for tokenize and prefilled as cardholder name in the Click to Pay sheet. Other address fields are optional.")
                .font(theme.typography.captionFont)
                .foregroundColor(theme.colors.textSecondary)

            HStack(spacing: theme.spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("First name", text: viewModel.firstNameBinding)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("c2p_merchant_first_name")
                    if viewModel.contactValidationAttempted, let firstNameError = viewModel.firstNameError {
                        Text(firstNameError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Last name", text: viewModel.lastNameBinding)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("c2p_merchant_last_name")
                    if viewModel.contactValidationAttempted, let lastNameError = viewModel.lastNameError {
                        Text(lastNameError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            TextField("Street address 1", text: viewModel.binding(for: \.addressLine1))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("c2p_merchant_address1")

            TextField("Street address 2 (optional)", text: viewModel.binding(for: \.addressLine2))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("c2p_merchant_address2")

            TextField("Country (ISO)", text: viewModel.binding(for: \.country))
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
                .accessibilityIdentifier("c2p_merchant_country")

            TextField("City", text: viewModel.binding(for: \.city))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("c2p_merchant_city")

            HStack(spacing: theme.spacing.sm) {
                TextField("State", text: viewModel.binding(for: \.state))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("c2p_merchant_state")
                TextField("ZIP", text: viewModel.binding(for: \.zip))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .accessibilityIdentifier("c2p_merchant_zip")
            }

            Toggle("Copy billing to shipping on tokenize", isOn: viewModel.binding(for: \.copyBillingToShipping))
                .font(theme.typography.bodyFont)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardCollectionNote: some View {
        Text("Card details are collected inside Click to Pay checkout (not on this screen).")
            .font(theme.typography.captionFont)
            .foregroundColor(theme.colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paySection: some View {
        let buttonConfig: ClickToPayButtonConfig = {
            let config = ClickToPayButtonConfig(cardBrands: [.mastercard, .visa, .amex, .discover])
            config.isEnabled = viewModel.isPayEnabled
            config.isDark = colorScheme == .dark
            config.buttonHeight = 10
            config.buttonWidth = 300
            return config
        }()

        return SpreedlyClickToPayButton(
            checkoutConfig: viewModel.merchantCheckoutConfig,
            buttonConfig: buttonConfig,
            prepareForPresentation: { await viewModel.prepareForCheckout() }
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("c2p_merchant_pay_button")
        .onAppear { syncGlobalTheme() }
    }

    @ViewBuilder
    private var outcomeSection: some View {
        if let successMessage = viewModel.successMessage {
            MessageView.success(title: "Payment successful", message: successMessage)
        }
        if let errorMessage = viewModel.errorMessage {
            MessageView.error(title: "Payment failed", message: errorMessage)
        }
    }
}
