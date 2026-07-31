//
//  ClickToPayRecognizedDevicePanel.swift
//  SpreedlySDKExample
//

import SwiftUI
import SpreedlyUI

struct ClickToPayRecognizedDevicePanel: View {
    @Environment(\.spreedlyTheme) private var theme

    let title: String
    let bodyText: String
    var cardLabels: [String] = []
    var showProgress = false
    var linkText: String?
    var onLinkTap: (() -> Void)?
    var linkEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(title)
                .font(theme.typography.subtitleFont)
                .foregroundColor(theme.colors.text)

            if showProgress {
                ProgressView()
                    .progressViewStyle(.circular)
            }

            Text(bodyText)
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.textSecondary)

            if !cardLabels.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    ForEach(cardLabels, id: \.self) { label in
                        Text(label)
                            .font(theme.typography.captionFont)
                            .foregroundColor(theme.colors.text)
                            .padding(.horizontal, theme.spacing.sm)
                            .padding(.vertical, theme.spacing.xs)
                            .background(theme.colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: theme.borderRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.borderRadius.md)
                                    .stroke(theme.colors.border, lineWidth: 1)
                            )
                    }
                }
            }

            if let linkText, let onLinkTap {
                Button(action: onLinkTap) {
                    Text(linkText)
                        .font(theme.typography.captionFont)
                        .foregroundColor(linkEnabled ? theme.colors.primary : theme.colors.disabled)
                }
                .disabled(!linkEnabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.borderRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: theme.borderRadius.lg)
                .stroke(theme.colors.border, lineWidth: 1)
        )
    }
}
