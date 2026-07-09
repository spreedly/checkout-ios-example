# Changelog

All notable changes to the Spreedly iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.1] - 2026-07-09

> **Distribution patch** — Same XCFramework binaries and SDK behavior as **1.4.0**. Pin **1.4.1** for new integrations (SPM and CocoaPods). Do not use tag **`1.4.0`** for Swift Package Manager — its `Package.swift` manifest is broken.

### Fixed

- **SPM manifest alignment**: `Package.swift` on **1.4.1** lists only the five XCFrameworks shipped in this release. Feature details are unchanged from **1.4.0** (see below).

## [1.4.0] - 2026-06-03

> **ACH is not included in this release.** Version **1.4.0** ships card tokenization, CVV recache, Braintree/Stripe APM, and gateway-specific 3DS only. Bank-account APIs (`BankAccountFormDropIn`, `createBankAccount`, etc.) may exist in the repository for internal QA — **merchants must not integrate ACH on 1.4.0**. ACH will be announced under a new version header when it completes QA

### Breaking Changes

- **Headless `SPLTextField` / `SPLTextFieldViewController` (iframe parity)** — CARD/CVV display follows `Spreedly.shared().setNumberFormat(_:)` / `toggleMask()` / `hostedCardDisplayState`. Removed `observeHostedCardDisplayState`, per-field `cvvDisplayMasked`, and controlled `panMasked` / `onPanMaskedChange`. Recompile headless integrations that passed display state into fields.
- **Express `CardFormDropIn` / `CardFormDropInViewController`** — Removed `showPanMaskToggle` and `showsAutofillToggle`; mask via merchant `toggleMask()` / `setNumberFormat`; autofill via `CardFormDropInDisplayConfig.enableAutofill`.
- **`resetPaymentSession()` removed** — `CardFormDropIn` clears secure values on dismiss and refreshes field values on each open while **keeping** merchant `setNumberFormat` / `toggleMask`. Call **`resetPaymentState()`** / **`reset()`** for a full wipe including display state.
- **CVV recache result delivery** — recache outcomes on `subscribeToRecacheResults` / `SpreedlyRecacheDelegate` only, not `paymentResultPublisher` or `paymentDelegate`.
- **Payment cancellation (`PaymentResult`)** — Stripe APM dismiss and Braintree user-cancel emit `PaymentResult.canceled()` (`isCanceled == true`, `isFailure == false`). Callers that treated cancel as failure must use `result.isCanceled`.

### Added

