# Custom Payment Fields - Spreedly iOS SDK

Build fully customized payment forms with secure individual field components.

**Estimated time:** ~15 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [SPLTextField Component](#spltextfield-component)
5. [FormFieldType Options](#formfieldtype-options)
6. [Building a Custom Form (SwiftUI)](#building-a-custom-form-swiftui)
7. [Keyboard Navigation and Focus Management](#keyboard-navigation-and-focus-management)
8. [Additional Fields (Billing/Shipping)](#additional-fields-billingshipping)
9. [UIKit Integration](#uikit-integration)
10. [Save Card Option in Custom Forms](#save-card-option-in-custom-forms)
11. [Error Handling](#error-handling)
12. [Related Documentation](#related-documentation)

---

## Introduction

### What are Custom Fields?

Custom payment fields give you per-field control over each input in your payment form. Instead of using the pre-built `CardFormDropIn` (Express Checkout), you use individual `SPLTextField` components. Each field handles its own validation, formatting, and secure storage while you control the layout, styling, and flow.

### When to Use

Choose custom fields when you need:

- **Custom layout** – Non-standard field arrangement (e.g., card number above name, different column layouts)
- **Brand-specific design** – Full control over spacing, grouping, and visual hierarchy
- **Partial form** – Only some payment fields (e.g., CVC recache, card number only)
- **Additional field logic** – Billing/shipping fields with custom validation or conditional display

### Custom vs Express Comparison

| Feature | Express (CardFormDropIn) | Custom (SPLTextField) |
|---------|--------------------------|------------------------|
| UI | Built-in, complete form | Manual layout per field |
| Validation | Automatic | Per-field callbacks |
| Save Card checkbox | Built-in | Implement yourself |
| Integration effort | Low | Medium |
| Customization | Limited (theming, extra fields) | Full control |
| Field order | Fixed | Your choice |
| Keyboard navigation | Built-in | You implement with callbacks |

---

## Prerequisites

Complete [getting-started.md](getting-started.md) before using custom fields. You must:

- Add SpreedlyCore, SpreedlySecurity, and SpreedlyUI to your project
- Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`)
- Call `Spreedly.setup(config:)` with signature parameters from your backend before any tokenization
- Fetch signature parameters fresh for each payment session

> **Blocked device handling:** If you enable `blockJailbrokenDevices`, `SPLTextField` fields render as blank on compromised devices. Unlike `CardFormDropIn` (which auto-dismisses its sheet), custom forms are your UI — the SDK cannot dismiss them for you. Check `Spreedly.isDeviceTrusted` when the form appears and show an appropriate error:
>
> ```swift
> .onAppear {
>     if !Spreedly.isDeviceTrusted {
>         errorMessage = Spreedly.initializationError?.message ?? "SDK blocked by security check"
>     }
> }
> ```

---

## Quick Start

Minimal example with a single card number field. Subscribe to payment results before calling `createCreditCard()` — the method returns `PaymentProcessingResult` (validation status only); the actual token is delivered via the subscription.

```swift
import SwiftUI
import SpreedlyCore
import SpreedlyUI
import Combine

struct MinimalPaymentForm: View {
    @State private var cardNumberValid = false
    @State private var cancellable: AnyCancellable?

    var body: some View {
        VStack(spacing: 16) {
            SPLTextField(
                type: .cardNumber,
                title: "Card Number",
                isRequired: true,
                onValidationChange: { isValid in
                    cardNumberValid = isValid
                }
            )

            Button("Continue") {
                let result = Spreedly.shared().createCreditCard(
                    additionalFields: [:],
                    metadata: [:]
                )
                if result.isProcessing {
                    // Processing started -- await final result via subscription
                }
            }
            .disabled(!cardNumberValid)
        }
        .padding()
        .onAppear {
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                if result.isSuccess, let token = result.token {
                    // Payment method tokenized -- send token to your backend
                } else if result.isFailure {
                    // Handle failure
                }
            }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }
}
```

---

## SPLTextField Component

`SPLTextField` is a single unified component for all payment field types. You configure it with a `type` parameter and optional callbacks.

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `type` | `FormFieldType` | Field type (e.g., `.cardNumber`, `.firstName`) |
| `title` | `String?` | Label above the field |
| `isRequired` | `Bool` | Whether the field is required for validation |
| `placeholder` | `String?` | Custom placeholder text |
| `theme` | `SpreedlyTheme?` | Light mode theme |
| `darkTheme` | `SpreedlyTheme?` | Dark mode theme |
| `yearFormat` | `YearFormat` | `.twoDigit` or `.fourDigit` (default), applies to expiration fields |
| `keyboardType` | `UIKeyboardType` | Keyboard type (e.g., `.numberPad`, `.default`) |
| `textContentType` | `UITextContentType?` | Hint for autofill and keyboard optimization |
| `onValidationChange` | `((Bool) -> Void)?` | Called when validation state changes |
| `onSubmit` | `(() -> Void)?` | Called when user presses return/submit key |
| `submitLabel` | `SpreedlySubmitLabel?` | Label on keyboard return key. Example values: `.done`, `.go`, `.next`, `.send`, `.return`. See [SpreedlySubmitLabel](#spreedlysubmitlabel-enum) for all options. |
| `shouldFocus` | `Bool` | When true, the field becomes first responder (for programmatic focus) |
| `onFocus` | `(() -> Void)?` | Called when the field gains focus. Used with `shouldFocus` for programmatic field navigation (e.g., after card number is filled, focus moves to expiration date) |

#### Helper Properties and Methods

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `isValidForced` | `Bool` | Forces validation check and returns result |
| `hasValue` | `Bool` | Whether the field has a non-empty value |
| `inputLength` | `Int` | Current character count of the field's input |
| `clear()` | — | Clears the field's value |
| `reset()` | — | Resets the field to its initial state |

**YearFormat:** For `.expirationYear` and `.expirationDate` fields, use the `yearFormat` parameter to control whether the year is displayed and validated as 2-digit (`.twoDigit`, e.g. "25") or 4-digit (`.fourDigit`, e.g. "2025"). Default is `.fourDigit`.

---

## FormFieldType Options

Use the `type` parameter to specify the field behavior. The SDK applies validation, formatting, and secure storage based on the type.

| FormFieldType | Description | Typical Keyboard |
|---------------|-------------|------------------|
| `.firstName` | First name | `.default` |
| `.lastName` | Last name | `.default` |
| `.fullName` | Full name (single field) | `.default` |
| `.cardNumber` | Card number with formatting | `.numberPad` |
| `.expirationMonth` | Expiration month (01–12) | `.numberPad` |
| `.expirationYear` | Expiration year (2 or 4 digit) | `.numberPad` |
| `.expirationDate` | Combined expiration (MM/YY) | `.numberPad` |
| `.cvc` | Security code (CVC/CVV) | `.numberPad` |
| `.addressLine1` | Primary address | `.default` |
| `.addressLine2` | Secondary address | `.default` |
| `.city` | City | `.default` |
| `.state` | State/Province | `.default` |
| `.zipCode` | Postal/ZIP code | `.default` |

Both patterns are valid: use `.firstName` and `.lastName` for separate fields, or `.fullName` for a single combined name field.

> **Combined expiry field:** Instead of separate `.expirationMonth` and `.expirationYear` fields, you can use `.expirationDate` as a single combined MM/YY field. Use the `yearFormat` property (`.twoDigit` or `.fourDigit`) to control year display. This simplifies the form when a single expiration input is preferred.

---

## Building a Custom Form (SwiftUI)

Full example with all core payment fields, validation tracking, and submit handling:

```swift
import SwiftUI
import SpreedlyUI
import SpreedlyCore

struct CustomPaymentForm: View {
    @State private var cardNumberValid = false
    @State private var expirationMonthValid = false
    @State private var expirationYearValid = false
    @State private var cvcValid = false
    @State private var firstNameValid = false
    @State private var lastNameValid = false
    @State private var isFormValid = false
    @State private var focusedFieldType: FormFieldType?
    @State private var cancellable: AnyCancellable?

    private var fieldOrder: [FormFieldType] {
        [.firstName, .lastName, .cardNumber, .expirationMonth, .expirationYear, .cvc]
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                SPLTextField(
                    type: .firstName,
                    title: "First Name",
                    isRequired: true,
                    keyboardType: .default,
                    textContentType: .givenName,
                    onValidationChange: { isValid in
                        firstNameValid = isValid
                        updateFormValidity()
                    },
                    onSubmit: { handleFieldSubmit(for: .firstName) },
                    submitLabel: getSubmitLabel(for: .firstName),
                    shouldFocus: focusedFieldType == .firstName,
                    onFocus: { focusedFieldType = .firstName }
                )

                SPLTextField(
                    type: .lastName,
                    title: "Last Name",
                    isRequired: true,
                    keyboardType: .default,
                    textContentType: .familyName,
                    onValidationChange: { isValid in
                        lastNameValid = isValid
                        updateFormValidity()
                    },
                    onSubmit: { handleFieldSubmit(for: .lastName) },
                    submitLabel: getSubmitLabel(for: .lastName),
                    shouldFocus: focusedFieldType == .lastName,
                    onFocus: { focusedFieldType = .lastName }
                )
            }

            SPLTextField(
                type: .cardNumber,
                title: "Card Number",
                isRequired: true,
                keyboardType: .numberPad,
                textContentType: .creditCardNumber,
                onValidationChange: { isValid in
                    cardNumberValid = isValid
                    updateFormValidity()
                },
                onSubmit: { handleFieldSubmit(for: .cardNumber) },
                submitLabel: getSubmitLabel(for: .cardNumber),
                shouldFocus: focusedFieldType == .cardNumber,
                onFocus: { focusedFieldType = .cardNumber }
            )

            HStack(spacing: 16) {
                SPLTextField(
                    type: .expirationMonth,
                    title: "Month",
                    isRequired: true,
                    keyboardType: .numberPad,
                    onValidationChange: { isValid in
                        expirationMonthValid = isValid
                        updateFormValidity()
                    },
                    onSubmit: { handleFieldSubmit(for: .expirationMonth) },
                    submitLabel: getSubmitLabel(for: .expirationMonth),
                    shouldFocus: focusedFieldType == .expirationMonth,
                    onFocus: { focusedFieldType = .expirationMonth }
                )

                SPLTextField(
                    type: .expirationYear,
                    title: "Year",
                    isRequired: true,
                    keyboardType: .numberPad,
                    onValidationChange: { isValid in
                        expirationYearValid = isValid
                        updateFormValidity()
                    },
                    onSubmit: { handleFieldSubmit(for: .expirationYear) },
                    submitLabel: getSubmitLabel(for: .expirationYear),
                    shouldFocus: focusedFieldType == .expirationYear,
                    onFocus: { focusedFieldType = .expirationYear }
                )
            }

            SPLTextField(
                type: .cvc,
                title: "Security Code",
                isRequired: true,
                keyboardType: .numberPad,
                textContentType: .creditCardSecurityCode,
                onValidationChange: { isValid in
                    cvcValid = isValid
                    updateFormValidity()
                },
                onSubmit: { handleFieldSubmit(for: .cvc) },
                submitLabel: getSubmitLabel(for: .cvc),
                shouldFocus: focusedFieldType == .cvc,
                onFocus: { focusedFieldType = .cvc }
            )

            Button("Pay Now") {
                submitPayment()
            }
            .disabled(!isFormValid)
        }
        .padding()
        .onAppear {
            focusedFieldType = fieldOrder.first
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                if result.isSuccess, let token = result.token {
                    // Payment method tokenized -- send token to your backend
                } else if result.isFailure {
                    // Handle failure via result.failureDetails
                }
            }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }

    private func updateFormValidity() {
        isFormValid = cardNumberValid &&
                     expirationMonthValid &&
                     expirationYearValid &&
                     cvcValid &&
                     firstNameValid &&
                     lastNameValid
    }

    private func getSubmitLabel(for fieldType: FormFieldType) -> SpreedlySubmitLabel {
        guard let currentIndex = fieldOrder.firstIndex(of: fieldType) else {
            return .done
        }
        let isLastField = currentIndex == fieldOrder.count - 1
        return isLastField ? .done : .next
    }

    private func handleFieldSubmit(for fieldType: FormFieldType) {
        guard let currentIndex = fieldOrder.firstIndex(of: fieldType) else { return }
        let isLastField = currentIndex == fieldOrder.count - 1

        if isLastField {
            if isFormValid {
                submitPayment()
            }
        } else {
            let nextIndex = currentIndex + 1
            if nextIndex < fieldOrder.count {
                focusedFieldType = fieldOrder[nextIndex]
            }
        }
    }

    private func submitPayment() {
        let processingResult = Spreedly.shared().createCreditCard(
            additionalFields: [:],
            metadata: [:]
        )

        if processingResult.isValidationFailed {
            // Handle invalidFields, invalidAdditionalFields
        }
    }
}
```

---

## Keyboard Navigation and Focus Management

### fieldOrder Array

Define the tab order for your form:

```swift
private var fieldOrder: [FormFieldType] {
    [.firstName, .lastName, .cardNumber, .expirationMonth, .expirationYear, .cvc]
}
```

### handleFieldSubmit for Next/Done

When the user presses the keyboard return key, `onSubmit` fires. Use it to move focus or submit:

```swift
private func handleFieldSubmit(for fieldType: FormFieldType) {
    guard let currentIndex = fieldOrder.firstIndex(of: fieldType) else { return }
    let isLastField = currentIndex == fieldOrder.count - 1

    if isLastField {
        if isFormValid { submitPayment() }
    } else {
        let nextIndex = currentIndex + 1
        if nextIndex < fieldOrder.count {
            focusedFieldType = fieldOrder[nextIndex]
        }
    }
}
```

### SpreedlySubmitLabel Enum

Control the keyboard return key label:

```swift
public enum SpreedlySubmitLabel: Int {
    case `return` = 0    // Standard return key
    case done = 1        // "Done" button
    case go = 2          // "Go" button
    case search = 3      // "Search" button
    case send = 4        // "Send" button
    case next = 5        // "Next" (recommended for form navigation)
    case join = 6        // "Join" button
    case route = 7       // "Route" button
    case `continue` = 8  // "Continue" button
}
```

Use `.next` for intermediate fields and `.done` for the last field.

---

## Additional Fields (Billing/Shipping)

> **Naming clarification:** The SDK has two distinct concepts:
> - **`otherFields` / `FormField` array** -- extra UI fields passed to `CardFormDropIn` via its `otherFields:` parameter. These render additional `SPLTextField` components inside the drop-in form. See [express-checkout.md](express-checkout.md).
> - **`additionalFields` / `AdditionalField` dict** -- extra data (billing, shipping) passed to `createCreditCard(additionalFields:metadata:)` for tokenization. These are key-value pairs sent with the tokenization request.

For billing and shipping data, use `createCreditCard(additionalFields:metadata:)` and the `AdditionalField` enum. Non-sensitive fields can be regular `TextField`s; only card data must use `SPLTextField`.

### createCreditCard(additionalFields:metadata:shouldRetain:)

```swift
let processingResult = Spreedly.shared().createCreditCard(
    additionalFields: [
        .firstName: "John",
        .lastName: "Doe",
        .addressLine1: "123 Main St",
        .city: "Anytown",
        .state: "CA",
        .zipCode: "12345",
        .country: "US",
        .phoneNumber: "+1234567890",
        .email: "john.doe@example.com"
    ],
    metadata: ["orderId": "12345"],
    shouldRetain: true  // sets PaymentResult.shouldRetain; backend must call retain API separately
)
```

### AdditionalField Enum

**Billing fields:**

| Field | Description |
|-------|-------------|
| `.firstName` | First name |
| `.lastName` | Last name |
| `.fullName` | Full name |
| `.addressLine1` | Primary address |
| `.addressLine2` | Secondary address |
| `.city` | City |
| `.state` | State/Province |
| `.zipCode` | Postal/ZIP code |
| `.country` | Country code |
| `.phoneNumber` | Phone number |
| `.email` | Email address |

**Shipping fields:**

| Field | Description |
|-------|-------------|
| `.shippingAddress1` | Shipping address line 1 |
| `.shippingAddress2` | Shipping address line 2 |
| `.shippingCity` | Shipping city |
| `.shippingState` | Shipping state/province |
| `.shippingZip` | Shipping postal/ZIP code |
| `.shippingCountry` | Shipping country code |
| `.shippingPhoneNumber` | Shipping phone number |

### Field Fallback Logic

1. **SDK fields first** – If a value exists in the SDK's secure fields, that value is used.
2. **Additional fields fallback** – If the SDK field is empty, the value from `additionalFields` is used.
3. **Empty string default** – If neither has a value, an empty string is used.

### Validation: invalidAdditionalFields

When validation fails, check `invalidAdditionalFields` on `PaymentProcessingResult`:

```swift
let processingResult = Spreedly.shared().createCreditCard(
    additionalFields: [
        .email: "invalid-email",
        .firstName: "",
        .addressLine1: "123 Main St"
    ]
)

if processingResult.isValidationFailed {
    if !processingResult.invalidFields.isEmpty {
        // Invalid SDK form fields
    }
    if !processingResult.invalidAdditionalFields.isEmpty {
        for field in processingResult.invalidAdditionalFields {
            switch field {
            case .email:
                showError("Please enter a valid email address")
            case .firstName:
                showError("First name is required")
            default:
                showError("\(field.fieldName) is invalid")
            }
        }
    }
}
```

You can also use `hasInvalidAdditionalField(_:)`:

```swift
if processingResult.hasInvalidAdditionalField(.email) {
    highlightEmailField()
}
```

---

## UIKit Integration

Use `SPLTextFieldViewController` to embed individual fields in UIKit.

> **Themed initializer (Objective-C):** For themed fields in Objective-C, use `initWithField:title:isRequired:placeholder:keyboardType:textContentType:lightThemeConfig:darkThemeConfig:onValidationChange:onFocus:` with `SPLThemeConfig` instances. See [objective-c.md](objective-c.md#spltextfieldviewcontroller) for the full signature and example.

### Programmatic Setup

```swift
let cardNumberField = SPLTextFieldViewController(
    field: .cardNumber,
    title: "Card Number",
    isRequired: true,
    placeholder: nil,
    keyboardType: .numberPad,
    textContentType: .creditCardNumber,
    onValidationChange: { [weak self] isValid in
        // Update UI state
    },
    onSubmit: { [weak self] in
        self?.cvcField?.becomeFirstResponder()
    },
    submitLabel: .next,
    onFocus: nil
)

addChild(cardNumberField)
view.addSubview(cardNumberField.view)
cardNumberField.didMove(toParent: self)
```

### Storyboard

Add a container view where the field should appear, then instantiate and add the child view controller in code:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    let fieldVC = SPLTextFieldViewController(
        field: .cardNumber,
        title: "Card Number",
        isRequired: true
    )
    addChild(fieldVC)
    containerView.addSubview(fieldVC.view)
    fieldVC.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        fieldVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
        fieldVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        fieldVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        fieldVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ])
    fieldVC.didMove(toParent: self)
}
```

### Focus Management (UIKit)

Use `becomeFirstResponder` and `resignFirstResponder` to move focus between `SPLTextFieldViewController` instances in your `onSubmit` callbacks.

### Objective-C

Use `SPLTextFieldViewController` with the same pattern in Objective-C. Add the field as a child view controller and call `createCreditCardObjCWithAdditionalFields:metadata:` for tokenization:

```objc
SPLTextFieldViewController *cardNumberField = [[SPLTextFieldViewController alloc]
    initWithField:FormFieldTypeCardNumber
    title:@"Card Number"
    isRequired:YES
    placeholder:nil
    keyboardType:UIKeyboardTypeNumberPad
    textContentType:UITextContentTypeCreditCardNumber
    onValidationChange:^(BOOL valid) { /* update UI */ }
    onSubmit:^{ [self.cvcField becomeFirstResponder]; }
    submitLabel:SpreedlySubmitLabelNext
    onFocus:nil];

[self addChildViewController:cardNumberField];
[self.view addSubview:cardNumberField.view];
cardNumberField.view.translatesAutoresizingMaskIntoConstraints = NO;
// Add layout constraints for cardNumberField.view
[cardNumberField didMoveToParentViewController:self];

// For tokenization, implement SpreedlyPaymentDelegate and call:
PaymentProcessingResult *result = [[Spreedly shared] createCreditCardObjCWithAdditionalFields:@{} metadata:@{}];
```

Set `[Spreedly shared].paymentDelegate` **before** calling `createCreditCardObjC` to receive the token via `paymentDidComplete:`. When `result.isProcessing` is `YES`, the async tokenization is underway and the delegate will fire when it completes.

**Cleanup (Objective-C):** Call `[[Spreedly shared] reset]` in `viewWillDisappear:` and remove child `SPLTextFieldViewController` instances in `viewDidDisappear:`. See [objective-c.md](objective-c.md#cleanup-and-teardown) for full cleanup patterns.

---

## Save Card Option in Custom Forms

`CardFormDropIn` includes a built-in "Save card for future payments" checkbox. Custom forms do not. Implement it yourself:

```swift
struct CustomPaymentForm: View {
    @State private var shouldRetain = false
    // ... other state

    var body: some View {
        VStack(spacing: 16) {
            // Your SPLTextField fields

            Toggle("Save card for future payments", isOn: $shouldRetain)

            Button("Submit Payment") {
                processPayment()
            }
        }
        .onAppear {
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                if result.isSuccess, shouldRetain, let token = result.token {
                    savePaymentMethodForFutureUse(token: token)
                }
            }
        }
    }

    private func savePaymentMethodForFutureUse(token: String) {
        // Store token securely, send to backend, etc.
    }
}
```

In custom forms, pass the user's choice via the `shouldRetain` parameter on `createCreditCard(additionalFields:metadata:shouldRetain:)`. This sets `PaymentResult.shouldRetain` on success so your app knows the user opted in. **The SDK does not send a retain request to the Spreedly API** -- your backend must call the Spreedly retain endpoint separately if you want to vault the payment method for future use. See the example app's `RetainPaymentMethodAPIClient` for this pattern.

---

## Error Handling

### Validation Failures

Check `PaymentProcessingResult` after `createCreditCard`:

```swift
let result = Spreedly.shared().createCreditCard(
    additionalFields: additionalFields,
    metadata: [:]
)

if result.isValidationFailed {
    for fieldType in result.invalidFields {
        // Highlight invalid SDK fields
    }
    for additionalField in result.invalidAdditionalFields {
        // Highlight invalid additional fields
    }
}
```

### Payment Results

Subscribe to payment results before calling `createCreditCard`:

```swift
let cancellable = Spreedly.shared().subscribeToPaymentResults { result in
    if result.isSuccess {
        // Use result.token
    } else if result.isFailure {
        // Use result.failureDetails
    }
}
```

Cancel the subscription and reset validation parameters when the view disappears:

```swift
.onDisappear {
    cancellable?.cancel()
    cancellable = nil
    Spreedly.shared().setParam(parameter: .allowBlankName, value: false)
    Spreedly.shared().setParam(parameter: .allowExpiredDate, value: false)
    Spreedly.shared().setParam(parameter: .allowBlankDate, value: false)
}
```

Reset validation parameters in `onDisappear` to restore defaults when the form is dismissed.

---

## Related Documentation

- [express-checkout.md](express-checkout.md) – Pre-built payment form with `CardFormDropIn`
- [theme-and-styling.md](theme-and-styling.md) – Theming and customization
- [objective-c.md](objective-c.md) – Objective-C integration with delegates and wrappers
- [CARD_TOKENIZATION_FLOW.md](../development/CARD_TOKENIZATION_FLOW.md) – Detailed flow diagrams for card tokenization
