//
//  StripeAPMPaymentFlowView.swift
//  SpreedlySDKExample
//
//  Requires the app target to link both SpreedlyStripeAPM and StripePaymentSheet (stripe-ios-spm).
//  StripePaymentSheet must be added so its resource bundle (Stripe_StripePaymentSheet) is embedded;
//  otherwise presenting PaymentSheet will crash with "unable to find bundle named Stripe_StripePaymentSheet".
//

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI
import SpreedlyStripeAPM

struct StripeAPMPaymentFlowView: View {
    @Environment(\.spreedlyTheme) private var environmentTheme
    @State private var selectedProduct: Product?
    @State private var selectedAPMTypes: Set<String> = ["ideal"]
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingMessage: String?
    @State private var paymentResultCancellable: AnyCancellable?
    @State private var stage: StripeAPMStage = .idle

    private let products: [Product] = [
        Product(id: "prod_1", name: "Wireless Earbuds", price: 99, description: "Premium wireless earbuds with active noise cancellation", iconName: "airpods"),
        Product(id: "prod_2", name: "Smart Watch", price: 0.44, description: "Feature-rich smartwatch with health tracking", iconName: "applewatch"),
        Product(id: "prod_3", name: "Tablet", price: 699, description: "High-performance tablet with stunning display", iconName: "ipad"),
        Product(id: "prod_4", name: "Laptop", price: 400, description: "Powerful laptop for work and creativity", iconName: "laptopcomputer"),
        Product(id: "prod_5", name: "Smart Speaker", price: 299, description: "Voice-controlled smart speaker with premium sound", iconName: "speaker.wave.3"),
        Product(id: "prod_6", name: "Gaming Console", price: 399, description: "Next-generation gaming console", iconName: "gamecontroller")
    ]

    private let availableAPMTypes: [(id: String, name: String, icon: String)] = [
        ("ideal", "iDEAL", "building.columns"),
        ("bancontact", "Bancontact", "creditcard"),
        ("eps", "EPS", "building.columns"),
        ("p24", "Przelewy24 (P24)", "creditcard"),
        ("sepa_debit", "SEPA Debit", "building.columns")
    ]

    private var theme: SpreedlyTheme {
        environmentTheme
    }

    private var isStartButtonEnabled: Bool {
        selectedProduct != nil && !selectedAPMTypes.isEmpty && !isLoading
    }

    /// Primary selected APM display name for messages: "iDEAL" | "Bancontact" | "EPS" | "Przelewy24 (P24)" | "SEPA Debit" (per PAYMENT_MESSAGES_CROSS_PLATFORM).
    private var stripeAPMMethodDisplayName: String {
        availableAPMTypes.first { selectedAPMTypes.contains($0.id) }?.name ?? "iDEAL"
    }

