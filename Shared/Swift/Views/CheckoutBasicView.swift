//
//  CheckoutBasicView.swift
//  SpreedlySDKExample
//
//  Created by Vinay Naikade on 02/07/25.
//

// =============================================================================
// KT OVERVIEW — CheckoutBasicView
// =============================================================================
// This view demonstrates the "Drop-In" approach to card payments.
// It uses CardFormDropIn — a pre-built SDK component that handles the entire
// card form (fields, validation, submission) inside a modal sheet.
//
// Flow:
//   1. User configures options (validation toggles, theme, year format)
//   2. User taps "Show Basic Checkout Form"
//   3. App generates an HMAC signature (required for Spreedly API auth)
//   4. CardFormDropIn is presented as a sheet (SDK handles everything inside)
//   5. App subscribes to payment results via Spreedly.shared().subscribeToPaymentResults
//   6. On success → shows token; on failure → shows error message
//
// KEY POINT: The app does NOT build the form itself — CardFormDropIn does it all.
// Compare with CustomFormView which builds the form field-by-field.
// =============================================================================

import SwiftUI
import Combine

import SpreedlyCore
import SpreedlyUI

// Step 1: ThemeOption enum — used by the theme picker buttons on this screen
enum ThemeOption: String, CaseIterable {
    case `default` = "Default"
    case blue = "Blue Theme"
    case green = "Green Theme"
    case purple = "Purple Theme"
    
    var displayName: String {
        return self.rawValue
    }
}

struct CheckoutBasicView: View {
    // Step 2: State variables — control what's shown and track payment lifecycle
    @State private var showForm = false                    // controls sheet presentation
    @State private var paymentResult: PaymentResult?       // holds successful payment result
    @State private var errorMessage: String?               // holds error string to display
    @State private var isLoading: Bool = false              // shows loading spinner while API calls run
    @State private var cancellable: AnyCancellable?        // Combine subscription for payment results
    @Environment(\.spreedlyTheme) private var theme        // reads the current Spreedly theme from SwiftUI environment
    @Environment(\.colorScheme) private var colorScheme    // light/dark mode detection
    
    // Step 3: Validation config — toggles that relax SDK validation rules
    @State private var allowBlankName: Bool = false         // if true, name fields can be empty
    @State private var allowExpiredDate: Bool = false       // if true, past expiry dates are accepted
    @State private var allowBlankDate: Bool = false         // if true, expiry fields can be empty
    @State private var yearFormat: YearFormat = .fourDigit  // .twoDigit = "YY", .fourDigit = "YYYY"
    @State private var nameDisplayMode: DropInNameDisplayMode = .separateFields  // .separateFields = first+last, .singleField = full name
    
    // Step 4: Theme config — allows user to pick a custom color theme for the card form
    @State private var useCustomTheme: Bool = false
    @State private var lightTheme: SpreedlyTheme?          // custom light-mode theme (nil = use SDK default)
    @State private var darkTheme: SpreedlyTheme?           // custom dark-mode theme (nil = use SDK default)
    @State private var selectedTheme: ThemeOption = .default
    
    // MARK: - Body (composed from subviews to avoid type-checker timeout)
    // Step 5: Main body — sheet modifier presents CardFormDropIn when showForm = true
    public var body: some View {
        mainScrollContent
            .sheet(isPresented: $showForm) { formSheet }
            .onAppear(perform: setupOnAppear)
            .onDisappear(perform: cleanupOnDisappear)
    }
    
    private var mainScrollContent: some View {
        ScrollView {
            ZStack {
                VStack(spacing: 20) {
                    headerSection
                    defaultFieldsCard
                    configurationOptionsCard
                    themeConfigurationCard
                    showFormButtonSection
                    if let result = paymentResult, result.isSuccess { successResultView(result) }
                    if let error = errorMessage { errorMessageView(error) }
                    Spacer(minLength: 20)
                }
                .padding()
                if isLoading { loadingOverlayView }
            }
        }
    }
    
    private var headerSection: some View {
        Group {
            Text("Basic Checkout Component")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.title)
                .accessibilityLabel(AccessibilityLabels.BasicCheckout.title)
                .accessibilityHint(AccessibilityHints.BasicCheckout.title)
                .accessibilityAddTraits(.isHeader)
            Text("This demonstrates the CardFormDropIn component with configurable name display modes and default fields.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.description)
                .accessibilityHint(AccessibilityHints.BasicCheckout.description)
        }
    }
    
