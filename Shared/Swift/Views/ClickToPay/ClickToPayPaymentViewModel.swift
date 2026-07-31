//
//  ClickToPayPaymentViewModel.swift
//  SpreedlySDKExample
//

import Combine
import Foundation
import SwiftUI
import SpreedlyCore
import SpreedlyClickToPay

enum DeviceRecognitionState: String {
    case checking = "Checking"
    case notRecognized = "NotRecognized"
    case recognized = "Recognized"
    case usingDifferentEmail = "UsingDifferentEmail"
}

@MainActor
final class ClickToPayPaymentViewModel: ObservableObject {
    enum Stage: String {
        case idle = "Idle"
        case checkout = "Checkout"
        case tokenizing = "Tokenize"
    }

    @Published var stage: Stage = .idle
    @Published var selectedProduct: Product?
    @Published var email = ""
    @Published var emailError: String?
    @Published var phoneError: String?
    @Published var firstNameError: String?
    @Published var lastNameError: String?
    /// Set when the shopper taps Pay — contact field errors show only after this.
    @Published private(set) var contactValidationAttempted = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var flowPhase: ClickToPayFlowState = .idle
    @Published var flowMessage = "Ready"
    @Published var scenarioHint = ClickToPaySandboxCatalog.scenario1Hint
    @Published var merchantPrefill = ClickToPayMerchantPrefill.qaDefault
    @Published private(set) var deviceRecognition: DeviceRecognitionState = .notRecognized
    @Published private(set) var recognizedCardLabels: [String] = []
    @Published private(set) var deviceDetectorKey = -1

    private let doLookup = true
    private var savedCardsDetectorController: ClickToPaySavedCardsDetectorController?
    private var skipDeviceDetectorOnNextScreenDisplay = false

    let products: [Product] = [
        Product(id: "c2p_sunglasses", name: "Sunglasses", price: 44, description: "Premium UV protection", iconName: "sunglasses"),
        Product(id: "c2p_watch", name: "Watch", price: 199, description: "Swiss precision", iconName: "applewatch"),
        Product(id: "c2p_headphones", name: "Headphones", price: 299, description: "Noise cancelling", iconName: "airpods"),
        Product(id: "c2p_camera", name: "Camera", price: 899, description: "Professional grade", iconName: "camera"),
        Product(id: "c2p_laptop", name: "Laptop", price: 1299, description: "Ultra portable", iconName: "laptopcomputer"),
        Product(id: "c2p_phone", name: "Phone", price: 999, description: "Latest model", iconName: "iphone"),
    ]

    private var cancellables = Set<AnyCancellable>()
    private var paymentCancellable: AnyCancellable?

    init() {
        email = ClickToPaySandboxCatalog.stableScenario1Email
        SpreedlyClickToPayCheckout.setAutoTokenizeAuthRefresher { [weak self] in
            await self?.refreshAuth() ?? false
        }
        subscribeToCheckout()
    }

    /// Pay is tappable once a product is selected and device recognition is not in progress.
    var isPayEnabled: Bool {
        selectedProduct != nil
            && stage == .idle
            && deviceRecognition != .checking
    }

    var showContactIdentityFields: Bool {
        deviceRecognition == .notRecognized || deviceRecognition == .usingDifferentEmail
    }

    var contactHint: String {
        switch deviceRecognition {
        case .checking:
            return "Checking whether this device has saved Click to Pay cards…"
        case .recognized:
            return "Your saved cards are ready. Tap Click to Pay to continue."
        case .usingDifferentEmail, .notRecognized:
            return ClickToPaySandboxCatalog.scenario1Hint
        }
    }

    var deviceDetectorConfig: ClickToPayCheckoutConfig {
        let amount = (selectedProduct?.price as NSDecimalNumber?)?.doubleValue ?? 100
        return ClickToPaySandboxCatalog.buildDeviceDetectorConfig(transactionAmount: amount)
    }

