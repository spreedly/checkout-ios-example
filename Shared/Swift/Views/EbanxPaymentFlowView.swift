//
//  EbanxPaymentFlowView.swift
//  SpreedlySDKExample
//
//  Follows the same architecture as StripeAPMPaymentFlowView and OffsitePaymentFlowView:
//  {Flow}PaymentFlowView with stage enum, product selection, and PaymentResult subscription.
//

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI

struct EbanxPaymentFlowView: View {
    @Environment(\.spreedlyTheme) private var environmentTheme
    @State private var selectedProduct: Product?
    @State private var selectedProvider: OffsitePaymentMethodType = .pix
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingMessage: String?
    @State private var paymentResultCancellable: AnyCancellable?
    @State private var stage: EbanxStage = .idle
    
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
    
    private var isStartButtonEnabled: Bool {
        selectedProduct != nil && !isLoading
    }
    
    private var currencyCode: CurrencyCode {
        selectedProvider == .oxxo ? .mxn : .brl
    }

    /// Method display name for messages: "Pix" | "Boleto Bancario" | "OXXO" | "NuPay" (per PAYMENT_MESSAGES_CROSS_PLATFORM).
    private var ebanxMethodDisplayName: String {
        switch selectedProvider {
        case .pix: return "Pix"
        case .boletoBancario: return "Boleto Bancario"
        case .oxxo: return "OXXO"
        case .nupay: return "NuPay"
        default: return "Pix"
        }
    }

    private var buttonTitle: String {
        guard let product = selectedProduct else {
            return "Select a product"
        }
        let symbol = currencyCode == .mxn ? "MXN" : "BRL"
        switch stage {
        case .idle:
            return String(format: "Pay %@ %.2f", symbol, NSDecimalNumber(decimal: product.price).doubleValue)
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
                
                Button(action: startEbanxFlow) {
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
                .accessibilityIdentifier(AccessibilityIdentifiers.EbanxPayment.startButton)
                .accessibilityLabel(AccessibilityLabels.EbanxPayment.startButton)
                .accessibilityHint(AccessibilityHints.EbanxPayment.startButton)
                .accessibilityAddTraits(.isButton)
                
                if let success = successMessage {
                    MessageView.success(
                        message: success,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.EbanxPayment.successIcon,
                        iconAccessibilityLabel: AccessibilityLabels.EbanxPayment.successIcon,
                        iconAccessibilityHint: AccessibilityHints.EbanxPayment.successIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.EbanxPayment.successTitle,
                        titleAccessibilityLabel: AccessibilityLabels.EbanxPayment.successTitle,
                        titleAccessibilityHint: AccessibilityHints.EbanxPayment.successTitle
                    )
                }
                
                if let pending = pendingMessage {
                    MessageView.pending(
                        message: pending,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.EbanxPayment.pendingIcon,
                        iconAccessibilityLabel: AccessibilityLabels.EbanxPayment.pendingIcon,
                        iconAccessibilityHint: AccessibilityHints.EbanxPayment.pendingIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.EbanxPayment.pendingTitle,
                        titleAccessibilityLabel: AccessibilityLabels.EbanxPayment.pendingTitle,
                        titleAccessibilityHint: AccessibilityHints.EbanxPayment.pendingTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.EbanxPayment.pendingMessage,
                        messageAccessibilityHint: AccessibilityHints.EbanxPayment.pendingMessage
                    )
                }

                if let error = errorMessage {
                    MessageView.error(
                        message: error,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.EbanxPayment.errorIcon,
                        iconAccessibilityLabel: AccessibilityLabels.EbanxPayment.errorIcon,
                        iconAccessibilityHint: AccessibilityHints.EbanxPayment.errorIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.EbanxPayment.errorTitle,
                        titleAccessibilityLabel: AccessibilityLabels.EbanxPayment.errorTitle,
                        titleAccessibilityHint: AccessibilityHints.EbanxPayment.errorTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.EbanxPayment.errorMessage,
                        messageAccessibilityHint: AccessibilityHints.EbanxPayment.errorMessage
                    )
                }
            }
            .padding(theme.spacing.md)
        }
        .navigationTitle("EBANX Payment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupSubscriptions()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("EBANX Payment Flow")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.EbanxPayment.title)
                .accessibilityLabel(AccessibilityLabels.EbanxPayment.title)
                .accessibilityHint(AccessibilityHints.EbanxPayment.title)
                .accessibilityAddTraits(.isHeader)
            Text("Create EBANX offsite payment method, then purchase and complete checkout via Safari.")
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.textSecondary)
                .accessibilityIdentifier(AccessibilityIdentifiers.EbanxPayment.description)
                .accessibilityLabel(AccessibilityLabels.EbanxPayment.description)
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
    
    // MARK: - Provider Selection
    
    private var paymentProviderSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Select EBANX payment method")
                .font(theme.typography.subtitleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.EbanxPayment.providerSectionTitle)
                .accessibilityLabel(AccessibilityLabels.EbanxPayment.providerSectionTitle)
                .accessibilityHint(AccessibilityHints.EbanxPayment.providerSectionTitle)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: theme.spacing.sm) {
                EbanxProviderRowView(
                    iconName: "qrcode",
                    title: "Pix",
                    subtitle: "Pay with QR code via banking app (Brazil)",
                    isSelected: selectedProvider == .pix,
                    onSelect: { selectedProvider = .pix }
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.EbanxPayment.providerRowPix)
                .accessibilityLabel(AccessibilityLabels.EbanxPayment.providerRowPix)
                .accessibilityHint(AccessibilityHints.EbanxPayment.providerRowPix)
                .accessibilityAddTraits(selectedProvider == .pix ? [.isButton, .isSelected] : .isButton)
                
                EbanxProviderRowView(
                    iconName: "doc.text",
                    title: "Boleto Bancario",
                    subtitle: "Pay with bank slip at bank or ATM (Brazil)",
                    isSelected: selectedProvider == .boletoBancario,
                    onSelect: { selectedProvider = .boletoBancario }
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.EbanxPayment.providerRowBoleto)
                .accessibilityLabel(AccessibilityLabels.EbanxPayment.providerRowBoleto)
                .accessibilityHint(AccessibilityHints.EbanxPayment.providerRowBoleto)
                .accessibilityAddTraits(selectedProvider == .boletoBancario ? [.isButton, .isSelected] : .isButton)
                
                EbanxProviderRowView(
                    iconName: "barcode",
                    title: "OXXO",
                    subtitle: "Pay with cash at any OXXO store (Mexico)",
                    isSelected: selectedProvider == .oxxo,
                    onSelect: { selectedProvider = .oxxo }
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.EbanxPayment.providerRowOxxo)
                .accessibilityLabel(AccessibilityLabels.EbanxPayment.providerRowOxxo)
                .accessibilityHint(AccessibilityHints.EbanxPayment.providerRowOxxo)
                .accessibilityAddTraits(selectedProvider == .oxxo ? [.isButton, .isSelected] : .isButton)
                
                EbanxProviderRowView(
                    iconName: "iphone.and.arrow.forward",
                    title: "NuPay",
                    subtitle: "Pay via Nubank app (Brazil)",
                    isSelected: selectedProvider == .nupay,
                    onSelect: { selectedProvider = .nupay }
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.EbanxPayment.providerRowNupay)
                .accessibilityLabel(AccessibilityLabels.EbanxPayment.providerRowNupay)
                .accessibilityHint(AccessibilityHints.EbanxPayment.providerRowNupay)
                .accessibilityAddTraits(selectedProvider == .nupay ? [.isButton, .isSelected] : .isButton)
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
    
    // Step 0: Subscribe to payment results (fires for both tokenization AND checkout)
    private func setupSubscriptions() {
        paymentResultCancellable?.cancel()
        paymentResultCancellable = Spreedly.shared().subscribeToPaymentResults { result in
            handlePaymentResult(result)
        }
    }
    
    // MARK: - Flow
    
    // Step 1: Tokenization — generate signature, build EBANX config, create payment method
    private func startEbanxFlow() {
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
            
            // Step 1b: Build config per provider, then submit to SDK
            let config = buildOffsitePaymentConfig()
            _ = Spreedly.shared().submitOffsitePayment(config: config)
        }
    }
    
