# Click to Pay Integration - Spreedly iOS SDK

Accept Mastercard Click to Pay checkout via the native `SpreedlyClickToPay` module (native SPL fields + MC bridge + Spreedly tokenize). Card PAN and CVV are collected inside the SDK checkout sheet (or your custom UI via `ClickToPayCheckoutController`) — not on a separate merchant card form.

**Estimated integration time:** ~20 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Prerequisites](#prerequisites)
4. [Merchant-to-SDK Flow](#merchant-to-sdk-flow)
5. [SDK Methods](#sdk-methods)
6. [Configuration](#configuration)
7. [Flow Events](#flow-events)
8. [Result States](#result-states)
9. [Advanced Integration](#advanced-integration)
10. [SwiftUI Integration](#swiftui-integration)
11. [UIKit / Swift Integration](#uikit--swift-integration)
12. [Objective-C Integration](#objective-c-integration)
13. [Differences from Web iframe](#differences-from-web-iframe)
14. [Important Notes](#important-notes)
15. [Troubleshooting](#troubleshooting)
16. [Related Documentation](#related-documentation)

---

## Introduction

Click to Pay lets shoppers pay with cards saved to the Mastercard SRC network. The iOS SDK loads Mastercard's integration script inside a `WKWebView`, runs identity lookup / OTP / card selection, then tokenizes through Spreedly Core with a `click_to_pay` metadata block and CVV.

### Key characteristics

- **Drop-in button** — `SpreedlyClickToPayButton` embeds MC `<src-button>` (iframe parity); tap opens checkout
- **Checkout config** — `ClickToPayCheckoutConfig` holds init, customer, UI, and checkout options (Android / RN parity)
- **MC bridge** — `WKWebView` runs MC `lib.js`; default sheet uses MC WebView widgets (iframe parity)
- **PAN for new users** — default sheet uses native `SPLTextField` → `checkoutWithNewCard` (iframe `add-new-card` parity); saved cards and OTP use MC WebView widgets
- **Native CVV only** — security code is collected with `SPLTextField`; never taken from MC COMPLETE payload
- **Tokenize on COMPLETE** — `createClickToPayPaymentMethod` runs automatically after `checkoutActionCode: COMPLETE`

### Optional module

Add **`SpreedlyClickToPay`** from `checkout-ios-package` only when you use Click to Pay. It requires **SpreedlyCore**, **SpreedlySecurity**, and **SpreedlyUI** (same version as your other Spreedly modules).

---

## Installation

Use the **same** [checkout-ios-package](https://github.com/spreedly/checkout-ios-package) version for every Spreedly module. See [Getting Started — Installation](getting-started.md#installation) for private-repo access and version pinning.

> **Availability:** Included from package **1.6.0+** (`SpreedlyClickToPay` XCFramework). Use the **same** package version for Core, Security, UI, and Click to Pay.

### Swift Package Manager

In Xcode **File → Add Package Dependencies**, add `https://github.com/spreedly/checkout-ios-package`, then select:

- **Required:** `SpreedlyCore`, `SpreedlySecurity`, `SpreedlyUI`
- **Click to Pay:** `SpreedlyClickToPay`

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/spreedly/checkout-ios-package", from: "1.6.0")
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

### CocoaPods

```ruby
pod 'SpreedlyCore', '~> 1.6'
pod 'SpreedlySecurity', '~> 1.6'
pod 'SpreedlyUI', '~> 1.6'
pod 'SpreedlyClickToPay', '~> 1.6'
```

No extra `post_install` block is required for Click to Pay (unlike Stripe APM).

---

## Prerequisites

1. Complete [getting-started.md](getting-started.md) (`Spreedly.setup`)
2. **Sandbox or production `srcDpaId` (DPAID)** from Spreedly Support
3. **C2P enabled** on your Spreedly environment key
4. **ATS** — allow Mastercard SRC hosts in `Info.plist`:

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

Adjust for your security policy; production apps typically allow HTTPS to these hosts without disabling ATS globally.

---

## Merchant-to-SDK Flow

```
Step 1: Spreedly.setup(environmentKey:accessSecret:) — required before any checkout

Step 2: Build ClickToPayCheckoutConfig
        — set srcDpaId (required at runtime)
        — set tokenizeBilling.firstName + lastName (required for default-sheet auto-tokenize)
        — optional: customer, initConfig amount/currency, otp/displayCards options

Step 3: Subscribe to payment results
        Spreedly.shared().subscribeToPaymentResults { result in ... }

Step 4: Add SpreedlyClickToPayButton(checkoutConfig:) to your checkout screen
        — optional: prepareForPresentation { refresh signed Spreedly.setup config }

Step 5: Shopper taps MC button → SDK presents checkout → token in PaymentResult
```

If your app refreshes signed `Spreedly.setup` config before checkout, use `prepareForPresentation` on the button (or refresh in `onAppear` before the shopper taps).

---

## SDK Methods

| Swift API | iframe equivalent | Purpose |
|-----------|-------------------|---------|
| `SpreedlyClickToPayButton(checkoutConfig:)` | `<src-button>` click → `c2pInit` | MC-branded pay button on merchant checkout |
| `ClickToPayButtonConfig` | `<src-button card-brands="...">` + MC Storybook controls | Button `card-brands`, `isDark`, `buttonWidth`/`buttonHeight`, `theme`, `isEnabled`, accessibility |
| `SpreedlyClickToPayCheckout.present(config:from:)` | `c2pInit` (advanced) | Full-screen checkout without drop-in button |
| `SpreedlyClickToPayCheckout.cancel()` | — | Dismiss active checkout |
| `SpreedlyClickToPayCheckout.isActive` | — | Whether a checkout session is in progress |
| `SpreedlyClickToPayCheckout.lookup(customer:)` | `c2pLookup` | Manual identity lookup (active checkout required) |
| `SpreedlyClickToPayCheckout.signOut(onComplete:)` | `c2pSignOut()` | Clear MC device session (does not dismiss the sheet) |
| `SpreedlyClickToPayCheckout.initiateOtp()` | — | Start OTP validation (headless; channel must be selected first when using external picker) |
| `SpreedlyClickToPayCheckout.validateOtp(_:)` | MC `validate` | Submit OTP code (headless / custom UI) |
| `SpreedlyClickToPayCheckout.present(config:)` | — | Present from key-window top VC (fails via `PaymentResult` if none found) |
| `SpreedlyClickToPayCheckout.delegate` | `Spreedly.on` | ObjC `ClickToPayDelegate` for sheet **and** headless VC |
| `SpreedlyClickToPayCheckout.setAutoTokenizeAuthRefresher` | — | Refresh signed `Spreedly.setup` before auto-tokenize |
| `SpreedlyClickToPayButton.prepareForPresentation` | — | Run auth refresh before opening sheet |
| `ClickToPayCheckoutController.setRememberMeSelected(_:)` | Remember me | Sync Remember me before saved-card or new-card checkout (headless) |
| `SpreedlyClickToPayCheckout.selectOtpChannel(_:)` | OTP channel picker | External OTP channel selection |
| `SpreedlyClickToPayCheckout.selectCard(_:)` | — | Select saved card (merchant-hosted list) |
| `SpreedlyClickToPayCheckout.checkoutSelectedCard(...)` | `c2pCheckout` | Checkout saved card + CVV |
| `SpreedlyClickToPayCheckout.checkoutWithNewCard(...)` | new card checkout | Checkout with SPL-collected PAN |
| `SpreedlyClickToPayCheckout.events` | `Spreedly.on('c2p-…')` | Combine event stream |
| `SpreedlyClickToPayCheckout.state` | — | Flow phase snapshot publisher |
| `SpreedlyClickToPayCheckout.makeController(config:)` | headless `c2pInit` | Headless controller factory |
| `ClickToPayCheckoutController` + `webViewHost()` | headless UI | Custom merchant UI |
| `controller.beginCheckout()` | `c2pInit` (+ `doLookup`) | Start MC init |
| `Spreedly.shared().createClickToPayPaymentMethod(clickToPay:verificationValue:…)` | `paymentMethod` | Core tokenize (advanced) |
| `subscribeToPaymentResults` | `paymentMethod` / `errors` | Async tokenize result |
| `ClickToPaySavedCardsDetector` | — | Optional hidden `getCards` probe before checkout (Android: `ClickToPaySavedCardsProbe`) |
| `ClickToPayCheckoutConfig.asSavedCardsDetectorConfig()` | — | Detector-safe config clone (`customer: nil`, `merchantHostedCardList: true`) |
| `ClickToPaySavedCardsDetectorController.signOut(onComplete:)` | `c2pSignOut()` | Clear MC session from the detector without starting checkout |

---

## Configuration

### `ClickToPayCheckoutConfig` (sole merchant config)

| Property | Required | Default | iframe | Notes |
|----------|----------|---------|--------|-------|
| `initConfig` | No | `ClickToPayInitConfig()` | `c2pConfig` transaction block | Amount, currency, brands — see below |
| `srcDpaId` | **Yes** (runtime) | `""` | `c2pConfig.srcDpaId` | Sandbox or production DPAID from Spreedly Support |
| `locale` | No | `en_US` | `dpaLocale` | MC WebView widget locale |
| `isSandbox` | No | `true` | `options.isTest` | MC script host (`sandbox.src` vs `src`) |
| `isTest` | No | `false` | — | Optional override for `click_to_pay.test` on tokenize; when `false`, follows `isSandbox` |
| `dpaPresentationName` / `dpaName` | No | sandbox strings | `dpaData` | MC init metadata (not the native sheet nav title) |
| `customer` | No | `nil` | `customer` | Prefill for lookup; omit to show native identity form |
| `doLookup` | No | `true` | `doLookup` | Auto lookup after init (`getCards` → `idLookup` when empty) |
| `displayCards` | No | `ClickToPayDisplayCardsConfig()` | `options.displayCards` | MC card-list chrome — see below |
| `otp` | No | `ClickToPayOtpConfig()` | `options.otp` | OTP / Remember me — see below |
| `merchantHostedCardList` | No | `false` | — | `true`: merchant calls `selectCard` + `checkoutSelectedCard` |
| `tokenizeBilling` | No* | `nil` | billing on `c2pCheckout` | *`firstName` + `lastName` **required** for default-sheet auto-tokenize — see below |
| `tokenizeMetadata` | No | `nil` | `metadata` on `c2pCheckout` | Optional payment-method metadata on auto-tokenize |
| `eligibleForCardUpdater` | No | `nil` | `eligible_for_card_updater` | Swift-only; optional Account Updater flag |

### `ClickToPayInitConfig`

| Property | Required | Default | Notes |
|----------|----------|---------|-------|
| `transactionAmount` | No | `100` | Major units for MC init (use `amountCents:` convenience for cents) |
| `transactionCurrencyCode` | No | `"USD"` | ISO currency |
| `dynamicDataType` | No | `"NONE"` | MC dynamic data type |
| `cardBrands` | No | all four networks | `[.mastercard, .visa, .discover, .amex]` |

### `ClickToPayDisplayCardsConfig`

| Property | Required | Default | Notes |
|----------|----------|---------|-------|
| `displaySignOut` | No | `true` | MC card-list sign-out link |
| `displayAddCard` | No | `true` | Add-new-card entry on MC list |
| `displayPreferredCard` | No | `true` | Highlight preferred card |
| `cardSelectionType` | No | `.radioButton` | `.radioButton` or `.gridView` |

### `ClickToPayOtpConfig`

| Property | Required | Default | Notes |
|----------|----------|---------|-------|
| `rememberMe` | No | `false` | When `true`, optional **native** saved-card CVV bar Remember me toggle. **Returning-user OTP skip** is controlled by the shopper's MC WebView OTP checkbox — merchants do not need to set this for persistence. |
| `presentation` | No | `.overlay` | MC OTP presentation (`.none` hides MC overlay type) |
| `channelSelection` | No | `.inline` | `.external` shows native channel picker before OTP |
| `requestedValidationChannelId` | No | `nil` | Pre-select OTP channel |

### `ClickToPayCustomer`

| Property | Required | Default | Notes |
|----------|----------|---------|-------|
| `email` | No* | `nil` | *Email **or** phone+country required for lookup |
| `phoneNumber` | No* | `nil` | Used with `countryCode` for phone lookup |
| `countryCode` | No* | `nil` | Required when using phone without email |
| `mainLookupMethod` | No | `.email` | When both email and phone set, which drives `idLookup` |

Helpers: `hasEmail()`, `hasPhoneLookup()`, `isValidForLookup()`.

### `ClickToPayTokenizeBilling`

All properties optional on the type; **`firstName` and `lastName` are required at tokenize time** for the default sheet. Address, shipping, and other fields are optional — only values you set are sent.

| Property | Notes |
|----------|-------|
| `firstName`, `lastName` | **Required** for auto-tokenize; prefill native new-card name fields |
| `fullName`, `email`, `phoneNumber`, `company` | Optional |
| `month`, `year` | Optional expiry on payment method |
| `addressLine1`, `addressLine2`, `city`, `state`, `zip`, `country` | Optional billing address |
| `shippingAddressLine1`, `shippingAddressLine2`, `shippingCity`, `shippingState`, `shippingZip`, `shippingCountry`, `shippingPhoneNumber` | Optional shipping |

Use `toBillingFields(fallbackEmail:)` → `ClickToPayBillingFields` for headless tokenize.

### `ClickToPayNewCardFields` (headless new-card checkout)

| Property | Required | Notes |
|----------|----------|-------|
| `cardNumber`, `cardExpiryMonth`, `cardExpiryYear`, `cardSecurityCode` | Yes | SPL-collected values |
| `cardholderFirstName`, `cardholderLastName` | Yes | Passed to `checkoutWithNewCard` |

The default sheet collects these via native `SPLTextField` — merchants only construct `ClickToPayNewCardFields` for headless `checkoutWithNewCard`.

```swift
let initConfig = ClickToPayInitConfig(amountCents: 9900, transactionCurrencyCode: "USD")
var config = ClickToPayCheckoutConfig(
    initConfig: initConfig,
    srcDpaId: "your-sandbox-or-production-dpaid",
    customer: ClickToPayCustomer(email: "shopper@example.com"),
    dpaPresentationName: "Your Store"
)
var billing = ClickToPayTokenizeBilling()
billing.email = "shopper@example.com"
billing.firstName = "Jane"
billing.lastName = "Doe"
billing.addressLine1 = "300 Morris Rd"
billing.city = "Durham"
billing.state = "NC"
billing.zip = "27701"
billing.country = "US"
config.tokenizeBilling = billing
config.tokenizeMetadata = ["order_id": "12345"]
config.eligibleForCardUpdater = true
```

### `ClickToPayButtonConfig` (drop-in button)

| Property | iframe / MC | Default |
|----------|-------------|---------|
| `cardBrands` | `<src-button card-brands="...">` (`[ClickToPayCardBrand]`) | `checkoutConfig.initConfig.cardBrands` |
| `isDark` | MC `dark` attribute | `false` |
| `buttonWidth` | MC `width` (px); max **500** | `0` (intrinsic MC width) |
| `buttonHeight` | MC `height` (px); **32–60** (layout uses painted size) | `0` (intrinsic MC height) |
| `theme` | Deprecated MC `theme` attribute | `nil` (omit; prefer `isDark`) |
| `isEnabled` | disable via shadow DOM / pointer-events | `true` |
| `buttonAccessibilityLabel` | — | `"Click to Pay"` |
| `accessibilityIdentifier` | UI tests | `"spreedly_click_to_pay_button"` |

```swift
let buttonConfig = ClickToPayButtonConfig(
    cardBrands: [.mastercard, .visa],
    isDark: true,
    buttonWidth: 280
)
SpreedlyClickToPayButton(checkoutConfig: config, buttonConfig: buttonConfig)
```

`ClickToPayCardBrand` maps to MC wire strings (`mastercard`, `visa`, `discover`, `amex`). Use `ClickToPayCardBrand.defaultCheckoutBrands` for all four networks. Objective-C: `cardBrandWireValues` on `ClickToPayButtonConfig` / `ClickToPayInitConfig`.

**`<src-button>` size limits** ([Mastercard UCS UI Components](https://developer.mastercard.com/unified-checkout-solutions/documentation/ui-components/)): `buttonWidth` max **500** px; `buttonHeight` **32–60** px. The SDK clamps out-of-range values before sending them to MC. Constants: `ClickToPayButtonConfig.mcButtonWidthMax`, `mcButtonHeightMin`, `mcButtonHeightMax`.

### Default checkout sheet (after button tap)

| Phase | What the shopper sees |
|-------|-------------------------|
| Bootstrap | Centered loader while MC `lib.js` loads |
| Identity lookup | Native email, phone, country code, and **Look up** when no valid `customer` is configured |
| Auto lookup | Loader with optional email context when `customer` is prefilled |
| Saved cards | MC card list in the WebView with a pinned native CVV bar, optional native **Remember me** toggle when `otp.rememberMe` is enabled, and pay button |
| OTP | MC OTP widget (full-bleed WebView) with shopper **Remember me** checkbox; choice is forwarded to MC at checkout |
| New user | Native SPL card form (card number → expiry → CVV → name), cardholder name prefilled from `tokenizeBilling` when set, and **Pay with new card** |
| DCF | Full-screen bank confirmation WebView |
| Tokenize | Processing loader while Spreedly tokenizes after MC `COMPLETE` |

The sheet navigation title is the fixed localized string **Click to Pay** (`c2p_nav_default_title`). Set `dpaPresentationName` to your store or brand name for Mastercard's checkout UI inside the WebView — it does not replace the native navigation title.

Headless integrators building a custom UI with `ClickToPayCheckoutController` can mirror the same phases; the default sheet is not required. Use `ClickToPayFlowState.checkoutTitle` for long-form status copy in custom chrome.

### Card-only checkout (outside Click to Pay)

The Click to Pay module is for SRC wallet flows only. If you need standard card tokenization without Click to Pay, use [`CardFormDropIn`](getting-started.md) (SwiftUI/UIKit) or headless `createPaymentMethod` / `createCreditCard` — not a fallback inside the C2P sheet. A common pattern is two buttons on checkout: **`SpreedlyClickToPayButton`** and **Pay with card** (`CardFormDropIn`).

### Theming

The default sheet uses the same **`SpreedlyTheme` / `SpreedlyThemeManager`** objects as `CardFormDropIn` and headless `SPLTextField` — but **there is no `theme` parameter on `ClickToPayCheckoutConfig` or the button**. Set the global theme **before** checkout:

```swift
import SpreedlyUI

SpreedlyThemeManager.setGlobalTheme(lightTheme: merchantLight, darkTheme: merchantDark)
// SpreedlyClickToPayButton inherits theme for native overlays; MC src-button uses MC styling.
```

The coordinator wraps the sheet with `.spreedlyAdaptiveGlobalTheme()`, so native chrome picks up `SpreedlyThemeManager.globalTheme` automatically (including light/dark mode changes). See [Theme and styling](theme-and-styling.md).

**Themed (native SDK UI):** primary/secondary buttons, loaders, section copy, native `SPLTextField` (new-card and saved-card CVV), and the **Remember me** toggle (switch tint uses `colors.primary`).

**Not merchant-themed:** Mastercard WebView widgets (saved card list, OTP, DCF). Use `config.locale` and `dpaPresentationName` for MC-facing presentation.

**Headless** (`ClickToPayCheckoutController` + your own UI): apply `.spreedlyTheme(...)` or the same global theme to your SwiftUI hierarchy; C2P still does not accept per-present theme parameters.

### Localization

- **Native chrome** — sheet navigation title is always localized **Click to Pay**; buttons, loaders, and form labels use bundled `c2p_*` strings in the **iOS app locale**.
- **MC WebView widgets** (saved card list, OTP input) follow **`config.locale`** (e.g. `en_US`), matching the web iframe.

---

## Flow Events

Every `ClickToPayEvent` includes `checkoutId` (RN / Android parity).

**Which callback to use**

| Need | API |
|------|-----|
| Payment token / failure | `subscribeToPaymentResults` (Swift) or `SpreedlyPaymentDelegate` (ObjC) — **source of truth** |
| Flow progress (lookup, OTP, cards, errors) | `SpreedlyClickToPayCheckout.events` (Combine) or `ClickToPayDelegate` (ObjC) |
| Phase + masked cards snapshot | `SpreedlyClickToPayCheckout.state` → `ClickToPayCheckoutFlowSnapshot` |

CVV is **never** included on `ClickToPayEvent` cases. Collect CVV with native `SPLTextField`, then pass it to `checkoutSelectedCard` or headless `ClickToPayCheckoutController.tokenize`.

The default sheet collects CVV and tokenizes internally after `.checkoutComplete` — you do not receive CVV on the event stream.

### Event catalog

| Event | When fired | Associated values | ObjC `userInfo` keys |
|-------|------------|-------------------|----------------------|
| `.checkoutStarted` | Checkout session begins | — | `checkoutId` |
| `.initialized` | MC `init` completes | `success`, `availableCardBrands` | `success`, `availableCardBrands` |
| `.newUser` | Lookup → consumer not enrolled | — | `checkoutId` |
| `.existingUser` | Lookup → consumer found, OTP next | — | `checkoutId` |
| `.verifiedUser` | Saved cards loaded after OTP / lookup | — | `checkoutId` |
| `.otpInitiated` | OTP validation started | `maskedValidationChannel`, `channels`, `network`, `rememberMe` | same + `channels[]` |
| `.otpChannelSelectionRequired` | External channel picker needed | `channels` | `channels[]` |
| `.otpResponse` | OTP validate result | `success`, `errorReason?` | `success`, `errorReason?` |
| `.otpResend` | Shopper tapped resend | — | `checkoutId` |
| `.otpNotYou` | Shopper tapped Not you | — | `checkoutId` |
| `.displayCardsReady` | Masked cards ready (merchant-hosted list) | `cards: [ClickToPayMaskedCard]` | `cards[]` |
| `.addNewCard` | Add-new-card path | `brands` | `brands` |
| `.checkoutCancelled` | DCF / checkout cancelled | — | `checkoutId` |
| `.checkoutDifferentPaymentMethod` | MC alternate payment action | — | `checkoutId` |
| `.checkoutError` | MC checkout error action | `actionCode` | `actionCode` |
| `.checkoutWindowOpened` | DCF window opened | — | `checkoutId` |
| `.checkoutWindowClosed` | DCF window closed | — | `checkoutId` |
| `.sessionDeleted` | Sign out completed | `deviceRecognized?` | `deviceRecognized?` |
| `.checkoutComplete` | MC `COMPLETE` | `metadata: ClickToPayMetadata` | `correlationId`, `flowId` |
| `.paymentMethodTokenized` | Informational token emit | `token` | `token` (prefer `subscribeToPaymentResults`) |
| `.error` | Terminal / validation error | `code: ClickToPayErrorCode`, `message` | `code` (rawValue), `message` |
| `.validationErrors` | Field-level errors | `errors: [ClickToPayFieldError]` | `errors[]` with `key`, `attribute`, `message` |

### `ClickToPayErrorCode`

| Case | Typical cause |
|------|----------------|
| `c2pInit` | MC init / script load failure |
| `c2pLookup` | Invalid identity or lookup failure |
| `c2pOtp` | OTP initiation or validation failure |
| `c2pCheckout` | Checkout / DCF failure |
| `c2pTokenize` | Spreedly tokenize failure |
| `networkTimeout` | Bootstrap / MC lib load timeout (15s) |
| `unknown` | Unmapped error |

```swift
SpreedlyClickToPayCheckout.events
    .sink { event in
        switch event {
        case .initialized(_, let success, let brands):
            break
        case .checkoutComplete(_, let metadata):
            break // token via subscribeToPaymentResults
        case .error(_, let code, let message):
            break
        default:
            break
        }
    }
    .store(in: &cancellables)
```

Objective-C: set `SpreedlyClickToPayCheckout.delegate` and implement `clickToPay(_:didReceiveEvent:userInfo:)` — works for **singleton sheet present** and embedded `ClickToPayCheckoutViewController`.

---

## Result States

Subscribe to **`SpreedlyClickToPayCheckout.state`** for a `ClickToPayCheckoutFlowSnapshot`:

| Snapshot field | Description |
|----------------|-------------|
| `checkoutId` | Active checkout session id |
| `phase` | `ClickToPayFlowState` (see table below) |
| `message` | Human-readable status (may match loader copy) |
| `awaitingExternalOtpChannel` | `true` when external OTP channel picker should show |
| `otpValidationChannels` | Available OTP channels |
| `selectedOtpChannelId` | Currently selected channel |
| `maskedCards` | Typed saved cards when loaded |
| `selectedCardId` | Selected `srcDigitalCardId` |
| `cardsReady` | Saved cards loaded and selectable |

Phases match `ClickToPayFlowState`:

| Phase | Meaning |
|-------|---------|
| `idle` | No active checkout |
| `loadingWebView` / `mcScriptReady` | Loading MC script and UI kit |
| `initialized` | MC init complete |
| `lookupComplete` | Lookup in progress |
| `otpRequired` | Awaiting OTP |
| `cardsLoaded` | Saved cards ready |
| `newUserEnrollment` | New-user card entry |
| `checkoutInProgress` | DCF checkout open |
| `complete` / `tokenizing` | MC COMPLETE; Spreedly tokenize in flight |
| `finished` | Token event emitted after successful tokenize (`paymentMethodTokenized`) |
| `failed` | Terminal error — sheet dismisses; read `subscribeToPaymentResults` for tokenize outcome |

**Payment outcome:** Always use `subscribeToPaymentResults` — `PaymentResult.isSuccess` and `PaymentResult.token` are the source of truth for the `payment_method_token`. After tokenize succeeds, flow state moves to `finished` and `.paymentMethodTokenized` fires on `events`.

**Cancellation:** `.checkoutCancelled` is emitted on DCF cancel; the singleton sheet dismisses automatically. Headless integrators should reset UI when receiving this event.

**Sign-out:** The sheet toolbar **Sign out** clears the MC device session, dismisses the checkout sheet, and emits `.sessionDeleted`. Reset merchant UI when you receive `sessionDeleted` (for example return to your product screen). Programmatic `SpreedlyClickToPayCheckout.signOut(onComplete:)` clears the session **without** dismissing the sheet — use it to clear stale Remember-me cards, then call `lookup(customer:)` again. OTP **Not you** dismisses the sheet after cleanup (`.otpNotYou` then `.sessionDeleted`). MC card-list sign-out during saved-cards may restart lookup in-sheet (iframe parity).

---

## Advanced Integration

### Programmatic present (no drop-in button)

Use `SpreedlyClickToPayCheckout.present(config:from:)` when you build a custom merchant pay button or drive checkout from your own UI. The SDK still runs the same full-screen sheet. Check `SpreedlyClickToPayCheckout.isActive` before presenting if you need to guard double-taps.

### Headless / custom UI

Use `SpreedlyClickToPayCheckout.makeController(config:)` (or `ClickToPayCheckoutController` from your own factory):

> **Note:** Prefer `makeController` so singleton helpers (`cancel`, `lookup`, static OTP/card methods) target the same session. `ClickToPayCheckoutController(config:)` creates an isolated flow with its own event bus.

```swift
let controller = SpreedlyClickToPayCheckout.makeController(config: config)
// Embed controller.webViewHost() in your SwiftUI hierarchy
controller.beginCheckout()

controller.events
    .sink { event in /* handle ClickToPayEvent */ }
    .store(in: &cancellables)

controller.state // @Published snapshot on the controller instance
```

Wire OTP manually when using external channel selection:

```swift
SpreedlyClickToPayCheckout.selectOtpChannel(channelId)
SpreedlyClickToPayCheckout.initiateOtp()
// OTP entry: MC src-otp-input in the WebView, or headless:
SpreedlyClickToPayCheckout.validateOtp("123456") // forwards to MC validate
```

**Saved cards (headless):** Prefer `controller.typedMaskedCards` (`[ClickToPayMaskedCard]`) or `controller.flowSnapshot.maskedCards` over raw `maskedCards` dictionaries.

**Lookup validation:** `ClickToPayCheckoutController.lookup` rejects empty email/phone the same way as `SpreedlyClickToPayCheckout.lookup` (validation error events, no MC call).

### Merchant-hosted card list

Set `config.merchantHostedCardList = true`, then drive checkout from your UI:

```swift
SpreedlyClickToPayCheckout.selectCard(srcDigitalCardId)
SpreedlyClickToPayCheckout.checkoutSelectedCard(
    srcDigitalCardId: srcDigitalCardId,
    verificationValue: cvvFromSecureField,
    rememberMe: true
)
```

Listen for `.displayCardsReady` to render masked cards from the event payload.

### Saved cards pre-checkout detection

Optional. Merchants who do **not** adopt this API keep the same checkout flow — present `SpreedlyClickToPayButton` or `SpreedlyClickToPayCheckout.present` as today.

Use `ClickToPaySavedCardsDetector` when you want to know whether this device has **Remember-me** saved cards **before** showing contact fields or opening checkout. The detector mounts a hidden MC WebView, runs `init` + `getCards` only, then calls your `onResult` once with `ClickToPaySavedCardsDetectionResult` (`hasSavedCards`, optional `savedCards` labels). It does **not** tokenize, emit checkout flow events, or present the checkout sheet.

**Android name mapping:** iOS `ClickToPaySavedCardsDetector` ↔ Android `ClickToPaySavedCardsProbe`.

```swift
import SpreedlyClickToPay

// Build from your checkout config, then adapt for the detector:
let detectorConfig = checkoutConfig.asSavedCardsDetectorConfig()

ClickToPaySavedCardsDetector(
    config: detectorConfig,
    detectorKey: deviceDetectorKey, // bump to remount after sign-out
    onResult: { result in
        if result.hasSavedCards {
            // Hide email/phone — shopper is recognized on this device
            recognizedCardLabels = result.savedCards.compactMap { card in
                guard let last4 = card.panLastFour else { return nil }
                let brand = card.cardBrand ?? "Card"
                return "\(brand) •••• \(last4)"
            }
        } else {
            // Show contact fields for idLookup on present
        }
        deviceDetectorKey = -1 // tear down before checkout
    },
    onControllerReady: { controller in
        savedCardsDetectorController = controller
    }
)
.frame(width: 0, height: 0)
.accessibilityHidden(true)
```

**Rules:**

1. **One MC flow at a time** — remove or tear down the detector (`deviceDetectorKey = -1` or let the view disappear) **before** `SpreedlyClickToPayCheckout.present` or `SpreedlyClickToPayButton` opens checkout. Both share the process MC host and cookies.
2. **No customer on detector config** — `asSavedCardsDetectorConfig()` clears `customer` so Remember-me cookies drive `getCards` without spurious `idLookup`.
3. **Sign out from detector** — `ClickToPaySavedCardsDetectorController.signOut(onComplete:)` clears the MC session without checkout; remount the detector or bump `detectorKey` to re-probe.
4. **Timeout** — if `getCards` does not complete within 30 seconds, `onResult` receives `hasSavedCards: false`.
5. **ObjC** — `ClickToPaySavedCardsDetectionResult` and `ClickToPaySavedCardsDetectorController` are `@objcMembers`; embed the SwiftUI detector via `UIHostingController` or use the Example app pattern.

The Example app Click to Pay sandbox demonstrates recognized-device UI (hide contact fields when saved cards exist, **Use a different email** link to sign out and re-probe).

### Headless tokenize

After `.checkoutComplete(checkoutId, metadata)` on a headless `ClickToPayCheckoutController`, pass billing with **required** `firstName` and `lastName`. Address and other fields are optional — only values you set on `ClickToPayTokenizeBilling` are sent.

```swift
var billing = ClickToPayTokenizeBilling()
billing.firstName = "Jane"
billing.lastName = "Doe"
billing.email = "shopper@example.com"
// billing.addressLine1 = "..." // optional

controller.tokenize(
    verificationValue: cvv,
    billing: billing.toBillingFields(),
    paymentMetadata: ["order_id": "12345"]
)
// Then await subscribeToPaymentResults for the token
```

Or call `Spreedly.shared().createClickToPayPaymentMethod(clickToPay: metadata, verificationValue: cvv, billing: billing.toBillingFields())`.

### Manual card entry (headless)

When driving a custom UI, `ClickToPayCheckoutController` exposes:

- `showManualCardEntry()` / `dismissManualCardEntry()` — toggle native SPL card form
- `setPendingVerificationValue(_:)` — stash CVV for the next checkout or tokenize call

### Re-presenting checkout

Calling `present` while a session is active replaces the previous checkout (`cancel(emitCancelled: false)` internally). Check `SpreedlyClickToPayCheckout.isActive` before presenting if you need to guard double-taps.

### `ClickToPayCheckoutViewController` (UIKit / ObjC)

| API | Behavior |
|-----|----------|
| `presentWithConfig:from:` | Singleton full-screen sheet — same as `SpreedlyClickToPayCheckout.present`. Set `SpreedlyClickToPayCheckout.delegate` before present for `ClickToPayDelegate` callbacks (iframe `Spreedly.on` parity). |
| `initWithConfig:` + embed in your hierarchy | Headless WebView host; calls `beginCheckout()` on load. Set `clickToPayDelegate` for flow events. Dismisses on terminal `PaymentResult` (success or failure) from `subscribeToPaymentResults` / `paymentDelegate`. |

The Swift and Objective-C Example apps include Click to Pay sandbox harnesses with event logging.

---

## SwiftUI Integration

```swift
import SpreedlyClickToPay
import SpreedlyCore

struct CheckoutView: View {
    private let config = makeConfig()

    var body: some View {
        SpreedlyClickToPayButton(checkoutConfig: config)
            .onAppear {
                _ = Spreedly.shared().subscribeToPaymentResults { result in
                    if result.isSuccess, let token = result.token {
                        // purchase with token
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
            customer: ClickToPayCustomer(email: "shopper@example.com"),
            dpaPresentationName: "Your Store",
            tokenizeBilling: billing
        )
    }
}
```

---

## UIKit / Swift Integration

```swift
var billing = ClickToPayTokenizeBilling()
billing.firstName = "Jane"
billing.lastName = "Doe"
let config = ClickToPayCheckoutConfig(
    initConfig: ClickToPayInitConfig(amountCents: 9900),
    srcDpaId: "your-sandbox-or-production-dpaid",
    customer: ClickToPayCustomer(email: "shopper@example.com"),
    dpaPresentationName: "Your Store",
    tokenizeBilling: billing
)
let buttonVC = SpreedlyClickToPayButtonViewController(checkoutConfig: config)
addChild(buttonVC)
stack.addArrangedSubview(buttonVC.view)
buttonVC.didMove(toParent: self)
```

---

## Objective-C Integration

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

For advanced sheet-only integration, use `[ClickToPayCheckoutViewController presentWithConfig:config from:self]`. For headless UI, embed `[[ClickToPayCheckoutViewController alloc] initWithConfig:config]` and set `clickToPayDelegate`. See [Objective-C — Click to Pay](objective-c.md#click-to-pay).

---

## Differences from Web iframe

| Topic | Web iframe | iOS SDK |
|-------|------------|---------|
| Merchant button | `<src-button>` + `onclick` → `c2pInit` | `SpreedlyClickToPayButton` |
| `lib.js` on merchant page | Loaded before click | Loaded in checkout sheet only (`c2p-host.html`) |
| Presenter | `Spreedly.c2pInit` | Button tap → internal `present` (advanced: call `present` directly) |
| Config | `options` object | `ClickToPayCheckoutConfig` |
| Card-only | Separate integration | Use `CardFormDropIn` or headless card APIs — not inside C2P |
| Events | `Spreedly.on(event, fn)` | `SpreedlyClickToPayCheckout.events` or `ClickToPayDelegate` (sheet **and** headless VC) |

---

## Important Notes

- **Tokenize billing** — set `config.tokenizeBilling` with `firstName` and `lastName` before checkout completes. Those names prefill the cardholder fields on the native new-user card form; shoppers can change them before enrollment. The SDK does not fill address defaults; unset optional billing fields are omitted from the tokenize request.
- **Only tokenize on `COMPLETE`** — other action codes emit events and reset UI.
- **Amount** — use `ClickToPayInitConfig(amountCents:)`; SDK converts to MC major units.
- **Lookup** — iframe parity: `getCards` first, then `idLookup` when empty and customer is valid. Phone lookup requires country code.
- **Card-only checkout** — use [`CardFormDropIn`](getting-started.md), not guest checkout inside C2P.
- **Do not log** raw CVV, PAN, or full tokens.

### Blocked devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK blocks Click to Pay at button tap and `present`. No sheet is shown; `ClickToPayEvent.error` / `.validationErrors` are emitted and a `PaymentResult.failure` is published on `subscribeToPaymentResults`. See [Security — Runtime Integrity](security.md#runtime-integrity).

---

## Returning users and OTP

Returning shoppers skip OTP when Mastercard `getCards()` returns saved cards from a **Remember-me device cookie**. Optionally run [`ClickToPaySavedCardsDetector`](#saved-cards-pre-checkout-detection) on screen load to adapt merchant contact UI before checkout.

| Shopper action (MC WebView OTP) | Next checkout |
|--------------------------------|---------------|
| **Remember me checked** + full checkout completed | Saved cards load — **no OTP** |
| **Remember me unchecked** | `idLookup` runs — **OTP required** |

Merchants do **not** configure Remember-me persistence. `config.otp.rememberMe` only controls an optional duplicate toggle on the native saved-card CVV bar.

`deviceRecognized` on `.sessionDeleted` (after sign-out) is not the same as OTP skip — it reflects MC device recognition at sign-out time.

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| MC `init` fails | Valid `srcDpaId`, sandbox vs production, ATS |
| Tokenize HTTP 422 | C2P enabled on environment key; confirm `firstName` and `lastName` on `tokenizeBilling` |
| Tokenize fails before network / “First name and last name are required” | Set `tokenizeBilling.firstName` and `.lastName` on `ClickToPayCheckoutConfig` (or pass billing to `createClickToPayPaymentMethod`) |
| OTP never shows | Email/phone enrolled in sandbox |
| Identity form keeps showing | Provide valid email, or phone **and** country code on `ClickToPayCustomer` before present, or complete the native Look up step |
| Phone lookup ignored | `countryCode` is required when using phone without email |
| OTP every visit despite checking Remember me | Complete a full saved-card checkout after OTP; verify the MC widget was checked. Unchecked Remember me always requires OTP on the next visit. |
| Remember Me on native CVV bar | Set `otp.rememberMe = true` to show the optional native toggle (MC OTP widget always offers Remember me) |
| Sheet does not appear (SwiftUI) | Use `present(config:from:)` with a visible view controller, or ensure a key window exists. `present(config:)` without `from:` publishes `PaymentResult.failure` when no top view controller is found. |
| No delegate callbacks (ObjC/UIKit sheet) | Set `SpreedlyClickToPayCheckout.delegate` before `presentWithConfig:from:` (or use embedded VC with `clickToPayDelegate`) |
| Payment error during tokenize | Inline error on the sheet during processing; cancel and call `present` again for a full retry. |
| Tokenize hangs after COMPLETE | Auto-tokenize times out after 120 seconds; check CVV collection and `subscribeToPaymentResults` |
| Blank DCF / OTP area (MC chrome only) | Ensure the WebView keeps full height during checkout (native card form must not collapse it). Retry after dismissing the keyboard. |

---

## Related Documentation

- [Objective-C](objective-c.md)
- [Getting Started](getting-started.md)

