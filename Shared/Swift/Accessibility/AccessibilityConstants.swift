//
//  SPLAccessibilityIdentifiers.swift
//  MerchantExample
//
//
//

import Foundation

/// Centralized accessibility identifiers for the MerchantExample app
/// This helps reduce duplication and makes UI testing easier
public enum AccessibilityIdentifiers {
    
    // MARK: - Main Navigation
    public enum Navigation {
        public static let basicCheckoutLink = "basic-checkout-navigation-link"
        public static let additionalFieldsLink = "additional-fields-navigation-link"
        public static let customFormLink = "custom-form-navigation-link"
        public static let customThemeLink = "custom-theme-navigation-link"
        public static let cvvRecachingLink = "cvv-recaching-navigation-link"
        public static let threeDSChallengeLink = "three-ds-challenge-navigation-link"
        public static let gatewaySpecific3DSChallengeLink = "gateway-specific-3ds-challenge-navigation-link"
        public static let offsitePaymentFlowLink = "offsite-payment-flow-navigation-link"
        public static let ebanxPaymentFlowLink = "ebanx-payment-flow-navigation-link"
        public static let stripeAPMPaymentFlowLink = "stripe-apm-payment-flow-navigation-link"
        public static let aboutSection = "about-section"
    }
    
    // MARK: - Basic Checkout View
    public enum BasicCheckout {
        public static let title = "basic-checkout-title"
        public static let description = "basic-checkout-description"
        public static let defaultFieldsSection = "default-fields-section"
        public static let defaultFieldsTitle = "default-fields-title"
        public static let defaultFieldsList = "default-fields-list"
        public static let firstNameFieldItem = "default-fields-first-name"
        public static let lastNameFieldItem = "default-fields-last-name"
        public static let fullNameFieldItem = "default-fields-full-name"
        public static let cardNumberFieldItem = "default-fields-card-number"
        public static let expiryMonthFieldItem = "default-fields-expiry-month"
        public static let expiryYearFieldItem = "default-fields-expiry-year"
        public static let cvcFieldItem = "default-fields-cvc"
        public static let allowBlankNameToggle = "allow-blank-name-toggle"
        public static let allowExpiredDateToggle = "allow-expired-date-toggle"
        public static let allowBlankDateToggle = "allow-blank-date-toggle"
        public static let yearFormatPicker = "year-format-picker"
        public static let yearFormatLabel = "year-format-label"
        public static let yearFormatPickerContainer = "year-format-picker-container"
        public static let yearFormatTwoDigit = "year-format-two-digit"
        public static let yearFormatFourDigit = "year-format-four-digit"
        public static let configurationSection = "configuration-options-section"
        public static let configurationTitle = "configuration-options-title"
        public static let showFormButton = "show-basic-checkout-button"
        public static let successResultSection = "success-result-section"
        public static let successIcon = "success-result-icon"
        public static let successTitle = "success-result-title"
        public static let transactionTokenText = "transaction-token-text"
        public static let errorMessage = "error-message"
        public static let loadingProgressView = "loading-progress-view"
        public static let cardFormDropIn = "basic-checkout-card-form-dropin"
    }
    
    // MARK: - Additional Fields Checkout View
    public enum AdditionalFields {
        public static let title = "additional-fields-title"
        public static let description = "additional-fields-description"
        public static let defaultFieldsTitle = "additional-fields-default-fields-title"
        public static let firstNameFieldItem = "additional-fields-first-name-field-item"
        public static let lastNameFieldItem = "additional-fields-last-name-field-item"
        public static let cardNumberFieldItem = "additional-fields-card-number-field-item"
        public static let expiryMonthFieldItem = "additional-fields-expiry-month-field-item"
        public static let expiryYearFieldItem = "additional-fields-expiry-year-field-item"
        public static let cvcFieldItem = "additional-fields-cvc-field-item"
        public static let additionalFieldsTitle = "additional-fields-additional-fields-title"
        public static let addressLine1FieldItem = "additional-fields-address-line1-field-item"
        public static let addressLine2FieldItem = "additional-fields-address-line2-field-item"
        public static let cityFieldItem = "additional-fields-city-field-item"
        public static let stateFieldItem = "additional-fields-state-field-item"
        public static let zipCodeFieldItem = "additional-fields-zip-code-field-item"
        public static let fieldsListSection = "fields-list-section"
        public static let configurationTitle = "additional-fields-configuration-title"
        public static let yearFormatLabel = "additional-fields-year-format-label"
        public static let yearFormatTwoDigit = "additional-fields-year-format-two-digit"
        public static let yearFormatFourDigit = "additional-fields-year-format-four-digit"
        public static let allowBlankNameToggle = "additional-fields-allow-blank-name-toggle"
        public static let allowExpiredDateToggle = "additional-fields-allow-expired-date-toggle"
        public static let allowBlankDateToggle = "additional-fields-allow-blank-date-toggle"
        public static let yearFormatPicker = "additional-fields-year-format-picker"
        public static let configurationSection = "additional-fields-configuration-section"
        public static let showFormButton = "show-additional-fields-checkout-button"
        public static let successResultSection = "additional-fields-success-result-section"
        public static let errorMessage = "additional-fields-error-message"
        public static let cardFormDropIn = "additional-fields-card-form-dropin"
    }
    
