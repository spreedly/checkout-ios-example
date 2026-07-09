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
//   3b. Card/CVC: onFieldStateChange + opaque onChange; name/expiry onChange logs values; PAN format → setNumberFormat; toggleMask
//   4. User taps "PAY NOW" → app generates signature → calls Spreedly.shared().createCreditCard()
//   5. createCreditCard() returns immediately with a processing status (validation pass/fail)
//   6. Actual API result arrives asynchronously via subscribeToPaymentResults
//
// KEY DIFFERENCE FROM CheckoutBasicView:
//   - CheckoutBasicView uses CardFormDropIn (SDK builds the entire form)
//   - CustomFormView uses SPLTextField individually (app controls layout and UX)
//   - CustomFormView calls createCreditCard() directly instead of letting the drop-in handle it
//
// MERCHANT APIs DEMONSTRATED (see Spreedly / SPLTextField doc comments in SDK):
//   - Spreedly.setParam(.allowBlankName | .allowExpiredDate | .allowBlankDate) — validation toggles below
//   - Spreedly.shared().setNumberFormat / toggleMask — global PAN+CVV display (iframe / web hosted-field parity)
//   - Spreedly.resetPaymentState() — full reset (fields + mask); headless only — no preservePaymentStateOnNextShow here
//   - SPLTextField.onFieldStateChange — HostedFieldState snapshots (no raw PAN/CVV); inspector panel below
//   - SPLTextField.onChange — opaque on PAN/CVC; plaintext logged for name/expiry in this sample
//   - SPLTextField.enableAutofill — QA toggle on every hosted field; off matches legacy iframe toggleAutoComplete
// =============================================================================