- **Express core field copy** — `DropInCoreFieldLabels` and `CardFormDropInDisplayConfig` on `CardFormDropIn` / `CardFormDropInViewController` for optional card number, CVV, and expiration labels/placeholders. Defaults unchanged when omitted.
- **Iframe-style PAN/CVV display** — `CardNumberFormat` (`pretty`, `plain`, `masked`), `HostedCardDisplayState`, `Spreedly.shared().hostedCardDisplayState`, `setNumberFormat(_:)` (enum or iframe string aliases `prettyFormat` / `plainFormat` / `maskedFormat`), and `toggleMask()`. Mask control is merchant UI outside the fields.
- **Lifecycle mask overlay** — `forceMaskOnLifecycleStop` (default `true`) on card-number `SPLTextField`: temporary visual mask when the field leaves the active lifecycle while PAN was revealed.
- **`SPLTextField.onFieldStateChange` / `HostedFieldState`** — typed field snapshots (`INPUT`, `FOCUS`, `BLUR`, `VALIDATION`, `PAN_MASK_CHANGED`): `cardScheme`, digit lengths (no raw PAN/CVV), `isValid`, `isEmpty`, `isFocused`, `isPanMasked`, `iin`; optional `onInputLength` callback. ObjC: `HostedFieldStateListener`.
- **`SPLTextField.onFocusChanged`** — optional focus/blur callback on headless fields.
- **`SPLTextField.trailingIcon` / `trailingIconViewFactory`** — optional trailing slot on CARD fields (e.g., card brand logo).
- **`Spreedly.areAllFieldsValid(fieldTypes:)`** — aggregate validation gate over a `FormFieldType` list.
- **`SpreedlyUIManager.shared.getRegisteredFieldCount()`** — count of mounted hosted field instances for pay-button gating.
- **`Spreedly.resetPaymentFormPreservingDisplayConfig()`** — clears payment field values and validation without resetting `hostedCardDisplayState` (preserves mask/format state).
- **`EmailValidator.isValid(_:)`** — merchant email validation before tokenize (rejects single-label domains).
- **`eligibleForCardUpdater`** — optional parameter on `createCreditCard` (Swift) and matching ObjC overload; JSON key sent only when non-null.
- **Hosted fields autofill** — `SPLTextField` / express drop-in `enableAutofill`; CARD honors initializer `keyboardType` and `textContentType` when autofill is on.
- **`allowInternationalZipCodes` validation param** — `setParam(.allowInternationalZipCodes)` defaults to international ZIP validation.
- **`HostedFieldState.iin`** — merchant-safe IIN prefix on card field snapshots when six or more digits are present.
- **`HostedFieldState.panDisplayFormat` / `panDisplayPolicyMasked`** — card-number snapshot of global display format and mask policy at emission time.
- **`Spreedly.isInitialized`** — `true` only after signed `setup(config:)` / `setupWithConfig(_:)` (non-empty `environmentKey`, `nonce`, `signature`, `certificateToken`, `timestamp`). Not `true` after `initializeSDK()` alone or implicit `shared()` without signed auth.
- **Braintree transaction status fields** — line items, shipping address, locale, and `enablePaylaterButton` on status-driven PayPal/Venmo launch (iframe parity).
- **Braintree PayPal vault & checkout_with_vault flows** — status-driven `paypal_flow_type` (`checkout`, `vault`, `checkout_with_vault`) with billing agreement, shipping, and line items.
- **Braintree PayPal device-data gating** — device fingerprint collection skipped for PayPal `checkout` only; collected for Venmo and PayPal vault / checkout-with-vault flows.
- **Braintree Venmo `multi_use` / `single_use` mapping** — honors status-driven `venmo_flow_type` for usage and vault behavior.
- **Client token 24h validation** — Braintree checkout validates `created_at` within 24 hours and rejects stale tokens before launch.
- **Payment type mismatch validation** — Braintree checkout fails early when config payment type does not match status `payment_method_type`.
- **Recache accessors** — `Spreedly.subscribeToRecacheResults`, `SpreedlyRecacheDelegate`, and `PaymentResult.paymentMethodUpdatedAt` on successful recache.
- **Stripe APM PaymentSheet appearance** — `StripeAPMAppearanceConfig` on `SpreedlyStripeAPMCheckout.present(config:appearance:)` / `present(config:appearance:from:)`.
- **Gateway-specific 3DS completion safety net** — background transaction status watch after `GatewaySpecific3DSTriggerCompletion` when the app skips `finalizeTransaction`; `finalizeTransaction` still takes precedence.
- **Legacy iframe migration guide** — [`guides/migration/from-legacy.md`](guides/migration/from-legacy.md) with iframe-to-native mapping tables.

### Deprecated

- **`resetPaymentFormPreservingPANFormatState()`** — renamed to **`resetPaymentFormPreservingDisplayConfig()`**; legacy selector kept for this release.

### Changed

- **PAN/CVV display transforms** — `masked` and `plain` use full-mask display; `pretty` keeps grouped digits on focus and blur. Mask character is `*` (legacy `•` input still accepted).
- **Hosted card display transitions** — `setNumberFormat(.pretty)` unmasks the PAN only; **CVV mask is preserved** from the prior state. `plain` and `masked` couple PAN and CVV; `toggleMask()` toggles between masked and plain.
- **`resetPaymentState()` display reset** — clears form values and resets `hostedCardDisplayState` to defaults. Re-apply `setNumberFormat` / `toggleMask` after reset for a non-default mask.
- **Post-tokenize hosted display** — successful `createCreditCard` and express sheet open call `resetPaymentFormPreservingDisplayConfig()` so mask/format is preserved; full `resetPaymentState()` still clears display for merchant clean-slate resets.
- **Express autofill** — autofill is controlled by `CardFormDropInDisplayConfig.enableAutofill` only; removed the in-sheet autofill QA toggle.
- **`reset()` clears visible field text** — `Spreedly.shared().reset()` is an alias of `resetPaymentState()` and now clears registered `SPLTextField` visible text.
- **Recache API failure handling** — HTTP 200 with `transaction.succeeded == false` emits `PaymentResult.failure` on the recache channel.
- **Braintree checkout launch** — always fetches transaction status before launch (`clientToken` on config is fallback); fails when `payment_method_type` is missing or mismatched; removed iOS-only 60-second tokenize timeout.
- **Braintree gateway-specific 3DS** — skips device-fingerprint iframe and routes to challenge when status requires `device_fingerprint`.
- **Worldpay gateway-specific 3DS** — tightened device-fingerprint completion detection so unrelated browser messages no longer cause spurious early completion.

