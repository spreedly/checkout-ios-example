import SwiftUI
import SpreedlyUI

/// Custom light theme factory with a modern, gradient-based design
/// Uses SpreedlyThemeManager.createCustomTheme() for proper accessibility support
public func createCustomSpreedlyLightTheme() -> SpreedlyTheme {
    return SpreedlyThemeManager.createCustomTheme(
        colors: customLightColors,
        typography: customTypography,
        spacing: customSpacing,
        borderRadius: customBorderRadius,
        shadows: customLightShadows
    )
}

/// Custom dark theme factory with a modern, gradient-based design
/// Uses SpreedlyThemeManager.createC ustomTheme() for proper accessibility support
public func createCustomSpreedlyDarkTheme() -> SpreedlyTheme {
    return SpreedlyThemeManager.createCustomTheme(
        colors: customDarkColors,
        typography: customTypography,
        spacing: customSpacing,
        borderRadius: customBorderRadius,
        shadows: customDarkShadows
    )
}

// MARK: - Custom Light Colors
fileprivate var customLightColors: SpreedlyColors {
    return SpreedlyColors(
        primary: Color(red: 0.4, green: 0.2, blue: 0.8), // Deep purple
        secondary: Color(red: 0.8, green: 0.3, blue: 0.6), // Magenta
        accent: Color(red: 1.0, green: 0.7, blue: 0.2), // Golden yellow
        background: Color.clear, // Very light purple tint
        surface: Color.white,
        text: Color(red: 0.15, green: 0.1, blue: 0.25), // Dark purple-gray
        textSecondary: Color(red: 0.5, green: 0.45, blue: 0.6), // Medium purple-gray
        border: Color(red: 0.85, green: 0.8, blue: 0.9), // Light purple-gray
        borderFocused: Color(red: 0.4, green: 0.2, blue: 0.8), // Deep purple
        error: Color(red: 0.8, green: 0.2, blue: 0.4), // Pink-red
        success: Color(red: 0.2, green: 0.6, blue: 0.4), // Teal green
        warning: Color(red: 1.0, green: 0.6, blue: 0.2), // Orange
        disabled: Color(red: 0.75, green: 0.7, blue: 0.8), // Light purple-gray
        placeholder: Color(red: 0.65, green: 0.6, blue: 0.75) // Medium purple-gray
    )
}

// MARK: - Custom Dark Colors
fileprivate var customDarkColors: SpreedlyColors {
    return SpreedlyColors(
        primary: Color(red: 0.6, green: 0.4, blue: 1.0), // Bright purple
        secondary: Color(red: 0.9, green: 0.5, blue: 0.8), // Light magenta
        accent: Color(red: 1.0, green: 0.8, blue: 0.4), // Light golden yellow
        background: Color.clear,
        surface: Color(red: 0.1, green: 0.1, blue: 0.15), // Dark purple-gray
        text: Color(red: 0.95, green: 0.9, blue: 1.0), // Light purple-white
        textSecondary: Color(red: 0.7, green: 0.65, blue: 0.8), // Medium purple-gray
        border: Color(red: 0.3, green: 0.25, blue: 0.4), // Dark purple-gray
        borderFocused: Color(red: 0.6, green: 0.4, blue: 1.0), // Bright purple
        error: Color(red: 1.0, green: 0.3, blue: 0.5), // Bright pink-red
        success: Color(red: 0.3, green: 0.8, blue: 0.5), // Bright teal green
        warning: Color(red: 1.0, green: 0.7, blue: 0.3), // Bright orange
        disabled: Color(red: 0.4, green: 0.35, blue: 0.5), // Medium dark purple-gray
        placeholder: Color(red: 0.5, green: 0.45, blue: 0.6) // Medium purple-gray
    )
}

// MARK: - Custom Typography
fileprivate var customTypography: SpreedlyTypography {
    return SpreedlyTypography(
        titleFont: SpreedlyFont.system(size: 28, weight: .bold, design: .rounded),
        subtitleFont: SpreedlyFont.system(size: 22, weight: .semibold, design: .rounded),
        bodyFont: SpreedlyFont.system(size: 16, weight: .regular, design: .rounded),
        captionFont: SpreedlyFont.system(size: 14, weight: .medium, design: .rounded),
        buttonFont: SpreedlyFont.system(size: 18, weight: .semibold, design: .rounded),
        fieldFont: SpreedlyFont.system(size: 16, weight: .regular, design: .rounded)
    )
}

// MARK: - Custom Spacing
fileprivate var customSpacing: SpreedlySpacing {
    return SpreedlySpacing(
        xs: 4,
        sm: 8,
        md: 16,
        lg: 24,
        xl: 32,
        xxl: 48
    )
}

// MARK: - Custom Border Radius
fileprivate var customBorderRadius: SpreedlyBorderRadius {
    return SpreedlyBorderRadius(
        xs: 4,
        sm: 8,
        md: 12,
        lg: 16,
        xl: 24
    )
}

// MARK: - Custom Light Shadows
fileprivate var customLightShadows: SpreedlyShadows {
    return SpreedlyShadows(
        small: Shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1),
        medium: Shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2),
        large: Shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    )
}

// MARK: - Custom Dark Shadows
fileprivate var customDarkShadows: SpreedlyShadows {
    return SpreedlyShadows(
        small: Shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1),
        medium: Shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2),
        large: Shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
    )
}

// MARK: - View Extension for Custom Shadow
extension View {
    func customShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
} 