    // MARK: - Custom Form View
    public enum CustomForm {
        public static let title = "custom-form-title"
        public static let description = "custom-form-description"
        public static let componentsTitle = "custom-form-components-title"
        public static let cardHolderNameComponent = "custom-form-card-holder-name-component"
        public static let cardNumberComponent = "custom-form-card-number-component"
        public static let cvcComponent = "custom-form-cvc-component"
        public static let expiryDateComponent = "custom-form-expiry-date-component"
        public static let componentsSection = "custom-form-components-section"
        public static let configurationTitle = "custom-form-configuration-title"
        public static let yearFormatLabel = "custom-form-year-format-label"
        public static let yearFormatTwoDigit = "custom-form-year-format-two-digit"
        public static let yearFormatFourDigit = "custom-form-year-format-four-digit"
        public static let allowBlankNameToggle = "custom-form-allow-blank-name-toggle"
        public static let allowExpiredDateToggle = "custom-form-allow-expired-date-toggle"
        public static let allowBlankDateToggle = "custom-form-allow-blank-date-toggle"
        public static let combinedExpiryDateToggle = "custom-form-combined-expiry-date-toggle"
        public static let yearFormatPicker = "custom-form-year-format-picker"
        public static let configurationSection = "custom-form-configuration-section"
        public static let cardHolderNameLabel = "custom-form-card-holder-name-label"
        public static let cardHolderNameField = "custom-form-card-holder-name-field"
        public static let cardNumberLabel = "custom-form-card-number-label"
        public static let cvcLabel = "custom-form-cvc-label"
        public static let expiryDateLabel = "custom-form-expiry-date-label"
        public static let expiryMonthLabel = "custom-form-expiry-month-label"
        public static let expiryYearLabel = "custom-form-expiry-year-label"
        public static let fieldsSection = "custom-form-fields-section"
        public static let payButton = "custom-form-pay-button"
        public static let successResultSection = "custom-form-success-result-section"
        public static let errorMessage = "custom-form-error-message"
    }
    
    // MARK: - Custom Theme Form View
    public enum CustomTheme {
        public static let title = "custom-theme-title"
        public static let subtitle = "custom-theme-subtitle"
        public static let header = "custom-theme-header"
        public static let configurationTitle = "custom-theme-configuration-title"
        public static let personalInfoTitle = "custom-theme-personal-info-title"
        public static let paymentInfoTitle = "custom-theme-payment-info-title"
        public static let allowBlankNameToggle = "custom-theme-allow-blank-name-toggle"
        public static let allowExpiredDateToggle = "custom-theme-allow-expired-date-toggle"
        public static let allowBlankDateToggle = "custom-theme-allow-blank-date-toggle"
        public static let configurationSection = "custom-theme-configuration-section"
        public static let personalInfoSection = "custom-theme-personal-info-section"
        public static let paymentInfoSection = "custom-theme-payment-info-section"
        public static let formSections = "custom-theme-form-sections"
        public static let payButton = "custom-theme-pay-button"
        public static let successResultSection = "custom-theme-success-result-section"
        public static let errorMessage = "custom-theme-error-message"
    }
    
    // MARK: - CVV Recaching View
    public enum CVVRecaching {
        public static let title = "cvv-recaching-title"
        public static let description = "cvv-recaching-description"
        public static let aboutTitle = "cvv-recaching-about-title"
        public static let aboutSection = "cvv-recaching-about-section"
        public static let aboutBulletPoint1 = "cvv-recaching-about-bullet-point-1"
        public static let aboutBulletPoint2 = "cvv-recaching-about-bullet-point-2"
        public static let aboutBulletPoint3 = "cvv-recaching-about-bullet-point-3"
        public static let aboutBulletPoint4 = "cvv-recaching-about-bullet-point-4"
        public static let cardsListTitle = "cvv-recaching-cards-list-title"
        public static let cardsListSection = "cvv-recaching-cards-list-section"
        public static let cardRow = "cvv-recaching-card-row"
        public static let emptyState = "cvv-recaching-empty-state"
        public static let loadingState = "cvv-recaching-loading-state"
        public static let recacheButton = "cvv-recaching-recache-button"
        public static let successResultSection = "cvv-recaching-success-result-section"
        public static let successIcon = "cvv-recaching-success-icon"
        public static let successTitle = "cvv-recaching-success-title"
        public static let updatedTokenText = "cvv-recaching-updated-token-text"
        public static let errorMessage = "cvv-recaching-error-message"
        public static let configurationTitle = "cvv-recaching-configuration-title"
        public static let configurationSection = "cvv-recaching-configuration-section"
        public static let presentationModeLabel = "cvv-recaching-presentation-mode-label"
        public static let presentationModePicker = "cvv-recaching-presentation-mode-picker"
        public static let presentationModeSheet = "cvv-recaching-presentation-mode-sheet"
        public static let presentationModeAlert = "cvv-recaching-presentation-mode-alert"
        public static let labelTextLabel = "cvv-recaching-label-text-label"
        public static let labelTextField = "cvv-recaching-label-text-field"
        public static let placeholderTextLabel = "cvv-recaching-placeholder-text-label"
        public static let placeholderTextField = "cvv-recaching-placeholder-text-field"
        public static let buttonTextLabel = "cvv-recaching-button-text-label"
        public static let buttonTextField = "cvv-recaching-button-text-field"
        public static let cancelButtonTextLabel = "cvv-recaching-cancel-button-text-label"
        public static let cancelButtonTextField = "cvv-recaching-cancel-button-text-field"
        public static let allowBlankNameToggle = "cvv-recaching-allow-blank-name-toggle"
        public static let allowExpiredDateToggle = "cvv-recaching-allow-expired-date-toggle"
        public static let allowBlankDateToggle = "cvv-recaching-allow-blank-date-toggle"
        public static let themeConfigurationTitle = "cvv-recaching-theme-configuration-title"
        public static let themeConfigurationSection = "cvv-recaching-theme-configuration-section"
        public static let useCustomThemeToggle = "cvv-recaching-use-custom-theme-toggle"
        public static let currentThemeLabel = "cvv-recaching-current-theme-label"
        public static let currentTheme = "cvv-recaching-current-theme"
        public static let customThemeColorsLabel = "cvv-recaching-custom-theme-colors-label"
        public static let blueThemeButton = "cvv-recaching-blue-theme-button"
        public static let greenThemeButton = "cvv-recaching-green-theme-button"
        public static let purpleThemeButton = "cvv-recaching-purple-theme-button"
        public static let resetThemeButton = "cvv-recaching-reset-theme-button"
    }
    
