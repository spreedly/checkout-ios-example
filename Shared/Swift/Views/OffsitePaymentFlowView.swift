//
//  OffsitePaymentFlowView.swift
//  MerchantExample
//
//
//

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI

struct OffsitePaymentFlowView: View {
    @Environment(\.spreedlyTheme) private var environmentTheme
    @State private var selectedProduct: Product?
    @State private var selectedProvider: OffsitePaymentMethodType = .sprel
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingMessage: String?
    @State private var paymentResultCancellable: AnyCancellable?
    @State private var stage: OffsiteStage = .idle
    
    private let products: [Product] = [
        Product(id: "prod_1", name: "Wireless Earbuds", price: 99, description: "Premium wireless earbuds with active noise cancellation", iconName: "airpods"),
        Product(id: "prod_2", name: "Smart Watch", price: 0.44, description: "Feature-rich smartwatch with health tracking", iconName: "applewatch"),
        Product(id: "prod_3", name: "Tablet", price: 699, description: "High-performance tablet with stunning display", iconName: "ipad"),
        Product(id: "prod_4", name: "Laptop", price: 400, description: "Powerful laptop for work and creativity", iconName: "laptopcomputer"),
        Product(id: "prod_5", name: "Smart Speaker", price: 299, description: "Voice-controlled smart speaker with premium sound", iconName: "speaker.wave.3"),
        Product(id: "prod_6", name: "Gaming Console", price: 399, description: "Next-generation gaming console", iconName: "gamecontroller")
    ]
    
    private var theme: SpreedlyTheme {
        environmentTheme
    }
    
    /// Provider display name for messages: "PayPal" or "Sprel" (per PAYMENT_MESSAGES_CROSS_PLATFORM).
    private var providerDisplayName: String {
        selectedProvider == .paypal ? "PayPal" : "Sprel"
    }

    private var isStartButtonEnabled: Bool {
        selectedProduct != nil && !isLoading
    }
    
