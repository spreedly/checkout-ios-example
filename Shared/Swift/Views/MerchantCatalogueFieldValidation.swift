//
//  MerchantCatalogueFieldValidation.swift
//  SpreedlySDKExample
//
//  Example-app only — sample error copy for merchant-owned TextFields
//  (not Spreedly SDK validators). Used by CustomMerchantTextFieldsDemoView.
//  Charset is intentionally open (non-Latin names/cities OK), matching SDK stance.
//

import Foundation

// MARK: - Name

enum DemoNameError {
    case empty
    case tooShort
}

enum DemoNameValidation {
    static func validate(_ value: String, isRequired: Bool) -> DemoNameError? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return isRequired ? .empty : nil
        }
        if trimmed.count < 2 { return .tooShort }
        return nil
    }

    static func message(for error: DemoNameError?) -> String? {
        switch error {
        case .empty: return "Name is required"
        case .tooShort: return "Name must be at least 2 characters"
        case nil: return nil
        }
    }
}

// MARK: - Address

enum DemoAddressError {
    case empty
    case tooShort
}

enum DemoAddressValidation {
    static func validate(_ value: String, isRequired: Bool) -> DemoAddressError? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return isRequired ? .empty : nil
        }
        if trimmed.count < 5 { return .tooShort }
        return nil
    }

    static func message(for error: DemoAddressError?) -> String? {
        switch error {
        case .empty: return "Address line 1 is required"
        case .tooShort: return "Address must be at least 5 characters"
        case nil: return nil
        }
    }
}

// MARK: - City

enum DemoCityError {
    case empty
    case tooShort
}

enum DemoCityValidation {
    static func validate(_ value: String, isRequired: Bool) -> DemoCityError? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return isRequired ? .empty : nil
        }
        if trimmed.count < 2 { return .tooShort }
        return nil
    }

    static func message(for error: DemoCityError?) -> String? {
        switch error {
        case .empty: return "City is required"
        case .tooShort: return "City must be at least 2 characters"
        case nil: return nil
        }
    }
}

// MARK: - State (US-style region code demo)

enum DemoStateError {
    case empty
    case invalidLength
    case invalidFormat
}

enum DemoStateValidation {
    /// Demo-only US-style region codes (2–3 letters). Not a worldwide state validator.
    static func validate(_ value: String, isRequired: Bool) -> DemoStateError? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return isRequired ? .empty : nil
        }
        if trimmed.count < 2 || trimmed.count > 3 { return .invalidLength }
        if trimmed.range(of: #"^[A-Za-z]+$"#, options: .regularExpression) == nil {
            return .invalidFormat
        }
        return nil
    }

    static func message(for error: DemoStateError?) -> String? {
        switch error {
        case .empty: return "State is required"
        case .invalidLength: return "State must be 2-3 characters"
        case .invalidFormat: return "State must be letters only (e.g., CA, NY, or ca)"
        case nil: return nil
        }
    }
}

// MARK: - ZIP / postal

enum DemoZipCodeError {
    case empty
    case invalidFormat
    case tooLong
}

enum DemoZipCodeValidation {
    /// Align demo max with SDK ZIP/phone char limit (15).
    private static let maxLength = 15
    private static let pattern = #"^[A-Za-z0-9\s-]+$"#

    static func validate(_ value: String, isRequired: Bool) -> DemoZipCodeError? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return isRequired ? .empty : nil
        }
        if trimmed.count > maxLength { return .tooLong }
        if trimmed.range(of: pattern, options: .regularExpression) == nil {
            return .invalidFormat
        }
        return nil
    }

    static func message(for error: DemoZipCodeError?) -> String? {
        switch error {
        case .empty: return "Zip code is required"
        case .invalidFormat: return "Invalid postal code format"
        case .tooLong: return "Postal code is too long (max 15 characters)"
        case nil: return nil
        }
    }
}