    // MARK: - 3DS Challenge View
    public enum ThreeDSChallenge {
        public static let title = "three-ds-challenge-title"
        public static let description = "three-ds-challenge-description"
        public static let payButton = "three-ds-challenge-pay-button"
        public static let successIcon = "three-ds-challenge-success-icon"
        public static let successTitle = "three-ds-challenge-success-title"
        public static let errorIcon = "three-ds-challenge-error-icon"
        public static let errorTitle = "three-ds-challenge-error-title"
        public static let errorMessage = "three-ds-challenge-error-message"
    }
    
    // MARK: - Offsite Payment Flow View
    public enum OffsitePayment {
        public static let navigationLink = "offsite-payment-flow-navigation-link"
        public static let title = "offsite-payment-title"
        public static let description = "offsite-payment-description"
        public static let providerSectionTitle = "offsite-payment-provider-section-title"
        public static let startButton = "offsite-payment-start-button"
        public static let providerRowPayPal = "offsite-payment-provider-row-paypal"
        public static let providerRowSprel = "offsite-payment-provider-row-sprel"
        public static let successIcon = "offsite-payment-success-icon"
        public static let successTitle = "offsite-payment-success-title"
        public static let pendingIcon = "offsite-payment-pending-icon"
        public static let pendingTitle = "offsite-payment-pending-title"
        public static let pendingMessage = "offsite-payment-pending-message"
        public static let errorIcon = "offsite-payment-error-icon"
        public static let errorTitle = "offsite-payment-error-title"
        public static let errorMessage = "offsite-payment-error-message"
    }
    
    // MARK: - EBANX Payment Flow View
    /// Use Navigation.ebanxPaymentFlowLink for the EBANX nav link (single source of truth).
    public enum EbanxPayment {
        public static let title = "ebanx-payment-title"
        public static let description = "ebanx-payment-description"
        public static let providerSectionTitle = "ebanx-payment-provider-section-title"
        public static let startButton = "ebanx-payment-start-button"
        public static let providerRowPix = "ebanx-payment-provider-row-pix"
        public static let providerRowBoleto = "ebanx-payment-provider-row-boleto"
        public static let providerRowOxxo = "ebanx-payment-provider-row-oxxo"
        public static let providerRowNupay = "ebanx-payment-provider-row-nupay"
        public static let successIcon = "ebanx-payment-success-icon"
        public static let successTitle = "ebanx-payment-success-title"
        public static let pendingIcon = "ebanx-payment-pending-icon"
        public static let pendingTitle = "ebanx-payment-pending-title"
        public static let pendingMessage = "ebanx-payment-pending-message"
        public static let errorIcon = "ebanx-payment-error-icon"
        public static let errorTitle = "ebanx-payment-error-title"
        public static let errorMessage = "ebanx-payment-error-message"
    }

    public enum StripeAPMPayment {
        public static let navigationLink = "stripe-apm-payment-flow-navigation-link"
        public static let title = "stripe-apm-payment-title"
        public static let description = "stripe-apm-payment-description"
        public static let apmSectionTitle = "stripe-apm-payment-apm-section-title"
        public static let startButton = "stripe-apm-payment-start-button"
        public static let successIcon = "stripe-apm-payment-success-icon"
        public static let successTitle = "stripe-apm-payment-success-title"
        public static let pendingIcon = "stripe-apm-payment-pending-icon"
        public static let pendingTitle = "stripe-apm-payment-pending-title"
        public static let pendingMessage = "stripe-apm-payment-pending-message"
        public static let errorIcon = "stripe-apm-payment-error-icon"
        public static let errorTitle = "stripe-apm-payment-error-title"
        public static let errorMessage = "stripe-apm-payment-error-message"
    }

