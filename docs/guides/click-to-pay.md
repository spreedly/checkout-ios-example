# Click to Pay — Spreedly iOS SDK

Let shoppers pay with cards already saved to the Mastercard SRC network, and tokenize the result
through Spreedly.

|  |  |
|---|---|
| **Use this when** | You want Click to Pay's saved-card wallet at checkout |
| **Use something else when** | Plain card entry → [Express checkout](express-checkout.md). Click to Pay is not a card form — a common pattern is two buttons side by side |
| **You build** | 2 things: a checkout screen · a backend charge call |
| **Modules** | `SpreedlyCore` + `SpreedlySecurity` + `SpreedlyUI` + `SpreedlyClickToPay` |
| **Requires** | SDK 1.6.0+ · iOS 16.0+ from 1.7.0 (iOS 14.0+ on 1.6.x) · Xcode 26.0+ |
| **Integration time** | ~20 minutes |
| **UI** | Spreedly sheet wrapping Mastercard widgets — SwiftUI · UIKit · Objective-C |

**Fast path:** [How it works](#1-how-it-works) → [What you need](#2-what-you-need) →
[Install](#3-install) → [Configure your app](#4-configure-your-app) →
[Build the flow](#5-build-the-flow) → [your platform](#6-integration-by-platform).

---

## 1. How it works

Two parts you build, plus a third the SDK runs for you.

| Part | Who builds it | Job |
|---|---|---|
| Checkout screen | **Your app** | Shows the Mastercard button, receives a `payment_method_token` |
| Charge call | **Your server** | Uses the token for `purchase` or `authorize` |
| Checkout sheet | **The SDK** | Loads Mastercard's script in a web view, runs lookup, OTP, and card selection, collects CVV in native fields, then tokenizes |

A single successful checkout:

1. The shopper taps the Mastercard button on your screen.
2. The SDK opens its sheet and loads Mastercard's script.
3. Mastercard looks the shopper up — `getCards` first, then `idLookup` when that is empty and a
   valid customer is configured. Phone lookup needs a country code.
4. A returning shopper picks a saved card; a new one enters a card in native Spreedly fields.
5. CVV is always collected in a native Spreedly field, never taken from Mastercard's payload.
6. On Mastercard `COMPLETE`, the SDK tokenizes with Spreedly and publishes a `PaymentResult`.
7. You send that token to your backend to charge.

> **Important:** CVV never appears on the event stream, and the SDK only tokenizes on `COMPLETE`.
> Every other Mastercard action code emits an event and resets the UI.

### Choose your integration path

| Path | You get | Pick this if |
|---|---|---|
| **Drop-in button** | `SpreedlyClickToPayButton` — Mastercard's own button, tap opens the sheet | Default. Matches the web integration |
| **Programmatic present** | Your button, the SDK's sheet | You need your own button styling or trigger |
| **Headless controller** | The web view host only; you build every screen | You have a design system that owns the whole checkout |

> **Important:** Click to Pay is for SRC wallet flows only. For standard card entry use
> [`CardFormDropIn`](express-checkout.md) or headless `createPaymentMethod` / `createCreditCard` —
> not a fallback inside the Click to Pay sheet. A common pattern is two buttons on checkout: `SpreedlyClickToPayButton` and
> **Pay with card**.

<details>
<summary><b>What the shopper sees</b> — the sheet's eight phases</summary>

| Phase | What the shopper sees |
|-------|-------------------------|
| Bootstrap | Centered loader while the Mastercard script loads |
| Identity lookup | Native email, phone, country code and **Look up** when no valid `customer` is configured |
| Auto lookup | Loader with optional email context when `customer` is prefilled |
| Saved cards | Mastercard card list with a pinned native CVV bar, optional native **Remember me** toggle when `otp.rememberMe` is enabled, and a pay button |
| OTP | Mastercard OTP widget with the shopper's **Remember me** checkbox; the choice is forwarded at checkout |
| New user | Native SPL card form (number → expiry → CVV → name), cardholder name prefilled from `tokenizeBilling` |
| Bank confirmation | Full-screen confirmation WebView |
| Tokenize | Processing loader while Spreedly tokenizes after Mastercard `COMPLETE` |

The sheet's navigation title is always the localized **Click to Pay** (`c2p_nav_default_title`);
`dpaPresentationName` names your store inside Mastercard's own UI. Headless integrators can mirror
these phases — the sheet is not required. Use `ClickToPayFlowState.checkoutTitle` for long-form
status copy in custom chrome.

</details>

**Working on only one part?** iOS → [step 3](#step-3--add-the-button--your-app) · Backend →
[step 5](#step-5--charge-the-token--your-server).

---

<a id="prerequisites"></a>
## 2. What you need

| Category | You need | Where to get it |
|---|---|---|
| Spreedly | Click to Pay enabled on your environment key | Contact Spreedly Support |
| Credentials | A sandbox or production `srcDpaId` (DPAID) | Contact Spreedly Support — there is no self-serve path |
| Your app | Mastercard SRC hosts allowed by App Transport Security | Your `Info.plist` — see [Configure your app](#4-configure-your-app) |
| Your app | A shopper first and last name available at checkout | Required at tokenize time. See [step 2](#step-2--build-the-config--your-app) |
| Your backend | An endpoint that charges a `payment_method_token` | See [step 5](#step-5--charge-the-token--your-server) |

> **Important:** the first name and last name requirement is the most common cause of a
> Click to Pay integration failing at the last step. Without them, tokenization fails with
> HTTP 422 after the shopper has already completed the entire Mastercard flow.

### Compatibility

| SDK version | iOS | Xcode | Notes |
|---|---|---|---|
| 1.7.0+ | **16.0+** | 26.0+ | — |
| 1.6.x | 14.0+ | 26.0+ | Click to Pay since 1.6.0. Last line that supports iOS 14 and 15 — see [Migrating to iOS 16](migration/v1-to-v2.md) |
| 1.5.x and earlier | — | — | **No Click to Pay module.** Upgrade to 1.6.0+ |

Assumed done: [Getting Started](getting-started.md) — installation plus `Spreedly.initializeSDK()`
at launch and `Spreedly.setup(config:)` with a signed bundle from your server.

---

## 3. Install

> **You'll need:** the latest tag from
> [checkout-ios-package](https://github.com/spreedly/checkout-ios-package/releases). Use one
> version for every Spreedly module in your app.

`SpreedlyClickToPay` is optional — add it only if you use Click to Pay. It requires `SpreedlyCore`,
`SpreedlySecurity`, and `SpreedlyUI` at the same version.

**Swift Package Manager**

```swift
dependencies: [
    .package(url: "https://github.com/spreedly/checkout-ios-package", from: "1.7.0")  // use the latest release tag
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SpreedlyCore", package: "checkout-ios-package"),
            .product(name: "SpreedlySecurity", package: "checkout-ios-package"),
            .product(name: "SpreedlyUI", package: "checkout-ios-package"),
            .product(name: "SpreedlyClickToPay", package: "checkout-ios-package"),
        ]
    )
]
```

**CocoaPods**

```ruby
pod 'SpreedlyCore',       '~> 1.7'
pod 'SpreedlySecurity',   '~> 1.7'
pod 'SpreedlyUI',         '~> 1.7'
pod 'SpreedlyClickToPay', '~> 1.7'
```

No `post_install` block is needed — unlike [Stripe APM](stripe-apm.md).

---

## 4. Configure your app

> **You'll need:** to know whether you are integrating against sandbox or production.

Mastercard's widgets load in a web view, so App Transport Security has to allow their hosts.

| Key | Value | Why | Required |
|---|---|---|---|
| `NSAppTransportSecurity` → `sandbox.src.mastercard.com` | Exception domain | Sandbox widgets fail to load without it | Only while `isSandbox` is `true` |
| `NSAppTransportSecurity` → `src.mastercard.com` | Exception domain | Production widgets | Yes, before go-live |

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>sandbox.src.mastercard.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <false/>
        </dict>
        <key>src.mastercard.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

> **Security:** this allows HTTPS to two named hosts. It does not disable ATS globally, and it
> should not — adjust to your own security policy, but do not reach for
> `NSAllowsArbitraryLoads`.

No URL scheme and no capability are needed. Click to Pay never leaves your app.

---

## 5. Build the flow

Five steps.

### Step 1 — Subscribe to results · `Your app`

```swift
cancellable = Spreedly.shared().subscribeToPaymentResults { result in
    if result.isSuccess, let token = result.token {
        // Send token to your backend — step 5
    } else if result.isFailure {
        // result.failureDetails?.getDescription()
    }
}
```

This is the **source of truth** for the outcome. The event stream in
[section 7](#7-handle-the-result) is for progress, not for the token.

### Step 2 — Build the config · `Your app`

> **You'll need:** your `srcDpaId`, and the shopper's first and last name.

```swift
var billing = ClickToPayTokenizeBilling()
billing.firstName = "Jane"          // required
billing.lastName  = "Doe"           // required
billing.email     = "shopper@example.com"

let config = ClickToPayCheckoutConfig(
    initConfig: ClickToPayInitConfig(amountCents: 9900, transactionCurrencyCode: "USD"),
    srcDpaId: "your-sandbox-or-production-dpaid",
    dpaPresentationName: "Your Store",
    customer: ClickToPayCustomer(email: "shopper@example.com"),
    tokenizeBilling: billing
)
```

Only four things matter to get started:

| Property | Required | Notes |
|---|---|---|
| `srcDpaId` | **Yes** | From Spreedly Support. Sandbox and production values differ |
| `tokenizeBilling.firstName` / `.lastName` | **Yes** | Tokenization fails without both |
| `initConfig` | No | Amount and currency for Mastercard. `amountCents:` converts for you |
| `customer` | No | Prefills lookup. Omit it and the sheet shows a native identity form instead |

<details>
<summary><b>Every <code>ClickToPayCheckoutConfig</code> property</b></summary>

| Property | Required | Default | Notes |
|---|---|---|---|
| `initConfig` | No | `ClickToPayInitConfig()` | Amount, currency, brands |
| `srcDpaId` | **Yes** | `""` | Sandbox or production DPAID |
| `locale` | No | `en_US` | Locale for Mastercard's widgets |
| `isSandbox` | No | `true` | Selects the Mastercard script host |
| `isTest` | No | `false` | Overrides `click_to_pay.test` on tokenize; otherwise follows `isSandbox` |
| `dpaPresentationName` / `dpaName` | No | sandbox strings | Shown inside Mastercard's UI. Does **not** change the native sheet title |
| `customer` | No | `nil` | Prefill for lookup |
| `doLookup` | No | `true` | Auto lookup after init |
| `displayCards` | No | `ClickToPayDisplayCardsConfig()` | Mastercard card-list chrome |
| `otp` | No | `ClickToPayOtpConfig()` | OTP and Remember me |
| `merchantHostedCardList` | No | `false` | `true` hands card selection to your UI |
| `tokenizeBilling` | See above | `nil` | First and last name required |
| `tokenizeMetadata` | No | `nil` | Payment-method metadata |
| `eligibleForCardUpdater` | No | `nil` | Swift only. Account Updater opt-in (`eligible_for_card_updater` on the wire) |

**`ClickToPayInitConfig`** — `transactionAmount` (major units, default `100`),
`transactionCurrencyCode` (`"USD"`), `dynamicDataType` (`"NONE"`),
`cardBrands` (defaults to all four networks).

**`ClickToPayCustomer`** — `email`, `phoneNumber`, `countryCode`, `mainLookupMethod`. Email **or**
phone plus country code is required for lookup. Helpers: `hasEmail()`, `hasPhoneLookup()`,
`isValidForLookup()`.

**`ClickToPayDisplayCardsConfig`** — `displaySignOut` (`true`), `displayAddCard` (`true`),
`displayPreferredCard` (`true`), `cardSelectionType` (`.radioButton` or `.gridView`).

**`ClickToPayOtpConfig`** — `rememberMe` (`false`), `presentation` (`.overlay`),
`channelSelection` (`.inline` or `.external`), `requestedValidationChannelId`.

**`ClickToPayTokenizeBilling`** — all properties are optional on the type, but `firstName` and
`lastName` are **required at tokenize time** for the default sheet. Only values you set are sent.

| Property | Notes |
|----------|-------|
| `firstName`, `lastName` | **Required** for auto-tokenize; prefill the native new-card name fields |
| `fullName`, `email`, `phoneNumber`, `company` | Optional |
| `month`, `year` | Optional expiry on the payment method |
| `addressLine1`, `addressLine2`, `city`, `state`, `zip`, `country` | Optional billing address |
| `shippingAddressLine1`, `shippingAddressLine2`, `shippingCity`, `shippingState`, `shippingZip`, `shippingCountry`, `shippingPhoneNumber` | Optional shipping |

Use `toBillingFields(fallbackEmail:)` → `ClickToPayBillingFields` for headless tokenize.

**`ClickToPayNewCardFields`** (headless new-card checkout only — the default sheet collects these
via native `SPLTextField`):

| Property | Required | Notes |
|----------|----------|-------|
| `primaryAccountNumber` | Yes | SPL-collected card number |
| `panExpirationMonth` | Yes | Two digits, `"01"`–`"12"` |
| `panExpirationYearTwoDigit` | Yes | **Two digits**, not four — `"29"`, not `"2029"` |
| `cardSecurityCode` | Yes | SPL-collected CVV |
| `cardholderFirstName`, `cardholderLastName` | Yes | Passed to `checkoutWithNewCard` |

All six are `let` on a public memberwise init, so build the value in one call:

```swift
let fields = ClickToPayNewCardFields(
    primaryAccountNumber: pan,
    panExpirationMonth: "09",
    panExpirationYearTwoDigit: "29",
    cardSecurityCode: cvv,
    cardholderFirstName: "Jane",
    cardholderLastName: "Doe"
)
```

</details>

### Step 3 — Add the button · `Your app`

```swift
SpreedlyClickToPayButton(checkoutConfig: config)
```

That is the whole integration. The button is Mastercard's own `<src-button>`; tapping it opens
the SDK's checkout sheet.

> **Gotcha:** if your app refreshes the signed `Spreedly.setup` config before checkout, use
> `SpreedlyClickToPayButton.prepareForPresentation` to run that refresh before the sheet opens —
> or refresh in `onAppear` before the shopper taps.

<details>
<summary><b>Styling the button</b> — <code>ClickToPayButtonConfig</code></summary>

```swift
let buttonConfig = ClickToPayButtonConfig(
    cardBrands: [.mastercard, .visa],
    isDark: true,
    buttonWidth: 280
)
SpreedlyClickToPayButton(checkoutConfig: config, buttonConfig: buttonConfig)
```

| Property | Default | Notes |
|---|---|---|
| `cardBrands` | from `initConfig` | `[.mastercard, .visa, .discover, .amex]` |
| `isDark` | `false` | Mastercard's dark treatment |
| `buttonWidth` | intrinsic | Maximum **500** px — the SDK clamps higher values |
| `buttonHeight` | intrinsic | **32–60** px — the SDK clamps outside that range |
| `isEnabled` | `true` | — |
| `theme` | `nil` | Deprecated Mastercard `theme` attribute — prefer `isDark` |
| `buttonAccessibilityLabel` | `"Click to Pay"` | — |
| `accessibilityIdentifier` | `"spreedly_click_to_pay_button"` | For UI tests |

Size limits come from
[Mastercard's UI component spec](https://developer.mastercard.com/unified-checkout-solutions/documentation/ui-components/).
Constants: `ClickToPayButtonConfig.mcButtonWidthMax`, `mcButtonHeightMin`, `mcButtonHeightMax`.

`ClickToPayCardBrand` maps to Mastercard wire strings (`mastercard`, `visa`, `discover`, `amex`).
Use `ClickToPayCardBrand.defaultCheckoutBrands` for all four. Objective-C uses
`cardBrandWireValues` on `ClickToPayButtonConfig` and `ClickToPayInitConfig`.

</details>

<a id="theming"></a>
### Step 4 — Theme it (optional) · `Your app`

There is **no** `theme` parameter on the config or the button. Set the global theme before
checkout:

```swift
import SpreedlyUI

SpreedlyThemeManager.setGlobalTheme(lightTheme: merchantLight, darkTheme: merchantDark)
```

| Themed | Not themed |
|---|---|
| Native buttons, loaders, section copy, `SPLTextField`, the Remember me toggle (switch tint uses `colors.primary`) | Mastercard's web widgets — the saved-card list, OTP input, and bank confirmation |

For Mastercard's surfaces, use `locale` and `dpaPresentationName` instead.

**Localization splits the same way.** Native chrome — the sheet title, buttons, loaders and form
labels — uses bundled `c2p_*` strings in the **iOS app locale**, and the navigation title is always
the localized **Click to Pay** (`c2p_nav_default_title`). Mastercard's WebView widgets (saved card
list, OTP input) follow **`config.locale`**, matching the web iframe.

### Step 5 — Charge the token · `Your server`

```bash
curl -X POST https://core.spreedly.com/v1/gateways/${GATEWAY_TOKEN}/purchase.json \
  -u ${ENVIRONMENT_KEY}:${ACCESS_SECRET} \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "payment_method_token": "ABC...payment_method_token",
      "amount": 9900,
      "currency_code": "USD"
    }
  }'
```

| Parameter | Required | Value and constraints |
|---|---|---|
| `payment_method_token` | Yes | The `token` from `PaymentResult` |
| `amount` | Yes | Minor units. Match what you passed as `amountCents` |
| `currency_code` | Yes | Match `transactionCurrencyCode` |

### Try it in sandbox

| Value | Use |
|---|---|
| Sandbox `srcDpaId` from Spreedly Support | Runs against `sandbox.src.mastercard.com` |
| `isSandbox: true` (the default) | Selects the sandbox script host |
| A sandbox-enrolled email or phone | Needed to see the returning-shopper path — an unenrolled address always shows the new-card form |

Full matrix: [Testing Guide](testing-guide.md).

---

## 6. Integration by platform

The same steps wired into each UI stack. Read only your own — the other two are collapsed.

### SwiftUI

```swift
import SwiftUI
import SpreedlyCore
import SpreedlyClickToPay

struct CheckoutView: View {
    private let config = makeConfig()

    var body: some View {
        SpreedlyClickToPayButton(checkoutConfig: config)
            .onAppear {
                _ = Spreedly.shared().subscribeToPaymentResults { result in
                    if result.isSuccess, let token = result.token {
                        // Send token to your backend
                    }
                }
            }
    }

    private func makeConfig() -> ClickToPayCheckoutConfig {
        var billing = ClickToPayTokenizeBilling()
        billing.firstName = "Jane"
        billing.lastName = "Doe"
        billing.email = "shopper@example.com"
        return ClickToPayCheckoutConfig(
            initConfig: ClickToPayInitConfig(amountCents: 9900),
            srcDpaId: "your-sandbox-or-production-dpaid",
            dpaPresentationName: "Your Store",
            customer: ClickToPayCustomer(email: "shopper@example.com"),
            tokenizeBilling: billing
        )
    }
}
```

### UIKit

<details>
<summary><b>Full UIKit implementation</b> — <code>SpreedlyClickToPayButtonViewController</code> as a child view controller</summary>

```swift
import UIKit
import SpreedlyCore
import SpreedlyClickToPay

var billing = ClickToPayTokenizeBilling()
billing.firstName = "Jane"
billing.lastName = "Doe"

let config = ClickToPayCheckoutConfig(
    initConfig: ClickToPayInitConfig(amountCents: 9900),
    srcDpaId: "your-sandbox-or-production-dpaid",
    dpaPresentationName: "Your Store",
    customer: ClickToPayCustomer(email: "shopper@example.com"),
    tokenizeBilling: billing
)

let buttonVC = SpreedlyClickToPayButtonViewController(checkoutConfig: config)
addChild(buttonVC)
stack.addArrangedSubview(buttonVC.view)
buttonVC.didMove(toParent: self)
```

For your own button, present the sheet directly:

```swift
SpreedlyClickToPayCheckout.present(config: config, from: self)
```

Guard double taps with `SpreedlyClickToPayCheckout.isActive`. Presenting while a session is
active replaces it.

</details>

### Objective-C

<details>
<summary><b>Full Objective-C implementation</b> — config construction, button view controller, <code>ClickToPayDelegate</code></summary>

```objc
#import <SpreedlyClickToPay/SpreedlyClickToPay-Swift.h>

ClickToPayInitConfig *initConfig = [[ClickToPayInitConfig alloc] initWithAmountCents:9900
                                                           transactionCurrencyCode:@"USD"];
initConfig.cardBrandWireValues = @[@"mastercard", @"visa"];

ClickToPayCheckoutConfig *config = [[ClickToPayCheckoutConfig alloc] init];
config.initConfig = initConfig;
config.srcDpaId = @"your-sandbox-or-production-dpaid";
config.customer = [[ClickToPayCustomer alloc] initWithEmail:@"shopper@example.com"
                                              phoneNumber:nil
                                              countryCode:nil
                                         mainLookupMethod:ClickToPayMainLookupMethodEmail];
config.dpaPresentationName = @"Your Store";

ClickToPayTokenizeBilling *billing = [[ClickToPayTokenizeBilling alloc] init];
billing.firstName = @"Jane";
billing.lastName = @"Doe";
config.tokenizeBilling = billing;

SpreedlyClickToPayButtonViewController *buttonVC =
    [[SpreedlyClickToPayButtonViewController alloc] initWithCheckoutConfig:config];
[self addChildViewController:buttonVC];
[stack addArrangedSubview:buttonVC.view];
[buttonVC didMoveToParentViewController:self];
```

Sheet without the drop-in button:

```objc
[ClickToPayCheckoutViewController presentWithConfig:config from:self];
```

Set `SpreedlyClickToPayCheckout.delegate` **before** presenting, then implement
`clickToPay:didReceiveEvent:userInfo:`.

`ClickToPayCheckoutViewController` has two modes:

| API | Behavior |
|-----|----------|
| `presentWithConfig:from:` | Singleton full-screen sheet, same as `SpreedlyClickToPayCheckout.present`. Set `SpreedlyClickToPayCheckout.delegate` before presenting for `ClickToPayDelegate` callbacks |
| `initWithConfig:` + embed in your hierarchy | Headless WebView host; calls `beginCheckout()` on load. Set `clickToPayDelegate` for flow events. Dismisses on a terminal `PaymentResult` from `subscribeToPaymentResults` / `paymentDelegate` |

</details>

> **iOS only:** the Objective-C surface has no Android or React Native equivalent. React Native
> consumers use the `checkout-react-native` bridge.

---

## 7. Handle the result

Three channels, three jobs. Only one of them is the outcome.

| Need | Use | Notes |
|---|---|---|
| The token, or the failure | `subscribeToPaymentResults` / `SpreedlyPaymentDelegate` | **Source of truth** |
| Flow progress | `SpreedlyClickToPayCheckout.events` / `ClickToPayDelegate` | Lookup, OTP, card list, errors |
| Phase and masked cards | `SpreedlyClickToPayCheckout.state` | A `ClickToPayCheckoutFlowSnapshot` |

| Result | Meaning | What to show the shopper |
|---|---|---|
| `PaymentResult.isSuccess` | Tokenized | Dismiss, send `result.token` to your backend |
| `PaymentResult.isFailure` | Tokenization or checkout failed | `failureDetails.getDescription()` |
| `.checkoutCancelled` event | Shopper cancelled at the bank confirmation step | Reset your checkout UI. The sheet dismisses itself |
| `.sessionDeleted` event | Signed out | Return to your product screen |

> **Important:** CVV is never on the event stream, in any case. `.paymentMethodTokenized` carries
> the token for information only — read the token from `subscribeToPaymentResults`.

<details>
<summary><b>Flow snapshot and phases</b> — <code>ClickToPayCheckoutFlowSnapshot</code>, <code>ClickToPayFlowState</code></summary>

Subscribe to `SpreedlyClickToPayCheckout.state` for a `ClickToPayCheckoutFlowSnapshot`:

| Snapshot field | Description |
|----------------|-------------|
| `checkoutId` | Active checkout session id |
| `phase` | `ClickToPayFlowState` — see below |
| `message` | Human-readable status, may match the loader copy |
| `awaitingExternalOtpChannel` | `true` when the external OTP channel picker should show |
| `otpValidationChannels` | Available OTP channels |
| `selectedOtpChannelId` | Currently selected channel |
| `maskedCards` | Typed saved cards when loaded |
| `selectedCardId` | Selected `srcDigitalCardId` |
| `cardsReady` | Saved cards loaded and selectable |

Phases (`ClickToPayFlowState`):

| Phase | Meaning |
|-------|---------|
| `idle` | No active checkout |
| `loadingWebView` / `mcScriptReady` | Loading the Mastercard script and UI kit |
| `initialized` | Mastercard init complete |
| `lookupComplete` | Lookup in progress |
| `otpRequired` | Awaiting OTP |
| `cardsLoaded` | Saved cards ready |
| `newUserEnrollment` | New-user card entry |
| `checkoutInProgress` | Bank confirmation open |
| `complete` / `tokenizing` | Mastercard `COMPLETE`; Spreedly tokenize in flight |
| `finished` | Token event emitted after successful tokenize |
| `failed` | Terminal error — the sheet dismisses; read `subscribeToPaymentResults` for the outcome |

</details>

<details>
<summary><b>Full event catalog</b> — every <code>ClickToPayEvent</code> case</summary>

Every event carries `checkoutId`, matching Android and React Native. Objective-C receives the same
payloads as `userInfo` keys — including `channels[]`, `cards[]`, `errors[]` (each with `key`,
`attribute`, `message`), `correlationId` and `flowId` on `.checkoutComplete`, and `code` as the
`ClickToPayErrorCode` raw value on `.error`.

| Event | When | Values |
|---|---|---|
| `.checkoutStarted` | Session begins | — |
| `.initialized` | Mastercard init completed | `success`, `availableCardBrands` |
| `.newUser` | Lookup found no enrolment | — |
| `.existingUser` | Consumer found, OTP next | — |
| `.verifiedUser` | Saved cards loaded | — |
| `.otpInitiated` | OTP started | `maskedValidationChannel`, `channels`, `network`, `rememberMe` |
| `.otpChannelSelectionRequired` | External picker needed | `channels` |
| `.otpResponse` | Validate result | `success`, `errorReason?` |
| `.otpResend` / `.otpNotYou` | Shopper action | — |
| `.displayCardsReady` | Masked cards ready | `cards: [ClickToPayMaskedCard]` |
| `.addNewCard` | Add-new-card path | `brands` |
| `.checkoutCancelled` | Cancelled at bank confirmation | — |
| `.checkoutDifferentPaymentMethod` | Alternate method chosen | — |
| `.checkoutError` | Mastercard checkout error | `actionCode` |
| `.checkoutWindowOpened` / `.checkoutWindowClosed` | Bank confirmation window | — |
| `.sessionDeleted` | Sign out completed | `deviceRecognized?` |
| `.checkoutComplete` | Mastercard `COMPLETE` | `metadata: ClickToPayMetadata` |
| `.paymentMethodTokenized` | Informational | `token` |
| `.error` | Terminal or validation error | `code: ClickToPayErrorCode`, `message` |
| `.validationErrors` | Field-level errors | `errors: [ClickToPayFieldError]` |

```swift
SpreedlyClickToPayCheckout.events
    .sink { event in
        switch event {
        case .initialized(_, let success, let brands): break
        case .checkoutComplete(_, let metadata): break
        case .error(_, let code, let message): break
        default: break
        }
    }
    .store(in: &cancellables)
```

**Flow phases** on `state`: `idle` → `loadingWebView` → `mcScriptReady` → `initialized` →
`lookupComplete` → `otpRequired` → `cardsLoaded` or `newUserEnrollment` → `checkoutInProgress` →
`complete` / `tokenizing` → `finished`, or `failed` at any point.

</details>

---

## 8. Errors and troubleshooting

**Error codes**

| `ClickToPayErrorCode` | Typical cause |
|---|---|
| `c2pInit` | Mastercard init or script load failed — check `srcDpaId` and ATS |
| `c2pLookup` | Invalid identity or lookup failure |
| `c2pOtp` | OTP initiation or validation failed |
| `c2pCheckout` | Checkout or bank confirmation failed |
| `c2pTokenize` | Spreedly tokenization failed |
| `networkTimeout` | Mastercard script did not load within 15 seconds |
| `unknown` | Unmapped |

**Problems you hit while integrating**

| Symptom | Cause | Fix |
|---|---|---|
| Tokenize returns HTTP 422 | Missing names, or Click to Pay not enabled | Set `tokenizeBilling.firstName` and `.lastName`; confirm Click to Pay on your environment key |
| "First name and last name are required" before any network call | Same cause, caught client-side | Same fix |
| Mastercard init fails | Bad `srcDpaId`, wrong sandbox flag, or ATS | Check all three — see [Configure your app](#4-configure-your-app) |
| The identity form keeps appearing | No valid `customer` | Provide an email, or a phone **and** country code |
| Phone lookup ignored | `countryCode` missing | It is required when using phone without email |
| OTP appears on every visit | Remember me was not checked, or checkout was not completed | Remember me lives in Mastercard's widget. `otp.rememberMe` only adds a duplicate native toggle |
| Sheet does not appear (SwiftUI) | No top view controller found | Use `present(config:from:)` with a visible view controller |
| No delegate callbacks (Objective-C) | Delegate set too late | Set `SpreedlyClickToPayCheckout.delegate` **before** presenting |
| OTP never shows | Email or phone not enrolled | Use an address enrolled in the Mastercard sandbox |
| Remember Me missing from the native CVV bar | Not enabled | Set `otp.rememberMe = true`. The Mastercard OTP widget always offers its own |
| Payment error during tokenize | Inline error on the sheet while processing | Cancel and call `present` again for a full retry |
| Tokenize hangs after `COMPLETE` | Auto-tokenize timed out after 120 seconds | Check CVV collection and that you subscribed to results |
| Blank Mastercard area | The web view lost height, usually to the keyboard | Keep it full height during checkout; dismiss the keyboard and retry |

Broader error model: [Error Handling](error-handling.md).

---

<a id="important-notes"></a>
## 9. Edge cases and cleanup

### Blocked devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK
> blocks Click to Pay at both button tap and `present`. No sheet appears, `.error` and
> `.validationErrors` are emitted, and a `PaymentResult.failure` is published. See
> [Security — Runtime Integrity](security.md#runtime-integrity).

### Returning shoppers and OTP

| What the shopper did in Mastercard's OTP widget | Next checkout |
|---|---|
| Checked Remember me **and** completed checkout | Saved cards load, no OTP |
| Left Remember me unchecked | Lookup runs, OTP required |

You do not configure this. It is a device cookie owned by Mastercard.

<details>
<summary><b>Detecting saved cards before checkout</b> — optional</summary>

`ClickToPaySavedCardsDetector` mounts a hidden web view, runs init and `getCards` only, and calls
`onResult` once. It never tokenizes, emits flow events, or presents the sheet. Use it to decide
whether to show contact fields at all.

```swift
let detectorConfig = checkoutConfig.asSavedCardsDetectorConfig()

ClickToPaySavedCardsDetector(
    config: detectorConfig,
    detectorKey: deviceDetectorKey,   // bump to remount after sign-out
    onResult: { result in
        if result.hasSavedCards {
            // Recognized on this device — hide email and phone
        }
        deviceDetectorKey = -1        // tear down before checkout
    },
    onControllerReady: { savedCardsDetectorController = $0 }
)
```

`onResult` receives a `ClickToPaySavedCardsDetectionResult` (`hasSavedCards`, optional
`savedCards` labels), and `onControllerReady` hands back a `ClickToPaySavedCardsDetectorController`
whose `signOut(onComplete:)` clears the Mastercard session without starting checkout.

Operating rules:

- Run **one** Mastercard flow at a time — tear the detector down before presenting checkout.
- `asSavedCardsDetectorConfig()` clears `customer` and sets `merchantHostedCardList`, so the probe
  cannot trigger a lookup.
- Bump `detectorKey` to remount after a sign-out.
- `getCards` times out after 30 seconds and reports `hasSavedCards: false`.
- Objective-C: the detector is `@objcMembers`; host it through `UIHostingController`.

Merchants who skip this keep exactly the same flow. Android calls the equivalent
`ClickToPaySavedCardsProbe`.

</details>

<details>
<summary><b>Headless and merchant-hosted card list</b> — advanced</summary>

```swift
let controller = SpreedlyClickToPayCheckout.makeController(config: config)
// Embed controller.webViewHost() in your hierarchy
controller.beginCheckout()
controller.events.sink { event in /* … */ }.store(in: &cancellables)
```

Prefer `makeController` over constructing `ClickToPayCheckoutController` directly —
`ClickToPayCheckoutController(config:)` creates an **isolated** flow with its own event bus, so the
static helpers (`cancel`, `lookup`, OTP and card methods) would not target it.

`controller.lookup` rejects empty email or phone the same way the static `lookup` does — validation
error events, no Mastercard call. Prefer `controller.typedMaskedCards` or
`controller.flowSnapshot.maskedCards` over raw dictionaries.

**Headless tokenize.** After `.checkoutComplete(checkoutId, metadata)`, pass billing with the
required `firstName` and `lastName`:

```swift
var billing = ClickToPayTokenizeBilling()
billing.firstName = "Jane"
billing.lastName = "Doe"
billing.email = "shopper@example.com"
// billing.addressLine1 = "..."   // optional

controller.tokenize(
    verificationValue: cvv,
    billing: billing.toBillingFields(),
    paymentMetadata: ["order_id": "12345"]
)
// Then await subscribeToPaymentResults for the token
```

Or call `Spreedly.shared().createClickToPayPaymentMethod(clickToPay: metadata, verificationValue: cvv, billing: billing.toBillingFields())`.

**Manual card entry.** When driving your own UI, the controller also exposes
`showManualCardEntry()` / `dismissManualCardEntry()` to toggle the native SPL card form, and
`setPendingVerificationValue(_:)` to stash a CVV for the next checkout or tokenize call. New-card
checkout goes through `checkoutWithNewCard` with a `ClickToPayNewCardFields` value.

Merchant-hosted card list — set `config.merchantHostedCardList = true`, listen for
`.displayCardsReady`, then:

```swift
SpreedlyClickToPayCheckout.selectCard(srcDigitalCardId)
SpreedlyClickToPayCheckout.checkoutSelectedCard(
    srcDigitalCardId: srcDigitalCardId,
    verificationValue: cvvFromSecureField,
    rememberMe: true
)
```

External OTP channel selection:

```swift
SpreedlyClickToPayCheckout.selectOtpChannel(channelId)
SpreedlyClickToPayCheckout.initiateOtp()
SpreedlyClickToPayCheckout.validateOtp("123456")
```

Prefer `controller.typedMaskedCards` over raw dictionaries.

</details>

### Sign out

The sheet's **Sign out** clears the Mastercard device session, dismisses the sheet, and emits
`.sessionDeleted`. `SpreedlyClickToPayCheckout.signOut(onComplete:)` clears the session **without**
dismissing — use it to drop stale Remember-me cards, then call `lookup(customer:)` again.

### Cleanup

`SpreedlyClickToPayCheckout.cancel()` dismisses an active sheet. Hold your `AnyCancellable` for
the lifetime of the screen. Never log raw CVV, PAN, or full tokens.

---

## 10. API at a glance

| API | Module | Purpose |
|---|---|---|
| `SpreedlyClickToPayButton(checkoutConfig:buttonConfig:)` | `SpreedlyClickToPay` | Mastercard button, SwiftUI |
| `SpreedlyClickToPayButtonViewController(checkoutConfig:)` | `SpreedlyClickToPay` | Mastercard button, UIKit and Objective-C |
| `SpreedlyClickToPayCheckout.present(config:from:)` | `SpreedlyClickToPay` | Present the sheet from your own button |
| `SpreedlyClickToPayCheckout.cancel()` / `.isActive` | `SpreedlyClickToPay` | Dismiss, and guard double taps |
| `SpreedlyClickToPayCheckout.events` / `.state` | `SpreedlyClickToPay` | Progress stream and phase snapshot |
| `SpreedlyClickToPayCheckout.delegate` | `SpreedlyClickToPay` | Objective-C event channel |
| `SpreedlyClickToPayCheckout.signOut(onComplete:)` / `.lookup(customer:)` | `SpreedlyClickToPay` | Session control |
| `SpreedlyClickToPayCheckout.makeController(config:)` | `SpreedlyClickToPay` | Headless controller |
| `ClickToPayCheckoutController` + `webViewHost()` + `beginCheckout()` | `SpreedlyClickToPay` | Host the WebView in your own UI and start the flow |
| `SpreedlyClickToPayCheckout.setAutoTokenizeAuthRefresher` | `SpreedlyClickToPay` | Refresh a signed `Spreedly.setup` before auto-tokenize |
| `SpreedlyClickToPayButton.prepareForPresentation` | `SpreedlyClickToPay` | Run an auth refresh before the sheet opens |
| `ClickToPayCheckoutController.setRememberMeSelected(_:)` | `SpreedlyClickToPay` | Sync Remember me before a headless checkout |
| `SpreedlyClickToPayCheckout.checkoutWithNewCard(...)` | `SpreedlyClickToPay` | Headless checkout with SPL-collected card fields |
| `Spreedly.shared().createClickToPayPaymentMethod(...)` | `SpreedlyCore` | Core tokenize, for advanced flows |
| `ClickToPaySavedCardsDetectorController.signOut(onComplete:)` | `SpreedlyClickToPay` | Clear the Mastercard session from the detector (`c2pSignOut()` on web) |
| `ClickToPayCheckoutConfig` | `SpreedlyClickToPay` | The one merchant config object |
| `ClickToPaySavedCardsDetector` | `SpreedlyClickToPay` | Pre-checkout saved-card probe |
| `Spreedly.shared().subscribeToPaymentResults { }` | `SpreedlyCore` | Receive the token |
| `SpreedlyThemeManager.setGlobalTheme(lightTheme:darkTheme:)` | `SpreedlyUI` | Theme the native chrome |

---

## 11. Related documentation

- [Express checkout](express-checkout.md) — plain card entry, the usual companion button
- [Testing Guide](testing-guide.md) — sandbox setup and the go-live checklist
- [Theme and styling](theme-and-styling.md) — building the theme you set in step 4
- [Security](security.md) — runtime integrity and screen prevention
- [Objective-C](objective-c.md) — selector forms for every API above
- [Getting Started](getting-started.md) — installation and SDK lifecycle

<details>
<summary><b>Differences from the web iframe</b> — for merchants porting a web integration</summary>

| Topic | Web iframe | iOS SDK |
|-------|------------|---------|
| Merchant button | `<src-button>` + `onclick` → `c2pInit` | `SpreedlyClickToPayButton` |
| `lib.js` on the merchant page | Loaded before click | Loaded in the checkout sheet only (`c2p-host.html`) |
| Presenter | `Spreedly.c2pInit` | Button tap → internal `present`; advanced integrations call `present` directly |
| Config | `options` object | `ClickToPayCheckoutConfig` |
| DPA ID | `c2pConfig.srcDpaId` | `srcDpaId` |
| Widget locale | `dpaLocale` | `locale` |
| DPA display metadata | `dpaData` | `dpaPresentationName` / `dpaName` |
| Transaction block | `c2pConfig` | `initConfig` (`ClickToPayInitConfig`) |
| Card-only | Separate integration | `CardFormDropIn` or headless card APIs — not inside Click to Pay |
| Events | `Spreedly.on(event, fn)` | `SpreedlyClickToPayCheckout.events` or `ClickToPayDelegate` |

</details>

