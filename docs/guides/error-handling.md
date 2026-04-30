# Error Handling - Spreedly iOS SDK

Handle payment errors, validation failures, and network issues properly.

**Estimated time:** ~10 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Error Types](#error-types)
3. [Handling Validation Errors](#handling-validation-errors-swift)
4. [CardFormDropIn: onProcessingResult](#cardformdropin-onprocessingresult)
5. [Handling Payment Failures](#handling-payment-failures-swift)
6. [Handling Network Errors](#handling-network-errors)
7. [Handling 3DS Errors](#handling-3ds-errors)
8. [Common Error Scenarios](#common-error-scenarios)
9. [UIKit/Objective-C Error Handling](#uikitobjective-c-error-handling)
10. [Best Practices](#best-practices)
11. [Related Documentation](#related-documentation)

---

## Prerequisites

- Complete [Getting Started](getting-started.md) (SDK installed and initialized)
- At least one payment flow integrated (e.g., [Express Checkout](express-checkout.md) or [Custom Payment Forms](custom-payment-forms.md))

---

## Introduction

The Spreedly iOS SDK categorizes errors into distinct types and delivers them through synchronous and asynchronous flows. Understanding these flows and error types helps build reliable payment experiences.

The error handling flow involves three main components:

- **PaymentProcessingResult**: Immediate synchronous response from `createCreditCard()` or `submitOffsitePayment()` indicating validation status
- **PaymentResult**: Final result delivered asynchronously through `subscribeToPaymentResults` or the delegate. `subscribeToPaymentResults` callbacks are always dispatched on the **main thread**.
- **FailedDetails**: Detailed failure information for debugging and user feedback

---

## Error Types

### PaymentProcessingResult

Returned immediately by `createCreditCard()` and `submitOffsitePayment()` to indicate the initial processing status:

| Property | Type | Description |
|----------|------|-------------|
| `isProcessing` | Bool | Request started successfully; listen for async `PaymentResult` |
| `isSuccess` | Bool | Same as `isProcessing`; true when request started successfully |
| `isValidationFailed` | Bool | Form validation failed before processing started |
| `invalidFields` | [FormFieldType] | Array of invalid SDK form fields |
| `invalidAdditionalFields` | [AdditionalField] | Array of invalid additional fields |
| `getDescription()` | String | Human-readable error or status message |

### PaymentResult

Delivered asynchronously via `subscribeToPaymentResults` or the delegate, representing the final payment outcome:

| Property | Type | Description |
|----------|------|-------------|
| `isInitial` | Bool | `true` on the default/empty `PaymentResult`. The publisher is a passthrough stream and does not automatically emit an initial value -- you will only see `isInitial` if you check the subject's stored value or in testing. Treat it as "no outcome yet" and return early. |
| `isSuccess` | Bool | Payment succeeded |
| `isCanceled` | Bool | User canceled the payment flow (e.g., dismissed the form, canceled a 3DS challenge, or backed out of an APM flow). Handle this as a non-error state — allow the user to retry. |
| `isFailure` | Bool | Payment failed |
| `token` | String? | Payment method token |
| `paymentResponse` | PaymentMethodResponse? | Full response object |
| `shouldRetain` | Bool | Whether to save card (set by CardFormDropIn and by `createCreditCard(..., shouldRetain:)`) |
| `failureDetails` | FailedDetails? | Error details when failed |
| `state` | String? | Transaction state (for offsite/APM flows) |

> **Three mutually exclusive states:** `isSuccess`, `isCanceled`, and `isFailure` are mutually exclusive. Exactly one will be `true` on any non-initial `PaymentResult`. Always check all three in your result handler. `subscribeToPaymentResults` delivers every emitted result on the main queue without any filtering.

### FailedDetails

Contains failure details:

| Property | Type | Description |
|----------|------|-------------|
| `getDescription()` | String | Human-readable error message |
| `errorType` | ErrorType | Enum: `apiError`, `networkError`, `unknownError` |
| `message` | String? | Primary error message |
| `originalError` | Error? | Original error that caused the failure (for debugging) |
| `apiError` | SpreedlyApiError? | Specific API error type |
| `statusCode` | NSNumber? | HTTP status code when applicable |
| `validationErrors` | [PaymentValidationError] | Field-specific validation errors |
| `rawErrorResponse` | String? | Complete raw error response (for debugging) |

### SpreedlyApiError

API error types available in `FailedDetails.apiError`:

| Enum Value | HTTP Status | Description |
|------------|-------------|-------------|
| `accountInactive` | — | Environment not activated for real transactions |
| `validationError` | 422 | Field validation errors (blank, invalid format) |
| `paymentRequired` | 402 | Payment required (billing/plan issue) |
| `unprocessableEntity` | 422 | Unprocessable Entity (invalid data) |
| `unauthorized` | 401 | Invalid credentials or tokens |
| `forbidden` | 403 | Forbidden (access denied) |
| `notFound` | 404 | Resource not found |
| `rateLimited` | 429 | Too many requests |
| `serverError` | 5xx | Server error |
| `unknown` | — | Unrecognized error code |

### FormFieldType

Values used in `PaymentProcessingResult.invalidFields` and for field-level validation:

| Value | Description |
|-------|-------------|
| `.cardNumber` | Card number |
| `.cvc` | Security code (CVC/CVV) |
| `.expirationMonth` | Expiration month |
| `.expirationYear` | Expiration year |
| `.expirationDate` | Combined expiration (MM/YY) |
| `.firstName` | First name |
| `.lastName` | Last name |
| `.fullName` | Full name (single field) |
| `.addressLine1` | Address line 1 |
| `.addressLine2` | Address line 2 |
| `.city` | City |
| `.state` | State/Province |
| `.zipCode` | Postal/ZIP code |

### PaymentValidationError

Field-specific validation errors in `FailedDetails.validationErrors`:

| Property | Type | Description |
|----------|------|-------------|
| `fieldName` | String | Field identifier |
| `errorKey` | String? | Error key (e.g., `invalid`, `blank`) |
| `errorMessage` | String? | Human-readable error message |

### ThreeDSChallengeResult

3DS-specific result from challenge flows:

| Property | Type | Description |
|----------|------|-------------|
| `isSuccess` | Bool | Challenge completed successfully |
| `isFailure` | Bool | Challenge failed |
| `isCanceled` | Bool | User canceled the challenge |
| `error` | Error? | Error when challenge failed |
| `failureDetails` | FailedDetails? | Structured failure info with `message` property; use for user-facing error text |

---

## Handling Validation Errors (Swift)

When `PaymentProcessingResult.isValidationFailed` is true, iterate over `invalidFields` and `invalidAdditionalFields` to highlight problematic fields in your UI.

> **Note:** `CardFormDropIn` uses `onProcessingResult` for validation (see [CardFormDropIn: onProcessingResult](#cardformdropin-onprocessingresult)), while custom forms call `createCreditCard()` directly. Both produce `PaymentProcessingResult`.

```swift
let processingResult = Spreedly.shared().createCreditCard(
    additionalFields: [:],
    metadata: [:]
)

if processingResult.isValidationFailed {
    // Highlight invalid SDK form fields
    for fieldType in processingResult.invalidFields {
        highlightInvalidField(fieldType)
    }
    
    // Highlight invalid additional fields
    for additionalField in processingResult.invalidAdditionalFields {
        highlightInvalidAdditionalField(additionalField)
    }
    
    // Show user-friendly message
    let message = processingResult.getDescription()
    showErrorMessage(message)
}
```

Use `getDescription()` for a human-readable summary, or build custom messages from the invalid field arrays.

---

## CardFormDropIn: onProcessingResult

When using `CardFormDropIn` (SwiftUI) or `CardFormDropInViewController` (UIKit/Objective-C), the `onProcessingResult` callback fires with `PaymentProcessingResult` for validation and loading state—**not** for final success or failure. Success and failure are delivered separately via `subscribeToPaymentResults` or `paymentDelegate`.

### Swift (CardFormDropIn)

```swift
CardFormDropIn(
    yearFormat: yearFormat,
    nameDisplayMode: nameDisplayMode,
    onProcessingResult: { processingResult in
        if processingResult.isProcessing {
            // Show loading state while request is in flight
            isLoading = true
        } else if processingResult.isValidationFailed {
            // Show validation errors via getDescription()
            isLoading = false
            errorMessage = processingResult.getDescription()
            // Optionally iterate invalidFields and invalidAdditionalFields for field-level highlighting
        }
    }
)
.screenPrevention()

// Success/failure comes via subscribeToPaymentResults:
cancellable = Spreedly.shared().subscribeToPaymentResults { result in
    isLoading = false
    if result.isSuccess { /* handle success */ }
    else if result.isFailure { /* handle failure via result.failureDetails */ }
}
```

### Objective-C (CardFormDropInViewController)

```objc
CardFormDropInViewController *dropInVC = [[CardFormDropInViewController alloc]
    initWithOtherFields:@[]
    yearFormat:yearFormat
    nameDisplayMode:nameDisplayMode
    onProcessingResult:^(PaymentProcessingResult *processingResult) {
        if (processingResult.isProcessing) {
            self.isLoading = YES;
            [self.loadingIndicator startAnimating];
        } else if (processingResult.isValidationFailed) {
            self.isLoading = NO;
            [self.loadingIndicator stopAnimating];
            self.errorMessage = [NSString stringWithFormat:@"Validation failed: %@",
                [processingResult getDescription]];
            [self updateUI];
        }
    }];

// Success/failure comes via paymentDelegate:
[[Spreedly shared] setPaymentDelegate:self];
// Implement paymentDidComplete: to receive PaymentResult
```

---

## Handling Payment Failures (Swift)

Check `PaymentResult.isFailure` and use `failureDetails.getDescription()` for user-facing messages. Use `errorType` and `apiError` for specific handling:

```swift
cancellable = Spreedly.shared().subscribeToPaymentResults { result in
    if result.isSuccess {
        // Use result.token, result.paymentResponse
        handleSuccess(result.token)
    } else if result.isFailure {
        guard let details = result.failureDetails else {
            showErrorMessage("Payment failed")
            return
        }
        
        let userMessage = details.getDescription()
        
        switch details.errorType {
        case .apiError:
            if let apiError = details.apiError {
                // Handle specific API errors
                switch apiError {
                case .accountInactive:
                    showErrorMessage("Please use test card numbers in test environment")
                case .validationError:
                    handleValidationErrors(details.validationErrors)
                case .rateLimited:
                    showRetryOption()
                default:
                    showErrorMessage(userMessage)
                }
            } else {
                showErrorMessage(userMessage)
            }
        case .networkError:
            showErrorMessage("Network error. Please check your connection and try again.")
        case .unknownError:
            showErrorMessage(userMessage)
        }
    }
}
```

---

## Handling Network Errors

### Connectivity Check

Use `NWPathMonitor` to check connectivity before initiating payments:

```swift
import Network

let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    if path.status == .satisfied {
        // Network available
    } else {
        // No network - show appropriate message
        showErrorMessage("No internet connection. Please check your network and try again.")
    }
}
monitor.start(queue: DispatchQueue.global())
```

### Retry Logic

For transient errors such as `rateLimited` or `serverError`, offer a retry option:

```swift
switch details.apiError {
case .rateLimited, .serverError:
    showRetryOption()
default:
    showPermanentError(details)
}

private func showRetryOption() {
    let alert = UIAlertController(
        title: "Error",
        message: "A temporary error occurred. Would you like to try again?",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
        self.processPayment()
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    present(alert, animated: true)
}
```

### Timeout Handling

Network timeouts are reported as `ErrorType.networkError` in `FailedDetails`. Show a clear message and allow the user to retry.

---

## Handling 3DS Errors

### Forter3DS Not Linked

**Symptom:** App crashes with `dyld: Library not loaded: @rpath/Forter3DS.framework/Forter3DS`

**Solution:** Add Forter3DS as a direct dependency to your app target and set it to "Embed & Sign" in Frameworks, Libraries, and Embedded Content.

### Challenge Failed

Handle `ThreeDSChallengeResult.isFailure` and inspect the `error` property:

```swift
cancellable = Spreedly.shared().subscribeToThreeDSChallengeResults { result in
    if result.isSuccess {
        // Challenge completed successfully
    } else if result.isFailure {
        if let error = result.error {
            showErrorMessage("Authentication failed: \(error.localizedDescription)")
        } else {
            showErrorMessage("Authentication failed. Please try again.")
        }
    } else if result.isCanceled {
        showErrorMessage("Authentication was canceled")
    }
}
```

### User Canceled

When `ThreeDSChallengeResult.isCanceled` is true, inform the user and allow them to retry or abandon the flow.

### Timeout

If the challenge times out, the result will typically be a failure with a network or timeout error. Handle it the same way as other challenge failures.

---

## Common Error Scenarios

### SDK Not Initialized

**Error:** "Spreedly instance not initialized. Call Spreedly.initializeSDK() or Spreedly.setup(config:) first."

**Solution:** Call `Spreedly.setup(config:)` with valid credentials before any payment operation. Ensure setup runs at app launch or before presenting payment UI.

### Missing Configuration (`setup` Not Called)

If you call `Spreedly.shared()` without first calling `Spreedly.setup(config:)`, the SDK auto-initializes with a default (empty) configuration and logs a warning. Subsequent API calls (e.g., `createCreditCard`, `submitOffsitePayment`) will fail because the environment key is missing.

**Behavior by flow:**

| Operation | Failure Mode |
|-----------|-------------|
| `Spreedly.setup(config:)` with nil/empty `environmentKey` | Logs error, triggers `assertionFailure` (crashes in debug builds, silently returns in release) |
| `createCreditCard(...)` without setup | Validation passes, but the API call fails with an authentication error via `PaymentResult.failure` |
| `submitOffsitePayment(...)` without setup | Returns `PaymentProcessingResult.validationFailed()` and emits `PaymentResult.failure` with message "Spreedly configuration is missing" |

**Solution:** Always call `Spreedly.setup(config:)` with a valid `environmentKey` before any payment operation. In debug builds, a missing environment key will crash with `assertionFailure` to surface the issue early.

### Invalid Credentials

**Error:** `SpreedlyApiError.unauthorized` or "Invalid environment key or authentication failed"

**Solution:** Verify `environmentKey`, `certificateToken`, `nonce`, `signature`, and `timestamp` in `SpreedlyConfig`. Fetch signature parameters from your backend; they are time-sensitive.

### Card Number Validation

**Error:** `isValidationFailed` with `invalidFields` containing `.cardNumber`

**Solution:** Ensure the card number passes Luhn validation and matches the expected format. Use test card numbers (e.g., 4111111111111111) in test environments.

### Expired Card

**Error:** Validation or API error for expiration date

**Solution:** Check `allowExpiredDate` parameter. By default, expired dates are rejected. Use `Spreedly.shared().setParam(parameter: .allowExpiredDate, value: true)` only if your business logic allows it.

### Rate Limiting

**Error:** `SpreedlyApiError.rateLimited` (HTTP 429)

**Solution:** Implement exponential backoff. Show a "Too many requests" message and allow the user to retry after a short delay.

### Payment Method Not Found (404)

**Error:** `SpreedlyApiError.notFound`

**Solution:** The requested resource (e.g., payment method token) does not exist. Verify the token or identifier before retrying.

---

## UIKit/Objective-C Error Handling

### SpreedlyPaymentDelegate

Set `Spreedly.shared().paymentDelegate` to receive payment results in Objective-C:

```objc
@interface MyViewController : UIViewController <SpreedlyPaymentDelegate>
@end

@implementation MyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Spreedly shared].paymentDelegate = self;
}

- (void)paymentDidComplete:(PaymentResult *)result {
    if (result.isSuccess) {
        NSLog(@"Payment successful");
        // Use result.token for your payment processing
    } else if (result.isFailure) {
        NSString *message = [result.failureDetails getDescription];
        [self showErrorMessage:message];
    }
}

@end
```

### paymentDidComplete: Delegate Method

The `paymentDidComplete:` method is called with a `PaymentResult` when the payment flow completes. Check `result.isSuccess` and `result.isFailure` and use `result.failureDetails.getDescription` for error messages.

### Error Handling in Objective-C

Handle validation and processing results from `createCreditCard`:

```objc
PaymentProcessingResult *result = [[Spreedly shared] createCreditCardObjCWithAdditionalFields:@{} metadata:@{}];

if (result.isValidationFailed) {
    for (NSNumber *fieldNum in result.invalidFields) {
        FormFieldType field = [fieldNum intValue];
        [self highlightInvalidField:field];
    }
    [self showErrorMessage:[result getDescription]];
} else if (result.isProcessing) {
    [self showLoadingState];
}
```

---

## Best Practices

1. **Always subscribe before presenting:** Call `subscribeToPaymentResults` or set `paymentDelegate` before calling `createCreditCard()` or presenting payment UI.

2. **Show user-friendly messages:** Use `failureDetails.getDescription()` or map `SpreedlyApiError` to clear, non-technical messages. Avoid exposing raw error details or stack traces to users.

3. **Log errors for debugging:** In debug builds, log `errorType`, `statusCode`, and `apiError` to aid troubleshooting. Do not log sensitive data such as full card numbers or tokens.

4. **Do not expose raw error details to users:** Present sanitized, actionable messages. Reserve technical details for internal logging.

5. **Handle all result states:** Check `isSuccess`, `isFailure`, `isCanceled`, and `isValidationFailed` as appropriate. Do not assume a single outcome.

6. **Cancel subscriptions on view disappear:** Call `cancellable?.cancel()` in `onDisappear` or `viewWillDisappear` to avoid memory leaks and duplicate handling.

---

## See Also: Example App Patterns

The example app demonstrates error handling across several views:

- **`CheckoutBasicView.swift`** -- basic `failureDetails.getDescription()` pattern for `CardFormDropIn`
- **`CustomFormView.swift`** -- validation errors via `onProcessingResult` and payment failures via `subscribeToPaymentResults`
- **`CVVRecachingView.swift`** -- error handling for CVV recaching flows

The examples use the simple `failureDetails.getDescription()` pattern for displaying errors. The advanced `errorType` / `apiError` patterns documented above provide more per-field control for production apps that need to distinguish between error categories or present context-specific messages.

---

## Customer Troubleshooting

### Common issues

| Symptom | Likely cause | What to try |
|---------|--------------|-------------|
| SPM cannot resolve `checkout-ios-package` | Missing or invalid GitHub token | Confirm your PAT has `read:packages` scope; see [Getting Started -- Installation](getting-started.md#installation) |
| CocoaPods `pod install` fails | Podspec source not configured or private repo token invalid | Use `:git =>` with a valid token; see [Getting Started -- Installation](getting-started.md#installation) |
| `initializeSDK()` / `setup(config:)` fails immediately | Expired or reused signed auth params | Issue **fresh** environment key, HMAC signature, and timestamp from your backend per payment session |
| `UNAUTHORIZED` / auth errors | Wrong or revoked credentials | Rotate signing keys on the server; confirm `environmentKey` matches your Spreedly account |
| `ACCOUNT_INACTIVE` | Live card data in a test environment | Use Spreedly test cards or activate the environment |
| Timeouts / network errors | Device or API connectivity | Retry with backoff for transient failures; see [Best Practices](#best-practices) |
| 3DS challenge never appears | Forter3DS SDK not linked, or `#if canImport` not used | Verify `Forter3DS` is added via SPM/CocoaPods; see [3DS Global](3ds-global.md) |
| Screen prevention blocks screenshots in Simulator | `ScreenPreventionSecureView` is active | This is expected behavior; disable in debug builds if needed; see [Security](security.md) |
| Blank form fields / empty `SPLTextField` | `blockJailbrokenDevices` is enabled and device failed integrity checks | Check `Spreedly.isDeviceTrusted`; drop-in components auto-dismiss, but custom forms must handle this — see [Custom Payment Forms](custom-payment-forms.md#prerequisites) |
| SDK returns `.compromisedDevice` error | Device blocked by `SecurityManager` | `Spreedly.initializationError` has the details; see [Security — Runtime Integrity](security.md#runtime-integrity) |

For SDK log delivery issues (Datadog), see [Telemetry Spec -- Operational Readiness](../development/TELEMETRY_SPEC.md#operational-readiness).

### What you can share with Spreedly Support

**OK to share:** SDK version, approximate time (UTC), masked `environment_key` (first 4 characters only), `session_id` from Datadog global attributes (if you use SDK telemetry), `PaymentResult` `errorType` / `apiError`, HTTP status code if shown, iOS version, device model.

**Never share:** Full card number, CVV, full `environmentKey`, raw error responses if they could contain tokens or PII, complete auth signatures or HMAC secrets.

### When to contact support

Open a ticket via [Spreedly Support](https://spreedly.com/support/) after you have confirmed credentials, a fresh init payload, and a minimal reproduction case (or merchant logs scoped as above). Include references to the integration guides you followed ([Getting Started](getting-started.md), [Security](security.md)).

---

## Related Documentation

- [express-checkout.md](express-checkout.md) - CardFormDropIn integration and callbacks
- [3ds-global.md](3ds-global.md) - 3DS authentication and challenge handling
- [offsite-payments.md](offsite-payments.md) - Offsite payment flows and result handling
- [troubleshooting.md](troubleshooting.md) - Installation, build, and runtime troubleshooting
