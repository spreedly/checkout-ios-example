# Upgrade to the iOS 16 minimum

| | |
|---|---|
| **Audience** | Merchants on 1.6.x or earlier upgrading to 1.7.0 |
| **Use this when** | Deciding whether your app can adopt 1.7.0, which raises the iOS floor |
| **Use something else when** | Moving off the legacy web iframe → [From legacy iframe-ui](from-legacy.md) |
| **Requires** | From SDK 1.x · app deployment target **iOS 16.0+** |

SDK **1.7.0** raises the minimum supported iOS version from **14.0** to **16.0**. An app whose
deployment target is below iOS 16 cannot adopt it: the build fails with Swift Package Manager, and
`pod install` fails with CocoaPods. **1.6.x** stays available for apps that still support iOS 14 or
iOS 15.

> **Check your version constraint now.** 1.7.0 is a minor release, so the usual constraints
> (`from: "1.6.1"` in Swift Package Manager, `~> 1.6` in CocoaPods) resolve to 1.7.0 on your next
> package update. If your app still supports iOS 14 or 15, pin to 1.6.x first — see
> [Staying on 1.6.x](#staying-on-16x).

No public API is removed. Deprecated symbols still compile. For the other changes in 1.7.0, see the
[Changelog](../../CHANGELOG.md).

## Who is affected

Every app that links a Spreedly iOS module: Core, Security, UI, Stripe APM, Stripe Radar, Braintree,
or Click to Pay. Use one version for every Spreedly module you depend on — that rule does not change.

## Breaking changes

### Minimum iOS version moves to 16.0

| | 1.6.x | 1.7.0 and later |
|---|---|---|
| App deployment target | iOS 14.0 or later | iOS 16.0 or later |
| What happens below the floor | Builds | Swift Package Manager: Xcode reports a minimum-platform error when it builds the app. CocoaPods: `pod install` fails because the pods need a higher minimum deployment target |

Devices that cannot run iOS 16 — including iPhone 7 and earlier, and the first-generation iPhone SE —
cannot run an app that adopts 1.7.0.

## Deprecations carried forward

These deprecations are still present in 1.7.0. They still compile and still warn. Prefer the
replacement now so a later removal does not block you.

| Still available, deprecated | Use instead |
|---|---|
| `AccountHolderType` | `BankAccountHolderType` |
| `PaymentMethodAPIKeys.accountNumber` | `bankAccountNumber` |
| `PaymentMethodAPIKeys.routingNumber` | `bankRoutingNumber` |
| `PaymentMethodAPIKeys.accountType` | `bankAccountType` |
| `PaymentMethodAPIKeys.accountHolderType` | `bankAccountHolderType` |
| `resetPaymentFormPreservingPANFormatState()` | `resetPaymentFormPreservingDisplayConfig()` |
| `preserveDropInFormOnRotation()` / `preservePaymentStateOnNextShow()` | Nothing. Rotation handling is automatic in `CardFormDropIn` |
| `getChallengeContainerView(for:)` | Nothing. Gateway-specific 3DS challenges are presented by the system browser session. The method returns `nil` |
| `finalizeTransactionWithTransactionToken:completeResponseData:error:` | `finalizeTransactionForTransactionToken:completeResponseData:error:` |

Every row also applies to 1.6.x, so you can make these changes before you upgrade.

## Upgrade steps

1. In Xcode, set the app target's **Minimum Deployments** to **iOS 16.0** or later. Do the same for
   every extension and test target that links the SDK.
2. Install **Xcode 26.0** or later. **26.5** is the version the published binaries are built with.
3. If you use CocoaPods, set `platform :ios, '16.0'` in the Podfile. Move off the deprecated symbols
   in the table above.
4. Bump every Spreedly dependency to **1.7.0** — one version for all of them:

   ```swift
   .package(url: "https://github.com/spreedly/checkout-ios-package", from: "1.7.0")
   ```

   ```ruby
   pod 'SpreedlyCore', '~> 1.7'
   ```

5. Build. A deployment-target error means the app or an extension is still below iOS 16. Raise that
   target, or stay on 1.6.x.
6. Run your payment regression tests: card tokenization, any drop-in you ship, 3DS if you use it,
   and each optional module (Stripe APM, Stripe Radar, Braintree, Click to Pay).

## Compatibility

| Component | 1.6.x | 1.7.0 and later |
|---|---|---|
| iOS | 14.0 | 16.0 |
| Swift | 6.0 | 6.0 |
| Xcode | 26.0 (26.5 recommended) | 26.0 (26.5 recommended) |

## Staying on 1.6.x

If you cannot raise the app's deployment target, pin to 1.6.x so a package update does not pull in
1.7.0. Swift Package Manager:

```swift
.package(url: "https://github.com/spreedly/checkout-ios-package", .upToNextMinor(from: "1.6.1"))
```

CocoaPods:

```ruby
pod 'SpreedlyCore', '~> 1.6.0'
```

Repeat the constraint for each Spreedly pod you use, and keep `platform :ios, '14.0'` (or whatever
floor you already ship). Features that require iOS 16 ship in 1.7.0 and later only, so a 1.6.x app
does not receive them.

## Related

- [Getting started](../getting-started.md)
- [Changelog](../../CHANGELOG.md)
