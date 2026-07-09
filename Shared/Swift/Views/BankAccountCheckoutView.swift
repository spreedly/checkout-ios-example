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

    public var body: some View {
        ScrollView {
            ZStack {
                VStack(spacing: 20) {
                    headerSection
                    requiredFieldsCard
                    optionalFieldsCard
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
        .sheet(isPresented: $showForm) { formSheet }
        .onAppear(perform: setupOnAppear)
        .onDisappear(perform: cleanupOnDisappear)
    }

    private var headerSection: some View {
        Group {
            Text("ACH Bank Account Drop-In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.title)
                .accessibilityLabel(AccessibilityLabels.BankAccountCheckout.title)
                .accessibilityAddTraits(.isHeader)

            Text("Preview only — ACH bank-account flows are in the SDK for internal testing and will not ship in 1.4.1. Do not integrate ACH in production.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()

            Text("Demonstrates BankAccountFormDropIn — the SDK's drop-in form for ACH tokenization. Routing/account numbers stay inside SecureValueContainer; the bank-account payload is emitted via the same publisher card payments use.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.description)
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

            HStack {
                Text("Name display:")
                Picker("Name display", selection: $nameDisplayMode) {
                    Text("Full Name").tag(DropInNameDisplayMode.singleField)
                    Text("Separate").tag(DropInNameDisplayMode.separateFields)
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.nameDisplayModePicker)
            }

            Toggle("Show bank name field", isOn: $showBankName)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.showBankNameToggle)

            Toggle("Show account type (checking/savings)", isOn: $showAccountType)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.0/255.0, green: 119.0/255.0, blue: 200.0/255.0)))
                .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.showAccountTypeToggle)

            Toggle("Show holder type (personal/business)", isOn: $showAccountHolderType)
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
        Button("Show Bank Account Form") {
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
        .accessibilityIdentifier(AccessibilityIdentifiers.BankAccountCheckout.showFormButton)
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
            onProcessingResult: { processingResult in
                if processingResult.isProcessing { isLoading = true }
            }
        ).screenPrevention()
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
