# Changelog

All notable changes to the Spreedly iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.7] - 2026-05-05

### Changed

- HC-1369 **Replaced the auto-merged release PR with a sync-branch + direct-tag-push pattern** in `tag-release.yml`. The previous `gh pr merge --squash` step failed against `checkout-ios-package`'s `Require PR Review` ruleset and only shipped 1.3.6 via a one-off manual approval. The dist-sync flow now: (1) pushes the version-bump commit to a `sync/v${VERSION}` branch, (2) pushes the GPG-signed tag directly to dist (tags bypass branch-protection rulesets), (3) creates the GitHub Release, and (4) opens a non-blocking sync PR for human review. GPG signing stays on the SDK runner; **no GPG keys are added to the public package repo**. Mirrors the approach used by `checkout-android-sdk`. Also adds a maintenance-aware `expected_branch` output (`main` for the current major, `release/N.x` otherwise) so dist sync targets the right branch on patch releases.

### Notes

This is a validation release for the new GPG-signed tag pipeline (HC-1369). The compiled SDK binary is functionally identical to 1.3.6 — same source code, same dependencies, only the embedded `SpreedlySDK.version` string changes. Merchants on 1.3.6 do not need to upgrade for functional reasons; 1.3.7 exists to prove the new release pipeline end-to-end before the next merchant-facing change ships.

## [1.3.6] - 2026-05-04

### Fixed

- HC-1369 **Stale `sbom.json` in `checkout-ios-package`**: The SBOM is now copied from the SDK release artifact (`sbom-vX.Y.Z.json`) into `checkout-ios-package/sbom.json` during the `Sync to Package Repo` step. Previously the file was inherited from the prior release and reported the wrong component version, breaking PCI DSS audit trails.
- HC-1369 **Stale `README.md` install snippets in `checkout-ios-package`**: Version pins in the badge, SPM `from:`, and all CocoaPods `:tag =>` lines are now `sed`-rewritten on every release. Previously merchants copy-pasting from README would install the previous version instead of the one they intended to install.
- HC-1369 **Stale `PACKAGE_VERIFICATION.md` in `checkout-ios-package`**: Download URLs, `VERSION="..."`, and "Last Updated" lines are now `sed`-rewritten on every release. The verification guide had been pinned at 1.3.0 across five releases.
- HC-1369 **Missing release entries in root `CHANGELOG.md` of `checkout-ios-package`**: A PCI DSS compliance entry is now auto-prepended for every release. Tickets are auto-extracted from the SDK CHANGELOG entry for that version. Previously the root CHANGELOG never received the new release header.
- HC-1369 **Dead `*.tar.gz` archives in `checkout-ios-package`**: The release script now removes leftover `.tar.gz` files. Three stale archives from October 2025 (release 0.0.36) had been sitting in the repo since.
- HC-1369 **No downloadable assets on `checkout-ios-package` release pages**: A new `attach-release-assets` job in `checkout-ios-package/.github/workflows/release.yml` auto-uploads `sbom.json`, all framework `*.zip` files, and their `*.zip.sha256` checksums to the GitHub Release page on `release: published`. Prior releases (1.3.0 through 1.3.5) had zero downloadable assets on the release page.

### Changed

- HC-1369 **`Sync to Package Repo` step in `tag-release.yml` now refreshes all version-coupled artifacts in `checkout-ios-package`**, not just XCFrameworks/podspecs/checksums. The PR body opened against the package repo now honestly enumerates every file group that was modified.

### Security