### Fixed

- **Separate expiry month field** — month field no longer pads a lone `0` to `00`; merchants can backspace and clear while typing; months 10–12 can be entered digit-by-digit.
- **Expiry autofill and placeholders** — wallet/card-scan strings (`06/30`, `06/2030`, compact `0630`) parse into combined or split fields; MM/YY placeholders match `yearFormat`; four-digit autofill years truncate to two digits on separate year fields.
- **Hosted autofill and PAN keyboard** — `enableAutofill: false` suppresses hints without clearing PAN/CVC; PAN field honors initializer `keyboardType` and `textContentType`.
- **Recache optional CVV** — ROUTEX, UATP, and Tarjeta D recache accept empty or shorter CVV; Confirm stays disabled until CVV passes card-brand rules; recache entry always masked (ignores checkout display config).
- **Optional CVV submit validation** — headless tokenize and recache accept empty or shorter CVV when the card type allows; stale CVC digit no longer flashes invalid after successful Pay.
- **Braintree `client_token` expiry** — parses `transaction.context` for token and `created_at`; skips expiry enforcement when `created_at` is missing or unparseable.
- **Braintree status and cancel handling** — status responses with an empty or missing `transaction.token` in the body no longer block launch (token backfilled from the request); responses with no `transaction` object still fail; SDK cancel publishes `PaymentResult.canceled()`; empty error descriptions fall back to `"Braintree payment failed"`; superseded `present()` no longer emits spurious cancel.
- **Express PAN display on re-open** and **PAN mask event timing** — merchant `setNumberFormat` / `toggleMask` survives sheet re-open; `PAN_MASK_CHANGED` and `HostedFieldState.isPanMasked` match the selected format at emit time.

## [1.3.8] - 2026-05-08

### Added

- **RC pre-releases on `checkout-ios-package`**: Tagged release candidates (`vX.Y.Z-rc.N`) now publish as pre-releases on `checkout-ios-package`. Partners can pin to the exact RC for parallel validation via `exact: "X.Y.Z-rc.N"` in SPM or `:tag => 'X.Y.Z-rc.N'` in CocoaPods. Stable consumers tracking `from: "X.Y.Z"` are unaffected — pre-releases are opt-in by SemVer convention.

### Changed

- **RC validation before stable promotion**: Each RC is validated before the matching stable tag is published. Stable promotion is a no-rebuild artifact promotion (same XCFrameworks, identical checksums), so the artifact validated for an RC is byte-identical to the stable release.

- **More reliable GitHub Releases on `checkout-ios-package`**: Release assets (SBOM, framework zips, and SHA-256 checksums) are now uploaded and verified together before the release is published, giving merchants complete and consistent releases.

- **Documentation**: Historical entries in this changelog were rewritten for a merchant-facing voice.

### Fixed

- **SDK identification on Core API requests**: All outbound requests to Spreedly Core now include `from` and `v` URL query parameters identifying the calling SDK platform and version. Previously, Core could not attribute HTTP traffic to a specific SDK — only Datadog telemetry carried this data.

- **Example repository**: Merchant-facing docs no longer include internal-only SDK references; the sample app Swift Package Manager pin reflects the latest published package.
- **Verified sync commits**: Commits synced to the public package repository ship with Verified status where signing is configured.

### Security

- **Stripe iOS SDK upgrade**: Embedded `stripe-ios-spm` updated from 24.25.0 to 25.10.0 (Stripe major release). `SpreedlyStripeAPM`'s public API surface is unchanged; merchants integrating Stripe APM should review Stripe's release notes for upstream behavior changes that may affect their payment flows.

## [1.3.7] - 2026-05-05

### Changed

- Automated publishing adjustments on the Swift Package distribution repo only (no behavioral SDK surface change).

### Notes

Validation release — binary behavior matches `1.3.6` aside from embedded `SpreedlySDK.version` (`1.3.7`). No functional reason to upgrade from `1.3.6` unless you care about tagging or distribution bookkeeping for your own audits.

## [1.3.6] - 2026-05-04

### Fixed

- **SBOM accuracy**: Published SBOM now matches each released SDK revision.
- **Install directions**: README badges, SPM `from:` pins, and CocoaPods tags on the distribution repository update with each release so copied snippets reference the advertised version.
- **Checksum guide**: Verification instructions reference the URLs and tarball versions for each release build.
- **Publication hygiene**: Distribution changelog entries align with each shipped SDK release; stray legacy `.tar.gz` archives were removed from historic downloads.
- **Release artifacts**: Stable GitHub Releases include downloadable frameworks, checksums, and SBOM payloads.

