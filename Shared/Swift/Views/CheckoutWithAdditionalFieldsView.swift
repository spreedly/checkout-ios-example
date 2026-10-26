//
//  CheckoutWithAdditionalFieldsView.swift
//  SpreedlySDKExample
//
//  Drop-in checkout demo with Enable + Required toggles for every mountable
//  additional (non-card) catalogue field.
//

import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI

struct CheckoutWithAdditionalFieldsView: View {
    @State private var showForm = false
    @State private var paymentResult: PaymentResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var cancellable: AnyCancellable?
    @Environment(\.spreedlyTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var allowBlankName: Bool = false
    @State private var allowExpiredDate: Bool = false
    @State private var allowBlankDate: Bool = false
    @State private var yearFormat: YearFormat = .fourDigit
    @State private var enableAutofill: Bool = true

    @State private var catalogueRows: [AdditionalFieldToggleRow] = AdditionalFieldCatalogueDemo.defaultRows()
    @State private var firstNameCustomRule: DemoCustomValidationKind = .none
    @State private var lastNameCustomRule: DemoCustomValidationKind = .none
    @State private var showAdditionalFieldsConfig = false
    @State private var groupBillingAddress = false
    @State private var groupShippingAddress = false
    @State private var groupEmail = false

    private var selectedOtherFields: [FormField] {
        catalogueRows.compactMap { $0.formField() }
    }

    private var customValidationSelections: [CustomValidatableFieldName: DemoCustomValidationKind] {
        var map = AdditionalFieldCatalogueDemo.customValidationSelections(from: catalogueRows)
        map[.firstName] = firstNameCustomRule
        map[.lastName] = lastNameCustomRule
        return map
    }

    private var activeCustomRulesSummary: String {
        DemoCustomValidationRecipes.activeRulesSummary(selections: customValidationSelections)
    }

    private var toggleTint: Color {
        Color(red: 0.0 / 255.0, green: 119.0 / 255.0, blue: 200.0 / 255.0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Checkout with Additional Fields")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.title)
                    .accessibilityAddTraits(.isHeader)

                Text("Drop-in checkout with optional additional fields. Use Optional address groups for quick enable, or Show Additional Fields Configuration for per-field Enable / Required / Custom rule. Custom rules run on blur + Pay.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.description)

                Text(activeCustomRulesSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .accessibilityIdentifier("additionalFields_activeCustomRules")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Fields:")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("• First Name")
                    Text("• Last Name")
                    Text("• Card Number")
                    Text("• Expiry Month")
                    Text("• Expiry Year")
                    Text("• CVC")

                    Text("Drop-in name Custom rules:")
                        .font(.caption.weight(.semibold))
                        .padding(.top, 4)
                    customRulePickerRow(
                        title: "First name",
                        selection: $firstNameCustomRule,
                        enabled: true,
                        accessibilityId: "additionalFields_firstName_customRule"
                    )
                    customRulePickerRow(
                        title: "Last name",
                        selection: $lastNameCustomRule,
                        enabled: true,
                        accessibilityId: "additionalFields_lastName_customRule"
                    )
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

                AdditionalFieldCatalogueCards(
                    catalogueRows: $catalogueRows,
                    showConfig: $showAdditionalFieldsConfig,
                    groupBilling: $groupBillingAddress,
                    groupShipping: $groupShippingAddress,
                    groupEmail: $groupEmail,
                    accessibilityPrefix: "additionalFields",
                    configTitleAccessibilityId: AccessibilityIdentifiers.AdditionalFields.additionalFieldsTitle,
                    toggleTint: toggleTint,
                    onCatalogueChanged: applyCustomValidationSelections
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuration Options:")
                        .font(.headline)
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.configurationTitle)
                        .accessibilityAddTraits(.isHeader)

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
                    .toggleStyle(SwitchToggleStyle(tint: toggleTint))
                    .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.allowBlankNameToggle)

                    Toggle(
                        "Allow Expired Date",
                        isOn: Binding(
                            get: { allowExpiredDate },
                            set: { newValue in
                                allowExpiredDate = newValue
                                Spreedly.shared().setParam(parameter: .allowExpiredDate, value: newValue)
                            }
                        )
                    )
                    .toggleStyle(SwitchToggleStyle(tint: toggleTint))
                    .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.allowExpiredDateToggle)

                    Toggle(
                        "Allow Blank Date",
                        isOn: Binding(
                            get: { allowBlankDate },
                            set: { newValue in
                                allowBlankDate = newValue
                                Spreedly.shared().setParam(parameter: .allowBlankDate, value: newValue)
                            }
                        )
                    )
                    .toggleStyle(SwitchToggleStyle(tint: toggleTint))
                    .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.allowBlankDateToggle)

                    HStack {
                        Text("Year Format:")
                            .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.yearFormatLabel)

                        Picker("Year Format", selection: $yearFormat) {
                            Text("YY").tag(YearFormat.twoDigit)
                                .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.yearFormatTwoDigit)
                            Text("YYYY").tag(YearFormat.fourDigit)
                                .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.yearFormatFourDigit)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Toggle("Enable Autofill", isOn: $enableAutofill)
                        .toggleStyle(SwitchToggleStyle(tint: toggleTint))
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
                        if let lastFour = result.paymentResponse?.transaction?.paymentMethod?.lastFourDigits {
                            Text("Card ending in •••• \(lastFour)")
                                .font(theme.typography.captionFont)
                                .foregroundColor(theme.colors.textSecondary)
                        }
                        if let firstSixDigits = result.paymentResponse?.transaction?.paymentMethod?.firstSixDigits {
                            Text("Card starting in •••• \(firstSixDigits)")
                                .font(theme.typography.captionFont)
                                .foregroundColor(theme.colors.textSecondary)
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
                }

                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityIdentifier(AccessibilityIdentifiers.AdditionalFields.errorMessage)
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .sheet(isPresented: $showForm) {
            CardFormDropIn(
                otherFields: selectedOtherFields,
                yearFormat: yearFormat,
                displayConfig: CardFormDropInDisplayConfig(enableAutofill: enableAutofill),
                onProcessingResult: { processingResult in
                    if processingResult.isProcessing {
                        isLoading = true
                    }
                }
            )
        }
        .onAppear {
            applyCustomValidationSelections()
            allowBlankName = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankName)
            allowExpiredDate = Spreedly.shared().paramsManager.getParam(parameter: .allowExpiredDate)
            allowBlankDate = Spreedly.shared().paramsManager.getParam(parameter: .allowBlankDate)

            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                paymentResult = result
                isLoading = false

                if result.isSuccess {
                    errorMessage = nil
                    showForm = false
                    if result.shouldRetain, let paymentMethodToken = result.token {
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
        .onChange(of: firstNameCustomRule) { _ in applyCustomValidationSelections() }
        .onChange(of: lastNameCustomRule) { _ in applyCustomValidationSelections() }
        .onDisappear {
            DemoCustomValidationRecipes.removeAllManagedValidations()
            cancellable?.cancel()
            cancellable = nil
            ValidationParamReset.reset()
        }
    }

    @ViewBuilder
    private func customRulePickerRow(
        title: String,
        selection: Binding<DemoCustomValidationKind>,
        enabled: Bool,
        formFieldType: FormFieldType? = nil,
        accessibilityId: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(enabled ? 1 : 0.45)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(DemoCustomValidationKind.pickerCases(for: formFieldType)) { kind in
                    Text(kind.pickerLabel).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
            .accessibilityIdentifier(accessibilityId)
        }
    }

    private func applyCustomValidationSelections() {
        DemoCustomValidationRecipes.applySelections(customValidationSelections)
    }

    private func retainPaymentMethod(token: String) async {
        do {
            let apiClient = SpreedlyConfigManager.shared.createRetainPaymentMethodAPIClient()
            _ = try await apiClient.retainPaymentMethod(token: token)
        } catch {
            logError(tag: "SpreedlyExample", message: "Retain payment method failed: \(error.localizedDescription)", error: error)
        }
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
    CheckoutWithAdditionalFieldsView()
}
