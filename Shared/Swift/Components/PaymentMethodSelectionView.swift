//
//  PaymentMethodSelectionView.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import SwiftUI

// MARK: - Payment Method Selection View
struct PaymentMethodSelectionView: View {
    let cards: [SavedCard]
    @Binding var selectedCard: SavedCard?
    @Environment(\.spreedlyTheme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Select Payment Method")
                .font(theme.typography.subtitleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier("payment-method-selection-title")
                .accessibilityLabel("Select Payment Method")
                .accessibilityHint("Choose a payment method from the list")
                .accessibilityAddTraits(.isHeader)
            
            if cards.isEmpty {
                Text("No payment methods available")
                    .font(theme.typography.captionFont)
                    .foregroundColor(theme.colors.textSecondary)
                    .padding(theme.spacing.md)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("payment-method-empty-state")
                    .accessibilityLabel("No payment methods available")
                    .accessibilityHint("There are no saved payment methods to select from")
            } else {
                VStack(spacing: theme.spacing.md) {
                    ForEach(cards) { card in
                        PaymentMethodRowView(
                            card: card,
                            isSelected: selectedCard?.id == card.id,
                            onSelect: {
                                selectedCard = card
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacing.md)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.borderRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: theme.borderRadius.xl)
                .stroke(theme.colors.border, lineWidth: 1)
        )
        .customShadow(theme.shadows.small)
    }
}

// MARK: - Payment Method Row View
struct PaymentMethodRowView: View {
    let card: SavedCard
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.spreedlyTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    
    /// Cell background: elevated in dark mode so card rows stand out from list surface (#1C1C1E).
    private var cellBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#2C2C2E") : Color(.systemGray6)
    }
    
    /// Selected cell: same as cell in dark mode (border + checkmark show selection); primary tint in light.
    private var selectedCellBackgroundColor: Color {
        colorScheme == .dark ? cellBackgroundColor : theme.colors.primary.opacity(0.1)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Card Icon/Indicator
            Image(systemName: "creditcard.fill")
                .foregroundColor(isSelected ? theme.colors.primary : .gray)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(card.displayName)
                    .font(theme.typography.subtitleFont)
                    .foregroundColor(theme.colors.text)
                
                if let month = card.expiryMonth, let year = card.expiryYear {
                    Text("Expires: \(month)/\(year)")
                        .font(theme.typography.captionFont)
                        .foregroundColor(theme.colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Selection Indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.colors.primary)
                    .font(.title3)
            }
        }
        .padding(theme.spacing.md)
        .background(isSelected ? selectedCellBackgroundColor : cellBackgroundColor)
        .cornerRadius(theme.borderRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: theme.borderRadius.sm)
                .stroke(isSelected ? theme.colors.primary : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
        .accessibilityIdentifier("payment-method-row-\(card.id)")
        .accessibilityLabel("\(card.displayName), expires \(card.expiryMonth ?? "")/\(card.expiryYear ?? "")")
        .accessibilityHint("Tap to select this payment method")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    PaymentMethodSelectionView(
        cards: [],
        selectedCard: .constant(nil)
    )
}