- HC-1369 **Automated GPG-signed release tags**: `tag-release.yml` now auto-signs RC/stable tags with the iOS Release Bot key (fingerprint `B5F9 FB98 4885 87B6 3590 D5BD 2DE8 551B 78F5 9704`) instead of relying on manual `git tag -s`. The same workflow also auto-merges the dist-repo release PR, pushes a GPG-signed bare-semver tag to `checkout-ios-package`, and creates the corresponding GitHub Release. Closes the manual-signing gap and brings iOS in line with the Android and React Native release pipelines.
- HC-1369 **`attach-release-assets` job on `checkout-ios-package/.github/workflows/release.yml`**: Uploads `sbom.json`, all framework `*.zip` files, and their `*.zip.sha256` checksums to the dist GH Release page on `release: published`. Pairs with the new auto-created GH Release so the merchant-facing dist release page is now both signed and complete.
- HC-1369 **GitHub `Verified` badge on signed tags**: The `tag-release.yml` auto-sign step now uses a GitHub-verifiable mailbox as the tagger email, so signed RC and stable tags display the green `Verified` badge on the releases page. Brings iOS to visual parity with Android and React Native.

### Notes

This release introduces tag-signing automation (HC-1369) and a set of dist-sync hygiene fixes prepared together. Framework binaries differ from 1.3.5 in three ways: the embedded `SpreedlySDK.version` string is now `1.3.6`, RC/stable tags are GPG-signed by the iOS Release Bot at CI time, and the dist GH Release page now ships with downloadable SBOM + framework zips + checksums. Merchants who want to verify release tags should contact Spreedly Support for the bot's verification key and `git tag -v` instructions.

## [1.3.5] - 2026-04-29

### Added

- HC-1331 **Tag-driven release automation**: New `tag-release.yml` workflow triggered by `vX.Y.Z` tags. Builds XCFrameworks, creates GitHub Releases, and auto-syncs to `checkout-ios-package` and `checkout-ios-example` repos.
- HC-1331 **Automated dev releases**: `auto-dev-release.yml` publishes dev pre-releases on every merge to `main`.
- HC-1331 **Release readiness checks**: `release-readiness.yml` and `release-health.yml` for pre-release validation.
- HC-1344 **Dependency vulnerability gating**: `dependency-review-action@v4` blocks PRs introducing high-severity CVEs.
- HC-1335 **LICENSE embedded in XCFramework artifacts**: LICENSE file is now included inside each `.xcframework` bundle and `.zip` distribution archive.
- HC-1278 **Secret scanning**: Gitleaks CI integration and pre-commit hook for credential detection.
- HC-1311 CocoaPods custom xcconfig guide in getting-started documentation.
- **Jailbreak device blocking**: New `blockJailbrokenDevices` option on `SpreedlyConfig` (defaults to `false`). When enabled, the SDK refuses to initialize on compromised devices and sets `Spreedly.initializationError` with a `SpreedlySecurityError`. Works from both Swift and Objective-C.
- **`Spreedly.blockJailbrokenDevices` static property**: For merchants using `initializeSDK()` without a config object. Set before calling `initializeSDK()`.
- **`Spreedly.isDeviceTrusted`**: Read-only property that returns `false` when the device fails integrity checks and the SDK is blocked. Replaces `isOperational`.
- **Auto-dismiss on blocked devices**: `CardFormDropIn`, `CVVRecachingView`, and `DoChallengeIfNeeded` automatically dismiss their sheets when presented on a blocked device. Custom forms using `SPLTextField` directly still require a manual `isDeviceTrusted` check.

### Changed

- HC-1336 **Pipeline hardening**: Pod spec lint validation, post-release asset verification, GPG-signed release tag documentation.
- **Renamed `Spreedly.isOperational` to `Spreedly.isDeviceTrusted`**: Aligns with industry conventions (Apple `canMakePayments`, Google `isReadyToPay`).
- HC-1311 **Forter3DS pinned to exact 2.1.0**: Changed from `from: "2.1.0"` (up-to-next-major) to `exact: "2.1.0"` for deterministic builds.
- HC-1302 Documentation accuracy audit across integration guides.
- HC-1263 **`sdkPlatform` is now a `SdkPlatform` enum**: Replaced the `String?` parameter on `SpreedlyConfig` with a type-safe `SdkPlatform` enum (`.ios`, `.reactNative`). **Breaking**: callers passing `sdkPlatform: "react_native"` must change to `sdkPlatform: .reactNative`.