    public enum BraintreePayment {
        public static let title = "braintree-payment-title"
        public static let description = "braintree-payment-description"
        public static let payButton = "braintree-payment-pay-button"
        public static let successIcon = "braintree-payment-success-icon"
        public static let successTitle = "braintree-payment-success-title"
        public static let successMessage = "braintree-payment-success-message"
        public static let pendingIcon = "braintree-payment-pending-icon"
        public static let pendingTitle = "braintree-payment-pending-title"
        public static let pendingMessage = "braintree-payment-pending-message"
        public static let errorIcon = "braintree-payment-error-icon"
        public static let errorTitle = "braintree-payment-error-title"
        public static let errorMessage = "braintree-payment-error-message"
    }
}

/// Centralized accessibility hints for the MerchantExample app
/// Provides descriptive hints for better accessibility support
public enum AccessibilityHints {
    
    // MARK: - Main Navigation
    public enum Navigation {
        public static let basicCheckoutLink = "Navigate to basic checkout form with default fields"
        public static let additionalFieldsLink = "Navigate to checkout form with additional address fields"
        public static let customFormLink = "Navigate to custom form built with headless components"
        public static let customThemeLink = "Navigate to custom themed payment form"
        public static let cvvRecachingLink = "Navigate to CVV recaching screen for saved payment methods"
        public static let threeDSChallengeLink = "Navigate to 3DS challenge demo screen"
        public static let gatewaySpecific3DSChallengeLink = "Navigate to Gateway Specific 3DS challenge demo screen"
        public static let offsitePaymentFlowLink = "Navigate to offsite payment flow screen"
        public static let ebanxPaymentFlowLink = "Navigate to EBANX payment flow screen"
        public static let stripeAPMPaymentFlowLink = "Navigate to Stripe APM payment flow screen"
        public static let aboutSection = "Information about the Spreedly SDK examples"
    }
    
    // MARK: - Basic Checkout View
    public enum BasicCheckout {
        public static let title = "Basic checkout component demonstration"
        public static let description = "Shows a complete checkout form with default payment fields"
        public static let defaultFieldsSection = "List of default fields included in the basic checkout"
        public static let defaultFieldsTitle = "Section title for default payment fields"
        public static let defaultFieldsList = "List container for default field items"
        public static let firstNameFieldItem = "First name field included in basic checkout"
        public static let lastNameFieldItem = "Last name field included in basic checkout"
        public static let fullNameFieldItem = "Full name field included in basic checkout"
        public static let cardNumberFieldItem = "Card number field included in basic checkout"
        public static let expiryMonthFieldItem = "Expiry month field included in basic checkout"
        public static let expiryYearFieldItem = "Expiry year field included in basic checkout"
        public static let cvcFieldItem = "CVC field included in basic checkout"
        public static let allowBlankNameToggle = "Toggle to allow or require card holder name"
        public static let allowExpiredDateToggle = "Toggle to allow or prevent expired card dates"
        public static let allowBlankDateToggle = "Toggle to allow or require expiration date"
        public static let yearFormatPicker = "Choose between 2-digit or 4-digit year format"
        public static let yearFormatLabel = "Label for year format selection"
        public static let yearFormatPickerContainer = "Container for year format picker"
        public static let yearFormatTwoDigit = "Two-digit year format option"
        public static let yearFormatFourDigit = "Four-digit year format option"
        public static let configurationSection = "Configuration options for the checkout form"
        public static let configurationTitle = "Section title for configuration options"
        public static let showFormButton = "Tap to display the basic checkout form"
        public static let successResultSection = "Payment processing result information"
        public static let successIcon = "Success indicator icon"
        public static let successTitle = "Payment success message"
        public static let transactionTokenText = "Transaction token from payment processing"
        public static let errorMessage = "Error message from payment processing"
        public static let loadingProgressView = "Loading indicator while processing payment"
        public static let cardFormDropIn = "Complete checkout form component"
    }
    
