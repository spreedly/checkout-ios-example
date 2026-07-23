//
//  BankAccountCheckoutView.swift
//  SpreedlySDKExample
//
//  Demonstrates the SDK's pre-built `BankAccountFormDropIn` for ACH bank-account
//  tokenization. Mirrors the structure of `CheckoutBasicView` so merchants can
//  copy-paste between the two flows.
//

import SwiftUI
import Combine
import UIKit

import SpreedlyCore
import SpreedlyUI

struct BankAccountCheckoutView: View {
    @State private var showForm = false
    @State private var paymentResult: PaymentResult?
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var cancellable: AnyCancellable?
    @Environment(\.spreedlyTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var nameDisplayMode: DropInNameDisplayMode = .singleField
    @State private var showBankName: Bool = false
    @State private var showAccountType: Bool = true
    @State private var showAccountHolderType: Bool = true

    // Theme picker state — mirrors the card-checkout demo so merchants see the same
    // preset-driven theming flow for ACH. When `useCustomTheme` is off, the SDK
    // falls back to its default theme.
    @State private var useCustomTheme: Bool = false
    @State private var lightTheme: SpreedlyTheme?
    @State private var darkTheme: SpreedlyTheme?
    /// Selected primary chip (`achThemeSwatches`), mirrors Android `primaryColors`.
    @State private var selectedPrimarySwatchID: Int?
    /// Selected field background chip (`fieldBackgroundSwatches`), mirrors Android `fieldBackgroundColors`.
    @State private var selectedFieldBackgroundID: Int?
    /// Single corner scale passed into `SpreedlyBorderRadius` (mirrors Android `borderRadius` on `CustomFieldsConfig` / `SPLThemeConfig`).
    @State private var formCornerRadius: CGFloat = 8

    public var body: some View {
        ScrollView {
            ZStack {
                VStack(spacing: 20) {
                    headerSection
                    requiredFieldsCard
                    optionalFieldsCard
                    themeConfigurationCard
                    showFormButtonSection
                    if let result = paymentResult, result.isSuccess {
                        successResultView(result)
                    }
                    if let error = errorMessage { errorMessageView(error) }
                    Spacer(minLength: 20)
                }
                .padding()
                if isLoading { loadingOverlayView }
            }
        }
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $showForm) { formSheet }
        .onAppear(perform: setupOnAppear)
        .onDisappear(perform: cleanupOnDisappear)
    }

    private var headerSection: some View {
        Group {
            Text("ACH Bank Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.title)
                .accessibilityLabel(AccessibilityLabels.BankAccountCheckout.title)
                .accessibilityAddTraits(.isHeader)

            Text("Tokenize bank account details via ACH")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.description)
                .accessibilityLabel(AccessibilityLabels.BankAccountCheckout.description)
                .accessibilityHint(AccessibilityHints.BankAccountCheckout.description)
        }
    }