### Changed

- Sync to the distribution repo refreshes every version-copied asset (checksums, podspec pins, manifests, prose), not binaries alone.

### Security

- **Signed tags**: Release tags are automation-signed consistently with other Spreedly mobile SDK pipelines.
- **Verified tags**: Stable tags expose GitHub's Verified badge wherever signing identities are corroborated.
- **Downloadable payloads**: Releases continue attaching SBOM, framework ZIPs, and checksum sidecars alongside signed tags.

### Notes

Beyond the bumped `SpreedlySDK.version` string and signed tagging, GitHub Releases now ship SBOM, packaged frameworks, and checksums consistently. Ask Spreedly Support if you need key material or `git tag -v` steps.

## [1.3.5] - 2026-04-29

### Breaking Changes

- **`sdkPlatform` on `SpreedlyConfig`**: Switched from string literals to the typed `SdkPlatform` enum. Swift callers passing `"react_native"` must migrate to `.reactNative`; native iOS integrations use `.ios`. Objective-C integrations remain compatible.

### Added

- **Device integrity gate**: Opt-in blocking of jailbroken/compromised devices via `blockJailbrokenDevices` on `SpreedlyConfig`; blocked apps receive `SpreedlySecurityError`.
- **`Spreedly.blockJailbrokenDevices`**: Static toggle for callers who initialize through `initializeSDK()` without assembling a standalone `SpreedlyConfig`.
- **`Spreedly.isDeviceTrusted`**: Preferred read-only signal replacing deprecated trust wording (see Changed).
- **Automatic sheet dismissal**: `CardFormDropIn`, CVV recache, gateway challenge flows dismiss when the device is blocked.
- **LICENSE in archives**: Each XCFramework bundle and distribution ZIP embeds the license text.
- **CocoaPods xcconfig guide**: Documented overrides for custom build settings in `getting-started`.

### Changed

- **Renamed `Spreedly.isOperational` → `Spreedly.isDeviceTrusted`**: Aligns naming with common platform affordances.
- **Forter 3DS dependency**: Pinned to exact `2.1.0` for reproducible builds.
- **Distribution hardening**: Podspec linting, post-release asset validation, and signed-tag documentation updated.
- **Integration guides**: Accuracy pass across major flows (3DS, APM, recache, testing).

### Fixed

- **Security recovery**: `initializeSDK()` now recovers when a device later passes integrity checks after a prior block.
- **Duplicate ObjC classes**: Stripe, Datadog, and Braintree consumers no longer load two copies of the same symbols (SPM + CocoaPods).
- **Stripe APM status copy**: iDEAL/SEPA flows show `processing` where appropriate, consistent with other Spreedly checkout SDKs.
- **Example pending UI**: Example surfaces dedicated pending states for Offsite, EBANX, Stripe APM, and Braintree mid-flight responses.

### Security

- **Binary hardening**: Additional obfuscation and tighter visibility of non-public implementation details.
- **Release binaries**: Optimized/stripped release slices with smaller local symbol tables.

### Removed

- Unsupported `Rapipago` and `NuPay Recurrent` cases from `OffsitePaymentMethodType`.
- Unused `cryptoData` case on `PaymentMethodType`.

## [1.3.4] - 2026-04-27

### Added

- Runtime integrity checks, configurable security blocking, and jailbreak detection hooks.

## [1.2.7] - 2026-03-20

### Added

- **`sdkPlatform` telemetry**: `SpreedlyConfig` defaults to native iOS; React Native bridges should set `.reactNative` for analytics differentiation.
- **`source` on payment methods**: Network requests include a source token indicating which checkout SDK produced the payload.
- **Braintree coverage**: Expanded automated tests around Braintree flows.

### Fixed

- **Stripe APM**: Correct processing label for iDEAL/SEPA once the gateway moves past `pending`.
- **`setConfig`**: Re-applying configuration propagates `sdkPlatform` updates.
- **Card form paste**: Sanitizes dashed/dotted PAN input before formatting.
- **Concurrency & memory**: Broader thread-safety and lifecycle fixes across UI + networking.
- **Example app dependency pins**: Example app `Package.resolved` updated for build reliability.

### Changed

