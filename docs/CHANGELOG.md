# Changelog

All notable changes to the Spreedly iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.8] - 2026-05-08

### Added

- **RC pre-releases on `checkout-ios-package`**: Tagged release candidates (`vX.Y.Z-rc.N`) now publish as pre-releases on `checkout-ios-package`. Partners (e.g. the React Native team) can pin to the exact RC for parallel validation via `exact: "X.Y.Z-rc.N"` in SPM or `:tag => 'X.Y.Z-rc.N'` in CocoaPods. Stable consumers tracking `from: "X.Y.Z"` are unaffected — pre-releases are opt-in by SemVer convention.

### Changed

- **RC TestFlight gate before stable promotion**: The release pipeline now ships every RC to a dedicated TestFlight tester group ahead of the stable tag push, giving QA real-device validation against the actual artifact that gets promoted. Stable promotion remains a no-rebuild artifact promotion (same XCFrameworks, identical checksums) so what QA validates is byte-identical to what merchants ship.

- **Draft-first single-shot release publish for `checkout-ios-package`**: All 11 dist release assets (`sbom.json` + 5 framework zips + 5 `.sha256` checksums) now attach to a draft release first, the draft is verified to have the full asset set, and only then is it flipped to published. Replaces the previous post-publish upload from the dist repo, so `checkout-ios-package` can enable GitHub Immutable Releases (a published release becomes locked and a partial-asset publish would be unrecoverable). Asset list is single-source-of-truth and re-tried with stale-draft cleanup on transient upload failures.

- **Documentation**: Historical entries in this changelog were rewritten for a merchant-facing voice; deeper engineering detail remains in internal SDK documentation that is not copied to the public package repository.

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
- **Stripe APM status copy**: iDEAL/SEPA flows show `processing` where appropriate, matching Android/Web.
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
- **TestFlight/Xcode Cloud**: Example `Package.resolved` drift that broke cloud builds is reconciled.

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

- Xcode Cloud builds by finishing the Swift Package Manager migration and generating secrets via CI.

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
