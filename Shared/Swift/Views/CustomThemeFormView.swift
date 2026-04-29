import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI
import UIKit


struct CustomThemeFormView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isLoading: Bool = false
    @State private var paymentResult: PaymentResult?
    @State private var errorMessage: String?
    @State private var cancellable: AnyCancellable?
    
    // Validation states for SPLTextField components
    @State private var fullNameIsValid: Bool = false
    @State private var cardNumberIsValid: Bool = false
    @State private var expirationMonthIsValid: Bool = false
    @State private var expirationYearIsValid: Bool = false
    @State private var cvcIsValid: Bool = false
    
    // Focus management
    @State private var focusedFieldType: FormFieldType?
    
    private let errorHandler = Spreedly.shared().errorHandler
    
    // Configuration options
    @State private var allowBlankName: Bool = false
    @State private var allowExpiredDate: Bool = false
    @State private var allowBlankDate: Bool = false
    
    // Should retain state
    @State private var shouldRetain: Bool = false
    
    // Custom theme instances with accessibility refresh support
    @State private var lightTheme: SpreedlyTheme = createCustomSpreedlyLightTheme()
    @State private var darkTheme: SpreedlyTheme = createCustomSpreedlyDarkTheme()
    @State private var accessibilityObserver: NSObjectProtocol?
    @State private var appActiveObserver: NSObjectProtocol?
    
    // Computed property to select theme based on color scheme
    private var theme: SpreedlyTheme {
        colorScheme == .dark ? darkTheme : lightTheme
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg) {
                headerSection
                
                configurationToggles
                
                formSections
                
                saveCardCheckbox
                
                submitButton
                
                resultSections
                
                Spacer(minLength: theme.spacing.xl)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    theme.colors.background,
                    theme.colors.background.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationTitle("Custom Theme")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Device trust check handled internally by the SDK
            
            allowBlankName = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankName)
            allowExpiredDate = Spreedly.shared().paramsManager.getParam(parameter: .allowExpiredDate)
            allowBlankDate = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankDate)
            
            // Subscribe to payment results
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                paymentResult = result
                isLoading = false

                if result.isSuccess {
                    errorMessage = nil  // Clear any previous error
                    // Check if user wants to retain the payment method
                    if shouldRetain, let paymentMethodToken = result.token {
                        
                        // Call retain API asynchronously
                        Task {
                            await retainPaymentMethod(token: paymentMethodToken)
                        }
                    }
                    clearForm()
                } else if result.isFailure {
                    if let failureDetails = result.failureDetails {
                        errorMessage = failureDetails.getDescription()
                    } else {
                        errorMessage = "Payment failed"
                    }
                
                }
            }
        }
        .onAppear {
            setupAccessibilityObserver()
        }
        .onDisappear {
            // Cancel subscription when view disappears
            cancellable?.cancel()
            cancellable = nil
            ValidationParamReset.reset()
            
            // Clean up accessibility observers
            if let observer = accessibilityObserver {
                NotificationCenter.default.removeObserver(observer)
                accessibilityObserver = nil
            }
            if let observer = appActiveObserver {
                NotificationCenter.default.removeObserver(observer)
                appActiveObserver = nil
            }
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
    
    private var isFormValid: Bool {
        // Name validation: only required if allowBlankName is false
        let nameValid = fullNameIsValid
        
        // Card number and CVC validation: always required
        let cardValid = cardNumberIsValid && cvcIsValid
        
        // Expiration date validation: both month and year must be valid
        let expirationValid = expirationMonthIsValid && expirationYearIsValid
        
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
    
    // MARK: - Focus Management
    
    /// Get the ordered list of field types based on current configuration
    private var fieldOrder: [FormFieldType] {
        return [.fullName, .cardNumber, .expirationMonth, .expirationYear, .cvc]
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
    
    private func handleSubmit() {
        // Check if form is valid before proceeding
        guard isFormValid else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        paymentResult = nil  // Clear any previous success
        
        Task {
            let signatureGenerated = await isSignatureGenerated()
            if !signatureGenerated {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to generate signature. Please try again."
                    self.paymentResult = nil  // Clear any previous success
                }
                return
            }
            
            await MainActor.run {
                // Initiate the payment and get immediate processing result
                // SPLTextField handles name collection internally through secure value container
                
                // Example of using AdditionalField enum for additional fields (empty in this case)
                let additionalFields: [AdditionalField: String] = [:]
                
                let processingResult = Spreedly.shared().createCreditCard(
                    additionalFields: additionalFields,
                    metadata: [:]
                )
                
                // Handle immediate processing result
                if processingResult.isValidationFailed {
                    self.isLoading = false
                    self.errorMessage = "Validation failed: \(processingResult.getDescription())"
                    self.paymentResult = nil
                } else if processingResult.isProcessing {
                    // Keep loading state - actual result will come through the subscription
                    // Payment results will be handled by the onAppear subscription
                }
            }
        }
    }
    
    private func clearForm() {
        errorMessage = nil
        fullNameIsValid = false
        cardNumberIsValid = false
        expirationMonthIsValid = false
        expirationYearIsValid = false
        cvcIsValid = false
        shouldRetain = false
        // SPLTextField handles its own clearing through SpreedlyUIManager.shared.resetFields
    }
    
    private func setupAccessibilityObserver() {
        // Listen for content size category changes (when user changes font size while app is active)
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            refreshCustomThemes()
        }
        
        // Listen for app becoming active (when user changes settings while app is in background)
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            refreshCustomThemes()
        }
        
        // Listen for Bold Text accessibility setting changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            refreshCustomThemes()
        }
    }
    
    private func refreshCustomThemes() {
        // Refresh the light theme with current accessibility settings
        if let lightTheme = lightTheme as? SpreedlyCustomTheme {
            let refreshedTypography = lightTheme.typography.refreshed()
            let refreshedTheme = SpreedlyCustomTheme(
                colors: lightTheme.colors,
                typography: refreshedTypography,
                spacing: lightTheme.spacing,
                borderRadius: lightTheme.borderRadius,
                shadows: lightTheme.shadows
            )
            self.lightTheme = refreshedTheme
        }
        
        // Refresh the dark theme with current accessibility settings
        if let darkTheme = darkTheme as? SpreedlyCustomTheme {
            let refreshedTypography = darkTheme.typography.refreshed()
            let refreshedTheme = SpreedlyCustomTheme(
                colors: darkTheme.colors,
                typography: refreshedTypography,
                spacing: darkTheme.spacing,
                borderRadius: darkTheme.borderRadius,
                shadows: darkTheme.shadows
            )
            self.darkTheme = refreshedTheme
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: theme.spacing.sm) {
            Text("Custom Theme Payment")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.title)
                .accessibilityHint(AccessibilityHints.CustomTheme.title)
            
            Text("Experience our beautiful custom theme")
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.subtitle)
                .accessibilityHint(AccessibilityHints.CustomTheme.subtitle)
        }
        .padding(.top, theme.spacing.lg)
    }
    
    private var configurationToggles: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("Configuration Options")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.configurationTitle)
                .accessibilityLabel(AccessibilityLabels.CustomTheme.configurationTitle)
                .accessibilityHint(AccessibilityHints.CustomTheme.configurationTitle)
                .accessibilityAddTraits(.isHeader)
            
            blankNameToggle
            expiredDateToggle
            blankDateToggle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 4, x: 0, y: 0)
        .padding(.horizontal, theme.spacing.md)
    }
    
    private var blankNameToggle: some View {
        HStack {
            Toggle("Allow Blank Name", isOn: $allowBlankName)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.allowBlankNameToggle)
                .accessibilityHint(AccessibilityHints.CustomTheme.allowBlankNameToggle)
                .onChange(of: allowBlankName) { newValue in
                    Spreedly.shared().setParam(parameter: .allowBlankName, value: newValue)
                }
        }
    }
    
    private var expiredDateToggle: some View {
        HStack {
            Toggle("Allow Expired Date", isOn: $allowExpiredDate)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.allowExpiredDateToggle)
                .accessibilityHint(AccessibilityHints.CustomTheme.allowExpiredDateToggle)
                .onChange(of: allowExpiredDate) { newValue in
                    Spreedly.shared().setParam(parameter: .allowExpiredDate, value: newValue)
                }
        }
    }

    private var blankDateToggle: some View {
        HStack {
            Toggle("Allow Blank Date", isOn: $allowBlankDate)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.allowBlankDateToggle)
                .accessibilityHint(AccessibilityHints.CustomTheme.allowBlankDateToggle)
                .onChange(of: allowBlankDate) { newValue in
                    Spreedly.shared().setParam(parameter: .allowBlankDate, value: newValue)
                }
        }
    }
    
    private var formSections: some View {
        VStack(spacing: theme.spacing.lg) {
            personalInformationSection
            paymentInformationSection
        }
        .padding(.horizontal, theme.spacing.md)
    }
    
    private var personalInformationSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Personal Information")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
                .padding(.horizontal, theme.spacing.sm)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.personalInfoTitle)
                .accessibilityLabel(AccessibilityLabels.CustomTheme.personalInfoTitle)
                .accessibilityHint(AccessibilityHints.CustomTheme.personalInfoTitle)
                .accessibilityAddTraits(.isHeader)
            
            fullNameField
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 4, x: 0, y: 0)
    }
    
    private var fullNameField: some View {
        SPLTextField(
            type: .fullName,
            title: "Full Name",
            isRequired: !allowBlankName,
            theme: lightTheme,
            darkTheme: darkTheme,
            onValidationChange: { isValid in
                fullNameIsValid = isValid
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
    
    private var paymentInformationSection: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Payment Information")
                .font(theme.typography.titleFont)
                .foregroundColor(theme.colors.text)
                .padding(.horizontal, theme.spacing.sm)
                .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.paymentInfoTitle)
                .accessibilityLabel(AccessibilityLabels.CustomTheme.paymentInfoTitle)
                .accessibilityHint(AccessibilityHints.CustomTheme.paymentInfoTitle)
                .accessibilityAddTraits(.isHeader)
            
            cardNumberField
            expirationAndCvcFields
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 4, x: 0, y: 0)
    }
    
    private var cardNumberField: some View {
        SPLTextField(
            type: .cardNumber,
            title: "Card Number",
            isRequired: true,
            theme: lightTheme,
            darkTheme: darkTheme,
            onValidationChange: { isValid in
                cardNumberIsValid = isValid
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
    
    private var expirationAndCvcFields: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            expirationMonthField
            expirationYearField
            cvcField
        }
    }
    
    private var expirationMonthField: some View {
        SPLTextField(
            type: .expirationMonth,
            title: "Month",
            isRequired: !allowBlankDate,
            theme: lightTheme,
            darkTheme: darkTheme,
            onValidationChange: { isValid in
                expirationMonthIsValid = isValid
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
    
    private var expirationYearField: some View {
        SPLTextField(
            type: .expirationYear,
            title: "Year",
            isRequired: !allowBlankDate,
            theme: lightTheme,
            darkTheme: darkTheme,
            onValidationChange: { isValid in
                expirationYearIsValid = isValid
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
    }
    
    private var cvcField: some View {
        SPLTextField(
            type: .cvc,
            title: "CVC",
            isRequired: true,
            theme: lightTheme,
            darkTheme: darkTheme,
            onValidationChange: { isValid in
                cvcIsValid = isValid
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
    
    private var saveCardCheckbox: some View {
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
        .padding(.horizontal, theme.spacing.md)
        .padding(.top, theme.spacing.xs)
        .accessibility(identifier: "custom-theme-form-save-card-checkbox")
    }
    
    private var submitButton: some View {
        Button(action: handleSubmit) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isLoading ? "Processing..." : "PAY NOW")
                    .font(primaryButtonFont)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: theme.borderRadius.md)
                    .fill(isFormValid && !isLoading ? theme.colors.primary : theme.colors.primary.opacity(0.6))
                    .customShadow(theme.shadows.small)
            )
        }
        .disabled(!isFormValid || isLoading)
        .padding(.horizontal, theme.spacing.md)
        .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.payButton)
        .accessibilityHint(AccessibilityHints.CustomTheme.payButton)
    }
    
    private var resultSections: some View {
        VStack(spacing: theme.spacing.md) {
            if let result = paymentResult, result.isSuccess {
                successResultSection(result: result)
            }
            
            if let error = errorMessage {
                errorResultSection(error: error)
            }
        }
    }
    
    private func successResultSection(result: PaymentResult) -> some View {
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
        .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.successResultSection)
        .accessibilityHint(AccessibilityHints.CustomTheme.successResultSection)
    }
    
    private func errorResultSection(error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.colors.error)
            Text("Error: \(error)")
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.error)
        }
        .padding(theme.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: theme.borderRadius.md)
                .fill(theme.colors.error.opacity(0.1))
                .customShadow(theme.shadows.small)
        )
        .padding(.horizontal, theme.spacing.md)
        .accessibilityIdentifier(AccessibilityIdentifiers.CustomTheme.errorMessage)
        .accessibilityHint(AccessibilityHints.CustomTheme.errorMessage)
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
    NavigationView {
        CustomThemeFormView()
    }
} 