    /// Checkout config for `SpreedlyClickToPayButton` (rebuilt when product or merchant fields change).
    var merchantCheckoutConfig: ClickToPayCheckoutConfig {
        let amount = (selectedProduct?.price as NSDecimalNumber?)?.doubleValue ?? 100
        return ClickToPaySandboxCatalog.buildCheckoutConfig(
            email: email,
            doLookup: doLookup,
            transactionAmount: amount,
            merchantPrefill: merchantPrefill
        )
    }

    /// Validates merchant fields and refreshes auth before the SDK opens checkout (button `prepareForPresentation`).
    func prepareForCheckout() async -> Bool {
        guard selectedProduct != nil else {
            errorMessage = "Please select a product"
            return false
        }
        guard validateMerchantContactOnPay() else {
            if errorMessage == nil, let firstIssue = firstMerchantValidationIssue() {
                errorMessage = firstIssue
            }
            return false
        }

        guard await refreshAuth() else {
            errorMessage = "Failed to refresh auth params"
            return false
        }

        tearDownDeviceDetector()

        let dpaId = SpreedlyConfigManager.shared.c2pSandboxSrcDpaId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if dpaId.isEmpty || dpaId.hasPrefix("$(") {
            errorMessage = "Missing SpreedlyC2PSandboxSrcDpaId in Info.plist."
            return false
        }

        errorMessage = nil
        successMessage = nil
        stage = .checkout
        return true
    }

    func binding<T>(for keyPath: WritableKeyPath<ClickToPayMerchantPrefill, T>) -> Binding<T> {
        Binding(
            get: { self.merchantPrefill[keyPath: keyPath] },
            set: { self.merchantPrefill[keyPath: keyPath] = $0 }
        )
    }

    var firstNameBinding: Binding<String> {
        Binding(
            get: { self.merchantPrefill.firstName },
            set: { newValue in
                self.merchantPrefill.firstName = newValue
                if self.contactValidationAttempted { _ = self.validateBillingNames() }
            }
        )
    }

    var lastNameBinding: Binding<String> {
        Binding(
            get: { self.merchantPrefill.lastName },
            set: { newValue in
                self.merchantPrefill.lastName = newValue
                if self.contactValidationAttempted { _ = self.validateBillingNames() }
            }
        )
    }

    var phoneCountryCodeBinding: Binding<String> {
        Binding(
            get: { self.merchantPrefill.phoneCountryCode },
            set: { self.updatePhoneCountryCode($0) }
        )
    }

    var phoneNumberBinding: Binding<String> {
        Binding(
            get: { self.merchantPrefill.phoneNumber },
            set: { self.updatePhoneNumber($0) }
        )
    }

    func selectProduct(_ product: Product) {
        selectedProduct = product
        errorMessage = nil
        successMessage = nil
    }

    func onMerchantScreenDisplayed() {
        if skipDeviceDetectorOnNextScreenDisplay {
            skipDeviceDetectorOnNextScreenDisplay = false
            return
        }
        Task {
            deviceRecognition = .checking
            recognizedCardLabels = []
            guard await refreshAuth() else {
                deviceRecognition = .notRecognized
                errorMessage = "Failed to initialize Spreedly SDK for Click to Pay."
                return
            }
            guard Spreedly.isInitialized else {
                deviceRecognition = .notRecognized
                return
            }
            deviceDetectorKey += 1
        }
    }

    func onDetectorControllerReady(_ controller: ClickToPaySavedCardsDetectorController) {
        savedCardsDetectorController = controller
    }

    func onDeviceDetectionResult(_ result: ClickToPaySavedCardsDetectionResult) {
        guard deviceRecognition != .usingDifferentEmail else { return }
        if result.hasSavedCards {
            recognizedCardLabels = result.savedCards.map(ClickToPaySandboxCatalog.label(for:))
            deviceRecognition = .recognized
        } else {
            recognizedCardLabels = []
            deviceRecognition = .notRecognized
        }
    }

