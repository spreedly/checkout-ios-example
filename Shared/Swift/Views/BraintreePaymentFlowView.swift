//
//  BraintreePaymentFlowView.swift
//  SpreedlySDKExample
//
//  Braintree PayPal / Venmo flow using the SDK's SpreedlyBraintreeCheckout.
//  When Braintree libraries are linked (via SpreedlyUI), the flow uses
//  SpreedlyBraintreeCheckout.present(config:) and paymentResultPublisher.
//

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI
import SpreedlyBraintree

struct BraintreePaymentFlowView: View {
    @Environment(\.spreedlyTheme) private var environmentTheme
    @State private var selectedProduct: Product?
    @State private var selectedPaymentType: String = "paypal"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingMessage: String?
    @State private var stage: BraintreeStage = .idle
    @State private var paymentResultCancellable: AnyCancellable?

    private let products: [Product] = [
        Product(id: "prod_1", name: "Wireless Earbuds", price: 99, description: "Premium wireless earbuds with ANC", iconName: "airpods"),
        Product(id: "prod_2", name: "Smart Watch", price: 0.44, description: "Feature-rich smartwatch with health tracking", iconName: "applewatch"),
        Product(id: "prod_3", name: "Tablet", price: 699, description: "High-performance tablet with stunning display", iconName: "ipad"),
        Product(id: "prod_4", name: "Laptop", price: 400, description: "Powerful laptop for work and creativity", iconName: "laptopcomputer"),
    ]

    private let paymentTypes: [(id: String, name: String, icon: String)] = [
        ("paypal", "PayPal", "dollarsign.circle"),
        ("venmo", "Venmo", "v.circle"),
    ]

    private var theme: SpreedlyTheme { environmentTheme }

    private var isPayButtonEnabled: Bool {
        selectedProduct != nil && !isLoading
    }

    /// Method display name for messages: "PayPal" | "Venmo" (per PAYMENT_MESSAGES_CROSS_PLATFORM).
    private var braintreeMethodDisplayName: String {
        selectedPaymentType == "venmo" ? "Venmo" : "PayPal"
    }