    // MARK: - Additional Fields Checkout View
    public enum AdditionalFields {
        public static let title = "Checkout with additional address fields"
        public static let description = "Shows checkout form with billing address fields"
        public static let defaultFieldsTitle = "Section title for default payment fields"
        public static let firstNameFieldItem = "First name field included in checkout"
        public static let lastNameFieldItem = "Last name field included in checkout"
        public static let cardNumberFieldItem = "Card number field included in checkout"
        public static let expiryMonthFieldItem = "Expiry month field included in checkout"
        public static let expiryYearFieldItem = "Expiry year field included in checkout"
        public static let cvcFieldItem = "CVC field included in checkout"
        public static let additionalFieldsTitle = "Section title for additional address fields"
        public static let addressLine1FieldItem = "Address line 1 field for billing information"
        public static let addressLine2FieldItem = "Address line 2 field for billing information (optional)"
        public static let cityFieldItem = "City field for billing information"
        public static let stateFieldItem = "State field for billing information"
        public static let zipCodeFieldItem = "ZIP code field for billing information"
        public static let yearFormatLabel = "Label for year format selection"
        public static let yearFormatTwoDigit = "Two-digit year format option"
        public static let yearFormatFourDigit = "Four-digit year format option"
        public static let configurationTitle = "Section title for configuration options"
        public static let fieldsListSection = "List of all fields including address information"
        public static let allowBlankNameToggle = "Toggle to allow or require card holder name"
        public static let allowExpiredDateToggle = "Toggle to allow or prevent expired card dates"
        public static let allowBlankDateToggle = "Toggle to allow or require expiration date"
        public static let yearFormatPicker = "Choose between 2-digit or 4-digit year format"
        public static let configurationSection = "Configuration options for the checkout form"
        public static let showFormButton = "Tap to display the checkout form with address fields"
        public static let successResultSection = "Payment processing result information"
        public static let errorMessage = "Error message from payment processing"
        public static let cardFormDropIn = "Complete checkout form with address fields"
    }
    
    // MARK: - Custom Form View
    public enum CustomForm {
        public static let title = "Custom payment form demonstration"
        public static let description = "Shows a custom form built with individual components"
        public static let componentsTitle = "Section title for form components list"
        public static let cardHolderNameComponent = "Card holder name component description"
        public static let cardNumberComponent = "Card number component description"
        public static let cvcComponent = "CVC component description"
        public static let expiryDateComponent = "Expiry date component description"
        public static let componentsSection = "List of form components used in custom form"
        public static let configurationTitle = "Section title for configuration options"
        public static let yearFormatLabel = "Label for year format selection"
        public static let yearFormatTwoDigit = "Two-digit year format option"
        public static let yearFormatFourDigit = "Four-digit year format option"
        public static let allowBlankNameToggle = "Toggle to allow or require card holder name"
        public static let allowExpiredDateToggle = "Toggle to allow or prevent expired card dates"
        public static let allowBlankDateToggle = "Toggle to allow or require expiration date"
        public static let combinedExpiryDateToggle = "Toggle to enable or disable combined expiry date field"
        public static let yearFormatPicker = "Choose between 2-digit or 4-digit year format"
        public static let configurationSection = "Configuration options for the custom form"
        public static let cardHolderNameLabel = "Label for card holder name field"
        public static let cardHolderNameField = "Enter the name as it appears on the card"
        public static let cardNumberLabel = "Label for card number field"
        public static let cvcLabel = "Label for security code field"
        public static let expiryDateLabel = "Label for expiry date field"
        public static let expiryMonthLabel = "Label for expiry month field"
        public static let expiryYearLabel = "Label for expiry year field"
        public static let fieldsSection = "Custom form input fields"
        public static let payButton = "Submit payment information"
        public static let successResultSection = "Payment processing result information"
        public static let errorMessage = "Error message from payment processing"
    }
    
    // MARK: - Custom Theme Form View
    public enum CustomTheme {
        public static let title = "Custom themed payment form"
        public static let subtitle = "Experience our beautiful custom theme design"
        public static let header = "Custom theme form header section"
        public static let configurationTitle = "Section title for configuration options"
        public static let personalInfoTitle = "Section title for personal information"
        public static let paymentInfoTitle = "Section title for payment information"
        public static let allowBlankNameToggle = "Toggle to allow or require card holder name"
        public static let allowExpiredDateToggle = "Toggle to allow or prevent expired card dates"
        public static let allowBlankDateToggle = "Toggle to allow or require expiration date"
        public static let configurationSection = "Configuration options for the themed form"
        public static let personalInfoSection = "Personal information input fields"
        public static let paymentInfoSection = "Payment information input fields"
        public static let formSections = "All form sections container"
        public static let payButton = "Submit payment with custom theme"
        public static let successResultSection = "Payment processing result information"
        public static let errorMessage = "Error message from payment processing"
    }
    
