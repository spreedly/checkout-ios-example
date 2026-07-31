# Custom Payment Fields - Spreedly iOS SDK

Build fully customized payment forms with secure individual field components.

**Estimated time:** ~15 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [SPLTextField Component](#spltextfield-component)
5. [FormFieldType Options](#formfieldtype-options)
6. [Building a Custom Form (SwiftUI)](#building-a-custom-form-swiftui)
7. [Keyboard Navigation and Focus Management](#keyboard-navigation-and-focus-management)
8. [Additional Fields (Billing/Shipping)](#additional-fields-billingshipping)
9. [UIKit Integration](#uikit-integration)
10. [Save Card Option in Custom Forms](#save-card-option-in-custom-forms)
11. [Error Handling](#error-handling)
12. [Headless PAN API quick reference](#headless-pan-api-quick-reference) — SwiftUI, UIKit, Objective-C (iframe parity)
13. [Related Documentation](#related-documentation)

---

## Introduction

### What are Custom Fields?

Custom payment fields give you per-field control over each input in your payment form. Instead of using the pre-built `CardFormDropIn` (Express Checkout), you use individual `SPLTextField` components. Each field handles its own validation, formatting, and secure storage while you control the layout, styling, and flow.

### When to Use

Choose custom fields when you need:

- **Custom layout** – Non-standard field arrangement (e.g., card number above name, different column layouts)
- **Brand-specific design** – Full control over spacing, grouping, and visual hierarchy
- **Partial form** – Only some payment fields (e.g., CVC recache, card number only)
- **Additional field logic** – Billing/shipping fields with custom validation or conditional display

### Custom vs Express Comparison

| Feature | Express (CardFormDropIn) | Custom (SPLTextField) |
|---------|--------------------------|------------------------|
| UI | Built-in, complete form | Manual layout per field |
| Validation | Automatic | Per-field callbacks |
| `onFieldStateChange` / `HostedFieldState` | — (use headless fields if needed) | ✓ per field |
| PAN mask / reveal | `setNumberFormat` / `toggleMask` on SDK state; initial format via `CardFormDropInDisplayConfig` | Card/CVC observe SDK state by default |
| Pre-submit `areAllFieldsValid` | ✓ (fields auto-register) | ✓ |
| `Spreedly.isInitialized` | ✓ | ✓ |
| Save Card checkbox | Built-in | Implement yourself |
| Integration effort | Low | Medium |
| Customization | Limited (theming, extra fields, `DropInCoreFieldLabels`) | Full control (including custom PAN brand icon) |
| Field order | Fixed | Your choice |
| Keyboard navigation | Built-in | You implement with callbacks |

See also [SDK lifecycle](getting-started.md#sdk-lifecycle) (init, leave checkout, reset vs destroy), [Express vs Custom](express-checkout.md#express-vs-custom-comparison), [Migration from legacy iframe-ui](migration/from-legacy.md), and the [Headless PAN API quick reference](#headless-pan-api-quick-reference) (SwiftUI, UIKit, Objective-C).

### Code sample — headless `SPLTextField` (field state + mask)

Iframe-style observability and mask controls on **headless** fields (not available on `CardFormDropIn`):

```swift
import SwiftUI
import SpreedlyCore
import SpreedlyUI

struct HostedFieldsForm: View {
    @State private var canPay = false

    var body: some View {
        Group {
            if !Spreedly.isInitialized {
                Text("Complete SDK setup before showing payment fields.")
            } else {
                hostedFieldsBody
            }
        }
    }

    private var hostedFieldsBody: some View {
        VStack(spacing: 12) {
            // Merchant UI outside the fields (iframe pattern)
            Picker("PAN format", selection: Binding(
                get: { Spreedly.shared().hostedCardDisplayState.cardNumberFormat },
                set: { Spreedly.shared().setNumberFormat($0) }
            )) {
                Text("Pretty").tag(CardNumberFormat.pretty)
                Text("Plain").tag(CardNumberFormat.plain)
                Text("Masked").tag(CardNumberFormat.masked)
            }
            .pickerStyle(.segmented)

            Button("Reveal / hide card number") {
                Spreedly.shared().toggleMask()  // PAN + CVC together
            }

            SPLTextField(
                type: .cardNumber,
                title: "Card number",
                isRequired: true,
                onFieldStateChange: { state in
                    // scheme, digit counts, isValid — not raw PAN
                    if state.eventType == .validation {
                        canPay = state.isValid
                    }
                }
            )
            SPLTextField(type: .cvc, title: "CVC", isRequired: true)
            SPLTextField(type: .expirationDate, title: "Expiry", isRequired: true)

            Button("Pay") {
                _ = Spreedly.shared().createCreditCard(additionalFields: [:], metadata: [:])
            }
            .disabled(
                !canPay
                    || !Spreedly.areAllFieldsValid(fieldTypes: [.cardNumber, .expirationDate, .cvc])
            )
        }
        .padding()
    }
}
```

Full API list: [docs index — public API inventory](../README.md#hosted-fields--public-api-inventory). **Default:** omit `enableAutofill` (SDK default `true`). Optional: `enableAutofill: false` per field to match legacy `toggleAutoComplete` off. See [Wallet / Keychain autofill](#wallet--keychain-autofill-legacy-toggleautocomplete).

---

## Prerequisites

Complete [getting-started.md](getting-started.md) before using custom fields. You must:

- Add SpreedlyCore, SpreedlySecurity, and SpreedlyUI to your project
- Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`)
- Call `Spreedly.setup(config:)` with signature parameters from your backend before any tokenization
- Fetch signature parameters fresh for each payment session
- Optional: check **`Spreedly.isInitialized`** after setup if you need a boolean “SDK ready” gate (same role as iframe **ready**; see [Getting Started — Basic Setup](getting-started.md#basic-setup))

> **Blocked device handling:** If you enable `blockJailbrokenDevices`, `SPLTextField` fields render as blank on compromised devices. Unlike `CardFormDropIn` (which auto-dismisses its sheet), custom forms are your UI — the SDK cannot dismiss them for you. Check `Spreedly.isDeviceTrusted` when the form appears and show an appropriate error:
>
> ```swift
> .onAppear {
>     if !Spreedly.isDeviceTrusted {
>         errorMessage = Spreedly.initializationError?.message ?? "SDK blocked by security check"
>     }
> }
> ```

---

## Quick Start

Minimal example with a single card number field. Subscribe to payment results before calling `createCreditCard()` — the method returns `PaymentProcessingResult` (validation status only); the actual token is delivered via the subscription.

```swift
import SwiftUI
import SpreedlyCore
import SpreedlyUI
import Combine

struct MinimalPaymentForm: View {
    @State private var cardNumberValid = false
    @State private var cancellable: AnyCancellable?

    var body: some View {
        VStack(spacing: 16) {
            SPLTextField(
                type: .cardNumber,
                title: "Card Number",
                isRequired: true,
                onValidationChange: { isValid in
                    cardNumberValid = isValid
                }
            )

            Button("Continue") {
                let result = Spreedly.shared().createCreditCard(
                    additionalFields: [:],
                    metadata: [:]
                )
                if result.isProcessing {
                    // Processing started -- await final result via subscription
                }
            }
            .disabled(!cardNumberValid)
        }
        .padding()
        .onAppear {
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                if result.isSuccess, let token = result.token {
                    // Payment method tokenized -- send token to your backend
                } else if result.isFailure {
                    // Handle failure
                }
            }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }
}
```

---

## SPLTextField Component

`SPLTextField` is a single unified component for all payment field types. You configure it with a `type` parameter and optional callbacks.

### Same names on SwiftUI, UIKit, and Objective-C

Use **`SPLTextField`** in SwiftUI. Use **`SPLTextFieldViewController`** in UIKit (Swift or Objective-C) — it wraps the same field.

| Feature | SwiftUI `SPLTextField` | UIKit `SPLTextFieldViewController` | SDK (`Spreedly` / manager) |
|---------|------------------------|-------------------------------------|----------------------------|
| Field snapshot (iframe `fieldEvent`) | `onFieldStateChange` | `onFieldStateChange` or `hostedFieldStateListener` | — |
| Per-keystroke (opaque card/CVC) | `onChange` | `fieldTextChangeListener` — implement **`FieldTextChangeListener`** (`onFieldTextChanged(_:text:)`) | — |
| Valid / invalid | `onValidationChange` | `onValidationChange` | — |
| Focus in only | `onFocus` | `onFocus` | — |
| Focus in and out | `onFocusChanged` | `onFocusChanged` | — |
| Digit count (card/CVV) | `onInputLength` | `onInputLength` | — |
| Move focus | `shouldFocus` | `shouldFocus` or `becomeFirstResponder()` | — |
| Brand icon (card) | `trailingIcon` | `trailingIconViewFactory` | — |
| PAN/CVV display (iframe parity) | Card + CVC follow `setNumberFormat` / `toggleMask` automatically | Same | `setNumberFormat` / `toggleMask` |
| Read mask state | `Spreedly.shared().hostedCardDisplayState` (`panMasked`, **`cvvDisplayMasked`** — read only) | ObjC: `hostedCardDisplayCardNumberFormatRawValue` (format only; no `cvvDisplayMasked` on `[Spreedly shared]`) | [read vs mask actions](#hostedcarddisplaystate-read-vs-mask-actions) |
| Merchant mask control | `toggleMask()` / `setNumberFormat(_:)` | `toggleMask` / `setNumberFormatWithType:` | — |
| Validate before pay | `Spreedly.areAllFieldsValid(fieldTypes:)` | `[Spreedly areAllFieldsValidWithFieldTypeRawValues:]` | `SpreedlyUIManager.shared.areAllFieldsValid()` / `areAllFieldsValid(fieldTypes:)` |
| Which fields failed | `getInvalidFieldTypes()` | `[[SpreedlyUIManager shared] getInvalidFieldTypes]` | same |
| SDK ready (iframe `ready`) | `Spreedly.isInitialized` | same | same |
| Email check | `EmailValidator.isValid(_:)` | `[EmailValidator isValid:]` | same |

**Merchant examples (iframe-style headless form):** see the SwiftUI and Objective-C sample screens in the Checkout iOS example app.

Both demos wire `onFieldStateChange`, `setNumberFormat`, `toggleMask`, `areAllFieldsValid`, and card brand icons. See also [Migration from legacy iframe-ui](migration/from-legacy.md#public-api-inventory).

#### `HostedFieldState` snapshot fields

Each `onFieldStateChange` (or ObjC `onFieldStateChanged:`) delivers:

| Field | Type | Notes |
|-------|------|--------|
| `fieldType` | `FormFieldType` | Which row fired the event |
| `eventType` | `HostedFieldEventType` | `.input`, `.focus`, `.blur`, `.validation`, `.panMaskChanged` |
| `isFocused` | `Bool` | Current focus |
| `isValid` | `Bool` | Validation state at event time |
| `isEmpty` | `Bool` | No user input yet |
| `cardScheme` | `CardType?` | Detected brand on card number (Swift); ObjC: `cardSchemeRawValue` |
| `numberLength` | `Int?` | PAN digit count only — **not** the PAN string |
| `cvvLength` | `Int?` | CVV digit count only |
| `isPanMasked` | `Bool` | **Card number only** — `true` when some or all PAN digits are **hidden in the field UI** at emit time (`.masked`); `false` when all digits are visible (`.pretty` / `.plain`). Always `true` on CVC — ignore there. |
| `panDisplayFormat` | `CardNumberFormat?` | **Card number only** — pretty / plain / masked at emit time. `nil` on CVC and other fields. ObjC: `panDisplayFormatRawValue`. |
| `panDisplayPolicyMaskedValue` | `Bool?` | **Card number only** — policy flag from hosted display state (`hostedCardDisplayState.panMasked`) at emit time, not “digits visible”. `nil` on CVC. Swift: use **`panDisplayPolicyMaskedValue`**; ObjC: **`panDisplayPolicyMasked`** (`NSNumber?`). |
| `iin` | `String?` | **Card number only** — issuer prefix for BIN UX (see below). Not the full PAN. |

**IIN (issuer identification number)** — iframe `inputProperties.iin` parity on **headless** card-number fields:

- Emitted on **`onFieldStateChange`** when the customer types on **`.cardNumber`**.
- **`nil`** until at least **6** digits are entered; **8** digits for Visa/Mastercard when enough digits are present.
- Safe for BIN-level UI (icons, routing rules) — never log it next to other sensitive fields.
- **Express (`CardFormDropIn`)** does not expose `onFieldStateChange` — use headless fields or your backend BIN service for the same UX.

**Never included:** raw PAN or CVV. Do not log `onChange` ciphertext for card fields.

#### What to read for mask UI {#what-to-read-for-mask-ui}

Use **`onFieldStateChange`** snapshots for checkout chrome (lock icons, format labels). Do **not** read `Spreedly.shared().hostedCardDisplayState` inside the same callback — it can lag one frame behind the field.

| Merchant need | Read this | Do not use |
|---------------|-----------|------------|
| “Card digits hidden in the field now?” | `HostedFieldState.isPanMasked` on **card number** events | `isPanMasked` on CVC (always `true`) |
| Show Pretty / Plain / Masked label | `state.panDisplayFormat` | Guessing from `isPanMasked` alone |
| Know SDK policy mask flag | `state.panDisplayPolicyMaskedValue` (Swift) / `panDisplayPolicyMasked` (ObjC) | Assigning `hostedCardDisplayState` |
| Change format or mask | `Spreedly.shared().setNumberFormat(_:)` / `toggleMask()` | Writing snapshot properties |
| CVC masked (`*` vs digits) | `Spreedly.shared().hostedCardDisplayState.cvvDisplayMasked` after `setNumberFormat` / `toggleMask` | Per-field mask params (removed) |

**Three terms:** **`isPanMasked`** = what the customer **sees** (all digits visible for `.pretty` / `.plain`; `*` hide for `.masked`). **`panDisplayPolicyMaskedValue`** = what **`setNumberFormat`** last set on `hostedCardDisplayState.panMasked`. **`panDisplayFormat`** = pretty vs plain vs masked layout.

On **`PAN_MASK_CHANGED`**, trust **`HostedFieldState`** (`isPanMasked`, `panDisplayFormat`, `panDisplayPolicyMaskedValue`) for UI updates.

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `type` | `FormFieldType` | Field type (e.g., `.cardNumber`, `.firstName`) |
| `title` | `String?` | Label above the field |
| `isRequired` | `Bool` | Whether the field is required for validation |
| `placeholder` | `String?` | Custom placeholder text. **Ignored when `type` is `.cardNumber`** — see [Card number placeholder](#card-number-placeholder-current-behavior). |
| `requiredMessage` | `String?` | Overrides the default required-field validation error (e.g. ACH flows use bank-specific copy instead of card defaults). Available on SwiftUI `SPLTextField` and UIKit/ObjC `SPLTextFieldViewController` (`requiredMessage` property). |
| `theme` | `SpreedlyTheme?` | Light mode theme |
| `darkTheme` | `SpreedlyTheme?` | Dark mode theme |
| `yearFormat` | `YearFormat` | `.twoDigit` or `.fourDigit` (default), applies to expiration fields |
| `keyboardType` | `UIKeyboardType?` | Overrides default keyboard for the field type; omit for SDK defaults (e.g. `.numberPad` for card number) |
| `textContentType` | `UITextContentType?` | Autofill hint when `enableAutofill` is `true`; ignored when `enableAutofill` is `false` |
| `enableAutofill` | `Bool` | Default `true`. `false` clears SDK credit-card `textContentType` hints (legacy `toggleAutoComplete` off). Card number still defaults to `.numberPad` when `keyboardType` is omitted. iOS may show system AutoFill in the field menu even when `false` — see [Wallet / Keychain autofill](#wallet--keychain-autofill-legacy-toggleautocomplete). |
| `onValidationChange` | `((Bool) -> Void)?` | Called when validation state changes |
| `onSubmit` | `(() -> Void)?` | Called when user presses return/submit key |
| `submitLabel` | `SpreedlySubmitLabel?` | Label on keyboard return key. Example values: `.done`, `.go`, `.next`, `.send`, `.return`. See [SpreedlySubmitLabel](#spreedlysubmitlabel-enum) for all options. |
| `shouldFocus` | `Bool` | When true, the field becomes first responder (for programmatic focus) |
| `onFocus` | `(() -> Void)?` | Called when the field gains focus. Used with `shouldFocus` for programmatic field navigation (e.g., after card number is filled, focus moves to expiration date) |
| `onFocusChanged` | `((Bool) -> Void)?` | Called when focus enters (`true`) or leaves (`false`). Prefer over `onFocus` when you need blur-aware UI |
| `onFieldStateChange` | `((HostedFieldState) -> Void)?` | Merchant-safe field snapshots (`INPUT`, `FOCUS`, `BLUR`, `VALIDATION`, `PAN_MASK_CHANGED`) with scheme, digit counts, **`iin`** (BIN prefix on card number), and `isPanMasked` on card number — no raw PAN or CVV. See [Migration from legacy iframe-ui](migration/from-legacy.md) |
| `onInputLength` | `((Int) -> Void)?` | Digit count for card number or CVV immediately before secure storage (counts only) |
| `onChange` | `((String) -> Void)?` | Optional per-keystroke value after normalization. Card number and CVV yield an **opaque SDK-encoded string** (not what appears on screen); other fields yield plaintext suitable for UX only. **Never log** this string. |
| `forceMaskOnLifecycleStop` | `Bool` | Card number only. Default `true` — force visual mask while app is backgrounded (security UX; not iframe `toggleMask`). |

#### PAN/CVV display (iframe and web hosted-field parity)

**Card number** and **CVC** `SPLTextField` rows always follow **`Spreedly.shared().setNumberFormat(_:)`** and **`Spreedly.shared().toggleMask()`** — there is no per-field observe or mask parameter (same as web `inAppElements` + global format APIs). Mount both fields, then drive display from merchant UI outside the fields.

**Effective mask** (what the user sees) is: force mask while the app is backgrounded when `forceMaskOnLifecycleStop` is enabled, **or** the current **`hostedCardDisplayState`** from `setNumberFormat` / `toggleMask`. Never puts raw PAN in `HostedFieldState` (use `isPanMasked` on snapshots instead).

**SDK-level (iframe parity)** — on the main thread.

#### `setNumberFormat` by language (pick one call per format)

| Surface | API | Example (masked) |
|---------|-----|------------------|
| **Swift** (preferred) | `setNumberFormat(_:)` | `Spreedly.shared().setNumberFormat(.masked)` |
| **Objective-C** (native) | `setNumberFormatWithCardNumberFormatRawValue:` | `[[Spreedly shared] setNumberFormatWithCardNumberFormatRawValue:2];` |
| **Objective-C** (iframe strings) | `setNumberFormatWithType:` | `[[Spreedly shared] setNumberFormatWithType:@"maskedFormat"];` |
| **Swift** (config/iframe strings only) | `setNumberFormat(type:)` | `Spreedly.shared().setNumberFormat(type: "maskedFormat")` |

**Iframe string → enum mapping** (same for `setNumberFormatWithType:` and `setNumberFormat(type:)`):

| iframe `type` | `CardNumberFormat` | ObjC raw value |
|---------------|-------------------|----------------|
| `prettyFormat` | `.pretty` | `0` |
| `plainFormat` | `.plain` | `1` |
| `maskedFormat` | `.masked` | `2` |

**Do not call two rows for the same format** — e.g. `setNumberFormat(.masked)` and `setNumberFormat(type: "maskedFormat")` together, or `setNumberFormatWithCardNumberFormatRawValue:2` and `setNumberFormatWithType:@"maskedFormat"` together. They are equivalent; one call is enough.

**Swift**

```swift
Spreedly.shared().setNumberFormat(.masked)   // .pretty / .plain / .masked
Spreedly.shared().toggleMask()               // plain ↔ masked for PAN + CVV
```

Use `setNumberFormat(type:)` in Swift only when your app still receives iframe format names from config or a legacy bridge — not alongside the enum call for the same format.

**Objective-C**

```objc
// Recommended for native ObjC (matches CardNumberFormat enum)
[[Spreedly shared] setNumberFormatWithCardNumberFormatRawValue:2]; // 0=pretty, 1=plain, 2=masked

// Or iframe string names (legacy parity, config-driven backends)
[[Spreedly shared] setNumberFormatWithType:@"maskedFormat"];

[[Spreedly shared] toggleMask];
```

Pick **raw value** or **type string**, not both, for the same format change. See [Objective-C guide](objective-c.md#pan-mask-card-number-only).

**Atomic state (Swift):** To set format and mask flags together, use **`SpreedlyUIManager.shared.setHostedCardDisplayState(_:)`** with a **`HostedCardDisplayState`**. **`SpreedlyUIManager.shared.resetHostedCardDisplayState()`** restores defaults (also available from Objective-C on the manager). Reading combined state: **`Spreedly.shared().hostedCardDisplayState`** (or the Combine publisher on **`SpreedlyUIManager.shared`**).

#### `HostedCardDisplayState` — read flags vs mask actions {#hostedcarddisplaystate-read-vs-mask-actions}

Developers often treat **`cvvDisplayMasked`** or **`panMasked`** as something to **call** to mask or unmask. They are **not APIs** — they are **read-only booleans** on the current display snapshot. The iframe had no `cvvDisplayMasked` name; native SDKs expose it so you can sync merchant UI (toggle label, icon) after the same coupled mask behavior as legacy **`setNumberFormat`** / **`toggleMask`** on number + CVV iframes.

| You want to… | Use this (main thread) | Do **not** use |
|--------------|------------------------|----------------|
| Mask or reveal **PAN + CVC display** together | **`Spreedly.shared().setNumberFormat(_:)`** (`.pretty` / `.plain` / `.masked`) or **`toggleMask()`** | `cvvDisplayMasked(...)` — not a function |
| Read whether CVC **looks** masked (`*` vs digits) | **`Spreedly.shared().hostedCardDisplayState.cvvDisplayMasked`** | Assigning on `[Spreedly shared]` — no public setter |
| Read whether PAN is in masked display mode | **`hostedCardDisplayState.panMasked`** (or **`HostedFieldState.isPanMasked`** on card-number events) | Per-field `panMasked` on `SPLTextField` (removed) |
| Read current PAN layout enum | **`hostedCardDisplayState.cardNumberFormat`** | — |

**What `cvvDisplayMasked` means**

| Value | CVC field **appearance** (display layer only) |
|-------|-----------------------------------------------|
| `true` | Masked display in the field (`***`) — default after **Masked** or mask-on **`toggleMask`** |
| `false` | Digits visible in the field (`123`) — after **`setNumberFormat(.pretty)`**, **`.plain`**, or reveal via **`toggleMask()`** |

Tokenization and secure storage are unchanged; this flag only drives how the CVC row **renders** (coupled with PAN mask APIs).

**How flags get updated** — only through mask/format **actions** (SDK writes the snapshot for you):

| Action | `panMasked` | `cvvDisplayMasked` |
|--------|-------------|-------------------|
| `setNumberFormat(.pretty)` | `false` | **unchanged** (PAN spacing only) |
| `setNumberFormat(.plain)` | `false` | `false` (reveals PAN + CVV) |
| `setNumberFormat(.masked)` | `true` | `true` |
| `toggleMask()` (from masked → plain) | `false` | `false` |
| `toggleMask()` (from plain/pretty → masked) | `true` | `true` |
| `resetPaymentState()` / defaults | `false` | `false` |

```swift
// Correct — actions change display; fields re-render
Spreedly.shared().toggleMask()

// Correct — read current snapshot for your own eye button / label
let masked = Spreedly.shared().hostedCardDisplayState.cvvDisplayMasked

// Wrong — cvvDisplayMasked is not callable and is not on Spreedly as a setter
// cvvDisplayMasked(false)   // does not exist
```

**`setNumberFormat`** sets PAN **display layout** and mask flags. **`.pretty`** unmasks PAN only (CVV mask unchanged); **`.plain`** reveals PAN + CVV; **`.masked`** hides both:

| Format | PAN (focused) | PAN (blur) | CVV |
|--------|----------------|------------|-----|
| **Pretty** (default) | Grouped, **all digits visible** (`4111 1111 1111 1111`) | Same (full spaced PAN) | Visible (`123`) |
| **Plain** | Ungrouped digits only — no spaces (`4111111111111111`) | Same | Visible (`123`) |
| **Masked** | Full hide, **no spaces** (`****************`) | Same | Masked (`***`) |

**`toggleMask()`** (merchant button — not a switch) switches **Plain+revealed ↔ Masked+hidden** for **PAN and CVV together** (iframe `plainFormat` ↔ `maskedFormat`). It does **not** select **Pretty**; use **`setNumberFormat(.pretty)`** for iframe-style grouped spacing. Display-only; tokenization still uses secure storage. Mask glyph is `*` (iframe parity).

| Parameter | Role |
|-----------|------|
| `forceMaskOnLifecycleStop` | Default `true`. Force **visual** mask while the app is backgrounded (security UX). |
| `trailingIcon` | Custom trailing content; replaces default scheme label on PAN. |

**Callbacks:**

| Callback | When |
|----------|------|
| `onFieldStateChange` | Includes `HostedFieldEventType.panMaskChanged` with `HostedFieldState.isPanMasked` (still no raw PAN). Also `INPUT`, `FOCUS`, `BLUR`, `VALIDATION`. **Only read `isPanMasked` when `fieldType == .cardNumber`** — CVC and other events always carry `isPanMasked: true`. Use separate callbacks or check `fieldType` before acting on the flag. |
| `onFocusChanged` | Focus enter/leave. |

**Headless vs express:**

| Surface | Behavior |
|---------|----------|
| Headless `SPLTextField` | Card number + CVC always follow **`setNumberFormat`** / **`toggleMask`** (no per-field mask params) |
| **`CardFormDropIn`** | Pretty + masked by default; **`setNumberFormat`** / **`toggleMask`** apply to card/CVC rows inside the sheet — use merchant UI calling **`Spreedly.shared().toggleMask()`** outside the field |

For drop-in or sheet flows, call **`setNumberFormat`** for PAN layout (pretty / plain / masked) and **`toggleMask`** for plain ↔ masked reveal on the main thread. For headless forms, wire both (e.g. segmented control for format + button for toggle); card and CVC fields observe shared display state by default.

```swift
// PAN display format (card number only)
Picker("Format", selection: Binding(
    get: { Spreedly.shared().hostedCardDisplayState.cardNumberFormat },
    set: { Spreedly.shared().setNumberFormat($0) }
)) {
    Text("Pretty").tag(CardNumberFormat.pretty)
    Text("Plain").tag(CardNumberFormat.plain)
    Text("Masked").tag(CardNumberFormat.masked)
}

// PAN + CVC reveal (iframe toggleMask)
Toggle("Show card number", isOn: Binding(
    get: { !Spreedly.shared().hostedCardDisplayState.panMasked },
    set: { showPlain in
        if showPlain == Spreedly.shared().hostedCardDisplayState.panMasked {
            Spreedly.shared().toggleMask()
        }
    }
))

SPLTextField(
    type: .cardNumber,
    title: "Card number",
    isRequired: true,
    onFieldStateChange: { state in
        guard state.fieldType == .cardNumber else { return }
        if state.eventType == .panMaskChanged {
            let digitsHidden = state.isPanMasked
            let format = state.panDisplayFormat
            let policyMasked = state.panDisplayPolicyMaskedValue ?? true
            // Update merchant chrome from snapshot only — not hostedCardDisplayState here.
            _ = (digitsHidden, format, policyMasked)
        }
    }
)

SPLTextField(type: .cvc, title: "CVC", isRequired: true)
```

For **card number only**, you can optionally replace the default trailing brand artwork with your own SwiftUI content or UIKit-built views (see below). **Omitting `trailingIcon`** keeps the built-in **`CardBrandIcon`**: full scheme name (`CardType.displayName`) in a small badge with up to **two lines** of text (express drop-in and headless both use this default).

#### Optional: merchant card brand (PAN field only)

BIN detection updates the detected `CardType` as the customer types. Use this to show **your** brand assets (from your asset catalog or design system). The SDK does not ship partner card-network artwork for the merchant override path—you map `CardType` → image via **`trailingIcon`** (legacy iframe `cardType` metadata pattern).

When you **do** supply `trailingIcon` / `trailingIconViewFactory`, you own sizing and wrapping:

- Prefer a **fixed-size image** (`Image` / `UIImageView`, e.g. 40×24 pt) per scheme when you have assets.
- For **text fallbacks**, use **short labels** (`MC`, `AMEX`) or allow **multiline** text (`lineLimit(2)`, `minimumScaleFactor`) in the size you choose—do not put a long single-line `displayName` in a tiny fixed frame (it will truncate).
- Return an empty view for `.unknown` when nothing should show.
- Size your trailing view (fixed image width or multiline text) so the PAN stays readable on narrow screens.

**SwiftUI** — use the initializer that includes `trailingIcon:` (a `@ViewBuilder` taking `CardType`):

```swift
SPLTextField(
    type: .cardNumber,
    title: "Card number",
    isRequired: true,
    trailingIcon: { scheme in
        switch scheme {
        case .visa: Image("MyVisaLogo")
        case .mastercard: Image("MyMastercardLogo")
        case .unknown: EmptyView()
        default: Image("MyGenericCard")
        }
    },
    onValidationChange: { _ in }
)
```

**UIKit / Objective-C** — on `SPLTextFieldViewController`, set **`trailingIconViewFactory`**. The factory receives the scheme **string** (`CardType`’s `rawValue`, e.g. `"visa"`, `"mastercard"`). Return a sized `UIView` (typically an `UIImageView` using your bundle images).

**Express checkout (`CardFormDropIn`)** — uses the built-in scheme label only; custom brand artwork is **headless** (`SPLTextField` / `SPLTextFieldViewController`) — see [express-checkout.md](express-checkout.md#callback-system).

#### Helper Properties and Methods

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `isValidForced` | `Bool` | Forces validation check and returns result |
| `hasValue` | `Bool` | Whether the field has a non-empty value |
| `inputLength` | `Int` | Current character count of the field's input |
| `clear()` | — | Clears the field's value |
| `reset()` / `resetPaymentState()` | — | On ``Spreedly`` — full reset: secure values, field UI, validation, and hosted PAN/CVV display (``reset()`` is an alias) |
| ``resetPaymentFormPreservingDisplayConfig()`` | — | On ``Spreedly`` — clears fields and validation; **keeps** ``setNumberFormat`` / ``toggleMask`` state |

#### Payment reset (merchant APIs) {#payment-reset-merchant-apis}

Two reset levels — pick the one that matches what you need to clear:

| API | Field values & validation | PAN/CVV display (`setNumberFormat` / `toggleMask`) |
|-----|---------------------------|-----------------------------------------------------|
| ``resetPaymentFormPreservingDisplayConfig()`` | Cleared | **Kept** |
| ``resetPaymentState()`` / ``reset()`` | Cleared | Reset to SDK defaults (Pretty, unmasked) |

##### When form reset preserving display config runs {#when-preserving-display-config-reset-runs}

| Situation | Headless (`SPLTextField`) | Express (`CardFormDropIn`) |
|-----------|---------------------------|----------------------------|
| **You call the API** | Clears fields + validation | Same |
| **Sheet / form opens** | **You** decide (no auto-call) | **Yes** — every `onAppear` clears fields, keeps mask/format |
| **Device rotation** (sheet stays open) | Fields usually stay mounted | Typed values **stay** — no clear on rotation |
| **After successful `createCreditCard`** | **Yes** — SDK runs automatically (keeps mask/format) | **Yes** — same; express also clears on **sheet open** |
| **New signed auth** | Re-**`setup(config:)`** — [SDK lifecycle](getting-started.md#sdk-lifecycle) | Same |

**Does not run:** on **`createBankAccount`** success (bank-account flow uses its own reset). **Does not** rotate signing credentials — fetch a new bundle from your server and call **`setup(config:)`** when auth must change.

Express lifecycle table: [Express Checkout — Sheet lifecycle](express-checkout.md#sheet-lifecycle).

| Concern | Headless | Express |
|---------|----------|---------|
| Drop-in dismiss | Your layout | SDK clears **secure values** on dismiss; mask/format outside the sheet unchanged |
| Full wipe including mask | ``resetPaymentState()`` | Same |

**Headless — form-only reset (keep mask/format)**

```swift
Spreedly.shared().setNumberFormat(.masked)
// user typed card data …
Spreedly.shared().resetPaymentFormPreservingDisplayConfig()
// fields empty; still Masked
```

**Headless or express — full reset**

```swift
Spreedly.shared().resetPaymentState() // alias: reset()
```

**YearFormat:** For `.expirationYear` and `.expirationDate` fields, use the `yearFormat` parameter to control whether the year is displayed and validated as 2-digit (`.twoDigit`, e.g. "25") or 4-digit (`.fourDigit`, e.g. "2025"). Default is `.fourDigit`.

---

## FormFieldType Options

Use the `type` parameter to specify the field behavior. The SDK applies validation, formatting, and secure storage based on the type.

| FormFieldType | Description | Typical Keyboard |
|---------------|-------------|------------------|
| `.firstName` | First name | `.default` |
| `.lastName` | Last name | `.default` |
| `.fullName` | Full name (single field) | `.default` |
| `.cardNumber` | Card number with formatting | `.numberPad` |
| `.expirationMonth` | Expiration month (01–12) | `.numberPad` |
| `.expirationYear` | Expiration year (2 or 4 digit) | `.numberPad` |
| `.expirationDate` | Combined expiration (MM/YY) | `.numberPad` |
| `.cvc` | Security code (CVC/CVV) | `.numberPad` |
| `.addressLine1` | Primary address | `.default` |
| `.addressLine2` | Secondary address | `.default` |
| `.city` | City | `.default` |
| `.state` | State/Province | `.default` |
| `.zipCode` | Postal/ZIP code | `.default` |
| `.routingNumber` | Bank routing number (US/Canada ACH, 9 digits) | `.numberPad` |
| `.accountNumber` | Bank account number (4–17 digits) | `.numberPad` |
| `.bankName` | Optional issuing bank name (ACH) | `.default` |

Both patterns are valid: use `.firstName` and `.lastName` for separate fields, or `.fullName` for a single combined name field.

> **ACH bank-account fields:** Use `.routingNumber`, `.accountNumber`, and `.bankName` with [ACH bank-account payments](ach-bank-account.md). Routing and account values are stored in `SecureValueContainer`; copy/cut/paste are disabled on those field types (Android parity). Stable **1.4.0** does not include ACH in the production release set — see [CHANGELOG](../CHANGELOG.md) for the current boundary.

> **Combined expiry field:** Instead of separate `.expirationMonth` and `.expirationYear` fields, you can use `.expirationDate` as a single combined MM/YY field. Use the `yearFormat` property (`.twoDigit` or `.fourDigit`) to control year display. This simplifies the form when a single expiration input is preferred.

---

## Building a Custom Form (SwiftUI)

Full example with all core payment fields, validation tracking, and submit handling:

```swift
import SwiftUI
import SpreedlyUI
import SpreedlyCore

struct CustomPaymentForm: View {
    @State private var cardNumberValid = false
    @State private var expirationMonthValid = false
    @State private var expirationYearValid = false
    @State private var cvcValid = false
    @State private var firstNameValid = false
    @State private var lastNameValid = false
    @State private var isFormValid = false
    @State private var focusedFieldType: FormFieldType?
    @State private var cancellable: AnyCancellable?

    private var fieldOrder: [FormFieldType] {
        [.firstName, .lastName, .cardNumber, .expirationMonth, .expirationYear, .cvc]
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                SPLTextField(
                    type: .firstName,
                    title: "First Name",
                    isRequired: true,
                    keyboardType: .default,
                    textContentType: .givenName,
                    onValidationChange: { isValid in
                        firstNameValid = isValid
                        updateFormValidity()
                    },
                    onSubmit: { handleFieldSubmit(for: .firstName) },
                    submitLabel: getSubmitLabel(for: .firstName),
                    shouldFocus: focusedFieldType == .firstName,
                    onFocus: { focusedFieldType = .firstName }
                )

                SPLTextField(
                    type: .lastName,
                    title: "Last Name",
                    isRequired: true,
                    keyboardType: .default,
                    textContentType: .familyName,
                    onValidationChange: { isValid in
                        lastNameValid = isValid
                        updateFormValidity()
                    },
                    onSubmit: { handleFieldSubmit(for: .lastName) },
                    submitLabel: getSubmitLabel(for: .lastName),
                    shouldFocus: focusedFieldType == .lastName,
                    onFocus: { focusedFieldType = .lastName }
                )
            }

            SPLTextField(
                type: .cardNumber,
                title: "Card Number",
                isRequired: true,
                keyboardType: .numberPad,
                textContentType: .creditCardNumber,
                onValidationChange: { isValid in
                    cardNumberValid = isValid
                    updateFormValidity()
                },
                onSubmit: { handleFieldSubmit(for: .cardNumber) },
                submitLabel: getSubmitLabel(for: .cardNumber),
                shouldFocus: focusedFieldType == .cardNumber,
                onFocus: { focusedFieldType = .cardNumber }
            )

            HStack(spacing: 16) {
                SPLTextField(
                    type: .expirationMonth,
                    title: "Month",
                    isRequired: true,
                    keyboardType: .numberPad,
                    onValidationChange: { isValid in
                        expirationMonthValid = isValid
                        updateFormValidity()
                    },
                    onSubmit: { handleFieldSubmit(for: .expirationMonth) },
                    submitLabel: getSubmitLabel(for: .expirationMonth),
                    shouldFocus: focusedFieldType == .expirationMonth,
                    onFocus: { focusedFieldType = .expirationMonth }
                )

                SPLTextField(
                    type: .expirationYear,
                    title: "Year",
                    isRequired: true,
                    keyboardType: .numberPad,
                    onValidationChange: { isValid in
                        expirationYearValid = isValid
                        updateFormValidity()
                    },
                    onSubmit: { handleFieldSubmit(for: .expirationYear) },
                    submitLabel: getSubmitLabel(for: .expirationYear),
                    shouldFocus: focusedFieldType == .expirationYear,
                    onFocus: { focusedFieldType = .expirationYear }
                )
            }

            SPLTextField(
                type: .cvc,
                title: "Security Code",
                isRequired: true,
                keyboardType: .numberPad,
                textContentType: .creditCardSecurityCode,
                onValidationChange: { isValid in
                    cvcValid = isValid
                    updateFormValidity()
                },
                onSubmit: { handleFieldSubmit(for: .cvc) },
                submitLabel: getSubmitLabel(for: .cvc),
                shouldFocus: focusedFieldType == .cvc,
                onFocus: { focusedFieldType = .cvc }
            )

            Button("Pay Now") {
                submitPayment()
            }
            .disabled(!isFormValid)
        }
        .padding()
        .onAppear {
            focusedFieldType = fieldOrder.first
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                if result.isSuccess, let token = result.token {
                    // Payment method tokenized -- send token to your backend
                } else if result.isFailure {
                    // Handle failure via result.failureDetails
                }
            }
        }
        .onDisappear {
            cancellable?.cancel()
        }
    }

    private func updateFormValidity() {
        isFormValid = cardNumberValid &&
                     expirationMonthValid &&
                     expirationYearValid &&
                     cvcValid &&
                     firstNameValid &&
                     lastNameValid
    }

    private func getSubmitLabel(for fieldType: FormFieldType) -> SpreedlySubmitLabel {
        guard let currentIndex = fieldOrder.firstIndex(of: fieldType) else {
            return .done
        }
        let isLastField = currentIndex == fieldOrder.count - 1
        return isLastField ? .done : .next
    }

    private func handleFieldSubmit(for fieldType: FormFieldType) {
        guard let currentIndex = fieldOrder.firstIndex(of: fieldType) else { return }
        let isLastField = currentIndex == fieldOrder.count - 1

        if isLastField {
            if isFormValid {
                submitPayment()
            }
        } else {
            let nextIndex = currentIndex + 1
            if nextIndex < fieldOrder.count {
                focusedFieldType = fieldOrder[nextIndex]
            }
        }
    }

    private func submitPayment() {
        let processingResult = Spreedly.shared().createCreditCard(
            additionalFields: [:],
            metadata: [:]
        )

        if processingResult.isValidationFailed {
            // Handle invalidFields, invalidAdditionalFields
        }
    }
}
```

---

## Keyboard Navigation and Focus Management

### fieldOrder Array

Define the tab order for your form:

```swift
private var fieldOrder: [FormFieldType] {
    [.firstName, .lastName, .cardNumber, .expirationMonth, .expirationYear, .cvc]
}
```

### handleFieldSubmit for Next/Done

When the user presses the keyboard return key, `onSubmit` fires. Use it to move focus or submit:

```swift
private func handleFieldSubmit(for fieldType: FormFieldType) {
    guard let currentIndex = fieldOrder.firstIndex(of: fieldType) else { return }
    let isLastField = currentIndex == fieldOrder.count - 1

    if isLastField {
        if isFormValid { submitPayment() }
    } else {
        let nextIndex = currentIndex + 1
        if nextIndex < fieldOrder.count {
            focusedFieldType = fieldOrder[nextIndex]
        }
    }
}
```

### SpreedlySubmitLabel Enum

Control the keyboard return key label:

```swift
public enum SpreedlySubmitLabel: Int {
    case `return` = 0    // Standard return key
    case done = 1        // "Done" button
    case go = 2          // "Go" button
    case search = 3      // "Search" button
    case send = 4        // "Send" button
    case next = 5        // "Next" (recommended for form navigation)
    case join = 6        // "Join" button
    case route = 7       // "Route" button
    case `continue` = 8  // "Continue" button
}
```

Use `.next` for intermediate fields and `.done` for the last field.

### Programmatic focus (legacy `transferFocus`)

Drive **`shouldFocus`** from one piece of state (e.g. `@State private var focusedFieldType: FormFieldType?`) so exactly one row has `shouldFocus == true` — on SwiftUI **`SPLTextField`** and UIKit **`SPLTextFieldViewController`**. **`becomeFirstResponder()`** on the view controller still works. **`CardFormDropIn`** keeps focus inside the built-in form only — there is **no merchant `transferFocus`-style API** on the express drop-in (internal Next/Done chain only).

### Wallet / Keychain autofill (legacy `toggleAutoComplete`)

When **`enableAutofill`** is `true` (default), hosted fields use each `FormFieldType`’s default **`textContentType`** (card number → `.creditCardNumber`, expiry → credit-card expiration hints, and so on). The card number row uses a **numeric keyboard** (default for card number fields); Wallet payment AutoFill (saved cards, **Scan Card**) appears via the system **AutoFill** affordance above the field, not the QuickType prediction strip. Test on a **device**; Simulator often shows nothing.

To match legacy iframe **`toggleAutoComplete()` off**, pass **`enableAutofill: false`**:

```swift
SPLTextField(type: .cardNumber, title: "Card number", isRequired: true, enableAutofill: false)
SPLTextField(type: .cvc, title: "CVC", isRequired: true, enableAutofill: false)
```

**Express drop-in:**

```swift
CardFormDropIn(
    displayConfig: CardFormDropInDisplayConfig(enableAutofill: false)
)
```

**UIKit / Objective-C** — set on `SPLTextFieldViewController` or `CardFormDropInViewController` before or after the view loads (`SPLTextFieldViewController` rebuilds the hosted field when the flag changes at runtime):

```swift
fieldVC.enableAutofill = false
```

```objc
fieldVC.enableAutofill = NO;
```

| `enableAutofill` | Card `textContentType` | Default card keyboard (if you omit `keyboardType`) |
|------------------|------------------------|-----------------------------------------------------|
| `true` (default) | `.creditCardNumber` | `.numberPad` (Wallet AutoFill via field affordance) |
| `false` | `nil` (no credit-card hint; wins over a custom type) | `.numberPad` |

You can still pass an explicit **`keyboardType`** when autofill is off.

**iOS system AutoFill:** `enableAutofill: false` clears AutoFill hints, uses an empty `textContentType`, clears the keyboard suggestion bar, and suppresses the edit menu (including AutoFill on iOS 17+); **paste** remains on card number and account number only. On headless forms, set it on **every** field on the screen; on express drop-in, `CardFormDropInDisplayConfig(enableAutofill: false)` applies to hosted fields in the drop-in. If one field still has hints, iOS may show AutoFill for the whole form. Some OS builds may still show Wallet UI above the keyboard; test on a device. Prefer **`enableAutofill: true`** (default) unless you must match legacy `toggleAutoComplete` off.

### Separated expiration autofill (Wallet)

When QuickType delivers **separate** month and year strings (saved card), forward them on the **main thread** with **`SpreedlyUIManager.shared.applySeparatedExpirationAutofill(month:year:excluding:)`**. Use **`excluding: .expirationDate`** when the user edits split **month** / **year** fields so both rows update; the SDK routes values into registered expiration fields.

### Pre-submit validation

Replaces legacy iframe **`validate()`** with a **boolean only** — no per-field error payload from this helper. Use **`createCreditCard`** / **`PaymentProcessingResult.validationFailed`**, or **`getInvalidFieldTypes()`**, for detail.

#### API

| Method | Use when |
|--------|----------|
| **`Spreedly.areAllFieldsValid(fieldTypes:)`** | You know which fields to gate (e.g. `[.cardNumber, .expirationDate, .cvc]`). Replaces iframe **`validate()`** for a typed field list. |
| **`SpreedlyUIManager.shared.areAllFieldsValid(fieldTypes:)`** | Same boolean check as **`Spreedly.areAllFieldsValid(fieldTypes:)`** if you prefer calling through the UI manager. |
| **`SpreedlyUIManager.shared.areAllFieldsValid()`** | Every registered field must pass (same check **`createCreditCard`** runs internally). |

Objective-C: **`[Spreedly areAllFieldsValidWithFieldTypeRawValues:]`** with `NSNumber` wrappers of `FormFieldType` raw values, or **`[[SpreedlyUIManager shared] areAllFieldsValid]`** for all registered fields.

#### How iOS checks fields

Each on-screen **`SPLTextField`** registers with **`SpreedlyUIManager`** while visible. For a typed list, the helper returns `true` only when **every listed type** has a registered field with **`isValid == true`**. Types you omit are not checked.

This applies to **headless and express**: **`CardFormDropIn`** builds the same `SPLTextField` rows, so these helpers work once the drop-in is on screen. Do not use a plain `TextField` for card/CVV and expect this API to see your input.

#### Footguns

- **`getRegisteredFieldCount() == 0`** — `areAllFieldsValid()` returns **`true`**. Treat as “fields not mounted yet,” not “form is valid.”
- **Empty `fieldTypes` list** — returns **`true`** (nothing listed failed).
- **Main thread** — call before enabling Pay; avoid invoking on every SwiftUI body pass.
- **Email** — use **`EmailValidator.isValid(_:)`** for optional email gates; it is not part of `areAllFieldsValid`.

#### Example

```swift
let gate: [FormFieldType] = [.cardNumber, .expirationDate, .cvc]
let ready = SpreedlyUIManager.shared.getRegisteredFieldCount() > 0
    && Spreedly.areAllFieldsValid(fieldTypes: gate)
payButton.isEnabled = ready
```

### Email validation (optional)

**`EmailValidator.isValid(_:)`** — Email format check before tokenize. Independent of `areAllFieldsValid` and not wired into `SPLTextField` validation.

```swift
if EmailValidator.isValid(emailText) {
    // proceed
}
```

Objective-C: **`[EmailValidator isValid:emailString]`**.

## Additional Fields (Billing/Shipping)

> **Naming clarification:** The SDK has two distinct concepts:
> - **`otherFields` / `FormField` array** -- extra UI fields passed to `CardFormDropIn` via its `otherFields:` parameter. These render additional `SPLTextField` components inside the drop-in form. See [express-checkout.md](express-checkout.md).
> - **`additionalFields` / `AdditionalField` dict** -- extra data (billing, shipping) passed to `createCreditCard(additionalFields:metadata:eligibleForCardUpdater:)` (and related overloads) for tokenization. These are key-value pairs sent with the tokenization request.

For billing and shipping data, use `createCreditCard(additionalFields:metadata:eligibleForCardUpdater:)` (and the ObjC overloads) plus the `AdditionalField` enum. Non-sensitive fields can be regular `TextField`s; only card data must use `SPLTextField`.

### Account Updater (tokenize)

#### Example: `createCreditCard(additionalFields:metadata:shouldRetain:eligibleForCardUpdater:)`

```swift
let processingResult = Spreedly.shared().createCreditCard(
    additionalFields: [
        .firstName: "John",
        .lastName: "Doe",
        .addressLine1: "123 Main St",
        .city: "Anytown",
        .state: "CA",
        .zipCode: "12345",
        .country: "US",
        .phoneNumber: "+1234567890",
        .email: "john.doe@example.com"
    ],
    metadata: ["orderId": "12345"],
    shouldRetain: true,  // sets PaymentResult.shouldRetain; backend must call retain API separately
    eligibleForCardUpdater: true  // optional; omit to leave the flag unset on the payment method
)
```

**Account Updater:** When `eligibleForCardUpdater` is `true` or `false`, the SDK sends that value at **payment-method** scope (not inside `credit_card`). The typed argument is then the single source of truth: any duplicate flag in top-level `metadata` is dropped for that request.

If you omit the typed parameter (`nil`), you can still send the legacy boolean using **`metadata`** (same shape your backend already accepts):

```json
{
  "metadata": {
    "eligible_for_card_updater": "true"
  }
}
```

When `eligibleForCardUpdater` is non-`nil` on `createCreditCard`, do not also set the same flag in `metadata` for that call.

### Mandate passthrough

Pass an optional **`mandate`** to attach mandate data to the payment method at tokenization. The SDK encodes it and forwards it to Spreedly at `payment_method.mandate` — a sibling of `credit_card`, not nested inside it — and omits the key entirely when the mandate is `nil` or empty. The SDK never interprets the contents.

```swift
let expiresAt = Date().addingTimeInterval(86_400)

let mandate: SpreedlyMandate = [
    "source": "acp",
    "source_version": "1.0",
    "raw_mandate": [
        "reason": "one_time",
        "max_amount": 5000,          // integer — see the note on numbers below
        "currency": "usd",
        "checkout_session_id": "cs_123",
        "merchant_id": "mer_123",
        "expires_at": expiresAt
    ],
    "valid_from": Date(),
    "valid_until": expiresAt
]

let processingResult = Spreedly.shared().createCreditCard(
    additionalFields: [:],
    metadata: ["orderId": "12345"],
    mandate: mandate
)
```

`SpreedlyMandate` is `[String: Any]`, so a mandate can carry nested objects, arrays, numbers, and booleans — Spreedly owns the mandate schema and validates it server-side, which means schema changes do not require an SDK update.

A few things to know:

- **Native Swift values are encoded for you.** `Date` becomes an ISO-8601 string (identical to what the Web SDK sends), `URL` becomes its absolute string, `UUID` becomes its lowercase UUID string (Foundation's `UUID.uuidString` is uppercase; the wire form matches JS), and string- or number-backed enums become their raw value. Optionals are unwrapped, and a `nil` becomes JSON `null`. This mirrors `JSON.stringify` exactly.
- **Numbers stay numbers.** Send `5000`, not `"5000"`. Spreedly currently accepts a bare digit string for `max_amount` and converts it, but that leniency is not part of the contract — it does not extend to `"5000.0"` or a locale-formatted `"5,000"`, and the SDK will not stringify numbers for you.
- **Non-finite numbers become `null`.** `Double.nan` and `Double.infinity` encode to JSON `null`, matching `JSON.stringify(NaN) === "null"`.
- **A value with no JSON representation fails tokenization.** `Data` and arbitrary class instances have no canonical encoding, so a mandate containing one throws an error naming the offending key path (e.g. `"mandate.raw_mandate.receipt"`) rather than being silently dropped or sending a partial mandate.
- **Never put cardholder data in a mandate.** Its contents are never logged, never sent to telemetry, and never persisted on device, but it is not a place for PAN, CVV, or account numbers.
- **The SDK does not validate mandate contents or size.** Spreedly enforces both.

The same `mandate:` parameter is available on `createBankAccount(...)`, `createClickToPayPaymentMethod(...)`, `CreditCardRequest`, `BankAccountRequest`, and both drop-ins.

### Headless `CreditCardRequest` (advanced)

If you build a **`CreditCardRequest`** (or **`BasePaymentMethodRequest`**) yourself instead of only using `createCreditCard`, pass **`eligibleForCardUpdater:`** on the initializer with the same semantics as the convenience API.

Constructing one of these request types directly is now a throwing call (`try CreditCardRequest(...)` / `try BasePaymentMethodRequest(...)`), because a `mandate:` value with no JSON representation is caught at construction time and surfaces as a thrown error naming the offending key rather than a silently omitted key.

### AdditionalField Enum

**Billing fields:**

| Field | Description |
|-------|-------------|
| `.firstName` | First name |
| `.lastName` | Last name |
| `.fullName` | Full name |
| `.addressLine1` | Primary address |
| `.addressLine2` | Secondary address |
| `.city` | City |
| `.state` | State/Province |
| `.zipCode` | Postal/ZIP code |
| `.country` | Country code |
| `.phoneNumber` | Phone number |
| `.email` | Email address |

**Shipping fields:**

| Field | Description |
|-------|-------------|
| `.shippingAddress1` | Shipping address line 1 |
| `.shippingAddress2` | Shipping address line 2 |
| `.shippingCity` | Shipping city |
| `.shippingState` | Shipping state/province |
| `.shippingZip` | Shipping postal/ZIP code |
| `.shippingCountry` | Shipping country code |
| `.shippingPhoneNumber` | Shipping phone number |

### Field Fallback Logic

1. **SDK fields first** – If a value exists in the SDK's secure fields, that value is used.
2. **Additional fields fallback** – If the SDK field is empty, the value from `additionalFields` is used.
3. **Empty string default** – If neither has a value, an empty string is used.

### Validation: invalidAdditionalFields

When validation fails, check `invalidAdditionalFields` on `PaymentProcessingResult`:

```swift
let processingResult = Spreedly.shared().createCreditCard(
    additionalFields: [
        .email: "invalid-email",
        .firstName: "",
        .addressLine1: "123 Main St"
    ]
)

if processingResult.isValidationFailed {
    if !processingResult.invalidFields.isEmpty {
        // Invalid SDK form fields
    }
    if !processingResult.invalidAdditionalFields.isEmpty {
        for field in processingResult.invalidAdditionalFields {
            switch field {
            case .email:
                showError("Please enter a valid email address")
            case .firstName:
                showError("First name is required")
            default:
                showError("\(field.fieldName) is invalid")
            }
        }
    }
}
```

You can also use `hasInvalidAdditionalField(_:)`:

```swift
if processingResult.hasInvalidAdditionalField(.email) {
    highlightEmailField()
}
```

---

## UIKit Integration

For PAN/CVC mask, `HostedFieldState`, and Objective-C parity, see [Headless PAN API quick reference](#headless-pan-api-quick-reference) (§2 UIKit, §3 Objective-C).

Use `SPLTextFieldViewController` to embed individual fields in UIKit. Property names match [the cross-surface table](#same-names-on-swiftui-uikit-and-objective-c) above (`onFieldStateChange`, `trailingIconViewFactory`, etc.).

Set **`onFieldTextChange`** (Swift UIKit) or **`fieldTextChangeListener`** (Objective-C) for the same behavior as SwiftUI **`onChange`**: opaque encoded values for PAN/CVV; plaintext for other field types. **Do not log** PAN/CVV payloads.

**Full demo:** the Objective-C example screen mirrors the SwiftUI one and is included in the example app.

> **Themed initializer (Objective-C):** For themed fields in Objective-C, use `initWithField:title:isRequired:placeholder:keyboardType:textContentType:lightThemeConfig:darkThemeConfig:onValidationChange:onFocus:` with `SPLThemeConfig` instances. See [objective-c.md](objective-c.md#spltextfieldviewcontroller) for the full signature and example.

### Programmatic Setup

```swift
let cardNumberField = SPLTextFieldViewController(
    field: .cardNumber,
    title: "Card Number",
    isRequired: true,
    placeholder: nil,
    keyboardType: .numberPad,
    textContentType: .creditCardNumber,
    onValidationChange: { [weak self] isValid in
        // Update UI state
    },
    onSubmit: { [weak self] in
        self?.cvcField?.becomeFirstResponder()
    },
    submitLabel: .next,
    onFocus: nil
)

addChild(cardNumberField)
view.addSubview(cardNumberField.view)
cardNumberField.didMove(toParent: self)
```

### Storyboard

Add a container view where the field should appear, then instantiate and add the child view controller in code:

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    let fieldVC = SPLTextFieldViewController(
        field: .cardNumber,
        title: "Card Number",
        isRequired: true
    )
    addChild(fieldVC)
    containerView.addSubview(fieldVC.view)
    fieldVC.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        fieldVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
        fieldVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        fieldVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        fieldVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ])
    fieldVC.didMove(toParent: self)
}
```

### Focus Management (UIKit)

Use `becomeFirstResponder` and `resignFirstResponder` to move focus between `SPLTextFieldViewController` instances in your `onSubmit` callbacks.

### Objective-C

Use `SPLTextFieldViewController` with the same pattern in Objective-C. Add the field as a child view controller and call `createCreditCardObjCWithAdditionalFields:metadata:` or `createCreditCardObjCWithAdditionalFields:metadata:eligibleForCardUpdater:` for tokenization:

```objc
SPLTextFieldViewController *cardNumberField = [[SPLTextFieldViewController alloc]
    initWithField:FormFieldTypeCardNumber
    title:@"Card Number"
    isRequired:YES
    placeholder:nil
    keyboardType:UIKeyboardTypeNumberPad
    textContentType:UITextContentTypeCreditCardNumber
    onValidationChange:^(BOOL valid) { /* update UI */ }
    onSubmit:^{ [self.cvcField becomeFirstResponder]; }
    submitLabel:SpreedlySubmitLabelNext
    onFocus:nil];

[self addChildViewController:cardNumberField];
[self.view addSubview:cardNumberField.view];
cardNumberField.view.translatesAutoresizingMaskIntoConstraints = NO;
// Add layout constraints for cardNumberField.view
[cardNumberField didMoveToParentViewController:self];

// For tokenization, implement SpreedlyPaymentDelegate and call:
PaymentProcessingResult *result = [[Spreedly shared] createCreditCardObjCWithAdditionalFields:@{} metadata:@{}];
```

Set `[Spreedly shared].paymentDelegate` **before** calling `createCreditCardObjC` to receive the token via `paymentDidComplete:`. When `result.isProcessing` is `YES`, the async tokenization is underway and the delegate will fire when it completes.

**Cleanup (Objective-C):** Call `[[Spreedly shared] reset]` in `viewWillDisappear:` and remove child `SPLTextFieldViewController` instances in `viewDidDisappear:`. See [objective-c.md](objective-c.md#cleanup-and-teardown) for full cleanup patterns.

---

## Save Card Option in Custom Forms

`CardFormDropIn` includes a built-in "Save card for future payments" checkbox. Custom forms do not. Implement it yourself:

```swift
struct CustomPaymentForm: View {
    @State private var shouldRetain = false
    // ... other state

    var body: some View {
        VStack(spacing: 16) {
            // Your SPLTextField fields

            Toggle("Save card for future payments", isOn: $shouldRetain)

            Button("Submit Payment") {
                processPayment()
            }
        }
        .onAppear {
            cancellable = Spreedly.shared().subscribeToPaymentResults { result in
                if result.isSuccess, shouldRetain, let token = result.token {
                    savePaymentMethodForFutureUse(token: token)
                }
            }
        }
    }

    private func savePaymentMethodForFutureUse(token: String) {
        // Store token securely, send to backend, etc.
    }
}
```

In custom forms, pass the user's choice via the `shouldRetain` parameter on `createCreditCard(additionalFields:metadata:shouldRetain:eligibleForCardUpdater:)`. This sets `PaymentResult.shouldRetain` on success so your app knows the user opted in. **The SDK does not send a retain request to the Spreedly API** -- your backend must call the Spreedly retain endpoint separately if you want to vault the payment method for future use. See the example app's `RetainPaymentMethodAPIClient` for this pattern.

---

## Error Handling

### Validation Failures

Check `PaymentProcessingResult` after `createCreditCard`:

```swift
let result = Spreedly.shared().createCreditCard(
    additionalFields: additionalFields,
    metadata: [:]
)

if result.isValidationFailed {
    for fieldType in result.invalidFields {
        // Highlight invalid SDK fields
    }
    for additionalField in result.invalidAdditionalFields {
        // Highlight invalid additional fields
    }
}
```

### Payment Results

Subscribe to payment results before calling `createCreditCard`:

```swift
let cancellable = Spreedly.shared().subscribeToPaymentResults { result in
    if result.isSuccess {
        // Use result.token
    } else if result.isFailure {
        // Use result.failureDetails
    }
}
```

Cancel the subscription and reset validation parameters when the view disappears:

```swift
.onDisappear {
    cancellable?.cancel()
    cancellable = nil
    Spreedly.shared().setParam(parameter: .allowBlankName, value: false)
    Spreedly.shared().setParam(parameter: .allowExpiredDate, value: false)
    Spreedly.shared().setParam(parameter: .allowBlankDate, value: false)
    Spreedly.shared().setParam(parameter: .allowInternationalZipCodes, value: true)
}
```

Reset validation parameters in `onDisappear` to restore defaults when the form is dismissed.

---

## Headless PAN API quick reference

Short reference for **card number** (and coupled **CVC** mask) on **headless** fields only — `SPLTextField` (SwiftUI) or `SPLTextFieldViewController` (UIKit / Objective-C). Not available on **`CardFormDropIn`** (express checkout uses merchant UI + `setNumberFormat` / `toggleMask` outside the sheet).

**Why these APIs exist (iframe parity):** Legacy iframe-ui had no raw PAN in `fieldEvent` payloads, external `setNumberFormat` / `toggleMask`, and optional custom card-brand art. The native SDK mirrors that: safe **`HostedFieldState`** snapshots, global display control on **`Spreedly`**, and headless-only trailing brand / mask hooks.

| Surface | Type | When to use |
|---------|------|-------------|
| SwiftUI | `SPLTextField(type: .cardNumber, …)` | SwiftUI custom checkout |
| UIKit (Swift) | `SPLTextFieldViewController(field: .cardNumber, …)` | UIKit apps embedding hosted fields |
| Objective-C | Same `SPLTextFieldViewController` + `HostedFieldStateListener` | ObjC custom checkout |

**Merchant examples:** SwiftUI `CustomFormView.swift` (hosted fields use the example **`enableAutofill`** toggle — no legacy autofill-off workaround); UIKit/ObjC `CustomFormViewController.m` in the Checkout iOS example app (paths are internal-only in repo docs — search the example app for those filenames).

---

### 1. Field — SwiftUI (`SPLTextField`)

```swift
SPLTextField(
    type: .cardNumber,
    title: "Card number",
    isRequired: true,
    enableAutofill: true,
    trailingIcon: { scheme in AnyView(MyVisaIcon(scheme)) },
    onFieldStateChange: { state in /* scheme, digit count, valid — no raw PAN */ },
    onInputLength: { count in print(count) },
    onValidationChange: { valid in payButton.isEnabled = valid }
)

SPLTextField(type: .cvc, title: "CVC", isRequired: true)

// Merchant UI outside fields (iframe / web parity)
Spreedly.shared().setNumberFormat(.pretty)
Spreedly.shared().toggleMask()
```

| Parameter | What it does |
|-----------|----------------|
| `enableAutofill` | `true` → credit-card autofill hint + number pad (unless you override `keyboardType`). `false` → no wallet autofill hints. |
| `trailingIcon` | **PAN only** — your brand `View` from detected `CardType`. Supersedes default `CardBrandIcon`. |
| `forceMaskOnLifecycleStop` | Default `true` — force visual mask while app is backgrounded. |
| `keyboardType` | Override SDK default (card number defaults to **`.numberPad`**). |
| `onFieldStateChange` | Safe **`HostedFieldState`** — brand, `numberLength`, `isPanMasked`, valid/empty/focus; **no raw PAN**. **`isPanMasked` is only meaningful when `state.fieldType == .cardNumber`** — always `true` for CVC. |
| `onInputLength` | Digit count only (not PAN string). |
| `onChange` | Opaque SDK-encoded string for PAN (not what appears on screen). **Do not log.** Use **`createCreditCard`** to tokenize. |
| `requiredMessage` | Overrides the default required-field error string (e.g. `"Name is required"` on ACH name fields). When set on name fields, min/max length errors also use bank-account wording. |

Card number and CVC display follow **`Spreedly.shared().setNumberFormat(_:)`** / **`toggleMask()`** automatically — no per-field mask or observe parameters.

---

### 2. Field — UIKit (`SPLTextFieldViewController`)

Embed as a child view controller; set properties **before** the view loads (or immediately after init).

```swift
let pan = SPLTextFieldViewController(
    field: .cardNumber,
    title: "Card number",
    isRequired: true
)
pan.enableAutofill = true
pan.trailingIconViewFactory = { schemeRaw in
    UIImageView(image: UIImage(named: "card_\(schemeRaw)"))
}
pan.onFieldStateChange = { state in
    if state.fieldType == .cardNumber {
        print(state.cardSchemeRawValue ?? "unknown")
        print(state.numberLength?.intValue ?? 0)
        print(state.isPanMasked)
    }
}
pan.onValidationChange = { valid in
    self.payButton.isEnabled = valid
}

addChild(pan)
container.addSubview(pan.view)
pan.didMove(toParent: self)
```

| Property | What it does |
|----------|----------------|
| `field` | Must be **`FormFieldType.cardNumber`** (or `.cvc` for coupled CVV mask). |
| `enableAutofill` | Same as SwiftUI — credit-card autofill when `true`. |
| `requiredMessage` | Same as SwiftUI — override required-field validation copy. |
| `trailingIconViewFactory` | **PAN only** — `(String) -> UIView` with scheme raw value (`"visa"`, `"mastercard"`, …). |
| `onFieldStateChange` | Swift closure — same snapshot as SwiftUI. |
| `hostedFieldStateListener` | ObjC **`HostedFieldStateListener`** alternative to `onFieldStateChange`. |
| `onInputLength` | Digit count for PAN/CVC. |
| `fieldTextChangeListener` / `onFieldTextChange` | Per-keystroke opaque/plain text (PAN = ciphertext). Prefer **`onFieldStateChange`** for parity. |
| `becomeFirstResponder()` | Programmatic focus (iframe `transferFocus`). |

---

### 3. Field — Objective-C (`SPLTextFieldViewController`)

Same class as UIKit; use **`HostedFieldStateListener`** if you avoid Swift closures.

```objc
self.cardNumberField = [[SPLTextFieldViewController alloc]
    initWithField:FormFieldTypeCardNumber
            title:@"Card number"
       isRequired:YES
      placeholder:nil
     keyboardType:UIKeyboardTypeNumberPad
  textContentType:UITextContentTypeCreditCardNumber
onValidationChange:^(BOOL valid) {
    self.payButton.enabled = valid;
}];

self.cardNumberField.trailingIconViewFactory = ^UIView *(NSString *schemeRaw) {
    return [self merchantPanTrailingBrandViewForSchemeRawValue:schemeRaw];
};
[self attachHostedFieldCallbacksToField:self.cardNumberField]; // onFieldStateChanged: / onInputLength

addChildViewController:self.cardNumberField];
[formContainer addSubview:self.cardNumberField.view];
[self.cardNumberField didMoveToParentViewController:self];
```

```objc
// HostedFieldStateListener (optional instead of onFieldStateChange block)
- (void)onFieldStateChanged:(HostedFieldState *)state {
    if (state.fieldType != FormFieldTypeCardNumber) { return; }
    NSLog(@"scheme=%@ len=%@ masked=%@",
          state.cardSchemeRawValue ?: @"",
          state.numberLength,
          state.isPanMasked ? @"YES" : @"NO");
}
self.cardNumberField.hostedFieldStateListener = self;
```

| API | What it does |
|-----|----------------|
| `trailingIconViewFactory` | Custom brand art; scheme string = `CardType` `rawValue`. |
| `hostedFieldStateListener` | ObjC-friendly **`onFieldStateChanged:`** (no raw PAN). |
| `FieldTextChangeListener` | Optional opaque `onFieldTextChanged:` for PAN/CVC keystrokes. |

---

### 4. Global SDK (`Spreedly` — all surfaces)

Call on the **main thread**. Updates every headless **card number** and **CVC** field display together.

**Swift**

```swift
Spreedly.shared().setNumberFormat(.masked)
Spreedly.shared().toggleMask()
let state = Spreedly.shared().hostedCardDisplayState
// state.cardNumberFormat, state.panMasked, state.cvvDisplayMasked
```

**Objective-C** — use **one** format API per change (not raw value **and** string together):

```objc
[[Spreedly shared] setNumberFormatWithCardNumberFormatRawValue:2]; // 0=pretty, 1=plain, 2=masked
[[Spreedly shared] setNumberFormatWithType:@"maskedFormat"];      // iframe string — same as raw 2
[[Spreedly shared] toggleMask];
NSInteger format = [[Spreedly shared] hostedCardDisplayCardNumberFormatRawValue];
```

| Method / property | Usage |
|-------------------|--------|
| `setNumberFormat(_:)` / `setNumberFormatWithCardNumberFormatRawValue:` / `setNumberFormatWithType:` | **Action** — sets PAN **layout** and **coupled CVV mask** for observing fields. See [setNumberFormat by language](#setnumberformat-by-language-pick-one-call-per-format). |
| `toggleMask()` | **Action** — merchant “eye”; toggles **plain+revealed ↔ masked+hidden** for **PAN and CVC** together. Does **not** select **Pretty** (use `setNumberFormat(.pretty)` for grouped spacing). |
| `hostedCardDisplayState` | **Read-only** snapshot: `cardNumberFormat`, `panMasked`, **`cvvDisplayMasked`** (booleans — not callable). See [read flags vs mask actions](#hostedcarddisplaystate-read-vs-mask-actions). |
| `hostedCardDisplayCardNumberFormatRawValue` | **Read-only** (ObjC): current `CardNumberFormat` raw value only — not `cvvDisplayMasked`. |
| `resetPaymentFormPreservingDisplayConfig()` | Clears values, validation, visible fields — **keeps** mask/format. |
| `resetPaymentState()` / `reset()` | Full reset — values, validation, visible fields, **and** PAN/CVV display back to defaults. |

```swift
// Clear fields but keep Masked / Plain / Pretty
Spreedly.shared().resetPaymentFormPreservingDisplayConfig()

// Full wipe (e.g. leave checkout)
Spreedly.shared().resetPaymentState()
```

**Display formats** {#display-formats}

> **iframe `prettyFormat` vs iOS `.pretty`**
>
> | | iframe `prettyFormat` | iOS `CardNumberFormat.pretty` |
> |---|---------------------|------------------------------|
> | **What you get** | Grouped spaced digits; PAN stays **visible** on blur | Same — grouped digits, **all PAN digits visible** on focus and blur |
> | **Not the same as** | — | **`.plain`** (ungrouped, all visible) or **`.masked`** (`*` on every digit) |
> | **From masked** | Use `prettyFormat` in JS | `setNumberFormat(.pretty)` — **unmasks PAN only**; CVV may stay `*` until you also set plain/masked or `toggleMask()` |
> | **Reveal / hide toggle** | `toggleMask()` (plain ↔ masked) | `toggleMask()` — does **not** switch to Pretty; call `setNumberFormat(.pretty)` for spacing |

| Value | iframe name | User sees (PAN) | CVV (when coupled) |
|-------|-------------|-----------------|---------------------|
| `.pretty` / `0` | `prettyFormat` | Grouped spaced digits (focus and blur); all digits visible | Unchanged vs prior mask (`.pretty` unmasks PAN only) |
| `.plain` / `1` | `plainFormat` | All digits, ungrouped | Revealed (coupled with PAN) |
| `.masked` / `2` | `maskedFormat` | Full `*` mask on every digit (no grouping) | Masked `*` (coupled with PAN) |

---

### 5. `HostedFieldState` (`onFieldStateChange` / `onFieldStateChanged:`)

**Never includes raw PAN or CVV** — safe for logging and analytics. **`HostedFieldState.iin`** is the typed BIN **prefix** only (6 or 8 digits on card-number events), not the full PAN.

**Swift**

```swift
onFieldStateChange: { state in
    guard state.fieldType == .cardNumber else { return }
    print(state.cardScheme?.rawValue ?? "unknown")
    print(state.numberLength ?? 0)
    print(state.isPanMasked)
    print(state.isValid)
    if state.eventType == .panMaskChanged { /* mask toggled */ }
}
```

**Objective-C**

```objc
- (void)onFieldStateChanged:(HostedFieldState *)state {
    if (state.fieldType != FormFieldTypeCardNumber) { return; }
    NSString *scheme = state.cardSchemeRawValue ?: @"unknown";
    NSInteger len = state.numberLength.integerValue;
    BOOL masked = state.isPanMasked;
    BOOL valid = state.isValid;
    // HostedFieldEventTypePanMaskChanged when mask changes
}
```

| Field | Swift | ObjC | Notes |
|-------|-------|------|-------|
| Scheme | `cardScheme` | `cardSchemeRawValue` | e.g. `"visa"` |
| PAN digit count | `numberLength` | `numberLength` (`NSNumber`) | Not the PAN string |
| BIN prefix | `iin` | `iin` | 6 or 8 digits on card number; `nil` if fewer than six |
| Mask flag | `isPanMasked` | `isPanMasked` | UI mask state (visible digits hidden?) |
| Event kind | `eventType` | `eventType` | `.input`, `.focus`, `.blur`, `.validation`, `.panMaskChanged` |

---

### 6. Pay / validate

Subscribe to results **before** calling `createCreditCard`. The synchronous return value reports client-side validation only — the final `PaymentResult` (with the token) arrives on `subscribeToPaymentResults` / `paymentDelegate`.

**Swift**

```swift
let cancellable = Spreedly.shared().subscribeToPaymentResults { result in
    if result.isSuccess, let token = result.token {
        // PAN was read from secure storage, never from onChange.
        // Send token to your backend to create the purchase.
    } else if result.isFailure {
        // Inspect result.failureDetails
    }
}

let ok = Spreedly.areAllFieldsValid(fieldTypes: [.cardNumber, .expirationMonth, .expirationYear, .cvc])
guard ok else { return }

let processing = Spreedly.shared().createCreditCard(
    additionalFields: [:],
    metadata: nil
)
if processing.isValidationFailed {
    // Surface processing.invalidFields to the user
}
```

**Objective-C**

```objc
NSArray<NSNumber *> *types = @[
    @(FormFieldTypeCardNumber),
    @(FormFieldTypeExpirationMonth),
    @(FormFieldTypeExpirationYear),
    @(FormFieldTypeCvc)
];
BOOL ok = [Spreedly areAllFieldsValidWithFieldTypeRawValues:types];
if (!ok) { return; }

// Final PaymentResult arrives via [Spreedly.shared setPaymentDelegate:self]
// and -paymentDidComplete: (SpreedlyPaymentDelegate).
PaymentProcessingResult *processing =
    [[Spreedly shared] createCreditCardObjCWithAdditionalFields:@{}
                                                       metadata:nil
                                                   shouldRetain:self.shouldRetain
                                         eligibleForCardUpdater:YES];
if (processing.isValidationFailed) {
    // Surface processing.invalidFields to the user
}
```

---

### 7. Typical headless setup (CustomForm pattern)

**SwiftUI** — segmented control drives global state; PAN + CVC observe it:

```swift
Picker("Format", selection: Binding(
    get: { uiManager.hostedCardDisplayState.cardNumberFormat },
    set: { Spreedly.shared().setNumberFormat($0) }
)) {
    Text("Pretty").tag(CardNumberFormat.pretty)
    Text("Plain").tag(CardNumberFormat.plain)
    Text("Masked").tag(CardNumberFormat.masked)
}
Button("toggleMask()") { Spreedly.shared().toggleMask() }

SPLTextField(type: .cardNumber, title: "Card number", isRequired: true)
SPLTextField(type: .cvc, title: "CVC", isRequired: true)
```

**Objective-C** — `UISegmentedControl` + `toggleMask` button (example app):

```objc
- (void)panFormatChanged:(UISegmentedControl *)sender {
    [[Spreedly shared] setNumberFormatWithCardNumberFormatRawValue:(NSInteger)sender.selectedSegmentIndex];
}
- (IBAction)toggleMaskTapped:(id)sender {
    [[Spreedly shared] toggleMask];
}
```

**Custom brand + mask:** Use merchant UI calling **`toggleMask`**, or combine mask controls with artwork inside **`trailingIcon` / `trailingIconViewFactory`** (Swift `HStack` / ObjC container).

---

### 8. Not on headless PAN / express-only

| API / callback | Headless `SPLTextField` | Express `CardFormDropIn` |
|----------------|-------------------------|---------------------------|
| `onFieldStateChange` / `HostedFieldStateListener` | ✓ | — |
| `trailingIcon` / `trailingIconViewFactory` | ✓ PAN only | — (default built-in brand) |
| `CardFormDropInDisplayConfig.cardNumberFormat` | — | ✓ seeds format on first open only |

---

### 9. Clipboard (default)

| Field | Paste | Copy / cut |
|-------|-------|------------|
| PAN | Allowed | Blocked |
| CVC | Blocked | Blocked |

Values live in **`SecureValueContainer`**. Tokenize with **`createCreditCard`**, not **`onChange`** / **`FieldTextChangeListener`**.

---

## Related Documentation

- [express-checkout.md](express-checkout.md) – Pre-built payment form with `CardFormDropIn`
- [theme-and-styling.md](theme-and-styling.md) – Theming and customization
- [objective-c.md](objective-c.md) – Objective-C integration with delegates and wrappers
