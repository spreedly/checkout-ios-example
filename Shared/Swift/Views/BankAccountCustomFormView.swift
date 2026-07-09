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

    @State private var nameDisplayMode: DropInNameDisplayMode = .singleField
    @State private var showBankName: Bool = false
    @State private var bankNameInput: String = ""
    @State private var bankAccountType: BankAccountType = .checking
    @State private var bankAccountHolderType: BankAccountHolderType = .personal

    @State private var allowBlankName: Bool = false

    @State private var focusedFieldType: FormFieldType?

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("ACH Bank Account – Custom Form")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.title)
                    .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.title)
                    .accessibilityHint(AccessibilityHints.BankAccountCustomForm.title)
                    .accessibilityAddTraits(.isHeader)

                Text("Preview only — ACH bank-account flows are in the SDK for internal testing and will not ship in 1.4.1. Do not integrate ACH in production.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding()

                Text("Headless ACH built field-by-field with individual SPLTextFields. The app owns the layout and submit flow; it calls Spreedly.shared().createBankAccount(...) directly when the user taps PAY NOW.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.description)
                    .accessibilityHint(AccessibilityHints.BankAccountCustomForm.description)

                componentsCard
                configurationCard

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
                                .fill(isFormValid && !isLoading ? theme.colors.primary : theme.colors.primary.opacity(0.6))
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
        .onAppear {
            if !Spreedly.isDeviceTrusted {
                errorMessage = Spreedly.initializationError?.message ?? "SDK blocked by security check"
            }

            allowBlankName = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankName)

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
            Text("Form Components:")
                .font(.headline)
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.componentsTitle)
                .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.componentsTitle)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.componentsTitle)
                .accessibilityAddTraits(.isHeader)

            Text("• Account Holder Name: SPLTextField with .fullName / .firstName / .lastName")
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.nameComponent)

            Text("• Bank Name (optional): plain SwiftUI TextField (free-form, not validated)")
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.bankNameComponent)

            Text("• Routing Number: SPLTextField with .routingNumber (ABA + Canadian validation)")
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.routingNumberComponent)

            Text("• Account Number: SPLTextField with .accountNumber (4–17 digits, secure)")
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.accountNumberComponent)
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

            HStack {
                Text("Name display:")
                Picker("Name display", selection: $nameDisplayMode) {
                    Text("Full Name").tag(DropInNameDisplayMode.singleField)
                    Text("Separate").tag(DropInNameDisplayMode.separateFields)
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.nameDisplayModePicker)
                .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.nameDisplayModePicker)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.nameDisplayModePicker)
            }

            Toggle("Show bank name field", isOn: $showBankName)
                .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.showBankNameToggle)
                .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.showBankNameToggle)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.showBankNameToggle)

            Toggle(
                "Allow Blank Name",
                isOn: Binding(
                    get: { allowBlankName },
                    set: { newValue in
                        allowBlankName = newValue
                        Spreedly.shared().setParam(parameter: .allowBlankName, value: newValue)
                    }
                )
            )
            .toggleStyle(SwitchToggleStyle(tint: theme.colors.primary))
            .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.allowBlankNameToggle)
            .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.allowBlankNameToggle)
            .accessibilityHint(AccessibilityHints.BankAccountCustomForm.allowBlankNameToggle)

            HStack {
                Text("Account type:")
                Picker("Account type", selection: $bankAccountType) {
                    Text("Checking").tag(BankAccountType.checking)
                    Text("Savings").tag(BankAccountType.savings)
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.accountTypePicker)
                .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.accountTypePicker)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.accountTypePicker)
            }

            HStack {
                Text("Holder type:")
                Picker("Holder type", selection: $bankAccountHolderType) {
                    Text("Personal").tag(BankAccountHolderType.personal)
                    Text("Business").tag(BankAccountHolderType.business)
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.holderTypePicker)
                .accessibilityLabel(AccessibilityLabels.BankAccountCustomForm.holderTypePicker)
                .accessibilityHint(AccessibilityHints.BankAccountCustomForm.holderTypePicker)
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

    private var fieldsSection: some View {
        VStack(spacing: 16) {
            switch nameDisplayMode {
            case .singleField:
                SPLTextField(
                    type: .fullName,
                    title: "Account Holder Name",
                    isRequired: !allowBlankName,
                    theme: theme,
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
                        isRequired: !allowBlankName,
                        theme: theme,
                        onValidationChange: { firstNameIsValid = $0 },
                        onSubmit: { handleFieldSubmit(for: .firstName) },
                        submitLabel: getSubmitLabel(for: .firstName),
                        shouldFocus: focusedFieldType == .firstName,
                        onFocus: { focusedFieldType = .firstName }
                    )
                    SPLTextField(
                        type: .lastName,
                        title: "Last Name",
                        isRequired: !allowBlankName,
                        theme: theme,
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bank Name")
                        .font(.subheadline)
                        .foregroundColor(theme.colors.textSecondary)
                    TextField("Bank name (optional)", text: $bankNameInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCustomForm.bankNameField)
                }
            }

            SPLTextField(
                type: .routingNumber,
                title: "Routing Number",
                isRequired: true,
                theme: theme,
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
                theme: theme,
                onValidationChange: { accountNumberIsValid = $0 },
                onSubmit: { handleFieldSubmit(for: .accountNumber) },
                submitLabel: getSubmitLabel(for: .accountNumber),
                shouldFocus: focusedFieldType == .accountNumber,
                onFocus: { focusedFieldType = .accountNumber }
            )
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
            nameValid = allowBlankName ? true : fullNameIsValid
        case .separateFields:
            nameValid = allowBlankName ? true : (firstNameIsValid && lastNameIsValid)
        @unknown default:
            nameValid = false
        }
        return routingValid && accountValid && nameValid
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
                let trimmedBankName = bankNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                let bankNameToSend: String? = (showBankName && !trimmedBankName.isEmpty) ? trimmedBankName : nil

                let processingResult = Spreedly.shared().createBankAccount(
                    additionalFields: [:],
                    bankAccountType: bankAccountType,
                    bankAccountHolderType: bankAccountHolderType,
                    bankName: bankNameToSend,
                    metadata: nil,
                    allowBlankName: allowBlankName ? true : nil
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
        switch nameDisplayMode {
        case .singleField:
            return [.fullName, .routingNumber, .accountNumber]
        case .separateFields:
            return [.firstName, .lastName, .routingNumber, .accountNumber]
        @unknown default:
            return [.routingNumber, .accountNumber]
        }
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
