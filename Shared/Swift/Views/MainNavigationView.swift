//
//  MainNavigationView.swift
//  SpreedlySDKExample
//
//  Created by Vinay Naikade on 02/07/25.
//

import SwiftUI
import SpreedlyCore
import SpreedlyUI

struct MainNavigationView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Background color for the entire view - adaptive for dark mode
                backgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom title with Poppins font, 24px, medium weight, gray-700
                    Text("Spreedly Examples")
                        .font(customTitleFont)
                        .foregroundColor(titleColor)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Styled panel container
                    VStack(spacing: 0) {
                        List {
                            Section(header: Text("Spreedly SDK Examples")) {
                                NavigationLink(destination: CheckoutBasicView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Basic Checkout Component")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Default fields only (First Name, Last Name, Card Number, Expiry Date, CVC)")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.basicCheckoutLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.basicCheckoutLink)
                                .accessibilityHint(AccessibilityHints.Navigation.basicCheckoutLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: CheckoutWithAdditionalFieldsView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Checkout with Additional Fields")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Default fields plus address fields (Address, City, State, ZIP)")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.additionalFieldsLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.additionalFieldsLink)
                                .accessibilityHint(AccessibilityHints.Navigation.additionalFieldsLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: CustomFormView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Custom Form with Headless Components")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Custom form built at application level using headless UI components")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.customFormLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.customFormLink)
                                .accessibilityHint(AccessibilityHints.Navigation.customFormLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: CustomThemeFormView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Custom Theme Form")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Beautiful form with custom theme and modern design")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.customThemeLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.customThemeLink)
                                .accessibilityHint(AccessibilityHints.Navigation.customThemeLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: CVVRecachingView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("CVV Recaching")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Update CVV for saved payment methods to enable repeat transactions")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.cvvRecachingLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.cvvRecachingLink)
                                .accessibilityHint(AccessibilityHints.Navigation.cvvRecachingLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: ThreeDSPaymentFlowView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Global 3DS Challenge")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Complete 3DS authentication flow with product selection and payment")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.threeDSChallengeLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.threeDSChallengeLink)
                                .accessibilityHint(AccessibilityHints.Navigation.threeDSChallengeLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: GatewaySpecificThreeDSPaymentFlowView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Gateway Specific 3DS Challenge")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Complete 3DS authentication flow with product selection and payment")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.gatewaySpecific3DSChallengeLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.gatewaySpecific3DSChallengeLink)
                                .accessibilityHint(AccessibilityHints.Navigation.gatewaySpecific3DSChallengeLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: OffsitePaymentFlowView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Offsite Payment Flow")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Create offsite payment method and complete checkout")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.offsitePaymentFlowLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.offsitePaymentFlowLink)
                                .accessibilityHint(AccessibilityHints.Navigation.offsitePaymentFlowLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: EbanxPaymentFlowView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("EBANX Payment Flow")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("OXXO, Boleto, Pix, NuPay offsite payments")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.ebanxPaymentFlowLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.ebanxPaymentFlowLink)
                                .accessibilityHint(AccessibilityHints.Navigation.ebanxPaymentFlowLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: StripeAPMPaymentFlowView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Stripe APM Payment Flow")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("iDEAL, Bancontact, SEPA and other Stripe APMs via PaymentSheet")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.stripeAPMPaymentFlowLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.stripeAPMPaymentFlowLink)
                                .accessibilityHint(AccessibilityHints.Navigation.stripeAPMPaymentFlowLink)
                                .accessibilityAddTraits(.isButton)
                                
                                NavigationLink(destination: BraintreePaymentFlowView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Braintree Payment Flow")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("PayPal and Venmo payments via Braintree gateway")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier("navigation_braintree_payment_flow_link")
                                .accessibilityLabel("Braintree Payment Flow")
                                .accessibilityHint("Navigate to Braintree PayPal and Venmo payment example")
                                .accessibilityAddTraits(.isButton)

                                NavigationLink(destination: ClickToPayMerchantCheckoutView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Click to Pay Checkout")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Product checkout with Click to Pay — merchant reference flow")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier("navigation_click_to_pay_checkout_link")
                                .accessibilityLabel("Click to Pay Checkout")
                                .accessibilityHint("Navigate to merchant Click to Pay checkout example")
                                .accessibilityAddTraits(.isButton)

                                NavigationLink(destination: BankAccountCheckoutView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("ACH Bank Account")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Tokenize bank accounts via ACH with routing number, account number, and account type")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.bankAccountCheckoutLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.bankAccountCheckoutLink)
                                .accessibilityHint(AccessibilityHints.Navigation.bankAccountCheckoutLink)
                                .accessibilityAddTraits(.isButton)

                                NavigationLink(destination: BankAccountCustomFormView()) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("ACH Bank Account – Custom Form")
                                            .font(headerFont)
                                            .foregroundColor(textColor)
                                        Text("Headless ACH built field-by-field with SPLTextField and createBankAccount")
                                            .font(subheadingFont)
                                            .foregroundColor(textColor)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.bankAccountCustomFormLink)
                                .accessibilityLabel(AccessibilityLabels.Navigation.bankAccountCustomFormLink)
                                .accessibilityHint(AccessibilityHints.Navigation.bankAccountCustomFormLink)
                                .accessibilityAddTraits(.isButton)
                            }
                            
                            Section(header: Text("About")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Spreedly SDK for iOS")
                                    .font(.headline)
                                Text("This example demonstrates different ways to integrate the Spreedly SDK:")
                                    .font(.body)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• Complete checkout components")
                                    Text("• Headless UI components")
                                    Text("• Custom form implementations")
                                    Text("• Secure field handling")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .accessibilityIdentifier(AccessibilityIdentifiers.Navigation.aboutSection)
                            .accessibilityLabel(AccessibilityLabels.Navigation.aboutSection)
                            .accessibilityHint(AccessibilityHints.Navigation.aboutSection)
                        }
                        }
                        .listStyle(.plain)
                        .background(listBackgroundColor)
                    }
                    .background(listBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))  // Clip to rounded corners
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: 4, x: 0, y: 0)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .onAppear {
                    ValidationParamReset.reset()
                }
            }
        }
    }
    
    // MARK: - Adaptive Colors
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#000000") : Color(hex: "#FBFCFF")
    }
    
    private var titleColor: Color {
        colorScheme == .dark ? Color(hex: "#FFFFFF") : Color(hex: "#363A3A")
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color(hex: "#FFFFFF") : Color(hex: "#545859")
    }
    
    private var listBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#1C1C1E") : Color(hex: "#FFFFFF")
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#EFEDEA")
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color(hex: "#AFB4B5").opacity(0.8)
    }
    
    // Custom title font: Poppins, 24px, weight 500 (medium)
    private var customTitleFont: Font {
        if let poppinsMedium = UIFont(name: "Poppins-Medium", size: 24) {
            return Font(poppinsMedium)
        } else if let poppins = UIFont(name: "Poppins", size: 24) {
            return Font(poppins)
        } else {
            // Fallback to system font with medium weight
            return Font.system(size: 24, weight: .medium)
        }
    }
    
    // Header font: Poppins, 16px, weight 500 (medium)
    private var headerFont: Font {
        if let poppinsMedium = UIFont(name: "Poppins-Medium", size: 16) {
            return Font(poppinsMedium)
        } else if let poppins = UIFont(name: "Poppins", size: 16) {
            return Font(poppins)
        } else {
            return Font.system(size: 16, weight: .medium)
        }
    }
    
    // Subheading font: Poppins, 14px, weight 500 (medium)
    private var subheadingFont: Font {
        if let poppinsMedium = UIFont(name: "Poppins-Medium", size: 14) {
            return Font(poppinsMedium)
        } else if let poppins = UIFont(name: "Poppins", size: 14) {
            return Font(poppins)
        } else {
            return Font.system(size: 14, weight: .medium)
        }
    }
}

#Preview {
    MainNavigationView()
} 