    private var buttonTitle: String {
        guard let product = selectedProduct else {
            return "Select a product"
        }
        switch stage {
        case .idle:
            return String(format: "Pay EUR %.2f", NSDecimalNumber(decimal: product.price).doubleValue)
        case .creatingPendingPurchase:
            return "Creating pending purchase..."
        case .checkout:
            return "Completing checkout..."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg) {
                headerSection

                stageIndicator

                ProductSelectionView(
                    products: products,
                    selectedProduct: $selectedProduct,
                    showSelectionIcon: false
                )

                apmTypeSelectionSection

                Button(action: startStripeAPMFlow) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, theme.spacing.sm)
                        }
                        Text(buttonTitle)
                            .font(theme.typography.buttonFont)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacing.md)
                    .background(isStartButtonEnabled ? theme.colors.primary : theme.colors.primary.opacity(0.6))
                    .cornerRadius(theme.borderRadius.sm)
                }
                .disabled(!isStartButtonEnabled)
                .accessibilityIdentifier(AccessibilityIdentifiers.StripeAPMPayment.startButton)
                .accessibilityLabel(AccessibilityLabels.StripeAPMPayment.startButton)
                .accessibilityHint(AccessibilityHints.StripeAPMPayment.startButton)
                .accessibilityAddTraits(.isButton)

                if let success = successMessage {
                    MessageView.success(
                        message: success,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.StripeAPMPayment.successIcon,
                        iconAccessibilityLabel: AccessibilityLabels.StripeAPMPayment.successIcon,
                        iconAccessibilityHint: AccessibilityHints.StripeAPMPayment.successIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.StripeAPMPayment.successTitle,
                        titleAccessibilityLabel: AccessibilityLabels.StripeAPMPayment.successTitle,
                        titleAccessibilityHint: AccessibilityHints.StripeAPMPayment.successTitle
                    )
                }

                if let pending = pendingMessage {
                    MessageView.pending(
                        message: pending,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.StripeAPMPayment.pendingIcon,
                        iconAccessibilityLabel: AccessibilityLabels.StripeAPMPayment.pendingIcon,
                        iconAccessibilityHint: AccessibilityHints.StripeAPMPayment.pendingIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.StripeAPMPayment.pendingTitle,
                        titleAccessibilityLabel: AccessibilityLabels.StripeAPMPayment.pendingTitle,
                        titleAccessibilityHint: AccessibilityHints.StripeAPMPayment.pendingTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.StripeAPMPayment.pendingMessage,
                        messageAccessibilityHint: AccessibilityHints.StripeAPMPayment.pendingMessage
                    )
                }

                if let error = errorMessage {
                    MessageView.error(
                        message: error,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.StripeAPMPayment.errorIcon,
                        iconAccessibilityLabel: AccessibilityLabels.StripeAPMPayment.errorIcon,
                        iconAccessibilityHint: AccessibilityHints.StripeAPMPayment.errorIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.StripeAPMPayment.errorTitle,
                        titleAccessibilityLabel: AccessibilityLabels.StripeAPMPayment.errorTitle,
                        titleAccessibilityHint: AccessibilityHints.StripeAPMPayment.errorTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.StripeAPMPayment.errorMessage,
                        messageAccessibilityHint: AccessibilityHints.StripeAPMPayment.errorMessage
                    )
                }
            }
            .padding(theme.spacing.md)
        }
        .navigationTitle("Stripe APM")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupSubscriptions()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("Stripe APM Payment Flow")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.StripeAPMPayment.title)
                .accessibilityLabel(AccessibilityLabels.StripeAPMPayment.title)
                .accessibilityHint(AccessibilityHints.StripeAPMPayment.title)
                .accessibilityAddTraits(.isHeader)
            Text("Create a pending purchase via Spreedly, then complete checkout using Stripe PaymentSheet.")
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.textSecondary)
                .accessibilityIdentifier(AccessibilityIdentifiers.StripeAPMPayment.description)
                .accessibilityLabel(AccessibilityLabels.StripeAPMPayment.description)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.borderRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: theme.borderRadius.xl)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .customShadow(theme.shadows.small)
    }

    // MARK: - Stage Indicator

    private var currentStepIndex: Int {
        switch stage {
        case .idle: return 0
        case .creatingPendingPurchase: return 1
        case .checkout: return 2
        }
    }

    private var stageIndicator: some View {
        let steps = ["Idle", "Pending Purchase", "Checkout"]

        return HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(index <= currentStepIndex ? theme.colors.primary : theme.colors.disabled)
                            .frame(width: 24, height: 24)

                        if index < currentStepIndex {
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
                        .foregroundColor(index <= currentStepIndex ? theme.colors.primary : theme.colors.textSecondary)
                }

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStepIndex ? theme.colors.primary : theme.colors.disabled)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                }
            }
        }
        .padding(theme.spacing.md)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.borderRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: theme.borderRadius.xl)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .customShadow(theme.shadows.small)
    }

    // MARK: - APM Type Selection

    private var apmTypeSelectionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Select APM types to offer")
                .font(theme.typography.subtitleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.StripeAPMPayment.apmSectionTitle)
                .accessibilityLabel(AccessibilityLabels.StripeAPMPayment.apmSectionTitle)
                .accessibilityHint(AccessibilityHints.StripeAPMPayment.apmSectionTitle)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: theme.spacing.sm) {
                ForEach(availableAPMTypes, id: \.id) { apmType in
                    APMTypeRowView(
                        iconName: apmType.icon,
                        title: apmType.name,
                        isSelected: selectedAPMTypes.contains(apmType.id),
                        onToggle: {
                            if selectedAPMTypes.contains(apmType.id) {
                                selectedAPMTypes.remove(apmType.id)
                            } else {
                                selectedAPMTypes.insert(apmType.id)
                            }
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.borderRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: theme.borderRadius.xl)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .customShadow(theme.shadows.small)
    }

    // MARK: - Subscriptions

    // Step 0: Subscribe to payment results before starting the flow
    private func setupSubscriptions() {
        paymentResultCancellable?.cancel()
        paymentResultCancellable = Spreedly.shared().subscribeToPaymentResults { result in
            handlePaymentResult(result)
        }
    }

    // MARK: - Flow

    // Step 1: Start flow — create pending purchase on backend
    private func startStripeAPMFlow() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        pendingMessage = nil
        stage = .creatingPendingPurchase

        Task {
            await createPendingPurchase()
        }
    }

    // Step 1a: Backend call — POST purchase with stripe_apm, get transaction_token + client_secret
    private func createPendingPurchase() async {
        let priceInDollars = await MainActor.run { selectedProduct?.price ?? 0 }
        guard priceInDollars > 0 else {
            await MainActor.run {
                isLoading = false
                stage = .idle
                errorMessage = "Please select a product"
            }
            return
        }
        let amountInCents = priceInDollars * AppConstants.centsPerDollar
        let redirectUrl = AppConstants.stripeAPMRedirectURL
        let callbackUrl = AppConstants.exampleCallbackURL

        let apmTypes = await MainActor.run { Array(selectedAPMTypes) }
        do {
            let client = SpreedlyConfigManager.shared.createPurchaseAPIClient()
            let response = try await client.stripeAPMPendingPurchase(
                amount: amountInCents,
                currencyCode: "EUR",
                redirectUrl: redirectUrl,
                callbackUrl: callbackUrl,
                apmTypes: apmTypes
            )

            await MainActor.run {
                guard let transaction = response.transaction else {
                    isLoading = false
                    stage = .idle
                    errorMessage = "Failed to create pending purchase"
                    return
                }

                guard transaction.state == "pending" else {
                    isLoading = false
                    stage = .idle
                    let msg = "Transaction not in pending state: \(transaction.state ?? "unknown"). Message: \(transaction.message ?? "none")"
                    errorMessage = msg
                    return
                }

                guard let clientSecret = transaction.gatewaySpecificResponseFields?
                        .stripePaymentIntents?.clientSecret,
                      !clientSecret.isEmpty else {
                    isLoading = false
                    stage = .idle
                    errorMessage = "Missing client_secret in pending purchase response"
                    return
                }

                // Step 2: Build StripeAPMConfig and present PaymentSheet via SDK
                stage = .checkout
                let config = StripeAPMConfig(
                    publishableKey: SpreedlyConfigManager.shared.stripePublishableKey,
                    clientSecret: clientSecret,
                    transactionToken: transaction.token,
                    merchantDisplayName: "Spreedly Example",
                    returnURL: AppConstants.stripeAPMReturnURL
                )

                SpreedlyStripeAPMCheckout.present(config: config)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                stage = .idle
                errorMessage = "Pending purchase failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Payment Result Handling

    // Step 4 result: SDK polled status and published result. Show success/pending/error.
    // Cancel arrives as isFailure with "canceled" in description — check for it.
    private func handlePaymentResult(_ result: PaymentResult) {
        guard stage == .checkout else {
            return
        }

        if result.isSuccess {
            isLoading = false
            stage = .idle
            if result.state == "processing" {
                pendingMessage = "Payment accepted and is being processed. Final confirmation may take a few days."
                successMessage = nil
            } else if result.state == "pending" {
                pendingMessage = "Payment submitted. Awaiting final confirmation from the payment provider."
                successMessage = nil
            } else {
                successMessage = "Payment successful. The transaction has been completed."
                pendingMessage = nil
            }
            errorMessage = nil
        } else if result.isFailure {
            isLoading = false
            stage = .idle
            let description = result.failureDetails?.getDescription() ?? "\(stripeAPMMethodDisplayName) payment failed."
            if description.lowercased().contains("canceled") {
                errorMessage = "\(stripeAPMMethodDisplayName) payment was canceled."
            } else {
                errorMessage = description
            }
            successMessage = nil
            pendingMessage = nil
        }
    }

}

// MARK: - APM Type Row View

private struct APMTypeRowView: View {
    let iconName: String
    let title: String
    let isSelected: Bool
    let onToggle: () -> Void
    @Environment(\.spreedlyTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var cellBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#2C2C2E") : Color(.systemGray6)
    }

    private var selectedCellBackgroundColor: Color {
        colorScheme == .dark ? cellBackgroundColor : theme.colors.primary.opacity(0.1)
    }

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacing.md) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(isSelected ? theme.colors.primary : theme.colors.textSecondary)
                .frame(width: 32, height: 32)

            Text(title)
                .font(theme.typography.subtitleFont)
                .foregroundColor(theme.colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .foregroundColor(isSelected ? theme.colors.primary : theme.colors.textSecondary)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(isSelected ? selectedCellBackgroundColor : cellBackgroundColor)
        .cornerRadius(theme.borderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: theme.borderRadius.sm)
                .stroke(isSelected ? theme.colors.primary : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onToggle()
        }
        .accessibilityAddTraits(.isButton)
    }
}

private enum StripeAPMStage {
    case idle
    case creatingPendingPurchase
    case checkout
}

#Preview {
    NavigationView {
        StripeAPMPaymentFlowView()
    }
}