    private var buttonTitle: String {
        guard let product = selectedProduct else {
            return "Select a product"
        }
        switch stage {
        case .idle:
            return String(format: "Pay $%.2f", NSDecimalNumber(decimal: product.price).doubleValue)
        case .creatingPaymentMethod:
            return "Creating payment method..."
        case .purchasing:
            return "Processing purchase..."
        case .checkout:
            return "Waiting for checkout..."
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg) {
                headerSection
                
                stageIndicator
                
                ProductSelectionView(
                    products: products,
                    selectedProduct: $selectedProduct
                )
                
                paymentProviderSection
                
                Button(action: startOffsiteFlow) {
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
                .accessibilityIdentifier(AccessibilityIdentifiers.OffsitePayment.startButton)
                .accessibilityLabel(AccessibilityLabels.OffsitePayment.startButton)
                .accessibilityHint(AccessibilityHints.OffsitePayment.startButton)
                .accessibilityAddTraits(.isButton)
                
                if let success = successMessage {
                    MessageView.success(
                        message: success,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.OffsitePayment.successIcon,
                        iconAccessibilityLabel: AccessibilityLabels.OffsitePayment.successIcon,
                        iconAccessibilityHint: AccessibilityHints.OffsitePayment.successIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.OffsitePayment.successTitle,
                        titleAccessibilityLabel: AccessibilityLabels.OffsitePayment.successTitle,
                        titleAccessibilityHint: AccessibilityHints.OffsitePayment.successTitle
                    )
                }
                
                if let pending = pendingMessage {
                    MessageView.pending(
                        message: pending,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.OffsitePayment.pendingIcon,
                        iconAccessibilityLabel: AccessibilityLabels.OffsitePayment.pendingIcon,
                        iconAccessibilityHint: AccessibilityHints.OffsitePayment.pendingIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.OffsitePayment.pendingTitle,
                        titleAccessibilityLabel: AccessibilityLabels.OffsitePayment.pendingTitle,
                        titleAccessibilityHint: AccessibilityHints.OffsitePayment.pendingTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.OffsitePayment.pendingMessage,
                        messageAccessibilityHint: AccessibilityHints.OffsitePayment.pendingMessage
                    )
                }

                if let error = errorMessage {
                    MessageView.error(
                        message: error,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.OffsitePayment.errorIcon,
                        iconAccessibilityLabel: AccessibilityLabels.OffsitePayment.errorIcon,
                        iconAccessibilityHint: AccessibilityHints.OffsitePayment.errorIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.OffsitePayment.errorTitle,
                        titleAccessibilityLabel: AccessibilityLabels.OffsitePayment.errorTitle,
                        titleAccessibilityHint: AccessibilityHints.OffsitePayment.errorTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.OffsitePayment.errorMessage,
                        messageAccessibilityHint: AccessibilityHints.OffsitePayment.errorMessage
                    )
                }
            }
            .padding(theme.spacing.md)
        }
        .navigationTitle("Offsite Payment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupSubscriptions()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("Offsite Payment Flow")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.OffsitePayment.title)
                .accessibilityLabel(AccessibilityLabels.OffsitePayment.title)
                .accessibilityHint(AccessibilityHints.OffsitePayment.title)
                .accessibilityAddTraits(.isHeader)
            Text("Create offsite payment method, then purchase and complete checkout.")
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.textSecondary)
                .accessibilityIdentifier(AccessibilityIdentifiers.OffsitePayment.description)
                .accessibilityLabel(AccessibilityLabels.OffsitePayment.description)
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
    
    private var currentStepIndex: Int {
        switch stage {
        case .idle: return 0
        case .creatingPaymentMethod: return 1
        case .purchasing: return 2
        case .checkout: return 3
        }
    }
    
    private var stageIndicator: some View {
        let steps = ["Idle", "Tokenize", "Purchase", "Checkout"]
        
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
    
    private var paymentProviderSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Select payment provider")
                .font(theme.typography.subtitleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.OffsitePayment.providerSectionTitle)
                .accessibilityLabel(AccessibilityLabels.OffsitePayment.providerSectionTitle)
                .accessibilityHint(AccessibilityHints.OffsitePayment.providerSectionTitle)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: theme.spacing.sm) {
                ProviderRowView(
                    iconName: "creditcard.fill",
                    title: "PayPal",
                    subtitle: "Pay securely with PayPal account",
                    isSelected: selectedProvider == .paypal,
                    onSelect: { selectedProvider = .paypal }
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.OffsitePayment.providerRowPayPal)
                .accessibilityLabel(AccessibilityLabels.OffsitePayment.providerRowPayPal)
                .accessibilityHint(AccessibilityHints.OffsitePayment.providerRowPayPal)
                .accessibilityAddTraits(selectedProvider == .paypal ? [.isButton, .isSelected] : .isButton)
                ProviderRowView(
                    iconName: "creditcard.fill",
                    title: "Sprel",
                    subtitle: "Pay securely with Sprel account",
                    isSelected: selectedProvider == .sprel,
                    onSelect: { selectedProvider = .sprel }
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.OffsitePayment.providerRowSprel)
                .accessibilityLabel(AccessibilityLabels.OffsitePayment.providerRowSprel)
                .accessibilityHint(AccessibilityHints.OffsitePayment.providerRowSprel)
                .accessibilityAddTraits(selectedProvider == .sprel ? [.isButton, .isSelected] : .isButton)
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
    
    // Step 0: Subscribe to payment results (fires for both tokenization AND checkout)
    private func setupSubscriptions() {
        paymentResultCancellable?.cancel()
        paymentResultCancellable = Spreedly.shared().subscribeToPaymentResults { result in
            handlePaymentResult(result)
        }
    }
    
    // Step 1: Tokenization — generate signature, build config, create payment method
    private func startOffsiteFlow() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        pendingMessage = nil
        stage = .creatingPaymentMethod
        
        Task {
            // Step 1a: Generate backend auth signature
            let signatureResult = await SpreedlyConfigManager.shared.generateSignature()
            guard case .success = signatureResult else {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to generate signature"
                    stage = .idle
                }
                return
            }
            
            // Step 1b: Build offsite config (.paypal or .sprel)
            let config = OffsitePaymentConfig(
                paymentMethodType: selectedProvider,
                email: "test@test.com",
                fullName: "Ana Santos Araujo",
                documentId: DocumentId(key: .documentId, value: "853.513.468-93"),
                country: "BR",
                phoneNumber: "8522847035",
                address1: "Rua E, 1040",
                city: "Maracanaú",
                state: "CE",
                zip: "12345"
            )
            
            // Step 1c: Submit to SDK — result arrives in handlePaymentResult
            _ = Spreedly.shared().submitOffsitePayment(config: config)
        }
    }
    
