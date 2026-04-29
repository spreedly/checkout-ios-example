# Offsite Payments - Spreedly iOS SDK

Accept payments via PayPal and other offsite providers using Safari-based checkout.

**Estimated integration time:** ~15 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [SDK Methods](#sdk-methods)
4. [Custom URL Scheme Setup](#custom-url-scheme-setup)
5. [Flow](#flow)
6. [Important Notes](#important-notes)
7. [SwiftUI Integration](#swiftui-integration)
8. [UIKit Integration](#uikit-integration)
9. [Objective-C Integration](#objective-c-integration)
10. [Config Reference](#config-reference)
11. [Merchant Checks](#merchant-checks)
12. [Error Handling](#error-handling)
13. [Troubleshooting](#troubleshooting)
14. [Related Documentation](#related-documentation)

---

## Introduction

### What are Offsite Payments?

Offsite payments let users pay via external providers such as PayPal and Sprel. The customer is redirected to the provider's website or app via `SFSafariViewController`. After completing payment, the user is redirected back to your app via a deep link.

### Offsite vs Standard Comparison

| Feature | Standard (Card) | Offsite |
|---------|-----------------|---------|
| Input | Card number, CVV | Provider selection |
| Tokenization | JSON | Form-encoded |
| Checkout | In-app | Safari |
| Return | Immediate | Deep link redirect |

### Supported Types

- `paypal` - PayPal checkout
- `sprel` - Sprel checkout

For EBANX providers (Pix, Boleto, OXXO, NuPay), see [ebanx-apm.md](ebanx-apm.md). EBANX methods use `submitOffsitePayment` under the hood but have additional configuration requirements covered in that guide.

---

## Prerequisites

Before integrating offsite payments:

- Complete [getting-started.md](getting-started.md) - installation, `Spreedly.setup(config:)`, and credential management
- Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`)
- Register a custom URL scheme in `Info.plist` (see [Custom URL Scheme Setup](#custom-url-scheme-setup))

> **Important:** Fetch signature parameters from your backend and call `Spreedly.setup(config:)` before calling `submitOffsitePayment()`.

---

## SDK Methods

| # | Method | Module | Purpose |
|---|--------|--------|---------|
| 1 | `submitOffsitePayment(config:)` | SpreedlyCore | Create payment method token |
| 2 | `subscribeToPaymentResults` | SpreedlyCore | Listen for results |
| 3 | `SpreedlyOffsiteCheckout.present(transactionToken:)` | SpreedlyUI | Present Safari |
| 4 | `handleOffsiteReturn(url:)` | SpreedlyCore | Handle redirect URL |

> **Note:** The SDK uses `checkTransactionStatus` internally to resolve checkout URLs and final transaction states after Safari returns. When using `SpreedlyOffsiteCheckout`, you should **not** call `checkTransactionStatus` directly -- the SDK manages this automatically and delivers results through `subscribeToPaymentResults`.

---

## Custom URL Scheme Setup

### 1. Register in Info.plist

Add a `CFBundleURLTypes` entry to your app's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.yourapp.offsite</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourAppScheme</string>
        </array>
    </dict>
</array>
```

Or in **Xcode**: Target → Info → URL Types → click **+** → set **URL Schemes** to your custom scheme (e.g., `yourAppScheme`).

> **Note:** Each app target should use its own unique URL scheme. For example, the Swift example uses `spreedlyApp`, while the Objective-C example uses `spreedlyCApp`. Merchants should choose their own consistent scheme for their app.

### 2. redirect_url Format

When calling the purchase API, pass a `redirect_url` using your registered scheme:

```
yourAppScheme://com.yourcompany.yourapp/offsite/checkout
```

The gateway appends the `transaction_token` as a query parameter on redirect. You can use any path structure after the scheme; the SDK matches on the scheme to recognize the redirect.

### 3. Handle Redirect in Your App

When the user completes checkout, the gateway redirects to your `redirect_url`. Pass the URL to the SDK so it can check the transaction status and emit a `PaymentResult`.

**SwiftUI** — in your `App` struct or root view:

```swift
@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    let isSpreedlyURL = Spreedly.shared().handleOffsiteReturn(url: url)
                    if !isSpreedlyURL {
                        // Handle other deep links
                    }
                }
        }
    }
}
```

**UIKit** — in `SceneDelegate`:

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    let isSpreedlyURL = Spreedly.shared().handleOffsiteReturn(url: url)
    if !isSpreedlyURL {
        // Handle other deep links
    }
}
```

**Objective-C** — in `SceneDelegate`:

```objc
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    NSURL *url = URLContexts.allObjects.firstObject.URL;
    if (url) {
        BOOL isSpreedlyURL = [[Spreedly shared] handleOffsiteReturnWithUrl:url];
        if (!isSpreedlyURL) {
            // Handle other deep links
        }
    }
}
```

**Legacy apps without SceneDelegate** — in `AppDelegate`:

```objc
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    BOOL handled = [[Spreedly shared] handleOffsiteReturnWithUrl:url];
    if (!handled) {
        // Handle other URLs
    }
    return handled;
}
```

### 4. callback_url

The `callback_url` is a server-to-server webhook. The gateway POSTs the transaction result to this URL; it is **not** used by the mobile app. Set it to your backend endpoint (e.g., `https://yourbackend.com/spreedly/callback`).

| Parameter | Purpose | Used by |
|-----------|---------|---------|
| `redirect_url` | Redirects the user back to your app after checkout | Mobile app (custom URL scheme) |
| `callback_url` | Server-to-server notification of transaction result | Your backend |

---

## Flow

1. **Create payment method:** Call `submitOffsitePayment(config:)` to receive `payment_method_token` via `PaymentResult`.
2. **Purchase on backend:** Call your purchase API with `payment_method_token`, `redirect_url`, and `callback_url` to receive `transaction_token`. Your backend response will contain the transaction token needed by the SDK:

```json
{
  "transaction": {
    "token": "AbCd1234...",
    "state": "pending",
    "checkout_url": "https://checkout.example.com/..."
  }
}
```

Extract `transaction.token` for use in `SpreedlyOffsiteCheckout.present(transactionToken:)`.

3. **Present checkout:** Call `SpreedlyOffsiteCheckout.present(transactionToken:)`. The SDK fetches the checkout URL and presents Safari directly.
4. **Handle return:** User completes payment. On redirect (or Done tap), the SDK checks status and emits `PaymentResult`.

---

## Important Notes

- **Two responses:** (1) After `submitOffsitePayment` — tokenization; `result.token` is the `payment_method_token`. (2) After checkout — final purchase result; use `result.isSuccess` / `result.state`. Distinguish them with a stage enum.
- **Braintree URL handler ordering:** If your app also uses Braintree, call `BraintreeURLHandler.handleOpen(url:)` before `handleOffsiteReturn(url:)` in your URL handler.
- **Do NOT cancel the subscription** in `onDisappear` — Safari on top can trigger disappear events, killing the subscription before the result arrives.
- **No SDK UI before Safari:** `SpreedlyOffsiteCheckout.present(transactionToken:)` opens `SFSafariViewController` directly on the topmost VC — no intermediate sheet or loader. The merchant controls their own loading indicator.

---

## SwiftUI Integration

```swift
import SpreedlyCore
import SpreedlyUI
import Combine

@State private var paymentResultCancellable: AnyCancellable?
@State private var stage: OffsiteStage = .idle  // idle | creatingPaymentMethod | purchasing | checkout
@State private var isLoading = false
@State private var errorMessage: String?
@State private var successMessage: String?

enum OffsiteStage {
    case idle
    case creatingPaymentMethod
    case purchasing
    case checkout
}

// 1. Subscribe (keep alive — do NOT cancel in onDisappear)
.onAppear {
    paymentResultCancellable?.cancel()
    paymentResultCancellable = Spreedly.shared().subscribeToPaymentResults { result in
        handlePaymentResult(result)
    }
}

// 2. Start flow
func startOffsiteFlow() {
    isLoading = true
    stage = .creatingPaymentMethod
    Task {
        let signatureResult = await fetchSignatureFromBackend()
        guard case .success(let spreedlyConfig) = signatureResult else {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to generate signature"
                stage = .idle
            }
            return
        }
        Spreedly.setup(config: spreedlyConfig)
        let config = OffsitePaymentConfig(
            paymentMethodType: .sprel,
            email: "user@example.com",
            fullName: "Test User",
            country: "US",
            phoneNumber: "1234567890"
        )
        _ = Spreedly.shared().submitOffsitePayment(config: config)
    }
}

// 3. Handle two responses
func handlePaymentResult(_ result: PaymentResult) {
    switch stage {
    case .creatingPaymentMethod:
        if result.isSuccess, let token = result.token {
            stage = .purchasing
            Task { await purchaseWithToken(token) }
        } else if result.isFailure {
            isLoading = false
            stage = .idle
            errorMessage = result.failureDetails?.getDescription() ?? "Failed to create payment method"
        }
    case .purchasing:
        break
    case .checkout:
        isLoading = false
        stage = .idle
        if result.isSuccess {
            successMessage = "Offsite checkout succeeded"
        } else if result.isFailure {
            switch result.state {
            case "processing":
                errorMessage = "Your payment is being processed. Please wait."
            case "gateway_processing_failed":
                errorMessage = "Couldn't complete your payment. Try again."
            case "pending":
                errorMessage = "Your payment is pending."
            default:
                errorMessage = result.failureDetails?.getDescription() ?? "Checkout failed"
            }
        }
    case .idle:
        break
    }
}

// 4. Purchase on your backend, then present checkout
// The example app uses PurchaseAPIClient (see API/PurchaseAPIClient.swift).
// In production, replace this with your own backend endpoint.
func purchaseWithToken(_ paymentMethodToken: String) async {
    let response = try? await yourBackend.offsitePurchase(
        gateway: "your_gateway_token",
        paymentMethodToken: paymentMethodToken,
        amount: amountInCents,
        currencyCode: "USD",
        redirectUrl: "yourAppScheme://com.yourcompany.yourapp/offsite/checkout",
        callbackUrl: "https://yourbackend.com/callback"
    )
    await MainActor.run {
        if let transaction = response?.transaction {
            stage = .checkout
            SpreedlyOffsiteCheckout.present(transactionToken: transaction.token)
        } else {
            isLoading = false
            stage = .idle
            errorMessage = "Purchase failed"
        }
    }
}

// 5. Handle redirect return
// IMPORTANT: Place .onOpenURL in your root @main App struct, NOT in the flow view.
// It is shown inline for readability only.
// See getting-started.md for the canonical onOpenURL setup.
.onOpenURL { url in
    let isSpreedlyURL = Spreedly.shared().handleOffsiteReturn(url: url)
    if !isSpreedlyURL {
        // Handle other custom URL navigations
    }
}
```

---

## UIKit Integration

```swift
import SpreedlyCore
import SpreedlyUI

class OffsitePaymentVC: UIViewController, SpreedlyPaymentDelegate {
    var stage: OffsiteStage = .idle
    var transactionToken: String?  // Set from backend purchase response

    override func viewDidLoad() {
        super.viewDidLoad()
        Spreedly.shared().paymentDelegate = self
    }

    func startOffsiteFlow() {
        stage = .creatingPaymentMethod
        // Generate signature, setup SDK, then:
        let config = OffsitePaymentConfig(
            paymentMethodType: .sprel,
            email: "user@example.com",
            fullName: "Test User",
            country: "US",
            phoneNumber: "1234567890"
        )
        Spreedly.shared().submitOffsitePayment(config: config)
    }

    // Two responses: 1st = tokenization, 2nd = checkout outcome
    func paymentDidComplete(_ result: PaymentResult) {
        DispatchQueue.main.async {
            if self.stage == .creatingPaymentMethod {
                if result.isSuccess, let token = result.token {
                    self.stage = .purchasing
                    self.purchaseWithToken(token)
                } else {
                    self.stage = .idle
                    self.showError(result.failureDetails?.getDescription() ?? "Failed")
                }
            } else if self.stage == .checkout {
                self.stage = .idle
                if result.isSuccess {
                    self.showSuccess("Offsite checkout succeeded")
                } else {
                    self.showError(result.failureDetails?.getDescription() ?? "Checkout failed")
                }
            }
        }
    }

    func purchaseWithToken(_ token: String) {
        // Call your backend; set transactionToken = response.transaction.token, then:
        self.stage = .checkout
        if let tkn = transactionToken {
            SpreedlyOffsiteCheckout.present(transactionToken: tkn)
        }
    }
}

// In SceneDelegate — handle redirect return:
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    let isSpreedlyURL = Spreedly.shared().handleOffsiteReturn(url: url)
    if !isSpreedlyURL {
        // Handle other URLs
    }
}
```

---

## Objective-C Integration

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>

typedef NS_ENUM(NSInteger, OffsiteStage) {
    OffsiteStageIdle,
    OffsiteStageCreatingPaymentMethod,
    OffsiteStagePurchasing,
    OffsiteStageCheckout
};

@interface OffsitePaymentViewController () <SpreedlyPaymentDelegate>
@property (nonatomic, assign) OffsiteStage stage;
@end

@implementation OffsitePaymentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Spreedly shared].paymentDelegate = self;
}

- (void)startOffsiteFlow {
    self.stage = OffsiteStageCreatingPaymentMethod;
    // Generate signature, setup SDK, then:
    OffsitePaymentConfig *config = [[OffsitePaymentConfig alloc]
        initWithPaymentMethodType:OffsitePaymentMethodTypeSprel
        redirectUrl:nil
        email:@"user@example.com"
        fullName:@"Test User"
        firstName:nil
        lastName:nil
        documentId:nil
        country:@"US"
        countryCode:nil
        phoneNumber:@"1234567890"
        address1:nil
        address2:nil
        city:nil
        state:nil
        zip:nil];
    [[Spreedly shared] submitOffsitePaymentWithConfig:config];
}

// Two responses: 1st = tokenization, 2nd = checkout outcome
- (void)paymentDidComplete:(PaymentResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.stage == OffsiteStageCreatingPaymentMethod) {
            if (result.isSuccess && result.token.length > 0) {
                self.stage = OffsiteStagePurchasing;
                [self purchaseWithToken:result.token];
            } else {
                self.stage = OffsiteStageIdle;
                [self showError:result.failureDetails.getDescription ?: @"Failed"];
            }
        } else if (self.stage == OffsiteStageCheckout) {
            self.stage = OffsiteStageIdle;
            if (result.isSuccess) {
                [self showSuccess:@"Offsite checkout succeeded"];
            } else {
                [self showError:result.failureDetails.getDescription ?: @"Checkout failed"];
            }
        }
    });
}

// After backend purchase succeeds, present checkout with the transaction token:
- (void)presentCheckoutWithTransactionToken:(NSString *)transactionToken {
    self.stage = OffsiteStageCheckout;
    [SpreedlyOffsiteCheckout presentWithTransactionToken:transactionToken];
}

@end
```

In `SceneDelegate.m` — handle redirect return:

```objc
// Add this to your SceneDelegate.m
@implementation SceneDelegate

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    NSURL *url = URLContexts.allObjects.firstObject.URL;
    if (url) {
        BOOL isSpreedlyURL = [[Spreedly shared] handleOffsiteReturnWithUrl:url];
        if (!isSpreedlyURL) {
            // Handle other URLs
        }
    }
}

@end
```

---

## Config Reference

`OffsitePaymentConfig` parameters:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `paymentMethodType` | Yes | `.paypal`, `.sprel` (for EBANX types like `.pix`, `.nupay`, see [ebanx-apm.md](ebanx-apm.md)) |
| `email` | No | Customer email |
| `fullName` | No | Full name |
| `firstName` | No | First name |
| `lastName` | No | Last name |
| `documentId` | No | Taxpayer ID — use `DocumentId` type (see [DocumentId](#documentid)) |
| `country` | No | Country code |
| `countryCode` | No | ISO country code |
| `phoneNumber` | No | Phone number |
| `address1` | No | Address line 1 |
| `address2` | No | Address line 2 |
| `city` | No | City |
| `state` | No | State/region |
| `zip` | No | Postal code |
| `redirectUrl` | No (tokenization), **Yes** (purchase) | Not required for `submitOffsitePayment()` (tokenization step), but your backend **must** include `redirect_url` in the Spreedly purchase API call. Without it, the payment provider cannot redirect the user back to your app after checkout. |

#### DocumentId

The `documentId` parameter in `OffsitePaymentConfig` is `DocumentId?`, not `String?`. It is required for providers that need a taxpayer ID (e.g., Sprel for Brazil, EBANX methods).

**Swift:**

```swift
DocumentId(key: .documentId, value: "853.513.468-93")
```

**Objective-C:**

```objc
[[DocumentId alloc] initWithKey:DocumentIdKeyDocumentId value:@"853.513.468-93" customKey:nil]
```

---

## Merchant Checks

| Check | Action |
|-------|--------|
| **Two responses** | Use a stage enum: first = tokenization (use token for purchase), second = checkout outcome |
| **Transaction nil** | If `response.transaction` is nil after purchase, do not call `SpreedlyOffsiteCheckout.present(transactionToken:)`; show error |
| **result.state** | `"processing"` — "Being processed..."; `"gateway_processing_failed"` — "Couldn't complete..."; `"pending"` — "Pending..."; else use `failureDetails` |
| **redirect_url** | Must use a custom URL scheme registered in `Info.plist`. Gateway appends `transaction_token` on redirect |

---

## Error Handling

### Tokenization Errors

When `result.isFailure` in the `creatingPaymentMethod` stage:

- Check `result.failureDetails?.getDescription()` for the error message
- Ensure `Spreedly.setup(config:)` was called with valid signature parameters
- Verify `paymentMethodType` and required fields for the provider

### Checkout Errors

When `result.isFailure` in the `checkout` stage:

- `result.state == "processing"` — Payment is being processed; inform the user to wait
- `result.state == "gateway_processing_failed"` — Gateway could not complete; suggest retry
- `result.state == "pending"` — Payment is pending; show appropriate message
- Otherwise use `result.failureDetails?.getDescription()` for user-facing error

### Network Errors

Network failures during tokenization or status check are reported via `PaymentResult` with `isFailure` true. Check connectivity and retry if appropriate.

For error handling patterns, see [error-handling.md](error-handling.md).

---

### Blocked Devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK blocks offsite payment flows automatically. The flow returns immediately without opening Safari, and a `PaymentResult.failure` is published. See [Security — Runtime Integrity](security.md#runtime-integrity) for details.

## Troubleshooting

### Payment result not received

- Subscribe to `subscribeToPaymentResults` (or set `paymentDelegate`) **before** calling `submitOffsitePayment`
- Do NOT cancel the subscription in `onDisappear` — Safari can trigger disappear events
- Ensure the subscription/delegate remains active until the flow completes

### Safari does not open

- Verify `transaction` is non-nil from your purchase API response
- Ensure `transaction.token` is valid before calling `SpreedlyOffsiteCheckout.present(transactionToken:)`
- Check that your backend returns a valid `checkout_url` for the transaction

### App not opening on redirect

- Verify `CFBundleURLTypes` is correctly configured in `Info.plist`
- Ensure `redirect_url` in your purchase API matches your registered URL scheme
- Test that `onOpenURL` (SwiftUI) or `scene:openURLContexts:` (UIKit) is invoked when opening the app via the redirect URL

### Tokenization fails immediately

- Call `Spreedly.setup(config:)` with valid signature parameters before `submitOffsitePayment`
- Fetch signature parameters from your backend; they are time-sensitive
- Verify `paymentMethodType` is set correctly (`.paypal` or `.sprel`)

---

## Related Documentation

- [ebanx-apm.md](ebanx-apm.md) – Pix, Boleto, OXXO, NuPay with gateway-specific fields
- [stripe-apm.md](stripe-apm.md) – Stripe alternative payment methods (iDEAL, Bancontact)
- [braintree-apm.md](braintree-apm.md) – Braintree PayPal and Venmo
- [getting-started.md](getting-started.md) – Installation and basic setup
- [error-handling.md](error-handling.md) – Error types and handling patterns
- [OFFSITE_FLOW.md](../development/OFFSITE_FLOW.md) – Detailed flow diagrams for offsite payments
