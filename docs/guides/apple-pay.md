# Apple Pay — Spreedly iOS SDK

Accept Apple Pay with Apple's official button and sheet. The SDK shows the button, presents Apple's sheet, tokenizes the authorized payment with Spreedly while the sheet is still open, waits for your server to charge it, and only then completes the sheet, so the shopper sees success once the money has moved.

|  |  |
|---|---|
| **Use this when** | You want Apple Pay on your own checkout screen, or at the top of the Spreedly card drop-in |
| **Use something else when** | Cards only → [Express Checkout](express-checkout.md) · your own card fields → [Custom Payment Forms](custom-payment-forms.md) · PayPal or Venmo → [Braintree APM](braintree-apm.md) |
| **You build** | 3 things: a charge endpoint on your server · an Apple Pay button (or drop-in wallet row) in your app · a `processPayment` closure that calls the endpoint |
| **Modules** | `SpreedlyCore` + `SpreedlySecurity` + `SpreedlyUI` + `SpreedlyApplePay` |
| **Requires** | The first SDK release that includes `SpreedlyApplePay` (not yet released) · iOS 16.0+ · Xcode 27.0+ · a physical device for end-to-end testing |
| **Integration time** | ~20 minutes (after Apple Developer setup) |
| **UI** | Apple's PassKit button and sheet, or the card drop-in — SwiftUI · UIKit · Objective-C |

> **iOS only:** Apple Pay uses Apple's PassKit framework and is specific to the iOS SDK.

