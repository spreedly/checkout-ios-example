//
//  CustomFormView.swift
//  SpreedlySDKExample
//
//  Created by Vinay Naikade on 02/07/25.
//

// =============================================================================
// KT OVERVIEW — CustomFormView
// =============================================================================
// This view demonstrates the "Headless UI" approach to card payments.
// Instead of using the pre-built CardFormDropIn, it builds the form field-by-field
// using individual SPLTextField components from the SDK.
//
// Flow:
//   1. App renders individual SPLTextField components for each field (name, card, CVC, expiry)
//   2. Each SPLTextField handles its own input masking, validation, and secure storage
//   3. App tracks per-field validity via onValidationChange callbacks
//   4. User taps "PAY NOW" → app generates signature → calls Spreedly.shared().createCreditCard()
//   5. createCreditCard() returns immediately with a processing status (validation pass/fail)
//   6. Actual API result arrives asynchronously via subscribeToPaymentResults
//
// KEY DIFFERENCE FROM CheckoutBasicView:
//   - CheckoutBasicView uses CardFormDropIn (SDK builds the entire form)
//   - CustomFormView uses SPLTextField individually (app controls layout and UX)
//   - CustomFormView calls createCreditCard() directly instead of letting the drop-in handle it
// =============================================================================

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI


/*
 * Theme Usage Examples for SPLTextField (SwiftUI):
 * 
 * SwiftUI Usage:
 * 
 * // Method 1: Using Environment Theme (Recommended)
 * struct MyView: View {
 *     @Environment(\.spreedlyTheme) private var theme
 *     
 *     var body: some View {
 *         SPLTextField(
 *             type: .cardNumber,
 *             isRequired: true,
 *             theme: theme  // Uses the current environment theme
 *         )
 *     }
 * }
 * 
 * // Method 2: Using Custom Theme Directly
 * struct MyView: View {
 *     var body: some View {
 *         SPLTextField(
 *             type: .cardNumber,
 *             isRequired: true,
 *             theme: SpreedlyThemeManager.createCustomTheme(
 *                 colors: SpreedlyColors(primary: Color.blue)
 *             )
 *         )
 *     }
 * }
 * 
 * // Method 3: Using Predefined Themes
 * struct MyView: View {
 *     var body: some View {
 *         SPLTextField(
 *             type: .cardNumber,
 *             isRequired: true,
 *             theme: SpreedlyDarkTheme()  // or SpreedlyLightTheme()
 *         )
 *     }
 * }
 * 
 * // Method 4: Setting Global Theme (affects all SPLTextField instances)
 * SpreedlyThemeManager.setGlobalTheme(SpreedlyDarkTheme())
 * 
 * // Method 5: Creating Custom Theme with Multiple Properties
 * let customTheme = SpreedlyThemeManager.createCustomTheme(
 *     colors: SpreedlyColors(
 *         primary: Color.blue,
 *         border: Color.gray,
 *         error: Color.red
 *     ),
 *     borderRadius: SpreedlyBorderRadius(sm: 12.0)
 * )
 * 
 * SPLTextField(
 *     type: .cardNumber,
 *     isRequired: true,
 *     theme: customTheme
 * )
 */

struct CustomFormView: View {
    // Step 1: State variables — track loading, results, errors, and Combine subscription
    @State private var isLoading: Bool = false
    @State private var paymentResult: PaymentResult?
    @State private var errorMessage: String?
    @State private var cancellable: AnyCancellable?        // Combine subscription for async payment results
    @Environment(\.spreedlyTheme) private var theme        // current theme from SwiftUI environment
    @Environment(\.colorScheme) private var colorScheme
    
    // Step 2: Per-field validation states — each SPLTextField reports validity via onValidationChange
    // The "PAY NOW" button is enabled only when ALL required fields are valid (see isFormValid).
    @State private var cardNumberIsValid: Bool = false
    @State private var cvcIsValid: Bool = false
    @State private var expirationDateIsValid: Bool = false
    @State private var expirationMonthIsValid: Bool = false
    @State private var expirationYearIsValid: Bool = false
    @State private var fullNameIsValid: Bool = false
    
