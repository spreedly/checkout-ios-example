//
//  BankAccountCustomFormView.swift
//  SpreedlySDKExample
//
//  Demonstrates the headless ACH integration path: routing/account/name fields are
//  built individually with `SPLTextField`, and submit calls
//  `Spreedly.shared().createBankAccount(...)` directly. Pair this screen with
//  `BankAccountCheckoutView` (drop-in) to see both ACH integration paths.
//

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI

struct BankAccountCustomFormView: View {
    @State private var isLoading: Bool = false
    @State private var paymentResult: PaymentResult?
    @State private var errorMessage: String?
    @State private var cancellable: AnyCancellable?
    @Environment(\.spreedlyTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var routingNumberIsValid: Bool = false
    @State private var accountNumberIsValid: Bool = false
    @State private var fullNameIsValid: Bool = false
    @State private var firstNameIsValid: Bool = false
    @State private var lastNameIsValid: Bool = false
    @State private var bankNameIsValid: Bool = true

    @State private var nameDisplayMode: DropInNameDisplayMode = .singleField
    @State private var showBankName: Bool = false
    @State private var showAccountType: Bool = true
    @State private var showAccountHolderType: Bool = true
    @State private var bankAccountType: BankAccountType = .checking
    @State private var bankAccountHolderType: BankAccountHolderType = .personal

    @State private var focusedFieldType: FormFieldType?

    /// Same chip + border-radius model as `BankAccountCheckoutView` / Android `BankAccountConfigPanel`.
    @State private var useCustomTheme: Bool = false
    @State private var lightTheme: SpreedlyTheme?
    @State private var darkTheme: SpreedlyTheme?
    @State private var selectedPrimarySwatchID: Int?
    @State private var selectedFieldBackgroundID: Int?
    @State private var formCornerRadius: CGFloat = 8

    private var activeFieldTheme: SpreedlyTheme? {
        useCustomTheme ? lightTheme : nil
    }

    private var activeFieldDarkTheme: SpreedlyTheme? {
        useCustomTheme ? darkTheme : nil
    }

    // Demo-side wording — matches the bundled `bank_account_holder_name_required`
    // string the SDK ships for the drop-in. Hard-coded here because the example
    // app doesn't link the SDK's internal `LocalizationHelper`.
    private let nameRequiredMessage: String = "Name is required"

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("ACH Bank Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.title)
                    .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.title)
                    .accessibilityHint(AccessibilityHints.BankAccountCustomForm.title)
                    .accessibilityAddTraits(.isHeader)

                Text("Tokenize bank account details via ACH")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.description)
                    .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.description)
                    .accessibilityHint(AccessibilityHints.BankAccountCustomForm.description)

                componentsCard
                configurationCard
                themeConfigurationCard

                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.errorMessage)
                        .accessibilityHint(AccessibilityHints.BankAccountCustomForm.errorMessage)
                }

                fieldsSection

                Button(action: handleSubmit) {
                    Text(isLoading ? "Processing..." : "PAY NOW")
                        .font(primaryButtonFont)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isFormValid && !isLoading ? payButtonPrimary : payButtonPrimary.opacity(0.6))
                        )
                }
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal)
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.payButton)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.payButton)

                if let result = paymentResult, result.isSuccess {
                    successResultView(result)
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            if !Spreedly.isDeviceTrusted {
                errorMessage = Spreedly.initializationError?.message ?? "SDK blocked by security check"
            }

            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                paymentResult = result
                isLoading = false

                if result.isSuccess {
                    errorMessage = nil
                    routingNumberIsValid = false
                    accountNumberIsValid = false
                    fullNameIsValid = false
                    firstNameIsValid = false
                    lastNameIsValid = false

                } else if result.isFailure {
                    if let failureDetails = result.failureDetails {
                        errorMessage = failureDetails.getDescription()
                    } else {
                        errorMessage = "Payment failed"
                    }
                }
            }
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
            ValidationParamReset.reset()
        }
    }

    // MARK: - Sections

    private var componentsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Form components:")
                .font(.headline)
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.componentsTitle)
                .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.componentsTitle)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.componentsTitle)
                .accessibilityAddTraits(.isHeader)

            Text("• Account holder name")
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.nameComponent)

            Text("• Routing number")
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.routingNumberComponent)

            Text("• Account number")
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.accountNumberComponent)

            Text("• Bank name (optional)")
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.bankNameComponent)
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

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration:")
                .font(.headline)
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.configurationTitle)
                .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.configurationTitle)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.configurationTitle)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name display:")
                Picker("Name display", selection: $nameDisplayMode) {
                    Text("Full Name").tag(DropInNameDisplayMode.singleField)
                    Text("Separate").tag(DropInNameDisplayMode.separateFields)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.nameDisplayModePicker)
                .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.nameDisplayModePicker)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.nameDisplayModePicker)
            }

            Toggle("Show bank name field", isOn: $showBankName)
                .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.showBankNameToggle)
                .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.showBankNameToggle)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.showBankNameToggle)

            Toggle("Show account type", isOn: $showAccountType)
                .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))

            Toggle("Show holder type", isOn: $showAccountHolderType)
                .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))
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

    private var themeConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme Configuration:")
                .font(.headline)
                .accessibilityIdentifier("bankAccountCustomThemeTitle")
                .accessibilityLabel("Theme Configuration")
                .accessibilityHint("Configure custom theme for the headless ACH form")
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
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0 / 255.0, green: 119.0 / 255.0, blue: 200.0 / 255.0)))
                .accessibilityIdentifier("bankAccountCustomThemeToggle")
                .accessibilityHint("Toggle to use a custom theme for the headless ACH form")
            }

            HStack {
                Text("Current accent:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(currentAccentSummary)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(
                        useCustomTheme && selectedPrimarySwatchID != nil && selectedFieldBackgroundID != nil
                            ? .primary
                            : .gray
                    )
                    .accessibilityIdentifier("bankAccountCustomCurrentTheme")
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
                            .accessibilityIdentifier("bankAccountCustomPrimarySwatch_\(swatch.id)")
                            .accessibilityLabel("Primary \(swatch.label)")
                            .accessibilityHint("Sets field focus accents and PAY NOW button to \(swatch.label)")
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
                            .accessibilityIdentifier("bankAccountCustomFieldBackgroundSwatch_\(swatch.id)")
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
                            .accessibilityIdentifier("bankAccountCustomFormCornerRadiusSlider")
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
                    .accessibilityIdentifier("bankAccountCustomResetThemeButton")
                    .accessibilityLabel("Reset to Default Theme")
                    .accessibilityHint("Reset the headless ACH form to the default theme")
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

    private var payButtonPrimary: Color {
        guard useCustomTheme,
              let pId = selectedPrimarySwatchID,
              let swatch = Self.achThemeSwatches.first(where: { $0.id == pId }) else {
            return theme.colors.primary
        }
        return colorScheme == .dark ? swatch.darkPrimary : swatch.lightPrimary
    }

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

    private var fieldsSection: some View {
        VStack(spacing: 16) {
            SPLTextField(
                type: .routingNumber,
                title: "Routing Number",
                isRequired: true,
                theme: activeFieldTheme,
                darkTheme: activeFieldDarkTheme,
                onValidationChange: { routingNumberIsValid = $0 },
                onSubmit: { handleFieldSubmit(for: .routingNumber) },
                submitLabel: getSubmitLabel(for: .routingNumber),
                shouldFocus: focusedFieldType == .routingNumber,
                onFocus: { focusedFieldType = .routingNumber }
            )

            SPLTextField(
                type: .accountNumber,
                title: "Account Number",
                isRequired: true,
                theme: activeFieldTheme,
                darkTheme: activeFieldDarkTheme,
                onValidationChange: { accountNumberIsValid = $0 },
                onSubmit: { handleFieldSubmit(for: .accountNumber) },
                submitLabel: getSubmitLabel(for: .accountNumber),
                shouldFocus: focusedFieldType == .accountNumber,
                onFocus: { focusedFieldType = .accountNumber }
            )

            Text("Personal information")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            switch nameDisplayMode {
            case .singleField:
                SPLTextField(
                    type: .fullName,
                    title: "Account Holder Name",
                    isRequired: true,
                    placeholder: "Account Holder Name",
                    requiredMessage: nameRequiredMessage,
                    theme: activeFieldTheme,
                    darkTheme: activeFieldDarkTheme,
                    onValidationChange: { fullNameIsValid = $0 },
                    onSubmit: { handleFieldSubmit(for: .fullName) },
                    submitLabel: getSubmitLabel(for: .fullName),
                    shouldFocus: focusedFieldType == .fullName,
                    onFocus: { focusedFieldType = .fullName }
                )
            case .separateFields:
                HStack(alignment: .top, spacing: 16) {
                    SPLTextField(
                        type: .firstName,
                        title: "First Name",
                        isRequired: true,
                        placeholder: "First Name",
                        requiredMessage: nameRequiredMessage,
                        theme: activeFieldTheme,
                        darkTheme: activeFieldDarkTheme,
                        onValidationChange: { firstNameIsValid = $0 },
                        onSubmit: { handleFieldSubmit(for: .firstName) },
                        submitLabel: getSubmitLabel(for: .firstName),
                        shouldFocus: focusedFieldType == .firstName,
                        onFocus: { focusedFieldType = .firstName }
                    )
                    SPLTextField(
                        type: .lastName,
                        title: "Last Name",
                        isRequired: true,
                        placeholder: "Last Name",
                        requiredMessage: nameRequiredMessage,
                        theme: activeFieldTheme,
                        darkTheme: activeFieldDarkTheme,
                        onValidationChange: { lastNameIsValid = $0 },
                        onSubmit: { handleFieldSubmit(for: .lastName) },
                        submitLabel: getSubmitLabel(for: .lastName),
                        shouldFocus: focusedFieldType == .lastName,
                        onFocus: { focusedFieldType = .lastName }
                    )
                }
            @unknown default:
                EmptyView()
            }

            if showBankName {
                SPLTextField(
                    type: .bankName,
                    title: "Bank Name",
                    isRequired: false,
                    placeholder: "Bank Name",
                    theme: activeFieldTheme,
                    darkTheme: activeFieldDarkTheme,
                    onValidationChange: { bankNameIsValid = $0 },
                    onSubmit: { handleFieldSubmit(for: .bankName) },
                    submitLabel: getSubmitLabel(for: .bankName),
                    shouldFocus: focusedFieldType == .bankName,
                    onFocus: { focusedFieldType = .bankName }
                )
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.bankNameField)
            }

            if showAccountType {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Account type:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("Account type", selection: $bankAccountType) {
                        Text("Checking").tag(BankAccountType.checking)
                        Text("Savings").tag(BankAccountType.savings)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.accountTypePicker)
                    .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.accountTypePicker)
                    .accessibilityHint(AccessibilityHints.BankAccountCustomForm.accountTypePicker)
                }
            }

            if showAccountHolderType {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Account holder type:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Picker("Holder type", selection: $bankAccountHolderType) {
                        Text("Personal").tag(BankAccountHolderType.personal)
                        Text("Business").tag(BankAccountHolderType.business)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.holderTypePicker)
                    .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.holderTypePicker)
                    .accessibilityHint(AccessibilityHints.BankAccountCustomForm.holderTypePicker)
                }
            }
        }
        .padding()
        .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.fieldsSection)
    }

    private func successResultView(_ result: PaymentResult) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.colors.success)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.successIcon)
                Text("Bank Account Tokenized!")
                    .font(theme.typography.subtitleFont)
                    .foregroundColor(theme.colors.success)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.successTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            if let token = result.token {
                Text("Payment Token: \(Spreedly.maskedToken(token))")
                    .font(theme.typography.captionFont)
                    .foregroundColor(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.tokenText)
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

    // MARK: - Submit

    private var isFormValid: Bool {
        let routingValid = routingNumberIsValid
        let accountValid = accountNumberIsValid
        let nameValid: Bool
        switch nameDisplayMode {
        case .singleField:
            nameValid = fullNameIsValid
        case .separateFields:
            nameValid = firstNameIsValid && lastNameIsValid
        @unknown default:
            nameValid = false
        }
        let bankNameValid = showBankName ? bankNameIsValid : true
        return routingValid && accountValid && nameValid && bankNameValid
    }

    private func handleSubmit() {
        guard isFormValid else { return }

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
                let processingResult = Spreedly.shared().createBankAccount(
                    additionalFields: [:],
                    bankAccountType: showAccountType ? bankAccountType : nil,
                    bankAccountHolderType: showAccountHolderType ? bankAccountHolderType : nil,
                    bankName: nil,
                    metadata: nil
                )

                if processingResult.isValidationFailed {
                    self.isLoading = false
                    self.errorMessage = "Validation failed: \(processingResult.getDescription())"
                    self.paymentResult = nil
                }
            }
        }
    }

    private func isSignatureGenerated() async -> Bool {
        let signatureGenerated = await SpreedlyConfigManager.shared.generateSignature()
        switch signatureGenerated {
        case .success(let success):
            return success
        case .failure:
            return false
        }
    }

    // MARK: - Focus Management

    private var fieldOrder: [FormFieldType] {
        let optionalBankName: [FormFieldType] = showBankName ? [.bankName] : []
        let nameFields: [FormFieldType]
        switch nameDisplayMode {
        case .singleField:
            nameFields = [.fullName]
        case .separateFields:
            nameFields = [.firstName, .lastName]
        @unknown default:
            nameFields = []
        }
        return [.routingNumber, .accountNumber] + nameFields + optionalBankName
    }

    private func getSubmitLabel(for fieldType: FormFieldType) -> SpreedlySubmitLabel {
        let allFields = fieldOrder
        guard let currentIndex = allFields.firstIndex(of: fieldType) else { return .done }
        return currentIndex == allFields.count - 1 ? .done : .next
    }

    private func handleFieldSubmit(for fieldType: FormFieldType) {
        let allFields = fieldOrder
        guard let currentIndex = allFields.firstIndex(of: fieldType) else { return }

        let submitLabel = getSubmitLabel(for: fieldType)
        switch submitLabel {
        case .next:
            if currentIndex < allFields.count - 1 {
                focusedFieldType = allFields[currentIndex + 1]
            }
        case .done:
            focusedFieldType = nil
            handleSubmit()
        case .return, .go, .search, .send, .join, .route, .continue:
            focusedFieldType = nil
        @unknown default:
            focusedFieldType = nil
        }
    }

    // MARK: - Adaptive Colors / Fonts

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

#if DEBUG
#Preview {
    BankAccountCustomFormView()
}
#endif
