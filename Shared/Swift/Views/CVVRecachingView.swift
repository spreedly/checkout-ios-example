//
//  CVVRecachingView.swift
//  SpreedlySDKExample
//
//  Created on 02/07/25.
//

import Combine
import SpreedlyCore
import SpreedlyUI
import SwiftUI

// MARK: - CVV Recaching View
struct CVVRecachingView: View {
    @Environment(\.spreedlyTheme) private var environmentTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedCard: SavedCard?
    @State private var showCVVRecachingView: Bool = false

    // MARK: - Configuration State
    // Customize CVV recaching UI appearance and behavior
    @State private var presentationMode: ScreenPresentationMode = .bottomSheet
    @State private var labelText: String = "CVV"
    @State private var placeholderText: String = "123"
    @State private var buttonText: String = "Confirm"
    @State private var cancelButtonText: String = "Cancel"
    @State private var allowBlankName: Bool = false
    @State private var allowExpiredDate: Bool = false
    @State private var allowBlankDate: Bool = false

    // MARK: - Theme Configuration State
    // Supports separate light/dark themes that switch based on device color scheme
    @State private var useCustomTheme: Bool = false
    @State private var lightTheme: SpreedlyTheme?
    @State private var darkTheme: SpreedlyTheme?
    @State private var selectedTheme: ThemeOption = .default

    // MARK: - Payment Result State
    @State private var paymentResult: PaymentResult?
    @State private var recacheCancellable: AnyCancellable?
    @State private var paymentCancellable: AnyCancellable?
    
    // MARK: - Payment Methods Loading State
    @State private var isLoadingCards: Bool = false

    // MARK: - Computed Properties
    // Selects theme based on color scheme: custom if enabled, otherwise environment theme
    private var theme: SpreedlyTheme {
        if useCustomTheme {
            return colorScheme == .dark
                ? (darkTheme ?? environmentTheme)
                : (lightTheme ?? environmentTheme)
        }
        return environmentTheme
    }

    // MARK: - Saved Cards State
    // Fetched from API
    @State private var savedCards: [SavedCard] = []

    public var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                            .id("header")
                        informationSection
                            .id("information")
                        configurationSection
                            .id("configuration")
                        themeConfigurationSection
                            .id("theme")

                        // Inline saved cards list so we can access `proxy` directly
                        savedCardsListSection(proxy: proxy)
                            .id("cards")

                        recacheButton
                            .id("recacheButton")
                        
                        if let result = paymentResult, result.isSuccess {
                            MessageView.success(
                                title: "CVV Recached Successfully!",
                                message: "Your payment method has been updated.",
                                additionalContent: {
                                    if let token = result.token {
                                        return AnyView(
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Updated Token: \(Spreedly.maskedToken(token))")
                                                    .font(theme.typography.captionFont)
                                                    .foregroundColor(theme.colors.textSecondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .accessibilityIdentifier(AccessibilityIdentifiers.CVVRecaching.updatedTokenText)
                                                    .accessibilityLabel(AccessibilityLabels.CVVRecaching.updatedTokenText)
                                                    .accessibilityHint(AccessibilityHints.CVVRecaching.updatedTokenText)
                                                if let updatedAt = result.paymentMethodUpdatedAt {
                                                    Text("Updated At: \(updatedAt)")
                                                        .font(theme.typography.captionFont)
                                                        .foregroundColor(theme.colors.textSecondary)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                }
                                            }
                                        )
                                    } else {
                                        return AnyView(EmptyView())
                                    }
                                },
                                iconAccessibilityIdentifier: AccessibilityIdentifiers.CVVRecaching.successIcon,
                                iconAccessibilityLabel: AccessibilityLabels.CVVRecaching.successIcon,
                                iconAccessibilityHint: AccessibilityHints.CVVRecaching.successIcon,
                                titleAccessibilityIdentifier: AccessibilityIdentifiers.CVVRecaching.successTitle,
                                titleAccessibilityLabel: AccessibilityLabels.CVVRecaching.successTitle,
                                titleAccessibilityHint: AccessibilityHints.CVVRecaching.successTitle
                            )
                        }
                        