    // Step 3: Focus management — tracks which field is focused for keyboard "Next"/"Done" navigation
    @State private var focusedFieldType: FormFieldType?
    
    // Step 4: Validation config — toggles that relax SDK validation rules (same as CheckoutBasicView)
    @State private var allowBlankName: Bool = false
    @State private var allowExpiredDate: Bool = false
    @State private var allowBlankDate: Bool = false
    @State private var combinedExpiryDate: Bool = false    // true = single MM/YY field, false = separate month + year
    @State private var yearFormat: YearFormat = .fourDigit
    
    // Step 5: Retain flag — if true, the token is saved server-side for future charges
    @State private var shouldRetain: Bool = false
    
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Custom Payment Form")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.title)
                    .accessibilityHint(AccessibilityHints.CustomForm.title)
                
                Text("This demonstrates a custom form built at the application level using headless UI components from the SDK.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.description)
                    .accessibilityHint(AccessibilityHints.CustomForm.description)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Form Components:")
                        .font(.headline)
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.componentsTitle)
                        .accessibilityLabel(AccessibilityLabels.CustomForm.componentsTitle)
                        .accessibilityHint(AccessibilityHints.CustomForm.componentsTitle)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("• Card Holder Name: SPLTextField with .fullName type")
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.cardHolderNameComponent)
                        .accessibilityLabel(AccessibilityLabels.CustomForm.cardHolderNameComponent)
                        .accessibilityHint(AccessibilityHints.CustomForm.cardHolderNameComponent)
                    
                    Text("• Card Number: SPLTextField with .cardNumber type")
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.cardNumberComponent)
                        .accessibilityLabel(AccessibilityLabels.CustomForm.cardNumberComponent)
                        .accessibilityHint(AccessibilityHints.CustomForm.cardNumberComponent)
                    
                    Text("• CVC: SPLTextField with .cvc type")
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.cvcComponent)
                        .accessibilityLabel(AccessibilityLabels.CustomForm.cvcComponent)
                        .accessibilityHint(AccessibilityHints.CustomForm.cvcComponent)
                    
                    Text("• Expiry Date: SPLTextField with .expirationDate type")
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.expiryDateComponent)
                        .accessibilityLabel(AccessibilityLabels.CustomForm.expiryDateComponent)
                        .accessibilityHint(AccessibilityHints.CustomForm.expiryDateComponent)
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
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.configurationTitle)
                        .accessibilityLabel(AccessibilityLabels.CustomForm.configurationTitle)
                        .accessibilityHint(AccessibilityHints.CustomForm.configurationTitle)
                        .accessibilityAddTraits(.isHeader)
                        
                    HStack {
                        Toggle(
                            "Combined Expiry Date",
                            isOn: $combinedExpiryDate
                        )
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.combinedExpiryDateToggle)
                        .accessibilityHint(AccessibilityHints.CustomForm.combinedExpiryDateToggle)
                    }
                    
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
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.allowBlankNameToggle)
                        .accessibilityHint(AccessibilityHints.CustomForm.allowBlankNameToggle)
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
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.allowExpiredDateToggle)
                        .accessibilityHint(AccessibilityHints.CustomForm.allowExpiredDateToggle)
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
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.allowBlankDateToggle)
                        .accessibilityHint(AccessibilityHints.CustomForm.allowBlankDateToggle)
                    }
                    
                    if !combinedExpiryDate {
                        HStack {
                            Text("Year Format:")
                                .font(.subheadline)
                                .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.yearFormatLabel)
                                .accessibilityLabel(AccessibilityLabels.CustomForm.yearFormatLabel)
                                .accessibilityHint(AccessibilityHints.CustomForm.yearFormatLabel)
                            
                            Spacer()
                            
                            Picker("Year Format", selection: $yearFormat) {
                                Text("YY").tag(YearFormat.twoDigit)
                                    .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.yearFormatTwoDigit)
                                    .accessibilityLabel(AccessibilityLabels.CustomForm.yearFormatTwoDigit)
                                    .accessibilityHint(AccessibilityHints.CustomForm.yearFormatTwoDigit)
                                
                                Text("YYYY").tag(YearFormat.fourDigit)
                                    .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.yearFormatFourDigit)
                                    .accessibilityLabel(AccessibilityLabels.CustomForm.yearFormatFourDigit)
                                    .accessibilityHint(AccessibilityHints.CustomForm.yearFormatFourDigit)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#EFEDEA"), lineWidth: 1) // gray-200 border
                )
                .shadow(color: cardShadowColor, radius: 4, x: 0, y: 0)
                
                // General error message (only for non-field-specific errors)
                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.errorMessage)
                        .accessibilityHint(AccessibilityHints.CustomForm.errorMessage)
                }
                
                // Step 6: SPLTextField components — each one is an individual SDK-provided secure input field
                // type: determines input behavior (masking, validation rules, keyboard type)
                // isRequired: controls if empty is a validation error
                // theme: applies visual styling from the current Spreedly theme
                // onValidationChange: callback that fires whenever field validity changes (used to enable/disable PAY button)
                // onSubmit + submitLabel: keyboard "Next"/"Done" button behavior
                // shouldFocus + onFocus: programmatic focus management for field-to-field navigation
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        SPLTextField(
                            type: .fullName,
                            title: "Card Holder Name",
                            isRequired: !allowBlankName,
                            theme: theme,
                            onValidationChange: { valid in
                                fullNameIsValid = valid
                            },
                            onSubmit: {
                                handleFieldSubmit(for: .fullName)
                            },
                            submitLabel: getSubmitLabel(for: .fullName),
                            shouldFocus: focusedFieldType == .fullName,
                            onFocus: {
                                focusedFieldType = .fullName
                            }
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Card Number component with proper theming
                        SPLTextField(
                            type: .cardNumber,
                            title: "Card Number",
                            isRequired: true,
                            theme: theme,
                            onValidationChange: { valid in
                                cardNumberIsValid = valid
                            },
                            onSubmit: {
                                handleFieldSubmit(for: .cardNumber)
                            },
                            submitLabel: getSubmitLabel(for: .cardNumber),
                            shouldFocus: focusedFieldType == .cardNumber,
                            onFocus: {
                                focusedFieldType = .cardNumber
                            }
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // CVC component with proper theming
                        SPLTextField(
                            type: .cvc,
                            title: "Security Code (CVC)",
                            isRequired: true,
                            theme: theme,
                            onValidationChange: { valid in
                                cvcIsValid = valid
                            },
                            onSubmit: {
                                handleFieldSubmit(for: .cvc)
                            },
                            submitLabel: getSubmitLabel(for: .cvc),
                            shouldFocus: focusedFieldType == .cvc,
                            onFocus: {
                                focusedFieldType = .cvc
                            }
                        )
                    }
                    
                    if combinedExpiryDate {
                        VStack(alignment: .leading, spacing: 8) {
                            // Combined Expiry Date component with proper theming and forced 2-digit year format
                            SPLTextField(
                                type: .expirationDate,
                                title: "Expiry Date",
                                isRequired: !allowBlankDate,
                                theme: theme,
                                yearFormat: .twoDigit,
                                onValidationChange: { valid in
                                    expirationDateIsValid = valid
                                },
                                onSubmit: {
                                    handleFieldSubmit(for: .expirationDate)
                                },
                                submitLabel: getSubmitLabel(for: .expirationDate),
                                shouldFocus: focusedFieldType == .expirationDate,
                                onFocus: {
                                    focusedFieldType = .expirationDate
                                }
                            )
                        }
                    } else {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                // Expiry Month component
                                SPLTextField(
                                    type: .expirationMonth,
                                    title: "Expiry Month",
                                    isRequired: !allowBlankDate,
                                    theme: theme,
                                    onValidationChange: { valid in
                                        expirationMonthIsValid = valid
                                    },
                                    onSubmit: {
                                        handleFieldSubmit(for: .expirationMonth)
                                    },
                                    submitLabel: getSubmitLabel(for: .expirationMonth),
                                    shouldFocus: focusedFieldType == .expirationMonth,
                                    onFocus: {
                                        focusedFieldType = .expirationMonth
                                    }
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {

                                // Expiry Year component with year format
                                SPLTextField(
                                    type: .expirationYear,
                                    title: "Expiry Year",
                                    isRequired: !allowBlankDate,
                                    theme: theme,
                                    yearFormat: yearFormat,
                                    onValidationChange: { valid in
                                        expirationYearIsValid = valid
                                    },
                                    onSubmit: {
                                        handleFieldSubmit(for: .expirationYear)
                                    },
                                    submitLabel: getSubmitLabel(for: .expirationYear),
                                    shouldFocus: focusedFieldType == .expirationYear,
                                    onFocus: {
                                        focusedFieldType = .expirationYear
                                    }
                                )
                                .id("expiry-year-\(yearFormat.rawValue)") // Force recreation when year format changes
                            }
                        }
                    }
                }
                .padding()
                
                // Checkbox for "Save card for future payments"
                HStack(spacing: theme.spacing.sm) {
                    Button(action: {
                        shouldRetain.toggle()
                    }) {
                        Image(systemName: shouldRetain ? "checkmark.square.fill" : "square")
                            .foregroundColor(shouldRetain ? theme.colors.primary : theme.colors.textSecondary)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(LocalizationHelper.localizedString(for: "save_card_for_future_payments", defaultValue: "Save card for future payments"))
                        .font(theme.typography.bodyFont)
                        .foregroundColor(theme.colors.text)
                        .onTapGesture {
                            shouldRetain.toggle()
                        }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, theme.spacing.xs)
                .accessibility(identifier: "custom-form-save-card-checkbox")
                
                // Step 7: Submit button — enabled only when isFormValid is true (all required fields pass validation)
                Button(action: handleSubmit) {
                    Text(isLoading ? "Processing..." : "PAY NOW")
                        .font(primaryButtonFont)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isFormValid && !isLoading ? theme.colors.primary : theme.colors.primary.opacity(0.6))
                        )
                }
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.payButton)
                .accessibilityHint(AccessibilityHints.CustomForm.payButton)
                
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
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        // Step 8: onAppear — sync validation toggle states and subscribe to async payment results
        .onAppear {
            if !Spreedly.isDeviceTrusted {
                errorMessage = Spreedly.initializationError?.message ?? "SDK blocked by security check"
            }
            
            allowBlankName = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankName)
            allowExpiredDate = Spreedly.shared().paramsManager.getParam(parameter: .allowExpiredDate)
            allowBlankDate = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankDate)
            
            // Subscribe to payment results — this Combine publisher fires when Spreedly API responds
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                paymentResult = result
                isLoading = false
                
                if result.isSuccess {
                    errorMessage = nil
                    fullNameIsValid = false
                    cardNumberIsValid = false
                    cvcIsValid = false
                    expirationDateIsValid = false
                    expirationMonthIsValid = false
                    expirationYearIsValid = false
                    // Check if user wants to retain the payment method
                    if shouldRetain, let paymentMethodToken = result.token {
                        // Call retain API asynchronously
                        Task {
                            await retainPaymentMethod(token: paymentMethodToken)
                        }
                    }
                    // Clear any previous error
                } else if result.isFailure {
                    if let failureDetails = result.failureDetails {
                        errorMessage = failureDetails.getDescription()
                    } else {
                        errorMessage = "Payment failed"
                    }
                
                }
            }
        }
        // Step 9: Cleanup — cancel Combine subscription and reset SDK validation params
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
            ValidationParamReset.reset()
        }
    }
    
    // MARK: - Retain Payment Method Helper
    private func retainPaymentMethod(token: String) async {
        do {
            let apiClient = SpreedlyConfigManager.shared.createRetainPaymentMethodAPIClient()
            _ = try await apiClient.retainPaymentMethod(token: token)
        } catch {
            logError(tag: "SpreedlyExample", message: "Retain payment method failed: \(error.localizedDescription)", error: error)
        }
    }
    
    // Step 10: Form validity — aggregates all per-field validation states to enable/disable the PAY button
    private var isFormValid: Bool {
        let nameValid = fullNameIsValid
        let cardValid = cardNumberIsValid && cvcIsValid
        let expirationValid: Bool
        if combinedExpiryDate {
            expirationValid = expirationDateIsValid
        } else {
            expirationValid = expirationMonthIsValid && expirationYearIsValid
        }
        
        return nameValid && cardValid && expirationValid
    }
    
    private func isSignatureGenerated() async -> Bool {
        let signatureGenerated = await SpreedlyConfigManager.shared.generateSignature()
        switch signatureGenerated {
        case .success(let success):
            return success
        case .failure(_):
            return false
        }
    }
    
    // Step 12: Focus management — defines field tab order and handles "Next"/"Done" keyboard actions
    // MARK: - Focus Management
    
    private var fieldOrder: [FormFieldType] {
        if combinedExpiryDate {
            return [.fullName, .cardNumber, .cvc, .expirationDate]
        } else {
            return [.fullName, .cardNumber, .cvc, .expirationMonth, .expirationYear]
        }
    }
    
    /// Get submit label for a field type
    private func getSubmitLabel(for fieldType: FormFieldType) -> SpreedlySubmitLabel {
        let allFields = fieldOrder
        guard let currentIndex = allFields.firstIndex(of: fieldType) else {
            return .done
        }
        
        // If this is the last field, show "Done", otherwise show "Next"
        return currentIndex == allFields.count - 1 ? .done : .next
    }
    
    /// Handle field submission (focus next field or submit form)
    private func handleFieldSubmit(for fieldType: FormFieldType) {
        let allFields = fieldOrder
        guard let currentIndex = allFields.firstIndex(of: fieldType) else {
            return
        }

        let submitLabel = getSubmitLabel(for: fieldType)

        switch submitLabel {
        case .next:
            // Move to next field
            if currentIndex < allFields.count - 1 {
                let nextFieldType = allFields[currentIndex + 1]
                focusNextField(fieldType: nextFieldType)
            }
        case .done:
            // Reset focus state before form submission
            focusedFieldType = nil
            // Submit the form
            handleSubmit()
        case .return, .go, .search, .send, .join, .route, .continue:
            // For other submit labels, treat them the same as .done
            focusedFieldType = nil
        @unknown default:
            // Handle any future unknown cases by submitting the form
            focusedFieldType = nil
        }
    }
    
    /// Focus the next field
    private func focusNextField(fieldType: FormFieldType) {
        focusedFieldType = fieldType
    }
    
    // Step 11: handleSubmit — the core payment flow for the custom form approach
    // 1. Generate HMAC signature (required by Spreedly API)
    // 2. Call createCreditCard() — SPLTextField already stored card data securely in SecureValueContainer
    // 3. createCreditCard() returns immediately with processing status (sync validation result)
    // 4. If processing started, the actual API result arrives via the subscribeToPaymentResults subscription
    private func handleSubmit() {
        guard isFormValid else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        paymentResult = nil
        
        Task {
            let signatureGenerated = await isSignatureGenerated()
            if !signatureGenerated {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to generate signature. Please try again."
                    self.paymentResult = nil
                }
                return
            }
            
            await MainActor.run {
                // additionalFields can carry extra billing/shipping data (empty here; see CheckoutWithAdditionalFieldsView)
                let additionalFields: [AdditionalField: String] = [:]
                
                // createCreditCard reads card data from SecureValueContainer (populated by SPLTextField)
                let processingResult = Spreedly.shared().createCreditCard(
                    additionalFields: additionalFields,
                    metadata: [:]
                )
                
                if processingResult.isValidationFailed {
                    self.isLoading = false
                    self.errorMessage = "Validation failed: \(processingResult.getDescription())"
                    self.paymentResult = nil
                } else if processingResult.isProcessing {
                    // API call in flight — result arrives via subscribeToPaymentResults
                }
            }
        }
    }
    
    private func clearForm() {
        errorMessage = nil
        shouldRetain = false
        // SPLTextField handles its own clearing through SpreedlyUIManager.shared.resetFields
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
    CustomFormView()
} 
