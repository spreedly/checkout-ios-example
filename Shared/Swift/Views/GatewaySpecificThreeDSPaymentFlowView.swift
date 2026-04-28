//
//  ThreeDSPaymentFlowView.swift
//  MerchantExample
//
//
//

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI

// MARK: - 3DS Payment Flow View
struct GatewaySpecificThreeDSPaymentFlowView: View {
    @Environment(\.spreedlyTheme) private var environmentTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedProduct: Product?
    @State private var selectedCard: SavedCard?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var show3DSChallenge: Bool = false
    @State private var transactionToken: String?
    @State private var challengeCancellable: AnyCancellable?
    @State private var gatewaySpecificCompletionCancellable: AnyCancellable?
    
    // Payment methods loading state
    @State private var isLoadingCards: Bool = false
    @State private var savedCards: [SavedCard] = []
    
    // Mocked products for demo - Electronic items
    private let products: [Product] = [
        Product(id: "prod_1", name: "Frictionless", price: 3001, description: "3DS2 frictionless (immediate success)", iconName: "airpods"),
        Product(id: "prod_2", name: "Fingerprint + Direct Auth", price: 3003, description: "Device fingerprint + direct authorize", iconName: "applewatch"),
        Product(id: "prod_3", name: "Fingerprint + Challenge", price: 3004, description: "Device fingerprint + challenge", iconName: "ipad"),
        Product(id: "prod_4", name: "Direct Challenge", price: 3005, description: "Challenge without fingerprint", iconName: "laptopcomputer"),
        Product(id: "prod_5", name: "Fingerprint + Forced Failure", price: 3103, description: "Device fingerprint + forced failure", iconName: "speaker.wave.3"),
        Product(id: "prod_6", name: "Challenge + Forced Failure", price: 3104, description: "Challenge + forced failure", iconName: "gamecontroller")
    ]
    
    // Computed property for theme
    private var theme: SpreedlyTheme {
        return environmentTheme
    }
    
    // Computed property to check if Pay button should be enabled
    private var isPayButtonEnabled: Bool {
        return selectedProduct != nil && selectedCard != nil && !isLoading
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg) {
                // Header
                headerSection
                
                // Product Selection
                ProductSelectionView(
                    products: products,
                    selectedProduct: $selectedProduct
                )
                
                // Payment Method Selection
                if isLoadingCards {
                    HStack {
                        ProgressView()
                            .padding(.trailing, theme.spacing.sm)
                        Text("Loading payment methods...")
                            .font(theme.typography.captionFont)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                    .padding(theme.spacing.md)
                    .frame(maxWidth: .infinity)
                } else {
                    PaymentMethodSelectionView(
                        cards: savedCards,
                        selectedCard: $selectedCard
                    )
                }
                
                // Pay Button
                payButton
                
                // Success Message
                if let success = successMessage {
                    MessageView.success(
                        message: success,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.ThreeDSChallenge.successIcon,
                        iconAccessibilityLabel: AccessibilityLabels.ThreeDSChallenge.successIcon,
                        iconAccessibilityHint: AccessibilityHints.ThreeDSChallenge.successIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.ThreeDSChallenge.successTitle,
                        titleAccessibilityLabel: AccessibilityLabels.ThreeDSChallenge.successTitle,
                        titleAccessibilityHint: AccessibilityHints.ThreeDSChallenge.successTitle
                    )
                }
                
                // Error Message
                if let error = errorMessage {
                    MessageView.error(
                        message: error,
                        iconAccessibilityIdentifier: AccessibilityIdentifiers.ThreeDSChallenge.errorIcon,
                        iconAccessibilityLabel: AccessibilityLabels.ThreeDSChallenge.errorIcon,
                        iconAccessibilityHint: AccessibilityHints.ThreeDSChallenge.errorIcon,
                        titleAccessibilityIdentifier: AccessibilityIdentifiers.ThreeDSChallenge.errorTitle,
                        titleAccessibilityLabel: AccessibilityLabels.ThreeDSChallenge.errorTitle,
                        titleAccessibilityHint: AccessibilityHints.ThreeDSChallenge.errorTitle,
                        messageAccessibilityIdentifier: AccessibilityIdentifiers.ThreeDSChallenge.errorMessage,
                        messageAccessibilityHint: AccessibilityHints.ThreeDSChallenge.errorMessage
                    )
                }
                
                Spacer(minLength: theme.spacing.lg)
            }
            .padding(theme.spacing.md)
        }
        .navigationTitle("3DS Challenge Demo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $show3DSChallenge) {
            if let transactionToken = transactionToken {
                   DoChallengeIfNeeded(
                    transactionToken: transactionToken,
                    onDismiss: {
                        show3DSChallenge = false
                    }
                )
                .screenPrevention()
            }
        }
        .onAppear {
            setupSubscriptions()
            fetchPaymentMethods()
        }
        .onDisappear {
            cleanupSubscriptions()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("3DS Gateway-Specific Flow")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.ThreeDSChallenge.title)
                .accessibilityLabel(AccessibilityLabels.ThreeDSChallenge.title)
                .accessibilityHint(AccessibilityHints.ThreeDSChallenge.title)
                .accessibilityAddTraits(.isHeader)
            