### Fixed

- HC-1317 `initializeSDK()` now correctly recovers from a previous security block when the device passes integrity checks.
- HC-1312 **Duplicate ObjC class warnings resolved**: Eliminated runtime `Class X is implemented in both` warnings for Stripe, Datadog, and Braintree dependencies. SPM and CocoaPods consumers no longer see duplicate class loading.
- HC-1302 CI cache key improvements to prevent `hashFiles` timeouts.
- HC-1301 Release workflow YAML validation fixes.
- HC-1278 Secret scanning workflow fixes (SARIF upload permissions, bash parse errors, regex improvements).
- HC-1274 **Pending/processing status UI**: Payment example flows now render dedicated pending message styles for intermediate gateway states (Offsite, EBANX, Stripe APM, Braintree).

### Security

- HC-1313 Binary hardening improvements to protect SDK internals from reverse engineering.
- HC-1314 Release binary optimization and symbol stripping across all frameworks.
- HC-1315 ABI metadata suppression and access level tightening for internal types.

### Removed

- Removed unsupported Rapipago payment method from `OffsitePaymentMethodType`.
- Removed unsupported NuPay Recurrent payment method from `OffsitePaymentMethodType`.
- Removed unused `cryptoData` case from `PaymentMethodType`.

## [1.3.4] - 2026-04-27

### Added

- HC-1317 Runtime integrity checks, security blocking, and jailbreak device detection.

## [1.2.7] - 2026-03-20

### Added

- HC-1234 **`sdk_platform` telemetry attribute**: New `sdkPlatform` field on `SpreedlyConfig` (default `.ios`). React Native bridges pass `.reactNative` to distinguish integration surface.
- HC-1263 **`source` field on payment method creation**: All payment method creation requests now include a `source` field identifying the checkout SDK platform (e.g. `"checkout-ios"`, `"checkout-react-native"`).
- HC-1242 Braintree test coverage improvements.

### Fixed

- HC-1179 **Stripe APM pending vs processing**: iOS now correctly shows "processing" for Stripe APM payments (iDEAL, SEPA), matching Android and Web behavior.
- HC-1263 `setConfig()` now correctly propagates `sdkPlatform` when reconfiguring an already-initialized SDK.
- HC-1251 **Card number field paste**: Pasted input with dashes or dots is now normalized to digits only and displayed with proper space-separated groups.
- HC-1242 Thread safety and memory management improvements across multiple components.
- HC-1249 **Xcode Cloud TestFlight build**: Resolved stale `Package.resolved` that caused build failures in Xcode Cloud.

### Changed

- HC-1265 Documentation audit: corrected Forter 3DS install instructions, clarified Info.plist key requirements, updated dependency tables.
- HC-1263 **`sdkPlatform` is now a `SdkPlatform` enum**: Replaced the `String?` parameter on `SpreedlyConfig` with a type-safe enum. **Breaking**: callers passing `sdkPlatform: "react_native"` must change to `sdkPlatform: .reactNative`.
- HC-1242 Logging performance improvements with lazy evaluation.

## [1.1.4] - 2026-03-11

### Changed

- HC-1234 Telemetry events and attributes for payment flows, 3DS, network, and error tracking.
- HC-1233 Version consistency, SBOM updates, documentation sync, PCI compliance improvements.

## [1.1.3] - 2026-03-09

### Fixed

- HC-1223 Fixed TestFlight validation by removing nested framework embed from SPLAccessibility.

## [1.1.2] - 2026-03-09

### Fixed

- HC-1223 Fixed Xcode Cloud build by migrating to SPM and generating xcconfig on CI.

## [1.1.1] - 2026-03-09

### Changed

- HC-1223 Updated version references and documentation for 1.1.0 release.

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
