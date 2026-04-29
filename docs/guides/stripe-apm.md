# Stripe APM Integration - Spreedly iOS SDK

Accept European payment methods via Stripe PaymentSheet (iDEAL, Bancontact, EPS, P24, SEPA).

**Estimated integration time:** ~15 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Supported APM Types](#supported-apm-types)
3. [Prerequisites](#prerequisites)
4. [URL Handling](#url-handling)
5. [SDK Methods](#sdk-methods)
6. [Flow](#flow)
7. [Backend API](#backend-api)
8. [SwiftUI Integration](#swiftui-integration)
9. [UIKit Integration](#uikit-integration)
10. [Objective-C Integration](#objective-c-integration)
11. [Result States](#result-states)
12. [Important Notes](#important-notes)
13. [Troubleshooting](#troubleshooting)
14. [Related Documentation](#related-documentation)

---

## Introduction

Stripe APM lets users pay via alternative payment methods (iDEAL, Bancontact, EPS, P24, SEPA Debit) using Stripe's native PaymentSheet. Unlike EBANX and other offsite flows, Stripe APM does **not** require a separate payment method tokenization step. Your backend creates a pending purchase directly, and the Stripe PaymentSheet handles APM selection and payment confirmation natively.

**Required for Stripe integration:** Stripe's code and resource bundles ship **inside** `SpreedlyStripeAPM`. Add `SpreedlyStripeAPM` (SPM or CocoaPods) to your app target and you're set — no separate Stripe package. Only add Stripe yourself if your app calls Stripe APIs outside the Spreedly module.

### Offsite vs Stripe APM vs Braintree

| Feature | Offsite | Stripe APM | Braintree |
|---------|---------|------------|-----------|
| Tokenization step | Yes (`submitOffsitePayment`) | No | No |
| Backend creates | Purchase (after token) | Pending purchase | Purchase |
| Checkout UI | Safari | Native PaymentSheet | Native PayPal/Venmo |
| Return flow | Deep link redirect | Deep link redirect | URL scheme / Universal Link |
| Module | SpreedlyUI | SpreedlyStripeAPM | SpreedlyBraintree |

---

## Supported APM Types

| Type | apm_types Value | Country | Currency |
|------|-----------------|---------|----------|
| iDEAL | `"ideal"` | Netherlands | EUR |
| Bancontact | `"bancontact"` | Belgium | EUR |
| EPS | `"eps"` | Austria | EUR |
| P24 | `"p24"` | Poland | PLN, EUR |
| SEPA Debit | `"sepa_debit"` | Eurozone | EUR |

Pass one or more of these values in the `apm_types` array when creating the pending purchase on your backend. The Stripe PaymentSheet displays only the APMs you specify (filtered by the currency in the purchase request).

**Typed constants (optional):** In Swift you can use `StripeAPMType` (e.g. `StripeAPMType.ideal.apmTypeValue`). In Objective-C use `StripeAPMTypeHelper.apmTypeValueForType:` (e.g. `[StripeAPMTypeHelper apmTypeValueForType:StripeAPMTypeEps]`). You can also pass string literals directly (e.g. `"ideal"`, `"sepa_debit"`).

---

## Prerequisites

Before integrating Stripe APM:

1. Complete [getting-started.md](getting-started.md) (installation, basic setup)
2. Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`)
3. **Stripe account** with APM payment methods enabled in the Stripe dashboard
4. **Stripe Payment Intents gateway** configured in Spreedly
5. **Stripe publishable key** (from the Stripe dashboard, starts with `pk_test_` or `pk_live_`)
6. **Stripe webhook** configured to send all Payment Intent events to Spreedly (required for delayed payment methods)
7. **SpreedlyStripeAPM** added to your app target (Stripe is fully embedded; no separate Stripe dependency)
8. **Info.plist:** Set **Bundle display name** (`CFBundleDisplayName`) in your app's `Info.plist`. The Stripe SDK requires it to be non-nil; otherwise you may see: *"CFBundleDisplayName must be non-nil. Please set 'Bundle display name' in your Info.plist."*
9. **Info.plist:** Add `NSCameraUsageDescription` with a user-facing string. The Stripe SDK's `StripePaymentSheet` includes card scanning that references camera APIs internally. Apple rejects App Store builds without this key (`ITMS-90683`), even if card scanning is never used.

Stripe APM lives in **SpreedlyStripeAPM**; PaymentSheet and its resources are part of that XCFramework. You do not manage a separate Stripe product or version for normal Spreedly checkout.

### Stripe dependency (SPM and CocoaPods)

There is no separate `StripePaymentSheet` dependency to add. SPM and CocoaPods both pull **SpreedlyStripeAPM** only; Stripe is built in. Add Stripe's own package or pod only if your app uses Stripe APIs outside Spreedly.

### CocoaPods: Stripe Bundle Patcher

**Current releases:** You do **not** need a `post_install` bundle patcher. Stripe resource bundles are generated during the Spreedly build and embedded in `SpreedlyStripeAPM.xcframework`. The `cocoapods_stripe_bundle_patcher.rb` script remains in the pod for backward compatibility; on new SDK versions it does nothing.

<details>
<summary>Legacy SDK versions (older Spreedly Stripe APM + CocoaPods)</summary>

Older builds expected CocoaPods bundle names to match what an SPM-linked XCFramework looked for, so apps had to run a small `post_install` patch.

**SPM users:** This was never required for SPM.

Add the following to your Podfile (after your `pod` declarations), then run `pod install`:

```ruby
post_install do |installer|
  stripe_apm_pod = installer.sandbox.pod_dir('SpreedlyStripeAPM')
  require File.join(stripe_apm_pod, 'scripts', 'cocoapods_stripe_bundle_patcher')
  SpreedlyStripeAPM::CocoaPods.apply_stripe_bundle_patch(installer)
end
```

Local development fallback (`:path => '../checkout-ios-package'`) is also supported:

```ruby
post_install do |installer|
  require_relative '../checkout-ios-package/scripts/cocoapods_stripe_bundle_patcher'
  SpreedlyStripeAPM::CocoaPods.apply_stripe_bundle_patch(installer)
end
```

The `cocoapods_stripe_bundle_patcher.rb` script is shipped inside the `SpreedlyStripeAPM` pod via `preserve_paths`. The `installer.sandbox.pod_dir('SpreedlyStripeAPM')` call locates the script automatically — no manual file copy, submodule, or path setup needed. This works for both remote (`:git =>`) and local (`:path =>`) pod installs.

The script patches the Pods embed script and adds a "Copy Stripe bundle for SPM" Run Script phase to your app target so all required Stripe bundles are present with SPM-expected names at runtime.

**React Native (checkout-react-native):** The RN Podfile's `apply_spreedly_stripe_support` uses the same sandbox-based lookup to find the patcher script automatically.

</details>

---

## URL Handling

Add a custom URL scheme to your app's `Info.plist` for redirect-based APMs. Example `CFBundleURLTypes` entry:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.yourapp.stripe</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
    </dict>
</array>
```

> **Braintree users:** If your app also uses Braintree (PayPal/Venmo), you must add a separate URL scheme: `$(PRODUCT_BUNDLE_IDENTIFIER).spreedly.braintree`. See [getting-started.md](getting-started.md#required-infoplist-entries) for the complete `CFBundleURLTypes` setup including both Stripe and Braintree schemes.

After the user completes authentication in Safari (e.g., iDEAL bank auth), they are redirected back into your app. The same `handleOffsiteReturn(url:)` call you already use for offsite payments handles Stripe APM redirects too. In **SwiftUI** use `onOpenURL`; in **UIKit/Objective-C** handle the URL in `SceneDelegate` (or `AppDelegate`). See the platform examples below.

> **Note:** Stripe return URL handling is done via the SDK's URL pre-handler (`Spreedly.shared().setURLPreHandler`). When you present the Stripe PaymentSheet, the SDK registers a pre-handler that forwards Stripe redirect URLs to `SpreedlyStripeAPMCheckout.handleStripeReturnURL(_:)`. Your app's `onOpenURL` or `SceneDelegate` should still forward URLs to `handleOffsiteReturn(url:)`, which invokes the pre-handler chain.

### redirect_url vs returnURL Clarification

- **Backend `redirect_url`** (in the purchase API): Can be either a **Spreedly-hosted URL** (e.g. `https://spreedly.com/stripe-apm/redirect`) or your **custom scheme** (e.g. `myapp://stripe-redirect`).
- **`StripeAPMConfig.returnURL`**: Your app's **custom URL scheme** (e.g. `myapp://stripe-redirect`). This must match the scheme registered in `Info.plist` under `CFBundleURLTypes`.
- **Example app:** The Spreedly example app uses a Spreedly-hosted URL for the backend `redirect_url` and a custom scheme for `returnURL`.

---

## SDK Methods

| # | Method | Module | Purpose |
|---|--------|--------|---------|
| 1 | Backend: create pending purchase | Merchant backend | Get `client_secret` and `transaction_token` |
| 2 | `SpreedlyStripeAPMCheckout.present(config:)` / `present(config:from:)` | SpreedlyStripeAPM | Present Stripe PaymentSheet. The no-argument variant finds the topmost VC automatically. Use `present(config:from:)` to specify the presenting view controller. |
| 3 | `SpreedlyStripeAPMCheckout.handleStripeReturnURL(_ url: URL) -> Bool` | SpreedlyStripeAPM | Handle Stripe redirect URL; returns `true` if the URL was handled |
| 4 | `subscribeToPaymentResults` | SpreedlyCore | Receive payment result |
| 5 | `handleOffsiteReturn(url:)` | SpreedlyCore | Handle redirect when app re-opens |

---

## Flow

1. **Backend creates pending purchase:** Call Spreedly purchase API with `payment_method_type: "stripe_apm"`, `apm_types`, `redirect_url`, and `callback_url`. Receive `transaction.token`, `transaction.state == "pending"`, and `transaction.gateway_specific_response_fields.stripe_payment_intents.client_secret`.

2. **Build StripeAPMConfig and present PaymentSheet:** Build `StripeAPMConfig` (publishable key, client secret, transaction token, merchant display name, return URL) and call `SpreedlyStripeAPMCheckout.present(config:)`. The SDK finds the topmost view controller; no need to pass a presenter.

3. **Handle PaymentResult:** User completes payment (and any redirect). Receive `PaymentResult` via `subscribeToPaymentResults` (SwiftUI/Swift) or `SpreedlyPaymentDelegate.paymentDidComplete:` (UIKit/Objective-C).

4. **Handle redirect URL:** When the user returns from an external flow (e.g. bank auth), forward the URL to `Spreedly.shared().handleOffsiteReturn(url:)` (SwiftUI: `onOpenURL`; UIKit/ObjC: SceneDelegate/AppDelegate).

---

## Backend API

> The example app uses `PurchaseAPIClient` (see `API/PurchaseAPIClient.swift`). In production, replace this with your own backend endpoint.

Your backend calls Spreedly's API to create a pending purchase with `stripe_apm` payment method type:

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

Extract `transaction.token` (the Spreedly transaction token) and `transaction.gateway_specific_response_fields.stripe_payment_intents.client_secret` (the Stripe PaymentIntent client secret) for use in `StripeAPMConfig`.

**`redirect_url`:** Can be a Spreedly-hosted URL (e.g. `https://spreedly.com/stripe-apm/redirect`) or your custom scheme (e.g. `myapp://stripe-redirect`). See [redirect_url vs returnURL Clarification](#redirect_url-vs-returnurl-clarification).

---

## SwiftUI Integration

```swift
import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI
import SpreedlyStripeAPM

struct StripeAPMPaymentView: View {
    @State private var paymentResultCancellable: AnyCancellable?
    @State private var stage: StripeAPMStage = .idle
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var selectedProduct: Product?
    @State private var selectedAPMTypes: Set<String> = ["ideal"]

    enum StripeAPMStage { case idle, creatingPendingPurchase, checkout }

    var body: some View {
        VStack {
            Button("Pay") { startStripeAPMFlow() }
                .disabled(selectedProduct == nil || selectedAPMTypes.isEmpty || isLoading)
            if let success = successMessage { Text(success).foregroundColor(.green) }
            if let error = errorMessage { Text(error).foregroundColor(.red) }
        }
        .onAppear {
            paymentResultCancellable?.cancel()
            paymentResultCancellable = Spreedly.shared().subscribeToPaymentResults { handlePaymentResult($0) }
        }
        // IMPORTANT: Place .onOpenURL in your root @main App struct, NOT here.
        // It is shown inline for readability only.
        // See getting-started.md for the canonical onOpenURL setup.
        .onOpenURL { url in
            _ = Spreedly.shared().handleOffsiteReturn(url: url)
        }
    }

    func startStripeAPMFlow() {
        guard let product = selectedProduct else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        stage = .creatingPendingPurchase

        Task {
            let client = YourAPIClient.shared
            let response = try await client.stripeAPMPendingPurchase(
                amount: product.price * 100,
                currencyCode: "EUR",
                redirectUrl: "myapp://stripe-redirect",
                callbackUrl: "https://your-backend.com/callback",
                apmTypes: Array(selectedAPMTypes)
            )

            await MainActor.run {
                guard let transaction = response.transaction,
                      transaction.state == "pending",
                      let clientSecret = transaction.gatewaySpecificResponseFields?.stripePaymentIntents?.clientSecret else {
                    isLoading = false
                    stage = .idle
                    errorMessage = "Failed to create pending purchase"
                    return
                }

                stage = .checkout
                isLoading = false

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

    func handlePaymentResult(_ result: PaymentResult) {
        guard stage == .checkout else { return }
        stage = .idle
        isLoading = false

        if result.isSuccess {
            switch result.state {
            case "succeeded": successMessage = "Payment completed!"
            case "processing": successMessage = "Payment accepted, confirmation pending."
            case "pending": successMessage = "Payment submitted."
            default: successMessage = "Payment completed."
            }
        } else {
            let msg = result.failureDetails?.getDescription() ?? "Payment failed"
            errorMessage = msg.lowercased().contains("canceled") ? "Payment was canceled." : msg
        }
    }
}
```

---

## UIKit Integration

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
            } else {
                let msg = result.failureDetails?.getDescription() ?? "Payment failed"
                self.showError(msg.contains("canceled") ? "Payment was canceled." : msg)
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

---

## Objective-C Integration

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
        } else {
            NSString *msg = [result.failureDetails getDescription] ?: @"Payment failed";
            [self showError:[msg rangeOfString:@"canceled" options:NSCaseInsensitiveSearch].location != NSNotFound ? @"Payment was canceled." : msg];
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

---

## Result States

| state | Meaning | UX |
|-------|---------|-----|
| `"succeeded"` | Payment completed, funds received | Show success |
| `"processing"` | Payment accepted, funds pending (e.g., SEPA debit) | Show "Payment accepted, confirmation pending" |
| `"pending"` | Payment submitted, awaiting final status | Show "Payment submitted" |
| `"failed"` / `"gateway_processing_failed"` | Payment failed | Show error, offer retry |

---

## Important Notes

- **No tokenization step:** Unlike EBANX/PayPal, Stripe APM does not use `submitOffsitePayment()`. The pending purchase is created directly on the backend.

- **SDK finds topmost VC:** Call `SpreedlyStripeAPMCheckout.present(config:)` with only the config. The SDK finds the topmost view controller automatically. If your app has a complex navigation hierarchy where automatic detection doesn't work, use `SpreedlyStripeAPMCheckout.present(config:from:)` and pass the presenting view controller explicitly.

- **URL handling:** Use `handleOffsiteReturn(url:)` in `onOpenURL` (SwiftUI) or in `SceneDelegate` (UIKit/Objective-C). The SDK forwards Stripe redirect URLs internally; no Stripe-specific code is required in the app.

- **Delayed payment methods:** The SDK sets `allowsDelayedPaymentMethods = true` on the PaymentSheet. Currency (e.g., EUR for iDEAL) in the pending purchase determines which APMs are shown.

---

### Blocked Devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK blocks this flow automatically. The `present()` call returns immediately without showing any UI, and a `PaymentResult.failure` is published. See [Security — Runtime Integrity](security.md#runtime-integrity) for details.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Crash: `Fatal error: unable to find bundle named Stripe_StripePaymentSheet` | On current SDKs, Stripe is embedded in `SpreedlyStripeAPM` — link that product from `checkout-ios-package` only, then clean and rebuild. **Legacy:** Very old CocoaPods setups may still need the [bundle patcher](#cocoapods-stripe-bundle-patcher) (see collapsed “Legacy SDK versions” there). |
| **CocoaPods:** Added `SpreedlyStripeAPM` but still get bundle error | Upgrade to a current SDK (embedded bundles). **Legacy:** Open the [CocoaPods Stripe Bundle Patcher](#cocoapods-stripe-bundle-patcher) section and use the legacy `post_install` if you must stay on an older release. |
| **Reinstalled Pods but still crashes** with the same bundle error | Clean build folder, clear Derived Data, `pod deintegrate` / fresh `pod install` if needed. **Legacy:** Same bundle error on old releases — add the patcher from [CocoaPods Stripe Bundle Patcher](#cocoapods-stripe-bundle-patcher). |
| App Store rejection `ITMS-90683` (missing `NSCameraUsageDescription`) | Add `NSCameraUsageDescription` to your app's `Info.plist`. The Stripe SDK's `StripePaymentSheet` module includes card scanning functionality that references camera APIs internally. Apple's static analysis detects these references even if card scanning is never presented to the user. Without this key, App Store and TestFlight submissions will be rejected. |
| `CFBundleDisplayName must be non-nil` | Set `CFBundleDisplayName` in your app's `Info.plist` with a string value (e.g. your app name). |
| User not redirected back to app after bank auth | Ensure `redirect_url` in the purchase request matches your custom URL scheme (e.g. `myapp://stripe-redirect`), and that `returnURL` in `StripeAPMConfig` matches. Register the scheme in `Info.plist` under `CFBundleURLTypes`. |
| `handleOffsiteReturn` not called | Forward all custom URL opens from `onOpenURL` (SwiftUI) or `SceneDelegate.scene(_:openURLContexts:)` (UIKit) to `Spreedly.shared().handleOffsiteReturn(url:)`. |
| Pending purchase fails or returns non-pending state | Verify your Stripe Payment Intents gateway is configured in Spreedly, APMs are enabled in Stripe dashboard, and the Stripe webhook is sending Payment Intent events to Spreedly. |

---

## Related Documentation

- [offsite-payments.md](offsite-payments.md) - PayPal and Sprel offsite payments
- [ebanx-apm.md](ebanx-apm.md) - Pix, Boleto, OXXO, NuPay
- [braintree-apm.md](braintree-apm.md) - PayPal and Venmo via Braintree
- [STRIPE_FLOW.md](../development/STRIPE_FLOW.md) - Detailed flow diagrams for Stripe APM