- **Docs / dependencies**: Forter 3DS install notes, Info.plist guidance, and dependency tables refreshed.
- **Logging**: Hot-path logging now evaluates lazily for lower overhead.

## [1.1.4] - 2026-03-11

### Changed

- Expanded structured telemetry for payments, 3DS, networking, and error surfaces.
- Release metadata documentation, SBOM exports, and compliance-facing sync refreshed.

## [1.1.3] - 2026-03-09

### Fixed

- TestFlight validation failure caused by nested framework embedding in accessibility helpers.

## [1.1.2] - 2026-03-09

### Fixed

- Build reliability: example app fully migrated to Swift Package Manager.

## [1.1.1] - 2026-03-09

### Changed

- Version strings and release documentation aligned with the `1.1.0` launch.

## [1.1.0] - 2026-03-09

### Added

- **Stripe APM Module** (`SpreedlyStripeAPM`): Stripe Alternative Payment Methods via native PaymentSheet. Supports iDEAL, Bancontact, EPS, P24, SEPA Debit. `SpreedlyStripeAPMCheckout` entry point with `StripeAPMConfig`. Backend-initiated flow with automatic status polling.
- **Braintree APM Module** (`SpreedlyBraintree`): Braintree PayPal and Venmo payments. `SpreedlyBraintreeCheckout` entry point with `BraintreeCheckoutConfig`. `BraintreePaymentType` enum for PayPal and Venmo selection. Full Objective-C support via `BraintreeURLHandlerObjC`.
- **EBANX Offsite Payments**: Pix, Boleto Bancario, NuPay, OXXO via EBANX with `DocumentId` support.
- **Gateway-Specific 3DS**: Gateway-managed 3D Secure authentication (e.g. Worldpay) with Safari-based challenge presentation and automatic status polling.
- **Offsite Payment Integration**: Safari-based offsite payment flow for PayPal and Sprel with `handleOffsiteReturn(url:)` for return handling.
- **CVV Recaching**: `SpreedlyCVVRecachingView` for updating CVV on saved payment methods with bottom sheet and dialog presentation modes.
- **Screen Prevention**: `ScreenPreventionSecureView` blocks screenshots and screen recording for PCI compliance.
- **Objective-C Support**: Full Objective-C compatibility via delegates, bridges, and `@objc` annotations including `SpreedlyPaymentDelegate`, `CardFormDropInViewController`, and `CVVRecachingViewController`.
- **Additional Fields**: Billing and shipping address fields via `AdditionalField` enum.
- **Card Brand Detection**: 50+ card brands with BIN pattern matching, Luhn validation, and brand-specific rules.
- **Theming**: Full theming system with light/dark mode support, Dynamic Type and Bold Text accessibility.
- **Localization**: Localized strings for Core, UI, Braintree, and Stripe APM modules.
- **DocC Documentation**: Documentation catalogs for SpreedlyCore, SpreedlyUI, SpreedlySecurity, and SpreedlyAnalytics.

### Security

- Log sanitization extended for card numbers, tokens, environment keys, and phone numbers.
- Sensitive card data automatically zeroed after API calls.
- Payment tokens masked in all example app views.

### Changed

- Datadog initialization now skips gracefully when no client token is configured.
- Fixed expiration date two-digit year pivot (years 50-99 now map to 1900s).
- Downgraded swift-tools-version from 6.1 to 6.0 for broader compatibility.

### Documentation

- Updated security guide with logging best practices.
- Recommended `.none` log level for production builds.
- Updated CocoaPods install examples to `~> 1.1`.
- Added CVV recaching accessibility hints.

## [1.0.0] - 2026-03-08

### Added

- Initial release of Spreedly iOS SDK.
- **SpreedlyCore**: Core payment processing, API client, 3DS (Forter global), models, and Combine publishers.
- **SpreedlyUI**: Card form drop-in (`CardFormDropIn`), hosted fields (`SPLTextField`), card brand icons, validation.
- **SpreedlySecurity**: AES-GCM encryption, secure value storage.
- **SpreedlyAnalytics**: Logging and observability.
- Swift Package Manager and CocoaPods distribution via `checkout-ios-package`.
- Example app with SwiftUI and Objective-C demonstrations.

### Compatibility

- iOS 14.0+ (minimum deployment target)
- Swift 5.10+
- Xcode 16.1+

---

## Versioning

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

### Support

- **Minimum iOS**: 14.0
- **Swift**: 5.10+
- **Xcode**: 16.1+

For detailed integration guides, see the [documentation index](README.md).
