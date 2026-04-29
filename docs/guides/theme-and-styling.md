# Theming and Customization - Spreedly iOS SDK

Customize the look and feel of all SDK payment components to match your brand.

**Estimated integration time:** ~15 minutes

## Table of Contents

- [Introduction](#introduction)
- [Theme Priority](#theme-priority)
- [Quick Start](#quick-start)
- [Global Theme Setup](#global-theme-setup)
- [Component-Level Theme Override](#component-level-theme-override)
- [SpreedlyColors Properties](#spreedlycolors-properties)
- [Deprecated / Removed Theme APIs](#deprecated--removed-theme-apis)
- [SpreedlyTheme Configuration](#spreedlytheme-configuration)
- [SpreedlyShadows](#spreedlyshadows)
- [UIKit Integration](#uikit-integration)
- [Objective-C Integration](#objective-c-integration)
- [Light and Dark Mode](#light-and-dark-mode)
- [Accessibility](#accessibility)
- [Complete Examples](#complete-examples)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

---

## Prerequisites

- Complete [Getting Started](getting-started.md) (SDK installed and initialized)
- `import SpreedlyCore` and `import SpreedlyUI` in files where you customize themes

---

## Introduction

The Spreedly iOS SDK provides theming support that lets you match payment components to your brand. Features:

- **Separate light and dark themes** with automatic switching based on device color scheme
- **Global and component-level themes** for fine-grained control
- **Full customization** of colors, typography, spacing, and border radius
- **UIKit and Objective-C support** via `SPLThemeConfig`

All SDK components (CardFormDropIn, SPLTextField, SpreedlyCVVRecachingView) respect the theming system.

---

## Theme Priority

Themes are resolved in this order (highest to lowest priority):

1. **Custom theme** passed directly to a component (e.g. `CardFormDropIn(theme: myTheme)`)
2. **Environment theme** (if set)
3. **Global theme** set via `SpreedlyThemeManager.setGlobalTheme(lightTheme:darkTheme:)`
4. **Default theme** built into the SDK

If you pass a theme directly to a component, it always wins over the global theme.

---

## Quick Start

Set a global theme that applies to all SDK components:

```swift
import SpreedlyUI

let lightTheme = SpreedlyThemeManager.createCustomTheme(
    colors: SpreedlyColors(
        primary: Color.blue,
        background: Color.white,
        text: Color.black
    )
)

let darkTheme = SpreedlyThemeManager.createCustomTheme(
    colors: SpreedlyColors(
        primary: Color.cyan,
        background: Color.black,
        text: Color.white
    )
)

SpreedlyThemeManager.setGlobalTheme(lightTheme: lightTheme, darkTheme: darkTheme)
```

All SDK components will now use these themes automatically, switching between light and dark based on the device color scheme.

---

## Global Theme Setup

### SwiftUI

Set the global theme once, typically at app launch or before presenting any payment UI:

```swift
import SpreedlyUI

let lightTheme = SpreedlyThemeManager.createCustomTheme(
    colors: SpreedlyColors(
        primary: Color(hex: "#007AFF"),
        background: Color(hex: "#F5F5F5"),
        text: Color(hex: "#1A1A1A"),
        textSecondary: Color(hex: "#666666"),
        error: Color(hex: "#FF3B30"),
        surface: Color.white,
        border: Color(hex: "#E0E0E0"),
        borderFocused: Color(hex: "#007AFF"),
        placeholder: Color(hex: "#999999")
    )
)

let darkTheme = SpreedlyThemeManager.createCustomTheme(
    colors: SpreedlyColors(
        primary: Color(hex: "#0A84FF"),
        background: Color(hex: "#1C1C1E"),
        text: Color.white,
        textSecondary: Color(hex: "#8E8E93"),
        error: Color(hex: "#FF453A"),
        surface: Color(hex: "#2C2C2E"),
        border: Color(hex: "#38383A"),
        borderFocused: Color(hex: "#0A84FF"),
        placeholder: Color(hex: "#636366")
    )
)

SpreedlyThemeManager.setGlobalTheme(lightTheme: lightTheme, darkTheme: darkTheme)
```

After setting the global theme, all SDK components (CardFormDropIn, SPLTextField, SpreedlyCVVRecachingView) will use it automatically.

---

## Component-Level Theme Override

Override the global theme for a specific component by passing `theme` and `darkTheme` parameters:

### CardFormDropIn

```swift
CardFormDropIn(
    theme: customLightTheme,
    darkTheme: customDarkTheme,
    onProcessingResult: { result in
        if result.isProcessing { /* Show loading indicator */ }
        else if result.isValidationFailed { /* Show validation errors */ }
    }
)
```

> **Note:** `onProcessingResult` fires for validation status only (`isProcessing`, `isValidationFailed`). Success and failure are delivered via `subscribeToPaymentResults` (Swift) or `paymentDelegate` (Obj-C).

### SpreedlyCVVRecachingView

```swift
SpreedlyCVVRecachingView(
    config: recacheConfig,
    paymentMethodToken: token,
    theme: customLightTheme,
    darkTheme: customDarkTheme,
    onProcessingResult: { result in
        // Handle result
    },
    onDismiss: {
        showRecaching = false
    }
)
```

### SPLTextField

**Method 1: Direct parameters (recommended)**

Pass `theme` and `darkTheme` directly to each field. The SDK automatically switches between them based on the device's color scheme:

```swift
SPLTextField(
    type: .cardNumber,
    title: "Card Number",
    isRequired: true,
    theme: customLightTheme,
    darkTheme: customDarkTheme,
    onValidationChange: { isValid in
        cardNumberValid = isValid
    }
)
```

**Method 2: Environment modifier**

Alternatively, apply a theme to all `SPLTextField` instances in a view hierarchy using the `.spreedlyTheme()` modifier:

```swift
SPLTextField(
    type: .cardNumber,
    title: "Card Number",
    isRequired: true,
    onValidationChange: { isValid in
        cardNumberValid = isValid
    }
)
.spreedlyTheme(customLightTheme)
```

> Direct parameters take precedence over the environment modifier. If both are set, the direct `theme`/`darkTheme` values win.

---

## SpreedlyColors Properties

| Property | Description | Example |
|----------|-------------|---------|
| `primary` | Primary accent color (buttons, focused borders) | Brand blue |
| `secondary` | Secondary color | Gray |
| `accent` | Accent color for highlights | Orange |
| `background` | Main background color | White or dark gray |
| `surface` | Card/container surface color | White or dark surface |
| `text` | Primary text color | Black or white |
| `textSecondary` | Secondary/muted text color | Gray |
| `border` | Default border color | Light gray |
| `borderFocused` | Border color when a field is focused | Primary color |
| `error` | Error state color | Red |
| `success` | Success state color | Green |
| `warning` | Warning state color | Orange |
| `disabled` | Disabled state color | Gray |
| `placeholder` | Placeholder text color | Light gray |

---

## Deprecated / Removed Theme APIs

The following methods are **no longer available** (they have been removed or commented out in the SDK):

- `SpreedlyThemeManager.setDarkTheme()` — Use `SpreedlyThemeManager.setGlobalTheme(lightTheme:darkTheme:)` instead
- `SpreedlyThemeManager.setLightTheme()` — Use `SpreedlyThemeManager.setGlobalTheme(lightTheme:darkTheme:)` instead
- `SpreedlyThemeManager.resetToDefaultTheme()` — Use `SpreedlyThemeManager.setGlobalTheme(lightTheme:darkTheme:)` with default themes instead

### SpreedlyThemeManager API

| Property/Method | Type | Description |
|----------------|------|-------------|
| `themeChangedNotification` | `Notification.Name` | Posted when the global theme changes. Use with `NotificationCenter.default.addObserver` to respond to theme updates. |
| `updateThemeForCurrentColorScheme()` | — | Updates the active theme based on the current system color scheme (light/dark mode). |

---

## SpreedlyTheme Configuration

`SpreedlyTheme` is a protocol. Create themes using `SpreedlyThemeManager.createCustomTheme()`:

```swift
let theme = SpreedlyThemeManager.createCustomTheme(
    colors: SpreedlyColors(
        primary: Color.blue,
        background: Color.white,
        text: Color.black,
        textSecondary: Color.gray,
        error: Color.red,
        surface: Color.white,
        border: Color(hex: "#E0E0E0"),
        borderFocused: Color.blue,
        placeholder: Color(hex: "#999999")
    ),
    typography: SpreedlyTypography(
        titleFont: SpreedlyFont.system(size: 24, weight: .bold),
        bodyFont: SpreedlyFont.system(size: 16, weight: .regular)
    ),
    spacing: SpreedlySpacing(
        xs: 4,
        sm: 8,
        md: 16,
        lg: 24,
        xl: 32,
        xxl: 48
    ),
    borderRadius: SpreedlyBorderRadius(
        xs: 4,
        sm: 8,
        md: 12,
        lg: 16,
        xl: 24
    ),
    shadows: SpreedlyShadows(
        small: Shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1),
        medium: Shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2),
        large: Shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    )
)
```

### SpreedlyThemeManager.createThemeFromAndroidConfig

This method is for **cross-platform apps** that share theme configuration between iOS and Android. It accepts hex color strings (the format used by the Android SDK's theme system) and maps them to the iOS SDK's `SpreedlyColors` and `SpreedlyBorderRadius`. If your app is iOS-only, you can skip this and use `SpreedlyTheme` directly.

Create an iOS theme from Android theme configuration:

```swift
let theme = SpreedlyThemeManager.createThemeFromAndroidConfig(
    primaryColor: "#0077C8",
    secondaryColor: "#AFB4B5",
    formBorderColor: "#D9D9D9",
    formBackgroundColor: "#FFFFFF",
    fieldBackgroundColor: "#F8F9FA",
    fieldLabelColor: "#6C757D",
    borderRadius: 8.0
)
```

This maps Android-style theme parameters to `SpreedlyColors` and `SpreedlyBorderRadius`, so you can share the same design tokens across iOS and Android.

### SpreedlyTypography Properties

Use `SpreedlyFont.system(size:weight:design:)` or `SpreedlyFont.custom(fontName:size:weight:design:)` for typography. Properties: `titleFont`, `subtitleFont`, `bodyFont`, `captionFont`, `buttonFont`, `fieldFont`.

### SpreedlyShadows

`SpreedlyTheme` includes `shadows: SpreedlyShadows` with `small`, `medium`, and `large` `Shadow` values:

| Property | Description |
|----------|-------------|
| `small` | Subtle shadow (radius: 2, y: 1) |
| `medium` | Medium elevation (radius: 4, y: 2) |
| `large` | Strong shadow (radius: 8, y: 4) |

Each `Shadow` has `color`, `radius`, `x`, and `y` properties.

---

## UIKit Integration

UIKit components use `SPLThemeConfig` for theming:

```swift
import SpreedlyUI

let lightThemeConfig = SPLThemeConfig(
    primaryColor: .systemBlue,
    secondaryColor: .systemGray,
    backgroundColor: .white,
    surfaceColor: .white,
    borderColor: .systemGray4,
    borderFocusedColor: .systemBlue,
    textColor: .black,
    textSecondaryColor: .systemGray,
    errorColor: .systemRed,
    placeholderColor: nil,
    borderRadius: 8.0
)

let darkThemeConfig = SPLThemeConfig(
    primaryColor: .systemBlue,
    secondaryColor: .systemGray,
    backgroundColor: .black,
    surfaceColor: .systemGray6,
    borderColor: .systemGray2,
    borderFocusedColor: .systemBlue,
    textColor: .white,
    textSecondaryColor: .systemGray,
    errorColor: .systemRed,
    placeholderColor: nil,
    borderRadius: 8.0
)

let recachingVC = CVVRecachingViewController(
    lastFourDigits: "4242",
    cardType: "Visa",
    cardBrand: "visa",
    paymentMethodToken: token,
    presentationMode: 0,
    labelText: "CVV",
    placeholderText: "123",
    buttonText: "Confirm",
    cancelButtonText: "Cancel",
    lightThemeConfig: lightThemeConfig,
    darkThemeConfig: darkThemeConfig,
    onProcessingResult: { result in
        // Handle result
    }
)

present(recachingVC, animated: true)
```

### SPLThemeConfig Properties

| Property | Type | Description |
|----------|------|-------------|
| `primaryColor` | `UIColor` | Primary accent color |
| `secondaryColor` | `UIColor` | Secondary color |
| `backgroundColor` | `UIColor` | Background color |
| `surfaceColor` | `UIColor` | Card/container surface color |
| `borderColor` | `UIColor` | Default border color |
| `borderFocusedColor` | `UIColor` | Focused border color |
| `textColor` | `UIColor` | Primary text color |
| `textSecondaryColor` | `UIColor` | Secondary text color |
| `errorColor` | `UIColor` | Error state color |
| `placeholderColor` | `UIColor?` | Placeholder text color (optional) |
| `borderRadius` | `CGFloat` | Corner radius for inputs |

---

## Objective-C Integration

### Setting Global Theme with SPLThemeConfig

Use `SpreedlyThemeManagerObjC` to set light and dark themes from Objective-C:

```objc
[SpreedlyThemeManagerObjC setGlobalThemeWithLightConfig:lightThemeConfig darkConfig:darkThemeConfig];
```

### SPLThemeConfig Usage

```objc
#import <SpreedlyUI/SpreedlyUI-Swift.h>

SPLThemeConfig *lightThemeConfig = [[SPLThemeConfig alloc]
    initWithPrimaryColor:[UIColor systemBlueColor]
    secondaryColor:[UIColor systemGrayColor]
    backgroundColor:[UIColor whiteColor]
    surfaceColor:[UIColor whiteColor]
    borderColor:[UIColor systemGray4Color]
    borderFocusedColor:[UIColor systemBlueColor]
    textColor:[UIColor blackColor]
    textSecondaryColor:[UIColor systemGrayColor]
    errorColor:[UIColor systemRedColor]
    placeholderColor:nil
    borderRadius:8.0];

SPLThemeConfig *darkThemeConfig = [[SPLThemeConfig alloc]
    initWithPrimaryColor:[UIColor systemBlueColor]
    secondaryColor:[UIColor systemGrayColor]
    backgroundColor:[UIColor blackColor]
    surfaceColor:[UIColor systemGray6Color]
    borderColor:[UIColor systemGray2Color]
    borderFocusedColor:[UIColor systemBlueColor]
    textColor:[UIColor whiteColor]
    textSecondaryColor:[UIColor systemGrayColor]
    errorColor:[UIColor systemRedColor]
    placeholderColor:nil
    borderRadius:8.0];

CVVRecachingViewController *recachingVC = [[CVVRecachingViewController alloc]
    initWithLastFourDigits:@"4242"
    cardType:@"Visa"
    cardBrand:@"visa"
    paymentMethodToken:token
    presentationMode:0
    labelText:@"CVV"
    placeholderText:@"123"
    buttonText:@"Confirm"
    cancelButtonText:@"Cancel"
    lightThemeConfig:lightThemeConfig
    darkThemeConfig:darkThemeConfig
    onProcessingResult:^(PaymentProcessingResult *result) {
        // Handle result
    }];

[self presentViewController:recachingVC animated:YES completion:nil];
```

---

## Light and Dark Mode

### Automatic Switching

When you set both light and dark themes, the SDK automatically switches based on the device color scheme:

```swift
SpreedlyThemeManager.setGlobalTheme(
    lightTheme: lightTheme,
    darkTheme: darkTheme
)
```

Components detect `@Environment(\.colorScheme)` changes and apply the appropriate theme.

### Single Theme Fallback

If you only set one theme, it applies to both light and dark mode:

```swift
SpreedlyThemeManager.setGlobalTheme(lightTheme: singleTheme, darkTheme: singleTheme)
```

### Per-Component Override

Override the automatic behavior for a specific component:

```swift
CardFormDropIn(
    theme: alwaysLightTheme,
    darkTheme: alwaysLightTheme,
    onProcessingResult: { result in
        // Handle result
    }
)
```

---

## Accessibility

### Dynamic Type

The SDK respects the user's Dynamic Type settings. Text sizes scale automatically based on the system font size preference. No additional configuration is required.

### Bold Text

When the user enables Bold Text in iOS settings, the SDK components automatically use bolder font weights. `CardFormDropIn`, `SPLTextField`, and `CVVRecachingView` manage Bold Text and Dynamic Type observers internally and refresh typography when settings change — no extra setup is needed when using these components.

### Refreshing on Accessibility Changes

If your app uses custom themes with `SpreedlyTypography` **outside** of SDK components (e.g., in your own views that reference SDK theme objects), listen for Dynamic Type and Bold Text changes and refresh the theme so typography updates immediately:

```swift
// Listen for content size category and bold text changes
NotificationCenter.default.addObserver(
    forName: UIContentSizeCategory.didChangeNotification,
    object: nil,
    queue: .main
) { _ in
    refreshCustomThemes()
}

NotificationCenter.default.addObserver(
    forName: UIAccessibility.boldTextStatusDidChangeNotification,
    object: nil,
    queue: .main
) { _ in
    refreshCustomThemes()
}

func refreshCustomThemes() {
    if let customTheme = lightTheme as? SpreedlyCustomTheme {
        let refreshedTypography = customTheme.typography.refreshed()
        lightTheme = SpreedlyCustomTheme(
            colors: customTheme.colors,
            typography: refreshedTypography,
            spacing: customTheme.spacing,
            borderRadius: customTheme.borderRadius,
            shadows: customTheme.shadows
        )
    }
}
```

**`typography.refreshed()`** — On `SpreedlyCustomTheme`, call `typography.refreshed()` to rebuild font metrics for the current Dynamic Type and Bold Text settings. Returns a new `SpreedlyTypography` instance with fonts scaled for the user's accessibility preferences. Use this when handling `UIContentSizeCategory.didChangeNotification` and `UIAccessibility.boldTextStatusDidChangeNotification` to ensure typography updates immediately.

### VoiceOver

All SDK components include accessibility labels and hints for VoiceOver users. Form fields announce their type, validation state, and required status.

---

## Complete Examples

### SwiftUI with CardFormDropIn

```swift
import SwiftUI
import SpreedlyUI

struct ThemedCheckoutView: View {
    @State private var showCheckout = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    let brandLight = SpreedlyThemeManager.createCustomTheme(
        colors: SpreedlyColors(
            primary: Color(hex: "#6200EE"),
            background: Color(hex: "#FAFAFA"),
            text: Color(hex: "#212121"),
            textSecondary: Color(hex: "#757575"),
            error: Color(hex: "#B00020"),
            surface: Color.white,
            border: Color(hex: "#E0E0E0"),
            borderFocused: Color(hex: "#6200EE"),
            placeholder: Color(hex: "#9E9E9E")
        )
    )

    let brandDark = SpreedlyThemeManager.createCustomTheme(
        colors: SpreedlyColors(
            primary: Color(hex: "#BB86FC"),
            background: Color(hex: "#121212"),
            text: Color(hex: "#E0E0E0"),
            textSecondary: Color(hex: "#A0A0A0"),
            error: Color(hex: "#CF6679"),
            surface: Color(hex: "#1E1E1E"),
            border: Color(hex: "#333333"),
            borderFocused: Color(hex: "#BB86FC"),
            placeholder: Color(hex: "#666666")
        )
    )

    var body: some View {
        Button("Checkout") {
            showCheckout = true
        }
        .sheet(isPresented: $showCheckout) {
            CardFormDropIn(
                theme: brandLight,
                darkTheme: brandDark,
                onProcessingResult: { result in
                    if result.isProcessing { isLoading = true }
                    else if result.isValidationFailed { errorMessage = result.getDescription() }
                }
            )
            .screenPrevention()
        }
    }
}
```

### UIKit with CVVRecachingViewController

```swift
import UIKit
import SpreedlyUI

class ThemedRecacheViewController: UIViewController {
    func showRecache() {
        let lightConfig = SPLThemeConfig(
            primaryColor: UIColor(red: 0.384, green: 0, blue: 0.933, alpha: 1),
            secondaryColor: .systemGray,
            backgroundColor: UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1),
            surfaceColor: .white,
            borderColor: UIColor(red: 0.878, green: 0.878, blue: 0.878, alpha: 1),
            borderFocusedColor: UIColor(red: 0.384, green: 0, blue: 0.933, alpha: 1),
            textColor: UIColor(red: 0.129, green: 0.129, blue: 0.129, alpha: 1),
            textSecondaryColor: UIColor(red: 0.459, green: 0.459, blue: 0.459, alpha: 1),
            errorColor: UIColor(red: 0.69, green: 0, blue: 0.125, alpha: 1),
            placeholderColor: nil,
            borderRadius: 12.0
        )

        let recachingVC = CVVRecachingViewController(
            lastFourDigits: "4242",
            cardType: "Visa",
            cardBrand: "visa",
            paymentMethodToken: "token_123",
            presentationMode: 0,
            labelText: "CVV",
            placeholderText: "123",
            buttonText: "Confirm",
            cancelButtonText: "Cancel",
            lightThemeConfig: lightConfig,
            darkThemeConfig: nil,
            onProcessingResult: { result in
                // Handle result
            }
        )

        present(recachingVC, animated: true)
    }
}
```

---

## Troubleshooting

**Theme not applying:**

- Verify `SpreedlyThemeManager.setGlobalTheme(lightTheme:darkTheme:)` is called before presenting any SDK components
- Check that you are passing the theme to the correct parameter (`theme` for light, `darkTheme` for dark)
- Component-level themes override global themes; check if a component has an explicit theme set

**Dark mode not switching:**

- Ensure you set both `lightTheme` and `darkTheme` parameters
- Verify the device or simulator is actually in dark mode (Settings > Display & Brightness)
- Check that you are not overriding with a single theme on the component

**Colors appearing wrong:**

- Double-check hex values and color space
- Verify colors render correctly in both light and dark mode
- Test on a physical device as simulator colors may differ slightly

**UIKit theme not matching SwiftUI:**

- UIKit uses `SPLThemeConfig` with `UIColor`; SwiftUI uses `SpreedlyColors` with `Color`
- Ensure equivalent color values are used in both configurations

---

## Related Documentation

- [express-checkout.md](express-checkout.md) - CardFormDropIn with theming
- [recaching.md](recaching.md) - CVV recaching with custom themes
- [custom-payment-forms.md](custom-payment-forms.md) - SPLTextField with theming
- [objective-c.md](objective-c.md) - Objective-C theme configuration
