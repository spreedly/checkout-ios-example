# Spreedly iOS SDK Docs

## Integration Guides

**Start here for lifecycle:** [Getting Started — SDK lifecycle](guides/getting-started.md#sdk-lifecycle) — when to call `initializeSDK`, `setup`, `reset`, and how this differs from web iframe `destroy`.

**`Spreedly.isInitialized`** is `true` only after **`Spreedly.setup(config:)`** with a full signed bundle from your server (similar to iframe **ready**). It is `false` after **`initializeSDK()`** alone. It is `false` when init was blocked; use `Spreedly.initializationError` and `Spreedly.isDeviceTrusted`. Setup details: [Getting Started — Basic Setup](guides/getting-started.md#basic-setup).

### Hosted fields — public API inventory

Everything below is **merchant-facing** in the current SDK. Use this checklist so nothing is missed; iframe → JS name mapping is in **[Migration from legacy iframe-ui](guides/migration/from-legacy.md#public-api-inventory)**.

#### `Spreedly` / `SpreedlyUIManager`

| API | Purpose |
|-----|---------|
| `Spreedly.isInitialized` | `true` after signed `setup(config:)` only; see [SDK lifecycle](guides/getting-started.md#isinitialized--when-to-use-it) |
| `Spreedly.areAllFieldsValid(fieldTypes:)` | Pre-submit validation for a list of `FormFieldType` |
| `SpreedlyUIManager.shared.areAllFieldsValid()` | All registered headless or drop-in fields must pass |
| `SpreedlyUIManager.shared.getRegisteredFieldCount()` | How many `SPLTextField` rows are registered (0 = not mounted yet) |
| `SpreedlyUIManager.shared.getInvalidFieldTypes()` | Which field types failed (Swift); ObjC: `[[SpreedlyUIManager shared] getInvalidFieldTypes]` → `NSNumber` raw values |
| `EmailValidator.isValid(_:)` | Optional email format check (not wired into every field) |
| `Spreedly.shared().hostedCardDisplayState` | **Read-only** snapshot (`cardNumberFormat`, `panMasked`, `cvvDisplayMasked`) — not mask/unmask functions; see [read vs mask actions](guides/custom-payment-forms.md#hostedcarddisplaystate-read-vs-mask-actions) |
| `hostedCardDisplayState.cvvDisplayMasked` | **Read-only:** `true` = CVC shows `*`; changes only via `setNumberFormat` / `toggleMask` (no iframe JS name) |
| `[Spreedly shared].hostedCardDisplayCardNumberFormatRawValue` | Objective-C: current `CardNumberFormat` raw value only (does not expose `cvvDisplayMasked`) |
| `Spreedly.shared().setNumberFormat(_:)` | **Action:** set PAN layout (`.pretty` / `.plain` / `.masked`) and coupled CVV mask |
| `Spreedly.shared().setNumberFormat(type:)` | **Swift bridge:** iframe strings (`prettyFormat`, `plainFormat`, `maskedFormat`) — same as enum; do not call both for one format |
| `[Spreedly setNumberFormatWithCardNumberFormatRawValue:]` | **ObjC:** `0` / `1` / `2` = pretty / plain / masked (preferred native path) |
| `[Spreedly setNumberFormatWithType:]` | **ObjC:** iframe strings — use **or** raw value, not both for the same format |
| `Spreedly.shared().toggleMask()` | Toggle plain ↔ masked for **PAN + CVC** (main thread) |
| `Spreedly.shared().resetPaymentFormPreservingDisplayConfig()` | Clear field values and validation; **keep** `setNumberFormat` / `toggleMask` state |
| `Spreedly.shared().resetPaymentState()` | Full reset: secure values, field UI, validation, and hosted PAN/CVV display (alias of `reset()`) |
| Express drop-in rotation | Typed fields stay on rotation in `CardFormDropIn` — no merchant API. [Sheet lifecycle](guides/express-checkout.md#sheet-lifecycle) |
| When form reset preserving display config runs | [Payment reset](guides/custom-payment-forms.md#when-preserving-display-config-reset-runs) |
| `Spreedly.shared().setParam(parameter: .allowInternationalZipCodes, value:)` | `true` (default) = international postal; `false` = US numeric ZIP only |
| `Spreedly.shared().createCreditCard(additionalFields:metadata:shouldRetain:eligibleForCardUpdater:)` | Tokenize the current `SPLTextField` values; opt the card into Spreedly's Account Updater service when `eligibleForCardUpdater: true`. ObjC: `createCreditCardObjCWithAdditionalFields:metadata:shouldRetain:eligibleForCardUpdater:`. |
| `Spreedly.shared().subscribeToPaymentResults { ... }` | Receive the async `PaymentResult` after `createCreditCard` / drop-ins (Swift Combine; ObjC: `SpreedlyPaymentDelegate`). |
| `Spreedly.shared().subscribeToRecacheResults { ... }` | Dedicated recache outcomes (Swift Combine; ObjC: `SpreedlyRecacheDelegate.recacheDidComplete:`). Separate from the payment channel above. |

Objective-C: `areAllFieldsValidWithFieldTypeRawValues:`, `setNumberFormatWithType:`, `setNumberFormatWithCardNumberFormatRawValue:`, `toggleMask`, `hostedCardDisplayCardNumberFormatRawValue`, `[[SpreedlyUIManager shared] getInvalidFieldTypes]`, `[EmailValidator isValid:]`. See [Objective-C](guides/objective-c.md).

**Headless PAN (iframe parity):** [Headless PAN API quick reference](guides/custom-payment-forms.md#headless-pan-api-quick-reference) — SwiftUI, UIKit, and Objective-C tables for `SPLTextField` / `SPLTextFieldViewController`, `HostedFieldState`, mask/format APIs, and pay flow.

#### Headless `SPLTextField` / `SPLTextFieldViewController` only

| API | Purpose |
|-----|---------|
| `onFieldStateChange` | `HostedFieldState` snapshots — scheme, digit **lengths**, `iin` (6–8 digit BIN **prefix** on card number only), validity, focus, `isPanMasked`; **never full PAN or CVV** |
| `onFocusChanged` | Focus enter (`true`) / blur (`false`) |
| `onFocus` | Focus enter only |
| `onInputLength` | Card/CVV digit count before encryption |
| `onValidationChange` | Per-field valid/invalid |
| `onChange` | Value updates; PAN/CVC values are **opaque** — use `onFieldStateChange` for lengths |
| `HostedFieldState` | Type on each callback: `fieldType`, `eventType` (`input`, `focus`, `blur`, `validation`, `panMaskChanged`), `isFocused`, `isValid`, `isEmpty`, `cardScheme`, `iin`, `numberLength`, `cvvLength`, `isPanMasked` |
| `HostedFieldStateListener` | ObjC protocol instead of `onFieldStateChange` block |
| Headless PAN/CVC display | Card + CVC follow global `setNumberFormat` / `toggleMask` — [PAN/CVV display](guides/custom-payment-forms.md#pancvv-display-iframe-and-web-hosted-field-parity) |
| `forceMaskOnLifecycleStop` | Lifecycle mask while app is backgrounded (card number) |
| `enableAutofill` | Default `true`; `false` = legacy `toggleAutoComplete` off (headless per field) |
| `keyboardType` / `textContentType` | Honored on card number (Wallet autofill when omitted) |
| `trailingIcon` / `trailingIconViewFactory` | Custom PAN brand artwork |

Property tables and snippets: [Custom Payment Forms](guides/custom-payment-forms.md#spltextfield-component).

#### `CardFormDropIn` / `CardFormDropInViewController`

| API | Purpose |
|-----|---------|
| `DropInCoreFieldLabels` | Override titles/placeholders for card number, CVC, expiry rows |
| `CardFormDropInDisplayConfig` | Initial `cardNumberFormat`, `enableAutofill` for all hosted fields in the drop-in on open — set before presenting the sheet |
| `Spreedly.setNumberFormat` / `toggleMask` | Still drive PAN/CVC inside the sheet from **outside** the drop-in |

**Not on express drop-in:** `onFieldStateChange`, `onFocusChanged`, `onInputLength`, custom `trailingIcon` — use headless fields if you need those.

Express snippets: [express-checkout.md](guides/express-checkout.md#code-sample--cardformdropin-with-labels-display-config-and-external-mask-ui). Headless snippet: [custom-payment-forms.md](guides/custom-payment-forms.md#code-sample--headless-spltextfield-field-state--mask).

| Guide | Description |
|-------|-------------|
| [Getting Started](guides/getting-started.md) | Install the SDK, set it up, and run a first payment |
| [Express Checkout](guides/express-checkout.md) | Use the ready-made CardFormDropIn payment form |
| [Custom Payment Forms](guides/custom-payment-forms.md) | Build your own payment form UI with SPLTextField |
| [ACH Bank Account](guides/ach-bank-account.md) _(preview — not yet released)_ | Tokenize US ABA + Canadian routing numbers via BankAccountFormDropIn or headless. **Do not integrate in production until ACH ships in a future release.** |
| [Theme and Styling](guides/theme-and-styling.md) | Colors, typography, dark mode |
| [Error Handling](guides/error-handling.md) | Error types, retry guidance, and user-friendly messages |
| [Security](guides/security.md) | Screen prevention, PCI compliance |
| [Recaching](guides/recaching.md) | CVV recaching for saved payment methods |
| [Offsite Payments](guides/offsite-payments.md) | PayPal, Sprel via Safari |
| [EBANX APM](guides/ebanx-apm.md) | Pix, Boleto, OXXO, NuPay via EBANX |
| [Stripe APM](guides/stripe-apm.md) | iDEAL, Bancontact, EPS, P24, SEPA via Stripe |
| [Braintree APM](guides/braintree-apm.md) | PayPal and Venmo via Braintree |
| [3DS Global](guides/3ds-global.md) | Forter-based 3D Secure authentication |
| [3DS Gateway-Specific](guides/3ds-gateway-specific.md) | Gateway-managed 3DS authentication (e.g. Worldpay) |
| [Objective-C](guides/objective-c.md) | Integrate from Objective-C using delegates and wrappers |
| [Privacy](guides/privacy.md) | Privacy requirements and data handling practices |
| [Troubleshooting](guides/troubleshooting.md) | Common issues and solutions |
| [Testing Guide](guides/testing-guide.md) | Test cards, environment setup, and flow-by-flow testing |

## Migration

| Guide | Description |
|-------|-------------|
| [From legacy iframe-ui](guides/migration/from-legacy.md) | Web iframe-ui → native `SPLTextField` / `CardFormDropIn` (`HostedFieldState` + `iin`, mask APIs, headless vs express, documented gaps) |
| [Migration index](guides/migration/README.md) | Major-version upgrade guides (`vN-to-vN+1`) |

**Legacy iframe migration:** This repo documents **web iframe-ui → native iOS** mapping in [from-legacy.md](guides/migration/from-legacy.md).

## Other

- [Changelog](CHANGELOG.md)
- [Root README](../README.md)