import SwiftUI
import Combine
import UIKit
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
    @ObservedObject private var uiManager = SpreedlyUIManager.shared

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
    
    /// QA inspector — store lives off the form's observation graph so INPUT/VALIDATION updates do not rebuild `SPLTextField`s.
    @State private var fieldStateInspectorCoordinator = FieldStateInspectorCoordinator()
    @State private var aggregateValidationReadout = ""
    @State private var onChangeReadout = "onChange: edit a field to see values (card/CVC stay opaque)."
    // Step 3: Focus management — tracks which field is focused for keyboard "Next"/"Done" navigation
    @State private var focusedFieldType: FormFieldType?
    
    // Step 4: Validation config — toggles that relax SDK validation rules (same as CheckoutBasicView)
    @State private var allowBlankName: Bool = false
    @State private var allowExpiredDate: Bool = false
    @State private var allowBlankDate: Bool = false
    @State private var eligibleForCardUpdater: Bool = false // when true, opts card into Spreedly Account Updater
    @State private var combinedExpiryDate: Bool = false    // true = single MM/YY field, false = separate month + year
    @State private var yearFormat: YearFormat = .fourDigit
    
    // Step 5: Retain flag — if true, the token is saved server-side for future charges
    @State private var shouldRetain: Bool = false

    /// QA: Wallet / edit-menu autofill on all hosted fields (`SPLTextField.enableAutofill`). Default matches SDK.
    @State private var enableAutofill: Bool = true

    // Theme picker — same pattern as CheckoutBasicView / CVVRecaching (light + dark passed to SPLTextField)
    @State private var useCustomTheme: Bool = false
    @State private var lightTheme: SpreedlyTheme?
    @State private var darkTheme: SpreedlyTheme?
    @State private var selectedTheme: ThemeOption = .default

    private var splLightTheme: SpreedlyTheme? { useCustomTheme ? lightTheme : nil }
    private var splDarkTheme: SpreedlyTheme? { useCustomTheme ? darkTheme : nil }
    
    
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
                
                // Configuration — each toggle calls Spreedly.shared().setParam (see ValidationParam in SDK).
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

                    HStack {
                        Toggle("Eligible for Card Updater", isOn: $eligibleForCardUpdater)
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                            .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.eligibleForCardUpdaterToggle)
                            .accessibilityHint(AccessibilityHints.CustomForm.eligibleForCardUpdaterToggle)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Enable autofill", isOn: $enableAutofill)
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                            .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.enableAutofillToggle)
                            .accessibilityHint(AccessibilityHints.CustomForm.enableAutofillToggle)
                        Text("Off clears Wallet hints and suppresses AutoFill on hosted fields.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: Hosted PAN/CVV display (merchant APIs on Spreedly)
                    // setNumberFormat + toggleMask update PAN + CVC display together.
                    // resetPaymentState() clears secure storage, SPLTextField text, errors, and display defaults.
                    VStack(alignment: .leading, spacing: 8) {
                        Text(HostedCardDisplayFormatCopy.maskToggleCaption)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Picker(
                            "Card number format",
                            selection: Binding(
                                get: { uiManager.hostedCardDisplayState.cardNumberFormat },
                                set: { newFormat in
                                    Spreedly.shared().setNumberFormat(newFormat)
                                }
                            )
                        ) {
                            Text("Pretty").tag(CardNumberFormat.pretty)
                            Text("Plain").tag(CardNumberFormat.plain)
                            Text("Masked").tag(CardNumberFormat.masked)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .accessibilityIdentifier("custom-form-pan-format-segmented")

                        Button("toggleMask()") {
                            Spreedly.shared().toggleMask()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0))
                        .accessibilityIdentifier("custom-form-toggle-mask-button")
                        .accessibilityHint("Toggles plain revealed ↔ masked hidden for PAN and CVC")

                        Button("resetPaymentState()") {
                            performFullPaymentReset()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0))
                        .accessibilityIdentifier("custom-form-reset-payment-state-button")
                        .accessibilityHint("Full reset: clears fields, validation, and hosted PAN/CVV display to SDK defaults.")
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

                themeConfigurationCard
                
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
                
                // Step 6: SPLTextField — headless fields (see SDK doc on SPLTextField.init for param detail).
                // setParam toggles above map to ValidationParam on Spreedly.shared().
                // Card + CVC: onFieldStateChange; PAN/CVV display driven by setNumberFormat / toggleMask above.
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        SPLTextField(
                            type: .fullName,
                            title: "Card Holder Name",
                            isRequired: !allowBlankName,
                            keyboardType: .default,
                            textContentType: .name,
                            enableAutofill: enableAutofill,
                            theme: splLightTheme,
                            darkTheme: splDarkTheme,
                            onValidationChange: { valid in
                                fullNameIsValid = valid
                                refreshAggregateValidationReadout()
                            },
                            onSubmit: {
                                handleFieldSubmit(for: .fullName)
                            },
                            submitLabel: getSubmitLabel(for: .fullName),
                            shouldFocus: focusedFieldType == .fullName,
                            onFocus: {
                                guard focusedFieldType != .fullName else { return }
                                focusedFieldType = .fullName
                            },
                            onChange: { value in
                                logNonSensitiveFieldChange(.fullName, value: value)
                            }
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Card Number component with proper theming
                        SPLTextField(
                            type: .cardNumber,
                            title: "Card Number",
                            isRequired: true,
                            enableAutofill: enableAutofill,
                            theme: splLightTheme,
                            darkTheme: splDarkTheme,
                            onValidationChange: { valid in
                                cardNumberIsValid = valid
                                refreshAggregateValidationReadout()
                            },
                            onSubmit: {
                                handleFieldSubmit(for: .cardNumber)
                            },
                            submitLabel: getSubmitLabel(for: .cardNumber),
                            shouldFocus: focusedFieldType == .cardNumber,
                            onFocus: {
                                guard focusedFieldType != .cardNumber else { return }
                                focusedFieldType = .cardNumber
                            },
                            onFieldStateChange: logFieldStateChange,
                            onChange: { _ in
                                onChangeReadout = "onChange: card number (opaque — not logged)"
                            },
                            trailingIcon: { scheme in
                                AnyView(merchantPanTrailingBrandView(for: scheme))
                            }
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // CVC component with proper theming
                        SPLTextField(
                            type: .cvc,
                            title: "Security Code (CVC)",
                            isRequired: true,
                            enableAutofill: enableAutofill,
                            theme: splLightTheme,
                            darkTheme: splDarkTheme,
                            onValidationChange: { valid in
                                cvcIsValid = valid
                                refreshAggregateValidationReadout()
                            },
                            onSubmit: {
                                handleFieldSubmit(for: .cvc)
                            },
                            submitLabel: getSubmitLabel(for: .cvc),
                            shouldFocus: focusedFieldType == .cvc,
                            onFocus: {
                                guard focusedFieldType != .cvc else { return }
                                focusedFieldType = .cvc
                            },
                            onFieldStateChange: logFieldStateChange,
                            onChange: { _ in
                                onChangeReadout = "onChange: CVC (opaque — not logged)"
                            }
                        )
                    }

                    FieldStateInspectorCardView(
                        store: fieldStateInspectorCoordinator.store,
                        aggregateValidationReadout: aggregateValidationReadout,
                        onChangeReadout: onChangeReadout,
                        cardBackgroundColor: cardBackgroundColor
                    )

                    if combinedExpiryDate {
                        VStack(alignment: .leading, spacing: 8) {
                            // Combined Expiry Date component with proper theming and forced 2-digit year format
                            SPLTextField(
                                type: .expirationDate,
                                title: "Expiry Date",
                                isRequired: !allowBlankDate,
                                enableAutofill: enableAutofill,
                                theme: splLightTheme,
                                darkTheme: splDarkTheme,
                                yearFormat: .twoDigit,
                                onValidationChange: { valid in
                                    expirationDateIsValid = valid
                                    refreshAggregateValidationReadout()
                                },
                                onSubmit: {
                                    handleFieldSubmit(for: .expirationDate)
                                },
                                submitLabel: getSubmitLabel(for: .expirationDate),
                                shouldFocus: focusedFieldType == .expirationDate,
                                onFocus: {
                                    guard focusedFieldType != .expirationDate else { return }
                                    focusedFieldType = .expirationDate
                                },
                                onChange: { value in
                                    logNonSensitiveFieldChange(.expirationDate, value: value)
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
                                    enableAutofill: enableAutofill,
                                    theme: splLightTheme,
                                    darkTheme: splDarkTheme,
                                    yearFormat: yearFormat,
                                    onValidationChange: { valid in
                                        expirationMonthIsValid = valid
                                        refreshAggregateValidationReadout()
                                    },
                                    onSubmit: {
                                        handleFieldSubmit(for: .expirationMonth)
                                    },
                                    submitLabel: getSubmitLabel(for: .expirationMonth),
                                    shouldFocus: focusedFieldType == .expirationMonth,
                                    onFocus: {
                                        guard focusedFieldType != .expirationMonth else { return }
                                        focusedFieldType = .expirationMonth
                                    },
                                    onChange: { value in
                                        logNonSensitiveFieldChange(.expirationMonth, value: value)
                                    }
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {

                                // Expiry Year component with year format
                                SPLTextField(
                                    type: .expirationYear,
                                    title: "Expiry Year",
                                    isRequired: !allowBlankDate,
                                    enableAutofill: enableAutofill,
                                    theme: splLightTheme,
                                    darkTheme: splDarkTheme,
                                    yearFormat: yearFormat,
                                    onValidationChange: { valid in
                                        expirationYearIsValid = valid
                                        refreshAggregateValidationReadout()
                                    },
                                    onSubmit: {
                                        handleFieldSubmit(for: .expirationYear)
                                    },
                                    submitLabel: getSubmitLabel(for: .expirationYear),
                                    shouldFocus: focusedFieldType == .expirationYear,
                                    onFocus: {
                                        guard focusedFieldType != .expirationYear else { return }
                                        focusedFieldType = .expirationYear
                                    },
                                    onChange: { value in
                                        logNonSensitiveFieldChange(.expirationYear, value: value)
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
            refreshAggregateValidationReadout()
            
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
    
    private func hostedFieldDisplayName(_ type: FormFieldType) -> String {
        switch type {
        case .cardNumber: return "Card number"
        case .fullName: return "Cardholder name"
        case .firstName: return "First name"
        case .lastName: return "Last name"
        case .expirationMonth: return "Expiry month"
        case .expirationYear: return "Expiry year"
        case .expirationDate: return "Expiry date"
        case .cvc: return "Security code (CVC)"
        case .addressLine1: return "Address line 1"
        case .addressLine2: return "Address line 2"
        case .city: return "City"
        case .state: return "State"
        case .zipCode: return "ZIP code"
        @unknown default: return "Field (\(type.rawValue))"
        }
    }

    private func hostedFieldEventDescription(_ event: HostedFieldEventType) -> String {
        switch event {
        case .input: return "INPUT"
        case .focus: return "FOCUS"
        case .blur: return "BLUR"
        case .validation: return "VALIDATION"
        case .panMaskChanged: return "PAN_MASK_CHANGED"
        @unknown default: return "UNKNOWN"
        }
    }

    private var parityFieldTypes: [FormFieldType] {
        var types: [FormFieldType] = [.fullName, .cardNumber, .cvc]
        if combinedExpiryDate {
            types.append(.expirationDate)
        } else {
            types.append(.expirationMonth)
            types.append(.expirationYear)
        }
        return types
    }

    private func logYesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private func cardNumberFormatLabel(_ format: CardNumberFormat) -> String {
        switch format {
        case .pretty: return "pretty"
        case .plain: return "plain"
        case .masked: return "masked"
        }
    }

    // MARK: - Theme configuration (CheckoutBasicView / CVVRecaching pattern)

    private var themeConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme Configuration:")
                .font(.headline)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.themeConfigurationTitle)
                .accessibilityLabel(AccessibilityLabels.CustomForm.themeConfigurationTitle)
                .accessibilityHint(AccessibilityHints.CustomForm.themeConfigurationTitle)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Toggle(
                    "Use Custom Theme",
                    isOn: Binding(
                        get: { useCustomTheme },
                        set: { newValue in
                            useCustomTheme = newValue
                            if !newValue {
                                lightTheme = nil
                                darkTheme = nil
                                selectedTheme = .default
                            }
                        }
                    )
                )
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.useCustomThemeToggle)
                .accessibilityHint(AccessibilityHints.CustomForm.useCustomThemeToggle)
            }

            HStack {
                Text("Current Theme:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Circle()
                    .fill(themeOptionSwatchColor(selectedTheme))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1))
                    .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.currentTheme)
                    .accessibilityLabel(selectedTheme.displayName)
            }
            .padding(.top, 4)

            if useCustomTheme {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick a color:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.customThemeColorsLabel)
                        .accessibilityLabel(AccessibilityLabels.CustomForm.customThemeColorsLabel)
                        .accessibilityHint(AccessibilityHints.CustomForm.customThemeColorsLabel)

                    HStack(spacing: 16) {
                        customFormThemeSwatch(option: .blue, swatchColor: .blue, apply: applyCustomFormBlueTheme)
                        customFormThemeSwatch(option: .green, swatchColor: .green, apply: applyCustomFormGreenTheme)
                        customFormThemeSwatch(option: .purple, swatchColor: .purple, apply: applyCustomFormPurpleTheme)
                    }

                    customFormResetThemeButton
                }
                .padding(.top, 4)
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
    }

    private func themeOptionSwatchColor(_ option: ThemeOption) -> Color {
        switch option {
        case .default: return Color.gray.opacity(0.45)
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        }
    }

    private func customFormThemeSwatch(
        option: ThemeOption,
        swatchColor: Color,
        apply: @escaping () -> Void
    ) -> some View {
        let isSelected = selectedTheme == option
        return Button(action: apply) {
            ZStack {
                Circle()
                    .fill(swatchColor)
                    .frame(width: 40, height: 40)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    .frame(width: 40, height: 40)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 3)
                        .frame(width: 46, height: 46)
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(themeSwatchAccessibilityId(for: option))
        .accessibilityLabel("\(option.displayName) theme color")
        .accessibilityHint(themeSwatchAccessibilityHint(for: option))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func themeSwatchAccessibilityId(for option: ThemeOption) -> String {
        switch option {
        case .blue: return AccessibilityIdentifiers.CustomForm.blueThemeButton
        case .green: return AccessibilityIdentifiers.CustomForm.greenThemeButton
        case .purple: return AccessibilityIdentifiers.CustomForm.purpleThemeButton
        case .default: return AccessibilityIdentifiers.CustomForm.resetThemeButton
        }
    }

    private func themeSwatchAccessibilityHint(for option: ThemeOption) -> String {
        switch option {
        case .blue: return AccessibilityHints.CustomForm.blueThemeButton
        case .green: return AccessibilityHints.CustomForm.greenThemeButton
        case .purple: return AccessibilityHints.CustomForm.purpleThemeButton
        case .default: return AccessibilityHints.CustomForm.resetThemeButton
        }
    }

    private func applyCustomFormBlueTheme() {
        lightTheme = SpreedlyThemeManager.createCustomTheme(
            colors: SpreedlyColors(
                primary: Color.blue,
                secondary: Color.blue.opacity(0.7),
                background: Color.white,
                surface: Color.white,
                text: Color.black,
                textSecondary: Color.gray,
                border: Color.blue.opacity(0.3),
                borderFocused: Color.blue,
                error: Color.red
            )
        )
        darkTheme = SpreedlyThemeManager.createCustomTheme(
            colors: SpreedlyColors(
                primary: Color.blue,
                secondary: Color.blue.opacity(0.7),
                background: Color.black,
                surface: Color(hex: "#1C1C1E"),
                text: Color.white,
                textSecondary: Color.gray.opacity(0.8),
                border: Color.blue.opacity(0.5),
                borderFocused: Color.blue,
                error: Color.red
            )
        )
        selectedTheme = .blue
    }

    private func applyCustomFormGreenTheme() {
        lightTheme = SpreedlyThemeManager.createCustomTheme(
            colors: SpreedlyColors(
                primary: Color.green,
                secondary: Color.green.opacity(0.7),
                background: Color.white,
                surface: Color.white,
                text: Color.black,
                textSecondary: Color.gray,
                border: Color.green.opacity(0.3),
                borderFocused: Color.green,
                error: Color.red
            )
        )
        darkTheme = SpreedlyThemeManager.createCustomTheme(
            colors: SpreedlyColors(
                primary: Color.green,
                secondary: Color.green.opacity(0.7),
                background: Color.black,
                surface: Color(hex: "#1C1C1E"),
                text: Color.white,
                textSecondary: Color.gray.opacity(0.8),
                border: Color.green.opacity(0.5),
                borderFocused: Color.green,
                error: Color.red
            )
        )
        selectedTheme = .green
    }

    private func applyCustomFormPurpleTheme() {
        lightTheme = SpreedlyThemeManager.createCustomTheme(
            colors: SpreedlyColors(
                primary: Color.purple,
                secondary: Color.purple.opacity(0.7),
                background: Color.white,
                surface: Color.white,
                text: Color.black,
                textSecondary: Color.gray,
                border: Color.purple.opacity(0.3),
                borderFocused: Color.purple,
                error: Color.red
            )
        )
        darkTheme = SpreedlyThemeManager.createCustomTheme(
            colors: SpreedlyColors(
                primary: Color.purple,
                secondary: Color.purple.opacity(0.7),
                background: Color.black,
                surface: Color(hex: "#1C1C1E"),
                text: Color.white,
                textSecondary: Color.gray.opacity(0.8),
                border: Color.purple.opacity(0.5),
                borderFocused: Color.purple,
                error: Color.red
            )
        )
        selectedTheme = .purple
    }

    private var customFormResetThemeButton: some View {
        Button("Reset to Default") {
            lightTheme = nil
            darkTheme = nil
            selectedTheme = .default
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
        .accessibilityIdentifier(AccessibilityIdentifiers.CustomForm.resetThemeButton)
        .accessibilityLabel("Reset to Default Theme")
        .accessibilityHint(AccessibilityHints.CustomForm.resetThemeButton)
    }

    @ViewBuilder
    private func merchantPanTrailingBrandView(for scheme: CardType) -> some View {
        switch scheme {
        case .visa:
            Image("visa_icon")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 24)
                .accessibilityLabel("Visa")
        case .mastercard, .mastercard2Series:
            merchantPanTrailingBrandPill(label: "MC")
        case .americanExpress:
            merchantPanTrailingBrandPill(label: "AMEX")
        case .discover:
            merchantPanTrailingBrandPill(label: "DISC")
        case .unknown:
            Text("")
        default:
            merchantPanTrailingBrandPill(label: merchantPanTrailingBrandFallbackLabel(for: scheme))
        }
    }

    @ViewBuilder
    private func merchantPanTrailingBrandPill(label: String) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .frame(width: 40, height: 24)
            .background(Color.accentColor.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel("Card brand \(label)")
    }

    private func merchantPanTrailingBrandFallbackLabel(for scheme: CardType) -> String {
        let raw = scheme.rawValue
        return raw
    }

    private func logFieldStateChange(_ state: HostedFieldState) {
        // Merchant pattern: drive mask UI from snapshot only — do not read hostedCardDisplayState here.
        // Updates are batched on the next main-queue turn so the form fields are not re-built per key.
        fieldStateInspectorCoordinator.store.ingest(state)
    }

    /// Local validity for the inspector readout — matches `isFormValid` / PAY button, stable field order.
    private func isFieldValidForInspector(_ type: FormFieldType) -> Bool {
        switch type {
        case .fullName: return fullNameIsValid
        case .cardNumber: return cardNumberIsValid
        case .cvc: return cvcIsValid
        case .expirationDate: return expirationDateIsValid
        case .expirationMonth: return expirationMonthIsValid
        case .expirationYear: return expirationYearIsValid
        default: return true
        }
    }

    private func refreshAggregateValidationReadout() {
        let fieldTypes = parityFieldTypes
        let allValid = isFormValid
        let invalid = fieldTypes.filter { !isFieldValidForInspector($0) }
        let registered = SpreedlyUIManager.shared.getRegisteredFieldCount()
        let invalidText = invalid.isEmpty
            ? "none"
            : invalid.map { hostedFieldDisplayName($0) }.joined(separator: ", ")
        let newReadout =
            "Form valid: \(logYesNo(allValid)) · invalid: \(invalidText) · registered: \(registered)"
        guard newReadout != aggregateValidationReadout else { return }
        aggregateValidationReadout = newReadout
    }

    private func performFullPaymentReset() {
        Spreedly.shared().resetPaymentState()
        fieldStateInspectorCoordinator.store.reset()
        aggregateValidationReadout = ""
        onChangeReadout = "onChange: edit a field to see values (card/CVC stay opaque)."
        cardNumberIsValid = false
        cvcIsValid = false
        expirationDateIsValid = false
        expirationMonthIsValid = false
        expirationYearIsValid = false
        fullNameIsValid = false
    }

    /// Logs non-sensitive field text for the onChange inspector (name, expiry — not PAN/CVV).
    private func logNonSensitiveFieldChange(_ fieldType: FormFieldType, value: String) {
        let label = hostedFieldDisplayName(fieldType)
        let display = value.isEmpty ? "(empty)" : value
        onChangeReadout = "onChange: \(label) = \"\(display)\""
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
                self.refreshAggregateValidationReadout()
                guard self.isFormValid else {
                    self.isLoading = false
                    self.errorMessage = "Fix invalid fields before paying."
                    return
                }

                // additionalFields can carry extra billing/shipping data (empty here; see CheckoutWithAdditionalFieldsView)
                let additionalFields: [AdditionalField: String] = [:]
                
                // createCreditCard reads card data from SecureValueContainer (populated by SPLTextField)
                let processingResult = Spreedly.shared().createCreditCard(
                    additionalFields: additionalFields,
                    metadata: [:],
                    eligibleForCardUpdater: eligibleForCardUpdater ? true : nil
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
        eligibleForCardUpdater = false
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

// MARK: - Field state inspector (isolated from payment fields — avoids re-rendering SPLTextField on each key)

/// Holds the inspector store without making `CustomFormView` observe `@Published` updates.
private final class FieldStateInspectorCoordinator {
    let store = FieldStateInspectorStore()
}

/// Batches `onFieldStateChange` and applies on the next main-queue turn so UITextField is not blocked.
private final class FieldStateInspectorStore: ObservableObject {
    struct Snapshot {
        var lastCardFieldState: HostedFieldState?
        var lastCvcFieldState: HostedFieldState?
        var eventLog: [String] = []
        var lastEventSummary: String = "Last event: —"
    }

    @Published private(set) var snapshot = Snapshot()

    private var pending: [HostedFieldState] = []
    private var flushScheduled = false

    private static let eventTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    func reset() {
        pending.removeAll(keepingCapacity: false)
        flushScheduled = false
        snapshot = Snapshot()
    }

    func ingest(_ state: HostedFieldState) {
        pending.append(state)
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushPending()
        }
    }

    private func flushPending() {
        flushScheduled = false
        guard !pending.isEmpty else { return }
        let batch = pending
        pending.removeAll(keepingCapacity: true)

        var next = snapshot
        for state in batch {
            switch state.fieldType {
            case .cardNumber:
                next.lastCardFieldState = Self.preferredInspectorSnapshot(
                    previous: next.lastCardFieldState,
                    incoming: state
                )
            case .cvc:
                next.lastCvcFieldState = Self.preferredInspectorSnapshot(
                    previous: next.lastCvcFieldState,
                    incoming: state
                )
            default:
                break
            }
            let fieldLabel = CustomFormInspectorFormatting.fieldDisplayName(state.fieldType)
            let event = CustomFormInspectorFormatting.eventDescription(state.eventType)
            let time = Self.eventTimeFormatter.string(from: Date())
            let line = "\(event) · \(fieldLabel) · \(time)"
            next.lastEventSummary = "Last event: \(line)"
            next.eventLog.insert(line, at: 0)
            if next.eventLog.count > 5 {
                next.eventLog.removeLast(next.eventLog.count - 5)
            }
        }
        snapshot = next
    }

    /// Post-sync programmatic INPUT can follow VALIDATION in the same batch; keep VALIDATION for the Event row.
    private static func preferredInspectorSnapshot(
        previous: HostedFieldState?,
        incoming: HostedFieldState
    ) -> HostedFieldState {
        guard incoming.eventType == .input,
              previous?.eventType == .validation,
              previous?.fieldType == incoming.fieldType else {
            return incoming
        }
        switch incoming.fieldType {
        case .cardNumber:
            if previous?.numberLength == incoming.numberLength {
                return previous!
            }
        case .cvc:
            if previous?.cvvLength == incoming.cvvLength {
                return previous!
            }
        default:
            break
        }
        return incoming
    }
}

private enum CustomFormInspectorFormatting {
    static func fieldDisplayName(_ type: FormFieldType) -> String {
        switch type {
        case .cardNumber: return "Card number"
        case .fullName: return "Cardholder name"
        case .firstName: return "First name"
        case .lastName: return "Last name"
        case .expirationMonth: return "Expiry month"
        case .expirationYear: return "Expiry year"
        case .expirationDate: return "Expiry date"
        case .cvc: return "Security code (CVC)"
        case .addressLine1: return "Address line 1"
        case .addressLine2: return "Address line 2"
        case .city: return "City"
        case .state: return "State"
        case .zipCode: return "ZIP code"
        @unknown default: return "Field (\(type.rawValue))"
        }
    }

    static func eventDescription(_ event: HostedFieldEventType) -> String {
        switch event {
        case .input: return "INPUT"
        case .focus: return "FOCUS"
        case .blur: return "BLUR"
        case .validation: return "VALIDATION"
        case .panMaskChanged: return "PAN_MASK_CHANGED"
        @unknown default: return "UNKNOWN"
        }
    }

    static func cardNumberFormatLabel(_ format: CardNumberFormat) -> String {
        switch format {
        case .pretty: return "pretty"
        case .plain: return "plain"
        case .masked: return "masked"
        }
    }

    static func logYesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }
}

private struct FieldStateInspectorCardView: View {
    @ObservedObject var store: FieldStateInspectorStore
    let aggregateValidationReadout: String
    let onChangeReadout: String
    let cardBackgroundColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Field state inspector")
                    .font(.headline)
                Text("Updates from onFieldStateChange. Use snapshot fields — not hostedCardDisplayState in the callback.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("PAN + CVC follow setNumberFormat / toggleMask (iframe parity)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("custom-form-wiring-readout")

            Text(store.snapshot.lastEventSummary)
                .font(.caption)
                .foregroundColor(
                    store.snapshot.lastEventSummary.contains("PAN_MASK_CHANGED") ? .orange : .secondary
                )
                .accessibilityIdentifier("custom-form-last-event-readout")

            DisclosureGroup("Event log (last 5)") {
                VStack(alignment: .leading, spacing: 4) {
                    if store.snapshot.eventLog.isEmpty {
                        Text("No events yet.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(store.snapshot.eventLog.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .font(.caption.weight(.semibold))
            .accessibilityIdentifier("custom-form-event-log")

            cardPanel
            cvcPanel

            VStack(alignment: .leading, spacing: 6) {
                if !aggregateValidationReadout.isEmpty {
                    Text(aggregateValidationReadout)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 36, alignment: .topLeading)
                        .animation(nil, value: aggregateValidationReadout)
                        .accessibilityIdentifier("custom-form-aggregate-validation-readout")
                }
                Text(onChangeReadout)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("custom-form-onchange-readout")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#EFEDEA"), lineWidth: 1)
        )
    }

    private var cardPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card number")
                .font(.subheadline.weight(.semibold))
            if let state = store.snapshot.lastCardFieldState {
                inspectorPanelContent(for: state, isCardNumber: true)
                    .accessibilityIdentifier("custom-form-field-state-inspector")
            } else {
                inspectorEmptyHint("Type a card number or change the format picker above.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var cvcPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CVC")
                .font(.subheadline.weight(.semibold))
            if let state = store.snapshot.lastCvcFieldState {
                inspectorPanelContent(for: state, isCardNumber: false)
                    .accessibilityIdentifier("custom-form-cvc-field-state-inspector")
            } else {
                inspectorEmptyHint("Type a security code. isPanMasked is not used on CVC events.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func inspectorPanelContent(for state: HostedFieldState, isCardNumber: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            inspectorRow(label: "Event", value: CustomFormInspectorFormatting.eventDescription(state.eventType))
            HStack(spacing: 16) {
                inspectorRow(label: "Valid", value: CustomFormInspectorFormatting.logYesNo(state.isValid), highlight: state.isValid)
                inspectorRow(label: "Focused", value: CustomFormInspectorFormatting.logYesNo(state.isFocused), highlight: state.isFocused)
                inspectorRow(label: "Empty", value: CustomFormInspectorFormatting.logYesNo(state.isEmpty), highlight: state.isEmpty)
            }
            if isCardNumber {
                Divider()
                Text("PAN display (from snapshot)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                HStack(alignment: .top, spacing: 12) {
                    inspectorRow(
                        label: "Format",
                        value: state.panDisplayFormat.map(CustomFormInspectorFormatting.cardNumberFormatLabel) ?? "—"
                    )
                    inspectorRow(
                        label: "Policy masked",
                        value: state.panDisplayPolicyMaskedValue.map(CustomFormInspectorFormatting.logYesNo) ?? "—",
                        highlight: state.panDisplayPolicyMaskedValue == true
                    )
                    inspectorRow(
                        label: "Digits hidden",
                        value: CustomFormInspectorFormatting.logYesNo(state.isPanMasked),
                        highlight: state.isPanMasked
                    )
                }
                HStack(spacing: 16) {
                    inspectorRow(
                        label: "Brand",
                        value: state.cardSchemeRawValue?.isEmpty == false ? (state.cardSchemeRawValue ?? "—") : "—"
                    )
                    inspectorRow(
                        label: "PAN digit count",
                        value: state.numberLength.map { String($0.intValue) } ?? "0"
                    )
                    inspectorRow(
                        label: "IIN",
                        value: state.iin ?? "—"
                    )
                }
            } else {
                inspectorRow(
                    label: "CVV digit count",
                    value: state.cvvLength.map { String($0.intValue) } ?? "0"
                )
            }
        }
    }

    private func inspectorRow(label: String, value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.weight(highlight ? .semibold : .regular))
                .foregroundColor(highlight ? .primary : .secondary)
        }
        .frame(minWidth: 72, alignment: .leading)
    }

    private func inspectorEmptyHint(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.secondary)
            .italic()
    }
}

#Preview {
    CustomFormView()
}