            Text("Gateway-specific 3DS: select a product and payment method, then complete the gateway challenge flow.")
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.textSecondary)
                .accessibilityIdentifier(AccessibilityIdentifiers.ThreeDSChallenge.description)
                .accessibilityHint(AccessibilityHints.ThreeDSChallenge.description)
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
    
    private var payButton: some View {
        Button(action: handlePayButtonTap) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, theme.spacing.sm)
                }
                Text(isLoading ? "Processing..." : "Pay")
                    .font(theme.typography.buttonFont)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacing.md)
            .background(isPayButtonEnabled ? theme.colors.primary : theme.colors.primary.opacity(0.6))
            .cornerRadius(theme.borderRadius.sm)
        }
        .disabled(!isPayButtonEnabled)
        .accessibilityIdentifier(AccessibilityIdentifiers.ThreeDSChallenge.payButton)
        .accessibilityLabel(isLoading ? "Processing" : AccessibilityLabels.ThreeDSChallenge.payButton)
        .accessibilityHint(AccessibilityHints.ThreeDSChallenge.payButton)
    }
    
    
    // MARK: - Actions
    
    private func handlePayButtonTap() {
        guard let product = selectedProduct,
              let card = selectedCard else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            // Generate signature first
            let signatureResult = await SpreedlyConfigManager.shared.generateSignature()
            
            guard case .success = signatureResult else {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to generate signature"
                    // Reset selections on error
                    resetSelections()
                }
                return
            }
            
            // Call purchase API
            let amountInCents = product.price
            
            do {
                let client = SpreedlyConfigManager.shared.createPurchaseAPIClient()
                
                let response = try await client.purchase(
                    paymentMethodToken: card.paymentMethodToken,
                    amount: amountInCents,
                    currencyCode: AppConstants.defaultCurrencyCode.rawValue,
                    useGatewaySpecific3DS: true
                )
                
                await MainActor.run {
                    isLoading = false
                    
                    // Check for errors
                    if let errors = response.errors, !errors.isEmpty {
                        let errorMessages = errors.compactMap { $0.message }.joined(separator: ", ")
                        errorMessage = errorMessages.isEmpty ? "Purchase failed" : errorMessages
                        // Reset selections on error
                        resetSelections()
                        return
                    }
                    
                    // Extract transaction token and check for 3DS
                    if let transaction = response.transaction {
                        transactionToken = transaction.token
                        
                        // Check if 3DS is required: transaction is pending or has device_fingerprint required action
                        if transaction.state == "pending" || transaction.scaAuthentication?.requiredAction == "device_fingerprint" {
                            show3DSChallenge = true
                        } else if transaction.state == "succeeded" {
                            handlePaymentSuccess()
                        }
                    } else {
                        errorMessage = SPLErrorMessages.noTransactionData
                        // Reset selections on error
                        resetSelections()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let apiError = error as? PurchaseAPIError {
                        errorMessage = apiError.localizedDescription
                    } else {
                        errorMessage = "Purchase failed: \(error.localizedDescription)"
                    }
                    // Reset selections on error
                    resetSelections()
                }
            }
        }
    }
    
    // MARK: - Subscriptions
    
    private func setupSubscriptions() {
        // Clean up any existing subscriptions first to prevent duplicates
        cleanupSubscriptions()
        
        // Subscribe to 3DS challenge results (must subscribe BEFORE presenting challenge view)
        // Note: The publisher already ensures the closure runs on the main thread via .receive(on: DispatchQueue.main)
        
        // Subscribe to Gateway-Specific 3DS trigger completion events
        // This is required for gateway-specific flows where merchant must call /complete.json
        // Using Combine publisher (consistent with other APIs like paymentResultPublisher)
        gatewaySpecificCompletionCancellable = Spreedly.shared().subscribeToGatewaySpecific3DSTriggerCompletion { event in
            // Handle onTriggerCompletion - merchant must call /complete.json
            // Note: SwiftUI views are structs (value types), so we can't use [weak self]
            // The cancellable is stored in @State and will be cleaned up in cleanupSubscriptions()
            // The publisher already ensures the closure runs on the main thread via .receive(on: DispatchQueue.main)
            self.handleGatewaySpecificTriggerCompletion(token: event.token, event: event)
        }
        
        challengeCancellable = Spreedly.shared().subscribeToThreeDSChallengeResults { result in
            
            self.isLoading = false
            
            if result.isSuccess {
                // 3DS Challenge completed successfully
                // Result is based on status API response
                handlePaymentSuccess()
                
            } else if result.isFailure {
                // 3DS Challenge failed
                // Check for specific error codes from status API and show human-readable messages
                var errorMsg: String?
                if let failureDetails = result.failureDetails,
                   let message = failureDetails.message {
                    if message.lowercased().contains("forced failure") {
                        errorMsg = "Forced Failure"
                    } else {
                        errorMsg = "Payment failed: \(message)"
                    }
                } else if let error = result.error {
                    errorMsg = "Payment failed: \(error.localizedDescription)"
                } else {
                    errorMsg = "Payment failed"
                }
                
                self.errorMessage = errorMsg
                logError(tag: "ThreeDSChallengeDemo", message: "3DS challenge failed: \(errorMsg ?? "Unknown error")")
                self.show3DSChallenge = false
                // Reset selections on failure
                self.resetSelections()
                
            } else if result.isCanceled {
                // User canceled 3DS challenge
                self.show3DSChallenge = false
                if let failureDetails = result.failureDetails,
                   let message = failureDetails.message,
                   message.lowercased().contains("forced failure") {
                    self.errorMessage = "Forced Failure"
                } else if let error = result.error,
                          error.localizedDescription.lowercased().contains("forced failure") {
                    self.errorMessage = "Forced Failure"
                } else {
                    self.errorMessage = "Payment canceled by user"
                }
                // Reset selections on cancel
                self.resetSelections()
            }
        }
    }
    
    private func cleanupSubscriptions() {
        challengeCancellable?.cancel()
        challengeCancellable = nil
        gatewaySpecificCompletionCancellable?.cancel()
        gatewaySpecificCompletionCancellable = nil
    }
    
    // MARK: - Gateway-Specific 3DS Handling
    
    /// Handles Gateway-Specific 3DS trigger completion notification
    /// This is called when device fingerprint polling completes and merchant must call /complete.json
    @MainActor
    private func handleGatewaySpecificTriggerCompletion(token: String, event: GatewaySpecific3DSEvent) {
        
        // MERCHANT RESPONSIBILITY: Call your backend /complete endpoint.
        // Your backend should call Spreedly:
        // POST https://core.spreedly.com/v1/transactions/{token}/complete.json
        // This example app calls a sample backend (configured via purchaseBaseURL).
        
        Task {
            do {
                // Call sample backend complete endpoint (for testing - in production, call your backend)
                let client = SpreedlyConfigManager.shared.createPurchaseAPIClient()
                let statusResponse = try await client.complete(transactionToken: token)
                
                if let transaction = statusResponse.transaction {
                    let state = transaction.state?.lowercased() ?? ""
                    if state == "succeeded" {
                        await MainActor.run {
                            handlePaymentSuccess()
                        }
                        return
                    }
                    // Always call finalizeTransaction with the transaction from /complete.json response
                    // The SDK lifecycle will handle all states (succeeded, failed, pending) appropriately
                    logDebug(tag: "ThreeDSPaymentFlowView", message: "Complete API response received - calling finalizeTransaction() with state: \(state)")
                    
                    await MainActor.run {
                        GatewaySpecific3DSIntegration.finalizeTransaction(
                            for: token,
                            transaction: transaction
                        )
                        logDebug(tag: "ThreeDSPaymentFlowView", message: "finalizeTransaction() called - SDK will handle succeeded/pending/failed states")
                    }
                } else {
                    logError(tag: "ThreeDSPaymentFlowView", message: "No transaction in complete API response")
                }
            } catch {
                logError(tag: "ThreeDSPaymentFlowView", message: "Failed to call complete API", error: error)
                await MainActor.run {
                    show3DSChallenge = false
                    let errorText = error.localizedDescription
                    if errorText.lowercased().contains("forced failure") {
                        errorMessage = "Forced Failure"
                    } else {
                        errorMessage = "Failed to complete 3DS flow: \(errorText)"
                    }
                    // Reset selections on error
                    resetSelections()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Resets the selected product and card after API response
    /// This method must be called on the main thread as it modifies @State properties
    /// - Note: All callers should ensure they're on the main thread (e.g., within MainActor.run blocks)
    @MainActor
    private func resetSelections() {
        selectedProduct = nil
        selectedCard = nil
    }

    @MainActor
    private func handlePaymentSuccess() {
        errorMessage = nil
        show3DSChallenge = false
        successMessage = "Payment successful. The transaction has been completed."
        // Reset selections after successful payment
        resetSelections()
    }
    
    // MARK: - API Calls
    
    /// Fetches payment methods from the API and converts them to SavedCard models
    /// Same implementation as CVVRecachingView
    private func fetchPaymentMethods() {
        isLoadingCards = true
        errorMessage = nil
        
        Task {
            do {
                let client = SpreedlyConfigManager.shared.createFetchPaymentMethodsAPIClient()
                let response = try await client.fetchPaymentMethods()
                
                // Convert PaymentMethod to SavedCard, filtering only credit cards
                let cards = response.paymentMethods?
                    .filter { $0.paymentMethodType == AppConstants.creditCardPaymentMethodType }
                    .compactMap { paymentMethod -> SavedCard? in
                        guard let lastFourDigits = paymentMethod.lastFourDigits,
                              let cardType = paymentMethod.cardType else {
                            return nil
                        }
                        
                        // Format card type for display (capitalize first letter)
                        let displayCardType = cardType.replacingOccurrences(of: "_", with: " ").capitalized
                        
                        // Format expiry month and year
                        let expiryMonth = paymentMethod.month.map { String(format: "%02d", $0) }
                        let expiryYear = paymentMethod.year.map { String($0) }
                        
                        return SavedCard(
                            id: paymentMethod.token ?? "",
                            paymentMethodToken: paymentMethod.token ?? "",
                            lastFourDigits: lastFourDigits,
                            cardType: displayCardType,
                            cardBrand: cardType.lowercased(),
                            expiryMonth: expiryMonth,
                            expiryYear: expiryYear
                        )
                    }
                
                await MainActor.run {
                    // Show only top 5 cards
                    savedCards = Array(cards?.prefix(upTo: 6) ?? [])
                    isLoadingCards = false
                }
            } catch {
                await MainActor.run {
                    isLoadingCards = false
                    if let apiError = error as? FetchPaymentMethodsAPIError {
                        errorMessage = apiError.localizedDescription
                    } else {
                        errorMessage = "Failed to load payment methods: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
}

#Preview {
    NavigationView {
        GatewaySpecificThreeDSPaymentFlowView()
    }
}