    // MARK: - CVV Recaching View
    public enum CVVRecaching {
        public static let title = "CVV recaching demonstration screen"
        public static let description = "Shows how to update CVV for saved payment methods"
        public static let aboutTitle = "Section title explaining CVV recaching"
        public static let aboutSection = "Information about CVV recaching functionality"
        public static let aboutBulletPoint1 = "Information about CVV storage security compliance"
        public static let aboutBulletPoint2 = "Information about CVV recaching for saved payment methods"
        public static let aboutBulletPoint3 = "Information about SDK secure UI for CVV entry"
        public static let aboutBulletPoint4 = "Information about using updated payment methods for transactions"
        public static let cardsListTitle = "Section title for saved payment methods list"
        public static let cardsListSection = "List of saved payment methods available for recaching"
        public static let emptyState = "Message shown when no saved payment methods are available"
        public static let loadingState = "Loading indicator while fetching payment methods"
        public static let recacheButton = "Button to trigger CVV recaching for selected card"
        public static let successResultSection = "CVV recaching success result information"
        public static let successIcon = "Success indicator icon"
        public static let successTitle = "CVV recaching success message"
        public static let updatedTokenText = "Updated payment method token after recaching"
        public static let errorMessage = "Error message from CVV recaching process"
        public static let configurationTitle = "Section title for configuration options"
        public static let configurationSection = "Configuration options for CVV recaching UI"
        public static let presentationModeLabel = "Label for presentation mode selection"
        public static let presentationModePicker = "Picker to choose between sheet or alert presentation"
        public static let presentationModeSheet = "Sheet presentation mode option"
        public static let presentationModeAlert = "Alert presentation mode option"
        public static let labelTextLabel = "Label for CVV input field label text"
        public static let labelTextField = "Text field to customize CVV input label"
        public static let placeholderTextLabel = "Label for placeholder text field"
        public static let placeholderTextField = "Text field to customize CVV placeholder text"
        public static let buttonTextLabel = "Label for button text field"
        public static let buttonTextField = "Text field to customize confirm button text"
        public static let cancelButtonTextLabel = "Label for cancel button text field"
        public static let cancelButtonTextField = "Text field to customize cancel button text"
        public static let allowBlankNameToggle = "Toggle to allow blank name in recaching request"
        public static let allowExpiredDateToggle = "Toggle to allow expired date in recaching request"
        public static let allowBlankDateToggle = "Toggle to allow blank date in recaching request"
        public static let themeConfigurationTitle = "Section title for theme configuration options"
        public static let themeConfigurationSection = "Theme configuration options for CVV recaching UI"
        public static let useCustomThemeToggle = "Toggle to enable or disable custom theme"
        public static let currentThemeLabel = "Label for current theme indicator"
        public static let currentTheme = "Current selected theme indicator"
        public static let customThemeColorsLabel = "Label for custom theme color options"
        public static let blueThemeButton = "Button to apply blue theme"
        public static let greenThemeButton = "Button to apply green theme"
        public static let purpleThemeButton = "Button to apply purple theme"
        public static let resetThemeButton = "Button to reset theme to default"
    }
    
    // MARK: - 3DS Challenge View
    public enum ThreeDSChallenge {
        public static let title = "3DS Challenge demonstration screen"
        public static let description = "Select a product and payment method, then proceed with the 3DS challenge flow"
        public static let payButton = "Tap to proceed with payment and 3DS challenge"
        public static let successIcon = "Success indicator icon"
        public static let successTitle = "Transaction success message"
        public static let errorIcon = "Error indicator icon"
        public static let errorTitle = "Error message title"
        public static let errorMessage = "Error message from 3DS challenge process"
    }
    
    // MARK: - Offsite Payment Flow View
    public enum OffsitePayment {
        public static let navigationLink = "Navigate to offsite payment flow screen"
        public static let title = "Offsite payment flow screen"
        public static let description = "Create offsite payment method, then purchase and complete checkout"
        public static let providerSectionTitle = "Section title for payment provider selection"
        public static let startButton = "Tap to start offsite payment flow"
        public static let providerRowPayPal = "Select PayPal as payment provider. Pay securely with PayPal account"
        public static let providerRowSprel = "Select Sprel as payment provider. Pay securely with Sprel account"
        public static let successIcon = "Success indicator icon"
        public static let successTitle = "Offsite checkout success message"
        public static let pendingIcon = "Pending indicator icon"
        public static let pendingTitle = "Pending message title"
        public static let pendingMessage = "Pending message from offsite payment process"
        public static let errorIcon = "Error indicator icon"
        public static let errorTitle = "Error message title"
        public static let errorMessage = "Error message from offsite payment process"
    }
    
    // MARK: - EBANX Payment Flow View
    public enum EbanxPayment {
        public static let title = "EBANX payment flow screen"
        public static let description = "Create EBANX offsite payment method, then purchase and complete checkout"
        public static let providerSectionTitle = "Section title for EBANX payment method selection"
        public static let startButton = "Tap to start EBANX payment flow"
        public static let providerRowPix = "Select Pix as payment method. Pay with QR code via banking app"
        public static let providerRowBoleto = "Select Boleto Bancario as payment method. Pay at bank or ATM"
        public static let providerRowOxxo = "Select OXXO as payment method. Pay with cash at OXXO store"
        public static let providerRowNupay = "Select NuPay as payment method. Pay via Nubank app"
        public static let successIcon = "Success indicator icon"
        public static let successTitle = "EBANX checkout success message"
        public static let pendingIcon = "Pending indicator icon"
        public static let pendingTitle = "Pending message title"
        public static let pendingMessage = "Pending message from EBANX payment process"
        public static let errorIcon = "Error indicator icon"
        public static let errorTitle = "Error message title"
        public static let errorMessage = "Error message from EBANX payment process"
    }

    public enum StripeAPMPayment {
        public static let navigationLink = "Navigate to Stripe APM payment flow screen"
        public static let title = "Stripe APM payment flow screen"
        public static let description = "Create a Stripe APM pending purchase and complete checkout via PaymentSheet"
        public static let apmSectionTitle = "Section title for Stripe APM type selection"
        public static let startButton = "Tap to start Stripe APM payment flow"
        public static let successIcon = "Success indicator icon"
        public static let successTitle = "Stripe APM checkout success message"
        public static let pendingIcon = "Pending indicator icon"
        public static let pendingTitle = "Pending message title"
        public static let pendingMessage = "Pending message from Stripe APM payment process"
        public static let errorIcon = "Error indicator icon"
        public static let errorTitle = "Error message title"
        public static let errorMessage = "Error message from Stripe APM payment process"
    }

