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
| Save Card checkbox | Built-in | Implement yourself | Implement yourself |
| Integration effort | Low | Medium | High |
| Customization | Limited (theming, extra fields) | Full control | Full control |

---

## Prerequisites

Before integrating Express Checkout:

1. Complete [getting-started.md](getting-started.md) (installation, basic setup).
2. Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`).
3. Call `Spreedly.setup(config:)` with `environmentKey`, `forterSiteId`, and signature parameters (nonce, signature, certificateToken, timestamp) **before** presenting the form. Without valid credentials, tokenization will fail.

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
            .screenPrevention()
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
        }
    }
}
```

Always apply `.screenPrevention()` to protect sensitive payment data from app switcher screenshots.

Reset validation parameters in `onDisappear` to restore defaults when the checkout view is dismissed.

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
    .screenPrevention()
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

Use `CardFormDropInViewController` with the parameterized initializer and present it modally. Use `onProcessingResult` only for validation status; handle success/failure via `subscribeToPaymentResults` (Swift) or `paymentDelegate` (Obj-C). Always wrap with `wrapInSecureViewControllerWithPlaceholderText:` for screen prevention:

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
        let secureVC = dropInVC.wrapInSecureViewController(placeholderText: "")
        present(secureVC, animated: true)
    }
}
```

### Objective-C

Create `CardFormDropInViewController` with `initWithOtherFields:yearFormat:nameDisplayMode:onProcessingResult:`, set `paymentDelegate` on `Spreedly.shared()`, and wrap with `wrapInSecureViewControllerWithPlaceholderText:` before presenting:

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
    UIViewController *secureVC = [dropInVC wrapInSecureViewControllerWithPlaceholderText:@""];
    [self presentViewController:secureVC animated:YES completion:nil];
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

## Callback System

There are **two separate channels** for handling results:

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

### 2. `subscribeToPaymentResults` (Swift) / `paymentDelegate` (Obj-C) → Actual payment result

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
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `allowBlankName` | `false` | Allow empty cardholder name |
| `allowExpiredDate` | `false` | Allow expired dates |
| `allowBlankDate` | `false` | Allow empty expiration month/year |

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
- [CARD_TOKENIZATION_FLOW.md](../development/CARD_TOKENIZATION_FLOW.md) – Detailed flow diagrams for card tokenization
