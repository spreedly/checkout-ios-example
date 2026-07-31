//
//  MerchantThemeConfigurationCard.swift
//  SpreedlySDKExample
//
//  Theme picker card shared by merchant demo screens (Custom Form pattern).
//

import SwiftUI
import SpreedlyUI

struct MerchantThemeConfigurationCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.spreedlyTheme) private var theme

    @Binding var useCustomTheme: Bool
    @Binding var lightTheme: SpreedlyTheme?
    @Binding var darkTheme: SpreedlyTheme?
    @Binding var selectedTheme: ThemeOption

    let titleAccessibilityIdentifier: String
    let toggleAccessibilityIdentifier: String
    let onThemeChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme Configuration")
                .font(.headline)
                .accessibilityIdentifier(titleAccessibilityIdentifier)
                .accessibilityAddTraits(.isHeader)

            Toggle(
                "Use Custom Theme",
                isOn: Binding(
                    get: { useCustomTheme },
                    set: { newValue in
                        useCustomTheme = newValue
                        if !newValue {
                            lightTheme = nil
                            darkTheme = nil
                            selectedTheme = .default
                        }
                        onThemeChanged()
                    }
                )
            )
            .spreedlyThemedSwitchToggle(tint: theme.colors.primary)
            .accessibilityIdentifier(toggleAccessibilityIdentifier)

            HStack {
                Text("Current Theme:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Circle()
                    .fill(swatchColor(selectedTheme))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1))
                Text(selectedTheme.displayName)
                    .font(.subheadline)
                    .foregroundColor(useCustomTheme ? .blue : .gray)
            }
            .padding(.top, 4)

            if useCustomTheme {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick a color:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 16) {
                        themeSwatch(option: .blue, swatchColor: .blue) { apply(.blue) }
                        themeSwatch(option: .green, swatchColor: .green) { apply(.green) }
                        themeSwatch(option: .purple, swatchColor: .purple) { apply(.purple) }
                    }

                    Button("Reset to Default") {
                        lightTheme = nil
                        darkTheme = nil
                        selectedTheme = .default
                        onThemeChanged()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }

            Text("Drop-ins that read `SpreedlyThemeManager.globalTheme` pick up this theme when their sheet opens — choose a theme here, then open a payment flow to preview it.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: cardShadowColor, radius: 4, x: 0, y: 0)
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color.white
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(white: 0.3) : Color(white: 0.85)
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }

    private func swatchColor(_ option: ThemeOption) -> Color {
        switch option {
        case .default: return Color.gray.opacity(0.45)
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        }
    }

    private func apply(_ option: ThemeOption) {
        guard let themes = MerchantThemePresets.lightAndDarkThemes(for: option) else { return }
        lightTheme = themes.light
        darkTheme = themes.dark
        selectedTheme = option
        onThemeChanged()
    }

    private func themeSwatch(
        option: ThemeOption,
        swatchColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        let isSelected = selectedTheme == option
        return Button(action: action) {
            ZStack {
                Circle()
                    .fill(swatchColor)
                    .frame(width: 40, height: 40)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    .frame(width: 40, height: 40)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 3)
                        .frame(width: 46, height: 46)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.displayName) theme color")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