    @ViewBuilder
    private var defaultFieldsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
                        Text("Default Fields:")
                            .font(.headline)
                            .accessibility(identifier: AccessibilityIdentifiers.BasicCheckout.defaultFieldsTitle)
                            .accessibility(label: Text(AccessibilityLabels.BasicCheckout.defaultFieldsTitle))
                            .accessibility(hint: Text(AccessibilityHints.BasicCheckout.defaultFieldsTitle))
                            .accessibility(addTraits: .isHeader)
                        
                        // Name fields (conditional based on display mode)
                        switch nameDisplayMode {
                        case .separateFields:
                            Group {
                                Text("• First Name")
                                    .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.firstNameFieldItem)
                                    .accessibilityLabel(AccessibilityLabels.BasicCheckout.firstNameFieldItem)
                                    .accessibilityHint(AccessibilityHints.BasicCheckout.firstNameFieldItem)
                                Text("• Last Name")
                                    .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.lastNameFieldItem)
                                    .accessibilityLabel(AccessibilityLabels.BasicCheckout.lastNameFieldItem)
                                    .accessibilityHint(AccessibilityHints.BasicCheckout.lastNameFieldItem)
                            }
                        case .singleField:
                            Text("• Full Name")
                                .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.fullNameFieldItem)
                                .accessibilityLabel(AccessibilityLabels.BasicCheckout.fullNameFieldItem)
                                .accessibilityHint(AccessibilityHints.BasicCheckout.fullNameFieldItem)
                        @unknown default:
                                fatalError()
                        }
                        
                        Text("• Card Number")
                            .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.cardNumberFieldItem)
                            .accessibilityLabel(AccessibilityLabels.BasicCheckout.cardNumberFieldItem)
                            .accessibilityHint(AccessibilityHints.BasicCheckout.cardNumberFieldItem)
                        
                        Text("• Expiry Month")
                            .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.expiryMonthFieldItem)
                            .accessibilityLabel(AccessibilityLabels.BasicCheckout.expiryMonthFieldItem)
                            .accessibilityHint(AccessibilityHints.BasicCheckout.expiryMonthFieldItem)
                        
                        Text("• Expiry Year")
                            .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.expiryYearFieldItem)
                            .accessibilityLabel(AccessibilityLabels.BasicCheckout.expiryYearFieldItem)
                            .accessibilityHint(AccessibilityHints.BasicCheckout.expiryYearFieldItem)
                        
                        Text("• CVC")
                            .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.cvcFieldItem)
                            .accessibilityLabel(AccessibilityLabels.BasicCheckout.cvcFieldItem)
                            .accessibilityHint(AccessibilityHints.BasicCheckout.cvcFieldItem)
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
    
    // Step: Config toggles — each toggle calls Spreedly.shared().setParam() to update SDK-level validation rules
    // These params affect how CardFormDropIn validates input (e.g., skip name validation if allowBlankName=true).
    private var configurationOptionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
                        Text("Configuration Options:")
                            .font(.headline)
                            .accessibility(identifier: AccessibilityIdentifiers.BasicCheckout.configurationTitle)
                            .accessibility(label: Text(AccessibilityLabels.BasicCheckout.configurationTitle))
                            .accessibility(hint: Text(AccessibilityHints.BasicCheckout.configurationTitle))
                            .accessibility(addTraits: .isHeader)
                        
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
                            .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.allowBlankNameToggle)
                            .accessibilityHint(AccessibilityHints.BasicCheckout.allowBlankNameToggle)
                            .accessibilityElement(children: .combine)
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
                            .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.allowExpiredDateToggle)
                            .accessibilityHint(AccessibilityHints.BasicCheckout.allowExpiredDateToggle)
                            .accessibilityElement(children: .combine)
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
                            .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.allowBlankDateToggle)
                            .accessibilityHint(AccessibilityHints.BasicCheckout.allowBlankDateToggle)
                            .accessibilityElement(children: .combine)
                        }
                        
                        HStack {
                            Text("Year Format:")
                                .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.yearFormatLabel)
                                .accessibilityLabel(AccessibilityLabels.BasicCheckout.yearFormatLabel)
                                .accessibilityHint(AccessibilityHints.BasicCheckout.yearFormatLabel)
                            
                            Picker("Year Format", selection: $yearFormat) {
                                Text("YY").tag(YearFormat.twoDigit)
                                    .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.yearFormatTwoDigit)
                                    .accessibilityLabel(AccessibilityLabels.BasicCheckout.yearFormatTwoDigit)
                                    .accessibilityHint(AccessibilityHints.BasicCheckout.yearFormatTwoDigit)
                                
                                Text("YYYY").tag(YearFormat.fourDigit)
                                    .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.yearFormatFourDigit)
                                    .accessibilityLabel(AccessibilityLabels.BasicCheckout.yearFormatFourDigit)
                                    .accessibilityHint(AccessibilityHints.BasicCheckout.yearFormatFourDigit)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        
                        HStack {
                            Text("Name Display Mode:")
                                .accessibilityIdentifier("basicCheckoutNameDisplayModeLabel")
                                .accessibilityLabel("Name Display Mode")
                                .accessibilityHint("Choose how to display name fields in the checkout form")
                            
                            Picker("Name Display Mode", selection: $nameDisplayMode) {
                                Text("Separate Fields").tag(DropInNameDisplayMode.separateFields)
                                    .accessibilityIdentifier("basicCheckoutNameDisplayModeSeparate")
                                    .accessibilityLabel("Separate Fields")
                                    .accessibilityHint("Display first name and last name as separate fields")
                                
                                Text("Single Field").tag(DropInNameDisplayMode.singleField)
                                    .accessibilityIdentifier("basicCheckoutNameDisplayModeSingle")
                                    .accessibilityLabel("Single Field")
                                    .accessibilityHint("Display name as a single full name field")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .accessibilityIdentifier("basicCheckoutNameDisplayModePicker")
                            .accessibilityLabel("Name Display Mode Picker")
                            .accessibilityHint("Select how to display name fields")
                        }
                    }
        .padding()
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 4, x: 0, y: 0)
    }
    
    // Step: Theme picker — creates a custom SpreedlyTheme using SpreedlyThemeManager.createCustomTheme()
    // Each button builds both a light and dark SpreedlyTheme with SpreedlyColors, then passes them to CardFormDropIn.
    private var themeConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
                        Text("Theme Configuration:")
                            .font(.headline)
                            .accessibilityIdentifier("basicCheckoutThemeTitle")
                            .accessibilityLabel("Theme Configuration")
                            .accessibilityHint("Configure custom theme for the checkout form")
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
                            .accessibilityIdentifier("basicCheckoutCustomThemeToggle")
                            .accessibilityHint("Toggle to use a custom theme for the checkout form")
                        }
                        
                        // Current theme indicator
                        HStack {
                            Text("Current Theme:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(selectedTheme.displayName)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(useCustomTheme ? .blue : .gray)
                                .accessibilityIdentifier("basicCheckoutCurrentTheme")
                        }
                        .padding(.top, 4)
                        
                        if useCustomTheme {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom Theme Colors:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack {
                                    Button("Blue Theme") {
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
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTheme == .blue ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedTheme == .blue ? Color.blue : Color.blue.opacity(0.3), lineWidth: selectedTheme == .blue ? 2 : 1)
                                    )
                                    .accessibilityIdentifier("basicCheckoutBlueThemeButton")
                                    .accessibilityLabel("Blue Theme")
                                    .accessibilityHint("Apply blue color theme to the checkout form")
                                    .accessibilityAddTraits(selectedTheme == .blue ? [.isButton, .isSelected] : .isButton)
                                    
                                    Button("Green Theme") {
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
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTheme == .green ? Color.green.opacity(0.2) : Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedTheme == .green ? Color.green : Color.green.opacity(0.3), lineWidth: selectedTheme == .green ? 2 : 1)
                                    )
                                    .accessibilityIdentifier("basicCheckoutGreenThemeButton")
                                    .accessibilityLabel("Green Theme")
                                    .accessibilityHint("Apply green color theme to the checkout form")
                                    .accessibilityAddTraits(selectedTheme == .green ? [.isButton, .isSelected] : .isButton)
                                    
                                    Button("Purple Theme") {
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
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTheme == .purple ? Color.purple.opacity(0.2) : Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedTheme == .purple ? Color.purple : Color.purple.opacity(0.3), lineWidth: selectedTheme == .purple ? 2 : 1)
                                    )
                                    .accessibilityIdentifier("basicCheckoutPurpleThemeButton")
                                    .accessibilityLabel("Purple Theme")
                                    .accessibilityHint("Apply purple color theme to the checkout form")
                                    .accessibilityAddTraits(selectedTheme == .purple ? [.isButton, .isSelected] : .isButton)
                                }
                                
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
                                .accessibilityIdentifier("basicCheckoutResetThemeButton")
                                .accessibilityLabel("Reset to Default Theme")
                                .accessibilityHint("Reset the checkout form to the default theme")
                            }
                            .padding(.top, 4)
                        }
                    }
        .padding()
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 4, x: 0, y: 0)
    }
    
    // Step 6: "Show Basic Checkout Form" button — generates HMAC signature, then opens the CardFormDropIn sheet
    private var showFormButtonSection: some View {
        Button("Show Basic Checkout Form") {
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
        .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.showFormButton)
        .accessibilityHint(AccessibilityHints.BasicCheckout.showFormButton)
    }
    
    private func successResultView(_ result: PaymentResult) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.colors.success)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.successIcon)
                    .accessibilityLabel(AccessibilityLabels.BasicCheckout.successIcon)
                    .accessibilityHint(AccessibilityHints.BasicCheckout.successIcon)
                    .accessibilityAddTraits(.isImage)
                Text("Payment Successful!")
                    .font(theme.typography.subtitleFont)
                    .foregroundColor(theme.colors.success)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.successTitle)
                    .accessibilityLabel(AccessibilityLabels.BasicCheckout.successTitle)
                    .accessibilityHint(AccessibilityHints.BasicCheckout.successTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            if let token = result.token {
                Text("Payment Token: \(Spreedly.maskedToken(token))")
                    .font(theme.typography.captionFont)
                    .foregroundColor(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.transactionTokenText)
                    .accessibilityLabel(AccessibilityLabels.BasicCheckout.transactionTokenText)
                    .accessibilityHint(AccessibilityHints.BasicCheckout.transactionTokenText)
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
    
    private func errorMessageView(_ error: String) -> some View {
        Text("Error: \(error)")
            .foregroundColor(.red)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.errorMessage)
            .accessibilityHint(AccessibilityHints.BasicCheckout.errorMessage)
    }
    
    private var loadingOverlayView: some View {
        ProgressView("Loading...")
            .progressViewStyle(CircularProgressViewStyle())
            .padding()
            .background(cardBackgroundColor.opacity(0.9))
            .cornerRadius(10)
            .shadow(radius: 10)
            .accessibilityIdentifier(AccessibilityIdentifiers.BasicCheckout.loadingProgressView)
            .accessibilityHint(AccessibilityHints.BasicCheckout.loadingProgressView)
    }
    
    // Step 7: CardFormDropIn — the SDK's pre-built card form presented as a sheet
    // Pass yearFormat, nameDisplayMode, and optional custom themes.
    // onProcessingResult fires immediately when user taps "Pay" (before API response).
    // .screenPrevention() blocks screenshots/screen recording for PCI compliance.
    private var formSheet: some View {
        CardFormDropIn(
            yearFormat: yearFormat,
            nameDisplayMode: nameDisplayMode,
            theme: useCustomTheme ? lightTheme : nil,
            darkTheme: useCustomTheme ? darkTheme : nil,
            onProcessingResult: { processingResult in
                if processingResult.isProcessing { isLoading = true }
            }
        ).screenPrevention()
    }
    
    // Step 8: setupOnAppear — syncs toggle states from SDK paramsManager and subscribes to payment results
    // subscribeToPaymentResults is the Combine-based callback that fires when Spreedly API responds.
    // This is where we handle success (show token, optionally retain) or failure (show error).
    private func setupOnAppear() {
        allowBlankName = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankName)
        allowExpiredDate = Spreedly.shared().paramsManager.getParam(parameter: .allowExpiredDate)
        allowBlankDate = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankDate)
        cancellable = Spreedly.shared().subscribeToPaymentResults { result in
            paymentResult = result
            isLoading = false
            if result.isSuccess {
                errorMessage = nil
                showForm = false
                // If "Save card" was checked, retain the payment method for future use
                if result.shouldRetain, let paymentMethodToken = result.token {
                    Task { await retainPaymentMethod(token: paymentMethodToken) }
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
    
    // Step 9: Cleanup — cancel the Combine subscription and reset validation params when leaving the screen
    private func cleanupOnDisappear() {
        cancellable?.cancel()
        cancellable = nil
        ValidationParamReset.reset()
    }
    
    // Step 10: Retain — calls Spreedly API to save the card token for future charges
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
    CheckoutBasicView()
}
