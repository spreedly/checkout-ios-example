//
//  ThreeDSPaymentFlowView.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI
#if canImport(Forter3DS)
import Forter3DS
#endif

// MARK: - 3DS Payment Flow View
struct ThreeDSPaymentFlowView: View {
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
    
    // Payment methods loading state
    @State private var isLoadingCards: Bool = false
    @State private var savedCards: [SavedCard] = []
    
    // Mocked products for demo - Electronic items
    private let products: [Product] = [
        Product(id: "prod_1", name: "Wireless Earbuds", price: 99, description: "Premium wireless earbuds with active noise cancellation", iconName: "airpods"),
        Product(id: "prod_2", name: "Smart Watch", price: 499, description: "Feature-rich smartwatch with health tracking and fitness monitoring", iconName: "applewatch"),
        Product(id: "prod_3", name: "Tablet", price: 699, description: "High-performance tablet with stunning display", iconName: "ipad"),
        Product(id: "prod_4", name: "Laptop", price: 400, description: "Powerful laptop for work and creativity", iconName: "laptopcomputer"),
        Product(id: "prod_5", name: "Smart Speaker", price: 299, description: "Voice-controlled smart speaker with premium sound", iconName: "speaker.wave.3"),
        Product(id: "prod_6", name: "Gaming Console", price: 399, description: "Next-generation gaming console with immersive gameplay", iconName: "gamecontroller")
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
            Text("3DS Global Flow")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.ThreeDSChallenge.title)
                .accessibilityLabel(AccessibilityLabels.ThreeDSChallenge.title)
                .accessibilityHint(AccessibilityHints.ThreeDSChallenge.title)
                .accessibilityAddTraits(.isHeader)
            
            Text("Global 3DS: select a product and payment method, then complete the challenge if required.")
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
                    useGatewaySpecific3DS: false
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
                        
                        // Check if 3DS is required (sca_authentication is nested inside transaction)
                        if transaction.scaAuthentication != nil {
                            show3DSChallenge = true
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
                    errorMessage = "Transaction failed due to failed authentication. Please try again."
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
        
        challengeCancellable = Spreedly.shared().subscribeToThreeDSChallengeResults { result in
            
            self.isLoading = false
            
            if result.isSuccess {
                // 3DS Challenge completed successfully
                // The SDK has already called three_ds_automated_complete API and status API internally
                // Result is based on status API response
                self.errorMessage = nil
                self.show3DSChallenge = false
                self.successMessage = "Your payment has been securely authenticated and processed."
                // Reset selections after successful payment
                self.resetSelections()
                
            } else if result.isFailure {
                // 3DS Challenge failed
                // Check for specific error codes from status API and show human-readable messages
                var errorMsg: String?
                if let failureDetails = result.failureDetails,
                   let message = failureDetails.message {
                    if message == "messages.failed_sca_authentication" ||
                        message.contains("Forter3DS.FTR3DSError") {
                        errorMsg = "Transaction failed due to failed authentication. Please try again."
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
                self.errorMessage = "Payment canceled by user"
                // Reset selections on cancel
                self.resetSelections()
            }
        }
    }
    
    private func cleanupSubscriptions() {
        challengeCancellable?.cancel()
        challengeCancellable = nil
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
        ThreeDSPaymentFlowView()
    }
}

