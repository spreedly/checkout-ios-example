# Stripe APM — Spreedly iOS SDK

> **Action required if you also link Stripe directly:** pin Stripe to `25.x`. Stripe `26.x` will
> fail SPM resolution while Spreedly resolves `25.x`. See [Install](#3-install).

Accept European bank-redirect payment methods — iDEAL, Bancontact, EPS, P24, SEPA Debit — through
Stripe's native PaymentSheet.

|  |  |
|---|---|
| **Use this when** | You want European APMs and your Spreedly gateway is Stripe Payment Intents |
| **Use something else when** | PayPal or Venmo → [Braintree APM](braintree-apm.md) · other redirect APMs → [Offsite payments](offsite-payments.md) |
| **You build** | 3 things: a purchase endpoint · a checkout screen · a webhook handler |
| **Modules** | `SpreedlyCore` + `SpreedlySecurity` + `SpreedlyUI` + `SpreedlyStripeAPM` |
| **Requires** | SDK 1.7.0+ · iOS 16.0+ (iOS 14.0+ on 1.6.x) · Xcode 26.0+ |
| **Integration time** | ~15 minutes |
| **UI** | Partner-hosted Stripe PaymentSheet — SwiftUI · UIKit · Objective-C |

**Fast path:** [How it works](#1-how-it-works) → [What you need](#2-what-you-need) →
[Install](#3-install) → [Configure your app](#4-configure-your-app) →
[Build the flow](#5-build-the-flow) → [your platform](#6-integration-by-platform).

---

## 1. How it works

Three parts. Unlike offsite payments, there is **no tokenization step** — your server creates a
pending purchase directly, and the PaymentSheet handles selection and confirmation.

| Part | Who builds it | Job |
|---|---|---|
| Purchase endpoint | **Your server** | Creates the pending purchase, returns a client secret and transaction token |
| Checkout screen | **Your app** | Presents the PaymentSheet and handles the return URL |
| Webhook handler | **Your server** | Receives the final outcome. Fulfil orders here, not on the SDK result |

A single successful payment:

1. The shopper taps pay in your app.
2. Your app asks your server for a pending purchase.
3. Your server calls Spreedly and returns the client secret and transaction token.
4. Your app presents the PaymentSheet; the shopper picks a method and authenticates at their bank.
5. The bank redirects back into your app; the SDK publishes a `PaymentResult`.
6. Stripe notifies Spreedly, Spreedly notifies your `callback_url`, and you fulfil the order.

<details>
<summary><b>How this differs from Offsite and Braintree</b></summary>

| Feature | Offsite | Stripe APM | Braintree |
|---------|---------|------------|-----------|
| Tokenization step | Yes (`submitOffsitePayment`) | No | No |
| Backend creates | Purchase (after token) | Pending purchase | Purchase |
| Checkout UI | Safari | Native PaymentSheet | Native PayPal/Venmo |
| Return flow | Deep link redirect | Deep link redirect | URL scheme / Universal Link |
| Module | SpreedlyUI | SpreedlyStripeAPM | SpreedlyBraintree |

</details>

**Working on only one part?** Backend → [step 1](#step-1--create-a-pending-purchase--your-server) ·
iOS → [step 2](#step-2--build-the-config--your-app) · Webhooks →
[What you need](#2-what-you-need), row 4.

---

## 2. What you need

Account and dashboard setup you cannot do from Xcode. Each missing item fails at **runtime**, not
at compile time.

| Category | You need | Where to get it |
|---|---|---|
| Spreedly | Stripe Payment Intents gateway | Spreedly dashboard → Gateways |
| Gateway / partner | APMs enabled on your Stripe account | Stripe dashboard → Settings → Payment methods |
| Credentials | Stripe publishable key (`pk_test_…` / `pk_live_…`) | Stripe dashboard → Developers → API keys |
| Webhooks | Stripe webhook sending all Payment Intent events to Spreedly | Stripe dashboard → Developers → Webhooks. Required — SEPA and other delayed methods settle asynchronously and never report final status without it |
| Your backend | An endpoint that creates the pending purchase | See [step 1](#step-1--create-a-pending-purchase--your-server) |

### Compatibility

| SDK version | iOS | Xcode | Notes |
|---|---|---|---|
| 1.7.0+ | **16.0+** | 26.0+ | Stripe embedded in `SpreedlyStripeAPM` |
| 1.6.x | 14.0+ | 26.0+ | Last line that supports iOS 14 and 15 — see [Migrating to iOS 16](migration/v1-to-v2.md) |

Assumed done: [Getting Started](getting-started.md) — installation plus `Spreedly.initializeSDK()`
at launch and `Spreedly.setup(config:)` with a signed bundle from your server.

---

## 3. Install

> **You'll need:** the latest tag from
> [checkout-ios-package](https://github.com/spreedly/checkout-ios-package/releases). Use one
> version for every Spreedly module in your app.

Stripe's code and resource bundles ship **inside** `SpreedlyStripeAPM`. Do not add a separate
Stripe dependency for APM-only integrations.

**Swift Package Manager**

```swift
.package(url: "https://github.com/spreedly/checkout-ios-package", from: "1.7.0")  // use the latest release tag
// Link SpreedlyCore, SpreedlySecurity, SpreedlyUI, SpreedlyStripeAPM to your app target.
```

**CocoaPods**

```ruby
pod 'SpreedlyCore',      '~> 1.7'
pod 'SpreedlySecurity',  '~> 1.7'
pod 'SpreedlyUI',        '~> 1.7'
pod 'SpreedlyStripeAPM', '~> 1.7'
```

<a id="cocoapods-stripe-bundle-patcher"></a>
<details>
<summary>CocoaPods only — required Stripe bundle patcher</summary>

Without this block the app crashes at launch with
`Fatal error: unable to find bundle named Stripe_StripePaymentSheet`. SPM users do not need it.

```ruby
post_install do |installer|
  stripe_apm_pod = installer.sandbox.pod_dir('SpreedlyStripeAPM')
  require File.join(stripe_apm_pod, 'scripts', 'cocoapods_stripe_bundle_patcher')
  SpreedlyStripeAPM::CocoaPods.apply_stripe_bundle_patch(installer)
end
```

Run `pod install` afterwards.

**Why this is needed:** the `SpreedlyStripeAPM` XCFramework is built against Stripe via SPM, which
produces resource bundles named `Stripe_StripePaymentSheet`. CocoaPods names them differently
(`StripePaymentSheet_StripePaymentSheet`). The patcher renames or copies bundles so the embedded
XCFramework finds them at runtime.

Local development fallback (`:path => '../checkout-ios-package'`) is also supported:

```ruby
post_install do |installer|
  require_relative '../checkout-ios-package/scripts/cocoapods_stripe_bundle_patcher'
  SpreedlyStripeAPM::CocoaPods.apply_stripe_bundle_patch(installer)
end
```

The `cocoapods_stripe_bundle_patcher.rb` script ships inside the pod via `preserve_paths`, so
`installer.sandbox.pod_dir('SpreedlyStripeAPM')` locates it automatically — no manual file copy or
path setup. This works for both remote (`:git =>`) and local (`:path =>`) installs. The script
patches the Pods embed script and adds a "Copy Stripe bundle for SPM" Run Script phase to your app
target.

**React Native:** the `checkout-react-native` Podfile's `apply_spreedly_stripe_support` uses the
same sandbox-based lookup.

</details>

<details>
<summary>If your app also links Stripe directly</summary>

Only relevant if you use [Stripe Radar](stripe-radar.md) or call Stripe APIs outside Spreedly, via
[stripe-ios-spm](https://github.com/stripe/stripe-ios-spm).

| Rule | Value |
|------|--------|
| **SPM (recommended)** | `from: "25.11.0"` (Up to Next Major → **25.x** only) |
| **Do not use** | Stripe **26.x** while Spreedly still resolves **25.x** — SPM will fail to resolve |

Details and troubleshooting: [Stripe Radar — Stripe version](stripe-radar.md#stripe-version-required).

</details>

---

## 4. Configure your app

> **You'll need:** a custom URL scheme you own, and your app's display name.

| Key | Value | Why | Required |
|---|---|---|---|
| `CFBundleURLTypes` | your scheme, e.g. `myapp` | Bank redirects return the shopper to your app | Yes |
| `CFBundleDisplayName` | your app name | Stripe traps at launch when it is nil | Yes |
| `NSCameraUsageDescription` | any user-facing string | Stripe's PaymentSheet references camera APIs; App Store rejects with `ITMS-90683` without it, even though card scanning is never shown | Yes |

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key><string>Editor</string>
    <key>CFBundleURLName</key><string>com.yourcompany.yourapp.stripe</string>
    <key>CFBundleURLSchemes</key><array><string>myapp</string></array>
  </dict>
</array>
```

> **Important:** `StripeAPMConfig.returnURL` must use the scheme you register here. The SDK appends
> `transaction_token=…` to it for you — register the base scheme only.

---

## 5. Build the flow

Five steps. Each is labelled with who writes it.

<a id="backend-api"></a>
### Step 1 — Create a pending purchase · `Your server`

> **You'll need:** the gateway and enabled APMs from [What you need](#2-what-you-need).

Your server calls the Spreedly purchase API. The shopper's app never holds your API secret.

| Parameter | Required | Value and constraints |
|---|---|---|
| `payment_method_type` | Yes | `"stripe_apm"` |
| `apm_types` | Yes | One or more of `ideal`, `bancontact`, `eps`, `p24`, `sepa_debit`. The sheet shows only what you pass, filtered by purchase currency |
| `redirect_url` | Yes | A Spreedly-hosted URL or your own scheme. Must not contain personally identifiable information |
| `callback_url` | Yes | Where Spreedly posts the final outcome. This is what you fulfil on |

Keep these from the response:

| Response field | Used for |
|---|---|
| `transaction.token` | `StripeAPMConfig.transactionToken` |
| `transaction.gateway_specific_response_fields.stripe_payment_intents.client_secret` | `StripeAPMConfig.clientSecret` |

`transaction.state` comes back as `"pending"`. Anything else means gateway, APM, or webhook setup
is incomplete — go back to [What you need](#2-what-you-need).

Currency and country coverage: `ideal` NL/EUR · `bancontact` BE/EUR · `eps` AT/EUR ·
`p24` PL/PLN or EUR · `sepa_debit` Eurozone/EUR.

**Optional — Stripe Radar:** when your app collects a Radar session ID first
([Stripe Radar](stripe-radar.md)), include it on the same purchase under
`gateway_specific_fields.stripe_payment_intents.radar_session_id`. Omit the block when you have no
session ID.

**Typed constants (optional):** in Swift use `StripeAPMType` (e.g. `StripeAPMType.ideal.apmTypeValue`).
In Objective-C use `StripeAPMTypeHelper.apmTypeValueForType:` (e.g.
`[StripeAPMTypeHelper apmTypeValueForType:StripeAPMTypeEps]`). String literals work too.

<details>
<summary><b>Full purchase request and response</b></summary>

```bash
POST https://core.spreedly.com/v1/gateways/{stripe_pi_gateway_token}/purchase.json
Authorization: Basic {base64(environment_key:access_secret)}
Content-Type: application/json

{
  "transaction": {
    "amount": 1000,
    "currency_code": "EUR",
    "channel": "app",
    "redirect_url": "myapp://stripe-redirect",
    "callback_url": "https://your-backend.com/spreedly/callbacks",
    "payment_method": {
      "payment_method_type": "stripe_apm",
      "apm_types": ["ideal", "bancontact", "eps", "p24", "sepa_debit"]
    }
  }
}
```

**Response (relevant fields):**

```json
{
  "transaction": {
    "token": "AbCd1234...",
    "state": "pending",
    "gateway_specific_response_fields": {
      "stripe_payment_intents": {
        "client_secret": "pi_3abc123_secret_xyz789..."
      }
    }
  }
}
```

</details>

### Step 2 — Build the config · `Your app`

> **You'll need:** your publishable key.

```swift
let config = StripeAPMConfig(
    publishableKey: publishableKey,
    clientSecret: clientSecret,
    transactionToken: transaction.token,
    merchantDisplayName: "Your Store",
    returnURL: "myapp://stripe-redirect"
)
```

### Step 3 — Subscribe to the result · `Your app`

```swift
cancellable = Spreedly.shared().subscribeToPaymentResults { result in
    // See section 7
}
```

Subscribe **before** presenting, so a fast completion cannot arrive before you are listening.

### Step 4 — Present the PaymentSheet · `Your app`

```swift
SpreedlyStripeAPMCheckout.present(config: config)
```

The SDK finds the topmost view controller. If your navigation hierarchy defeats that, use
`present(config:from:)` and pass the presenter yourself.

### Step 5 — Forward the return URL · `Your app`

```swift
.onOpenURL { url in
    Spreedly.shared().handleOffsiteReturn(url: url)
}
```

Stripe-specific routing happens inside the SDK — no Stripe code belongs in your URL handler. In
UIKit and Objective-C, do the same from `SceneDelegate.scene(_:openURLContexts:)`.

> **Why:** when you present the sheet, the SDK registers a URL pre-handler
> (`Spreedly.shared().setURLPreHandler`) that forwards Stripe redirects to
> `SpreedlyStripeAPMCheckout.handleStripeReturnURL(_:)`. Your app still forwards everything to
> `handleOffsiteReturn(url:)`, which invokes that pre-handler chain.

### Step 6 — Theme the sheet (optional) · `Your app`

Stripe's PaymentSheet has its own UI. To match your branding, build a `StripeAPMAppearanceConfig`
and pass it to one of the appearance-aware `present` overloads.

The config mirrors the publicly stable subset of Stripe's `PaymentSheet.Appearance`: corner radius,
border widths, colors, primary-button styling, shadow, and font. Anything you do not set keeps
Stripe's default — passing `nil`, or using the overloads without `appearance:`, gives you the
unmodified Stripe look.

```swift
let appearance = StripeAPMAppearanceConfig()

// Top-level
appearance.cornerRadius = 8                 // NSNumber-bridged for ObjC; assign Swift literal
appearance.borderWidth = 1.5

// Colors
appearance.colors.primary = .systemPurple
appearance.colors.background = .systemBackground
appearance.colors.danger = .systemRed

// Primary button
appearance.primaryButton.backgroundColor = .systemPurple
appearance.primaryButton.textColor = .white
appearance.primaryButton.cornerRadius = 8
appearance.primaryButton.height = 52

// Shadow
appearance.shadow.color = .black
appearance.shadow.opacity = 0.1

// Font (family only — size and weight are ignored; use sizeScaleFactor to scale)
appearance.font.base = UIFont(name: "AvenirNext-Regular", size: 17) ?? .systemFont(ofSize: 17)
appearance.font.sizeScaleFactor = 1.1

SpreedlyStripeAPMCheckout.present(config: config, appearance: appearance)
```

<details>
<summary><b>Objective-C</b> and <b>appearance notes</b></summary>

```objc
StripeAPMAppearanceConfig *appearance = [[StripeAPMAppearanceConfig alloc] init];
appearance.cornerRadius = @(8);
appearance.colors.primary = UIColor.systemPurpleColor;
appearance.primaryButton.backgroundColor = UIColor.systemPurpleColor;
appearance.primaryButton.height = 52;

[SpreedlyStripeAPMCheckout presentWithConfig:config appearance:appearance];
```

- `NSNumber?`-typed properties (`cornerRadius`, `selectedBorderWidth`, `primaryButton.cornerRadius`)
  accept Swift number literals via implicit `NSNumber` bridging, and `NSNumber *` from Objective-C.
  Set them to `nil` to inherit Stripe's adaptive default.
- `font.base`'s **family** is used; Stripe ignores its size and weight. Use `font.sizeScaleFactor`
  to scale all sizes.
- The disabled-shadow helper is `StripeAPMAppearanceShadow.disabled()`, mirroring Stripe's
  `Shadow.disabled`.
- Experimental and iOS-26-only Stripe appearance fields (`iconStyle`, `sheetCornerRadius`,
  `navigationBarStyle.glass`) are intentionally **not** exposed — they are `@_spi` or version-gated
  in Stripe's SDK and the surface may change.

</details>

### Try it in sandbox

Run the flow end to end before your production account is provisioned:

| Value | Use |
|---|---|
| `pk_test_…` publishable key | Test mode. The sheet renders and redirects exactly as in production |
| Stripe's test redirect page | Replaces the real bank. Gives you an authorize and a fail button, so you can exercise both result paths without a bank login |

Test mode moves no money and settles no SEPA mandates. Full matrix:
[Testing Guide](testing-guide.md).

---

## 6. Integration by platform

The same steps wired into each UI stack. Read only your own — the other two are collapsed.

### SwiftUI

```swift
import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyStripeAPM

struct StripeAPMPaymentView: View {
    @State private var cancellable: AnyCancellable?
    @State private var message: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Button("Pay with iDEAL") { Task { await startPayment() } }
                .disabled(isLoading)
            if let message { Text(message) }
        }
        .onAppear {
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                isLoading = false
                if result.isSuccess {
                    message = result.state == "succeeded"
                        ? "Payment completed."
                        : "Payment submitted, confirmation pending."
                } else if result.isCanceled {
                    message = "Payment was canceled."
                } else {
                    message = result.failureDetails?.getDescription() ?? "Payment failed."
                }
            }
        }
        .onDisappear { cancellable?.cancel() }
        .onOpenURL { Spreedly.shared().handleOffsiteReturn(url: $0) }
    }

    private func startPayment() async {
        isLoading = true
        // Step 1: your backend creates the pending purchase.
        let purchase = try? await YourAPIClient.shared.stripeAPMPendingPurchase(
            amountCents: 1099,
            currencyCode: "EUR",
            redirectUrl: "myapp://stripe-redirect",
            callbackUrl: "https://your-backend.example.com/callback",
            apmTypes: ["ideal"]
        )

        guard let transaction = purchase?.transaction,
              transaction.state == "pending",
              let clientSecret = transaction
                .gatewaySpecificResponseFields?.stripePaymentIntents?.clientSecret else {
            isLoading = false
            message = "Could not create the pending purchase."
            return
        }

        let config = StripeAPMConfig(
            publishableKey: publishableKey,
            clientSecret: clientSecret,
            transactionToken: transaction.token,
            merchantDisplayName: "Your Store",
            returnURL: "myapp://stripe-redirect"
        )
        SpreedlyStripeAPMCheckout.present(config: config)
    }
}
```

### UIKit

<details>
<summary><b>Full UIKit implementation</b> — <code>StripeAPMPaymentViewController</code>, <code>SpreedlyPaymentDelegate</code>, <code>SceneDelegate</code></summary>

```swift
import UIKit
import SpreedlyCore
import SpreedlyUI
import SpreedlyStripeAPM

class StripeAPMPaymentViewController: UIViewController, SpreedlyPaymentDelegate {

    enum StripeAPMStage { case idle, creatingPendingPurchase, checkout }
    var stage: StripeAPMStage = .idle
    var selectedProduct: Product?
    var selectedAPMTypes: Set<String> = ["ideal"]

    override func viewDidLoad() {
        super.viewDidLoad()
        Spreedly.shared().paymentDelegate = self
    }

    func startStripeAPMFlow() {
        guard let product = selectedProduct else { return }
        stage = .creatingPendingPurchase

        let client = YourAPIClient.shared
        client.stripeAPMPendingPurchase(
            amount: product.price * 100,
            currencyCode: "EUR",
            redirectUrl: "myapp://stripe-redirect",
            callbackUrl: "https://your-backend.com/callback",
            apmTypes: Array(selectedAPMTypes)
        ) { [weak self] response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.stage = .idle
                    self.showError(error.localizedDescription)
                    return
                }
                guard let transaction = response?.transaction,
                      transaction.state == "pending",
                      let clientSecret = transaction.gatewaySpecificResponseFields?.stripePaymentIntents?.clientSecret else {
                    self.stage = .idle
                    self.showError("Failed to create pending purchase")
                    return
                }

                self.stage = .checkout

                let config = StripeAPMConfig(
                    publishableKey: "pk_test_...",
                    clientSecret: clientSecret,
                    transactionToken: transaction.token,
                    merchantDisplayName: "Your Store",
                    returnURL: "myapp://stripe-redirect"
                )
                SpreedlyStripeAPMCheckout.present(config: config)
            }
        }
    }

    func paymentDidComplete(_ result: PaymentResult) {
        guard stage == .checkout else { return }
        DispatchQueue.main.async {
            self.stage = .idle
            if result.isSuccess {
                self.showSuccess(result.state == "succeeded" ? "Payment completed!" : "Payment submitted.")
            } else if result.isCanceled {
                self.showError("Payment was canceled.")
            } else {
                self.showError(result.failureDetails?.getDescription() ?? "Payment failed")
            }
        }
    }
}

// In SceneDelegate (or AppDelegate):
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    Spreedly.shared().handleOffsiteReturn(url: url)
}
```

</details>

### Objective-C

<details>
<summary><b>Full Objective-C implementation</b> — <code>StripeAPMPaymentViewController</code>, <code>SpreedlyPaymentDelegate</code>, <code>SceneDelegate</code></summary>

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <SpreedlyStripeAPM/SpreedlyStripeAPM-Swift.h>

typedef NS_ENUM(NSInteger, StripeAPMStage) {
    StripeAPMStageIdle,
    StripeAPMStageCreatingPendingPurchase,
    StripeAPMStageCheckout
};

@interface StripeAPMPaymentViewController () <SpreedlyPaymentDelegate>
@property (nonatomic, assign) StripeAPMStage stage;
@property (nonatomic, strong) Product *selectedProduct;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedAPMTypes;
@end

@implementation StripeAPMPaymentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Spreedly shared].paymentDelegate = self;
    self.selectedAPMTypes = [NSMutableSet setWithObject:@"ideal"];
}

- (void)startStripeAPMFlow {
    if (!self.selectedProduct || self.selectedAPMTypes.count == 0) return;

    self.stage = StripeAPMStageCreatingPendingPurchase;

    NSDecimalNumber *amountInCents = [self.selectedProduct.price decimalNumberByMultiplyingBy:@100];
    YourAPIClient *client = [YourAPIClient shared];
    [client stripeAPMPendingPurchaseWithAmount:amountInCents
                                 currencyCode:@"EUR"
                                  redirectUrl:@"myapp://stripe-redirect"
                                 callbackUrl:@"https://your-backend.com/callback"
                                    apmTypes:[self.selectedAPMTypes allObjects]
                                  completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.stage = StripeAPMStageIdle;
                [self showError:error.localizedDescription];
            });
            return;
        }
        PurchaseTransaction *tx = response.transaction;
        if (!tx || ![tx.state isEqualToString:@"pending"] || !tx.stripePaymentIntentClientSecret.length) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.stage = StripeAPMStageIdle;
                [self showError:@"Failed to create pending purchase"];
            });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.stage = StripeAPMStageCheckout;

            StripeAPMConfig *config = [[StripeAPMConfig alloc] initWithPublishableKey:@"pk_test_..."
                                                                        clientSecret:tx.stripePaymentIntentClientSecret
                                                                   transactionToken:tx.token
                                                                  merchantDisplayName:@"Your Store"
                                                                              returnURL:@"myapp://stripe-redirect"];
            [SpreedlyStripeAPMCheckout presentWithConfig:config];
        });
    }];
}

- (void)paymentDidComplete:(PaymentResult *)result {
    if (self.stage != StripeAPMStageCheckout) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.stage = StripeAPMStageIdle;
        if (result.isSuccess) {
            [self showSuccess:[result.state isEqualToString:@"succeeded"] ? @"Payment completed!" : @"Payment submitted."];
        } else if (result.isCanceled) {
            [self showError:@"Payment was canceled."];
        } else {
            [self showError:[result.failureDetails getDescription] ?: @"Payment failed"];
        }
    });
}

@end

// In SceneDelegate (or AppDelegate):
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    NSURL *url = URLContexts.allObjects.firstObject.URL;
    if (url) { [[Spreedly shared] handleOffsiteReturnWithUrl:url]; }
}
```

</details>

> **iOS only:** the Objective-C surface has no Android or React Native equivalent. React Native
> consumers use the `checkout-react-native` bridge instead.

---

## 7. Handle the result

| Result | Meaning | What to show the shopper |
|---|---|---|
| `isSuccess`, state `succeeded` | Funds received | Success |
| `isSuccess`, state `processing` | Accepted, funds pending — typical for SEPA | "Payment accepted, confirmation pending" |
| `isSuccess`, state `pending` | Submitted, awaiting final status | "Payment submitted" |
| `isCanceled` | Shopper dismissed the sheet | "Payment was canceled." |
| `isFailure` | Network, Stripe, or backend failure | Error plus a retry action |

> **Important:** `processing` and `pending` are not failures, and `succeeded` on the device is not
> a guarantee of settlement. **Fulfil orders on your `callback_url` webhook, not on the SDK
> result.** Shipping against the device result is the most expensive mistake in this flow.

---

## 8. Errors and troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `unable to find bundle named Stripe_StripePaymentSheet` | CocoaPods without the bundle patcher | Add the `post_install` block in [Install](#3-install), then `pod install` and clean build |
| Added `SpreedlyStripeAPM` but still get the bundle error | Patcher missing or not running | The `post_install` block is required for CocoaPods. Confirm the module is in your target, then clean build |
| Reinstalled Pods, still the same bundle error | Stale build artifacts | Clean build folder, clear Derived Data, `pod deintegrate` then a fresh `pod install`. Verify the patcher runs without errors |
| `CFBundleDisplayName must be non-nil` | Missing display name | Set it in `Info.plist` ([Configure your app](#4-configure-your-app)) |
| App Store rejection `ITMS-90683` | Missing `NSCameraUsageDescription` | Add the key — Apple's static analysis sees Stripe's camera references |
| Shopper never returns to the app after bank auth | Scheme mismatch | `redirect_url`, `StripeAPMConfig.returnURL`, and `CFBundleURLTypes` must all use the same scheme |
| Result never arrives | URL not forwarded | Route every custom-scheme open to `handleOffsiteReturn(url:)` |
| Purchase comes back non-pending | Gateway, APM, or webhook not configured | Re-check [What you need](#2-what-you-need) |
| SEPA payments never reach a final state | Stripe webhook not reaching Spreedly | Confirm the webhook is subscribed to all Payment Intent events |

Broader error model: [Error Handling](error-handling.md).

---

## 9. Edge cases and cleanup

### Blocked devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK
> blocks this flow automatically. `present()` returns immediately without showing any UI and a
> `PaymentResult.failure` is published. See
> [Security — Runtime Integrity](security.md#runtime-integrity).

### Screen prevention

The PaymentSheet is partner UI. Spreedly's `.screenPrevention()` does **not** cover it — do not
wrap it. See [Security](security.md).

### Delayed payment methods

The SDK sets `allowsDelayedPaymentMethods = true` on the PaymentSheet. Purchase currency decides
which APMs appear — a USD purchase shows none of the EUR methods.

### Cleanup

Hold the `AnyCancellable` from `subscribeToPaymentResults` for the lifetime of the screen and let
it deallocate with the view. Do not resubscribe on every render.

---

## 10. API at a glance

| API | Module | Purpose |
|---|---|---|
| `StripeAPMConfig(publishableKey:clientSecret:transactionToken:merchantDisplayName:returnURL:)` | `SpreedlyStripeAPM` | Sheet configuration |
| `SpreedlyStripeAPMCheckout.present(config:)` | `SpreedlyStripeAPM` | Present on the topmost view controller |
| `SpreedlyStripeAPMCheckout.present(config:from:)` | `SpreedlyStripeAPM` | Present from a specific view controller |
| `SpreedlyStripeAPMCheckout.present(config:appearance:)` / `present(config:appearance:from:)` | `SpreedlyStripeAPM` | Present with a themed sheet — see [step 6](#step-6--theme-the-sheet-optional--your-app) |
| `StripeAPMAppearanceConfig` | `SpreedlyStripeAPM` | Sheet theming: colors, corner radius, primary button, shadow, font |
| `StripeAPMType` / `StripeAPMTypeHelper` | `SpreedlyStripeAPM` | Typed APM constants for Swift and Objective-C |
| `SpreedlyStripeAPMCheckout.handleStripeReturnURL(_:)` | `SpreedlyStripeAPM` | Called by the SDK's URL pre-handler; returns `true` when handled |
| `Spreedly.shared().subscribeToPaymentResults { }` | `SpreedlyCore` | Receive the `PaymentResult` |
| `Spreedly.shared().handleOffsiteReturn(url:)` | `SpreedlyCore` | Forward redirect URLs from your app |

---

## 11. Related documentation

- [Stripe Radar](stripe-radar.md) — add a `radar_session_id` to the same purchase for fraud scoring
- [Offsite payments](offsite-payments.md) — the tokenize-then-redirect alternative, for APMs Stripe does not cover
- [Testing Guide](testing-guide.md) — sandbox keys, test flows, and the go-live checklist
- [Getting Started](getting-started.md) — installation and SDK lifecycle
- [Security](security.md) — runtime integrity and screen prevention

