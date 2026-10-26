//
//  CustomMerchantTextFieldsDemoView.swift
//  SpreedlySDKExample
//
//  Example-only: merchant-owned SwiftUI TextFields for catalogue data (name,
//  address, city, state, ZIP) passed via additionalFields, plus SPLTextField
//  for CHD (card / expiry / CVC). Enable / Required toggles per merchant field.
//  Local validation uses Android sample-app messages.
//

import Combine
import SpreedlyCore
import SpreedlyUI
import SwiftUI

struct CustomMerchantTextFieldsDemoView: View {
    private let hostedGateTypes: [FormFieldType] = [
        .cardNumber, .expirationMonth, .expirationYear, .cvc
    ]

    @State private var fullNameEnabled = true
    @State private var fullNameRequired = true
    @State private var fullName = ""
    @State private var fullNameError: String?

    @State private var addressEnabled = true
    @State private var addressRequired = false
    @State private var address = ""
    @State private var addressError: String?

    @State private var cityEnabled = true
    @State private var cityRequired = false
    @State private var city = ""
    @State private var cityError: String?

    @State private var stateEnabled = false
    @State private var stateRequired = false
    @State private var state = ""
    @State private var stateError: String?

    @State private var zipEnabled = true
    @State private var zipRequired = false
    @State private var zip = ""
    @State private var zipError: String?

    @State private var hostedGateReady = false
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var paymentResult: PaymentResult?
    @State private var cancellable: AnyCancellable?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your TextFields + Hosted Card")
                    .font(.title2.weight(.bold))

                Text(
                    "Build catalogue fields with your own SwiftUI TextFields (additionalFields). Card / expiry / CVC stay on SPLTextField. Toggle Enable and Required per field. Validation copy matches Android sample messages."
                )
                .font(.footnote)
                .foregroundColor(.secondary)

