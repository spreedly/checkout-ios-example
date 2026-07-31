# ACH Bank Account Payments - Spreedly iOS SDK

Tokenize bank accounts (US ABA routing numbers and Canadian routing numbers) with the Spreedly iOS SDK. Three integration paths are available.

**Estimated integration time:** ~15 minutes

> **Example app:** Spreedly's iOS sample app ships working demos for every integration path in both Swift and Objective-C — drop-in via `BankAccountFormDropIn` / `BankAccountFormDropInViewController`, and headless / custom layout via `SPLTextField` per field plus a direct call to `Spreedly.shared().createBankAccount(...)`.

## Table of Contents

1. [Introduction](#introduction)
2. [Required and Optional Fields](#required-and-optional-fields)
3. [Prerequisites](#prerequisites)
4. [Pre-built Drop-In Form (Express)](#pre-built-drop-in-form-express)
5. [Custom Layout](#custom-layout)
6. [Headless Flow](#headless-flow)
7. [Field Configuration](#field-configuration)
8. [Result States](#result-states)
9. [Backend API](#backend-api)
10. [SwiftUI Integration](#swiftui-integration)
11. [UIKit Integration](#uikit-integration)
12. [Objective-C Integration](#objective-c-integration)
13. [Validation Rules](#validation-rules)
14. [Security](#security)
15. [Important Notes](#important-notes)
16. [Troubleshooting](#troubleshooting)
17. [Iframe to iOS migration](#iframe-to-ios-migration)
18. [Related Documentation](#related-documentation)

---

## Introduction

ACH support tokenizes a bank account into a Spreedly `payment_method_token` which your backend then uses for `purchase` or `authorize` calls (same as a card token). The SDK provides three integration paths:

| Path | When to use |
|---|---|
| **`BankAccountFormDropIn`** | Quick integration with a pre-built UI. Good default for most merchants. |
| **Custom layout** | You want your own visual layout but the SDK's `SPLTextField` for the sensitive routing/account fields. |
| **Headless** | Fully custom UI; you call `Spreedly.shared().createBankAccount(...)` directly. |

All three paths return results through the same `paymentResultPublisher` / `SpreedlyPaymentDelegate` channel used for credit cards.

> **Release status:** ACH bank-account tokenization ships in **1.5.0+** (see [CHANGELOG](../CHANGELOG.md) `## [1.5.0]`).

### When to use ACH vs. credit card

ACH is typically a lower-cost rail for higher-value or recurring transactions in the US/Canada. The SDK does not opine on routing — that's a gateway / merchant decision. The SDK only handles tokenization.

---

## Required and Optional Fields

The Spreedly API requires:

| Field | Required | Notes |
|-------|----------|-------|
| Routing number | Yes | 9-digit ABA (US) or 9-digit Canadian routing number (leading `0`) |
| Account number | Yes | 4-17 numeric digits |
| Name | Yes | Either `full_name` OR `first_name` + `last_name` (unless `allowBlankName` is enabled) |

Optional fields:

| Field | Default | Notes |
|---|---|---|
| Account type | `checking` (alternative: `savings`) | Drives `bank_account_type` |
| Account holder type | `personal` (alternative: `business`) | Drives `bank_account_holder_type` |
| Bank name | Not shown by default | Display attribute (e.g. `"Chase Bank"`) |
| Email | Not collected by default | Lifted to `payment_method.email` |
| Metadata | Not collected by default | Lifted to `payment_method.metadata` |

---

## Prerequisites

1. Complete [getting-started.md](getting-started.md) (installation and basic SDK setup).
2. Call `Spreedly.initializeSDK()` at app launch (e.g. in `App.init()` or `AppDelegate`).
3. Call `Spreedly.setup(config:)` with `environmentKey`, `forterSiteId`, and signature parameters (`nonce`, `signature`, `certificateToken`, `timestamp`) **before** presenting the form.
4. Subscribe to `Spreedly.shared().subscribeToPaymentResults(...)` (Swift) or set `Spreedly.shared().paymentDelegate` (Objective-C) **before** presenting the form.

---

## Pre-built Drop-In Form (Express)

The simplest integration. `BankAccountFormDropIn` is a full SwiftUI form (UIKit wrapper available too). It collects routing/account/name plus any optional fields you've enabled, validates as the user types, and on submit calls `Spreedly.shared().createBankAccount(...)`.

**Drop-in UX (current SDK):**

- Submit button label is **Checkout** (Android parity), not the card drop-in “Pay now” string.
- Name fields use ACH-specific titles and required errors (not card “First name” / “Last name” defaults).
- Optional **Bank Name** uses `SPLTextField(type: .bankName)` inside the drop-in when enabled in `BankAccountFieldConfig`.
- Account type / holder type segmented controls use the sheet theme primary color.

### SwiftUI

```swift
import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI

struct BankCheckoutView: View {
    @State private var showSheet = false
    @State private var cancellable: AnyCancellable?

    var body: some View {
        Button("Pay with Bank Account") { showSheet = true }
            .sheet(isPresented: $showSheet) {
                BankAccountFormDropIn(
                    fieldConfig: .default,
                    onProcessingResult: { result in
                        if result.isProcessing { /* show loading */ }
                        else if result.isValidationFailed { /* show result.getDescription() */ }
                    }
                )
            }
            .onAppear {
                cancellable = Spreedly.shared().subscribeToPaymentResults { paymentResult in
                    if paymentResult.isSuccess {
                        showSheet = false
                        // Send paymentResult.token to your backend
                    } else if paymentResult.isFailure {
                        // Show paymentResult.failureDetails?.getDescription()
                    }
                }
            }
            .onDisappear { cancellable?.cancel() }
    }
}
```

`BankAccountFormDropIn` applies screen prevention automatically. For custom/`SPLTextField` ACH UI, apply `.screenPrevention()` yourself.

### UIKit

```swift
import UIKit
import Combine
import SpreedlyUI

class PaymentViewController: UIViewController {
    var cancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        cancellable = Spreedly.shared().subscribeToPaymentResults { [weak self] paymentResult in
            if paymentResult.isSuccess {
                self?.dismiss(animated: true)
            }
        }
    }

    func showBankForm() {
        let dropInVC = BankAccountFormDropInViewController(
            fieldConfig: .default,
            onProcessingResult: { result in
                if result.isProcessing { /* show loading */ }
                else if result.isValidationFailed { /* show result.getDescription() */ }
            }
        )
        // Built-in screen prevention — present directly.
        present(dropInVC, animated: true)
    }

    deinit { cancellable?.cancel() }
}
```

---

## Custom Layout

Build your own form using `SPLTextField` for routing number, account number, and any SDK-managed display fields such as Bank Name. The values register with the SDK until submission. When ready, call `Spreedly.shared().createBankAccount(...)`.

```swift
import SwiftUI
import SpreedlyCore
import SpreedlyUI

struct CustomBankForm: View {
    var body: some View {
        VStack(spacing: 12) {
            SPLTextField(
                type: .fullName,
                title: "Account Holder Name",
                isRequired: true,
                requiredMessage: "Name is required"
            )
            SPLTextField(type: .bankName, title: "Bank Name", isRequired: false)
            SPLTextField(type: .routingNumber, title: "Routing Number", isRequired: true)
            SPLTextField(type: .accountNumber, title: "Account Number", isRequired: true)

            Button("Checkout") {
                let result = Spreedly.shared().createBankAccount(
                    additionalFields: [:],
                    bankAccountType: .checking,
                    bankAccountHolderType: .personal,
                    metadata: nil
                )
                // result is `.processing` or `.validationFailed`;
                // success/failure arrive via subscribeToPaymentResults.
            }
        }
        .screenPrevention()
    }
}
```

If your app owns Bank Name outside `SPLTextField`, continue passing it through the `bankName:` parameter on `createBankAccount(...)`; an explicit parameter value takes precedence over any collected `.bankName` field.

---

## Headless Flow

Use `additionalFields` for non-sensitive values (name, email, metadata) when you are not collecting them in `SPLTextField`. **Routing and account numbers must still be entered through `SPLTextField`** (or registered in `SecureValueContainer`) — there is no plain-text path for those fields.

At tokenize time, `createBankAccount` and `createCreditCard` resolve holder names from secure-container values first, then fall back to matching `AdditionalField` entries when a secure value is empty (Android parity). Prefer one shape per flow: either `full_name` or `first_name` + `last_name`, not a mix.

```swift
let result = Spreedly.shared().createBankAccount(
    additionalFields: [
        .fullName: "Jane Doe",
        .email: "jane@example.com"
    ],
    bankAccountType: .savings,
    bankAccountHolderType: .business,
    bankName: "Chase Bank",
    metadata: ["order_id": "12345"],
    allowBlankName: false
)
```

The form-field validation still runs against the registered `.routingNumber` and `.accountNumber` `SPLTextField` instances; if those aren't present and valid, you'll get back `.validationFailed`.

---

## Field Configuration

`BankAccountFieldConfig` controls which optional fields appear in `BankAccountFormDropIn`.

### Presets

| Preset | Name fields | Bank Name | Account Type | Holder Type |
|---|---|---|---|---|
| `.default` | Single full-name field | Hidden | Shown | Shown |
| `.minimal` | Single full-name field | Hidden | Hidden | Hidden |
| `.full` | Single full-name field | Shown | Shown | Shown |

### Custom configuration

```swift
let config = BankAccountFieldConfig(
    nameDisplayMode: .separateFields,  // First Name + Last Name
    showBankName: true,
    bankNameLabel: "Issuing Bank",
    bankNameRequired: false,
    showAccountType: true,
    accountTypeLabel: nil,             // uses localized default
    showAccountHolderType: false,
    accountHolderTypeLabel: nil
)
```

### Name display modes

- `.singleField` — one account-holder name field that maps to `full_name` on the wire
- `.separateFields` — separate first and last name fields with ACH-specific labels (not card “First name” / “Last name” copy)

In custom layouts, pass `requiredMessage: "Name is required"` (or your own string) on name `SPLTextField` instances so required/min/max errors stay bank-appropriate instead of card defaults.

---

## Result States

The same callback channels used by credit-card flows apply to ACH:

| Channel | Delivers | Use |
|---|---|---|
| `onProcessingResult` (callback on the form) | `.processing` or `.validationFailed` | Show loading or field errors |
| `subscribeToPaymentResults` (Swift) / `paymentDelegate` (ObjC) | `PaymentResult.success(token)` or `.failure(details)` | Use the token / show error |

| Result state | Meaning | Recommended UX |
|---|---|---|
| `.isProcessing` | Validation passed, request started | Show loading indicator |
| `.isValidationFailed` | Client-side validation failed | Show field errors via `getDescription()` |
| `PaymentResult.isSuccess` | Tokenization succeeded | Use `result.token`, dismiss form, call backend |
| `PaymentResult.isFailure` (`.apiError`) | Spreedly API rejected the request | Show `failureDetails.getDescription()`; field-level errors flow through `errorHandler` |
| `PaymentResult.isFailure` (`.networkError`) | Couldn't reach Spreedly API | Offer retry |

---

## Backend API

After a successful tokenization, your backend uses the returned token to charge or authorize via the gateway:

```bash
curl -X POST https://core.spreedly.com/v1/gateways/${GATEWAY_TOKEN}/purchase.json \
  -u ${ENVIRONMENT_KEY}:${ACCESS_SECRET} \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "payment_method_token": "ABC...payment_method_token",
      "amount": 1000,
      "currency_code": "USD"
    }
  }'
```

The SDK does **not** call `purchase` / `authorize` — that's intentional. Tokenization happens on-device; charging happens on your backend so your environment-key / access-secret pair stays server-side.

---

## SwiftUI Integration

See [Pre-built Drop-In Form (Express)](#pre-built-drop-in-form-express) above for the canonical SwiftUI integration. A full working sample ships in Spreedly's iOS sample app.

---

## UIKit Integration

```swift
import UIKit
import Combine
import SpreedlyCore
import SpreedlyUI

final class BankCheckoutVC: UIViewController {
    private var cancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        cancellable = Spreedly.shared().subscribeToPaymentResults { [weak self] result in
            if result.isSuccess {
                self?.dismiss(animated: true)
                // Send result.token to backend
            }
        }
    }

    @IBAction private func payTapped() {
        let dropIn = BankAccountFormDropInViewController(
            fieldConfig: BankAccountFieldConfig(
                nameDisplayMode: .singleField,
                showBankName: false,
                showAccountType: true,
                showAccountHolderType: true
            ),
            onProcessingResult: { result in
                if result.isValidationFailed {
                    print(result.getDescription())
                }
            }
        )
        present(dropIn, animated: true)
    }
}
```

---

## Objective-C Integration

A full working sample ships in Spreedly's iOS sample app under the Objective-C target.

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>

@interface BankCheckoutVC : UIViewController <SpreedlyPaymentDelegate>
@end

@implementation BankCheckoutVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [[Spreedly shared] setPaymentDelegate:self];
}

- (IBAction)payTapped:(id)sender {
    BankAccountFieldConfig *config = [[BankAccountFieldConfig alloc]
        initWithNameDisplayMode:DropInNameDisplayModeSingleField
        showBankName:NO
        bankNameLabel:nil
        bankNameRequired:NO
        showAccountType:YES
        accountTypeLabel:nil
        showAccountHolderType:YES
        accountHolderTypeLabel:nil];

    BankAccountFormDropInViewController *dropIn = [[BankAccountFormDropInViewController alloc]
        initWithFieldConfig:config
        onProcessingResult:^(PaymentProcessingResult * _Nonnull result) {
            if (result.isValidationFailed) {
                NSLog(@"Validation failed: %@", [result getDescription]);
            }
        }];
    [self presentViewController:dropIn animated:YES completion:nil];
}

#pragma mark - SpreedlyPaymentDelegate

- (void)paymentDidComplete:(PaymentResult *)result {
    if (result.isSuccess) {
        // Send result.token to backend
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if (result.isFailure) {
        NSString *description = [result.failureDetails getDescription];
        NSLog(@"Failed: %@", description);
    }
}

@end
```

For headless ACH from Objective-C, `Spreedly.shared()` exposes:

```objc
- (PaymentProcessingResult *)createBankAccountObjCWithAdditionalFields:(NSDictionary<NSString *, NSString *> *)additionalFields
                                                       bankAccountType:(NSString *)bankAccountType
                                                 bankAccountHolderType:(NSString *)bankAccountHolderType
                                                              bankName:(nullable NSString *)bankName
                                                              metadata:(nullable NSDictionary<NSString *, NSString *> *)metadata
                                                        allowBlankName:(nullable NSNumber *)allowBlankName
                                                          shouldRetain:(nullable NSNumber *)shouldRetain;
```

Pass an empty string for `bankAccountType` / `bankAccountHolderType` to omit them from the request.

---

## Validation Rules

Validation runs on every keystroke and again at submission time:

| Field | Rule | Behavior |
|---|---|---|
| Routing number | `RoutingNumberRule` | 9 numeric digits; ABA checksum (US); a leading `0` is treated as Canadian and bypasses ABA. User-visible errors match Android (`Routing number is required`, `Routing number is invalid`). |
| Account number | `AccountNumberRule` | 4–17 numeric digits. Empty is valid only when the field is non-required. Errors match Android (`Account number is required`, `Account number is invalid`, `Account number is too short`, `Account number is too long`). |
| Name | `firstNameRules` / `lastNameRules` / `fullNameRules` | ACH drop-in and bank `SPLTextField` name fields use bank-specific required and length messages when `requiredMessage` is set (default in drop-in: `"Name is required"`). |
| Bank name | `bankNameRules` | Optional unless `BankAccountFieldConfig.bankNameRequired` is `true`; max length matches other text fields. |

If a field fails, `PaymentProcessingResult.isValidationFailed` is `true`, `invalidFields` lists the offending types, and field-level errors are wired into `Spreedly.shared().errorHandler` so the form will highlight them.

---

## Security

- Routing and account numbers are kept in protected memory by `SecureValueContainer` (the same path the SDK uses for PAN/CVV). They are read only when `createBankAccount` is dispatched and cleared immediately after the request completes.
- `BankAccountFormDropIn` and `BankAccountFormDropInViewController` apply screen prevention automatically (no merchant wrap required).
- Routing and account number fields disable copy, cut, and paste on the text field (parity with the Android bank-account form).
- Account number entry uses `.numberPad` keyboard and `oneTimeCode`-style autofill suppression where applicable.
- Logging of bank routing/account numbers is redacted by `LogSanitizer`; never log raw values.
- Bank account number is treated as PCI-equivalent sensitive data for purposes of memory handling; the SDK does not write it to disk.

For full security details, see [security.md](security.md).

---

## Important Notes

- On dismiss, `BankAccountFormDropIn` clears secure values and visible field text via `resetPaymentFormPreservingDisplayConfigForDropIn` (and field reset). It does **not** call full `reset()`, so display defaults such as mask/format state are preserved.
- The `bank_*`-prefixed JSON keys (`bank_routing_number`, `bank_account_number`, `bank_account_type`, `bank_account_holder_type`, `bank_name`) are the canonical Spreedly API contract for ACH. Do **not** mix them with credit-card key names.
- `email` and `metadata` are lifted to the `payment_method` level on the wire (not nested under `bank_account`). The SDK does this automatically when you pass them through `BankAccountRequest` / `createBankAccount`.
- An optional `mandate` (type `SpreedlyMandate`, i.e. `[String: Any]`) can be attached on `createBankAccount(...)`, `BankAccountRequest`, and `BankAccountFormDropIn`. It is encoded and forwarded to `payment_method.mandate` — also a sibling of `bank_account`, never nested inside it — and omitted when nil or empty. Spreedly owns the mandate schema and validates it; the SDK applies no size or content checks. The SDK encodes your mandate exactly as `JSON.stringify` would: `Date`, `URL`, `UUID`, and raw-value enums become their canonical JSON strings, `NaN`/`Infinity` become `null`, and `nil` optionals become `null` — so you can pass a `Date` directly rather than pre-formatting it. A value with no JSON representation (e.g. `Data`, an arbitrary object) fails tokenization with an error naming the offending key, rather than being dropped. Never place cardholder data in a mandate.
- Cross-platform parity: Android exposes a `bankAccountState` / `bankAccountCallbacks` Compose state surface for headless mode. iOS does not mirror this — SwiftUI's native `@State` and `SecureValueContainer` cover the same use cases idiomatically. The mapping is: `sdk.bankAccountState` → SwiftUI `@State` inside the form view; `bankAccountCallbacks.onRoutingNumberChange(...)` → `SPLTextField(type: .routingNumber, ...)` (auto-registers in `SecureValueContainer`); `resetBankAccountState()` → `Spreedly.shared().reset()`; `preserveBankAccountStateOnNextShow()` is unnecessary because SwiftUI preserves `@State` across re-presentations.
---

## Troubleshooting

| Issue | Solution |
|---|---|
| `paymentResultPublisher` never fires | Subscribe **before** presenting the form. Late subscriptions miss the result. |
| Submit button stays disabled | Check that all required fields are valid. The Submit button only enables once every required field passes its validator. |
| `bank_routing_number` shows `[REDACTED]` in logs | That's intentional — `LogSanitizer` redacts the field on every log path. |
| Field shows "Routing number is invalid" but the value looks right | Confirm it's a valid US ABA routing number (the SDK runs the standard ABA checksum). Canadian routing numbers must begin with `0`. |
| `createBankAccount` returns `.validationFailed` immediately | One or more `SPLTextField` fields are missing or invalid. Inspect `processingResult.invalidFields` to see which. |
| Tokenization succeeds but the gateway rejects the charge | Tokenization and charging are separate. Check the `purchase`/`authorize` response on your backend; the SDK only handles the tokenization step. |

---

## Iframe to iOS migration

The **web iframe SDK has no ACH / bank-account API** (no bank hosted fields, no `tokenizeBankAccount`). Use this table only as a **card → ACH pattern** map: left = what iframe does for **cards**; right = the ACH equivalent on iOS.

| Web iframe (cards) | ACH on iOS |
|--------------------|------------|
| Spreedly Express checkout UI | `BankAccountFormDropIn` / `BankAccountFormDropInViewController` |
| Hosted fields for number + CVV iframes | `SPLTextField` with `.routingNumber` / `.accountNumber` (optional name / bank name fields as needed) |
| `Spreedly.tokenizeCreditCard(...)` | `Spreedly.shared().createBankAccount(...)` / `createBankAccountObjC(...)` |
| `paymentMethod` event (token result) | `subscribeToPaymentResults` / `SpreedlyPaymentDelegate` |
| Backend `purchase` / `authorize` with `payment_method_token` | Same — bank account returns a Spreedly payment method token |

**What does not carry over from iframe card fields**

- iframe `setNumberFormat` / `toggleMask` — ACH fields are not card number/CVV display fields.
- iframe `fieldEvent` BIN / length for PAN — routing/account use field validation instead.

For iframe **card** field migration on iOS (including `createCreditCard`), see [Migration from legacy iframe-ui](migration/from-legacy.md). For ACH setup and APIs, use the sections above in this guide.

---

## Related Documentation

- [getting-started.md](getting-started.md) — Initial SDK setup
- [express-checkout.md](express-checkout.md) — Card-equivalent drop-in form
- [security.md](security.md) — `SecureValueContainer`, encryption, and screen prevention
- [error-handling.md](error-handling.md) — Result handling and error mapping
- [objective-c.md](objective-c.md) — Objective-C usage patterns
- [Migration from legacy iframe-ui](migration/from-legacy.md) — Card hosted-field iframe → iOS mapping