    func useDifferentEmail() {
        deviceRecognition = .usingDifferentEmail
        recognizedCardLabels = []
        email = ""
        emailError = nil
        phoneError = nil
        merchantPrefill.phoneCountryCode = ""
        merchantPrefill.phoneNumber = ""
        savedCardsDetectorController?.signOut()
    }

    func updateEmail(_ value: String) {
        if treatsDeviceAsRecognized(), value != email {
            useDifferentEmail()
        }
        email = value
        refreshCustomerIdentityValidity()
    }

    func updatePhoneCountryCode(_ value: String) {
        if treatsDeviceAsRecognized() {
            useDifferentEmail()
        }
        merchantPrefill.phoneCountryCode = value.filter(\.isNumber)
        refreshCustomerIdentityValidity()
    }

    func updatePhoneNumber(_ value: String) {
        if treatsDeviceAsRecognized() {
            useDifferentEmail()
        }
        merchantPrefill.phoneNumber = value.filter(\.isNumber)
        refreshCustomerIdentityValidity()
    }

    @discardableResult
    func validateCustomerIdentity() -> Bool {
        if treatsDeviceAsRecognized() {
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedEmail.isEmpty, !EmailValidator.isValid(trimmedEmail) {
                emailError = "Invalid email format"
                return false
            }
            emailError = nil
            phoneError = nil
            return true
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = merchantPrefill.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let countryCode = merchantPrefill.phoneCountryCode.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasValidEmail = !trimmedEmail.isEmpty && EmailValidator.isValid(trimmedEmail)
        let hasPhoneLookup = !phone.isEmpty && !countryCode.isEmpty
        let partialPhone = (!phone.isEmpty) != (!countryCode.isEmpty)

        if hasValidEmail || hasPhoneLookup {
            emailError = nil
            phoneError = nil
            return true
        }

        if !trimmedEmail.isEmpty && !EmailValidator.isValid(trimmedEmail) {
            emailError = "Invalid email format"
        } else {
            emailError = nil
        }

        phoneError = partialPhone
            ? "Country code and mobile number are both required for phone lookup"
            : "Email or phone with country code is required"
        return false
    }

    func cancelCheckout() {
        SpreedlyClickToPayCheckout.cancel()
    }

    /// Validates contact identity and billing names when the merchant taps Pay.
    @discardableResult
    func validateMerchantContactOnPay() -> Bool {
        contactValidationAttempted = true
        let identityValid = validateCustomerIdentity()
        let namesValid = validateBillingNames()
        return identityValid && namesValid
    }

    func firstMerchantValidationIssue() -> String? {
        if let emailError, !emailError.isEmpty { return emailError }
        if let phoneError, !phoneError.isEmpty { return phoneError }
        if let firstNameError, !firstNameError.isEmpty { return firstNameError }
        if let lastNameError, !lastNameError.isEmpty { return lastNameError }
        return "Please complete the required checkout fields."
    }

    @discardableResult
    func validateBillingNames() -> Bool {
        let first = merchantPrefill.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = merchantPrefill.lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        if first.isEmpty {
            firstNameError = "First name is required"
        } else {
            firstNameError = nil
        }

        if last.isEmpty {
            lastNameError = "Last name is required"
        } else {
            lastNameError = nil
        }

        return !first.isEmpty && !last.isEmpty
    }

    static func hasValidCustomerIdentity(
        deviceRecognition: DeviceRecognitionState,
        email: String,
        phoneNumber: String,
        phoneCountryCode: String
    ) -> Bool {
        if deviceRecognition == .recognized {
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedEmail.isEmpty || EmailValidator.isValid(trimmedEmail)
        }
        return hasValidCustomerIdentity(
            email: email,
            phoneNumber: phoneNumber,
            phoneCountryCode: phoneCountryCode
        )
    }

    static func hasValidCustomerIdentity(
        email: String,
        phoneNumber: String,
        phoneCountryCode: String
    ) -> Bool {
        let customer = ClickToPayCustomer(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            countryCode: phoneCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailValid = trimmedEmail.isEmpty || EmailValidator.isValid(trimmedEmail)
        return emailValid && customer.isValidForLookup()
    }

    private func refreshCustomerIdentityValidity() {
        if contactValidationAttempted || emailError != nil || phoneError != nil {
            _ = validateCustomerIdentity()
        }
    }

    private func refreshAuth() async -> Bool {
        switch await SpreedlyConfigManager.shared.generateSignature() {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    private func subscribeToCheckout() {
        SpreedlyClickToPayCheckout.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleClickToPayEvent(event)
            }
            .store(in: &cancellables)

        SpreedlyClickToPayCheckout.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.flowPhase = snapshot.phase
                self?.flowMessage = snapshot.message
            }
            .store(in: &cancellables)

        paymentCancellable = Spreedly.shared().subscribeToPaymentResults { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if result.isSuccess, let token = result.token {
                    self.successMessage = "Payment method tokenized: \(Spreedly.maskedToken(token))"
                    self.stage = .idle
                    self.markPaymentFlowCompleted()
                } else if let msg = result.failureDetails?.message, self.stage != .idle {
                    self.errorMessage = msg
                    self.stage = .idle
                    self.remountDeviceDetectorAfterCheckoutInterrupted()
                }
            }
        }
    }

    private func handleClickToPayEvent(_ event: ClickToPayEvent) {
        switch event {
        case .checkoutComplete:
            stage = .tokenizing
        case .otpNotYou:
            if stage == .checkout || stage == .tokenizing {
                errorMessage = nil
                successMessage = nil
                stage = .idle
                remountDeviceDetectorAfterCheckoutInterrupted()
            }
        case .sessionDeleted:
            if stage == .checkout || stage == .tokenizing {
                errorMessage = nil
                successMessage = nil
                stage = .idle
                remountDeviceDetectorAfterCheckoutInterrupted()
            }
        case .checkoutCancelled:
            if stage == .checkout || stage == .tokenizing {
                errorMessage = "Checkout was canceled."
                stage = .idle
                remountDeviceDetectorAfterCheckoutInterrupted()
            }
        case .paymentMethodTokenized:
            stage = .idle
            markPaymentFlowCompleted()
        case .checkoutError(_, let actionCode):
            if stage != .idle {
                errorMessage = "Checkout error (\(actionCode))."
                stage = .idle
                remountDeviceDetectorAfterCheckoutInterrupted()
            }
        case .validationErrors(_, let errors):
            if stage != .idle {
                errorMessage = errors.first?.message ?? "Validation failed."
                stage = .idle
                remountDeviceDetectorAfterCheckoutInterrupted()
            }
        case .error(_, _, let message):
            if stage != .idle {
                errorMessage = message
                stage = .idle
                remountDeviceDetectorAfterCheckoutInterrupted()
            }
        default:
            break
        }
    }

    private func treatsDeviceAsRecognized() -> Bool {
        deviceRecognition == .recognized
    }

    private func tearDownDeviceDetector() {
        savedCardsDetectorController = nil
        if deviceDetectorKey >= 0 {
            deviceDetectorKey = -1
        }
    }

    private func remountDeviceDetectorAfterCheckoutInterrupted() {
        skipDeviceDetectorOnNextScreenDisplay = false
        let keepDifferentEmailUi = deviceRecognition == .usingDifferentEmail
        if !keepDifferentEmailUi {
            deviceRecognition = .checking
            recognizedCardLabels = []
        }
        deviceDetectorKey = max(deviceDetectorKey, 0) + 1
    }

    private func markPaymentFlowCompleted() {
        skipDeviceDetectorOnNextScreenDisplay = true
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
