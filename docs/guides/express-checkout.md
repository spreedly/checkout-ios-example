# Express Checkout - Spreedly iOS SDK

Add a complete, pre-built payment form to your app in under 15 minutes.

**Estimated time:** ~15 minutes (assumes backend signature endpoint is already set up)

> **Example App:** See `CheckoutBasicView.swift` (Swift) and `CheckoutBasicViewController.m` (Objective-C) in the example project for a working implementation of `CardFormDropIn`.

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Step-by-Step Integration](#step-by-step-integration)
5. [Callback System](#callback-system)
6. [Advanced Configuration](#advanced-configuration)
7. [Save Card for Future Payments](#save-card-for-future-payments)
8. [Error Handling](#error-handling)
9. [Troubleshooting](#troubleshooting)
10. [Related Documentation](#related-documentation)

---

## Introduction

Express Checkout provides a complete, pre-built payment form that handles all UI and validation for you. The `CardFormDropIn` component renders a full checkout form with card number, expiration, CVC, and optional address fields. All validation is automatic; you only need to handle the payment result.

> **Custom PAN brand art (optional):** Express drop-in shows the **built-in** scheme label on the card number row. For **your** artwork, use headless `SPLTextField` (`trailingIcon`) or `SPLTextFieldViewController` (`trailingIconViewFactory`). See [Custom payment forms](custom-payment-forms.md#optional-merchant-card-brand-pan-field-only).

### When to Use

Choose Express Checkout when you need:

- Quick integration with minimal code
- A full payment form without building custom UI
- Automatic validation and error display
- Limited customization options

### Express vs Custom Comparison

| Feature | Express (CardFormDropIn) | Custom (SPLTextField) | Headless (createCreditCard) |
|---------|--------------------------|------------------------|-----------------------------|
| UI | Built-in, complete form | Manual layout per field | No UI, you build everything |
| Validation | Automatic | Per-field callbacks | Manual |
| Pre-submit `areAllFieldsValid` | ✓ (fields auto-register) | ✓ | Use after `SPLTextField` on screen — see [Pre-submit validation](custom-payment-forms.md#pre-submit-validation) |
| `onFieldStateChange` / focus observability | — (use headless `SPLTextField` if needed) | ✓ per field | ✓ per field (only when you build your form with `SPLTextField`) |
| PAN mask / reveal | Default pretty+masked; **`setNumberFormat`** = PAN layout + coupled CVV mask; **`toggleMask`** = plain ↔ masked (PAN + CVC) | Card/CVC observe SDK state by default | N/A |
| Save Card checkbox | Built-in | Implement yourself | Implement yourself |
| Integration effort | Low | Medium | High |
| Customization | Limited (theming, extra fields) | Full control | Full control |

---

## Prerequisites

Before integrating Express Checkout:

1. Complete [getting-started.md](getting-started.md) (installation, basic setup).
2. Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`).
3. Call `Spreedly.setup(config:)` with `environmentKey`, `forterSiteId`, and signature parameters (nonce, signature, certificateToken, timestamp) **before** presenting the form. Without valid credentials, tokenization will fail.
4. Enable the Pay button or present the sheet only when **`Spreedly.isInitialized`** is `true` after **`setup(config:)`** with signed credentials from your server. See [SDK lifecycle](getting-started.md#isinitialized--when-to-use-it).

### Blocked Devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, `CardFormDropIn` auto-dismisses the sheet and publishes a `PaymentResult.failure` via `paymentResultPublisher`. The merchant receives the error through the existing subscription — no extra code needed. See [Security — Runtime Integrity](security.md#runtime-integrity) for details.

---

## Quick Start

Minimal SwiftUI implementation:

```swift
import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI

struct CheckoutView: View {
    @State private var showCheckout = false
    @State private var cancellable: AnyCancellable?

    var body: some View {
        Button("Show Checkout") {
            showCheckout = true
        }
        .sheet(isPresented: $showCheckout) {
            CardFormDropIn(
                onProcessingResult: { result in
                    if result.isProcessing {
                        // Validation passed, request started; show loading
                    } else if result.isValidationFailed {
                        // Validation failed; show result.getDescription()
                    }
                }
            )
        }
        .onAppear {
            cancellable = Spreedly.shared().subscribeToPaymentResults { paymentResult in
                if paymentResult.isSuccess {
                    showCheckout = false
                }
            }
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
            Spreedly.shared().setParam(parameter: .allowBlankName, value: false)
            Spreedly.shared().setParam(parameter: .allowExpiredDate, value: false)
            Spreedly.shared().setParam(parameter: .allowBlankDate, value: false)
            Spreedly.shared().setParam(parameter: .allowInternationalZipCodes, value: true)
        }
    }
}
```

`CardFormDropIn` applies screen prevention automatically. For custom forms, apply `.screenPrevention()` yourself (see [Security](security.md)).

Reset validation parameters in `onDisappear` to restore defaults when the checkout view is dismissed.

### Code sample — `CardFormDropIn` with labels, display config, and external mask UI

The drop-in does **not** expose `onFieldStateChange` — use headless `SPLTextField` if you need per-field snapshots. For express checkout, drive PAN/CVV display from **buttons outside** the sheet (legacy iframe pattern); card and CVC rows inside the drop-in observe `Spreedly` display state automatically.

```swift
import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI

struct ExpressCheckoutView: View {
    @State private var showCheckout = false
    @State private var isPreparingCheckout = false
    @State private var paymentCancellable: AnyCancellable?

    private var canPresentCheckout: Bool {
        Spreedly.isInitialized && !isPreparingCheckout
    }

    private var coreLabels: DropInCoreFieldLabels {
        let labels = DropInCoreFieldLabels()
        labels.cardNumberTitle = "Card number"
        labels.cvcTitle = "Security code"
        return labels
    }

    var body: some View {
        VStack(spacing: 12) {
            Button("Masked format") {
                Spreedly.shared().setNumberFormat(.masked)
            }
            Button("Reveal / hide card number") {
                Spreedly.shared().toggleMask()
            }
            Button("Show checkout") { prepareAndShowCheckout() }
                .disabled(!canPresentCheckout)
        }
        .sheet(isPresented: $showCheckout) {
            CardFormDropIn(
                coreFieldLabels: coreLabels,
                displayConfig: CardFormDropInDisplayConfig(
                    cardNumberFormat: .pretty,
                    enableAutofill: true
                ),
                onProcessingResult: { result in
                    if result.isValidationFailed {
                        print(result.getDescription())
                    }
                }
            )
        }
        .onAppear {
            paymentCancellable = Spreedly.shared().subscribeToPaymentResults { result in
                if result.isSuccess {
                    showCheckout = false
                    // Handle token, retain, etc.
                } else if result.isFailure {
                    showCheckout = false
                    // Handle failureDetails
                }
            }
        }
        .onDisappear {
            paymentCancellable?.cancel()
            paymentCancellable = nil
        }
    }

    private func prepareAndShowCheckout() {
        isPreparingCheckout = true
        Task {
            do {
                let params = try await YourBackend.fetchSignatureParams()
                Spreedly.setup(config: SpreedlyConfig(
                    environmentKey: "YOUR_ENV_KEY",
                    forterSiteId: "YOUR_FORTER_SITE_ID",
                    certificateToken: params.certificateToken,
                    nonce: params.nonce,
                    signature: params.signature,
                    timestamp: params.timestamp
                ))
                await MainActor.run {
                    isPreparingCheckout = false
                    showCheckout = true
                }
            } catch {
                await MainActor.run { isPreparingCheckout = false }
                // Surface signature fetch failure to the user
            }
        }
    }
}
```

> **Tip:** You can read back current validation parameters via `Spreedly.shared().paramsManager.getParam(parameter:)` if you need to inspect or log the state before reset.

---

## Step-by-Step Integration

### SwiftUI

1. **Fetch signature parameters before presenting**

Signature parameters must be fetched from your backend before presenting the form; they are time-sensitive.

```swift
// Fetch fresh signature from your backend before presenting
Task {
    let params = try await YourBackend.fetchSignatureParams()
    Spreedly.setup(config: SpreedlyConfig(
        environmentKey: "YOUR_ENV_KEY",
        forterSiteId: "YOUR_FORTER_SITE_ID",
        certificateToken: params.certificateToken,
        nonce: params.nonce,
        signature: params.signature,
        timestamp: params.timestamp
    ))
    showForm = true
}
```

2. **Present as sheet**

```swift
.sheet(isPresented: $showCheckout) {
    CardFormDropIn(onProcessingResult: { result in
        if result.isProcessing { /* show loading */ }
        else if result.isValidationFailed { /* show result.getDescription() */ }
    })
}
```

3. **Handle `onProcessingResult` callback**

The callback receives a `PaymentProcessingResult` for **validation status only**:

- `isProcessing` – Validation passed and payment request started; show loading.
- `isValidationFailed` – Client-side validation failed; show field errors via `result.getDescription()`.

Success and failure come via `subscribeToPaymentResults` (Swift) or `paymentDelegate` (Obj-C), not `onProcessingResult`.

4. **Subscribe to payment results before presenting**

Subscribe to `Spreedly.shared().subscribeToPaymentResults` **before** presenting the form. If you subscribe after presenting, you may miss the result.

```swift
import Combine

// ...

.onAppear {
    cancellable = Spreedly.shared().subscribeToPaymentResults { paymentResult in
        if paymentResult.isSuccess {
            // Handle success (token, shouldRetain, etc.)
        }
    }
}
.onDisappear {
    cancellable?.cancel()
}
```

5. **Cancel subscription and reset on disappear**

Cancel the subscription and reset validation parameters when the view disappears to avoid leaks, duplicate handling, and stale validation state.

### UIKit

Use `CardFormDropInViewController` with the parameterized initializer and present it modally. Use `onProcessingResult` only for validation status; handle success/failure via `subscribeToPaymentResults` (Swift) or `paymentDelegate` (Obj-C). Screen prevention is built in — present the view controller directly:

```swift
import UIKit
import Combine
import SpreedlyUI

class PaymentViewController: UIViewController {
    var cancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        cancellable = Spreedly.shared().subscribeToPaymentResults { paymentResult in
            if paymentResult.isSuccess {
                self.dismiss(animated: true)
            } else if paymentResult.isFailure {
                // Handle failure via paymentResult.failureDetails?.getDescription()
            }
        }
    }

    deinit {
        cancellable?.cancel()
    }

    func showPaymentForm() {
        let dropInVC = CardFormDropInViewController(
            otherFields: [],
            yearFormat: .fourDigit,
            nameDisplayMode: .separateFields,
            onProcessingResult: { result in
                if result.isProcessing {
                    // Validation passed, request started; show loading
                } else if result.isValidationFailed {
                    // Validation failed; show result.getDescription()
                }
            }
        )
        present(dropInVC, animated: true)
    }
}
```

### Objective-C

Create `CardFormDropInViewController` with `initWithOtherFields:yearFormat:nameDisplayMode:onProcessingResult:`, set `paymentDelegate` on `Spreedly.shared()`, and present directly (built-in screen prevention):

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>

@interface PaymentViewController () <SpreedlyPaymentDelegate>
@end

@implementation PaymentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[Spreedly shared] setPaymentDelegate:self];
}

- (void)showPaymentForm {
    CardFormDropInViewController *dropInVC = [[CardFormDropInViewController alloc]
        initWithOtherFields:@[]
        yearFormat:YearFormatFourDigit
        nameDisplayMode:DropInNameDisplayModeSeparateFields
        onProcessingResult:^(PaymentProcessingResult *result) {
            if (result.isProcessing) {
                // Validation passed, request started; show loading
            } else if (result.isValidationFailed) {
                // Validation failed; show [result getDescription]
            }
        }];
    [self presentViewController:dropInVC animated:YES completion:nil];
}

- (void)paymentDidComplete:(PaymentResult *)result {
    if (result.isSuccess) {
        // Handle success (token, shouldRetain, etc.)
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if (result.isFailure) {
        // Handle failure via [result.failureDetails getDescription]
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
```

---

## Core field titles and placeholders

By default, `CardFormDropIn` uses localized labels for card number, CVC, and expiry. Override them with **`DropInCoreFieldLabels`**:

```swift
let labels = DropInCoreFieldLabels()
labels.cardNumberTitle = "Card number"
labels.cardNumberPlaceholder = "1234 5678 9012 3456"
labels.cvcTitle = "Security code"
labels.cvcPlaceholder = "CVC"

CardFormDropIn(coreFieldLabels: labels, onProcessingResult: { result in
    // ...
})
```

### Swift: `DropInCoreFieldLabels(customizations:)`

For many overrides at once, use **`DropInFieldLabelCustomization`** pairs in a dictionary (same outcome as setting individual properties on **`DropInCoreFieldLabels()`**):

```swift
let labels = DropInCoreFieldLabels(customizations: [
    .cardNumber: DropInFieldLabelCustomization(title: "PAN", placeholder: "0000 0000 0000 0000"),
    .cvc: DropInFieldLabelCustomization(title: "CVV", placeholder: "123"),
    .expirationMonth: DropInFieldLabelCustomization(title: "MM", placeholder: "MM"),
    .expirationYear: DropInFieldLabelCustomization(title: "YYYY", placeholder: "YYYY")
])

CardFormDropIn(coreFieldLabels: labels, onProcessingResult: { _ in })
```

Objective-C: set `coreFieldLabels` on `CardFormDropInViewController` before presentation.

Express drop-in shows the **default card scheme label** on the PAN row. Custom brand artwork is **headless only** — use **`trailingIcon`** / **`trailingIconViewFactory`** on `SPLTextField` (see [custom-payment-forms.md](custom-payment-forms.md#optional-merchant-card-brand-pan-field-only)).

**Field-state callbacks** (`onFieldStateChange`, `onFocusChanged`, `onInputLength`, `onFieldTextChange`) are **headless `SPLTextField` only**, not on `CardFormDropIn` (legacy iframe used separate field iframes; express is a bundled form).

---

## Callback System

Express checkout exposes **`onProcessingResult`** on the drop-in plus **`subscribeToPaymentResults`** / **`paymentDelegate`** for the final token.

### 1. `onProcessingResult` → Validation status only

Fires for `isProcessing` and `isValidationFailed` only. Use it for loading UI and validation error display.

```swift
CardFormDropIn(
    onProcessingResult: { result in
        if result.isProcessing {
            // Validation passed and request started; show loading
        } else if result.isValidationFailed {
            // Validation failed; show field errors
            print(result.getDescription())
        }
    }
)
```

### 2. PAN display config (legacy iframe `setNumberFormat`)

```swift
CardFormDropIn(
    displayConfig: CardFormDropInDisplayConfig(
        cardNumberFormat: .pretty,
        enableAutofill: true  // all drop-in hosted fields; false = legacy iframe toggleAutoComplete off
    ),
    onProcessingResult: { … }
)
```

Objective-C: set **`cardNumberFormat`** and **`enableAutofill`** on `CardFormDropInViewController` before `viewDidLoad`.

### Sheet lifecycle

Express-only behavior; full app flow in [Getting Started — SDK lifecycle](getting-started.md#sdk-lifecycle).

- **On open:** The SDK clears field values, validation, and visible text (same effect as **`resetPaymentFormPreservingDisplayConfig()`**). Your **`setNumberFormat` / `toggleMask`** choices **outside** the sheet are **kept**. The SDK seeds `displayConfig.cardNumberFormat` via `setNumberFormat` **only if** hosted display state is still the SDK default **and** the format is **not** `.pretty`.
- **On dismiss:** Secure values and errors are cleared; mask/format choices for UI **outside** the sheet stay as you set them.
- **Device rotation:** Landscape ↔ portrait while the sheet stays open — typed fields stay. You do nothing. Does **not** bring back PAN after the customer dismisses the sheet.

#### Device rotation (express drop-in)

| Integration | What merchants do |
|-------------|-------------------|
| **`CardFormDropIn`** (SwiftUI) | Nothing — handled on size-class change |
| **`CardFormDropInViewController`** (UIKit / Obj-C) | Nothing — handled in `viewWillTransition` |
| Custom host **without** those components | Use **`CardFormDropIn`** or **`CardFormDropInViewController`** so rotation keeps typed data |

#### When form reset preserving display config runs

| Situation | Fields cleared? | Mask/format (`setNumberFormat` / `toggleMask`) |
|-----------|-----------------|------------------------------------------------|
| **You call** `resetPaymentFormPreservingDisplayConfig()` | Yes | **Kept** |
| **Sheet opens** (`CardFormDropIn` appears) | Yes — SDK runs the same reset | **Kept** |
| **Rotation** while sheet stays open | **No** — typed values stay | **Kept** |
| **Successful `createCreditCard`** | **Yes** — SDK runs automatically | **Kept** |
| **You call** `resetPaymentState()` / `reset()` | Yes | Reset to SDK defaults |

Headless: the SDK does **not** auto-call this on open — only when **you** call it or when you use **`resetPaymentState()`**. Details: [Payment reset](custom-payment-forms.md#payment-reset-merchant-apis).

#### Reset APIs (merchant-callable)

Call these from **your** UI when you need to clear the form outside the automatic **sheet open** behavior above.

| API | Clears | Keeps |
|-----|--------|-------|
| **`resetPaymentFormPreservingDisplayConfig()`** | Field values, validation, visible text, card-brand context | **`setNumberFormat` / `toggleMask`** state (`hostedCardDisplayState`) |
| **`resetPaymentState()`** / **`reset()`** | Everything above **plus** PAN/CVV display back to SDK defaults (Pretty, unmasked) | Validation params (`setParam`), signing — re-**`setup(config:)`** for new auth |

```swift
// Clear fields but keep Masked / Plain / Pretty from your UI
Spreedly.shared().resetPaymentFormPreservingDisplayConfig()

// Leave checkout — wipe form and display
Spreedly.shared().resetPaymentState()
```

Objective-C: `[[Spreedly shared] resetPaymentFormPreservingDisplayConfig]` and `resetPaymentState`.

Card and CVC rows follow global hosted display state internally. Use **`Spreedly.shared().setNumberFormat(_:)`** / **`Spreedly.shared().toggleMask()`** from UI outside the sheet. Read **`Spreedly.shared().hostedCardDisplayState.cvvDisplayMasked`** for labels only — not a mask API. See [PAN/CVV display](custom-payment-forms.md#pancvv-display-iframe-and-web-hosted-field-parity) and [read flags vs mask actions](custom-payment-forms.md#hostedcarddisplaystate-read-vs-mask-actions).

For **`HostedFieldState`** / digit counts / brand while typing, per-field mask hooks, and UIKit/ObjC wiring, use **headless** `SPLTextField` — [Headless PAN API quick reference](custom-payment-forms.md#headless-pan-api-quick-reference) and [Migration from legacy iframe-ui](migration/from-legacy.md).

### 3. `subscribeToPaymentResults` (Swift) / `paymentDelegate` (Obj-C) → Actual payment result

Success (with token) and failure (with error) come through this channel, **not** `onProcessingResult`.

> **Thread safety:** `subscribeToPaymentResults` callbacks are always dispatched on the **main thread** (`DispatchQueue.main`). You can safely update UI directly in the callback without wrapping in `DispatchQueue.main.async`.

```swift
import Combine

cancellable = Spreedly.shared().subscribeToPaymentResults { paymentResult in
    if paymentResult.isSuccess {
        let token = paymentResult.token
        let shouldRetain = paymentResult.shouldRetain
    } else if paymentResult.isFailure {
        let errorMessage = paymentResult.failureDetails?.getDescription()
    }
}
```

### PaymentProcessingResult (onProcessingResult only)

| Property | Description |
|----------|-------------|
| `isProcessing` | `true` when validation passed and payment request has started; show loading UI |
| `isValidationFailed` | `true` when client-side validation failed; use `getDescription()` for error text |

### PaymentResult (subscribeToPaymentResults / paymentDelegate)

| Property | Description |
|----------|-------------|
| `isSuccess` | `true` when payment succeeded |
| `isFailure` | `true` when payment failed |
| `token` | Payment method token on success |
| `shouldRetain` | User's "save card" preference |
| `failureDetails` | Failure details on failure; use `getDescription()` for error text |

---

## Advanced Configuration

### Validation Parameters

Set these before showing the form:

```swift
Spreedly.shared().setParam(parameter: .allowBlankName, value: false)
Spreedly.shared().setParam(parameter: .allowExpiredDate, value: false)
Spreedly.shared().setParam(parameter: .allowBlankDate, value: false)
Spreedly.shared().setParam(parameter: .allowInternationalZipCodes, value: true)
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `allowBlankName` | `false` | Allow empty cardholder name |
| `allowExpiredDate` | `false` | Allow expired dates |
| `allowBlankDate` | `false` | Allow empty expiration month/year |
| `allowInternationalZipCodes` | `true` | When `false`, ZIP/postal fields accept US numeric ZIP only (`12345` or `12345-6789`); when `true`, international postal codes with letters, spaces, and hyphens are allowed |

### Additional Fields

Add address fields:

```swift
CardFormDropIn(
    otherFields: [
        FormField(id: "addressLine1", title: "Address", type: .addressLine1, isRequired: true),
        FormField(id: "addressLine2", title: "Address Line 2", type: .addressLine2, isRequired: false),
        FormField(id: "city", title: "City", type: .city, isRequired: true),
        FormField(id: "state", title: "State", type: .state, isRequired: true),
        FormField(id: "zipCode", title: "ZIP Code", type: .zipCode, isRequired: true)
    ],
    onProcessingResult: { result in
        if result.isProcessing { /* show loading */ }
        else if result.isValidationFailed { /* show result.getDescription() */ }
    }
)
```

Each **`FormField`** only carries **type**, **labels**, and **required** — the drop-in builds internal `SPLTextField` rows from them. You **cannot** attach `onFieldStateChange` / `onFocusChanged` / `onInputLength` to these entries; for iframe-style per-field callbacks use **headless** **`SPLTextField`** in [custom-payment-forms.md](custom-payment-forms.md#spltextfield-component).

### Year Format

`yearFormat` controls expiration year display:

```swift
CardFormDropIn(
    yearFormat: .fourDigit,  // e.g., 2025
    onProcessingResult: { result in
        if result.isProcessing { /* show loading */ }
        else if result.isValidationFailed { /* show result.getDescription() */ }
    }
)
```

### Name Display Mode

`nameDisplayMode` controls how the cardholder name is shown:

```swift
CardFormDropIn(
    nameDisplayMode: .separateFields,  // First Name and Last Name
    // or .singleField for Full Name
    onProcessingResult: { result in
        if result.isProcessing { /* show loading */ }
        else if result.isValidationFailed { /* show result.getDescription() */ }
    }
)
```

### Theming

Pass custom themes for light and dark mode. Use `theme:` (not `lightTheme:` — the init parameter is `theme:`; the stored property is `lightTheme`):

```swift
CardFormDropIn(
    theme: lightTheme,
    darkTheme: darkTheme,
    onProcessingResult: { result in
        if result.isProcessing { /* show loading */ }
        else if result.isValidationFailed { /* show result.getDescription() */ }
    }
)
```

---

## Save Card for Future Payments

`CardFormDropIn` includes a built-in "Save card for future payments" checkbox. The user's choice is available in `PaymentResult.shouldRetain`.

```swift
import Combine

let cancellable = Spreedly.shared().subscribeToPaymentResults { paymentResult in
    if paymentResult.isSuccess {
        if paymentResult.shouldRetain {
            // Save token for future use
        } else {
            // Use token for this transaction only
        }
    }
}
```

### Objective-C Example

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    [[Spreedly shared] setPaymentDelegate:self];
}

- (void)paymentDidComplete:(PaymentResult *)result {
    if (result.isSuccess) {
        if (result.shouldRetain) {
            // Save payment method token for future use
        } else {
            // Use token for this transaction only
        }
    }
}
```

---

## Error Handling

### Validation Errors

When `result.isValidationFailed` is true in `onProcessingResult`:

- `result.getDescription()` contains a summary
- Invalid fields are shown in the form
- Do not dismiss the form; let the user correct errors

### Network Errors

Network failures are reported via `subscribeToPaymentResults` / `paymentDelegate` when `paymentResult.isFailure` is true. Use `paymentResult.failureDetails?.getDescription()` and show a retry option.

### Example

```swift
import Combine

// onProcessingResult: validation status only
CardFormDropIn(
    onProcessingResult: { result in
        if result.isProcessing {
            // Show loading
        } else if result.isValidationFailed {
            showError(result.getDescription())
        }
    }
)

// subscribeToPaymentResults: actual success/failure
cancellable = Spreedly.shared().subscribeToPaymentResults { paymentResult in
    if paymentResult.isSuccess {
        showCheckout = false
    } else if paymentResult.isFailure {
        showError(paymentResult.failureDetails?.getDescription() ?? "Payment failed. Please try again.")
        showCheckout = false
    }
}
```

---

## Troubleshooting

### Form not displaying

- Ensure `SpreedlyUI` is imported and linked
- Verify SwiftUI view hierarchy
- Confirm `Spreedly.setup(config:)` was called before presenting

### Missing payment result

- Subscribe to `subscribeToPaymentResults` **before** presenting the form
- Cancel the subscription in `onDisappear` to avoid leaks

### Validation callbacks not firing

- Ensure `onProcessingResult` is not nil
- Verify the closure is retained (e.g., not deallocated early)

### Tokenization fails

- Call `Spreedly.setup(config:)` with valid signature parameters before showing the form
- Fetch signature parameters from your backend; they are time-sensitive

---

## Related Documentation

- [custom-payment-forms.md](custom-payment-forms.md) – Building custom forms with SPLTextField
- [theme-and-styling.md](theme-and-styling.md) – Theming and customization
- [error-handling.md](error-handling.md) – Error types and handling patterns
- [security.md](security.md) – Screen prevention, PCI compliance, security practices