    private var requiredFieldsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Required fields:")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            switch nameDisplayMode {
            case .singleField:
                Text("• Account Holder Name")
            case .separateFields:
                Text("• First Name")
                Text("• Last Name")
            @unknown default:
                EmptyView()
            }

            Text("• Routing Number (9 digits, ABA-validated)")
            Text("• Account Number (4–17 digits)")
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

    private var optionalFieldsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration:")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name display:")
                Picker("Name display", selection: $nameDisplayMode) {
                    Text("Full Name").tag(DropInNameDisplayMode.singleField)
                    Text("Separate").tag(DropInNameDisplayMode.separateFields)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.nameDisplayModePicker)
            }

            Toggle("Show bank name field", isOn: $showBankName)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.showBankNameToggle)

            Toggle("Show account type", isOn: $showAccountType)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.showAccountTypeToggle)

            Toggle("Show holder type", isOn: $showAccountHolderType)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.showAccountHolderTypeToggle)
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

    private var showFormButtonSection: some View {
        Button("Add Bank Account") {
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
        .background(isLoading ? exampleBrandBlue.opacity(0.6) : exampleBrandBlue)
        .cornerRadius(8)
        .disabled(isLoading)
        .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.showFormButton)
        .accessibilityLabel(AccessibilityLabels.BankAccountCheckout.showFormButton)
        .accessibilityHint(AccessibilityHints.BankAccountCheckout.showFormButton)
    }

    private var formSheet: some View {
        BankAccountFormDropIn(
            fieldConfig: BankAccountFieldConfig(
                nameDisplayMode: nameDisplayMode,
                showBankName: showBankName,
                showAccountType: showAccountType,
                showAccountHolderType: showAccountHolderType
            ),
            theme: useCustomTheme ? lightTheme : nil,
            darkTheme: useCustomTheme ? darkTheme : nil,
            onProcessingResult: { processingResult in
                if processingResult.isProcessing { isLoading = true }
            }
        )
    }

    private var themeConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme Configuration:")
                .font(.headline)
                .accessibilityIdentifier("bankAccountThemeTitle")
                .accessibilityLabel("Theme Configuration")
                .accessibilityHint("Configure custom theme for the bank account form")
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
                                selectedPrimarySwatchID = nil
                                selectedFieldBackgroundID = nil
                            } else {
                                if selectedPrimarySwatchID == nil { selectedPrimarySwatchID = 0 }
                                if selectedFieldBackgroundID == nil { selectedFieldBackgroundID = 0 }
                                applyCustomization()
                            }
                        }
                    )
                )
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier("bankAccountCustomThemeToggle")
                .accessibilityHint("Toggle to use a custom theme for the bank account form")
            }

            HStack {
                Text("Current accent:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(currentAccentSummary)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(useCustomTheme && selectedPrimarySwatchID != nil && selectedFieldBackgroundID != nil ? .primary : .gray)
                    .accessibilityIdentifier("bankAccountCurrentTheme")
            }
            .padding(.top, 4)

            if useCustomTheme {
                VStack(alignment: .leading, spacing: 12) {
                    Text("UI customization")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Primary color")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        ForEach(Self.achThemeSwatches) { swatch in
                            let chip = colorScheme == .dark ? swatch.darkPrimary : swatch.lightPrimary
                            Button {
                                selectedPrimarySwatchID = swatch.id
                                applyCustomization()
                            } label: {
                                Circle()
                                    .fill(chip)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selectedPrimarySwatchID == swatch.id ? Color.primary : Color.clear,
                                                lineWidth: selectedPrimarySwatchID == swatch.id ? 3 : 0
                                            )
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityIdentifier("bankAccountPrimarySwatch_\(swatch.id)")
                            .accessibilityLabel("Primary \(swatch.label)")
                            .accessibilityHint("Sets Checkout button and focus accents to \(swatch.label)")
                            .accessibilityAddTraits(selectedPrimarySwatchID == swatch.id ? [.isButton, .isSelected] : .isButton)
                        }
                    }

                    Text("Field background")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    HStack(spacing: 12) {
                        ForEach(Self.fieldBackgroundSwatches) { swatch in
                            let chip = colorScheme == .dark ? swatch.darkSurface : swatch.lightSurface
                            Button {
                                selectedFieldBackgroundID = swatch.id
                                applyCustomization()
                            } label: {
                                Circle()
                                    .fill(chip)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                selectedFieldBackgroundID == swatch.id ? Color.primary : Color.clear,
                                                lineWidth: selectedFieldBackgroundID == swatch.id ? 3 : 0
                                            )
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityIdentifier("bankAccountFieldBackgroundSwatch_\(swatch.id)")
                            .accessibilityLabel("Field background \(swatch.label)")
                            .accessibilityHint("Sets SPLTextField surface fill to \(swatch.label)")
                            .accessibilityAddTraits(selectedFieldBackgroundID == swatch.id ? [.isButton, .isSelected] : .isButton)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Border radius")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        HStack {
                            Spacer()
                            Text("\(Int(formCornerRadius)) pt")
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $formCornerRadius, in: 4...24, step: 1)
                            .accessibilityIdentifier("bankAccountFormCornerRadiusSlider")
                            .accessibilityLabel("Border radius")
                            .onChange(of: formCornerRadius) { _ in
                                refreshCustomThemeIfNeeded()
                            }
                    }
                    .padding(.top, 4)

                    Button("Reset to Default") {
                        lightTheme = nil
                        darkTheme = nil
                        selectedPrimarySwatchID = nil
                        selectedFieldBackgroundID = nil
                        formCornerRadius = 8
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .accessibilityIdentifier("bankAccountResetThemeButton")
                    .accessibilityLabel("Reset to Default Theme")
                    .accessibilityHint("Reset the bank account form to the default theme")
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

    /// Scales one merchant “base” radius into the full `SpreedlyBorderRadius` ladder (like a single Android `borderRadius` driving the form).
    private func borderRadiusFromSlider(_ base: CGFloat) -> SpreedlyBorderRadius {
        let sm = base
        let xs = max(2, base - 2)
        let md = min(base + 2, 28)
        let lg = min(base + 4, 32)
        let xl = min(base + 8, 36)
        return SpreedlyBorderRadius(xs: xs, sm: sm, md: md, lg: lg, xl: xl)
    }

    private func refreshCustomThemeIfNeeded() {
        applyCustomization()
    }

    /// Builds themes from Android-style **primary** + **field background** chips and the border-radius slider.
    private func applyCustomization() {
        guard useCustomTheme,
              let pId = selectedPrimarySwatchID,
              let fId = selectedFieldBackgroundID,
              let primarySwatch = Self.achThemeSwatches.first(where: { $0.id == pId }),
              let fieldSwatch = Self.fieldBackgroundSwatches.first(where: { $0.id == fId }) else { return }

        let borderRadius = borderRadiusFromSlider(formCornerRadius)
        let lightP = primarySwatch.lightPrimary
        let darkP = primarySwatch.darkPrimary
        let lightSurface = fieldSwatch.lightSurface
        let darkSurface = fieldSwatch.darkSurface

        let lightColors = SpreedlyColors(
            primary: lightP,
            secondary: lightP.opacity(0.75),
            background: Color.white,
            surface: lightSurface,
            text: Color.black,
            textSecondary: Color(red: 0.2, green: 0.2, blue: 0.22),
            border: lightP.opacity(0.32),
            borderFocused: lightP,
            error: Color.red,
            placeholder: Color.gray.opacity(0.65)
        )
        let darkColors = SpreedlyColors(
            primary: darkP,
            secondary: darkP.opacity(0.85),
            background: Color.black,
            surface: darkSurface,
            text: Color.white,
            textSecondary: Color.white.opacity(0.72),
            border: darkP.opacity(0.5),
            borderFocused: darkP,
            error: Color.red,
            placeholder: Color.white.opacity(0.55)
        )

        lightTheme = SpreedlyThemeManager.createCustomTheme(
            colors: lightColors,
            borderRadius: borderRadius
        )
        darkTheme = SpreedlyThemeManager.createCustomTheme(
            colors: darkColors,
            borderRadius: borderRadius
        )
    }

    private var currentAccentSummary: String {
        if !useCustomTheme { return ThemeOption.default.displayName }
        guard let pId = selectedPrimarySwatchID,
              let fId = selectedFieldBackgroundID,
              let p = Self.achThemeSwatches.first(where: { $0.id == pId }),
              let f = Self.fieldBackgroundSwatches.first(where: { $0.id == fId }) else {
            return "Pick colors"
        }
        return "\(p.label) · \(f.label)"
    }

    /// Primary chip colors aligned with Android `BankAccountConfigPanel` (`primaryColors` light/dark lists).
    private struct ACHThemeSwatch: Identifiable {
        let id: Int
        let lightPrimary: Color
        let darkPrimary: Color
        let label: String
    }

    private static let achThemeSwatches: [ACHThemeSwatch] = [
        ACHThemeSwatch(id: 0, lightPrimary: Color(hex: "#1976D2"), darkPrimary: Color(hex: "#64B5F6"), label: "Blue"),
        ACHThemeSwatch(id: 1, lightPrimary: Color(hex: "#388E3C"), darkPrimary: Color(hex: "#81C784"), label: "Green"),
        ACHThemeSwatch(id: 2, lightPrimary: Color(hex: "#7B1FA2"), darkPrimary: Color(hex: "#BA68C8"), label: "Purple"),
        ACHThemeSwatch(id: 3, lightPrimary: Color(hex: "#D32F2F"), darkPrimary: Color(hex: "#E57373"), label: "Red"),
        ACHThemeSwatch(id: 4, lightPrimary: Color(hex: "#00897B"), darkPrimary: Color(hex: "#4DB6AC"), label: "Teal"),
        ACHThemeSwatch(id: 5, lightPrimary: Color(hex: "#E64A19"), darkPrimary: Color(hex: "#FF8A65"), label: "Orange"),
    ]

    /// Field fill colors aligned with Android `BankAccountConfigPanel.fieldBackgroundColors` (light / dark rows).
    private struct ACHFieldBackgroundSwatch: Identifiable {
        let id: Int
        let lightSurface: Color
        let darkSurface: Color
        let label: String
    }

    private static let fieldBackgroundSwatches: [ACHFieldBackgroundSwatch] = [
        ACHFieldBackgroundSwatch(id: 0, lightSurface: Color.white, darkSurface: Color(hex: "#1C1C1E"), label: "Default"),
        ACHFieldBackgroundSwatch(id: 1, lightSurface: Color(hex: "#F5F5F5"), darkSurface: Color(hex: "#2C2C2C"), label: "Gray"),
        ACHFieldBackgroundSwatch(id: 2, lightSurface: Color(hex: "#E8F5E9"), darkSurface: Color(hex: "#1B3A2A"), label: "Pale green"),
        ACHFieldBackgroundSwatch(id: 3, lightSurface: Color(hex: "#E3F2FD"), darkSurface: Color(hex: "#1A2C3D"), label: "Pale blue"),
        ACHFieldBackgroundSwatch(id: 4, lightSurface: Color(hex: "#FFF3E0"), darkSurface: Color(hex: "#3D2E1A"), label: "Pale cream"),
        ACHFieldBackgroundSwatch(id: 5, lightSurface: Color(hex: "#F3E5F5"), darkSurface: Color(hex: "#2E1A3D"), label: "Pale purple"),
    ]

    /// Spreedly brand blue for example-only chrome (not tied to ACH sheet theme).
    private var exampleBrandBlue: Color {
        Color(red: 0.0 / 255.0, green: 119.0 / 255.0, blue: 200.0 / 255.0)
    }

    private func successResultView(_ result: PaymentResult) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.colors.success)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.successIcon)
                Text("Bank Account Tokenized!")
                    .font(theme.typography.subtitleFont)
                    .foregroundColor(theme.colors.success)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.successTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            if let token = result.token {
                Text("Payment Token: \(Spreedly.maskedToken(token))")
                    .font(theme.typography.captionFont)
                    .foregroundColor(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.transactionTokenText)
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
            .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.errorMessage)
    }

    private var loadingOverlayView: some View {
        ProgressView("Loading...")
            .progressViewStyle(CircularProgressViewStyle())
            .padding()
            .background(cardBackgroundColor.opacity(0.9))
            .cornerRadius(10)
            .shadow(radius: 10)
            .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.loadingProgressView)
    }

    private func setupOnAppear() {
        cancellable = Spreedly.shared().subscribeToPaymentResults { result in
            paymentResult = result
            isLoading = false
            if result.isSuccess {
                errorMessage = nil
                showForm = false
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

    private func cleanupOnDisappear() {
        cancellable?.cancel()
        cancellable = nil
        ValidationParamReset.reset()
    }

    private var primaryButtonFont: Font {
        if let poppins = UIFont(name: "Poppins", size: 16) {
            return Font(poppins)
        } else if let poppinsRegular = UIFont(name: "Poppins-Regular", size: 16) {
            return Font(poppinsRegular)
        } else {
            return Font.system(size: 16, weight: .regular)
        }
    }

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
    BankAccountCheckoutView()
}