    // Step 1b: Build config per EBANX provider (OXXO = Mexico/no doc, others = Brazil/CPF)
    private func buildOffsitePaymentConfig() -> OffsitePaymentConfig {
        switch selectedProvider {
        case .oxxo:
            return OffsitePaymentConfig(
                paymentMethodType: .oxxo,
                email: "test@test.com",
                fullName: "Manuela E. Beyer Rocabado",
                country: "MX",
                phoneNumber: "(040) 577-7687",
                address1: "Oyono, 882",
                city: "Hermosillo",
                state: "Sonora",
                zip: "48822"
            )
        case .nupay:
            return OffsitePaymentConfig(
                paymentMethodType: .nupay,
                email: "test@test.com",
                fullName: "Ana Santos Araujo",
                documentId: DocumentId(key: .documentId, value: "853.513.468-93"),
                country: "BR",
                phoneNumber: "8522847035"
            )
        default:
            return OffsitePaymentConfig(
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
        }
    }
    
    // MARK: - Payment Result Handling

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
            
        // Step 4 result: Checkout done (pending = normal for EBANX, treat as success in UX)
        case .checkout:
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
                if result.state == "processing" {
                    pendingMessage = "Payment accepted and is being processed. Final confirmation may take a few days."
                    successMessage = nil
                    errorMessage = nil
                } else if result.state == "pending" {
                    pendingMessage = "Payment submitted. Awaiting final confirmation from the payment provider."
                    successMessage = nil
                    errorMessage = nil
                } else if result.state == "gateway_processing_failed" {
                    errorMessage = "We couldn't complete your \(ebanxMethodDisplayName) payment. Please try again."
                    pendingMessage = nil
                    successMessage = nil
                } else {
                    let description = result.failureDetails?.getDescription() ?? "\(ebanxMethodDisplayName) payment failed."
                    errorMessage = description.lowercased().contains("canceled") ? "\(ebanxMethodDisplayName) payment was canceled." : description
                    pendingMessage = nil
                    successMessage = nil
                }
            }
            
        case .idle:
            break
        }
    }
    
    // MARK: - Purchase
    
    // Step 2: Purchase — backend creates transaction with EBANX-specific fields
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
        let redirectUrl = AppConstants.ebanxRedirectURL
        let callbackUrl = AppConstants.exampleCallbackURL
        let currency = currencyCode.rawValue

        do {
            let client = SpreedlyConfigManager.shared.createPurchaseAPIClient()
            let response = try await client.ebanxPurchase(
                paymentMethodToken: paymentMethodToken,
                amount: amountInCents,
                currencyCode: currency,
                redirectUrl: redirectUrl,
                callbackUrl: callbackUrl
            )
            
            await MainActor.run {
                if let transaction = response.transaction {
                    // Step 3: Checkout — SDK opens Safari with EBANX checkout page
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

// MARK: - EBANX Provider Row View

private struct EbanxProviderRowView: View {
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

private enum EbanxStage {
    case idle
    case creatingPaymentMethod
    case purchasing
    case checkout
}

#Preview {
    NavigationView {
        EbanxPaymentFlowView()
    }
}