    private var payButtonTitle: String {
        guard let product = selectedProduct else { return "Select a product" }
        switch stage {
        case .idle:
            return String(format: "Pay $%.2f with %@", NSDecimalNumber(decimal: product.price).doubleValue, selectedPaymentType.capitalized)
        case .creatingPurchase:
            return "Creating purchase..."
        case .checkout:
            return "Authorizing payment..."
        case .confirming:
            return "Confirming..."
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

                paymentTypeSection

                payButton

                if let success = successMessage {
                    MessageView.success(
                        message: success,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.BraintreePayment.successIcon,
                        iconAccessibilityLabel: AccessibilityLabels.BraintreePayment.successIcon,
                        iconAccessibilityHint: AccessibilityHints.BraintreePayment.successIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.BraintreePayment.successTitle,
                        titleAccessibilityLabel: AccessibilityLabels.BraintreePayment.successTitle,
                        titleAccessibilityHint: AccessibilityHints.BraintreePayment.successTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.BraintreePayment.successMessage,
                        messageAccessibilityHint: AccessibilityHints.BraintreePayment.successMessage
                    )
                }
                if let pending = pendingMessage {
                    MessageView.pending(
                        message: pending,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.BraintreePayment.pendingIcon,
                        iconAccessibilityLabel: AccessibilityLabels.BraintreePayment.pendingIcon,
                        iconAccessibilityHint: AccessibilityHints.BraintreePayment.pendingIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.BraintreePayment.pendingTitle,
                        titleAccessibilityLabel: AccessibilityLabels.BraintreePayment.pendingTitle,
                        titleAccessibilityHint: AccessibilityHints.BraintreePayment.pendingTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.BraintreePayment.pendingMessage,
                        messageAccessibilityHint: AccessibilityHints.BraintreePayment.pendingMessage
                    )
                }
                if let error = errorMessage {
                    MessageView.error(
                        message: error,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.BraintreePayment.errorIcon,
                        iconAccessibilityLabel: AccessibilityLabels.BraintreePayment.errorIcon,
                        iconAccessibilityHint: AccessibilityHints.BraintreePayment.errorIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.BraintreePayment.errorTitle,
                        titleAccessibilityLabel: AccessibilityLabels.BraintreePayment.errorTitle,
                        titleAccessibilityHint: AccessibilityHints.BraintreePayment.errorTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.BraintreePayment.errorMessage,
                        messageAccessibilityHint: AccessibilityHints.BraintreePayment.errorMessage
                    )
                }
            }
            .padding(theme.spacing.md)
        }
        .navigationTitle("Braintree")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: cleanupOnDisappear)
    }

    private func cleanupOnDisappear() {
        paymentResultCancellable?.cancel()
        paymentResultCancellable = nil
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("Braintree Payment Flow")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
            Text("Create a purchase on the Braintree gateway, then authorize via PayPal or Venmo using the SDK's Braintree checkout. Add BraintreePayPal, BraintreeVenmo, BraintreeDataCollector to the SpreedlyUI target (or app) to enable.")
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.borderRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: theme.borderRadius.xl).stroke(theme.colors.border, lineWidth: 1))
    }

    // MARK: - Stage indicator

    private var currentStepIndex: Int {
        switch stage {
        case .idle: return 0
        case .creatingPurchase: return 1
        case .checkout: return 2
        case .confirming: return 3
        }
    }

    private var stageIndicator: some View {
        let steps = ["Idle", "Purchase", "Checkout", "Confirm"]
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
        .overlay(RoundedRectangle(cornerRadius: theme.borderRadius.xl).stroke(theme.colors.border, lineWidth: 1))
    }

    // MARK: - Payment type selection

    private var paymentTypeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Payment Type")
                .font(theme.typography.subtitleFont)
                .foregroundColor(theme.colors.text)

            HStack(spacing: theme.spacing.md) {
                ForEach(paymentTypes, id: \.id) { type in
                    Button {
                        selectedPaymentType = type.id
                        errorMessage = nil
                        successMessage = nil
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.name)
                                .font(theme.typography.subtitleFont)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacing.md)
                        .background(selectedPaymentType == type.id ? theme.colors.primary.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(theme.borderRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.borderRadius.sm)
                                .stroke(selectedPaymentType == type.id ? theme.colors.primary : Color.clear, lineWidth: 2)
                        )
                    }
                    .foregroundColor(selectedPaymentType == type.id ? theme.colors.primary : theme.colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.borderRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: theme.borderRadius.xl).stroke(theme.colors.border, lineWidth: 1))
    }

    // MARK: - Pay button

    private var payButton: some View {
        Button(action: startBraintreeFlow) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, theme.spacing.sm)
                }
                Text(payButtonTitle)
                    .font(theme.typography.buttonFont)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacing.md)
            .background(isPayButtonEnabled ? theme.colors.primary : theme.colors.primary.opacity(0.6))
            .cornerRadius(theme.borderRadius.sm)
        }
        .disabled(!isPayButtonEnabled)
    }

    // MARK: - Flow (SDK-based)

    /// Starts the Braintree flow. If Braintree SDK is not linked, the flow will fail when
    /// present() is called and the error will be delivered via the payment result handler.
    private func startBraintreeFlow() {
        runSDKBraintreeFlow()
    }

    private func runSDKBraintreeFlow() {
        guard let product = selectedProduct else {
            errorMessage = "Please select a product"
            return
        }
        guard product.price > 0 else {
            errorMessage = "Invalid product price"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        pendingMessage = nil
        stage = .creatingPurchase

        let amountInCents = product.price * AppConstants.centsPerDollar
        // Step 1: Backend purchase — POST create-purchase (gateway braintree, offsite_sync + GSF)
        let paymentType = BraintreePaymentType(string: selectedPaymentType) ?? .paypal

        Task {
            do {
                let apiClient = SpreedlyConfigManager.shared.createPurchaseAPIClient()
                let response = try await apiClient.braintreePurchase(
                    amount: amountInCents,
                    currencyCode: "USD",
                    redirectUrl: AppConstants.braintreeRedirectURL,
                    callbackUrl: AppConstants.exampleCallbackURL,
                    paymentMethodType: paymentType.rawValueString
                )
                guard let transaction = response.transaction else {
                    await resetWith(error: "Failed to create purchase")
                    return
                }
                let validStates = ["processing", "pending"]
                guard let state = transaction.state, validStates.contains(state) else {
                    await resetWith(error: "Transaction not in expected state: \(transaction.state ?? "unknown"). Message: \(transaction.message ?? "none")")
                    return
                }
                let clientToken = transaction.gatewaySpecificResponseFields?.braintree?.clientToken
                let transactionToken = transaction.token
                let amount = String(format: "%.2f", NSDecimalNumber(decimal: product.price).doubleValue)

                await MainActor.run {
                    stage = .checkout
                    subscribeAndPresentBraintree(
                        transactionToken: transactionToken,
                        clientToken: clientToken,
                        paymentType: paymentType,
                        amount: amount
                    )
                }
            } catch {
                await resetWith(error: "Purchase failed: \(error.localizedDescription)")
            }
        }
    }

    private func subscribeAndPresentBraintree(
        transactionToken: String,
        clientToken: String?,
        paymentType: BraintreePaymentType,
        amount: String
    ) {
        paymentResultCancellable?.cancel()
        paymentResultCancellable = nil

        // Step 0: Subscribe to payment results (using .first() — only one result expected)
        paymentResultCancellable = Spreedly.shared().paymentResultPublisher
            .receive(on: DispatchQueue.main)
            .first()
            .sink { [self] result in
                paymentResultCancellable = nil
                handleBraintreeResult(result, transactionToken: transactionToken, paymentType: paymentType)
            }

        // Step 2: Build config — SDK always reads PayPal/Venmo options from transaction status.
        // clientToken is an optional fallback when status omits client_token.
        let config = BraintreeCheckoutConfig(
            transactionToken: transactionToken,
            paymentType: paymentType,
            merchantDisplayName: "",
            clientToken: clientToken,
            amount: amount,
            currencyCode: "USD"
        )
        // Step 3: Present Braintree PayPal/Venmo checkout via SDK
        SpreedlyBraintreeCheckout.present(config: config)
    }

    /// Best-effort confirm for cancel/failure so the backend can finalize the pending transaction.
    private func confirmNonSuccessful(
        transactionToken: String,
        state: String,
        message: String,
        paymentMethodType: String
    ) {
        Task {
            let apiClient = SpreedlyConfigManager.shared.createPurchaseAPIClient()
            _ = try? await apiClient.braintreeConfirm(
                transactionToken: transactionToken,
                state: state,
                paymentMethodType: paymentMethodType,
                message: message
            )
        }
    }

    // Step 4 result: SDK returned nonce + deviceData (or cancel/error).
    // On success: send nonce to backend → confirm (Step 5). Cancel/fail also notify backend (best-effort).
    private func handleBraintreeResult(_ result: PaymentResult, transactionToken: String, paymentType: BraintreePaymentType) {
        let confirmPaymentType = paymentType.rawValueString

        if result.isSuccess, let nonce = result.nonce {
            stage = .confirming
            Task {
                do {
                    let apiClient = SpreedlyConfigManager.shared.createPurchaseAPIClient()
                    let response = try await apiClient.braintreeConfirm(
                        transactionToken: transactionToken,
                        state: "Successful",
                        paymentMethodType: confirmPaymentType,
                        nonce: nonce
                    )
                    await MainActor.run {
                        isLoading = false
                        stage = .idle
                        if let txn = response.transaction {
                            if txn.succeeded {
                                successMessage = "Payment successful. The transaction has been completed successfully."
                                pendingMessage = nil
                                errorMessage = nil
                            } else if txn.state == "processing" || txn.state == "pending" {
                                successMessage = "Payment is being processed. Final confirmation may take a moment."
                                pendingMessage = nil
                                errorMessage = nil
                            } else {
                                let state = txn.state ?? ""
                                let message = txn.message ?? ""
                                errorMessage = "Confirmation returned state: \(state). Message: \(message)"
                                pendingMessage = nil
                                successMessage = nil
                            }
                        } else {
                            errorMessage = "Confirmation response missing transaction data."
                            pendingMessage = nil
                            successMessage = nil
                        }
                    }
                } catch {
                    Task { @MainActor in
                        isLoading = false
                        stage = .idle
                        errorMessage = "Confirmation failed: \(error.localizedDescription)"
                        pendingMessage = nil
                        successMessage = nil
                    }
                }
            }
        } else if result.isCanceled {
            isLoading = false
            stage = .idle
            let message = "\(braintreeMethodDisplayName) payment was canceled."
            errorMessage = message
            pendingMessage = nil
            successMessage = nil
            confirmNonSuccessful(
                transactionToken: transactionToken,
                state: "Cancelled",
                message: message,
                paymentMethodType: confirmPaymentType
            )
        } else {
            isLoading = false
            stage = .idle
            let message: String
            if let sdkMessage = result.failureDetails?.message, !sdkMessage.isEmpty {
                message = sdkMessage
            } else {
                message = "\(braintreeMethodDisplayName) payment failed."
            }
            errorMessage = message
            pendingMessage = nil
            successMessage = nil
            confirmNonSuccessful(
                transactionToken: transactionToken,
                state: "Failed",
                message: message,
                paymentMethodType: confirmPaymentType
            )
        }
    }

    private func resetWith(error message: String) async {
        await MainActor.run {
            isLoading = false
            stage = .idle
            errorMessage = message
            pendingMessage = nil
            successMessage = nil
        }
    }
}

private enum BraintreeStage {
    case idle
    case creatingPurchase
    case checkout
    case confirming
}

#Preview {
    NavigationView {
        BraintreePaymentFlowView()
    }
}
