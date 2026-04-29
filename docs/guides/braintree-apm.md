# Braintree Integration (PayPal / Venmo) - Spreedly iOS SDK

Accept PayPal and Venmo payments via the native Braintree SDK.

**Estimated integration time:** ~15 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Merchant-to-SDK Flow](#merchant-to-sdk-flow)
4. [URL Handling](#url-handling)
5. [SDK Methods](#sdk-methods)
6. [Flow](#flow)
7. [Backend API](#backend-api)
8. [SwiftUI Integration](#swiftui-integration)
9. [UIKit Integration](#uikit-integration-swift)
10. [Objective-C Integration](#objective-c-integration)
11. [Important Notes](#important-notes)
12. [Troubleshooting](#troubleshooting)
13. [Related Documentation](#related-documentation)

---

## Introduction

Braintree lets users pay with **PayPal** or **Venmo** via the native Braintree SDK. Unlike standard offsite flows, there is **no payment method tokenization step** — your backend creates a purchase on the Braintree gateway; the SDK presents the PayPal/Venmo flow and returns a **nonce** (not a token); your backend then calls Spreedly's confirm API to complete the transaction.

### Key Characteristics

- **No tokenization step:** Backend creates the purchase directly on the Braintree gateway
- **Returns nonce, not token:** Merchant sends the nonce to backend for `/confirm.json`
- **Native Braintree SDK UI:** Uses Braintree's native PayPal and Venmo flows

### Comparison: Offsite vs Stripe APM vs Braintree

| Feature | Offsite (PayPal/Sprel) | Stripe APM | Braintree (PayPal/Venmo) |
|---------|------------------------|------------|--------------------------|
| Tokenization | Yes (`submitOffsitePayment`) | No | No |
| Checkout | Safari | Stripe PaymentSheet | Native Braintree SDK |
| Return value | Token | Result state | Nonce |
| Backend step | Purchase with token | Purchase with client_secret | Purchase, then confirm with nonce |

---

## Prerequisites

Before integrating Braintree:

- Complete [getting-started.md](getting-started.md) (installation, basic setup)
- Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`)
- **Braintree account** with PayPal and/or Venmo enabled
- **Braintree gateway** configured in Spreedly
- **Braintree iOS SDK v7.x** — resolved transitively when you add `SpreedlyBraintree` (both SPM and CocoaPods). No extra Braintree dependencies needed.
- **Info.plist:** Set **Bundle display name** (`CFBundleDisplayName`). Some flows (including Venmo) require it to be non-nil; otherwise you may see: *"CFBundleDisplayName must be non-nil. Please set 'Bundle display name' in your Info.plist."*
- **Weak linking:** The Spreedly SDK compiles without Braintree packages; add `SpreedlyBraintree` to your app target only if you use Braintree. If Braintree is not linked, `SpreedlyBraintreeCheckout.present(config:)` will publish a failure gracefully (no crash) and `BraintreeURLHandler.handleOpen(url:)` will return `false`.

### How to Add Braintree (Swift Package Manager)

Add `SpreedlyBraintree` from `checkout-ios-package`. The required Braintree modules (Core, PayPal, Venmo, DataCollector) are resolved as transitive dependencies — no separate Braintree package needed.

### How to Add Braintree (CocoaPods)

Add `pod 'SpreedlyBraintree'` to your Podfile — Braintree is included **automatically** as a transitive dependency. You do **not** need a separate `pod 'Braintree'` entry.

---

## Merchant-to-SDK Flow

```
Step 1: Backend creates purchase
        POST purchase (amount, payment_method_type: "paypal" or "venmo", offsite_sync: true)
        Response: transaction_token + client_token

Step 2: Build BraintreeCheckoutConfig, subscribe to payment result, present
        BraintreeCheckoutConfig(transactionToken, paymentType, merchantDisplayName, clientToken, amount, currencyCode)
        Spreedly.shared().subscribeToPaymentResults { ... }
        SpreedlyBraintreeCheckout.present(config:)

Step 3: PaymentResult with nonce
        On success: result.nonce
        Send nonce to backend for confirm

Step 4: Backend calls /confirm.json
        POST confirm with nonce + device_data
```

---

## URL Handling

When the user returns from the PayPal or Venmo app, iOS can open your app via a custom URL scheme or Universal Link. Forward the URL to the SDK; no Braintree-specific logic is required beyond the handler call.

### Custom URL Scheme (Required)

Register in **Info.plist**: `CFBundleURLSchemes` = `$(PRODUCT_BUNDLE_IDENTIFIER).spreedly.braintree`

Example: `com.yourapp.spreedly.braintree://...`

This serves as a fallback when Universal Links don't work (e.g. AASA file not hosted, or user has not visited the domain).

### LSApplicationQueriesSchemes

Add `LSApplicationQueriesSchemes` to detect installed payment apps:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <!-- Braintree v7: PayPal app detection -->
    <string>paypal</string>
    <!-- Braintree v6 legacy: Venmo app detection (optional in v7) -->
    <string>com.venmo.touch.v2</string>
</array>
```

- **`paypal`** — Required for Braintree v7. The `BTPayPalClient` uses this to check if the PayPal app is installed for App Switch. Without it, PayPal always falls back to the browser flow.
- **`com.venmo.touch.v2`** — Legacy from Braintree v6. In v7, `BTVenmoClient` uses Universal Links and does not call `canOpenURL`. Including it is harmless but no longer necessary for v7 Venmo.

### Universal Links

The SDK hardcodes `https://spreedly.com/braintree/return` as the Universal Link base URL. This is passed to `BTPayPalClient` and `BTVenmoClient` automatically — **you do not configure this URL**.

For Universal Links to work, **two things** must be true:

1. **Merchant:** Add `applinks:spreedly.com` to the Associated Domains entitlement in your app's `.entitlements` file.
2. **Spreedly (infrastructure):** Host an `apple-app-site-association` (AASA) file at `https://spreedly.com/.well-known/apple-app-site-association` that includes your app's team ID and bundle identifier.

> **Current status:** The AASA file at `https://spreedly.com/.well-known/apple-app-site-association` exists but may not include Braintree/Venmo app-link paths. Verify the file includes your app's associated domains for the `braintree/return` path before relying on Venmo Universal Links. See the impact below.

**Impact without a working AASA file:**

- **PayPal:** Falls back to the custom URL scheme (`{bundleId}.spreedly.braintree`). App Switch still works.
- **Venmo:** **Returns will fail silently.** Braintree v7 `BTVenmoClient` uses Universal Links **only** — there is no custom URL scheme fallback. The Venmo app opens but cannot redirect back to your app.

> **Venmo Warning:** Until the AASA file at `spreedly.com` includes Braintree/Venmo app-link paths and is confirmed working, Venmo integration through Braintree is unreliable. Test Venmo returns thoroughly before shipping to production. PayPal is unaffected (has custom scheme fallback).

### URL Reference Table

| What | Value | Where to Configure |
|------|-------|--------------------|
| Universal Link (SDK-managed) | `https://spreedly.com/braintree/return` | No merchant action — SDK hardcodes this |
| Associated Domain | `applinks:spreedly.com` | `.entitlements` file (required for Venmo, recommended for PayPal) |
| Custom URL scheme (fallback) | `$(PRODUCT_BUNDLE_IDENTIFIER).spreedly.braintree` | `Info.plist` > `CFBundleURLSchemes` |
| PayPal app detection (v7) | `paypal` | `Info.plist` > `LSApplicationQueriesSchemes` |
| Venmo app detection (v6 legacy) | `com.venmo.touch.v2` | Optional in v7 |

### Handler Order

**Important:** Call **BraintreeURLHandler.handleOpen(url:)** FIRST, then `handleOffsiteReturn(url:)`. If Braintree returns `true`, the URL was for Braintree; otherwise continue with offsite handling.

> **Placement:** `BraintreeURLHandler.handleOpen(url:)` must be called in the root `@main App` struct's `.onOpenURL` (SwiftUI) or in `SceneDelegate.scene(_:openURLContexts:)` (UIKit/ObjC) -- NOT inside the Braintree flow view. See [getting-started.md](getting-started.md) for the complete URL handling setup.

| Mechanism | Description | What you do |
|-----------|-------------|-------------|
| **Custom URL scheme** | `$(PRODUCT_BUNDLE_IDENTIFIER).spreedly.braintree` | Register in Info.plist. In `onOpenURL` or SceneDelegate, call `BraintreeURLHandler.handleOpen(url:)` first; if it returns `true`, return. Otherwise call `handleOffsiteReturn(url:)`. |
| **Universal Link** | `https://spreedly.com/braintree/return?...` | Same as above: forward URL to `BraintreeURLHandler.handleOpen(url:)` first. Add `applinks:spreedly.com` to Associated Domains. |

---

## SDK Methods

| # | Method | Module | Purpose |
|---|--------|--------|---------|
| 1 | Backend: create Braintree purchase | Merchant backend | Get `transaction_token` and `client_token` (in `gateway_specific_response_fields.braintree.client_token`) |
| 2 | `BraintreeURLHandler.handleOpen(url:)` / `BraintreeURLHandlerObjC.handleOpenWithUrl:` | SpreedlyBraintree | Forward return URL from PayPal/Venmo so SDK can complete the flow |
| 3 | `BraintreeCheckoutConfig(transactionToken:paymentType:merchantDisplayName:clientToken:amount:currencyCode:)` | SpreedlyCore | Build config for checkout (`merchantDisplayName` can be `""`) |
| 4 | `SpreedlyBraintreeCheckout.present(config:)` / `present(config:from:)` / `presentWithConfig:` | SpreedlyBraintree | Present PayPal or Venmo flow. The no-argument variant finds the topmost VC automatically. Use `present(config:from:)` if you need to specify the presenting view controller (e.g., in complex navigation hierarchies). |
| 5 | `Spreedly.shared().subscribeToPaymentResults { }` (Swift) or `SpreedlyPaymentDelegate.paymentDidComplete:` (UIKit/ObjC) | SpreedlyCore | Receive `PaymentResult` with nonce. Send nonce to backend to confirm with `/confirm.json`. |
| 6 | Backend: POST confirm with nonce (+ device_data) | Merchant backend | Complete the transaction |

### SpreedlyBraintreeCheckout State Properties

| Property | Type | Description |
|----------|------|-------------|
| `isAvailable` | `Bool` | Whether Braintree checkout is available |
| `isActive` | `Bool` | Whether a checkout flow is currently active |
| `currentTransactionToken` | `String?` | The transaction token for the active checkout |

---

## Flow

1. **Backend creates purchase:** POST to Spreedly with `payment_method_type: "paypal"` or `"venmo"`, `offsite_sync: true`, and optional `gateway_specific_fields.braintree`. Receive `transaction_token` and `client_token` in the response.

2. **Subscribe to payment result** (before presenting) so you receive the nonce or failure.

3. **Build config and present:** Create `BraintreeCheckoutConfig` and call `SpreedlyBraintreeCheckout.present(config:)`.

4. **Handle return URL:** In your app's URL handler, call `BraintreeURLHandler.handleOpen(url:)` (Swift) or `[BraintreeURLHandlerObjC handleOpenWithUrl:]` (ObjC) first; if it returns `true`, return. Otherwise continue with `handleOffsiteReturn(url:)` or other handlers.

5. **On PaymentResult (success + nonce):** Send nonce to your backend; backend calls Spreedly confirm API.

6. **On PaymentResult (canceled or failure):** Show appropriate message; no backend confirm.

---

## Backend API

Your backend calls Spreedly's purchase API for the Braintree gateway:

```bash
POST https://core.spreedly.com/v1/gateways/{braintree_gateway_token}/purchase.json
Authorization: Basic {base64(environment_key:access_secret)}
Content-Type: application/json

{
  "transaction": {
    "amount": 999,
    "currency_code": "USD",
    "channel": "app",
    "payment_method": {
      "payment_method_type": "paypal",
      "offsite_sync": true,
      "redirect_url": "yourapp://com.yourapp/braintree/checkout",
      "callback_url": "https://yourdomain.com/braintree/callback"
    },
    "gateway_specific_fields": {
      "braintree": {
        "paypal_flow_type": "checkout"
      }
    }
  }
}
```

For Venmo use `"payment_method_type": "venmo"` and e.g. `"venmo_flow_type": "multi_use"` in `gateway_specific_fields.braintree`. The `redirect_url` and `callback_url` are required for the PayPal/Venmo flow to redirect back to your app.

**Response (relevant fields):**

```json
{
  "transaction": {
    "token": "AbCd1234...",
    "state": "processing",
    "gateway_specific_response_fields": {
      "braintree": {
        "client_token": "eyJ2ZXJzaW9uIjoyLCJhdXRo..."
      }
    }
  }
}
```

Extract `transaction.token` and `transaction.gateway_specific_response_fields.braintree.client_token` for use in `BraintreeCheckoutConfig`.

---

## SwiftUI Integration

```swift
import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI
import SpreedlyBraintree

struct BraintreePaymentView: View {
    @State private var paymentResultCancellable: AnyCancellable?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var selectedProduct: Product?
    @State private var selectedPaymentType: String = "paypal"

    var body: some View {
        VStack {
            Button("Pay") { startBraintreeFlow() }
                .disabled(selectedProduct == nil || isLoading)
            if let success = successMessage { Text(success).foregroundColor(.green) }
            if let error = errorMessage { Text(error).foregroundColor(.red) }
        }
        .onAppear {
            paymentResultCancellable?.cancel()
            paymentResultCancellable = Spreedly.shared().subscribeToPaymentResults { result in
                handlePaymentResult(result)
            }
        }
```

> **Alternative: `paymentResultPublisher` (Combine AnyPublisher)**
>
> Instead of the closure-based `subscribeToPaymentResults`, you can use `Spreedly.shared().paymentResultPublisher` (type: `AnyPublisher<PaymentResult, Never>`) with Combine. For flows where you expect a single result (e.g., Braintree checkout), use `.first()`:
>
> ```swift
> paymentResultCancellable = Spreedly.shared().paymentResultPublisher
>     .receive(on: DispatchQueue.main)
>     .first()
>     .sink { result in
>         paymentResultCancellable = nil
>         handlePaymentResult(result)
>     }
> ```
>
> The example app (`BraintreePaymentFlowView.swift`) uses this `paymentResultPublisher` pattern for Braintree.

```swift
        // (continued from above)
        // IMPORTANT: Place .onOpenURL in your root @main App struct, NOT here.
        // It is shown inline for readability only.
        // See getting-started.md for the canonical onOpenURL setup.
        .onOpenURL { url in
            if BraintreeURLHandler.handleOpen(url: url) { return }
            _ = Spreedly.shared().handleOffsiteReturn(url: url)
        }
    }

    func startBraintreeFlow() {
        guard let product = selectedProduct else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            // Replace with your own backend client that calls the Spreedly purchase API
            let paymentType = BraintreePaymentType(string: selectedPaymentType) ?? .paypal
            let response = try await YourBackend.braintreePurchase(
                amount: amountInCents,
                currencyCode: "USD",
                redirectUrl: "yourapp://com.yourapp/braintree/checkout",
                callbackUrl: "https://yourbackend.com/braintree/callback",
                paymentMethodType: paymentType.rawValueString
            )
            guard let tx = response.transaction,
                  ["processing", "pending"].contains(tx.state ?? ""),
                  let clientToken = tx.gatewaySpecificResponseFields?.braintree?.clientToken else {
                await MainActor.run { isLoading = false; errorMessage = "Failed to create purchase" }
                return
            }
            await MainActor.run {
                isLoading = false
                let config = BraintreeCheckoutConfig(
                    transactionToken: tx.token,
                    paymentType: paymentType,
                    merchantDisplayName: "",
                    clientToken: clientToken,
                    amount: String(format: "%.2f", NSDecimalNumber(decimal: product.price).doubleValue),
                    currencyCode: "USD"
                )
                SpreedlyBraintreeCheckout.present(config: config)
            }
        }
    }

    func handlePaymentResult(_ result: PaymentResult) {
        if result.isSuccess, let nonce = result.nonce {
            successMessage = "Payment authorized; confirming..."
            Task {
                do {
                    // Replace with your own backend client that calls the Spreedly confirm API
                    let paymentType = BraintreePaymentType(string: selectedPaymentType) ?? .paypal
                    let confirmResponse = try await YourBackend.braintreeConfirm(
                        transactionToken: result.token ?? "",
                        state: "Successful",
                        nonce: nonce,
                        paymentMethodType: paymentType.rawValueString
                    )
                    await MainActor.run {
                        successMessage = "Payment confirmed!"
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Confirm failed: \(error.localizedDescription)"
                    }
                }
            }
        } else if result.isCanceled {
            errorMessage = "Payment was canceled."
        } else {
            errorMessage = result.failureDetails?.getDescription() ?? "Payment failed."
        }
    }
}
```

---

## UIKit Integration (Swift)

```swift
import UIKit
import SpreedlyCore
import SpreedlyUI
import SpreedlyBraintree

class BraintreePaymentViewController: UIViewController, SpreedlyPaymentDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        Spreedly.shared().paymentDelegate = self
    }

    func startBraintreeFlow() {
        // Replace with your own backend client that calls the Spreedly purchase API
        let paymentType = BraintreePaymentType(string: selectedPaymentType) ?? .paypal
        YourBackend.braintreePurchase(amount: amountInCents, currencyCode: "USD", redirectUrl: "yourapp://braintree/return", callbackUrl: "https://yourbackend.com/callback", paymentMethodType: paymentType.rawValueString) { [weak self] response, error in
            guard let self = self, let tx = response?.transaction,
                  let clientToken = tx.gatewaySpecificResponseFields?.braintree?.clientToken else { return }
            DispatchQueue.main.async {
                let config = BraintreeCheckoutConfig(transactionToken: tx.token, paymentType: paymentType, merchantDisplayName: "", clientToken: clientToken, amount: "...", currencyCode: "USD")
                SpreedlyBraintreeCheckout.present(config: config)
            }
        }
    }

    func paymentDidComplete(_ result: PaymentResult) {
        if result.isSuccess, let nonce = result.nonce {
            // Replace with your own backend client that calls the Spreedly confirm API
            let paymentType = BraintreePaymentType(string: selectedPaymentType) ?? .paypal
            Task {
                let _ = try await YourBackend.braintreeConfirm(
                    transactionToken: result.token ?? "",
                    state: "Successful",
                    nonce: nonce,
                    paymentMethodType: paymentType.rawValueString
                )
                await MainActor.run { self.showSuccess("Payment confirmed!") }
            }
        } else if result.isCanceled {
            showError("Payment was canceled.")
        } else {
            showError(result.failureDetails?.getDescription() ?? "Payment failed.")
        }
    }

    deinit {
        if Spreedly.shared().paymentDelegate === self {
            Spreedly.shared().paymentDelegate = nil
        }
    }
}

// In SceneDelegate, forward URL; try Braintree first.
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    if BraintreeURLHandler.handleOpen(url: url) { return }
    Spreedly.shared().handleOffsiteReturn(url: url)
}
```

---

## Objective-C Integration

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <SpreedlyBraintree/SpreedlyBraintree-Swift.h>
// Import your own backend API client
#import "YourBackendAPIClient.h"

@interface BraintreePaymentViewController () <SpreedlyPaymentDelegate>
@property (nonatomic, copy) NSString *pendingTransactionToken;
@property (nonatomic, copy) NSString *pendingPaymentType;
@end

@implementation BraintreePaymentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Spreedly shared].paymentDelegate = self;
}

- (void)startBraintreeFlow {
    // Replace with your own backend client that calls the Spreedly purchase API
    [YourBackendAPIClient braintreePurchaseWithAmount:amountInCents
                           currencyCode:@"USD"
                            redirectUrl:@"yourapp://com.yourapp/braintree/checkout"
                            callbackUrl:@"https://yourbackend.com/braintree/callback"
                      paymentMethodType:self.selectedPaymentType
                             completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !response.transaction.braintreeClientToken.length) { /* show error */ return; }
        PurchaseTransaction *tx = response.transaction;
        BraintreePaymentType type = [self.selectedPaymentType isEqualToString:@"venmo"] ? BraintreePaymentTypeVenmo : BraintreePaymentTypePaypal;
        BraintreeCheckoutConfig *config = [[BraintreeCheckoutConfig alloc] initWithTransactionToken:tx.token
                                                                                        paymentType:type
                                                                                 merchantDisplayName:@""
                                                                                        clientToken:tx.braintreeClientToken
                                                                                             amount:amountString
                                                                                       currencyCode:@"USD"];
        [SpreedlyBraintreeCheckout presentWithConfig:config];
        self.pendingTransactionToken = tx.token;
        self.pendingPaymentType = self.selectedPaymentType;
    }];
}

- (void)paymentDidComplete:(PaymentResult *)result {
    if (result.isSuccess && result.nonce.length > 0) {
        __weak typeof(self) weakSelf = self;
        // Replace with your own backend client that calls the Spreedly confirm API
        [YourBackendAPIClient braintreeConfirmWithTransactionToken:self.pendingTransactionToken
                                               state:@"Successful"
                                               nonce:result.nonce
                                          deviceData:result.deviceData
                                   paymentMethodType:self.pendingPaymentType
                                          completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    [weakSelf showError:[NSString stringWithFormat:@"Confirm failed: %@", error.localizedDescription]];
                } else {
                    [weakSelf showSuccess:@"Payment confirmed!"];
                }
            });
        }];
    } else if (result.isCanceled) {
        [self showError:@"Payment was canceled."];
    } else {
        [self showError:[result.failureDetails getDescription] ?: @"Payment failed."];
    }
}

- (void)dealloc {
    if ([Spreedly shared].paymentDelegate == self) {
        [Spreedly shared].paymentDelegate = nil;
    }
}

@end

// In SceneDelegate, forward URL; try Braintree first.
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    NSURL *url = URLContexts.allObjects.firstObject.URL;
    if (!url) return;
    if ([BraintreeURLHandlerObjC handleOpenWithUrl:url]) return;
    [[Spreedly shared] handleOffsiteReturnWithUrl:url];
}
```

---

## Important Notes

- **No tokenization step:** Backend creates the Braintree purchase; app only presents checkout and sends the nonce to backend for confirm.
- **No separate configuration step:** Braintree URL handling works out of the box; call `BraintreeURLHandler.handleOpen(url:)` (Swift) or `[BraintreeURLHandlerObjC handleOpenWithUrl:]` (ObjC) in your URL handler. No `configure` call is needed.
- **Subscribe before present:** Set up payment result (Combine or delegate) before calling `SpreedlyBraintreeCheckout.present(config:)`.
- **deviceData:** `PaymentResult` exposes `result.deviceData` for fraud detection. In production, send this to your backend alongside the nonce when confirming. The sample backend does not use it.
- **URL handling:** Call Braintree URL handler first in your URL handler, then `handleOffsiteReturn(url:)` so Braintree returns are not treated as offsite.
- **Weak linking:** Add Braintree packages only to your app target when using Braintree; the SDK compiles without them.

Example references: `BraintreePaymentFlowView` (SwiftUI) and `BraintreePaymentFlowViewController` (Objective-C) in the example app.

---

### Blocked Devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK blocks this flow automatically. The `present()` call returns immediately without showing any UI, and a `PaymentResult.failure` is published. See [Security — Runtime Integrity](security.md#runtime-integrity) for details.

## Troubleshooting

### Payment result not received

- Subscribe to `subscribeToPaymentResults` (or set `paymentDelegate`) **before** calling `SpreedlyBraintreeCheckout.present(config:)`
- Ensure the subscription/delegate remains active until the flow completes

### Braintree returns failure

- Verify `SpreedlyBraintree` is added to your app target (it resolves Braintree dependencies transitively)
- If Braintree is not linked, `SpreedlyBraintreeCheckout.present(config:)` will publish a failure

### App not opening on redirect (PayPal)

- Verify `CFBundleURLTypes` is correctly configured in `Info.plist` with `$(PRODUCT_BUNDLE_IDENTIFIER).spreedly.braintree`
- Ensure `BraintreeURLHandler.handleOpen(url:)` is called first in your URL handler
- Test that `onOpenURL` (SwiftUI) or `scene:openURLContexts:` (UIKit) is invoked when opening the app via the redirect URL
- Add `paypal` to `LSApplicationQueriesSchemes` so the SDK can detect the PayPal app

### App not opening on redirect (Venmo)

- Braintree v7 Venmo uses Universal Links **only** — no custom URL scheme fallback
- Verify `applinks:spreedly.com` is in your Associated Domains entitlement
- Confirm the AASA file is hosted at `https://spreedly.com/.well-known/apple-app-site-association`
- If the AASA file is not hosted, Venmo returns **will not work**. See the [Venmo warning](#universal-links) above.

### CFBundleDisplayName error

- Add `CFBundleDisplayName` to your Info.plist with a non-nil string value (e.g. your app name)

---

## Related Documentation

- [offsite-payments.md](offsite-payments.md) – Safari-based PayPal and Sprel checkout
- [stripe-apm.md](stripe-apm.md) – Stripe alternative payment methods (iDEAL, Bancontact)
- [ebanx-apm.md](ebanx-apm.md) – EBANX payments (Pix, Boleto, OXXO, NuPay)
- [getting-started.md](getting-started.md) – Installation and basic setup
- [BRAINTREE_FLOW.md](../development/BRAINTREE_FLOW.md) – Detailed flow diagrams for Braintree PayPal/Venmo
- [BRAINTREE_UNIVERSAL_LINK_FLOW.md](../development/BRAINTREE_UNIVERSAL_LINK_FLOW.md) – Universal Link vs custom URL scheme flows, AASA status, and 3DS comparison
