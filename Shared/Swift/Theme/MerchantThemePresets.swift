//
//  MerchantThemePresets.swift
//  SpreedlySDKExample
//
//  Shared light/dark SpreedlyTheme presets for merchant demo screens.
//

import SwiftUI
import SpreedlyUI

enum MerchantThemePresets {
    static func lightAndDarkThemes(for option: ThemeOption) -> (light: SpreedlyTheme, dark: SpreedlyTheme)? {
        switch option {
        case .default:
            return nil
        case .blue:
            return (blueLight, blueDark)
        case .green:
            return (greenLight, greenDark)
        case .purple:
            return (purpleLight, purpleDark)
        }
    }

    /// Applies SDK global theme for drop-ins that read `SpreedlyThemeManager.globalTheme`.
    static func applyGlobalTheme(
        useCustomTheme: Bool,
        lightTheme: SpreedlyTheme?,
        darkTheme: SpreedlyTheme?
    ) {
        if useCustomTheme, let lightTheme, let darkTheme {
            SpreedlyThemeManager.setGlobalTheme(lightTheme: lightTheme, darkTheme: darkTheme)
        } else {
            SpreedlyThemeManager.setGlobalTheme(
                lightTheme: SpreedlyThemeManager.createCustomTheme(),
                darkTheme: SpreedlyThemeManager.createCustomTheme(colors: sdkDefaultDarkColors)
            )
        }
    }

    private static let sdkDefaultDarkColors = SpreedlyColors(
        primary: Color(hex: "#0077C8"),
        secondary: Color(hex: "#6C757D"),
        accent: Color(hex: "#FF9500"),
        background: Color(hex: "#000000"),
        surface: Color(hex: "#1C1C1E"),
        text: Color(hex: "#FFFFFF"),
        textSecondary: Color(hex: "#AEAEB2"),
        border: Color(hex: "#3A3A3C"),
        borderFocused: Color(hex: "#0077C8"),
        error: Color(hex: "#FF3B30"),
        success: Color(hex: "#34C759"),
        warning: Color(hex: "#FF9500"),
        disabled: Color(hex: "#6C757D"),
        placeholder: Color(hex: "#8E8E93")
    )

    private static let blueLight = SpreedlyThemeManager.createCustomTheme(
        colors: SpreedlyColors(
            primary: Color.blue,
            secondary: Color.blue.opacity(0.7),
            background: Color.white,
            surface: Color.white,
            text: Color.black,
            textSecondary: Color.gray,
            border: Color.blue.opacity(0.3),
            borderFocused: Color.blue,
            error: Color.red
        )
    )

    private static let blueDark = SpreedlyThemeManager.createCustomTheme(
        colors: SpreedlyColors(
            primary: Color.blue,
            secondary: Color.blue.opacity(0.7),
            background: Color.black,
            surface: Color(hex: "#1C1C1E"),
            text: Color.white,
            textSecondary: Color.gray.opacity(0.8),
            border: Color.blue.opacity(0.5),
            borderFocused: Color.blue,
            error: Color.red
        )
    )

    private static let greenLight = SpreedlyThemeManager.createCustomTheme(
        colors: SpreedlyColors(
            primary: Color.green,
            secondary: Color.green.opacity(0.7),
            background: Color.white,
            surface: Color.white,
            text: Color.black,
            textSecondary: Color.gray,
            border: Color.green.opacity(0.3),
            borderFocused: Color.green,
            error: Color.red
        )
    )

    private static let greenDark = SpreedlyThemeManager.createCustomTheme(
        colors: SpreedlyColors(
            primary: Color.green,
            secondary: Color.green.opacity(0.7),
            background: Color.black,
            surface: Color(hex: "#1C1C1E"),
            text: Color.white,
            textSecondary: Color.gray.opacity(0.8),
            border: Color.green.opacity(0.5),
            borderFocused: Color.green,
            error: Color.red
        )
    )

    private static let purpleLight = SpreedlyThemeManager.createCustomTheme(
        colors: SpreedlyColors(
            primary: Color.purple,
            secondary: Color.purple.opacity(0.7),
            background: Color.white,
            surface: Color.white,
            text: Color.black,
            textSecondary: Color.gray,
            border: Color.purple.opacity(0.3),
            borderFocused: Color.purple,
            error: Color.red
        )
    )

    private static let purpleDark = SpreedlyThemeManager.createCustomTheme(
        colors: SpreedlyColors(
            primary: Color.purple,
            secondary: Color.purple.opacity(0.7),
            background: Color.black,
            surface: Color(hex: "#1C1C1E"),
            text: Color.white,
            textSecondary: Color.gray.opacity(0.8),
            border: Color.purple.opacity(0.5),
            borderFocused: Color.purple,
            error: Color.red
        )
    )
}
