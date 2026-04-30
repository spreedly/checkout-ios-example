//
//  MessageView.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import SwiftUI
import SpreedlyUI

// MARK: - Message View
/// Reusable message view component for displaying success and error messages
/// Supports theming, accessibility, and optional additional content
struct MessageView: View {
    @Environment(\.spreedlyTheme) private var theme
    
    let type: MessageType
    let title: String
    let message: String
    let additionalContent: (() -> AnyView)?
    
    // Accessibility identifiers - optional for flexibility
    let iconAccessibilityIdentifier: String?
    let iconAccessibilityLabel: String?
    let iconAccessibilityHint: String?
    let titleAccessibilityIdentifier: String?
    let titleAccessibilityLabel: String?
    let titleAccessibilityHint: String?
    let messageAccessibilityIdentifier: String?
    let messageAccessibilityHint: String?
    
    init(
        type: MessageType,
        title: String,
        message: String,
        additionalContent: (() -> AnyView)? = nil,
        iconAccessibilityIdentifier: String? = nil,
        iconAccessibilityLabel: String? = nil,
        iconAccessibilityHint: String? = nil,
        titleAccessibilityIdentifier: String? = nil,
        titleAccessibilityLabel: String? = nil,
        titleAccessibilityHint: String? = nil,
        messageAccessibilityIdentifier: String? = nil,
        messageAccessibilityHint: String? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.additionalContent = additionalContent
        self.iconAccessibilityIdentifier = iconAccessibilityIdentifier
        self.iconAccessibilityLabel = iconAccessibilityLabel
        self.iconAccessibilityHint = iconAccessibilityHint
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.titleAccessibilityLabel = titleAccessibilityLabel
        self.titleAccessibilityHint = titleAccessibilityHint
        self.messageAccessibilityIdentifier = messageAccessibilityIdentifier
        self.messageAccessibilityHint = messageAccessibilityHint
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(messageColor)
                    .applyIf(iconAccessibilityIdentifier != nil) { view in
                        view.accessibilityIdentifier(iconAccessibilityIdentifier!)
                    }
                    .applyIf(iconAccessibilityLabel != nil) { view in
                        view.accessibilityLabel(iconAccessibilityLabel!)
                    }
                    .applyIf(iconAccessibilityHint != nil) { view in
                        view.accessibilityHint(iconAccessibilityHint!)
                    }
                    .accessibilityAddTraits(.isImage)
                
                Text(title)
                    .font(theme.typography.subtitleFont)
                    .foregroundColor(messageColor)
                    .applyIf(titleAccessibilityIdentifier != nil) { view in
                        view.accessibilityIdentifier(titleAccessibilityIdentifier!)
                    }
                    .applyIf(titleAccessibilityLabel != nil) { view in
                        view.accessibilityLabel(titleAccessibilityLabel!)
                    }
                    .applyIf(titleAccessibilityHint != nil) { view in
                        view.accessibilityHint(titleAccessibilityHint!)
                    }
                    .accessibilityAddTraits(.isHeader)
            }
            
            Text(message)
                .font(theme.typography.bodyFont)
                .foregroundColor(theme.colors.text)
                .applyIf(messageAccessibilityIdentifier != nil) { view in
                    view.accessibilityIdentifier(messageAccessibilityIdentifier!)
                }
                .applyIf(messageAccessibilityHint != nil) { view in
                    view.accessibilityHint(messageAccessibilityHint!)
                }
            
            if let additionalContent = additionalContent {
                additionalContent()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: theme.borderRadius.md)
                .fill(backgroundColor)
                .customShadow(theme.shadows.small)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .pending:
            return "hourglass.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    private var messageColor: Color {
        switch type {
        case .success:
            return theme.colors.success
        case .error:
            return theme.colors.error
        case .pending:
            return theme.colors.warning
        case .warning:
            return theme.colors.warning
        case .info:
            return theme.colors.primary
        }
    }
    
    private var backgroundColor: Color {
        switch type {
        case .success:
            return theme.colors.success.opacity(0.1)
        case .error:
            return theme.colors.error.opacity(0.1)
        case .pending:
            return theme.colors.warning.opacity(0.1)
        case .warning:
            return theme.colors.warning.opacity(0.1)
        case .info:
            return theme.colors.primary.opacity(0.1)
        }
    }
    
    // MARK: - Message Type
    
    enum MessageType {
        case success
        case error
        case pending
        case warning
        case info
    }
}