                hostedCardSection
                Divider()
                merchantFieldsSection
                Divider()
                paySection
            }
            .padding()
        }
        .navigationBarTitle("Custom Merchant TextFields", displayMode: .inline)
        .onAppear {
            AdditionalFieldValidator.ensureRegistered()
            refreshHostedGate()
            _ = validateAllMerchantFields(updateUI: true)
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                paymentResult = result
                isLoading = false
                if result.isSuccess {
                    errorMessage = nil
                    statusMessage = "Tokenized: \(result.token.map { Spreedly.maskedToken($0) } ?? "(no token)")"
                    clearMerchantFields()
                } else if let details = result.failureDetails {
                    errorMessage = details.getDescription()
                    statusMessage = nil
                } else {
                    errorMessage = "Payment failed"
                    statusMessage = nil
                }
            }
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
        }
    }

    // MARK: - CHD (SPLTextField)

    private var hostedCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Required card fields (SPLTextField)")
                .font(.headline)

            SPLTextField(
                type: .cardNumber,
                title: "Card Number",
                isRequired: true,
                onValidationChange: { _ in refreshHostedGate() }
            )
            HStack(spacing: 12) {
                SPLTextField(
                    type: .expirationMonth,
                    title: "Exp Month",
                    isRequired: true,
                    onValidationChange: { _ in refreshHostedGate() }
                )
                SPLTextField(
                    type: .expirationYear,
                    title: "Exp Year",
                    isRequired: true,
                    onValidationChange: { _ in refreshHostedGate() }
                )
            }
            SPLTextField(
                type: .cvc,
                title: "Security Code",
                isRequired: true,
                onValidationChange: { _ in refreshHostedGate() }
            )

            Text(
                "areAllFieldsValid(CHD) = \(hostedGateReady ? "true" : "false")"
            )
            .font(.caption2)
            .foregroundColor(hostedGateReady ? .green : .orange)
        }
    }

    // MARK: - Merchant-owned TextFields

    private var merchantFieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your catalogue TextFields")
                .font(.headline)

            merchantFieldBlock(
                title: "Full name",
                enabled: $fullNameEnabled,
                required: $fullNameRequired,
                text: $fullName,
                error: fullNameError,
                placeholder: "Jane Doe"
            ) {
                fullNameError = DemoNameValidation.message(
                    for: DemoNameValidation.validate(fullName, isRequired: fullNameRequired)
                )
            }

            merchantFieldBlock(
                title: "Address",
                enabled: $addressEnabled,
                required: $addressRequired,
                text: $address,
                error: addressError,
                placeholder: "123 Main Street"
            ) {
                addressError = DemoAddressValidation.message(
                    for: DemoAddressValidation.validate(address, isRequired: addressRequired)
                )
            }

            merchantFieldBlock(
                title: "City",
                enabled: $cityEnabled,
                required: $cityRequired,
                text: $city,
                error: cityError,
                placeholder: "San Francisco"
            ) {
                cityError = DemoCityValidation.message(
                    for: DemoCityValidation.validate(city, isRequired: cityRequired)
                )
            }

            merchantFieldBlock(
                title: "State",
                enabled: $stateEnabled,
                required: $stateRequired,
                text: $state,
                error: stateError,
                placeholder: "CA"
            ) {
                stateError = DemoStateValidation.message(
                    for: DemoStateValidation.validate(state, isRequired: stateRequired)
                )
            }

            merchantFieldBlock(
                title: "ZIP / postal",
                enabled: $zipEnabled,
                required: $zipRequired,
                text: $zip,
                error: zipError,
                placeholder: "94107"
            ) {
                zipError = DemoZipCodeValidation.message(
                    for: DemoZipCodeValidation.validate(zip, isRequired: zipRequired)
                )
            }
        }
    }

    private func merchantFieldBlock(
        title: String,
        enabled: Binding<Bool>,
        required: Binding<Bool>,
        text: Binding<String>,
        error: String?,
        placeholder: String,
        onEdit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Enable \(title)", isOn: enabled)
                if enabled.wrappedValue {
                    Toggle("Required", isOn: required)
                        .onChange(of: required.wrappedValue) { _ in onEdit() }
                }
            }
            .font(.subheadline)

            if enabled.wrappedValue {
                TextField(placeholder, text: text)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: text.wrappedValue) { _ in onEdit() }

                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: enabled.wrappedValue) { isOn in
            if !isOn {
                text.wrappedValue = ""
                onEdit()
            } else {
                onEdit()
            }
        }
    }

    // MARK: - Pay

    private var paySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let statusMessage = statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.green)
            }
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            Button(action: tokenize) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Tokenize")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
                .padding()
                .background(canTokenize ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!canTokenize || isLoading)
        }
    }

    private var canTokenize: Bool {
        hostedGateReady && merchantFieldsValid
    }

    private var merchantFieldsValid: Bool {
        validateAllMerchantFields(updateUI: false)
    }

    // MARK: - Actions

    private func refreshHostedGate() {
        hostedGateReady = Spreedly.areAllFieldsValid(fieldTypes: hostedGateTypes)
    }

    @discardableResult
    private func validateAllMerchantFields(updateUI: Bool) -> Bool {
        var ok = true

        if fullNameEnabled {
            let err = DemoNameValidation.validate(fullName, isRequired: fullNameRequired)
            if updateUI { fullNameError = DemoNameValidation.message(for: err) }
            if err != nil { ok = false }
        } else if updateUI {
            fullNameError = nil
        }

        if addressEnabled {
            let err = DemoAddressValidation.validate(address, isRequired: addressRequired)
            if updateUI { addressError = DemoAddressValidation.message(for: err) }
            if err != nil { ok = false }
        } else if updateUI {
            addressError = nil
        }

        if cityEnabled {
            let err = DemoCityValidation.validate(city, isRequired: cityRequired)
            if updateUI { cityError = DemoCityValidation.message(for: err) }
            if err != nil { ok = false }
        } else if updateUI {
            cityError = nil
        }

        if stateEnabled {
            let err = DemoStateValidation.validate(state, isRequired: stateRequired)
            if updateUI { stateError = DemoStateValidation.message(for: err) }
            if err != nil { ok = false }
        } else if updateUI {
            stateError = nil
        }

        if zipEnabled {
            let err = DemoZipCodeValidation.validate(zip, isRequired: zipRequired)
            if updateUI { zipError = DemoZipCodeValidation.message(for: err) }
            if err != nil { ok = false }
        } else if updateUI {
            zipError = nil
        }

        return ok
    }

    private func buildAdditionalFields() -> [AdditionalField: String] {
        var map: [AdditionalField: String] = [:]
        if fullNameEnabled { map[.fullName] = fullName }
        if addressEnabled { map[.addressLine1] = address }
        if cityEnabled { map[.city] = city }
        if stateEnabled { map[.state] = state }
        if zipEnabled { map[.zipCode] = zip }
        return map
    }

    private func clearMerchantFields() {
        fullName = ""
        address = ""
        city = ""
        state = ""
        zip = ""
        fullNameError = nil
        addressError = nil
        cityError = nil
        stateError = nil
        zipError = nil
    }

    private func tokenize() {
        guard validateAllMerchantFields(updateUI: true) else {
            errorMessage = "Fix merchant field errors before paying."
            return
        }
        guard hostedGateReady else {
            errorMessage = "Complete card fields first."
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = nil

        Task {
            let signatureOK = await generateSignature()
            await MainActor.run {
                guard signatureOK else {
                    isLoading = false
                    errorMessage = "Failed to generate signature."
                    return
                }
                refreshHostedGate()
                guard hostedGateReady, validateAllMerchantFields(updateUI: true) else {
                    isLoading = false
                    errorMessage = "Fix invalid fields before paying."
                    return
                }

                let processing = Spreedly.shared().createCreditCard(
                    additionalFields: buildAdditionalFields(),
                    metadata: ["source": "CustomMerchantTextFieldsDemo"]
                )
                if processing.isValidationFailed {
                    isLoading = false
                    errorMessage = processing.getDescription()
                }
            }
        }
    }

    private func generateSignature() async -> Bool {
        let result = await SpreedlyConfigManager.shared.generateSignature()
        switch result {
        case .success(let ok): return ok
        case .failure: return false
        }
    }
}