**Fast path:** [How it works](#1-how-it-works) → [What you need](#2-what-you-need) →
[Install](#3-install) → [Configure your app](#4-configure-your-app) →
[Build the flow](#5-build-the-flow) → [your platform](#6-integration-by-platform).

---

<a id="introduction"></a>
<a id="how-the-drop-in-and-the-button-work"></a>
<a id="flow"></a>
## 1. How it works

Three parts. Your server charges, your app shows Apple Pay, and the SDK connects the two while Apple's sheet is open.

| Part | Who builds it | Job |
|---|---|---|
| Charge endpoint | **Your server** | Runs purchase (or authorize) on the Spreedly payment method token and answers charged or declined |
| Apple Pay button or drop-in wallet row | **Your app** | `ApplePayConfiguration` + `ApplePayOrder`, the button in your layout, and result handling |
| `processPayment` closure | **Your app** | Calls your charge endpoint while the sheet is open; required, and the sheet waits for its answer |

One successful payment:

1. Your app calls `Spreedly.setup(config:)`, the same as card checkout.
2. You render the Apple Pay button with an `ApplePayConfiguration` and an `ApplePayOrder`. The SDK checks Wallet and shows the Pay button or nothing.
3. The shopper taps. The SDK runs `prepareForPresentation` if you set it, then presents Apple's sheet, and the shopper authorizes with Face ID, Touch ID or passcode.
4. The SDK asks your `signedAuth` for fresh signed auth for this attempt, then tokenizes the payment with Spreedly **while the sheet is open**.
5. The SDK calls your `processPayment` with the Spreedly token and waits while your server charges it.
6. Only after your server answers does the sheet show success or failure. The `PaymentResult` arrives on `Spreedly.shared().subscribeToPaymentResults` / `paymentDelegate`, the same channel as card checkout, on every path.

**Working on only one part?** Apple and Spreedly setup → [step 1](#step-1--merchant-id-and-processing-certificate--dashboard) · Backend → [step 6](#step-6--charge-the-token--your-server) · iOS → [step 3](#step-3--configure-apple-pay--your-app).

**Pick an integration path:**

| Path | Use when | You build |
|---|---|---|
| **`CardFormDropIn(walletButtons:)`** with a `SpreedlyApplePayWallet` | You use the card drop-in and want Apple Pay on top of it | Nothing beyond configuration |
| **`SpreedlyApplePayButton`** (SwiftUI) / **`SpreedlyApplePayButtonView`** (UIKit, Objective-C) | Apple Pay on your own checkout screen | Nothing beyond configuration |
| **`SpreedlyApplePayWallet`** (`WalletButtonProvider`) | You render several wallets from one list | Your own layout |

<details>
<summary><b>Drop-in or button?</b> — where Apple Pay appears and what you add</summary>

| | Card drop-in (`CardFormDropIn`) | Apple Pay button (`SpreedlyApplePayButton` / `SpreedlyApplePayButtonView`) |
|---|---|---|
| Where Apple Pay appears | At the top of the SDK's card sheet, above an "or pay with card" divider | Anywhere on your own screen |
| What the shopper sees | One sheet: Apple Pay **or** card fields | Your screen with Apple's button |
| What you add | `SpreedlyApplePayWallet` in `walletButtons` | The button view in your layout |
| Card payments | Included | Not included (add `SPLTextField`s or the drop-in if needed) |

</details>

<details>
<summary>What the SDK does for you, on both paths</summary>

1. Checks the device and Wallet, and shows the Pay button or nothing.
2. Renders Apple's official button with your type, style and corner radius.
3. On tap, checks the security gate, runs `prepareForPresentation` (if set, with a 30-second limit), and checks SDK setup.
4. Builds Apple's payment request from `ApplePayConfiguration` and `ApplePayOrder` and validates it.
5. Presents Apple's sheet.
6. For every attempt, gets fresh signed auth from your `signedAuth` (30-second limit), then tokenizes the payment with Spreedly while the sheet is open.
7. Runs your `processPayment` with timeout, pending and "status unknown" handling.
8. Completes the sheet with success or failure, publishes exactly one final `PaymentResult`, and records telemetry.
9. In the drop-in: shows "Your payment is still being processed. Please don't pay again.", disables card Pay and blocks swipe-to-close while pending, and closes the drop-in on success.

**What you write:** an `ApplePayConfiguration`, an `ApplePayOrder`, the button or wallet line, result handling, and a `processPayment` closure that calls your server. A complete integration is typically 15–30 lines of app code plus your server's charge endpoint. Everything that talks to PassKit is in the SDK.

</details>

---

<a id="prerequisites"></a>
## 2. What you need

Account and dashboard setup you can't do from Xcode. Each missing item fails at **runtime**, not at compile time.

| Category | You need | Where to get it |
|---|---|---|
| Apple | An **Apple Pay Merchant ID** (e.g. `merchant.com.example.store`) | Apple Developer → Certificates, Identifiers & Profiles → Identifiers → Merchant IDs |
| Apple + Spreedly | An **Apple Pay Payment Processing Certificate** created from a Spreedly certificate signing request and uploaded back to Spreedly, so Spreedly can decrypt Apple Pay payments | [Spreedly's Apple Pay guide](https://developer.spreedly.com/docs/apple-pay) · see [step 1](#step-1--merchant-id-and-processing-certificate--dashboard) |
| Your app target | The **Apple Pay capability** with that Merchant ID selected | Xcode → target → Signing & Capabilities · see [Configure your app](#4-configure-your-app) |
| Your backend | An endpoint that mints signed auth (called for every Apple Pay attempt), and one that charges a Spreedly token | [Getting Started](getting-started.md) · see [step 6](#step-6--charge-the-token--your-server) |
| Testing | A **physical device** with an Apple sandbox tester. The Simulator can show the sheet but can't produce a real payment token | App Store Connect → Users and Access → Sandbox |

### Compatibility

| SDK version | iOS | Xcode | Notes |
|---|---|---|---|
| Next release (after 1.8.0) | 16.0+ | 27.0+ | First release with `SpreedlyApplePay` |
| 1.8.0 and earlier | — | — | No Apple Pay module |

Assumed done: [Getting Started](getting-started.md) — installation plus `Spreedly.initializeSDK()` at launch and `Spreedly.setup(config:)` with a signed bundle.

---

<a id="installation"></a>
## 3. Install

> **You'll need:** the latest tag from
> [checkout-ios-package](https://github.com/spreedly/checkout-ios-package/releases). Use one
> version for every Spreedly module in your app.

`SpreedlyApplePay` is optional and ships alongside `SpreedlyCore` (tokenization), `SpreedlySecurity` and `SpreedlyUI` at the same SDK version. PassKit is an Apple system framework, so there's no third-party dependency.

**Swift Package Manager**

```swift
.package(url: "https://github.com/spreedly/checkout-ios-package", from: "X.Y.Z")  // the latest release tag; Apple Pay needs the first release that includes it
// Link SpreedlyCore, SpreedlySecurity, SpreedlyUI, SpreedlyApplePay to your app target.
```

`SpreedlyApplePay` is available through Swift Package Manager only; there is no CocoaPods pod for it.

```swift
import SpreedlyCore
import SpreedlyUI
import SpreedlyApplePay
```

---

## 4. Configure your app

> **You'll need:** the Merchant ID from [What you need](#2-what-you-need).

No Info.plist keys are needed for Apple Pay. Turn on the capability instead:

1. In Xcode, select your app target → **Signing & Capabilities** → **+ Capability** → **Apple Pay**.
2. Tick your Merchant ID.

Xcode adds the entitlement below. Its value must contain the same Merchant ID you pass to `ApplePayConfiguration`. If you sign manually, regenerate and download your provisioning profiles after enabling the capability, or the sheet won't open.

| Key | Value | Why | Required |
|---|---|---|---|
| `com.apple.developer.in-app-payments` | Your Merchant ID | Without it, Apple's sheet can't be presented | Yes |

```xml
<key>com.apple.developer.in-app-payments</key>
<array>
    <string>merchant.com.example.store</string>
</array>
```

---

## 5. Build the flow

Eight steps; steps 7 and 8 are only for subscriptions. Each is labelled with who does it.

<a id="step-1--merchant-id-and-processing-certificate--dashboard"></a>
### Step 1 — Merchant ID and processing certificate · `Dashboard`

1. Create the Merchant ID in your Apple Developer account.
2. Create a Payment Processing Certificate for it from a Spreedly certificate signing request, and upload the certificate to Spreedly. See [Spreedly's Apple Pay guide](https://developer.spreedly.com/docs/apple-pay).
3. Track the certificate's expiry date. Before it expires, create a new one from a fresh Spreedly certificate signing request and upload it, or Apple Pay payments stop vaulting.

### Step 2 — Signed auth · `Your server`

Mint signed auth exactly as for cards, but for **every Apple Pay attempt**: the SDK calls your `signedAuth` (step 4) after the shopper authorizes and uses the auth for that Apple Pay request only. Signed auth works for one request to Spreedly, even a failed one. You still call `Spreedly.setup(config:)` before checkout, as for cards; Apple Pay never replaces or uses up that auth, so a card form on the same screen keeps it. See [Signed auth for each attempt](#retry-auth) and [Getting Started](getting-started.md).

<a id="configuration"></a>
<a id="step-3--configure-apple-pay--your-app"></a>
### Step 3 — Configure Apple Pay · `Your app`

```swift
let applePayConfig = ApplePayConfiguration(
    merchantIdentifier: "merchant.com.example.store",
    countryCode: "US",
    currencyCode: "USD"
)
applePayConfig.supportedNetworks = [.visa, .masterCard, .amex, .discover]   // optional: only what your gateway accepts (default: all Spreedly-supported networks)
applePayConfig.merchantCapabilities = .threeDSecure                           // default; Apple Pay token format
applePayConfig.requiredBillingContactFields = [.postalAddress, .name]
applePayConfig.buttonType = .checkout                                         // default .buy
applePayConfig.buttonStyle = .automatic                                       // follows light/dark mode
applePayConfig.emptyWalletBehavior = .showPayButton                           // default
applePayConfig.metadata = ["order_id": "1234"]                                // optional, stored on the payment method

let order = ApplePayOrder(label: "Your Store", amount: NSDecimalNumber(string: "19.99"))
```

You set the total. The SDK passes it to Apple's sheet as-is; your server should charge the same total. The total must be zero or more. A negative or non-numeric total fails before the sheet opens with a message naming the problem.

<details>
<summary><b>Every <code>ApplePayConfiguration</code> property</b></summary>

| Property | Default | Notes |
|---|---|---|
| `merchantIdentifier` | — | Required. Your Apple Pay Merchant ID |
| `countryCode` | — | Required. 2-letter ISO 3166-1 |
| `currencyCode` | — | Required. 3-letter ISO 4217 |
| `supportedNetworks` | Every Apple Pay network Spreedly supports (`ApplePayConfiguration.defaultSupportedNetworks`). See [Supported card networks](#supported-card-networks) | Networks the shopper may pay with. Your gateway may not accept all of them: set this to the networks your gateway supports. Cards outside the list are greyed out in the sheet. **Must contain at least one network.** An empty list doesn't mean "all": the checkout fails before the sheet opens with "Apple Pay configuration needs at least one supported network." |
| `merchantCapabilities` | `.threeDSecure` | Limits which cards can pay (debit-only, credit-only). The SDK always keeps a payment format. See [Merchant capabilities](#merchant-capabilities) |
| `requiredBillingContactFields` / `requiredShippingContactFields` | empty | Collected contacts are sent to Spreedly with the token |
| `billingContact` / `shippingContact` | `nil` | A saved address you already have, shown as the default in the sheet. See [Prefill a saved address](#prefill-a-saved-address) |
| `shippingType` | `.shipping` | How the sheet labels the address: `.shipping`, `.delivery`, `.storePickup` or `.servicePickup`. Wording only |
| `buttonType` / `buttonStyle` / `cornerRadius` | `.buy` / `.automatic` / `8` | Apple's official button only |
| Button height | 44 pt minimum | UIKit / Objective-C views have a required 44 pt minimum (a lower required height constraint causes an Auto Layout conflict warning). In SwiftUI, don't apply a `.frame(height:)` below 44; a parent frame can override the button's own minimum |
| `emptyWalletBehavior` | `.showPayButton` | See [step 4](#empty-wallet-behavior) |
| `metadata` | `nil` | Merchant metadata on the payment method |
| `supportedCountries` | `nil` (any) | 2-letter ISO country codes of card issuers you accept, e.g. `["US", "CA"]`. **`nil` or an empty set means any country** (no restriction), the opposite of `supportedNetworks`. Any other entry (e.g. `"USA"`) fails the checkout with a configuration error |
| `merchantCategoryCode` | `0` (unset) | Your ISO 18245 business code, e.g. `5812`; sent on iOS 18+ only |
| `processPaymentTimeout` | `120` seconds | Longest wait for `processPayment` before a "status unknown" result. Values below 30 seconds are raised to 30 |
| `testCardNumber` | `nil` | Testing only. A Spreedly test card number sent with the Apple Pay token so purchases on a Spreedly Test gateway succeed. See [Try it in sandbox](#testing-on-a-spreedly-test-gateway) |

</details>

<a id="prefill-a-saved-address"></a>
**Prefill a saved address.** If the shopper is signed in and you have their address on file, pass it as `billingContact` or `shippingContact`. Apple shows it as the selected address, and the shopper can still pick another. Apple only shows a saved contact when the sheet asks for it, so the SDK fails the checkout before the sheet opens with a configuration error when:

- `billingContact` is set without `.postalAddress` in `requiredBillingContactFields`
- `shippingContact` is set with an empty `requiredShippingContactFields`

Apple shows only the parts of the saved contact that the sheet asks for: if you request just `.emailAddress`, the saved postal address isn't shown. In the Example app's Configure & Try screen, each prefill switch stays off and greyed out until its matching field is on.

**Billing edits in the sheet.** A saved `billingContact` is only the default Apple shows. If the shopper edits that billing address in the sheet, the sheet may show your saved address again afterwards. Apple gives apps no callback for billing-address changes (it does for shipping), so the SDK can't update what the sheet shows. Prefill the billing address only when it's current, for example the address the shopper confirmed in your app.

```swift
import Contacts
import PassKit

let saved = PKContact()
saved.name = PersonNameComponents(givenName: "Test", familyName: "Shopper")   // synthetic example
let address = CNMutablePostalAddress()
address.street = "1 Example Street"
address.city = "Springfield"
address.postalCode = "00000"
address.isoCountryCode = "US"
saved.postalAddress = address

applePayConfig.requiredShippingContactFields = [.postalAddress, .name]
applePayConfig.shippingContact = saved
applePayConfig.shippingType = .delivery   // the sheet says "Delivery Address" instead of "Shipping Address"
```

The saved contact is personal data. The SDK passes it to Apple only: it doesn't log it, add it to telemetry or send it to Spreedly. Spreedly receives the address the shopper approves in the sheet, as with any collected contact.

`shippingType` changes only the sheet's wording and works with or without a saved contact: use `.delivery` for food or grocery delivery, `.storePickup` for click and collect, and `.servicePickup` when the address is where a service happens.

<a id="merchant-capabilities"></a>
**Merchant capabilities.** Use `merchantCapabilities` to limit which cards the shopper can pay with. Most merchants keep the default.

<details>
<summary><b>Values, and what the SDK does with them</b></summary>

| Value | Use it when |
|---|---|
| `.threeDSecure` (default) | Always. It is Apple Pay's standard payment format (a one-time cryptogram), used by Visa, Mastercard, Amex and Discover. Despite the name, it does **not** trigger a 3-D Secure challenge |
| `.debit` or `.credit` | You accept only debit cards, or only credit cards |
| `.emv` | Only if you accept China UnionPay. Apple says to include it only for China UnionPay transactions |

- **The SDK keeps a payment format for you.** Apple Pay needs `.threeDSecure` or `.emv`. If you set only `.debit` or `.credit`, the SDK adds `.threeDSecure` and logs a warning, so `[.debit]` works the same as `[.threeDSecure, .debit]`.
- **Cards you don't accept are greyed out.** With `[.threeDSecure, .debit]`, the shopper's credit cards are greyed out in the sheet and can't be selected.
- **No eligible card at all.** If none of the shopper's cards match `merchantCapabilities` and `supportedNetworks`, availability is `.needsSetup`, and `emptyWalletBehavior` decides whether to show the Pay button or nothing.

```swift
applePayConfig.merchantCapabilities = .threeDSecure              // default: debit and credit
applePayConfig.merchantCapabilities = [.threeDSecure, .debit]     // debit cards only
```

```objc
applePayConfig.merchantCapabilities = PKMerchantCapability3DS | PKMerchantCapabilityDebit;
```

</details>

<a id="supported-card-networks"></a>
**Supported card networks.** By default the SDK offers every Apple Pay card network that Spreedly supports.

<details>
<summary>Network list and what's not included</summary>

| Network | `PKPaymentNetwork` | In the default list |
|---|---|---|
| Visa | `.visa` | Yes |
| Mastercard | `.masterCard` | Yes |
| Maestro | `.maestro` | Yes |
| American Express | `.amex` | Yes |
| Discover | `.discover` | Yes |
| JCB | `.JCB` | Yes |
| Elo | `.elo` | Yes |
| Cartes Bancaires | `.cartesBancaires` | Yes |
| Interac | `.interac` | Yes |
| mada | `.mada` | Yes |
| Bancontact | `.bancontact` | Yes |
| Dankort | `.dankort` | Yes |
| Verve | `.verve` | No. Apple added it in iOS 27, so it needs Xcode 27 or later. If your gateway accepts it, add it behind `if #available(iOS 27, *)` |
| China UnionPay | `.chinaUnionPay` | No. Add it if your gateway accepts it. Apple ties China UnionPay to the `.emv` capability, see [Merchant capabilities](#merchant-capabilities) |

Apple Pay networks not listed here (for example Visa Electron, V Pay, eftpos, girocard, Mir and Japan's Suica, QUICPay and iD) are not Spreedly card brands, so don't add them to `supportedNetworks`. Some Spreedly card brands, such as Cabal, Naranja and WEX, have no Apple Pay network, so you can't select them in `supportedNetworks`.

A network being a Spreedly card brand doesn't mean every gateway accepts it, so trim the list to what your gateway supports. Spreedly's [supported payment methods](https://developer.spreedly.com/docs/supported-payment-methods) page lists every card brand. Apple's [`PKPaymentNetwork`](https://developer.apple.com/documentation/passkit/pkpaymentnetwork) lists every Apple Pay network.

</details>

<a id="empty-wallet-behavior"></a>
### Step 4 — Show the button · `Your app`

Add the button to your screen ([§ 6](#6-integration-by-platform) has a full view per UI stack). When the device supports Apple Pay but Wallet has no card for your networks:

| `ApplePayEmptyWalletBehavior` | What the shopper sees |
|---|---|
| `.showPayButton` (default) | Pay button; Apple's sheet guides the shopper to add a card |
| `.hide` | No button until a card is added. Apple's guidelines recommend not hiding the Apple Pay button, so prefer the default unless your layout needs it |

On devices that can't use Apple Pay at all (unsupported hardware, region, or restrictions), the button is never shown, whatever this setting is. The button re-checks Wallet when your app becomes active, so it updates after the shopper adds a card.

`prepareForPresentation` is optional and runs on tap, before the sheet opens, for example to check the cart is still valid. Return `false` to stop the sheet from opening. If it doesn't return within 30 seconds, the SDK publishes a failure and the next tap starts a fresh checkout.

<a id="retry-auth"></a>
**Signed auth for each attempt.** `signedAuth` is required. The SDK calls it after the shopper authorizes and before the payment goes to Spreedly, once for every attempt, including a retry in the same sheet after a decline or a failed save. Spreedly's signed auth works for one request only, even a failed one, so mint fresh auth on your server every time it's called. Return it as a `SpreedlyConfig` with the same `environmentKey` you passed to `Spreedly.setup(config:)`. The auth signs that Apple Pay request only: it doesn't replace your `setup(config:)` configuration, so the card form in the drop-in keeps its own unused auth, and a card payment after an Apple Pay decline still works. Don't return the configuration you passed to `setup(config:)`: its nonce belongs to the card form, so the SDK refuses it. If `signedAuth` throws, returns incomplete auth or the `setup(config:)` auth, or takes longer than 30 seconds, that attempt fails without being sent, nothing is charged, and the shopper can try again in the sheet. Don't turn off Enhanced Security to avoid minting auth: it is Spreedly's protection against card testing.

<details>
<summary>Standalone Set Up button and checking availability yourself</summary>

For a payment-settings screen outside checkout, use the standalone Set Up button. It appears only when the device supports Apple Pay and Wallet has no eligible card:

```swift
SpreedlyApplePaySetUpButton(supportedNetworks: [.visa, .masterCard])
    .frame(height: 44)
```

Use these to decide whether to show an Apple Pay section at all:

```swift
switch SpreedlyApplePayWallet.availability(for: applePayConfig) {   // uses your networks and card types
case .ready: break         // Wallet has an eligible card
case .needsSetup: break    // Apple Pay works, but Wallet has no eligible card
case .unsupported: break   // device, region, or restrictions don't allow Apple Pay
}
let anyCard = SpreedlyApplePayWallet.availability(networks: ApplePayConfiguration.defaultSupportedNetworks)
SpreedlyApplePayWallet.openWalletSetup()   // opens Wallet's add-card flow
```

From Objective-C: `[SpreedlyApplePayWallet availabilityForConfiguration:config]`, `[SpreedlyApplePayWallet availabilityWithNetworks:capabilities:]` and `[[SpreedlyApplePaySetUpButtonView alloc] init]`. `SpreedlyApplePayButtonView.refreshAvailability()` re-checks on demand; the button already does this when it appears and when the app becomes active.

</details>

<a id="charge-before-the-sheet-completes"></a>
### Step 5 — Charge in `processPayment` · `Your app`

`processPayment` is required. The SDK vaults the payment while Apple's sheet is still open, calls your closure with the Spreedly token, and completes the sheet with your answer, so Apple's success check means your server accepted the payment:

```swift
let applePayWallet = SpreedlyApplePayWallet(
    configuration: applePayConfig,
    order: order,
    signedAuth: { try await yourServer.freshSpreedlyAuth() }   // new SpreedlyConfig for every attempt
) { authorization in
    // Your server runs purchase (or authorize) with the token and the amount from its own order.
    let charged = try await yourServer.charge(token: authorization.paymentMethodToken)
    return charged ? .approved : .declined(message: "Your card was declined.")
}
```

`processPayment` and `signedAuth` are initializer parameters on `SpreedlyApplePayButton`, `SpreedlyApplePayButtonView` and `SpreedlyApplePayWallet` (Objective-C: `signedAuthHandler:` and `processPaymentHandler:`). You can replace it later through the `processPayment` property or `setProcessPaymentHandler:`. The SDK never charges the card itself: purchase needs your Spreedly server credentials, which must not be in your app.

| Your answer | Apple's sheet | `PaymentResult` |
|---|---|---|
| `.approved` | Success | `isSuccess` with the token |
| `.declined(message:)` | Failure; the shopper can try another card | `isFailure`; your message is in `failureDetails` and is passed to Apple's sheet, which may show it or its own text |
| `.declined(message:errors:)` | Failure; the sheet marks the field in `errors` and the shopper can change it and pay again | `isFailure`; your message is in `failureDetails` |
| `.statusUnknown`, or the closure throws | Closes, so the shopper can't pay twice | `isFailure` + `isStatusUnknown`: you couldn't tell whether your server charged (for example the connection dropped) |

<a id="decline-with-field-errors"></a>
**Point the sheet at what's wrong.** When your server declines because of a detail the shopper can change, such as an address you don't deliver to, return `.declined(message:errors:)` with errors from PassKit's `PKPaymentRequest` error methods. Apple's sheet marks that field instead of showing a general failure:

```swift
return .declined(
    message: "We don't deliver to this address.",
    errors: [PKPaymentRequest.paymentShippingAddressUnserviceableError(withLocalizedDescription: "We don't deliver here")]
)
```

Apple shows its own prompt, "Update Delivery Address", for every shipping type, including pickup, and apps can't change it. Your `localizedDescription` appears when the shopper taps the address, so word it to match your `shippingType`, for example "Store pickup isn't available for this address" for `.storePickup`.

Other PassKit errors you can return: `paymentShippingAddressInvalidError(withKey:localizedDescription:)`, `paymentBillingAddressInvalidError(withKey:localizedDescription:)` and `paymentContactInvalidError(withContactField:localizedDescription:)`. The SDK doesn't show a coupon field in the sheet, so coupon errors have nothing to mark. A field error only helps when the sheet collects that field, so ask for it in `requiredBillingContactFields` or `requiredShippingContactFields`. Errors that aren't PassKit payment errors are left out, and with none left the sheet behaves as for `.declined(message:)`. Objective-C: `[ApplePayPaymentDecision declinedWithMessage:@"…" errors:@[error]]`.

Return `.declined(message:)` only when your server knows the charge failed. When you don't know the outcome, return `.statusUnknown` (or throw, in Swift); the SDK closes the sheet straight away instead of waiting for `processPaymentTimeout`. Objective-C uses `ApplePayPaymentDecision.statusUnknown`.

**Saving the card without charging now** (free trial, card on file, orders you confirm later): retain the payment method on your server and return `.approved`. The sheet's success then means the card is saved.

**Threads.** The SDK calls `processPayment`, `signedAuth` and `prepareForPresentation` from a background task. A closure written inside a `@MainActor` type (a SwiftUI view, a view controller) inherits main-actor isolation; anywhere else it runs on a background thread, so wrap UI updates in `await MainActor.run { … }`. In Objective-C, the `processPaymentHandler:` and prepare-handler blocks are called on the main thread, and their `completion` may be called from any thread. Results from `subscribeToPaymentResults` and `paymentDelegate` arrive on the main thread.

<details>
<summary>What your closure receives, and what happens when your server is slow</summary>

| `ApplePayPaymentAuthorization` property | Meaning |
|---|---|
| `paymentMethodToken` | Spreedly payment method token to charge on your server |
| `isRecurring` | Whether the order used a recurring request (`false` for one-time) |
| `isMerchantToken` / `merchantTokenIdentifier` | Whether Apple issued a merchant token (MPAN) you can charge later, and its identifier |
| `vaultResult` | The full `PaymentResult` from Spreedly (card details, raw response) |

Two different timers are involved:

| Timer | Who sets it | What happens when it runs out |
|---|---|---|
| Apple's sheet, about **30 seconds** after Face ID | Apple (you can't change it) | Apple closes the sheet with its own "Payment Not Completed" message. The payment is **not** canceled: your server may still be charging the card |
| `processPaymentTimeout`, default **120 seconds** | You, on `ApplePayConfiguration` | The SDK stops waiting for your `processPayment` answer and reports "status unknown" |

What the shopper sees:

1. **Your server answers within about 30 seconds.** Apple's sheet shows success or failure. This is the normal case.
2. **Your server takes longer.** Apple closes the sheet. The SDK publishes `isPending == true`; cover the checkout with a blocking overlay and "Your payment is still being processed. Please don't pay again." (see [While a payment is pending](#while-a-payment-is-pending)). When your server answers, the SDK publishes the final success or failure.
3. **Your server hasn't answered within `processPaymentTimeout`, or your closure throws.** The SDK publishes a failure with `isStatusUnknown == true`. If Apple's sheet is still open, the SDK closes it so the shopper can't pay twice. An answer that arrives later is ignored by the SDK.

**Apple doesn't say why its sheet closed.** PassKit reports a closed sheet the same way whether the shopper canceled, Apple's time limit ran out, or the app went to the background. It gives no reason, no error code and no warning beforehand. The SDK works it out from where the payment was:

| The sheet closed… | The SDK publishes |
|---|---|
| Before the shopper authorized with Face ID, Touch ID or passcode | `isCanceled`. Nothing was sent anywhere |
| After authorizing, while Spreedly is still saving the payment (your `processPayment` hasn't started) | `isFailure` with "The Apple Pay sheet closed before the payment was sent. Nothing was charged; the shopper can try again." `processPayment` is never called, so nothing is charged and Apple's "Payment Not Completed" is accurate |
| After authorizing, while your `processPayment` is running | `isPending`, then the final success, failure or `isStatusUnknown`. The charge can't be stopped once it has started |
| After your `processPayment` answered | The final result |

There is no separate "timed out" flag, and none is needed: `isPending` is your signal that Apple's sheet closed while your charge was still running (usually its time limit, or the shopper leaving the app). It arrives right after Apple's message, so use it to show your confirmation screen. Keep your server's charge well under 20 seconds so this rarely happens.

Apple's "Payment Not Completed" text can't be changed, so say clearly in your app what's happening right after it, for example *"Your payment is still being processed. Please don't pay again."*, until the final result arrives.

If `processPaymentTimeout` runs out first, the SDK cancels the Swift task running your closure, so an in-flight `URLSession` request in it ends with a cancellation error. Your server may still finish the charge: read the order status from your server rather than treating that error as "not charged".

| `processPaymentTimeout` | Behavior |
|---|---|
| Not set | 120 seconds (`ApplePayConfiguration.defaultProcessPaymentTimeout`) |
| Below 30 seconds | Raised to 30 (`minimumProcessPaymentTimeout`), so the SDK never gives up before Apple's sheet timeout |

</details>

<a id="step-6--charge-the-token--your-server"></a>
### Step 6 — Charge the token · `Your server`

> **You'll need:** your Spreedly environment key and access secret, on your server only.

Your endpoint receives `authorization.paymentMethodToken` from step 5 and runs purchase (or authorize) on it with the amount from **your own order**, not from the app. Answer charged, declined, or unknown.

- Keep the call short (well under 20 seconds) so Apple's sheet rarely closes first, and set `processPaymentTimeout` comfortably above your normal response time.
- Make the charge idempotent, for example keyed by order ID, so a retry can never charge the same order twice.
- **Do not send `attempt_3dsecure`** for Apple Pay payment methods; the shopper already authenticated with Apple Pay. If your gateway ever returns a 3-D Secure challenge for an Apple Pay transaction, handle it with the same gateway-specific 3DS flow you use for cards.

<a id="recurring-payments"></a>
<a id="1-show-the-subscription-sheet"></a>
<a id="2-check-whether-the-token-can-be-renewed"></a>
### Step 7 — Subscriptions (optional) · `Your app`

**Skip this step if** you only take one-time payments.

The SDK shows Apple's subscription sheet and tokenizes the first payment. It does not schedule renewals: your server charges each renewal (step 8). Create the order from a `PKRecurringPaymentRequest`; Apple may issue a **merchant token** that can be charged later.

```swift
import PassKit
import SpreedlyApplePay

let monthly = PKRecurringPaymentSummaryItem(label: "Pro Plan", amount: NSDecimalNumber(string: "9.99"))
monthly.intervalUnit = .month

let order = ApplePayOrder(recurringPaymentRequest: PKRecurringPaymentRequest(
    paymentDescription: "Pro Plan subscription",
    regularBilling: monthly,
    managementURL: subscriptionManagementURL   // a page where the shopper manages the subscription
))

applePayConfig.buttonType = .subscribe   // match the button to the action
```

> **Important:** Use days, not weeks. Apple Pay doesn't accept week units (`.weekOfYear`, `.weekOfMonth`) for billing intervals and won't open the sheet. Express a week as `intervalUnit = .day` with `intervalCount = 7` (or `14` for every two weeks). The SDK checks this before opening the sheet and returns a failure that says which item uses weeks.

Check which token Apple issued inside `processPayment`, before you enrol the subscription. `authorization.isRecurring` and `authorization.isMerchantToken` tell you which one you got:

| Token | Issued when | Can you charge renewals with it? |
|---|---|---|
| **Merchant token** | The shopper's card network supports merchant tokens | Yes |
| **Device token** | Otherwise | No — merchant-initiated renewals may be declined |

<details>
<summary><b>Declining a device token in <code>processPayment</code></b></summary>

```swift
applePayWallet.processPayment = { authorization in
    guard authorization.isMerchantToken else {
        return .declined(message: "This card can't be used for subscriptions.")
    }
    // First charge: cardholder-initiated, recurring, retained for renewals.
    let charged = try await yourServer.startSubscription(paymentMethodToken: authorization.paymentMethodToken)
    return charged ? .approved : .declined(message: "Your card was declined.")
}
```

</details>

For a free trial with nothing to charge today, retain the payment method on your server and return `.approved`.

<details>
<summary>Subscription links, free trials, and checking the token from the result</summary>

**Subscription links** on `PKRecurringPaymentRequest`:

| Property | Required | What it is |
|---|---|---|
| `managementURL` | Yes | A page on your site where the shopper manages the subscription: view it, change the plan or payment method, or cancel. Apple links to it from the sheet and from Wallet. Apple only opens it; it never calls it |
| `tokenNotificationURL` | No | An endpoint on your server that Apple calls when the subscription's merchant token changes, for example when the shopper replaces the card or the token is suspended or deleted. Use it to pause or update the subscription before a renewal fails. Apple only sends these for merchant tokens |
| `billingAgreement` | No | The terms shown on the sheet before the shopper pays, for example "You'll be charged USD 9.99 every month until you cancel." |

```swift
let request = PKRecurringPaymentRequest(
    paymentDescription: "Pro Plan subscription",
    regularBilling: monthly,
    managementURL: URL(string: "https://yourstore.com/account/subscription")!
)
request.tokenNotificationURL = URL(string: "https://yourstore.com/apple-pay/token-updates")   // optional
request.billingAgreement = "You'll be charged USD 9.99 every month until you cancel."           // optional
```

**Free trial:** set a recurring item for the trial as `trialBilling`. The sheet shows the trial, then the plan, which starts when the trial ends.

```swift
let trialEnd = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

let trial = PKRecurringPaymentSummaryItem(label: "Free trial", amount: .zero)
trial.intervalUnit = .day
trial.intervalCount = 7          // one week
trial.endDate = trialEnd

monthly.startDate = trialEnd     // first paid month starts after the trial

let recurring = PKRecurringPaymentRequest(
    paymentDescription: "Pro Plan subscription",
    regularBilling: monthly,
    managementURL: subscriptionManagementURL
)
recurring.trialBilling = trial
let trialOrder = ApplePayOrder(recurringPaymentRequest: recurring)
```

**From the result** instead of `processPayment`:

```swift
// Keep the returned AnyCancellable (for example in a property); results stop when it's released.
resultSubscription = Spreedly.shared().subscribeToPaymentResults { result in
    guard result.isSuccess, let token = result.token else { return }
    if result.isApplePayMerchantToken {
        // Retain `token` and schedule renewals on your server.
    } else {
        // Device token: ask for the shopper's approval each billing cycle (Pattern B),
        // or offer a card that supports merchant tokens.
    }
}
```

`result.applePayMerchantTokenIdentifier` returns Apple's merchant token identifier, or `nil` for a device token. In Objective-C, use `result.isApplePayMerchantToken` and `result.applePayMerchantTokenIdentifier`.

</details>

<a id="3-charge-renewals-from-your-server"></a>
### Step 8 — Charge renewals (optional) · `Your server`

**Skip this step if** you only take one-time payments.

| Pattern | How it works | Use when |
|---|---|---|
| **A — Charge the saved token** | Retain the Spreedly payment method after the first payment, then purchase or authorize it on each billing date as a merchant-initiated transaction | You got a merchant token **and** your gateway supports Apple Pay recurring |
| **B — Ask each cycle** | Present the Apple Pay sheet again every billing period | You got a device token, or your gateway needs the shopper present for each charge |

<a id="stored-credential-fields"></a>
For Pattern A, your server sends the stored-credential fields below on each purchase or authorize.

<details>
<summary><b>Pattern A: supported gateways and required fields</b></summary>

- **Supported gateways:** Adyen, Braintree, Checkout.com, CyberSource, CyberSource REST, Stripe Payment Intents, and Worldpay. On other gateways the stored-credential fields are ignored and the charge is processed as a regular Apple Pay payment.
- **Send stored-credential fields** `stored_credential_initiator` and `stored_credential_reason_type` on each purchase or authorize (see below).
- **Retain the payment method** (for example with `retain_on_success` on the first purchase) so the token stays available for renewals.
- **Do not send `attempt_3dsecure`.** The shopper already authenticated with Apple Pay.

**Stored-credential fields**

Your server sends these two fields on the purchase or authorize request. The SDK does not send them; it only tokenizes the Apple Pay payment.

| Charge | Shopper present? | `stored_credential_initiator` | `stored_credential_reason_type` |
|---|---|---|---|
| First subscription payment (in the app) | Yes | `cardholder` | `recurring` |
| Each subscription renewal | No | `merchant` | `recurring` |

`cardholder` means the shopper started the charge; `merchant` means your server charged a saved payment method without the shopper. `recurring` is for charges on a fixed schedule.

</details>

<details>
<summary>Example renewal request</summary>

```bash
# Renewal: merchant-initiated, recurring (run on your server)
curl -X POST https://core.spreedly.com/v1/gateways/${GATEWAY_TOKEN}/purchase.json \
  -u ${ENVIRONMENT_KEY}:${ACCESS_SECRET} \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "payment_method_token": "ABC...payment_method_token",
      "amount": 999,
      "currency_code": "USD",
      "stored_credential_initiator": "merchant",
      "stored_credential_reason_type": "recurring"
    }
  }'
```

See [Spreedly's Apple Pay documentation](https://developer.spreedly.com/docs/apple-pay) and the [Stored Credentials guide](https://developer.spreedly.com/docs/stored-credentials) for the full server-side request fields.

</details>

<a id="testing-on-a-spreedly-test-gateway"></a>
### Try it in sandbox

Apple Pay can't produce test cards: the token always carries the card the shopper picked in Wallet, even an Apple sandbox card. A Spreedly Test gateway only accepts [Spreedly test cards](https://developer.spreedly.com/docs/test-data), so it declines every Apple Pay purchase. Set `testCardNumber` to a Spreedly test card: the SDK sends it with the Apple Pay token, and Spreedly stores the payment method with that card number instead of the Wallet card's, marked as a test card. Your server then charges it like any other payment method.

| Value | Use |
|---|---|
| `"4111 1111 1111 1111"` | Purchase succeeds on a Spreedly Test gateway |
| `"4012 8888 8888 1881"` | Purchase is declined on a Spreedly Test gateway |

```swift
// Testing builds only (Xcode, ad-hoc or TestFlight). Drive it from your own test configuration.
applePayConfig.testCardNumber = "4111 1111 1111 1111"
```

```objc
applePayConfig.testCardNumber = @"4111 1111 1111 1111";   // testing builds only
```

- **Any card in Wallet works.** The card the shopper picks only gets through Apple Pay; the test card decides the outcome.
- **Testing only.** It replaces the shopper's card, so the SDK allows it only in apps installed from Xcode, an ad-hoc build or TestFlight. In an App Store or enterprise (in-house) install the checkout fails before the sheet opens with "Apple Pay testCardNumber is for testing only…". Remove it before release.
- **Format.** A valid card number: 12 to 19 digits of a supported card brand that passes the card number checksum; spaces are ignored. Anything else fails the checkout before the sheet opens, because Spreedly would reject it ("Number is invalid", "Card type is invalid") only after the shopper authorized.
- **Real gateways.** Leave it unset. A real gateway needs the Wallet card and Apple's one-time cryptogram.
- **Still needs a device.** The Simulator can show the sheet but never returns a payment token. See [Testing Guide](testing-guide.md).

---

## 6. Integration by platform

The same steps wired into each UI stack. Read only your own.

<a id="swiftui-integration"></a>
### SwiftUI

```swift
import Combine
import SpreedlyCore
import SpreedlyUI
import SpreedlyApplePay
import SwiftUI

struct CheckoutView: View {
    @State private var cancellable: AnyCancellable?
    @State private var status = ""

    private let applePayConfig: ApplePayConfiguration = {
        let config = ApplePayConfiguration(
            merchantIdentifier: "merchant.com.example.store",
            countryCode: "US",
            currencyCode: "USD"
        )
        config.emptyWalletBehavior = .hide
        return config
    }()

    var body: some View {
        VStack(spacing: 16) {
            SpreedlyApplePayButton(
                configuration: applePayConfig,
                order: ApplePayOrder(label: "Your Store", amount: NSDecimalNumber(string: "19.99")),
                signedAuth: {
                    // Fresh signed auth from your server for every attempt; it signs this Apple Pay request only.
                    try await yourServer.freshSpreedlyAuth()
                },
                processPayment: { authorization in
                    // Your server runs purchase with the token; the sheet waits for this answer.
                    try await yourServer.charge(token: authorization.paymentMethodToken)
                        ? .approved : .declined(message: "Your card was declined.")
                }
            )
            .frame(height: 48)

            Text(status)
        }
        .onAppear {
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                if result.isSuccess {
                    status = "Paid"
                } else if result.isPending {
                    status = "Your payment is still being processed. Please don't pay again."
                } else if result.isCanceled {
                    status = "Canceled"
                } else {
                    // failureDetails can carry the shopper's name, email, phone and address:
                    // redact those before you log it.
                    status = "Payment failed. Try again or pay with a card."
                }
            }
        }
    }
}
```

`yourServer.freshSpreedlyAuth()` (returns a `SpreedlyConfig` with new signed auth) and `yourServer.charge(token:)` are your app's functions.

<a id="uikit-integration"></a>
### UIKit

<details>
<summary><b>Full UIKit implementation</b> — <code>SpreedlyApplePayButtonView</code> in a view controller</summary>

```swift
import Combine
import SpreedlyCore
import SpreedlyUI
import SpreedlyApplePay
import UIKit

final class CheckoutViewController: UIViewController {
    private var cancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = ApplePayConfiguration(
            merchantIdentifier: "merchant.com.example.store",
            countryCode: "US",
            currencyCode: "USD"
        )
        let button = SpreedlyApplePayButtonView(
            configuration: config,
            order: ApplePayOrder(label: "Your Store", amount: NSDecimalNumber(string: "19.99")),
            signedAuth: { try await yourServer.freshSpreedlyAuth() },
            processPayment: { authorization in
                try await yourServer.charge(token: authorization.paymentMethodToken)
                    ? .approved : .declined(message: "Your card was declined.")
            }
        )

        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            button.heightAnchor.constraint(equalToConstant: 48)
        ])

        cancellable = Spreedly.shared().subscribeToPaymentResults { result in
            // Same handling as card checkout.
        }
    }
}
```

</details>

The view sets `isHidden = true` when there is nothing to show, so it collapses inside a `UIStackView`. Update `button.order` when the cart changes.

<a id="objective-c-integration"></a>
### Objective-C

`initWithConfiguration:order:signedAuthHandler:processPaymentHandler:` takes two blocks. `signedAuthHandler` calls `completion` exactly once with a `SpreedlyConfig` holding fresh signed auth from your server (or an error), for every payment attempt. `processPaymentHandler` calls `completion` exactly once with `ApplePayPaymentDecision.approved`, `[ApplePayPaymentDecision declinedWithMessage:]`, `[ApplePayPaymentDecision declinedWithMessage:errors:]` or `ApplePayPaymentDecision.statusUnknown`.

<details>
<summary><b>Full Objective-C implementation</b> — configuration, button view, <code>SpreedlyPaymentDelegate</code></summary>

```objc
@import SpreedlyCore;
@import SpreedlyUI;
@import SpreedlyApplePay;
@import PassKit;

@interface CheckoutViewController () <SpreedlyPaymentDelegate>
@end

@implementation CheckoutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Spreedly shared].paymentDelegate = self;

    ApplePayConfiguration *config =
        [[ApplePayConfiguration alloc] initWithMerchantIdentifier:@"merchant.com.example.store"
                                                      countryCode:@"US"
                                                     currencyCode:@"USD"];
    config.emptyWalletBehavior = ApplePayEmptyWalletBehaviorHide;

    ApplePayOrder *order =
        [[ApplePayOrder alloc] initWithLabel:@"Your Store"
                                      amount:[NSDecimalNumber decimalNumberWithString:@"19.99"]];

    // Charge on your server before the sheet completes. Call completion exactly once.
    SpreedlyApplePayButtonView *button =
        [[SpreedlyApplePayButtonView alloc] initWithConfiguration:config
                                                            order:order
                                                signedAuthHandler:^(void (^completion)(SpreedlyConfig *, NSError *)) {
        // Fresh signed auth from your server for every attempt.
        [self.server fetchSpreedlyAuth:completion];
    }
                                            processPaymentHandler:^(ApplePayPaymentAuthorization *authorization,
                                                                    void (^completion)(ApplePayPaymentDecision *)) {
        [self.server chargeToken:authorization.paymentMethodToken completion:^(BOOL charged, NSError *error) {
            if (error) {
                // No answer from your server (for example the connection dropped): the charge may
                // still go through, so close the sheet without offering another try.
                completion(ApplePayPaymentDecision.statusUnknown);
                return;
            }
            completion(charged ? ApplePayPaymentDecision.approved
                               : [ApplePayPaymentDecision declinedWithMessage:@"Your card was declined."]);
        }];
    }];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.leadingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.leadingAnchor],
        [button.trailingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.trailingAnchor],
        [button.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [button.heightAnchor constraintEqualToConstant:48]
    ]];
}

- (void)paymentDidComplete:(PaymentResult *)result {
    // Same handling as card checkout; result.isCanceled when the shopper closed the sheet.
    // result.isPending → show "Your payment is still being processed. Please don't pay again."; a final result follows.
}

@end
```

</details>

<a id="card-form-drop-in-with-apple-pay"></a>
### Card drop-in

Show Apple Pay at the top of the card form sheet, followed by an "or pay with card" divider and the card fields. Pass a `SpreedlyApplePayWallet` to the drop-in; nothing else changes in your card integration.

> **Swift Package Manager only:** `walletButtons` is part of `SpreedlyUI`, so it's there in CocoaPods installs too, but `SpreedlyApplePayWallet` comes from `SpreedlyApplePay`, which ships through Swift Package Manager only. With CocoaPods, leave `walletButtons` empty and the drop-in looks and works as before.

```
┌───────────────────────────────┐
│          Pay                  │  ← Apple Pay button
│  ──────  or pay with card ─── │  ← divider
│  First name     Last name     │
│  Card number                  │  ← existing card form
│  …                            │
│  [ PAY NOW ]                  │
└───────────────────────────────┘
```

**SwiftUI**

```swift
let applePay = SpreedlyApplePayWallet(
    configuration: applePayConfig,
    order: ApplePayOrder(label: "Your Store", amount: NSDecimalNumber(string: "19.99")),
    signedAuth: { try await yourServer.freshSpreedlyAuth() },   // its own auth: the card form keeps yours
    processPayment: { authorization in
        try await yourServer.charge(token: authorization.paymentMethodToken)
            ? .approved : .declined(message: "Your card was declined.")
    }
)

struct DropInCheckoutView: View {
    let applePay: SpreedlyApplePayWallet
    @State private var showForm = false

    var body: some View {
        Button("Pay") { showForm = true }
            .sheet(isPresented: $showForm) {
                CardFormDropIn(
                    walletButtons: [applePay],
                    onProcessingResult: { _ in }
                )
            }
    }
}
```

<details>
<summary><b>UIKit / Objective-C drop-in</b></summary>

```objc
// config and order are built as in the Objective-C section above.
SpreedlyApplePayWallet *applePayWallet =
    [[SpreedlyApplePayWallet alloc] initWithConfiguration:config
                                                    order:order
                                        signedAuthHandler:^(void (^completion)(SpreedlyConfig *, NSError *)) {
        // Fresh signed auth from your server for every attempt, then call completion exactly once.
    }
                                    processPaymentHandler:^(ApplePayPaymentAuthorization *authorization,
                                                            void (^completion)(ApplePayPaymentDecision *)) {
        // Charge authorization.paymentMethodToken on your server, then call completion exactly once.
    }];

CardFormDropInViewController *dropIn = [[CardFormDropInViewController alloc]
    initWithOtherFields:@[]
    yearFormat:YearFormatFourDigit
    nameDisplayMode:DropInNameDisplayModeSeparateFields
    onProcessingResult:nil];
dropIn.walletButtons = @[applePayWallet];
[self presentViewController:dropIn animated:YES completion:nil];
```

</details>

| Option | SwiftUI | UIKit / Objective-C | Default |
|---|---|---|---|
| Wallets (display order) | `walletButtons: [applePay]` | `walletButtons` | none |
| Divider label | `walletButtonDividerText:` | `walletButtonDividerText` | "or pay with card" (English) |
| Close the drop-in after a successful wallet payment | `dismissOnWalletButtonSuccess:` | `dismissOnWalletButtonSuccess` | `true` |

- If Apple Pay can't be offered (unsupported device, or an empty Wallet with `.hide`), the button **and** the divider are hidden and the sheet looks the same as without wallets.
- Wallet availability is re-checked when the app returns to the foreground, e.g. after the shopper adds a card in Wallet.
- Apple Pay and card results both arrive on `subscribeToPaymentResults` / `paymentDelegate`. A canceled or failed Apple Pay payment leaves the drop-in open so the shopper can pay by card.
- If Apple closes the sheet before your server answers, the drop-in shows "Your payment is still being processed. Please don't pay again.", disables card Pay, and can't be swiped down until the final result arrives.
- Set wallets on `CardFormDropInViewController` before presenting it.
- A failed Apple Pay payment shows a short shopper message in the drop-in ("Your payment couldn't be completed…", or "We couldn't confirm your payment…" for `isStatusUnknown`). The detailed reason stays in `failureDetails` for you.
- After "We couldn't confirm your payment…" the drop-in stays locked: card Pay and Apple Pay do nothing until you close it, because the first charge may have gone through. Check the order on your server before offering checkout again.
- Only one payment runs at a time, across every drop-in and Apple Pay button in your app. From the Apple Pay tap until its final result (including while your `prepareForPresentation` runs), card Pay and the keyboard's return on the last field do nothing; while a card is being saved, Apple Pay taps are ignored. Closing a drop-in doesn't end its payment: a drop-in opened afterwards stays blocked until that payment's result arrives.
- Building your own container for wallet buttons? Read the outcome on `subscribeToPaymentResults` / `paymentDelegate` (`isPending` first when the sheet closes early).

**Messages the drop-in shows for Apple Pay.** The divider label is the only text you can set. The other messages are fixed by the SDK and English only for now. For every result and its `failureDetails.message`, see [Errors and troubleshooting](#8-errors-and-troubleshooting).

| Text shown in the drop-in | Shown for | What it means | Charged? | Can you change it? |
|---|---|---|---|---|
| "or pay with card" | The divider between Apple Pay and the card fields | — | — | Yes: `walletButtonDividerText` |
| "Your payment is still being processed. Please don't pay again." (with a spinner) | `isPending` | Apple's sheet closed while your `processPayment` was still charging. The drop-in can't be swiped away and card **Pay** is disabled until the final result arrives | Not known yet | No |
| "Your payment couldn't be completed. Try again, or pay with a card below." | `isFailure`, except status unknown | The payment ended without a charge: your server declined it, Spreedly couldn't save it, or Apple's sheet closed before the charge started. The shopper can try again or pay by card | No | No |
| "We couldn't confirm your payment. Check your order before paying again." | `isFailure` + `isStatusUnknown` | Your `processPayment` returned `.statusUnknown`, threw, or didn't answer within `processPaymentTimeout`. The charge may have gone through | Maybe: check the order on your server | No |

Your `.declined(message:)` text isn't shown in the drop-in. It goes to Apple's sheet, which may show it or its own text, and to `failureDetails.message`. To use your own wording or language everywhere, put the Apple Pay button on your own screen ([Integration by platform](#6-integration-by-platform)) and show your own text for each result.

---

<a id="result-states"></a>
## 7. Handle the result

| Result | Meaning | What to show the user |
|---|---|---|
| `isSuccess` + `token` | Your `processPayment` returned `.approved` | Your receipt |
| `isPending` | Apple closed the sheet while your `processPayment` was running | A blocking overlay with "Your payment is still being processed. Please don't pay again." until the final result; see [While a payment is pending](#while-a-payment-is-pending) |
| `isFailure` | Tokenization failed, `processPayment` declined, SDK not configured, invalid configuration, device blocked, or the sheet could not open | Your own failure message; offer card checkout. If you log `failureDetails`, redact the shopper's contact details first: Spreedly's text can echo them |
| `isFailure` + `isStatusUnknown` | `processPayment` returned `.statusUnknown`, threw, or did not answer within `processPaymentTimeout` | Check the order on your server before asking the shopper to pay again |
| `isCanceled` | Shopper closed the sheet before authorizing, or `prepareForPresentation` returned `false` | Return to checkout; no message needed |

Handle all five states. Code that treats anything other than `isSuccess` as an error would show an error for `isPending`.

> **Important:** Fulfil the order from **your server's** charge result, not from the SDK result alone. No later server-to-server notification arrives in this flow: your charge endpoint (step 6) is the source of truth for whether the money moved. "Status unknown" means the SDK stopped waiting, not that the payment failed.

**Handling "status unknown":**

- Don't let the shopper pay again straight away. Show "We're confirming your payment" and check the order's status on your server.
- Make your charge idempotent, for example keyed by order ID, so a retry can never charge the same order twice.
- Let the shopper know the outcome once your server has it, on the order screen or by email or notification.

---

<a id="troubleshooting"></a>
## 8. Errors and troubleshooting

**Results you handle in code.** `failureDetails?.message` carries the text shown here. These SDK texts are written for you and your logs, not for shoppers; the only shopper text among them is your own `.declined(message:)`. On your own screens, map each result to your own wording.

| Result and message | When | Was the card charged? | What to do |
|---|---|---|---|
| `isFailure`: your `.declined(message:)` text, or "The payment was declined." when it's empty | Your `processPayment` returned `.declined` | No. Spreedly had already saved the payment method, so a token exists, but your server didn't charge it | Show the message; let the shopper try another card, or change the detail you marked with `.declined(message:errors:)` |
| Configuration error: "Apple Pay billingContact needs .postalAddress in requiredBillingContactFields…" | `billingContact` is set but the sheet doesn't ask for a billing address | No; the sheet didn't open | Add `.postalAddress` to `requiredBillingContactFields`, or remove `billingContact` |
| Configuration error: "Apple Pay shippingContact needs requiredShippingContactFields…" | `shippingContact` is set but the sheet doesn't ask for any shipping field | No; the sheet didn't open | Set `requiredShippingContactFields`, or remove `shippingContact` |
| `isFailure` + `isStatusUnknown`: "processPayment could not confirm the charge. It may still go through…" | Your `processPayment` returned `.statusUnknown` | Maybe | Check the order on your server before asking the shopper to pay again |
| `isFailure` + `isStatusUnknown`: "processPayment threw before returning a decision. The charge may still go through…" | Your `processPayment` threw (for example the connection dropped) | Maybe | Same as above |
| `isFailure` + `isStatusUnknown`: "The payment could not be confirmed in time…" | No answer within `processPaymentTimeout` | Maybe | Same as above; raise `processPaymentTimeout` if your backend is legitimately slow |
| `isPending` | Apple's sheet closed while your `processPayment` was running | Not yet known | Show a blocking overlay until the final result; see [While a payment is pending](#while-a-payment-is-pending) |
| `isFailure`: "The Apple Pay sheet closed before the payment was sent. Nothing was charged; the shopper can try again." | Apple's sheet closed while Spreedly was still saving the payment, before your `processPayment` started | No | Let the shopper tap Apple Pay again or pay by card |
| `isCanceled` | The shopper closed the sheet before authorizing, or `prepareForPresentation` returned `false` | No | Return to checkout |
| `isFailure` with `failureDetails.validationErrors` | Spreedly rejected the Apple Pay payment; each entry names the field, and `failureDetails.message` carries Spreedly's own text (e.g. "Number is invalid") | No | Log the details; show your own failure message and offer card checkout |
| `isFailure`: "Apple Pay could not be saved: no payment method token was returned." | Spreedly answered without a token | No | Let the shopper try again or pay by card |
| `isFailure` with "Spreedly is not configured…" | `Spreedly.setup(config:)` wasn't called before the checkout | No | Call `Spreedly.setup(config:)` with your environment key first |
| `isFailure` with a configuration message | Invalid `ApplePayConfiguration` or order (see below) | No | Fix the value named in the message |
| `isFailure`: "SDK blocked by security check…" | Device blocked by `blockJailbrokenDevices` | No | See [Blocked devices](#blocked-devices) |

**Problems you hit while integrating**

| Symptom | Cause | Fix |
|---|---|---|
| Button never appears | Device or region does not support Apple Pay, or `emptyWalletBehavior` is `.hide` and Wallet is empty | Check `SpreedlyApplePayWallet.availability(for:)` |
| Failure: merchant identifier / country / currency message | Invalid `ApplePayConfiguration` values | Fix them |
| Failure: "Apple Pay configuration needs at least one supported network." | `supportedNetworks` is empty. An empty list means no network, not all of them | Set at least one network, or leave the default |
| Failure: "Apple Pay total must be zero or more…" or "Apple Pay amount for "…" is not a number." | Negative or non-numeric order total | Fix the order total |
| Failure: "Apple Pay sheet could not be presented." | Merchant ID missing from the app's Apple Pay capability (`com.apple.developer.in-app-payments` entitlement), a provisioning profile created before the capability was enabled, or another sheet is already presented | See [Configure your app](#4-configure-your-app) |
| Sheet shows failure after Face ID, failure with a network error | The device lost its connection while Spreedly vaulted the payment | Nothing was charged; the shopper can try again |
| Sheet shows failure after Face ID | Spreedly could not decrypt or vault the payment | Confirm the Payment Processing Certificate for this Merchant ID is uploaded to Spreedly |
| Failure: "Apple Pay did not return a payment token…" | Simulator (or a placeholder merchant ID) authorized Wallet but Apple sent no token. Apple's sheet shows its own failure text; this message is in `failureDetails` | Test on a physical device with a real Merchant ID |
| Failure: "prepareForPresentation did not finish in time…" | Your `prepareForPresentation` took longer than 30 seconds | Make it fail fast; the next tap starts a fresh checkout |
| Failure: "signedAuth didn't return usable Spreedly auth within 30 seconds…" | Your `signedAuth` threw, took longer than 30 seconds, or returned auth missing a field, minted for another environment key, or the same auth you passed to `Spreedly.setup(config:)`. Nothing was sent | Mint fresh auth on your server for every call, with the same environment key as `Spreedly.setup(config:)`; see [Signed auth for each attempt](#retry-auth) |
| Failure with "The nonce has already been used" (`errors.replayed_tokenization_nonce` in `validationErrors`) | A request reused signed auth Spreedly had already seen, for example a card retry after a failed card payment | After a failed payment, get new auth from your server and call `Spreedly.setup(config:)` before the shopper pays by card again. Apple Pay brings its own auth for every attempt |
| Works in Simulator, no real token | Real Apple Pay tokens need a physical device | Use a device with a sandbox tester and test card |
| Apple shows "Payment Not Completed", then the payment succeeds | Your `processPayment` took longer than Apple's sheet allows (about 30 seconds) | Handle `isPending`, then the final result; speed up the server call |
| Every purchase declined on a Spreedly Test gateway ("Unable to process the purchase transaction.") | The Wallet card isn't a Spreedly test card | Set `testCardNumber`, see [Try it in sandbox](#testing-on-a-spreedly-test-gateway) |
| Failure: "Apple Pay testCardNumber must be a valid card number…" or "…is for testing only…" | Not a valid card number (wrong length, unknown brand or a typo), or an App Store / enterprise install | Use a [Spreedly test card](https://developer.spreedly.com/docs/test-data), or remove `testCardNumber` from App Store builds |
| Recurring checkout always declined in `processPayment` | Apple issued a device token. Apple's sandbox may not issue merchant tokens | Test merchant tokens with a production card |

Broader error model: [Error Handling](error-handling.md).

---

<a id="important-notes"></a>
## 9. Edge cases and cleanup

### Blocked devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK blocks Apple Pay automatically. The Apple Pay and Set Up buttons are hidden (in the card drop-in, together with the divider), no sheet opens, and nothing is sent to Spreedly. See [Security — Runtime Integrity](security.md#runtime-integrity) for details.

### One checkout at a time, one vault attempt

- **One sheet at a time.** While a checkout is running (the sheet is open, or a payment is still being confirmed), a tap on any Apple Pay button the SDK shows starts nothing. The button keeps its normal look, because Apple's guidelines don't allow making it appear unavailable; show "Your payment is still being processed. Please don't pay again." on `isPending` so the shopper knows why.
- **One vault attempt.** The SDK sends the authorized payment to Spreedly once and never retries it; a network failure ends the checkout with a failure, and nothing was charged.
- **Amounts are yours.** The total on the sheet comes from your `ApplePayOrder`; charge the same total on your server.
- **No card data in your app.** The SDK never logs or stores the Apple Pay payment data; it is sent once to Spreedly and the SDK doesn't keep it after the request.
- **Official button only.** Apple's guidelines require the PassKit button; the SDK uses it in every mode.
- **Screen protection.** With screen protection on (`.screenPrevention()`, or the card drop-in, which has it built in), the SDK blurs your app whenever it becomes inactive, and opening Apple's sheet makes it inactive. So the area behind the Apple Pay sheet shows a blur instead of your checkout. This is expected and doesn't affect the payment.

### App goes to the background during a payment

iOS closes Apple's sheet when the shopper leaves your app: opening the notification drawer, switching apps, or going to the Home Screen.

| When the shopper leaves | What the SDK publishes |
|---|---|
| Before authorizing with Face ID, Touch ID or passcode | `isCanceled`. Nothing was sent to Spreedly or your server |
| After authorizing, while Spreedly is still saving the payment | `isFailure`: the SDK doesn't start your `processPayment`, so nothing is charged and the shopper can try again |
| After authorizing, while your `processPayment` is running | `isPending` straight away, then the final success, failure or `isStatusUnknown` once it finishes. It's never reported as a cancel |

The SDK asks iOS for extra time to finish the vault and your `processPayment` call in the background. If iOS suspends the app before they finish, the final result is published when the shopper comes back. It can be `isStatusUnknown` if your server call was cut off, even though your server may have charged. If iOS ends the app, no final result reaches the app.

- **Keep listening for results** somewhere that outlives navigation, such as a screen or object that stays alive for the whole checkout. A view that unsubscribes when it disappears misses the final result.
- **Block the screen while the payment is pending.** When your app becomes active again, keep the checkout screen in place and cover it with a dimmed overlay until the final result arrives. See [While a payment is pending](#while-a-payment-is-pending).
- **SwiftUI: use `NavigationStack`.** The older `NavigationView` can drop the open checkout screen back to its parent when the app goes to the background, because iOS redraws the app for the app switcher. `NavigationStack` (iOS 16+) keeps it.
- **Your server decides.** If the app was ended, or the result is `isStatusUnknown`, look up the order on your server before asking the shopper to pay again.

<a id="while-a-payment-is-pending"></a>
### While a payment is pending

`isPending` means Apple's sheet has closed (its time limit, or the shopper left the app) while your `processPayment` is still charging. The final result follows. Until it arrives, the shopper mustn't leave the checkout or pay again, because the charge may still go through.

> **Important:** On `isPending`, cover your checkout with a full-screen overlay that blocks every tap, and keep it until the final success, failure or `isStatusUnknown` result. Navigating away, closing the screen, or offering another payment method at this point can lead to a double charge.

| Do | Why |
|---|---|
| Dim the screen and show a spinner with "Your payment is still being processed. Please don't pay again." | Apple's sheet just said "Payment Not Completed"; this tells the shopper it's still in progress |
| Block taps underneath, hide the back button, and stop the screen from being swiped or closed | The shopper can't navigate away or start a second payment |
| Announce the message to VoiceOver | VoiceOver users get the same information |
| Keep the result listener alive and remove the overlay on the final result | Then show your receipt, the error, or "check your order" for `isStatusUnknown` |

**SwiftUI**

```swift
import Combine
import SpreedlyCore
import SwiftUI

struct CheckoutScreen: View {
    @State private var isPaymentPending = false
    @State private var cancellable: AnyCancellable?

    var body: some View {
        YourCheckoutContent()                         // your checkout, including the Apple Pay button
            .disabled(isPaymentPending)
            .navigationBarBackButtonHidden(isPaymentPending)
            .interactiveDismissDisabled(isPaymentPending)
            .overlay {
                if isPaymentPending {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Your payment is still being processed. Please don't pay again.")
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(32)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .onAppear {
                cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                    isPaymentPending = result.isPending
                    // On the final result, show your receipt, the error, or "check your order".
                }
            }
    }
}
```

<details>
<summary><b>UIKit</b> — an overlay on the window</summary>

```swift
private var pendingOverlay: UIView?

private func showPendingOverlay() {
    guard pendingOverlay == nil, let window = view.window else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)

    let spinner = UIActivityIndicatorView(style: .large)
    spinner.startAnimating()
    let label = UILabel()
    label.text = "Your payment is still being processed. Please don't pay again."
    label.numberOfLines = 0
    label.textAlignment = .center
    label.textColor = .white
    label.font = .preferredFont(forTextStyle: .body)
    label.adjustsFontForContentSizeCategory = true

    let stack = UIStackView(arrangedSubviews: [spinner, label])
    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    overlay.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        stack.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 32),
        stack.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -32)
    ])

    window.addSubview(overlay)                       // covers the navigation bar too
    isModalInPresentation = true                     // a presented checkout can't be swiped away
    pendingOverlay = overlay
    UIAccessibility.post(notification: .announcement, argument: label.text)
}

private func hidePendingOverlay() {
    pendingOverlay?.removeFromSuperview()
    pendingOverlay = nil
    isModalInPresentation = false
}

// In your SpreedlyPaymentDelegate / subscribeToPaymentResults handler:
// result.isPending ? showPendingOverlay() : hidePendingOverlay()
```

</details>

**Card drop-in:** while the payment is pending it does this for you. It shows the spinner and this message, disables card **Pay**, and can't be swiped down (SwiftUI and UIKit) until the final result. If you wrap the drop-in in your own container (for example a navigation controller with a close button), disable that close button on `isPending` too, and keep a result listener outside the drop-in.

<a id="app-store-privacy-label"></a>
### App Store privacy label

Your app's privacy label in App Store Connect describes what **your app** collects, including data that Spreedly processes on your behalf. `SpreedlyCore`'s privacy manifest declares the data types the SDK sends for Apple Pay, but completing your label is still up to you.

<details>
<summary>What Apple Pay adds to your privacy label</summary>

| What you set | Sent to Spreedly | Privacy label category |
|---|---|---|
| Any Apple Pay payment | The encrypted Apple Pay payment. Never the card number | Financial Info → Payment Info (see note below) |
| `requiredBillingContactFields` / `requiredShippingContactFields` with `.name` | Name | Contact Info → Name |
| … with `.emailAddress` | Email | Contact Info → Email Address |
| … with `.phoneNumber` | Phone number | Contact Info → Phone Number |
| … with `.postalAddress` | Billing or delivery address | Contact Info → Physical Address |
| `metadata` | Whatever you put in it | Depends on the content. Avoid putting personal data here |

- **Purpose:** declare these under **App Functionality** (processing the payment and delivering the order).
- **Linked to the shopper:** contact details are normally linked to the shopper's order or account, so mark them as linked to the user.
- **Not used for tracking:** the SDK doesn't use this data for tracking or advertising.
- **Payment Info:** the card number stays encrypted, and neither your app nor the SDK can read it. Because your app still passes the encrypted payment to Spreedly, most apps declare Payment Info. Confirm the final answer with your privacy or legal team.
- **Ask only for what you need.** Every contact field you request adds a line to your privacy label. If you only ship digital goods, you may not need an address at all.
- **Telemetry:** Apple Pay telemetry records event names, whether the order is a subscription (`total_price_status`: `recurring` or `FINAL`), the currency code, the button type, success, duration, and whether a merchant token was issued. It never includes contact details, amounts, or payment data. See [Privacy and Data Handling](privacy.md).

</details>

<a id="before-going-live"></a>
### Before going live

| Item | What to verify |
|---|---|
| Merchant ID and entitlement | The production app's `com.apple.developer.in-app-payments` entitlement contains the Merchant ID passed to `ApplePayConfiguration` |
| Processing certificate | A Payment Processing Certificate for that Merchant ID, created from a Spreedly certificate signing request, is uploaded to Spreedly, and its expiry date is tracked |
| `processPayment` | Charges the token on your server and returns `.approved`, `.declined(message:)`, `.declined(message:errors:)` or `.statusUnknown`; your server is the source of truth for the order |
| `testCardNumber` | Unset in App Store builds (the SDK refuses it there) |
| Result handling | `isSuccess`, `isPending`, `isFailure` (including `isStatusUnknown`) and `isCanceled` are all handled; see [Handle the result](#result-states) |
| Real device | One real payment completed on a physical device with the production Merchant ID |
| Privacy label | App Store privacy answers cover the contact fields you request; see [App Store privacy label](#app-store-privacy-label) |

### Cleanup

Keep the `AnyCancellable` from `subscribeToPaymentResults` for as long as you need results, and release it when the screen goes away. The SDK releases the checkout itself once it publishes the final result, so there's nothing else to tear down.

---

<a id="sdk-methods"></a>
## 10. API at a glance

| API | Module | Purpose |
|---|---|---|
| `Spreedly.setup(config:)` | `SpreedlyCore` | SDK setup with your environment key (and signed auth for the card form) |
| `signedAuth` / `signedAuthHandler:` | `SpreedlyApplePay` | Required: fresh signed auth for each Apple Pay attempt |
| `ApplePayConfiguration` | `SpreedlyApplePay` | Merchant ID, country, currency, networks, contact fields, saved contacts, shipping type, button look, empty-Wallet behavior |
| `ApplePayOrder` | `SpreedlyApplePay` | One-time total, or a subscription from a recurring request |
| `SpreedlyApplePayButton` | `SpreedlyApplePay` | SwiftUI button + sheet |
| `SpreedlyApplePayButtonView` | `SpreedlyApplePay` | UIKit / Objective-C button + sheet |
| `processPayment` / `processPaymentHandler:` | `SpreedlyApplePay` | Required: charge on your server before the sheet completes |
| `ApplePayPaymentAuthorization` / `ApplePayPaymentDecision` | `SpreedlyApplePay` | What `processPayment` receives / returns (`.approved`, `.declined(message:)`, `.declined(message:errors:)`, `.statusUnknown`) |
| `SpreedlyApplePaySetUpButton` / `SpreedlyApplePaySetUpButtonView` | `SpreedlyApplePay` | Standalone "Set Up Apple Pay" button (e.g. a settings screen) |
| `SpreedlyApplePayWallet` | `SpreedlyApplePay` | `WalletButtonProvider` for `CardFormDropIn(walletButtons:)` |
| `SpreedlyApplePayWallet.availability(for:)` | `SpreedlyApplePay` | `.unsupported` / `.needsSetup` / `.ready` |
| `SpreedlyApplePayWallet.openWalletSetup()` | `SpreedlyApplePay` | Opens Wallet card setup |
| `subscribeToPaymentResults` / `paymentDelegate` | `SpreedlyCore` | Result delivery |
| `CardFormDropIn(walletButtons:)` / `CardFormDropInViewController.walletButtons` | `SpreedlyUI` | Apple Pay + divider at the top of the card drop-in |

Objective-C selectors: [Objective-C](objective-c.md).

---

<a id="related-documentation"></a>
## 11. Related documentation

- [Getting Started](getting-started.md) — installation, signed auth and the SDK lifecycle
- [Custom Payment Forms](custom-payment-forms.md) — hosted card fields next to a standalone Apple Pay button
- [Error Handling](error-handling.md) — `PaymentResult` failure details
- [Testing Guide](testing-guide.md) — device and sandbox testing for every flow
- [Objective-C](objective-c.md) — Objective-C delegates
- [Security](security.md) — runtime integrity and screen prevention