// MARK: - View Extension for Conditional Modifiers
extension View {
    @ViewBuilder
    func applyIf(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Convenience Initializers

extension MessageView {
    /// Convenience initializer for success messages
    static func success(
        title: String = "Success!",
        message: String,
        additionalContent: (() -> AnyView)? = nil,
        iconAccessibilityIdentifier: String? = nil,
        iconAccessibilityLabel: String? = nil,
        iconAccessibilityHint: String? = nil,
        titleAccessibilityIdentifier: String? = nil,
        titleAccessibilityLabel: String? = nil,
        titleAccessibilityHint: String? = nil,
        messageAccessibilityIdentifier: String? = nil,
        messageAccessibilityHint: String? = nil
    ) -> MessageView {
        MessageView(
            type: .success,
            title: title,
            message: message,
            additionalContent: additionalContent,
            iconAccessibilityIdentifier: iconAccessibilityIdentifier,
            iconAccessibilityLabel: iconAccessibilityLabel,
            iconAccessibilityHint: iconAccessibilityHint,
            titleAccessibilityIdentifier: titleAccessibilityIdentifier,
            titleAccessibilityLabel: titleAccessibilityLabel,
            titleAccessibilityHint: titleAccessibilityHint,
            messageAccessibilityIdentifier: messageAccessibilityIdentifier,
            messageAccessibilityHint: messageAccessibilityHint
        )
    }
    
    /// Convenience initializer for error messages
    static func error(
        title: String = "Error",
        message: String,
        additionalContent: (() -> AnyView)? = nil,
        iconAccessibilityIdentifier: String? = nil,
        iconAccessibilityLabel: String? = nil,
        iconAccessibilityHint: String? = nil,
        titleAccessibilityIdentifier: String? = nil,
        titleAccessibilityLabel: String? = nil,
        titleAccessibilityHint: String? = nil,
        messageAccessibilityIdentifier: String? = nil,
        messageAccessibilityHint: String? = nil
    ) -> MessageView {
        MessageView(
            type: .error,
            title: title,
            message: message,
            additionalContent: additionalContent,
            iconAccessibilityIdentifier: iconAccessibilityIdentifier,
            iconAccessibilityLabel: iconAccessibilityLabel,
            iconAccessibilityHint: iconAccessibilityHint,
            titleAccessibilityIdentifier: titleAccessibilityIdentifier,
            titleAccessibilityLabel: titleAccessibilityLabel,
            titleAccessibilityHint: titleAccessibilityHint,
            messageAccessibilityIdentifier: messageAccessibilityIdentifier,
            messageAccessibilityHint: messageAccessibilityHint
        )
    }

    /// Convenience initializer for pending messages
    static func pending(
        title: String = "Pending",
        message: String,
        additionalContent: (() -> AnyView)? = nil,
        iconAccessibilityIdentifier: String? = nil,
        iconAccessibilityLabel: String? = nil,
        iconAccessibilityHint: String? = nil,
        titleAccessibilityIdentifier: String? = nil,
        titleAccessibilityLabel: String? = nil,
        titleAccessibilityHint: String? = nil,
        messageAccessibilityIdentifier: String? = nil,
        messageAccessibilityHint: String? = nil
    ) -> MessageView {
        MessageView(
            type: .pending,
            title: title,
            message: message,
            additionalContent: additionalContent,
            iconAccessibilityIdentifier: iconAccessibilityIdentifier,
            iconAccessibilityLabel: iconAccessibilityLabel,
            iconAccessibilityHint: iconAccessibilityHint,
            titleAccessibilityIdentifier: titleAccessibilityIdentifier,
            titleAccessibilityLabel: titleAccessibilityLabel,
            titleAccessibilityHint: titleAccessibilityHint,
            messageAccessibilityIdentifier: messageAccessibilityIdentifier,
            messageAccessibilityHint: messageAccessibilityHint
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        MessageView.success(
            message: "Transaction completed successfully!"
        )
        
        MessageView.error(
            message: "Payment failed: Invalid card number"
        )

        MessageView.pending(
            message: "Payment is still being processed by the provider."
        )
        
        MessageView.success(
            title: "CVV Recached Successfully!",
            message: "Your payment method has been updated.",
            additionalContent: {
                AnyView(
                    Text("Updated Token: abc123xyz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
            }
        )
    }
    .padding()
}

