# Spreedly iOS SDK — Example App

> **This project is for demonstration and reference purposes only.** It is not intended for use in production environments. The code, configuration, and architecture shown here illustrate SDK integration patterns — adapt them to your own security requirements, backend infrastructure, and key management practices before shipping to production.

Demonstrates integrating the [Spreedly iOS SDK](https://github.com/spreedly/checkout-ios-package) into a merchant application. The project includes **two variant builds** — one using **Swift Package Manager** and one using **CocoaPods** — that share the same application code.

Each variant contains a **SwiftUI (Swift)** target and a **UIKit (Objective-C)** target, showing both language integration paths.

**SDK Version:** 1.6.0

## Prerequisites

| Requirement       | Version        |
|-------------------|----------------|
| **Xcode**         | 26.0+  |
| **iOS Deployment**| 14.0+    |
| **Swift**         | 6.0+  |
| **XcodeGen**      | 2.40+ (to regenerate `.xcodeproj`) |
| **CocoaPods**     | 1.15+ (CocoaPods variant only) |

## SDK Modules

| Module | Product | Description |
|--------|---------|-------------|
| **SpreedlyCore** | `SpreedlyCore` | SpreedlyCore framework |
  | **SpreedlySecurity** | `SpreedlySecurity` | SpreedlySecurity framework |
  | **SpreedlyUI** | `SpreedlyUI` | SpreedlyUI framework |
  | **SpreedlyStripeAPM** | `SpreedlyStripeAPM` | SpreedlyStripeAPM framework |
  | **SpreedlyStripeRadar** | `SpreedlyStripeRadar` | SpreedlyStripeRadar framework |
  | **SpreedlyBraintree** | `SpreedlyBraintree` | SpreedlyBraintree framework |
  | **SpreedlyClickToPay** | `SpreedlyClickToPay` | SpreedlyClickToPay framework |

## Credential Setup

1. Copy the template at the repository root:

   ```bash
   cp SpreedlyKeys.xcconfig.example SpreedlyKeys.xcconfig
   ```

2. Open `SpreedlyKeys.xcconfig` and fill in your Spreedly environment key, server URL, and other credentials. This file is **git-ignored** and will not be committed.

3. Both variants read these values from `Info.plist` at runtime via `$(VARIABLE_NAME)` substitution.

> **Security note:** Values injected via xcconfig end up in the compiled `Info.plist` inside the app binary. This is acceptable for a demo, but production apps should fetch sensitive credentials from a secure backend rather than embedding them in the client. If you accidentally commit or share real keys, rotate them immediately.

## Quick Start — SPM Variant

```bash
# (Re)generate the Xcode project from project.yml
cd ExampleSPM
xcodegen generate

# Open in Xcode
open MerchantExampleSPM.xcodeproj
```

1. Xcode will automatically resolve SPM dependencies on first open.
2. Select the **MerchantExampleSPM** (Swift) or **MerchantExampleSPMObjC** (Objective-C) scheme.
3. Build & run on a simulator or device.

## Quick Start — CocoaPods Variant

```bash
# (Re)generate the Xcode project from project.yml
cd ExampleCocoaPods
xcodegen generate

# Install pods
pod install

# Open the workspace (NOT the .xcodeproj)
open MerchantExamplePods.xcworkspace
```

1. Select the **MerchantExamplePods** (Swift) or **MerchantExamplePodsObjC** (Objective-C) scheme.
2. Build & run on a simulator or device.

### Local Package Development

To build against a local checkout of `checkout-ios-package`:

1. Open `ExampleCocoaPods/Podfile`.
2. Set `USE_LOCAL_PACKAGE = true`.
3. Update `LOCAL_PACKAGE` to point to your local `checkout-ios-package` directory.
4. Run `pod install` again.

## Example Screens

| # | Screen | Description |
|---|--------|-------------|
| 1 | **Basic Checkout** | Drop-in `CardFormDropIn` with default fields (name, card, expiry, CVC). |
| 2 | **Checkout with Additional Fields** | `CardFormDropIn` with extra billing/address fields (address, city, state, ZIP). |
| 3 | **Custom Form** | Headless UI — builds card form field-by-field using individual `SPLTextField` components. |
| 4 | **Custom Theme** | Custom light/dark themes applied to `SPLTextField` components. |
| 5 | **CVV Recaching** | Update CVV on a saved payment method (sheet or dialog presentation). |
| 6 | **3DS Global Flow** | Purchase with Forter-based Global 3D Secure challenge. |
| 7 | **3DS Gateway-Specific** | Purchase with gateway-specific 3DS (device fingerprint, challenge, frictionless). |
| 8 | **Offsite Payment** | PayPal / Sprel offsite redirect-based payment flow. |
| 9 | **EBANX Payment** | Pix, Boleto, OXXO, NuPay offsite payment methods via EBANX. |
| 10 | **Stripe APM** | Stripe Alternative Payment Methods via `SpreedlyStripeAPM`. |
| 11 | **Braintree Payment** | PayPal / Venmo via `SpreedlyBraintree`. |

## Project Structure

```
checkout-ios-example/
  README.md
  LICENSE
  .gitignore
  SpreedlyKeys.xcconfig.example

  Shared/                              # Shared source files (both variants)
    Swift/                             # SwiftUI views, config, API clients
    ObjC/                              # UIKit view controllers, config, API clients

  ExampleSPM/                          # SPM variant
    project.yml                        # XcodeGen spec
    MerchantExampleSPM.xcodeproj       # Generated (git-ignored)
    MerchantExampleSPM/                # Swift/SwiftUI entry point
    MerchantExampleSPMObjC/            # ObjC/UIKit entry point

  ExampleCocoaPods/                    # CocoaPods variant
    project.yml                        # XcodeGen spec
    Podfile
    Gemfile
    MerchantExamplePods.xcodeproj      # Generated by pod install (git-ignored)
    MerchantExamplePods.xcworkspace    # Generated by pod install (git-ignored)
    MerchantExamplePods/               # Swift/SwiftUI entry point
    MerchantExamplePodsObjC/           # ObjC/UIKit entry point
    Config/                            # Wrapper xcconfigs (merge keys + Pods configs)
```

## SDK Documentation

- [Getting Started Guide](docs/guides/getting-started.md)
- [SDK Distribution](https://github.com/spreedly/checkout-ios-package)

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
