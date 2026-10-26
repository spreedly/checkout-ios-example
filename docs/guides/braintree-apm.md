# Braintree APM — Spreedly iOS SDK

> **Venmo: verify before you ship.** Braintree v7 Venmo returns depend on Universal Links with no
> custom-scheme fallback. If the Spreedly AASA file does not yet include Braintree app-link paths,
> **Venmo returns fail silently** — the Venmo app opens but cannot redirect back. Test Venmo end to
> end before production. PayPal is unaffected. See [Universal Links](#universal-links).

Accept PayPal and Venmo through the native Braintree SDK.

|  |  |
|---|---|
| **Use this when** | You want PayPal or Venmo and your Spreedly gateway is Braintree |
| **Use something else when** | European bank redirects → [Stripe APM](stripe-apm.md) · Pix, Boleto, OXXO, NuPay → [EBANX APM](ebanx-apm.md) · Safari-based PayPal → [Offsite payments](offsite-payments.md) |
| **You build** | 3 things: a purchase endpoint · a checkout screen · a confirm call |
| **Modules** | `SpreedlyCore` + `SpreedlySecurity` + `SpreedlyUI` + `SpreedlyBraintree` |
| **Requires** | SDK 1.7.0+ · iOS 16.0+ (iOS 14.0+ on 1.6.x) · Xcode 26.0+ |
| **Integration time** | ~15 minutes |
| **UI** | Partner-hosted PayPal / Venmo flows — SwiftUI · UIKit · Objective-C |

**Fast path:** [How it works](#1-how-it-works) → [What you need](#2-what-you-need) →
[Install](#3-install) → [Configure your app](#4-configure-your-app) →
[Build the flow](#5-build-the-flow) → [your platform](#6-integration-by-platform).

---

## 1. How it works

Three parts. There is **no tokenization step**: instead of a new payment method token, the SDK
hands back a **nonce** that your backend exchanges for a completed transaction. `result.token` is
still populated — it echoes the `transactionToken` you passed in, so you can correlate the result
with the purchase you created in step 1.

| Part | Who builds it | Job |
|---|---|---|
| Purchase endpoint | **Your server** | Creates the purchase on the Braintree gateway, returns a transaction token and client token |
| Checkout screen | **Your app** | Presents PayPal or Venmo, receives a nonce, forwards the return URL |
| Confirm call | **Your server** | Posts the nonce to Spreedly's confirm API to complete the transaction |

A single successful payment:

1. The shopper taps pay in your app.
2. Your server creates the Braintree purchase and returns a transaction token and client token.
3. Your app subscribes to results, then presents PayPal or Venmo.
4. The SDK loads transaction status, then hands off to the Braintree SDK.
5. The shopper authorizes in the PayPal or Venmo app, and iOS returns them to yours.
6. A `PaymentResult` arrives carrying a **nonce** (and `deviceData` when required).
7. Your server posts that nonce to the confirm API. **The money moves there, not on the device.**

<details>
<summary><b>How this differs from the other APM flows</b></summary>

| | Offsite | Stripe APM | **Braintree** |
|---|---|---|---|
| Tokenization step | Yes (`submitOffsitePayment`) | No | **No** |
| Checkout UI | Safari | Stripe PaymentSheet | **Native PayPal / Venmo** |
| Returns | Token | Result state | **Nonce** |
| Backend steps | Purchase with token | Purchase with client secret | **Purchase, then confirm with nonce** |

</details>

**Working on only one part?** Backend → [step 1](#step-1--create-the-purchase--your-server) and
[step 5](#step-5--confirm-with-the-nonce--your-server) · iOS →
[step 2](#step-2--subscribe-to-results--your-app).

---

## 2. What you need

Account and dashboard setup you cannot do from Xcode. Each missing item fails at **runtime**.

| Category | You need | Where to get it |
|---|---|---|
| Spreedly | Braintree gateway configured | Spreedly dashboard → Gateways |
| Gateway / partner | Braintree account with PayPal and/or Venmo enabled | Braintree control panel |
| Your app | Associated Domains entitlement `applinks:spreedly.com` | Your `.entitlements` file — **required for Venmo** |
| Your app | `CFBundleDisplayName` set | Your `Info.plist`. Some flows, Venmo included, trap without it |
| Your backend | Endpoints that create the purchase and call confirm | See [step 1](#step-1--create-the-purchase--your-server) and [step 5](#step-5--confirm-with-the-nonce--your-server) |

**Skip the Venmo rows if** you only accept PayPal — PayPal has a custom-scheme fallback and works
without Universal Links.

### Compatibility

| SDK version | iOS | Xcode | Notes |
|---|---|---|---|
| 1.7.0+ | **16.0+** | 26.0+ | Braintree iOS v7.x resolved transitively |
| 1.6.x | 14.0+ | 26.0+ | Last line that supports iOS 14 and 15 — see [Migrating to iOS 16](migration/v1-to-v2.md) |

Assumed done: [Getting Started](getting-started.md) — installation plus `Spreedly.initializeSDK()`
at launch and `Spreedly.setup(config:)` with a signed bundle from your server.

---

## 3. Install

> **You'll need:** the latest tag from
> [checkout-ios-package](https://github.com/spreedly/checkout-ios-package/releases). Use one
> version for every Spreedly module in your app.

`SpreedlyBraintree` is optional — add it only if you use Braintree. The SDK compiles without it,
and the Braintree APIs simply are not available in your code.

Braintree's own modules (Core, PayPal, Venmo, DataCollector) resolve **transitively**. Do not add
a separate Braintree dependency.

**Swift Package Manager**

```swift
.package(url: "https://github.com/spreedly/checkout-ios-package", from: "1.7.0")  // use the latest release tag
// Link SpreedlyCore, SpreedlySecurity, SpreedlyUI, SpreedlyBraintree to your app target.
```

**CocoaPods**

```ruby
pod 'SpreedlyCore',      '~> 1.7'
pod 'SpreedlySecurity',  '~> 1.7'
pod 'SpreedlyUI',        '~> 1.7'
pod 'SpreedlyBraintree', '~> 1.7'
```

No `post_install` block is needed — unlike [Stripe APM](stripe-apm.md).

---

## 4. Configure your app

> **You'll need:** your bundle identifier, and your app's display name.

| Key | Value | Why | Required |
|---|---|---|---|
| `CFBundleURLTypes` → `CFBundleURLSchemes` | `$(PRODUCT_BUNDLE_IDENTIFIER).spreedly.braintree` | PayPal's fallback return path when Universal Links are unavailable | Yes |
| Associated Domains | `applinks:spreedly.com` | The only return path Venmo has | Yes for Venmo |
| `CFBundleDisplayName` | Your app name | Braintree traps when it is nil | Yes |
| `LSApplicationQueriesSchemes` | `paypal` | Lets the SDK detect the PayPal app for App Switch | Recommended |

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key><string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER).spreedly.braintree</string>
        </array>
    </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
    <!-- Braintree v7: PayPal app detection -->
    <string>paypal</string>
    <!-- Braintree v6 legacy: Venmo app detection (harmless, unused in v7) -->
    <string>com.venmo.touch.v2</string>
</array>
```

Without `paypal` in that list, PayPal always falls back to the browser flow instead of App Switch.

<a id="universal-links"></a>

### Universal Links

The SDK hardcodes `https://spreedly.com/braintree/return` and passes it to `BTPayPalClient` and
`BTVenmoClient`. **You do not configure this URL.** Two things must be true for it to work:

1. **You:** add `applinks:spreedly.com` to Associated Domains in your `.entitlements`.
2. **Spreedly:** host an `apple-app-site-association` file at
   `https://spreedly.com/.well-known/apple-app-site-association` covering the `braintree/return`
   path for your team ID and bundle identifier.

> **Important:** the AASA file exists but may not yet include Braintree app-link paths. Verify it
> before relying on Venmo.

| If the AASA file is not working | Result |
|---|---|
| **PayPal** | Falls back to the custom URL scheme. App Switch still works |
| **Venmo** | **Returns fail silently.** Braintree v7 Venmo is Universal-Links-only — no fallback exists |

<details>
<summary><b>URL reference</b> — every value, and where each one is configured</summary>

| What | Value | Where |
|---|---|---|
| Universal Link | `https://spreedly.com/braintree/return` | SDK-managed — no action |
| Associated Domain | `applinks:spreedly.com` | `.entitlements` |
| Custom scheme fallback | `$(PRODUCT_BUNDLE_IDENTIFIER).spreedly.braintree` | `Info.plist` → `CFBundleURLSchemes` |
| PayPal app detection | `paypal` | `Info.plist` → `LSApplicationQueriesSchemes` |

</details>

---

## 5. Build the flow

Five steps. Each is labelled with who writes it.

### Step 1 — Create the purchase · `Your server`

> **You'll need:** the Braintree gateway token and your Spreedly credentials.

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
      "braintree": { "paypal_flow_type": "checkout" }
    }
  }
}
```

| Parameter | Required | Value and constraints |
|---|---|---|
| `payment_method_type` | Yes | `"paypal"` or `"venmo"` — must match the `paymentType` you pass in step 3 |
| `offsite_sync` | Yes | `true` |
| `redirect_url` / `callback_url` | Yes | Both are required for the return to work |
| `gateway_specific_fields.braintree` | No | Flow type, Venmo profile, line items — see below |

Keep these from the response:

| Response field | Used for |
|---|---|
| `transaction.token` | `BraintreeCheckoutConfig.transactionToken` |
| `transaction.gateway_specific_response_fields.braintree.client_token` | `BraintreeCheckoutConfig.clientToken` |

`transaction.state` comes back as `processing` or `pending`.

<details>
<summary><b>Gateway-specific fields</b> — PayPal flow types, Venmo options</summary>

**PayPal** — `paypal_flow_type`:

| Value | Use case |
|---|---|
| `checkout` | One-time checkout (default) |
| `vault` | Vault PayPal for later use |
| `checkout_with_vault` | Checkout and request a billing agreement |

`line_items`, `shipping_address`, and `billing_agreement_description` apply to the vault and
checkout-with-vault flows.

**Venmo**:

| Field | Typical value |
|---|---|
| `venmo_flow_type` | `multi_use` to vault the account; omit or `single_use` for one-time |
| `venmo_profile_id` | Your Braintree Venmo profile ID, when required |

</details>

### Step 2 — Subscribe to results · `Your app`

```swift
cancellable = Spreedly.shared().subscribeToPaymentResults { result in
    if result.isSuccess, let nonce = result.nonce {
        // Send nonce (and result.deviceData when non-nil) to your backend — step 5
    }
}
```

> **Important:** subscribe **before** presenting. A late subscription misses the nonce, and the
> shopper completes a payment you never confirm.

Objective-C: set `Spreedly.shared().paymentDelegate` instead.

### Step 3 — Build the config and present · `Your app`

```swift
let config = BraintreeCheckoutConfig(
    transactionToken: transaction.token,
    paymentType: .paypal,          // or .venmo — must match the purchase
    merchantDisplayName: "",       // may be empty
    clientToken: clientToken
)
SpreedlyBraintreeCheckout.present(config: config)
```

The SDK finds the topmost view controller. Use `present(config:from:)` to pass a presenter
explicitly if your navigation hierarchy defeats that.

| Field | Required | Notes |
|---|---|---|
| `transactionToken` | Yes | Identifies the purchase and drives the status call |
| `paymentType` | Yes | `.paypal` or `.venmo`, matching `payment_method_type` |
| `merchantDisplayName` | No | Shown in Braintree's UI when set |
| `clientToken` | No | **Fallback only**, used if status omits one. Pass it when you have it |
| `amount` / `currencyCode` | No | **Not used at launch** — both come from transaction status |

> **Gotcha:** every `present(config:)` calls `GET .../transactions/{token}/status.json` first.
> Amount, currency, and flow options shown to the shopper come from **that payload**, not from the
> config. Set them on the purchase.

<details>
<summary><b>Status fields the SDK reads</b> — top-level or inside <code>context</code></summary>

| Field | Purpose |
|---|---|
| `client_token` | Required to launch. From status, `context`, or the config fallback |
| `payment_method_type` | Must match `BraintreeCheckoutConfig.paymentType` |
| `created_at` | A token older than 24 hours blocks launch. Present-but-unparseable also blocks. Missing or blank does not |
| `amount`, `currency_code` | What PayPal or Venmo shows the shopper |
| `paypal_flow_type` | `checkout`, `vault`, or `checkout_with_vault` |
| `line_items`, `shipping_address`, `billing_agreement_description` | Vault and checkout-with-vault flows |
| `venmo_flow_type`, `venmo_profile_id` | Venmo options |

Spreedly may return these base64-encoded inside `context`; the SDK merges both. If the body omits
`transaction.token`, the SDK backfills it from the request URL.

</details>

### Step 4 — Forward the return URL · `Your app`

```swift
.onOpenURL { url in
    if BraintreeURLHandler.handleOpen(url: url) { return }
    _ = Spreedly.shared().handleOffsiteReturn(url: url)
}
```

> **Important:** call `BraintreeURLHandler.handleOpen(url:)` **first**. It returns `true` when the
> URL was Braintree's. Calling `handleOffsiteReturn` first swallows Braintree returns and the flow
> never completes.

This belongs in your root `@main App` struct, or `SceneDelegate.scene(_:openURLContexts:)` — not
inside the payment view. See [Getting Started](getting-started.md).

<a id="device-data"></a>

### Step 5 — Confirm with the nonce · `Your server`

Post the nonce to Spreedly's confirm API. Include `device_data` when the SDK returned it.

| Outcome | What to send |
|---|---|
| Success | `state: "Successful"`, the `nonce`, `device_data` when non-nil, `payment_method_type` |
| Canceled | `state: "Cancelled"`, a `message`, `payment_method_type`, no nonce |
| Failed | `state: "Failed"`, a `message`, `payment_method_type`, no nonce |

**Device data** is collected only when Braintree's fraud tools need it:

| Payment | `result.deviceData` |
|---|---|
| PayPal `checkout` | `nil` — not collected |
| PayPal `vault` or `checkout_with_vault` | Collected when possible |
| Venmo | Collected when possible |

Pass it through whenever it is non-nil. When `nil`, omit `device_data` or send `null` per your API
contract.

### Try it in sandbox

| Value | Use |
|---|---|
| Braintree sandbox gateway in Spreedly | Runs the whole flow without moving money |
| PayPal sandbox buyer account | Needed to complete the PayPal side |
| Venmo | Requires the Venmo app on the device, or Braintree's test mode |

Full matrix: [Testing Guide](testing-guide.md).

---

## 6. Integration by platform

The same steps wired into each UI stack. Read only your own — the other two are collapsed.

### SwiftUI

```swift
import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyBraintree

struct BraintreePaymentView: View {
    @State private var cancellable: AnyCancellable?
    @State private var message: String?
    @State private var isLoading = false
    private let paymentType: BraintreePaymentType = .paypal

    var body: some View {
        VStack(spacing: 16) {
            Button("Pay with PayPal") { Task { await startPayment() } }
                .disabled(isLoading)
            if let message { Text(message) }
        }
        .onAppear {
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                handle(result)
            }
        }
        .onDisappear { cancellable?.cancel() }
        // Place .onOpenURL in your root @main App struct — shown here for readability only.
        .onOpenURL { url in
            if BraintreeURLHandler.handleOpen(url: url) { return }
            _ = Spreedly.shared().handleOffsiteReturn(url: url)
        }
    }

    private func startPayment() async {
        isLoading = true
        // Step 1 runs on your backend.
        guard let response = try? await YourBackend.braintreePurchase(
                amount: 999,
                currencyCode: "USD",
                redirectUrl: "yourapp://com.yourapp/braintree/checkout",
                callbackUrl: "https://yourbackend.com/braintree/callback",
                paymentMethodType: paymentType.rawValueString),
              let tx = response.transaction,
              ["processing", "pending"].contains(tx.state ?? ""),
              let clientToken = tx.gatewaySpecificResponseFields?.braintree?.clientToken else {
            isLoading = false
            message = "Could not create the purchase."
            return
        }

        isLoading = false
        let config = BraintreeCheckoutConfig(
            transactionToken: tx.token,
            paymentType: paymentType,
            merchantDisplayName: "",
            clientToken: clientToken
        )
        SpreedlyBraintreeCheckout.present(config: config)
    }

    private func handle(_ result: PaymentResult) {
        if result.isSuccess, let nonce = result.nonce {
            message = "Authorized, confirming…"
            Task {
                _ = try? await YourBackend.braintreeConfirm(
                    transactionToken: result.token ?? "",
                    state: "Successful",
                    nonce: nonce,
                    deviceData: result.deviceData,
                    paymentMethodType: paymentType.rawValueString
                )
                message = "Payment confirmed."
            }
        } else if result.isCanceled {
            message = "Payment was canceled."
        } else {
            message = result.failureDetails?.getDescription() ?? "Payment failed."
        }
    }
}
```

<details>
<summary><b>Alternative: <code>paymentResultPublisher</code></b> — Combine, single result</summary>

Instead of the closure form, use `Spreedly.shared().paymentResultPublisher`
(`AnyPublisher<PaymentResult, Never>`). For a flow that produces one result, apply `.first()`:

```swift
cancellable = Spreedly.shared().paymentResultPublisher
    .receive(on: DispatchQueue.main)
    .first()
    .sink { result in
        cancellable = nil
        handle(result)
    }
```

The example app's Braintree screen uses this pattern.

</details>

### UIKit

<details>
<summary><b>Full UIKit implementation</b> — <code>BraintreePaymentViewController</code>, <code>SpreedlyPaymentDelegate</code>, <code>SceneDelegate</code></summary>

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
        let paymentType = BraintreePaymentType(string: selectedPaymentType) ?? .paypal
        YourBackend.braintreePurchase(
            amount: amountInCents,
            currencyCode: "USD",
            redirectUrl: "yourapp://braintree/return",
            callbackUrl: "https://yourbackend.com/callback",
            paymentMethodType: paymentType.rawValueString
        ) { [weak self] response, error in
            guard let self = self, let tx = response?.transaction,
                  let clientToken = tx.gatewaySpecificResponseFields?.braintree?.clientToken else { return }
            DispatchQueue.main.async {
                let config = BraintreeCheckoutConfig(
                    transactionToken: tx.token,
                    paymentType: paymentType,
                    merchantDisplayName: "",
                    clientToken: clientToken
                )
                SpreedlyBraintreeCheckout.present(config: config)
            }
        }
    }

    func paymentDidComplete(_ result: PaymentResult) {
        if result.isSuccess, let nonce = result.nonce {
            let paymentType = BraintreePaymentType(string: selectedPaymentType) ?? .paypal
            Task {
                _ = try await YourBackend.braintreeConfirm(
                    transactionToken: result.token ?? "",
                    state: "Successful",
                    nonce: nonce,
                    deviceData: result.deviceData,
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

// In SceneDelegate — Braintree first.
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    if BraintreeURLHandler.handleOpen(url: url) { return }
    Spreedly.shared().handleOffsiteReturn(url: url)
}
```

</details>

### Objective-C

<details>
<summary><b>Full Objective-C implementation</b> — <code>BraintreePaymentViewController</code>, <code>SpreedlyPaymentDelegate</code>, <code>SceneDelegate</code></summary>

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <SpreedlyBraintree/SpreedlyBraintree-Swift.h>
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
    [YourBackendAPIClient braintreePurchaseWithAmount:amountInCents
                           currencyCode:@"USD"
                            redirectUrl:@"yourapp://com.yourapp/braintree/checkout"
                            callbackUrl:@"https://yourbackend.com/braintree/callback"
                      paymentMethodType:self.selectedPaymentType
                             completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !response.transaction.braintreeClientToken.length) { /* show error */ return; }
        PurchaseTransaction *tx = response.transaction;
        BraintreePaymentType type = [self.selectedPaymentType isEqualToString:@"venmo"]
            ? BraintreePaymentTypeVenmo : BraintreePaymentTypePaypal;
        BraintreeCheckoutConfig *config = [[BraintreeCheckoutConfig alloc]
            initWithTransactionToken:tx.token
                         paymentType:type
                 merchantDisplayName:@""
                         clientToken:tx.braintreeClientToken
                              amount:nil
                        currencyCode:nil];
        [SpreedlyBraintreeCheckout presentWithConfig:config];
        self.pendingTransactionToken = tx.token;
        self.pendingPaymentType = self.selectedPaymentType;
    }];
}

- (void)paymentDidComplete:(PaymentResult *)result {
    if (result.isSuccess && result.nonce.length > 0) {
        __weak typeof(self) weakSelf = self;
        [YourBackendAPIClient braintreeConfirmWithTransactionToken:self.pendingTransactionToken
                                               state:@"Successful"
                                               nonce:result.nonce
                                          deviceData:result.deviceData
                                             message:nil
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

// In SceneDelegate — Braintree first.
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    NSURL *url = URLContexts.allObjects.firstObject.URL;
    if (!url) return;
    if ([BraintreeURLHandlerObjC handleOpenWithUrl:url]) return;
    [[Spreedly shared] handleOffsiteReturnWithUrl:url];
}
```

</details>

> **iOS only:** the Objective-C surface has no Android or React Native equivalent. React Native
> consumers use the `checkout-react-native` bridge.

---

## 7. Handle the result

| Result | Meaning | What to do |
|---|---|---|
| `isSuccess` with `nonce` | Shopper authorized | Send `nonce` plus `deviceData` to your backend; confirm there |
| `token` | Echo of the `transactionToken` you passed in `BraintreeCheckoutConfig` — **not** a new payment method token | Use it to match the result to the purchase you created in [step 1](#step-1--create-the-purchase--your-server) |
| `state` | `"pending"` on success | Informational. The transaction is not complete until your server confirms |
| `isCanceled` | Shopper backed out of PayPal or Venmo | Tell your backend with `state: "Cancelled"`. Show "Payment was canceled." |
| `isFailure` | Braintree or network failure | Tell your backend with `state: "Failed"`. Show `failureDetails.getDescription()` |

> **Important:** a nonce is **not** a payment. Nothing is charged until your server calls confirm.
> Never fulfil an order on `isSuccess` alone.

Cancellation publishes `PaymentResult.canceled()`, not a failure. When the Braintree SDK returns
an empty error description, the SDK substitutes `"Braintree payment failed"`.

---

## 8. Errors and troubleshooting

<details>
<summary><b>Failures before PayPal or Venmo opens</b> — messages from the launch status call</summary>

| Message | What to check |
|---|---|
| `Failed to fetch Braintree client token` | Status API failed, or the response could not be read. Verify the transaction token and environment |
| `No transaction data in status response` | Status returned without a `transaction` object |
| `Braintree client_token not available in transaction status` | Purchase is not on the Braintree gateway, or status and `context` both omit `client_token` |
| `Braintree client_token has expired` | `created_at` is older than 24 hours |
| `Missing payment_method_type in transaction` | Status omits it, top-level and in `context` |
| `Payment type mismatch: expected …, got …` | Config `.paypal` / `.venmo` does not match the transaction |

</details>

**Problems you hit while integrating**

| Symptom | Cause | Fix |
|---|---|---|
| The result never arrives | Subscribed after presenting | Subscribe first — [step 2](#step-2--subscribe-to-results--your-app) |
| Braintree returns failure immediately | `SpreedlyBraintree` not linked | Add it to your app target; it resolves Braintree transitively |
| App does not reopen after PayPal | Scheme or handler order | Register `$(PRODUCT_BUNDLE_IDENTIFIER).spreedly.braintree`, and call `BraintreeURLHandler.handleOpen(url:)` **first** |
| PayPal never App Switches | `paypal` missing from `LSApplicationQueriesSchemes` | Add it, or accept the browser flow |
| **App does not reopen after Venmo** | Universal Links not working | Venmo has **no** scheme fallback. Verify `applinks:spreedly.com` and the AASA file — see [Universal Links](#universal-links) |
| `CFBundleDisplayName must be non-nil` | Missing display name | Set it in `Info.plist` |
| Amount shown is wrong | Set on the config instead of the purchase | `amount` and `currencyCode` on the config are ignored at launch |

Broader error model: [Error Handling](error-handling.md).

---

## 9. Edge cases and cleanup

### Blocked devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK
> blocks this flow automatically. The `present()` call returns immediately without showing any UI,
> and a `PaymentResult.failure` is published. See
> [Security — Runtime Integrity](security.md#runtime-integrity) for details.

### Screen prevention

PayPal and Venmo are partner UI. Spreedly's `.screenPrevention()` does **not** cover them — do not
wrap those surfaces. See [Security](security.md).

### Client token lifetime

A client token older than 24 hours blocks launch. Create the purchase close to checkout rather
than reusing a token from an earlier session.

### Cleanup

Hold the `AnyCancellable` for the lifetime of the screen. In UIKit and Objective-C, clear
`paymentDelegate` in `deinit`/`dealloc` when it still points at you — both examples above do.

---

## 10. API at a glance

| API | Module | Purpose |
|---|---|---|
| `BraintreeCheckoutConfig(transactionToken:paymentType:merchantDisplayName:clientToken:)` | `SpreedlyCore` | Checkout configuration |
| `SpreedlyBraintreeCheckout.present(config:)` | `SpreedlyBraintree` | Present on the topmost view controller |
| `SpreedlyBraintreeCheckout.present(config:from:)` | `SpreedlyBraintree` | Present from a specific view controller |
| `SpreedlyBraintreeCheckout.isAvailable` / `.isActive` / `.currentTransactionToken` | `SpreedlyBraintree` | Checkout state |
| `BraintreeURLHandler.handleOpen(url:)` | `SpreedlyBraintree` | Forward the return URL. Returns `true` when handled |
| `BraintreeURLHandlerObjC.handleOpenWithUrl:` | `SpreedlyBraintree` | Objective-C form |
| `Spreedly.shared().subscribeToPaymentResults { }` | `SpreedlyCore` | Receive the nonce |
| `Spreedly.shared().paymentResultPublisher` | `SpreedlyCore` | Combine alternative |
| `Spreedly.shared().handleOffsiteReturn(url:)` | `SpreedlyCore` | Forward non-Braintree return URLs |

Objective-C selectors: [Objective-C](objective-c.md).

---

## 11. Related documentation

- [Stripe APM](stripe-apm.md) — European bank redirects, the other native-sheet APM
- [EBANX APM](ebanx-apm.md) — Pix, Boleto, OXXO, NuPay
- [Offsite payments](offsite-payments.md) — the Safari-based PayPal alternative
- [Testing Guide](testing-guide.md) — sandbox gateways and the go-live checklist
- [Getting Started](getting-started.md) — installation, SDK lifecycle, and the canonical URL setup
- [Security](security.md) — runtime integrity and screen prevention

