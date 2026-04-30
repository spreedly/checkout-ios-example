//
//  ProductSelectionView.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import SwiftUI

// MARK: - Product Selection View
struct ProductSelectionView: View {
    let products: [Product]
    @Binding var selectedProduct: Product?
    /// When false, the selection checkmark/circle at the bottom of each product cell is hidden (e.g. Stripe example).
    var showSelectionIcon: Bool = true
    @Environment(\.spreedlyTheme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text("Select Product")
                .font(theme.typography.subtitleFont)
                .foregroundColor(theme.colors.text)
                .accessibilityIdentifier("product-selection-title")
                .accessibilityLabel("Select Product")
                .accessibilityHint("Choose a product from the grid")
                .accessibilityAddTraits(.isHeader)
            
            // Grid layout with 2 columns
            let columns = [
                GridItem(.flexible(), spacing: theme.spacing.md),
                GridItem(.flexible(), spacing: theme.spacing.md)
            ]
            
            LazyVGrid(columns: columns, spacing: theme.spacing.md) {
                ForEach(products.prefix(6)) { product in // Limit to 6 products (3 rows x 2 columns)
                    ProductRowView(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        showSelectionIcon: showSelectionIcon,
                        onSelect: {
                            selectedProduct = product
                        }
                    )
                }
            }
            
            if let selected = selectedProduct {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    Divider()
                    HStack {
                        Text("Total Amount:")
                            .font(theme.typography.subtitleFont)
                            .foregroundColor(theme.colors.text)
                        Spacer()
                        Text(selected.formattedPrice)
                            .font(theme.typography.subtitleFont)
                            .foregroundColor(theme.colors.primary)
                    }
                    .accessibilityIdentifier("product-total-amount")
                    .accessibilityLabel("Total amount: \(selected.formattedPrice)")
                }
                .padding(.top, theme.spacing.sm)
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

// MARK: - Product Row View
struct ProductRowView: View {
    let product: Product
    let isSelected: Bool
    var showSelectionIcon: Bool = true
    let onSelect: () -> Void
    @Environment(\.spreedlyTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    
    /// Cell background: elevated in dark mode so product cards stand out from list surface (#1C1C1E).
    private var cellBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#2C2C2E") : Color(.systemGray6)
    }
    
    /// Selected cell: same as cell in dark mode (border + checkmark show selection); primary tint in light.
    private var selectedCellBackgroundColor: Color {
        colorScheme == .dark ? cellBackgroundColor : theme.colors.primary.opacity(0.1)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Product Icon
            Image(systemName: product.iconName)
                .foregroundColor(isSelected ? theme.colors.primary : .gray)
                .font(.title)
                .frame(height: 30)
            
            VStack(spacing: theme.spacing.xs) {
                Text(product.name)
                    .font(theme.typography.captionFont)
                    .foregroundColor(theme.colors.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 36)
                
                Text(product.formattedPrice)
                    .font(theme.typography.subtitleFont)
                    .foregroundColor(theme.colors.primary)
            }
            
            // Selection Indicator - optional; when hidden, use spacer to keep layout consistent
            Group {
                if showSelectionIcon {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.colors.primary)
                            .font(.title3)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.clear)
                            .font(.title3)
                    }
                }
            }
            .frame(height: showSelectionIcon ? 24 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
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
        .accessibilityIdentifier("product-row-\(product.id)")
        .accessibilityLabel("\(product.name), \(product.formattedPrice)")
        .accessibilityHint("Tap to select this product")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ProductSelectionView(
        products: [
            Product(id: "1", name: "Product 1", price: 3001, description: "Description 1", iconName: "bag.fill"),
            Product(id: "2", name: "Product 2", price: 3003, description: "Description 2", iconName: "bag.fill"),
            Product(id: "3", name: "Product 3", price: 3004, description: "Description 3", iconName: "bag.fill"),
            Product(id: "4", name: "Product 4", price: 3005, description: "Description 4", iconName: "bag.fill"),
            Product(id: "5", name: "Product 5", price: 3103, description: "Description 5", iconName: "bag.fill"),
            Product(id: "6", name: "Product 6", price: 3104, description: "Description 6", iconName: "bag.fill")
        ],
        selectedProduct: .constant(nil)
    )
}
