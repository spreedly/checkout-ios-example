# Migration from legacy iframe-ui

If you integrated Spreedly [iframe-ui](https://developer.spreedly.com/docs/iframe-ui) on the web, use this guide to move to native **`SPLTextField`** (headless) or **`CardFormDropIn`** (pre-built express UI) on iOS.

Match **outcomes** (tokenize, validation, PCI boundaries), not identical JavaScript method names.

## Who this guide is for

| You used… | This guide covers… |
|-----------|-------------------|
| **iFrame v1** hosted fields (`iframe-v1.min.js`, separate number + CVV iframes) | Yes — full mapping below |
| **SpreedlyExpress** checkout button (`SpreedlyExpress.onPaymentMethod`) | **No** — use [Express Checkout](../express-checkout.md) for the native drop-in; this guide is for per-field iframe parity |
| ACH, full 3DS, offsite, APM | Brief pointers only — see dedicated guides linked from [getting-started.md](../getting-started.md) |

Official legacy references: [iFrame UI](https://developer.spreedly.com/docs/iframe-ui), [iFrame events](https://developer.spreedly.com/docs/iframe-events).

---

## Start here

Five steps to replace iframe hosted fields on iOS:

1. **App launch** — `Spreedly.initializeSDK()` once. See [Basic setup](../getting-started.md#basic-setup).
2. **Before checkout** — your server returns signed credentials; call **`Spreedly.setup(config:)`** (Swift) or **`setupWithConfig(_:)`** (Objective-C).
3. **Choose UI** — **`CardFormDropIn`** (fastest) **or** headless **`SPLTextField`** (iframe-style per-field callbacks). See [Choose your path](#choose-your-path-headless-vs-express).
4. **Tokenize** — `Spreedly.shared().createCreditCard(...)` and listen on **`subscribeToPaymentResults`** (Swift) or **`paymentDelegate`** (ObjC). There is no `createPaymentMethod` on iOS.
5. **Leave checkout** — `Spreedly.shared().reset()` (alias `resetPaymentState()`). There is no `destroy()` — the SDK singleton stays alive. See [SDK lifecycle](../getting-started.md#sdk-lifecycle).

> Gate checkout on **`Spreedly.isInitialized`**. Setup and lifecycle details: [getting-started.md](../getting-started.md#basic-setup).

| Legacy iframe | iOS equivalent |
|---------------|----------------|
| `ready` | **`Spreedly.isInitialized`** after **`setup(config:)`** succeeds |
| `destroy` / remove iframe | **Platform** — no `destroy()`; use `reset()` + remove native fields; re-**`setup(config:)`** when you need fresh auth |

---

## Quick legacy → iOS cheat sheet

| Legacy (iframe v1) | iOS SDK |
|--------------------|---------|
| `Spreedly.init(...)` | `SpreedlyConfig` + **`Spreedly.setup(config:)`** |
| `Spreedly.on('ready')` | **`Spreedly.isInitialized`** after **`setup(config:)`** — see [Basic setup](../getting-started.md#basic-setup) |
| `fieldEvent` / `inputProperties` | **`onFieldStateChange { HostedFieldState }`** (headless only) |
| `Spreedly.validate()` | **`Spreedly.areAllFieldsValid(fieldTypes:)`** |
| `Spreedly.tokenizeCreditCard()` | **`Spreedly.shared().createCreditCard(...)`** + **`subscribeToPaymentResults`** |
| `paymentMethod` event | **`PaymentResult`** success on payment stream |
| `Spreedly.setNumberFormat(...)` | **`Spreedly.shared().setNumberFormat(_:)`** or **`setNumberFormat(type:)`** |
| `Spreedly.toggleMask()` | **`Spreedly.shared().toggleMask()`** |
| `Spreedly.setRecache` / `recache` | **`recachePaymentMethod`** + **`subscribeToRecacheResults`** |
| `Spreedly.reload()` | **`resetPaymentState()`** + new signed auth → **`setup(config:)`** |
| Express sheet survives rotation | **Automatic** in **`CardFormDropIn`** / **`CardFormDropInViewController`** — no merchant API |
| Clear fields but keep mask/format | **`resetPaymentFormPreservingDisplayConfig()`** |

---

## Choose your path: headless vs express

| Capability | Headless `SPLTextField` / `SPLTextFieldViewController` | Express `CardFormDropIn` |
|------------|--------------------------------------------------------|---------------------------|
| Fastest path to tokenize | More wiring | **Yes** — built-in form + submit |
| `onFieldStateChange` / `HostedFieldState` | **Yes** | **No** |
| `HostedFieldState.iin` (BIN prefix while typing) | **Yes** — `HostedFieldState.iin` on card-number events | **No** — use headless or backend BIN |
| Custom `trailingIcon` / brand artwork | **Yes** (`.cardNumber` only) | Built-in label only |
| `onFocusChanged` / `onInputLength` | **Yes** | **No** |
| `setNumberFormat` / `toggleMask` from merchant UI | **Yes** | **Yes** — call from UI **outside** the sheet |
| In-field mask eye | **No** — merchant UI + `toggleMask()` | Same |

**Rule of thumb:** iframe merchants who relied on **`fieldEvent`** per keystroke → **headless**. Merchants who only need a working card form → **express**.

Deep dives: [Custom Payment Forms](../custom-payment-forms.md) (headless), [Express Checkout](../express-checkout.md) (drop-in).

---

## Not the same as iframe

Read this before coding — intentional differences from iframe v1 (by design, not missing card features).

**Status** (in the **Status** column of mapping tables below):

- **Parity** — Supported with an iOS-first API or pattern.
- **Platform** — Same outcome via iOS/UIKit idioms (not a JS-shaped API).
- **Gap** — No equivalent today; read **Notes** for what to do instead.
- **N/A** — Web-only or not meaningful on iOS.

### iframe `inputProperties` flags → iOS (what is similar)

Legacy iframe sends one JSON blob per `fieldEvent` with separate booleans. **iOS still validates the same rules** — it exposes a different shape:

| Legacy iframe property | Similar on iOS? | Use on iOS instead |
|------------------------|-----------------|-------------------|
| `inputProperties.validNumber` | **Yes** (combined) | **`HostedFieldState.isValid`** on the card-number field (plus **`numberLength`**, **`cardScheme`**) |
| `inputProperties.validCvv` | **Yes** (combined) | **`HostedFieldState.isValid`** on the CVC field (plus **`cvvLength`**) |
| `inputProperties.luhnValid` | **Yes** (combined) | **`HostedFieldState.isValid`** — Luhn and scheme-specific rules run inside validation; there is **no** separate `luhnValid` property |
| `inputProperties.cardType` | **Yes** | **`HostedFieldState.cardScheme`** |
| `inputProperties.numberLength` / `cvvLength` | **Yes** | **`HostedFieldState.numberLength`** / **`cvvLength`** (digit counts only) |
| `inputProperties.iin` | **Yes** | **`HostedFieldState.iin`** (headless card number only) |
| `setValue('number' \| 'cvv', …)` | **No** (intentional) | User typing + Wallet/autofill only — no programmatic PAN/CVV API |

You **cannot** mirror iframe logic that branches on `luhnValid` separately from `validNumber` (e.g. show “checksum failed” while length rules still pass). Use **`isValid`** and your own copy, or **`onValidationChange`**.

All **Gap** and **N/A** iframe APIs are listed in the [1:1 mapping tables](#legacy-iframe-javascript-11-mapping) below — not only in this summary.

| Legacy iframe | iOS SDK today | Status |
|---------------|---------------|--------|
| Single `inputProperties` on every event | **`HostedFieldState`** + **`areAllFieldsValid(fieldTypes:)`** | Platform |
| `fieldEvent` on express only | **`CardFormDropIn`** has no **`onFieldStateChange`** — use headless | Platform |

Use **`onFieldStateChange`** for scheme and digit **counts** — never log raw PAN/CVV or parse **`onChange`** ciphertext (opaque on `.cardNumber` and `.cvc`).

---

## Legacy iFrame (JavaScript) 1:1 mapping

If you integrated **Spreedly iFrame v1** (`iframe-v1.min.js`) in a WebView or mobile browser, use these tables to find the Checkout **iOS** pattern. Official legacy references: [iFrame UI](https://developer.spreedly.com/docs/iframe-ui), [iFrame events](https://developer.spreedly.com/docs/iframe-events).

### Step-by-step by topic

### Initialization and configuration

| If you previously used… | Use this in iOS SDK… | Notes | Status |
|---------------------------|----------------------|-------|--------|
| `Spreedly.init(environmentKey, { nonce, signature, certificateToken, timestamp, numberEl, cvvEl, … })` | **`SpreedlyConfig`** + **`Spreedly.setup(config:)`** (Swift) or **`setupWithConfig(_:)`** (ObjC) | [Basic setup](../getting-started.md#basic-setup). Add **`SPLTextField`** or **`CardFormDropIn`** — no DOM element ids. | Platform |
| `Spreedly.on('ready', fn)` | After **`setup(config:)`** succeeds | Use **`Spreedly.isInitialized`** or your own flag — no global `ready` callback. | Platform |
| `Spreedly.setLabel` / `setPlaceholder` | `title:` / `placeholder:` on **`SPLTextField`**; **`DropInCoreFieldLabels`** on express | See [Theme and Styling](../theme-and-styling.md). | Parity |
| `Spreedly.setStyle(field, css)` | **`SpreedlyTheme`** / **`SpreedlyThemeManager`** | Map CSS to theme tokens. | Platform |
| `Spreedly.setNumberFormat('prettyFormat' \| 'plainFormat' \| 'maskedFormat')` | **`Spreedly.shared().setNumberFormat(_:)`** (`.pretty` / `.plain` / `.masked`); ObjC: **`setNumberFormatWithCardNumberFormatRawValue:`** or **`setNumberFormatWithType:`**; Swift: **`setNumberFormat(type:)`** | See [iframe `prettyFormat` vs iOS `.pretty`](../custom-payment-forms.md#display-formats). **`toggleMask`** = plain ↔ masked (not Pretty). | Parity |
| `Spreedly.toggleMask()` | **`Spreedly.shared().toggleMask()`** on main thread | Coupled PAN + CVV; merchant UI outside fields. | Parity |
| `Spreedly.transferFocus(field)` | **`shouldFocus: true`** on SwiftUI **`SPLTextField`** or **`SPLTextFieldViewController`** (UIKit / ObjC) | **`becomeFirstResponder()`** still works on the view controller. | Parity |
| `Spreedly.toggleAutoComplete()` | **`enableAutofill: false`** on headless fields or **`CardFormDropInDisplayConfig.enableAutofill`** | Legacy autofill off. | Parity |
| `Spreedly.setParam(name, value)` | **`Spreedly.shared().setParam(parameter: .allowBlankName \| .allowExpiredDate \| .allowBlankDate \| .allowInternationalZipCodes, value:)`** | Typed **`ValidationParam`**. | Parity |

### Validation and field state (headless)

| If you previously used… | Use this in iOS SDK… | Notes | Status |
|---------------------------|----------------------|-------|--------|
| `Spreedly.validate()` + `validation` event (`inputProperties`) | **`Spreedly.areAllFieldsValid(fieldTypes:)`**; **`onValidationChange`**; **`createCreditCard`** → **`PaymentProcessingResult.validationFailed`** | Per-field booleans + aggregate; **no** single `inputProperties` object. Use **`HostedFieldState`** while typing. | Parity |
| `fieldEvent` with `input` + `inputProperties.cardType` / `validNumber` / `validCvv` | **`onFieldStateChange { HostedFieldState }`** (plus **`onChange`** / **`onValidationChange`** if you split concerns) | **`HostedFieldState`** bundles scheme, digit **lengths**, **`iin`**, **`isValid`**, focus, mask — **no** separate `validNumber` / `validCvv` / `luhnValid` bits. Brand **icons** are still merchant assets. | Platform |
| `inputProperties.iin` (6–8 digits while typing) | **`HostedFieldState.iin`** on card-number snapshots | Merchant-safe prefix only (not full PAN); `nil` when fewer than six digits. Omitted from `HostedFieldState` debug description. | Parity |
| `inputProperties.numberLength` / `cvvLength` | **`HostedFieldState.numberLength`** / **`cvvLength`** (digit counts) | Do **not** infer lengths from **`onChange`** ciphertext on PAN/CVC. | Platform |
| `fieldEvent` `focus` / `blur` | **`HostedFieldEventType.focus`** / **`.blur`**, or **`onFocusChanged`** | Same semantics as iframe focus/blur. | Platform |
| `fieldEvent` `mouseover` / `mouseout` | — | Desktop-only hover; not emitted on iOS. | N/A |
| `inputProperties.luhnValid` | **`HostedFieldState.isValid`** | **Similar on iOS:** Luhn + length + scheme rules run inside **`isValid`**. **Not exposed:** separate `luhnValid` boolean. | Platform |
| `setValue('number', …)` / `setValue('cvv', …)` | Not exposed | Sensitive fields accept user input and autofill only — no programmatic `setValue` (PCI). | Gap |

### Tokenization, reset, and listeners

| If you previously used… | Use this in iOS SDK… | Notes | Status |
|---------------------------|----------------------|-------|--------|
| `Spreedly.tokenizeCreditCard()` | **`Spreedly.shared().createCreditCard(...)`** / **`createCreditCardObjC(...)`** + **`subscribeToPaymentResults`** or **`paymentDelegate`** | Async **`PaymentResult`**. | Parity |
| `eligible_for_card_updater` | **`eligibleForCardUpdater`** on **`createCreditCard`** / **`createCreditCardObjCWithAdditionalFields:metadata:eligibleForCardUpdater:`** | Typed param wins over conflicting metadata. | Parity |
| `Spreedly.reload()` | **`resetPaymentState()`** + new signed auth → **`Spreedly.setup(config:)`** | Unlike iframe `reload()` (DOM remount), iOS keeps one `Spreedly` instance — **`setup`** rotates signing; `resetPaymentState` alone does not. Successful **`createCreditCard`** calls **`resetPaymentFormPreservingDisplayConfig()`** (fields only, mask/format kept). **Express rotation:** automatic in **`CardFormDropIn`**. | Platform |
| *(no iframe equivalent)* | **`resetPaymentFormPreservingDisplayConfig()`** | Clears field values and validation; **keeps** `setNumberFormat` / `toggleMask`. [When it runs](../custom-payment-forms.md#when-preserving-display-config-reset-runs). | Platform |
| Express rotation while sheet open | *(automatic)* | **`CardFormDropIn`** keeps typed fields on rotation — no merchant API. Does **not** restore PAN after dismiss. [Sheet lifecycle](../express-checkout.md#sheet-lifecycle). | Platform |
| `Spreedly.removeHandlers()` / `off` | Cancel Combine **`AnyCancellable`** subscriptions | No global event bus. | Platform |
| `destroy` | **`reset()`** + remove views; re-**`setup(config:)`** for new auth | No public **`destroy()`**. | Platform |

### Recache, errors, 3DS

| If you previously used… | Use this in iOS SDK… | Notes | Status |
|---------------------------|----------------------|-------|--------|
| `recacheReady` | Add **`SpreedlyCVVRecachingView`** / **`CVVRecachingView`** (or **`CVVRecachingViewController`**) + **`setup`** before **`recachePaymentMethod`** | There is **no** `recacheReady` event name — readiness is structural (submit disabled until CVV valid). See [Recaching → Web iframe parity](../recaching.md#web-iframe-parity). | Platform |
| `recache` success | **`recachePaymentMethod`** + **`subscribeToRecacheResults`** / **`recacheDelegate`** | **Not** on payment stream. | Parity |
| `errors` | **`PaymentResult`** failure + **`APIErrorHandler`** | [Error handling](../error-handling.md). | Parity |
| `paymentMethod` | **`PaymentResult`** success | Token + payload. | Parity |
| `3ds:status` | **`subscribeToThreeDSChallengeResults`** + gateway APIs | [3DS Global](../3ds-global.md), [3DS Gateway-Specific](../3ds-gateway-specific.md). | Platform |
| `fraud:token` | Braintree device data ([Braintree APM](../braintree-apm.md)); gateway fraud via 3DS/APM modules | Different fraud integrations; not a drop-in `fraud:token`. **No Stripe Radar module on iOS.** | Gap |
| `consoleError` | (no merchant hook) | Use Spreedly support + your own crash reporting for **app** code. | N/A |

---

## Mask and display (iframe `toggleMask` / `setNumberFormat`)

The iframe has **no eye icon** inside number or CVV iframes. Mask/reveal is **merchant-owned UI** calling **`Spreedly.shared().setNumberFormat(_:)`** or **`toggleMask()`** on the **main thread**.

> **iframe `prettyFormat` vs iOS `.pretty`**
>
> - **Match:** grouped spaced digits with the **full PAN visible** on focus and blur (iframe `prettyFormat`).
> - **Use `.plain`** when you want all digits visible **without** spacing (iframe `plainFormat`).
> - **Use `.masked`** or **`toggleMask()`** for `*` on every digit (iframe `maskedFormat` / `toggleMask`).
> - **`setNumberFormat(.pretty)` from masked** unmasks the PAN only; CVV may stay masked until you set plain/masked or call **`toggleMask()`**.
> - **`toggleMask()` does not select Pretty** — call **`setNumberFormat(.pretty)`** for grouped spacing.
>
> Full table: [Display formats](../custom-payment-forms.md#display-formats).

```swift
SPLTextField(type: .cardNumber, title: "Card number", isRequired: true)
SPLTextField(type: .cvc, title: "CVC", isRequired: true)

Spreedly.shared().setNumberFormat(.pretty)   // iframe prettyFormat — grouped, all digits visible
Spreedly.shared().setNumberFormat(.plain)    // iframe plainFormat
Spreedly.shared().setNumberFormat(.masked)   // iframe maskedFormat — `*` on PAN + CVV

Button("toggleMask()") { Spreedly.shared().toggleMask() }  // plain ↔ masked (not Pretty)
```

**Objective-C:**

```objc
[[Spreedly shared] setNumberFormatWithCardNumberFormatRawValue:2]; // 0=pretty, 1=plain, 2=masked
[[Spreedly shared] setNumberFormatWithType:@"maskedFormat"];
[[Spreedly shared] toggleMask];
```

Read **`Spreedly.shared().hostedCardDisplayState`** for UI labels only — do not assign mask flags directly. Full reference: [PAN/CVV display](../custom-payment-forms.md#pancvv-display-iframe-and-web-hosted-field-parity).

> **PAN + CVV share one display state:** **`Spreedly.shared().setNumberFormat`** / **`toggleMask`** apply to **both** headless `.cardNumber` and `.cvc` fields. Unlike separate iframe embeds with per-field state.

**`SPLTextField.forceMaskOnLifecycleStop`** (default `true`) — masks revealed PAN when the app backgrounds; does not replace **`toggleMask()`**. See CHANGELOG.

**Express:** seed layout with **`CardFormDropInDisplayConfig(cardNumberFormat:)`**; mask APIs still apply from merchant UI outside the sheet.

---

## Field-state observability (headless)

Legacy `fieldEvent` / `inputProperties` let merchants drive BIN UX, pay-button state, and validation while typing. **iOS today (headless):**

- Use **`SPLTextField.onFieldStateChange`** with **`HostedFieldState`** — preferred iframe-style channel: `INPUT`, `FOCUS`, `BLUR`, `VALIDATION`, `PAN_MASK_CHANGED`; includes **`cardScheme`**, **`numberLength`** / **`cvvLength`**, **`iin`**, **`isValid`**, **`isEmpty`**, **`isFocused`**, **`isPanMasked`**.
- **`HostedFieldState.isValid`** replaces iframe **`validNumber`**, **`validCvv`**, and **`luhnValid`** (validation still runs; booleans are combined).
- The SDK **does not** ship brand image assets — use **`trailingIcon`** (SwiftUI) or **`trailingIconViewFactory`** (UIKit) on **`.cardNumber`** only.

| Signal | Merchant-visible? | Notes |
|--------|-------------------|--------|
| **`onFieldStateChange(HostedFieldState)?`** | Yes | **Preferred** — same role as iframe `fieldEvent` + `inputProperties` |
| **`onChange`** | Yes (ciphertext on PAN/CVC) | Do **not** log or parse for display; use **`onFieldStateChange`** for lengths |
| **`onValidationChange(Bool)?`** | Yes | Per-field validity; also on **`HostedFieldState.isValid`** |
| **`Spreedly.areAllFieldsValid(fieldTypes:)`** | Yes | Pre-submit aggregate (**main thread**) |
| **`onInputLength`** | Yes | Digit count for card/CVC before secure storage (counts only) |
| **`PaymentProcessingResult.validationFailed`** | Yes | Use **`getInvalidFieldTypes()`** after failed submit |
| Hosted-field interaction telemetry | **Internal** | **Not** a supported merchant API |

> **Iframe event names → Swift cases:** `INPUT` → `.input`, `FOCUS` → `.focus`, `BLUR` → `.blur`, `VALIDATION` → `.validation`, `PAN_MASK_CHANGED` → `.panMaskChanged`. The tables in this guide use iframe-style names for parity; Swift code compares against the `HostedFieldEventType` enum cases. Objective-C reads the enum's raw value or `HostedFieldEventType...` constants.

**Card brand while typing:** **`HostedFieldState.cardScheme`** + optional **`trailingIcon:`** (SwiftUI) or **`trailingIconViewFactory`** (UIKit) on **headless** PAN field only. SDK does not ship brand image assets.

**SwiftUI vs UIKit / Objective-C:**

| SwiftUI | UIKit / Objective-C |
|---------|---------------------|
| `onFieldStateChange` | `onFieldStateChange` or **`hostedFieldStateListener`** |
| `onChange` | **`fieldTextChangeListener`** |
| `trailingIcon` | **`trailingIconViewFactory`** |
| `shouldFocus` | **`shouldFocus`** on view controller (or **`becomeFirstResponder()`**) |

### Code samples (headless)

```swift
@State private var cardBrand: CardType?

SPLTextField(
    type: .cardNumber,
    title: "Card number",
    isRequired: true,
    onFieldStateChange: { state in
        if state.fieldType == .cardNumber {
            cardBrand = state.cardScheme
        }
    },
    trailingIcon: { scheme in
        Image(systemName: iconName(for: scheme))
    }
)
```

```swift
// Pre-submit gate — mirrors iframe validNumber / validCvv / luhnValid → use isValid (one flag per field)
var cardValid = false
SPLTextField(type: .cardNumber, title: "Card number", isRequired: true,
    onFieldStateChange: { state in
        if state.eventType == .validation || state.eventType == .input {
            cardValid = state.isValid
        }
    })
// guard cardValid && Spreedly.areAllFieldsValid(fieldTypes: [.cardNumber, .expirationMonth, .expirationYear, .cvc])
```

**Objective-C:**

```objc
fieldVC.onFieldStateChange = ^(HostedFieldState *state) { /* ... */ };
// Or: fieldVC.hostedFieldStateListener = self;  // HostedFieldStateListener
```

**UIKit wrapper:**

```swift
let fieldVC = SPLTextFieldViewController(field: .cardNumber, title: "Card number", isRequired: true, placeholder: nil, onValidationChange: nil)
fieldVC.onFieldStateChange = { state in /* HostedFieldState */ }
```

See [custom-payment-forms.md](../custom-payment-forms.md) and [express-checkout.md](../express-checkout.md).

---

## Hosted field observability (summary)

| Legacy iframe | iOS equivalent |
|---------------|----------------|
| `fieldEvent` + `inputProperties.cardType` / `validNumber` / `validCvv` | **`onFieldStateChange { HostedFieldState }`** — use **`isValid`**, **`cardScheme`**, **`numberLength`** / **`cvvLength`** (no separate `validNumber` / `validCvv` / `luhnValid` flags) |
| `inputProperties.numberLength` / `cvvLength` | **`HostedFieldState.numberLength`** / **`cvvLength`** |
| `fieldEvent` `focus` / `blur` | **`HostedFieldEventType.focus`** / **`.blur`**, or **`onFocusChanged`** |
| `toggleMask` | **`Spreedly.shared().toggleMask()`** — plain ↔ masked (PAN+CVV) |
| Live `iin` | **`HostedFieldState.iin`** on headless card-number events |

### IIN while typing (headless)

Iframe **`inputProperties.iin`** maps to **`HostedFieldState.iin`** on **`SPLTextField`** / **`SPLTextFieldViewController`** **card-number** callbacks only:

| Detail | iOS behavior |
|--------|----------------|
| **When set** | `onFieldStateChange` while the customer types |
| **Length** | `nil` until **6** digits; **8** for Visa/Mastercard when enough digits are present |
| **Safe to use for** | BIN icons, routing rules, digit-count UX — **not** the full PAN |
| **Express drop-in** | No `onFieldStateChange` — use headless fields or your backend BIN API |

```swift
SPLTextField(type: .cardNumber, title: "Card number", isRequired: true,
    onFieldStateChange: { state in
        guard state.fieldType == .cardNumber, let prefix = state.iin else { return }
        // Drive BIN UI from prefix only — do not log with other payment data
    })
```

---

## API lookup (reference)

Detailed inventory and extended mapping tables. For onboarding, start with [Start here](#start-here).

### Public API inventory

Single checklist of **merchant-facing APIs** verified against the shipped SDK surface.

#### SDK-level

- **`Spreedly.isInitialized`** — `true` after successful signed **`setup`**
- **`Spreedly.setup(config:)`** / **`setupWithConfig(_:)`** — SDK configuration ([Basic setup](../getting-started.md#basic-setup))
- **`Spreedly.areAllFieldsValid(fieldTypes:)`** — aggregate validation before tokenize
- **`SpreedlyUIManager.shared.areAllFieldsValid()`** — all registered fields
- **`getRegisteredFieldCount()`** / **`getInvalidFieldTypes()`** on **`SpreedlyUIManager.shared`** — pay-button gating (ObjC: **`getInvalidFieldTypes`** returns **`NSNumber`** raw values)
- **`EmailValidator.isValid(_:)`** — optional email gate
- **`Spreedly.shared().hostedCardDisplayState`**, **`setNumberFormat(_:)`**, **`setNumberFormat(type:)`**, **`toggleMask()`**
- **`SpreedlyUIManager.shared.setHostedCardDisplayState(_:)`** / **`resetHostedCardDisplayState()`**
- **`SpreedlyUIManager.shared.applySeparatedExpirationAutofill(month:year:excluding:)`**
- **`Spreedly.shared().setParam(parameter:value:)`** — **`ValidationParam`**
- **Objective-C:** **`hostedCardDisplayCardNumberFormatRawValue`** on **`[Spreedly shared]`**

#### Headless `SPLTextField` only

- **Callbacks:** **`onFieldStateChange`**, **`onFocusChanged`**, **`onFocus`**, **`onInputLength`**, **`onValidationChange`**, **`onChange`**
- **`HostedFieldState`:** **`fieldType`**, **`eventType`**, **`isFocused`**, **`isValid`**, **`isEmpty`**, **`cardScheme`**, **`numberLength`**, **`cvvLength`**, **`isPanMasked`**, **`iin`**
- **`forceMaskOnLifecycleStop`**, **`enableAutofill`**, **`trailingIcon`** / **`trailingIconViewFactory`**
- **`HostedFieldStateListener`** / **`hostedFieldStateListener`**

#### `CardFormDropIn` only

- **`DropInCoreFieldLabels`**, **`CardFormDropInDisplayConfig`**
- **`onProcessingResult`** — immediate validation only; token on **`subscribeToPaymentResults`**
- **Not available:** **`onFieldStateChange`**, per-field focus callbacks, custom PAN **`trailingIcon`**

### Safe field-state observability (extended)

| Signal | Merchant-visible? | Notes |
|--------|--------------------|--------|
| **`onFieldStateChange(HostedFieldState)?`** | Yes | Preferred iframe-style channel |
| **`onChange`** | Yes (ciphertext on PAN/CVC) | Do not log or display |
| **`onValidationChange(Bool)?`** | Yes | Also in **`HostedFieldState.isValid`** |
| **`PaymentProcessingResult.validationFailed`** | Yes | Use **`getInvalidFieldTypes()`** after failed submit |
| **`onFieldStateChange` on `CardFormDropIn`** | **No** | Use headless |

### Extended mapping tables

#### Initialization and configuration (full)

| If you previously used… | Use this in iOS SDK… | Notes | Status |
|---------------------------|----------------------|-------|--------|
| `Spreedly.setFieldType('number'\|'cvv', …)` | Default keyboards from **`FormFieldType`**; optional **`keyboardType`** on **`SPLTextField`** | | Platform |
| `Spreedly.setTitle(field, text)` | Native accessibility patterns | No iframe `title` attribute | N/A |
| (no iframe equivalent) | **`hostedCardDisplayState`** read-only | After **`setNumberFormat`** / **`toggleMask`** | Platform |
| `Spreedly.transferFocus` on express | Not on **`CardFormDropIn`** | Internal focus chain only | Platform |
| `Spreedly.setRequiredAttribute(field)` | **`isRequired: true`** | | Parity |

#### Validation and field state (full)

Same rows as [Validation and field state (headless)](#validation-and-field-state-headless) above, plus:

| If you previously used… | Use this in iOS SDK… | Notes | Status |
|---------------------------|----------------------|-------|--------|
| Enter / Tab / Escape from iframe | **`submitLabel`**, **`onSubmit`**, focus chain between fields | Tab order is **merchant-owned** on iOS — wire card → expiry → CVC explicitly. | Platform |

#### Release notes and docs

| If you previously used… | Use this in iOS SDK… | Notes | Status |
|---------------------------|----------------------|-------|--------|
| iframe `feed.xml` / web changelog habits | [CHANGELOG](../../CHANGELOG.md) + GitHub releases on `checkout-ios-package` | Optional RSS/XML feed is **not** published from this repo today. | Gap |
| TypeScript / `@types` | Swift sources + Xcode Quick Help | Types ship with the SDK; use Xcode or doc comments. | Platform |

See also [Headless PAN API quick reference](../custom-payment-forms.md#headless-pan-api-quick-reference).
