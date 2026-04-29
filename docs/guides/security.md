# Security Best Practices - Spreedly iOS SDK

Protect sensitive payment data with screen prevention, secure storage, and PCI compliance.

**Estimated time:** ~10 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Runtime Integrity](#runtime-integrity)
3. [Screen Prevention](#screen-prevention)
4. [Secure Value Collection](#secure-value-collection)
5. [API Key Handling](#api-key-handling)
6. [Token Storage](#token-storage)
7. [PCI Compliance](#pci-compliance)
8. [Memory Management](#memory-management)
9. [Logging Security](#logging-security)
10. [Binary Hardening](#binary-hardening)
11. [Best Practices Checklist](#best-practices-checklist)
12. [Testing Security](#testing-security)
13. [Related Documentation](#related-documentation)

---

## Prerequisites

- Complete [Getting Started](getting-started.md) (SDK installed and initialized)
- Familiarity with your app's `Info.plist` and entitlements configuration

---

## Introduction

The Spreedly iOS SDK provides security features to meet PCI DSS requirements and protect sensitive payment information. It covers screen prevention, secure value collection, API key handling, token storage, and other security practices for integrating the SDK into your application.

---

## Runtime Integrity

The SDK performs runtime security checks during initialization to detect compromised environments. These checks run automatically and use only public POSIX/Darwin APIs (App Store safe).

### What It Detects

- **Debugger attachment** — LLDB, Frida, or other debuggers attached to the process
- **Jailbroken devices** — sandbox escape, hooking framework injection (MobileSubstrate, libhooker, FridaGadget, etc.), known jailbreak filesystem artifacts

### Blocking Jailbroken Devices (Opt-In)

By default, the SDK runs on all devices. To block all SDK operations on compromised devices, enable `blockJailbrokenDevices` before initialization.

**Option A — Config property** (when using `setup(config:)`):

```swift
let config = SpreedlyConfig(environmentKey: "your-environment-key")
config.blockJailbrokenDevices = true
Spreedly.setup(config: config)
```

**Option B — Static property** (when using `initializeSDK()`):

```swift
Spreedly.blockJailbrokenDevices = true
Spreedly.initializeSDK()
```

**Objective-C (either option):**

```objc
// Option A
SpreedlyConfig *config = [[SpreedlyConfig alloc] initWithEnvironmentKey:@"your-environment-key"];
config.blockJailbrokenDevices = YES;
[Spreedly setupWithConfig:config];

// Option B
Spreedly.blockJailbrokenDevices = YES;
[Spreedly initializeSDK];
```

**Checking the result:**

```swift
if let error = Spreedly.initializationError {
    print("SDK blocked: \(error.message)")
    print("Signals: \(error.signals)")
    return
}

// Or check anytime:
if !Spreedly.isDeviceTrusted {
    // SDK is blocked — show a fallback UI or redirect to web checkout
}
```

When blocking is enabled and the device is compromised, `Spreedly.initializationError` is set with a `SpreedlySecurityError` containing:
- `code` — the error category (`.deviceCompromised`)
- `message` — human-readable description
- `signals` — which specific checks fired (e.g. `["sandbox_broken", "dylib_injection"]`)

### What Gets Blocked

When the SDK is blocked, **all operations fail gracefully** — no card data UI appears, no network traffic leaves the device:

- **Card forms** (`CardFormDropIn`, `SPLTextField`) render as invisible — no text fields appear
- **Recaching UI** (`CVVRecachingView`) does not render and emits a failure result
- **3DS challenges** (`DoChallengeIfNeeded`) do not render and emit a 3DS failure result
- **APM flows** (Stripe `present()`, Braintree `present()`) reject immediately with a `PaymentResult.failure`
- **Offsite payments** (`OffsitePaymentSafariFlow.present()`) reject immediately
- **Network calls** — a `BlockedNetworkClient` is injected so any network request throws without leaving the device
- **3DS integrations** (Forter, Gateway-Specific) check the blocked state and emit failure results

Merchants observing `paymentResultPublisher` or the `SpreedlyPaymentDelegate` will receive a `PaymentResult.failure` with an error message indicating the SDK is blocked.

### Blocked-Device Behavior by Component

| Component | Presentation | What happens when blocked |
|---|---|---|
| `CardFormDropIn` | `.sheet` | Auto-dismisses the sheet, publishes `PaymentResult.failure` via `paymentResultPublisher` |
| `CVVRecachingView` | `.sheet` | Auto-dismisses the sheet, publishes `PaymentResult.failure` |
| `CVVRecachingView` | `.dialog` (alert mode) | Prevents dimming overlay, auto-dismisses via `onDismiss` callback |
| `DoChallengeIfNeeded` | `.sheet` | Auto-dismisses, emits `ThreeDSChallengeResult.failure` via `threeDSChallengeResultPublisher` |
| `SPLTextField` (custom forms) | Inline | Renders blank (zero-size placeholder). **Merchant must check `Spreedly.isDeviceTrusted` on appear and show an error.** See [Custom Payment Forms](custom-payment-forms.md#prerequisites). |
| Braintree `present()` | UIKit | Returns immediately, publishes `PaymentResult.failure` |
| Stripe `present()` | UIKit | Returns immediately, publishes `PaymentResult.failure` |
| Offsite `present()` | Safari | Returns immediately, publishes `PaymentResult.failure` |
| `createCreditCard()` / network | N/A | `BlockedNetworkClient` throws immediately — no data leaves the device |
| 3DS (Global / Gateway-Specific) | N/A | Emits `ThreeDSChallengeResult.failure`, no UI shown |

### How Errors Reach the Merchant

Blocked-device errors flow through the same channels merchants already subscribe to:

| Flow | Error channel | What the merchant receives |
|---|---|---|
| Drop-in forms, recaching, APMs | `Spreedly.shared().subscribeToPaymentResults` / `SpreedlyPaymentDelegate` | `PaymentResult` with `isFailure == true` and message "SDK blocked by security check" |
| 3DS challenges | `Spreedly.shared().subscribeToThreeDSChallengeResults` | `ThreeDSChallengeResult` with `isFailure == true` |
| Custom forms (`SPLTextField`) | `Spreedly.initializationError` / `Spreedly.isDeviceTrusted` | Merchant checks these on appear — fields are blank but no automatic error is published |
| Direct API calls | `BlockedNetworkClient` throws | `NSError` in `spreedlySecurityErrorDomain` with "SDK blocked" message |

### Testing Blocked-Device Behavior

Real integrity checks only run on **physical devices in RELEASE builds**. On the Simulator, all checks return clean.

To test the blocking flow during development, use the DEBUG-only override in your example/test code:

```swift
#if DEBUG
SecurityManager.shared.setOverrideAssessment(
    SecurityAssessment(level: .compromised, signals: ["sandbox_broken", "dylib_injection"])
)
#endif
```

Set the override **before** calling `Spreedly.setup(config:)`. The SDK will treat the device as compromised and block. Pass `nil` to restore normal behavior.

### Recovery

If the device condition changes (e.g., a debugger is detached), calling `Spreedly.setup(config:)` or `Spreedly.initializeSDK()` again re-runs the assessment. If it passes, the block is cleared and the SDK resumes normal operation.

### Querying Security Status Directly

You can also call `SecurityManager` directly for custom policy decisions:

```swift
let assessment = SecurityManager.shared.performAssessment()
// assessment.level: .clean, .suspicious, or .compromised
// assessment.signals: ["sandbox_broken", "dylib_injection", ...]
// assessment.isCompromised: true when 2+ signals fired
```

### DEBUG Builds

Debugger detection is disabled in DEBUG builds so Xcode development is not disrupted. Jailbreak checks are disabled on the iOS Simulator.

---

## Screen Prevention

The SDK includes screen prevention features to protect sensitive payment information from unauthorized capture. This is important for PCI DSS compliance and protecting user payment data.

### What It Protects Against

- **Screenshots**: Prevents users from taking screenshots of protected content
- **Screen Recording**: Blocks screen recording of sensitive payment information
- **Screen Sharing**: Prevents content from being shared via AirPlay, screen mirroring, or other sharing methods
- **App Switcher Preview**: Automatically applies privacy overlay when the app goes to background to protect previews in the app switcher

### Three Layers of Protection

1. **View-level Protection**: Prevents screenshots, screen recordings, and screen sharing of protected views
2. **App Switcher Protection**: Automatically applies privacy overlay when app goes to background
3. **Automatic Management**: Handles lifecycle events and screen capture detection

### SwiftUI Integration

Apply screen prevention to any SwiftUI view using the `.screenPrevention()` modifier. The most effective approach is to apply it at the root screen level.

**Apply at Root Level (Recommended):**

```swift
import SwiftUI
import SpreedlyUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .screenPrevention()
        }
    }
}
```

**Apply to Sheets Separately:**

Sheets require separate protection. Apply `.screenPrevention()` inside the `.sheet()` modifier:

```swift
.sheet(isPresented: $showPaymentForm) {
    PaymentFormView()
        .screenPrevention()
}
```

**Custom Placeholder Text:**

Provide custom placeholder text that appears in screenshots, screen recordings, and app switcher previews:

```swift
WindowGroup {
    MainView()
        .screenPrevention(placeholderText: "Secure Payment")
}

// In sheets
.sheet(isPresented: $showForm) {
    PaymentFormView()
        .screenPrevention(placeholderText: "Payment Information")
}
```

**CardFormDropIn:** Apply `.screenPrevention()` to `CardFormDropIn` when presenting it. Example:

```swift
.sheet(isPresented: $showForm) {
    CardFormDropIn(
        yearFormat: yearFormat,
        nameDisplayMode: nameDisplayMode,
        onProcessingResult: { _ in }
    )
    .screenPrevention()
}
```

**Important:** Screen prevention cannot be applied to 3DS challenges (`DoChallengeIfNeeded` or `DoChallengeIfNeededViewController`) because the challenge UI is presented in a separate view controller that cannot be wrapped in the protection layer.

### UIKit Integration

**CardFormDropInViewController:** Wrap `CardFormDropInViewController` with `wrapInSecureViewController(placeholderText:)` before presenting. Example:

```swift
let dropInVC = CardFormDropInViewController(
    otherFields: [],
    yearFormat: .fourDigit,
    nameDisplayMode: .separateFields,
    onProcessingResult: { _ in }
)
let secureVC = dropInVC.wrapInSecureViewController(placeholderText: "Payment information is protected")
present(secureVC, animated: true)
```

For other UIKit view controllers, use the `wrapInSecureViewController()` extension:

```swift
import UIKit
import SpreedlyUI

let sensitiveDataVC = SensitiveDataViewController()
let secureVC = sensitiveDataVC.wrapInSecureViewController(
    placeholderText: "Payment information is protected"
)
present(secureVC, animated: true)
```

**Note:** The `placeholderText` parameter defaults to `""` and is optional.

### Objective-C Integration

For custom view controllers that display sensitive data, use `wrapInSecureViewControllerWithPlaceholderText:`:

```objc
#import <SpreedlyUI/SpreedlyUI-Swift.h>

SensitiveDataViewController *sensitiveVC = [[SensitiveDataViewController alloc] init];
UIViewController *secureVC = [sensitiveVC wrapInSecureViewControllerWithPlaceholderText:@"Secure Payment"];
[self presentViewController:secureVC animated:YES completion:nil];
```

**Note:** The `placeholderText` parameter defaults to `""` and is optional.

For root-level wrapping in `SceneDelegate` (protecting the entire app):

```objc
// In SceneDelegate scene:willConnectToSession:options:
UIViewController *secureVC = [navController wrapInSecureViewControllerWithPlaceholderText:@""];
self.window.rootViewController = secureVC;
```

---

## Secure Value Collection

The SDK uses `SecureValueContainer` to handle sensitive fields such as card number and CVV. Sensitive data never passes through your application code in plain text.

- **SecureValueContainer** handles card number and CVV collection
- **CVV is never stored locally**; it is only transmitted securely to Spreedly
- Sensitive data is encrypted using industry-standard encryption via Apple's CryptoKit framework
- When using SDK UI components, `SecureValueContainer` is managed automatically
- `SecureValueContainer` cleans up after use

---

## API Key Handling

### Never Hardcode API Keys

Never embed API keys directly in source code. Hardcoded keys can be extracted from app binaries and exposed in version control.

**Bad Practice:**

```swift
Spreedly.setup(config: SpreedlyConfig(
    environmentKey: "production_key_abc123xyz"
))
```

**Good Practice:**

Fetch credentials from your backend server. Store the environment key securely (for example, in Keychain or a secure configuration service) and load it at runtime.

```swift
// Fetch from backend before each payment session
let config = await fetchSpreedlyConfigFromBackend()
Spreedly.setup(config: config)
```

### Signature Parameters

Signature parameters (`nonce`, `signature`, `certificateToken`, `timestamp`) are **time-sensitive** and must be:

- Fetched from your backend server
- Generated fresh before each payment session
- Never stored or reused across sessions

Call `Spreedly.setup(config:)` with valid signature parameters before any tokenization, payment form presentation, or 3DS challenge flow.

**Example: Fetch signature before presenting the payment form**

```swift
// Before presenting the payment form
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
    // Now present the form
}
```

---

## Token Storage

### Use iOS Keychain for Sensitive Tokens

Store sensitive tokens (such as session tokens or refresh tokens) in the iOS Keychain. Never store them in UserDefaults or plain text files.

**Recommended:**

```swift
import Security

// Use Keychain Services for sensitive token storage
// Use Keychain Services API for secure token persistence
```

### Never Store In

- **UserDefaults** or SharedPreferences
- **Plain text files**
- **Unencrypted** local databases (Core Data, SQLite)

### Payment Method Tokens

Payment method tokens returned by Spreedly are non-sensitive and can be stored for future use (for example, to charge a saved card). Store them in Keychain if you persist them locally, or pass them to your backend for server-side storage.

---

## PCI Compliance

The SDK helps you reduce PCI DSS scope:

- **Sensitive data handling**: Card number and CVV are collected and processed within `SecureValueContainer`; no card data passes through your application code
- **No card data in merchant app**: Sensitive cardholder data is encrypted and transmitted directly to Spreedly
- **HTTPS/TLS**: All network communication uses HTTPS/TLS
- **Screen prevention**: Protects against screenshot and screen recording capture of payment forms

---

## Memory Management

Proper memory management prevents leaks and reduces the risk of sensitive data lingering in memory.

### Cancel Combine Subscriptions

When using Combine publishers (for example, `subscribeToPaymentResults`), cancel subscriptions when views disappear:

```swift
.onDisappear {
    cancellable?.cancel()
    cancellable = nil
}
```

### SecureValueContainer Cleanup

`SecureValueContainer` cleans up after use. When using programmatic recaching, ensure you call `SecureValueContainer.shared.stopCollection()` when finished, or rely on the SDK's automatic cleanup when using UI components.

---

## Logging Security

The SDK's logging system automatically redacts sensitive data via `LogSanitizer`:

- **Card numbers** (PANs) are sanitized in log output
- **Expiry dates** are redacted
- **API keys**, environment keys, and credentials are redacted
- **CVV/CVC** and other sensitive fields are never logged
- **Phone numbers** and emails are redacted in sensitive contexts
- **Card data in JSON payloads** is sanitized
- **URL path tokens** (e.g. transaction tokens in API paths) are masked at multiple layers

### Production Recommendations

Use `SpreedlyLoggerConfiguration` presets for one-step setup:

```swift
#if DEBUG
Spreedly.configureLogging(.debug)     // console on, min .debug
#else
Spreedly.configureLogging(.production) // console off, Datadog at .warn
#endif
```

Or use fine-grained control:

```swift
Spreedly.setLogLevel(.none)           // suppress all console output
Spreedly.setDatadogLogLevel(.error)   // Datadog receives errors only
Spreedly.disableLogging()             // equivalent to setLogLevel(.none)
```

- Avoid `.debug` and `.verbose` in production builds
- Never log CVV or full card numbers in your own code

### Custom Logger PCI Compliance

When you inject a custom logger via `Spreedly.setLogger(_:)`:

- **All messages are sanitized** before delivery — card numbers, CVV, tokens, API keys, and PII are redacted by `LogSanitizer` before your code receives them
- **Error objects** are passed as-is so you can inspect `NSError` domain/code
- The SDK holds a **weak** reference — keep a strong reference elsewhere
- Your logger's own `minLogLevel` is respected, so set it to `.warn` or `.error` in production to minimize noise

```swift
// Production-safe custom logger
final class ProductionLogger: SpreedlyLogger {
    var minLogLevel: LogLevel = .error  // only errors in production

    func verbose(tag: String, message: String, error: Error?) { }
    func debug(tag: String, message: String, error: Error?)   { }
    func info(tag: String, message: String, error: Error?)    { }
    func warn(tag: String, message: String, error: Error?)    { }
    func error(tag: String, message: String, error: Error?) {
        // Safe to log — message is already PCI-sanitized by the SDK
        YourObservabilityService.logError(tag: tag, message: message, error: error)
    }
    func isLoggable(level: LogLevel) -> Bool {
        level.shouldLog(minLevel: minLogLevel)
    }
}
```

### os_log Persistence

The SDK uses Apple's unified logging (`os_log`) for console output. Be aware that `os_log` output can persist in the system log store and may be exported via `sysdiagnose` or accessed through device management profiles. For production apps, use `Spreedly.configureLogging(.production)` or `Spreedly.disableLogging()` to suppress all SDK console output.

### Third-Party SDK Logging

The Spreedly SDK does not control logging from third-party SDKs it depends on (Braintree, Stripe, Datadog). These SDKs have their own logging systems that may output payment-related information. You should configure these independently:

- **Braintree**: Refer to [Braintree iOS SDK documentation](https://developer.paypal.com/braintree/docs/start/hello-client/ios/v5) for logging configuration.
- **Stripe**: Refer to [Stripe iOS SDK documentation](https://docs.stripe.com/payments/accept-a-payment?platform=ios) for controlling log output.
- **Datadog**: The Spreedly SDK initializes Datadog via a build-time injected client token. Spreedly sanitizes all messages before sending. If you also use Datadog directly in your app, ensure your own logs do not contain PCI data.

### Error Message Sanitization

The SDK automatically sanitizes all public-facing error messages in `FailedDetails`, `APIErrorHandler`, and logging. Merchants no longer need to call `sanitizeForDisplay()` — error descriptions returned by `getDescription()` and similar APIs are already safe to log or display.

For displaying masked payment tokens in your UI (e.g., "•••• 4242"), use `Spreedly.maskedToken(_:)`. For logging, use the SDK's `logInfo`/`logError` functions, which auto-sanitize output.

---

## Binary Hardening

The SDK applies hardening techniques to internal API endpoints, sensitive string constants, and network configuration. This prevents casual extraction of SDK internals from the compiled framework binary using tools like `strings` or disassemblers. Combined with Apple's standard code signing and App Store encryption, this raises the cost of reverse engineering the SDK's network layer.

No action is required from merchants — binary hardening is applied automatically during the SDK build process.

---

## Best Practices Checklist

- [ ] Consider enabling `blockJailbrokenDevices` for high-risk payment flows
- [ ] Check `Spreedly.initializationError` after setup when blocking is enabled, or `Spreedly.isDeviceTrusted` at any time
- [ ] Apply `.screenPrevention()` to payment forms and custom views displaying sensitive data
- [ ] Fetch signature parameters from your backend before each payment session
- [ ] Cancel Combine subscriptions in `onDisappear` (or `dealloc` for Objective-C)
- [ ] Use Keychain for sensitive token storage; never use UserDefaults or plain text
- [ ] Set log level to `.warn` or `.error` in production
- [ ] Never log CVV or full card numbers
- [ ] Never hardcode API keys; fetch from backend or secure configuration
- [ ] Use HTTPS for all network communications
- [ ] Protect app switcher previews (screen prevention handles this automatically when applied)

---

## Testing Security

### Test Screenshot Prevention

1. Apply `.screenPrevention()` to a view
2. Take a screenshot (Command+Shift+3 on simulator, or device buttons)
3. Verify the screenshot shows placeholder text or blank content

### Test Screen Recording Prevention

1. Start screen recording on your device (Control Center to Screen Recording)
2. Navigate to a protected view
3. Verify the recording shows placeholder text or blank content

### Test App Switcher Protection

1. Navigate to a protected view
2. Put the app in background (home gesture or button)
3. Open app switcher
4. Verify the app preview shows blur overlay or placeholder text

---

## Related Documentation

- [getting-started.md](getting-started.md) - SDK setup and initialization
- [error-handling.md](error-handling.md) - Error handling and troubleshooting
- [recaching.md](recaching.md) - CVV recaching and saved payment methods
