//
//  CheckoutWithAdditionalFieldsView.swift
//  SpreedlySDKExample
//
//  Created by Vinay Naikade on 02/07/25.
//

// =============================================================================
// KT OVERVIEW — CheckoutWithAdditionalFieldsView
// =============================================================================
// This view demonstrates using CardFormDropIn with EXTRA billing/address fields.
// It's the same "Drop-In" approach as CheckoutBasicView, but passes an
// `otherFields` array to CardFormDropIn so the SDK renders additional fields
// (address, city, state, ZIP) below the standard card fields.
//
// Flow:
//   1. Define additional FormField objects (address, city, state, zip)
//   2. User configures validation options (same toggles as CheckoutBasicView)
//   3. User taps "Show Checkout Form with Address"
//   4. App generates HMAC signature, then presents CardFormDropIn as a sheet
//   5. CardFormDropIn renders standard card fields + the additional fields
//   6. Payment result arrives via subscribeToPaymentResults (same as CheckoutBasicView)
//
// KEY DIFFERENCE FROM CheckoutBasicView:
//   - Passes `otherFields: additionalFields` to CardFormDropIn
//   - The SDK auto-renders those extra fields and includes their values in the API call
// =============================================================================

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI


struct CheckoutWithAdditionalFieldsView: View {
    // Step 1: State variables — same pattern as CheckoutBasicView
    @State private var showForm = false
    @State private var paymentResult: PaymentResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var cancellable: AnyCancellable?
    @Environment(\.spreedlyTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    
    // Step 2: Validation config toggles (same as CheckoutBasicView)
    @State private var allowBlankName: Bool = false
    @State private var allowExpiredDate: Bool = false
    @State private var allowBlankDate: Bool = false
    @State private var yearFormat: YearFormat = .fourDigit

    // Step 3: Define additional fields — these are passed to CardFormDropIn via `otherFields`
    // Each FormField has: id (unique key), title (label), type (determines validation & keyboard), isRequired
    // CardFormDropIn renders these BELOW the standard card fields (name, number, expiry, CVC)
    private let additionalFields: [FormField] = [
        FormField(id: "addressLine1", title: "Address Line 1", type: .addressLine1, isRequired: true),
        FormField(id: "addressLine2", title: "Address Line 2", type: .addressLine2, isRequired: false),
        FormField(id: "city", title: "City", type: .city, isRequired: true),
        FormField(id: "state", title: "State", type: .state, isRequired: true),
        FormField(id: "zipCode", title: "ZIP Code", type: .zipCode, isRequired: true)
    ]
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Checkout with Additional Fields")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.title)
                    .accessibilityHint(AccessibilityHints.AdditionalFields.title)
                
                Text("This demonstrates the CardFormDropIn component with additional address fields for billing information.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.description)
                    .accessibilityHint(AccessibilityHints.AdditionalFields.description)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Fields:")
                        .font(.headline)
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.defaultFieldsTitle)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.defaultFieldsTitle)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.defaultFieldsTitle)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("• First Name")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.firstNameFieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.firstNameFieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.firstNameFieldItem)
                    
                    Text("• Last Name")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.lastNameFieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.lastNameFieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.lastNameFieldItem)
                    
                    Text("• Card Number")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.cardNumberFieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.cardNumberFieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.cardNumberFieldItem)
                    
                    Text("• Expiry Month")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.expiryMonthFieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.expiryMonthFieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.expiryMonthFieldItem)
                    
                    Text("• Expiry Year")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.expiryYearFieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.expiryYearFieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.expiryYearFieldItem)
                    
                    Text("• CVC")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.cvcFieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.cvcFieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.cvcFieldItem)
                    
                    Text("Additional Fields:")
                        .font(.headline)
                        .padding(.top, 8)
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.additionalFieldsTitle)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.additionalFieldsTitle)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.additionalFieldsTitle)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("• Address Line 1 (Required)")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.addressLine1FieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.addressLine1FieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.addressLine1FieldItem)
                    
                    Text("• Address Line 2 (Optional)")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.addressLine2FieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.addressLine2FieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.addressLine2FieldItem)
                    
                    Text("• City (Required)")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.cityFieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.cityFieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.cityFieldItem)
                    
                    Text("• State (Required)")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.stateFieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.stateFieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.stateFieldItem)
                    
                    Text("• ZIP Code (Required)")
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.zipCodeFieldItem)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.zipCodeFieldItem)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.zipCodeFieldItem)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
                .shadow(color: cardShadowColor, radius: 4, x: 0, y: 0)
                
                // Configuration toggles
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuration Options:")
                        .font(.headline)
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.configurationTitle)
                        .accessibilityLabel(AccessibilityLabels.AdditionalFields.configurationTitle)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.configurationTitle)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack {
                        Toggle(
                            "Allow Blank Name",
                            isOn: Binding(
                                get: { allowBlankName
                                },
                                set: { newValue in
                                    allowBlankName = newValue
                                    Spreedly
                                        .shared()
                                        .setParam(
                                            parameter: .allowBlankName,
                                            value: newValue
                                        )
                                }
                            )
                        )
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.allowBlankNameToggle)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.allowBlankNameToggle)
                    }
                    
                    HStack {
                        Toggle(
                            "Allow Expired Date",
                            isOn: Binding(
                                get: { allowExpiredDate
                                },
                                set: { newValue in
                                    allowExpiredDate = newValue
                                    Spreedly
                                        .shared()
                                        .setParam(
                                            parameter: .allowExpiredDate,
                                            value: newValue
                                        )
                                }
                            )
                        )
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.allowExpiredDateToggle)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.allowExpiredDateToggle)
                    }
                    
                    HStack {
                        Toggle(
                            "Allow Blank Date",
                            isOn: Binding(
                                get: { allowBlankDate
                                },
                                set: { newValue in
                                    allowBlankDate = newValue
                                    Spreedly
                                        .shared()
                                        .setParam(
                                            parameter: .allowBlankDate,
                                            value: newValue
                                        )
                                }
                            )
                        )
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.allowBlankDateToggle)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.allowBlankDateToggle)
                    }
                    
                    HStack {
                        Text("Year Format:")
                            .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.yearFormatLabel)
                            .accessibilityLabel(AccessibilityLabels.AdditionalFields.yearFormatLabel)
                            .accessibilityHint(AccessibilityHints.AdditionalFields.yearFormatLabel)
                        
                        Picker("Year Format", selection: $yearFormat) {
                            Text("YY").tag(YearFormat.twoDigit)
                                .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.yearFormatTwoDigit)
                                .accessibilityLabel(AccessibilityLabels.AdditionalFields.yearFormatTwoDigit)
                                .accessibilityHint(AccessibilityHints.AdditionalFields.yearFormatTwoDigit)
                            
                            Text("YYYY").tag(YearFormat.fourDigit)
                                .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.yearFormatFourDigit)
                                .accessibilityLabel(AccessibilityLabels.AdditionalFields.yearFormatFourDigit)
                                .accessibilityHint(AccessibilityHints.AdditionalFields.yearFormatFourDigit)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
                .shadow(color: cardShadowColor, radius: 4, x: 0, y: 0)
                
                // Step 4: Generate HMAC signature and present the card form sheet
                Button("Show Checkout Form with Address") {
                    isLoading = true
                    Task {
                        await SpreedlyConfigManager.shared.generateSignature()
                        isLoading = false
                        showForm = true
                    }
                }
                .font(primaryButtonFont)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isLoading ? theme.colors.primary.opacity(0.6) : theme.colors.primary)
                .cornerRadius(8)
                .disabled(isLoading)
                .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.showFormButton)
                .accessibilityHint(AccessibilityHints.AdditionalFields.showFormButton)
                
                if let result = paymentResult, result.isSuccess {
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.colors.success)
                            Text("Payment Successful!")
                                .font(theme.typography.subtitleFont)
                                .foregroundColor(theme.colors.success)
                        }
                        
                        if let token = result.token {
                            Text("Payment Token: \(Spreedly.maskedToken(token))")
                                .font(theme.typography.captionFont)
                                .foregroundColor(theme.colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(theme.spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: theme.borderRadius.md)
                            .fill(theme.colors.success.opacity(0.1))
                            .customShadow(theme.shadows.small)
                    )
                    .padding(.horizontal, theme.spacing.md)
                    .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.successResultSection)
                    .accessibilityHint(AccessibilityHints.AdditionalFields.successResultSection)
                }
                
                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.errorMessage)
                        .accessibilityHint(AccessibilityHints.AdditionalFields.errorMessage)
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        // Step 5: CardFormDropIn with otherFields — the key difference from CheckoutBasicView
        // otherFields: additionalFields adds address fields below the standard card form
        // .screenPrevention() blocks screenshots/recording for PCI compliance
        .sheet(isPresented: $showForm) {
            CardFormDropIn(
                otherFields: additionalFields,
                yearFormat: yearFormat,
                onProcessingResult: { processingResult in
                    if processingResult.isProcessing {
                        isLoading = true
                    }
                }
            ).screenPrevention()
        }
        // Step 6: onAppear — sync toggle states and subscribe to async payment results (same pattern as CheckoutBasicView)
        .onAppear {
            allowBlankName = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankName)
            allowExpiredDate = Spreedly.shared().paramsManager.getParam(parameter: .allowExpiredDate)
            allowBlankDate = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankDate)
            
            cancellable =  Spreedly.shared().subscribeToPaymentResults { result in
                paymentResult = result
                isLoading = false
                
                if result.isSuccess {
                    errorMessage = nil  // Clear any previous error
                    showForm = false
                    // Check if user wants to retain the payment method
                    if result.shouldRetain, let paymentMethodToken = result.token {
                        
                        // Call retain API asynchronously
                        Task {
                            await retainPaymentMethod(token: paymentMethodToken)
                        }
                    }
                } else if result.isFailure {
                    if let failureDetails = result.failureDetails {
                        errorMessage = failureDetails.getDescription()
                    } else {
                        errorMessage = "Payment failed"
                    }
                    paymentResult = nil
                    isLoading = false
                    showForm = false
                }
            }
        }
        // Step 7: Cleanup — cancel subscription and reset validation params
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
            ValidationParamReset.reset()
        }
    }
    
    // Step 8: Retain — saves the payment token server-side for future charges
    // MARK: - Retain Payment Method Helper
    private func retainPaymentMethod(token: String) async {
        do {
            let apiClient = SpreedlyConfigManager.shared.createRetainPaymentMethodAPIClient()
            _ = try await apiClient.retainPaymentMethod(token: token)
        } catch {
            logError(tag: "SpreedlyExample", message: "Retain payment method failed: \(error.localizedDescription)", error: error)
        }
    }
    
    // Primary button font: Poppins, 16px, weight 400 (regular)
    private var primaryButtonFont: Font {
        if let poppins = UIFont(name: "Poppins", size: 16) {
            return Font(poppins)
        } else if let poppinsRegular = UIFont(name: "Poppins-Regular", size: 16) {
            return Font(poppinsRegular)
        } else {
            // Fallback to system font with regular weight
            return Font.system(size: 16, weight: .regular)
        }
    }
    
    // MARK: - Adaptive Colors
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#1C1C1E") : Color(hex: "#FFFFFF")
    }
    
    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#EFEDEA")
    }
    
    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color(hex: "#AFB4B5").opacity(0.8)
    }
}

#Preview {
    CheckoutWithAdditionalFieldsView()
} 
