//
//  Product.swift
//  MerchantExample
//
//
//

import Foundation

// MARK: - Product Model
struct Product: Identifiable {
    let id: String
    let name: String
    let price: Decimal
    let description: String?
    let iconName: String
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = CurrencyCode.usd.rawValue
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
    
    init(id: String, name: String, price: Decimal, description: String? = nil, iconName: String = "bag.fill") {
        self.id = id
        self.name = name
        self.price = price
        self.description = description
        self.iconName = iconName
    }
}