                        errorMessageView
                            .id("error")
                    }
                    .padding()
                }
                
                // Loading overlay - same pattern as CheckoutBasicView
                if isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                        .background(cardBackgroundColor.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                        .accessibilityIdentifier(AccessibilityIdentifiers.CVVRecaching.loadingState)
                        .accessibilityHint(AccessibilityHints.CVVRecaching.loadingState)
                }
            }
            .navigationTitle("CVV Recaching")
            .navigationBarTitleDisplayMode(.inline)
            // MARK: - CVV Recaching Component
            // Use .sheet() for sheet mode or .crossDissolveFullScreenCover() for alert mode
            // Component handles CVV collection, validation, and API communication
            .sheet(
                isPresented: Binding(
                    get: {
                        showCVVRecachingView
                        && recacheConfig != nil
                        && recacheConfig?.recachePresentationMode == .bottomSheet
                    },
                    set: { showCVVRecachingView = $0 }
                )
            ) {
                if let config = recacheConfig {
                    SpreedlyCVVRecachingView(
                        config: config,
                        paymentMethodToken: selectedCard?.paymentMethodToken ?? "",
                        theme: useCustomTheme ? lightTheme : nil,
                        darkTheme: useCustomTheme ? darkTheme : nil,
                        allowBlankName: allowBlankName,
                        allowExpiredDate: allowExpiredDate,
                        allowBlankDate: allowBlankDate,
                        onProcessingResult: { processingResult in
                            // Called during recaching: isProcessing = request started, isValidationFailed = validation error
                            // Final success/failure comes via recache result subscription
                            if processingResult.isProcessing {
                                isLoading = true
                            } else if processingResult.isValidationFailed {
                                errorMessage = "CVV validation failed"
                                isLoading = false
                            }
                        },
                        onDismiss: {
                            // Called when Cancel button is tapped - merchant handles dismissal
                            showCVVRecachingView = false
                        }
                    )
                }
            }
            // Show Recache CVV UI as FullScreen (Alert mode)
            .crossDissolveFullScreenCover(
                isPresented: Binding(
                    get: {
                        showCVVRecachingView
                        && recacheConfig != nil
                        && recacheConfig?.recachePresentationMode == .dialog
                    },
                    set: { showCVVRecachingView = $0 }
                )
            ) {
                if let config = recacheConfig {
                    SpreedlyCVVRecachingView(
                        config: config,
                        paymentMethodToken: selectedCard?.paymentMethodToken ?? "",
                        theme: useCustomTheme ? lightTheme : nil,
                        darkTheme: useCustomTheme ? darkTheme : nil,
                        allowBlankName: allowBlankName,
                        allowExpiredDate: allowExpiredDate,
                        allowBlankDate: allowBlankDate,
                        onProcessingResult: { processingResult in
                            // Called during recaching: isProcessing = request started, isValidationFailed = validation error
                            // Final success/failure comes via recache result subscription
                            if processingResult.isProcessing {
                                isLoading = true
                            } else if processingResult.isValidationFailed {
                                errorMessage = "CVV validation failed"
                                isLoading = false
                            }
                        },
                        onDismiss: {
                            // Called when Cancel button is tapped - merchant handles dismissal
                            showCVVRecachingView = false
                        }
                    )
                }
            }
            .onAppear {
                recacheCancellable = Spreedly.shared().subscribeToRecacheResults { result in
                    paymentResult = result
                    isLoading = false
                    if result.isSuccess {
                        errorMessage = nil
                        showCVVRecachingView = false
                    } else if result.isFailure {
                        // Failure: handle error (common causes: invalid CVV, network error, expired token)
                        if let failureDetails = result.failureDetails {
                            errorMessage = failureDetails.getDescription()
                        } else {
                            errorMessage = "CVV Recaching failed"
                        }
                        paymentResult = nil
                        isLoading = false
                        showCVVRecachingView = false
                    }
                }

                // Blocked-device recache failures publish on the payment channel, not recache.
                paymentCancellable = Spreedly.shared().subscribeToPaymentResults { result in
                    guard result.isFailure else { return }
                    paymentResult = result
                    isLoading = false
                    showCVVRecachingView = false
                    if let failureDetails = result.failureDetails {
                        errorMessage = failureDetails.getDescription()
                    } else {
                        errorMessage = "Recache blocked or payment failed"
                    }
                }

                // Fetch payment methods on view appear
                fetchPaymentMethods()
            }
            .onDisappear {
                recacheCancellable?.cancel()
                recacheCancellable = nil
                paymentCancellable?.cancel()
                paymentCancellable = nil
                ValidationParamReset.reset()
            }
        }
    }

    // MARK: - View Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("CVV Recaching")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.title
                )
                .accessibilityLabel(AccessibilityLabels.CVVRecaching.title)
                .accessibilityHint(AccessibilityHints.CVVRecaching.title)
                .accessibilityAddTraits(.isHeader)

            Text(
                "Update CVV for saved payment methods to enable repeat transactions"
            )
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .accessibilityIdentifier(
                AccessibilityIdentifiers.CVVRecaching.description
            )
            .accessibilityHint(AccessibilityHints.CVVRecaching.description)
        }
        .padding(.top)
    }

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About CVV Recaching:")
                .font(.headline)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.aboutTitle
                )
                .accessibilityLabel(AccessibilityLabels.CVVRecaching.aboutTitle)
                .accessibilityHint(AccessibilityHints.CVVRecaching.aboutTitle)
                .accessibilityAddTraits(.isHeader)

            // CVV recaching flow:
            // 1. CVV values cannot be stored (PCI compliance)
            // 2. Customer must re-enter CVV for saved cards
            // 3. SDK provides secure UI for CVV collection
            // 4. After recaching, token is updated and ready for transactions
            VStack(alignment: .leading, spacing: 4) {
                Text("• CVV values cannot be stored for security compliance")
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(
                        AccessibilityIdentifiers.CVVRecaching.aboutBulletPoint1
                    )
                    .accessibilityLabel(
                        AccessibilityLabels.CVVRecaching.aboutBulletPoint1
                    )
                    .accessibilityHint(
                        AccessibilityHints.CVVRecaching.aboutBulletPoint1
                    )
                Text("• Recaching updates the CVV for saved payment methods")
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(
                        AccessibilityIdentifiers.CVVRecaching.aboutBulletPoint2
                    )
                    .accessibilityLabel(
                        AccessibilityLabels.CVVRecaching.aboutBulletPoint2
                    )
                    .accessibilityHint(
                        AccessibilityHints.CVVRecaching.aboutBulletPoint2
                    )
                Text("• SDK provides secure UI for CVV entry")
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(
                        AccessibilityIdentifiers.CVVRecaching.aboutBulletPoint3
                    )
                    .accessibilityLabel(
                        AccessibilityLabels.CVVRecaching.aboutBulletPoint3
                    )
                    .accessibilityHint(
                        AccessibilityHints.CVVRecaching.aboutBulletPoint3
                    )
                Text("• Updated payment method can be used for transactions")
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(
                        AccessibilityIdentifiers.CVVRecaching.aboutBulletPoint4
                    )
                    .accessibilityLabel(
                        AccessibilityLabels.CVVRecaching.aboutBulletPoint4
                    )
                    .accessibilityHint(
                        AccessibilityHints.CVVRecaching.aboutBulletPoint4
                    )
            }
            .font(.system(size: 15))
            .foregroundColor(.secondary)
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

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration Options:")
                .font(.headline)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.configurationTitle
                )
                .accessibilityLabel(
                    AccessibilityLabels.CVVRecaching.configurationTitle
                )
                .accessibilityHint(
                    AccessibilityHints.CVVRecaching.configurationTitle
                )
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 12) {
                presentationModePicker
                labelTextField
                placeholderTextField
                buttonTextField
                cancelButtonTextField
                recacheOptionsToggles
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

    private var presentationModePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Presentation Mode:")
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.presentationModeLabel
                )

            Picker("Presentation Mode", selection: $presentationMode) {
                Text("Sheet").tag(ScreenPresentationMode.bottomSheet)
                    .accessibilityIdentifier(
                        AccessibilityIdentifiers.CVVRecaching
                            .presentationModeSheet
                    )

                Text("Alert").tag(ScreenPresentationMode.dialog)
                    .accessibilityIdentifier(
                        AccessibilityIdentifiers.CVVRecaching
                            .presentationModeAlert
                    )
            }
            .pickerStyle(SegmentedPickerStyle())
            .accessibilityIdentifier(
                AccessibilityIdentifiers.CVVRecaching.presentationModePicker
            )
        }
    }

    private var labelTextField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Label Text:")
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.labelTextLabel
                )

            TextField("CVV", text: $labelText)
                .font(configurationTextFieldFont)
                .foregroundColor(textFieldTextColor)
                .padding(12)
                .background(textFieldBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(textFieldBorderColor, lineWidth: 1)
                )
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.labelTextField
                )
        }
    }

    private var placeholderTextField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Placeholder Text:")
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.placeholderTextLabel
                )

            TextField("123", text: $placeholderText)
                .font(configurationTextFieldFont)
                .foregroundColor(textFieldTextColor)
                .padding(12)
                .background(textFieldBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(textFieldBorderColor, lineWidth: 1)
                )
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.placeholderTextField
                )
        }
    }

    private var buttonTextField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Button Text:")
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.buttonTextLabel
                )

            TextField("Confirm", text: $buttonText)
                .font(configurationTextFieldFont)
                .foregroundColor(textFieldTextColor)
                .padding(12)
                .background(textFieldBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(textFieldBorderColor, lineWidth: 1)
                )
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.buttonTextField
                )
        }
    }

    private var cancelButtonTextField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cancel Button Text:")
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.cancelButtonTextLabel
                )

            TextField("Cancel", text: $cancelButtonText)
                .font(configurationTextFieldFont)
                .foregroundColor(textFieldTextColor)
                .padding(12)
                .background(textFieldBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(textFieldBorderColor, lineWidth: 1)
                )
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.cancelButtonTextField
                )
        }
    }

    private var recacheOptionsToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Allow Blank Name", isOn: $allowBlankName)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.allowBlankNameToggle
                )
                .accessibilityLabel(
                    AccessibilityLabels.CVVRecaching.allowBlankNameToggle
                )
                .accessibilityHint(
                    AccessibilityHints.CVVRecaching.allowBlankNameToggle
                )

            Toggle("Allow Expired Date", isOn: $allowExpiredDate)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.allowExpiredDateToggle
                )
                .accessibilityLabel(
                    AccessibilityLabels.CVVRecaching.allowExpiredDateToggle
                )
                .accessibilityHint(
                    AccessibilityHints.CVVRecaching.allowExpiredDateToggle
                )

            Toggle("Allow Blank Date", isOn: $allowBlankDate)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.allowBlankDateToggle
                )
                .accessibilityLabel(
                    AccessibilityLabels.CVVRecaching.allowBlankDateToggle
                )
                .accessibilityHint(
                    AccessibilityHints.CVVRecaching.allowBlankDateToggle
                )
        }
    }

    private var themeConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme Configuration:")
                .font(.headline)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching
                        .themeConfigurationTitle
                )
                .accessibilityLabel(
                    AccessibilityLabels.CVVRecaching.themeConfigurationTitle
                )
                .accessibilityHint(
                    AccessibilityHints.CVVRecaching.themeConfigurationTitle
                )
                .accessibilityAddTraits(.isHeader)

            themeToggle
            currentThemeIndicator

            if useCustomTheme {
                customThemeButtons
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

    private var themeToggle: some View {
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
            .accessibilityIdentifier(
                AccessibilityIdentifiers.CVVRecaching.useCustomThemeToggle
            )
            .accessibilityHint(
                AccessibilityHints.CVVRecaching.useCustomThemeToggle
            )
        }
    }

    private var currentThemeIndicator: some View {
        HStack {
            Text("Current Theme:")
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.currentThemeLabel
                )
                .accessibilityLabel(
                    AccessibilityLabels.CVVRecaching.currentThemeLabel
                )
                .accessibilityHint(
                    AccessibilityHints.CVVRecaching.currentThemeLabel
                )

            Text(selectedTheme.displayName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(useCustomTheme ? .blue : .gray)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.currentTheme
                )
        }
        .padding(.top, 4)
    }

    private var customThemeButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Theme Colors:")
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.customThemeColorsLabel
                )
                .accessibilityLabel(
                    AccessibilityLabels.CVVRecaching.customThemeColorsLabel
                )
                .accessibilityHint(
                    AccessibilityHints.CVVRecaching.customThemeColorsLabel
                )

            HStack {
                blueThemeButton
                greenThemeButton
                purpleThemeButton
            }

            resetThemeButton
        }
        .padding(.top, 4)
    }

    private var blueThemeButton: some View {
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
        .background(
            selectedTheme == .blue
                ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)
        )
        .foregroundColor(.blue)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    selectedTheme == .blue
                        ? Color.blue : Color.blue.opacity(0.3),
                    lineWidth: selectedTheme == .blue ? 2 : 1
                )
        )
        .accessibilityIdentifier(
            AccessibilityIdentifiers.CVVRecaching.blueThemeButton
        )
        .accessibilityLabel("Blue Theme")
        .accessibilityHint(AccessibilityHints.CVVRecaching.blueThemeButton)
        .accessibilityAddTraits(selectedTheme == .blue ? [.isButton, .isSelected] : .isButton)
    }

    private var greenThemeButton: some View {
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
        .background(
            selectedTheme == .green
                ? Color.green.opacity(0.2) : Color.green.opacity(0.1)
        )
        .foregroundColor(.green)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    selectedTheme == .green
                        ? Color.green : Color.green.opacity(0.3),
                    lineWidth: selectedTheme == .green ? 2 : 1
                )
        )
        .accessibilityIdentifier(
            AccessibilityIdentifiers.CVVRecaching.greenThemeButton
        )
        .accessibilityLabel("Green Theme")
        .accessibilityHint(AccessibilityHints.CVVRecaching.greenThemeButton)
        .accessibilityAddTraits(selectedTheme == .green ? [.isButton, .isSelected] : .isButton)
    }

    private var purpleThemeButton: some View {
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
        .background(
            selectedTheme == .purple
                ? Color.purple.opacity(0.2) : Color.purple.opacity(0.1)
        )
        .foregroundColor(.purple)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    selectedTheme == .purple
                        ? Color.purple : Color.purple.opacity(0.3),
                    lineWidth: selectedTheme == .purple ? 2 : 1
                )
        )
        .accessibilityIdentifier(
            AccessibilityIdentifiers.CVVRecaching.purpleThemeButton
        )
        .accessibilityLabel("Purple Theme")
        .accessibilityHint(AccessibilityHints.CVVRecaching.purpleThemeButton)
        .accessibilityAddTraits(selectedTheme == .purple ? [.isButton, .isSelected] : .isButton)
    }

    private var resetThemeButton: some View {
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
        .accessibilityIdentifier(
            AccessibilityIdentifiers.CVVRecaching.resetThemeButton
        )
        .accessibilityLabel("Reset to Default Theme")
        .accessibilityHint("Reset the CVV recaching dialog to the default theme")
    }

    /// Saved cards list section is now a function so we can pass the ScrollViewProxy
    private func savedCardsListSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Payment Methods")
                .font(.headline)
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.cardsListTitle
                )
                .accessibilityLabel(
                    AccessibilityLabels.CVVRecaching.cardsListTitle
                )
                .accessibilityHint(
                    AccessibilityHints.CVVRecaching.cardsListTitle
                )
                .accessibilityAddTraits(.isHeader)

            if isLoadingCards {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .accessibilityIdentifier(
                    AccessibilityIdentifiers.CVVRecaching.loadingState
                )
                .accessibilityLabel(
                    AccessibilityLabels.CVVRecaching.loadingState
                )
                .accessibilityHint(
                    AccessibilityHints.CVVRecaching.loadingState
                )
            } else if savedCards.isEmpty {
                Text("No saved payment methods")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(
                        AccessibilityIdentifiers.CVVRecaching.emptyState
                    )
                    .accessibilityHint(
                        AccessibilityHints.CVVRecaching.emptyState
                    )
            } else {
                ForEach(Array(savedCards.prefix(3))) { card in
                    CardRowView(
                        card: card,
                        isSelected: selectedCard?.id == card.id,
                        onSelect: { /* left empty; handled by onTapGesture below */

                            // Ensure the layout/update occurs, then scroll to the selected card.
                            // Using async ensures we don't race with SwiftUI layout.
                            if selectedCard == nil {
                                DispatchQueue.main.async {
                                    // Use .center or .top depending on your preference
                                    proxy.scrollTo(
                                        "recacheButton",
                                        anchor: .top
                                    )
                                }
                            }
                            // Select the card
                            selectedCard = card
                        }
                    )
                    .id(card.id)  // important: give each row its own id
                    .accessibilityIdentifier(
                        "\(AccessibilityIdentifiers.CVVRecaching.cardRow)_\(card.id)"
                    )
                }
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

    private var recacheButton: some View {
        Button(action: {
            guard Spreedly.isDeviceTrusted else {
                errorMessage = "Device integrity check failed. Recache is not available on this device."
                return
            }
            errorMessage = nil
            isLoading = true
            // Generate signature for Spreedly configuration before showing recaching UI
            Task {
                let signatureGenerated = await SpreedlyConfigManager.shared.generateSignature()
                await MainActor.run {
                    isLoading = false
                    switch signatureGenerated {
                    case .success(_):
                        showCVVRecachingView = true
                    case .failure(let error):
                        errorMessage = "Failed to generate signature: \(error.localizedDescription)"
                    }
                }
            }
        }) {
            Text("Recache CVV")
                .font(primaryButtonFont)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background((isLoading || selectedCard == nil) ? theme.colors.primary.opacity(0.6) : theme.colors.primary)
                .cornerRadius(8)
        }
        .disabled(isLoading || selectedCard == nil)
        .frame(minHeight: 0)
        .padding(.horizontal)
        .accessibilityIdentifier(
            AccessibilityIdentifiers.CVVRecaching.recacheButton
        )
        .accessibilityLabel(AccessibilityLabels.CVVRecaching.recacheButton)
        .accessibilityHint(AccessibilityHints.CVVRecaching.recacheButton)
        .accessibilityHidden(selectedCard == nil)

    }

    private var errorMessageView: some View {
        Group {
            if let error = errorMessage {
                MessageView.error(
                    message: error,
                    messageAccessibilityIdentifier: AccessibilityIdentifiers.CVVRecaching.errorMessage,
                    messageAccessibilityHint: AccessibilityHints.CVVRecaching.errorMessage
                )
            } else {
                // Empty view to maintain layout stability
                Color.clear
                    .frame(height: 0)
            }
        }
    }


    /// Creates RecacheConfig from selected card and UI configuration.
    /// Returns nil if no card selected (prevents modifier from activating).
    private var recacheConfig: RecacheConfig? {
        guard let card = selectedCard else {
            return nil
        }

        // Create SavedCardInfo to display card details
        let cardInfo = SavedCardInfo(
            lastFourDigits: card.lastFourDigits,
            cardType: card.cardType,
            cardBrand: card.cardBrand
        )

        return RecacheConfig(
            cardInfo: cardInfo,
            presentationMode: presentationMode == .bottomSheet ? .bottomSheet : .dialog,
            labelText: labelText,
            placeholderText: placeholderText,
            buttonText: buttonText,
            cancelButtonText: cancelButtonText
        )
    }

    // MARK: - API Methods
    
    /// Fetches payment methods from the API and converts them to SavedCard models
    private func fetchPaymentMethods() {
        isLoadingCards = true
        errorMessage = nil
        
        Task {
            do {
                let client = SpreedlyConfigManager.shared.createFetchPaymentMethodsAPIClient()
                let response = try await client.fetchPaymentMethods()
                
                // Convert PaymentMethod to SavedCard, filtering only credit cards
                let cards = response.paymentMethods?
                    .filter { $0.paymentMethodType == "credit_card" }
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
                    savedCards = cards ?? []
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
    
    // MARK: - Computed Properties
    
    // Configuration text field font: Poppins, 16px, regular weight
    private var configurationTextFieldFont: Font {
        if let poppins = UIFont(name: "Poppins", size: 16) {
            return Font(poppins)
        } else if let poppinsRegular = UIFont(name: "Poppins-Regular", size: 16) {
            return Font(poppinsRegular)
        } else {
            // Fallback to system font
            return Font.system(size: 16)
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
    
    private var textFieldBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#2C2C2E") : Color(hex: "#FFFFFF")
    }
    
    private var textFieldTextColor: Color {
        colorScheme == .dark ? Color(hex: "#FFFFFF") : Color(hex: "#545859")
    }
    
    private var textFieldBorderColor: Color {
        colorScheme == .dark ? Color(hex: "#48484A") : Color(hex: "#D1D5DB")
    }
}

// MARK: - Card Row View
struct CardRowView: View {
    let card: SavedCard
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Card Icon/Indicator
            Image(systemName: "creditcard.fill")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let month = card.expiryMonth, let year = card.expiryYear {
                    Text("Expires: \(month)/\(year)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Selection Indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
        .accessibilityIdentifier(
            "\(AccessibilityIdentifiers.CVVRecaching.cardRow)_\(card.id)"
        )
        .accessibilityLabel(
            "\(card.displayName), expires \(card.expiryMonth ?? "")/\(card.expiryYear ?? "")"
        )
        .accessibilityHint("Tap to select this card for CVV recaching")
        .accessibilityAddTraits(
            isSelected ? [.isButton, .isSelected] : .isButton
        )
    }
}

#Preview {
    CVVRecachingView()
}