    public enum BraintreePayment {
        public static let title = "Braintree payment flow screen"
        public static let description = "Create a Braintree purchase and complete checkout"
        public static let payButton = "Tap to start Braintree payment flow"
        public static let successIcon = "Success indicator icon"
        public static let successTitle = "Braintree checkout success message"
        public static let successMessage = "Success message from Braintree payment process"
        public static let pendingIcon = "Pending indicator icon"
        public static let pendingTitle = "Pending message title"
        public static let pendingMessage = "Pending message from Braintree payment process"
        public static let errorIcon = "Error indicator icon"
        public static let errorTitle = "Error message title"
        public static let errorMessage = "Error message from Braintree payment process"
    }
}

/// Centralized accessibility labels for the MerchantExample app
/// Provides descriptive labels for better accessibility support
public enum AccessibilityLabels {
    
    // MARK: - Main Navigation
    public enum Navigation {
        public static let basicCheckoutLink = "Basic Checkout Component"
        public static let additionalFieldsLink = "Checkout with Additional Fields"
        public static let customFormLink = "Custom Form with Headless Components"
        public static let customThemeLink = "Custom Theme Form"
        public static let cvvRecachingLink = "CVV Recaching"
        public static let threeDSChallengeLink = "3DS Challenge"
        public static let gatewaySpecific3DSChallengeLink = "Gateway Specific 3DS Challenge"
        public static let offsitePaymentFlowLink = "Offsite Payment Flow"
        public static let ebanxPaymentFlowLink = "EBANX Payment Flow"
        public static let stripeAPMPaymentFlowLink = "Stripe APM Payment Flow"
        public static let aboutSection = "About Spreedly SDK for iOS"
    }
    
    // MARK: - Basic Checkout View
    public enum BasicCheckout {
        public static let title = "Basic Checkout Component"
        public static let defaultFieldsTitle = "Default Fields"
        public static let firstNameFieldItem = "First Name"
        public static let lastNameFieldItem = "Last Name"
        public static let fullNameFieldItem = "Full Name"
        public static let cardNumberFieldItem = "Card Number"
        public static let expiryMonthFieldItem = "Expiry Month"
        public static let expiryYearFieldItem = "Expiry Year"
        public static let cvcFieldItem = "CVC"
        public static let allowBlankNameToggle = "Allow Blank Name"
        public static let allowExpiredDateToggle = "Allow Expired Date"
        public static let allowBlankDateToggle = "Allow Blank Date"
        public static let yearFormatLabel = "Year Format"
        public static let yearFormatTwoDigit = "YY"
        public static let yearFormatFourDigit = "YYYY"
        public static let configurationTitle = "Configuration Options"
        public static let successIcon = "Success"
        public static let successTitle = "Payment Successful"
        public static let transactionTokenText = "Transaction Token"
    }
    
    // MARK: - Additional Fields Checkout View
    public enum AdditionalFields {
        public static let defaultFieldsTitle = "Default Fields"
        public static let firstNameFieldItem = "First Name"
        public static let lastNameFieldItem = "Last Name"
        public static let cardNumberFieldItem = "Card Number"
        public static let expiryMonthFieldItem = "Expiry Month"
        public static let expiryYearFieldItem = "Expiry Year"
        public static let cvcFieldItem = "CVC"
        public static let additionalFieldsTitle = "Additional Fields"
        public static let addressLine1FieldItem = "Address Line 1"
        public static let addressLine2FieldItem = "Address Line 2"
        public static let cityFieldItem = "City"
        public static let stateFieldItem = "State"
        public static let zipCodeFieldItem = "ZIP Code"
        public static let yearFormatLabel = "Year Format"
        public static let yearFormatTwoDigit = "YY"
        public static let yearFormatFourDigit = "YYYY"
        public static let configurationTitle = "Configuration Options"
    }
    
    // MARK: - Custom Form View
    public enum CustomForm {
        public static let componentsTitle = "Form Components"
        public static let cardHolderNameComponent = "Card Holder Name Component"
        public static let cardNumberComponent = "Card Number Component"
        public static let cvcComponent = "CVC Component"
        public static let expiryDateComponent = "Expiry Date Component"
        public static let configurationTitle = "Configuration Options"
        public static let yearFormatLabel = "Year Format"
        public static let yearFormatTwoDigit = "YY"
        public static let yearFormatFourDigit = "YYYY"
        public static let cardHolderNameLabel = "Card Holder Name"
        public static let cardNumberLabel = "Card Number"
        public static let cvcLabel = "Security Code (CVC)"
        public static let expiryDateLabel = "Expiry Date"
        public static let expiryMonthLabel = "Expiry Month"
        public static let expiryYearLabel = "Expiry Year"
    }
    