    // Handles PaymentResult — `stage` tells us which step fired it
    private func handlePaymentResult(_ result: PaymentResult) {
        switch stage {

        // Step 1 result: Got token → move to Step 2 (purchase)
        case .creatingPaymentMethod:
            if result.isSuccess, let paymentMethodToken = result.token {
                stage = .purchasing
                Task { await purchaseWithToken(paymentMethodToken) }
            } else if result.isFailure {
                isLoading = false
                stage = .idle
                if let detail = result.failureDetails?.getDescription() {
                    errorMessage = "Failed to create payment method: \(detail)"
                } else {
                    errorMessage = "Failed to create payment method"
                }
            }
            
        case .purchasing:
            break
            
        // Step 4 result: Checkout done — show success/pending/error to user
        case .checkout:
            if result.isSuccess {
                isLoading = false
                stage = .idle
                if result.state == "processing" {
                    pendingMessage = "Your \(providerDisplayName) payment is currently being processed. Please wait a moment."
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
                if result.state == "processing" {
                    pendingMessage = "Your \(providerDisplayName) payment is currently being processed. Please wait a moment."
                    successMessage = nil
                    errorMessage = nil
                } else if result.state == "gateway_processing_failed" {
                    errorMessage = "We couldn’t complete your \(providerDisplayName) payment. Please try again."
                    pendingMessage = nil
                    successMessage = nil
                } else if result.state == "pending" {
                    pendingMessage = "Payment submitted. Awaiting final confirmation from the payment provider."
                    successMessage = nil
                    errorMessage = nil
                } else {
                    errorMessage = result.failureDetails?.getDescription() ?? "\(providerDisplayName) checkout failed."
                    pendingMessage = nil
                    successMessage = nil
                }
            }
            
        case .idle:
            break
        }
    }
    
    // Step 2: Purchase — backend creates transaction, returns transaction_token
    private func purchaseWithToken(_ paymentMethodToken: String) async {
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
        let redirectUrl = AppConstants.offsiteRedirectURL
        let callbackUrl = AppConstants.exampleCallbackURL
        let gateway = selectedProvider == .sprel ? "sprel" : "paypal"
        do {
            let client = SpreedlyConfigManager.shared.createPurchaseAPIClient()
            let response = try await client.offsitePurchase(
                gateway: gateway,
                paymentMethodToken: paymentMethodToken,
                amount: amountInCents,
                currencyCode: CurrencyCode.usd.rawValue,
                redirectUrl: redirectUrl,
                callbackUrl: callbackUrl
            )
            
            await MainActor.run {
                if let transaction = response.transaction {
                    // Step 3: Checkout — SDK opens Safari with gateway's checkout page
                    stage = .checkout
                    SpreedlyOffsiteCheckout.present(transactionToken: transaction.token)
                } else {
                    isLoading = false
                    stage = .idle
                    errorMessage = "Purchase failed while setting up a transaction"
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                stage = .idle
                if error.localizedDescription == "gateway_setup_failed" {
                    errorMessage = "Purchase failed while setting up a transaction"
                } else {
                    errorMessage = "Purchase failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Provider Row View
private struct ProviderRowView: View {
    let iconName: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onSelect: () -> Void
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
            
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(title)
                    .font(theme.typography.subtitleFont)
                    .foregroundColor(theme.colors.text)
                Text(subtitle)
                    .font(theme.typography.captionFont)
                    .foregroundColor(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
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
            onSelect()
        }
    }
}

private enum OffsiteStage {
    case idle
    case creatingPaymentMethod
    case purchasing
    case checkout
}

#Preview {
    NavigationView {
        OffsitePaymentFlowView()
    }
}