    // MARK: - Custom Theme Form View
    public enum CustomTheme {
        public static let configurationTitle = "Configuration Options"
        public static let personalInfoTitle = "Personal Information"
        public static let paymentInfoTitle = "Payment Information"
        public static let allowBlankDateToggle = "Allow Blank Date"
    }
    
    // MARK: - CVV Recaching View
    public enum CVVRecaching {
        public static let title = "CVV Recaching"
        public static let aboutTitle = "About CVV Recaching"
        public static let aboutBulletPoint1 = "CVV values cannot be stored for security compliance"
        public static let aboutBulletPoint2 = "Recaching updates the CVV for saved payment methods"
        public static let aboutBulletPoint3 = "SDK provides secure UI for CVV entry"
        public static let aboutBulletPoint4 = "Updated payment method can be used for transactions"
        public static let cardsListTitle = "Saved Payment Methods"
        public static let loadingState = "Loading payment methods"
        public static let recacheButton = "Recache CVV"
        public static let successIcon = "Success"
        public static let successTitle = "CVV Recached Successfully"
        public static let updatedTokenText = "Updated Token"
        public static let configurationTitle = "Configuration Options"
        public static let presentationModeLabel = "Presentation Mode"
        public static let labelTextLabel = "Label Text"
        public static let placeholderTextLabel = "Placeholder Text"
        public static let buttonTextLabel = "Button Text"
        public static let cancelButtonTextLabel = "Cancel Button Text"
        public static let allowBlankNameToggle = "Allow Blank Name"
        public static let allowExpiredDateToggle = "Allow Expired Date"
        public static let allowBlankDateToggle = "Allow Blank Date"
        public static let themeConfigurationTitle = "Theme Configuration"
        public static let currentThemeLabel = "Current Theme"
        public static let customThemeColorsLabel = "Custom Theme Colors"
    }
    
    // MARK: - 3DS Challenge View
    public enum ThreeDSChallenge {
        public static let title = "3DS Challenge Flow"
        public static let description = "3DS Challenge Flow"
        public static let payButton = "Pay"
        public static let successIcon = "Success"
        public static let successTitle = "Success!"
        public static let errorIcon = "Error"
        public static let errorTitle = "Error"
        public static let errorMessage = "Error"
    }
    
    // MARK: - Offsite Payment Flow View
    public enum OffsitePayment {
        public static let navigationLink = "Offsite Payment Flow"
        public static let title = "Offsite Payment Flow"
        public static let description = "Create offsite payment method and complete checkout"
        public static let providerSectionTitle = "Select payment provider"
        public static let startButton = "Start Offsite Flow"
        public static let providerRowPayPal = "PayPal, Pay securely with PayPal account"
        public static let providerRowSprel = "Sprel, Pay securely with Sprel account"
        public static let successIcon = "Success"
        public static let successTitle = "Success"
        public static let pendingIcon = "Pending"
        public static let pendingTitle = "Pending"
        public static let pendingMessage = "Pending message"
        public static let errorIcon = "Error"
        public static let errorTitle = "Error"
        public static let errorMessage = "Error message"
    }
    
    // MARK: - EBANX Payment Flow View
    public enum EbanxPayment {
        public static let title = "EBANX Payment Flow"
        public static let description = "Create EBANX offsite payment and complete checkout"
        public static let providerSectionTitle = "Select EBANX payment method"
        public static let startButton = "Start EBANX Flow"
        public static let providerRowPix = "Pix, Pay with QR code via banking app"
        public static let providerRowBoleto = "Boleto Bancario, Pay at bank or ATM"
        public static let providerRowOxxo = "OXXO, Pay with cash at OXXO store"
        public static let providerRowNupay = "NuPay, Pay via Nubank app"
        public static let successIcon = "Success"
        public static let successTitle = "Success"
        public static let pendingIcon = "Pending"
        public static let pendingTitle = "Pending"
        public static let pendingMessage = "Pending message"
        public static let errorIcon = "Error"
        public static let errorTitle = "Error"
        public static let errorMessage = "Error message"
    }

    public enum StripeAPMPayment {
        public static let navigationLink = "Stripe APM Payment Flow"
        public static let title = "Stripe APM Payment Flow"
        public static let description = "Create Stripe APM pending purchase and complete checkout"
        public static let apmSectionTitle = "Select Stripe APM types"
        public static let startButton = "Start Stripe APM Flow"
        public static let successIcon = "Success"
        public static let successTitle = "Success"
        public static let pendingIcon = "Pending"
        public static let pendingTitle = "Pending"
        public static let pendingMessage = "Pending message"
        public static let errorIcon = "Error"
        public static let errorTitle = "Error"
        public static let errorMessage = "Error message"
    }

    public enum BraintreePayment {
        public static let title = "Braintree Payment Flow"
        public static let description = "Braintree checkout flow"
        public static let payButton = "Pay with Braintree"
        public static let successIcon = "Success"
        public static let successTitle = "Success"
        public static let successMessage = "Success message"
        public static let pendingIcon = "Pending"
        public static let pendingTitle = "Pending"
        public static let pendingMessage = "Pending message"
        public static let errorIcon = "Error"
        public static let errorTitle = "Error"
        public static let errorMessage = "Error message"
    }
}
