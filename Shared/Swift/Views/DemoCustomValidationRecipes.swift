//
//  DemoCustomValidationRecipes.swift
//  SpreedlySDKExample
//
//  QA-facing demo recipes for merchant custom field validators.
//  Example-app only — not part of the Spreedly SDK.
//

import Foundation
import SpreedlyCore
import SpreedlyUI

/// Demo rule kinds a tester can attach to a catalogue / name field.
enum DemoCustomValidationKind: String, CaseIterable, Identifiable {
    case none
    case minLength3
    case noDigits
    case digitsOnly
    case noSpecialChars
    case onlyWhenCountryUS
    case alwaysInvalid

    var id: String { rawValue }

    /// Short label shown in pickers and the Active rules banner.
    var pickerLabel: String {
        switch self {
        case .none: return "None"
        case .minLength3: return "Min length 3"
        case .noDigits: return "No digits"
        case .digitsOnly: return "Digits only"
        case .noSpecialChars: return "No special characters"
        case .onlyWhenCountryUS: return "Only when country = US"
        case .alwaysInvalid: return "Always invalid"
        }
    }

    /// `onlyWhenCountryUS` is only offered on state / ZIP (billing + shipping).
    static func pickerCases(for formFieldType: FormFieldType?) -> [DemoCustomValidationKind] {
        allCases.filter { kind in
            guard kind == .onlyWhenCountryUS else { return true }
            guard let formFieldType else { return false }
            switch formFieldType {
            case .state, .zipCode, .shippingState, .shippingZip:
                return true
            default:
                return false
            }
        }
    }

    /// Same filter using the validation wire-field name (name-only pickers omit the US rule).
    static func pickerCases(for field: CustomValidatableFieldName?) -> [DemoCustomValidationKind] {
        allCases.filter { kind in
            guard kind == .onlyWhenCountryUS else { return true }
            guard let field else { return false }
            switch field {
            case .state, .zipCode, .shippingState, .shippingZipCode:
                return true
            default:
                return false
            }
        }
    }
}

enum DemoCustomValidationRecipes {
    /// All keys this helper may register (remove before re-add).
    static let managedFields: [CustomValidatableFieldName] = CustomValidatableFieldName.allCases

    static func customValidatableField(for type: FormFieldType) -> CustomValidatableFieldName? {
        switch type {
        case .firstName: return .firstName
        case .lastName: return .lastName
        case .fullName: return .fullName
        case .email: return .email
        case .company: return .company
        case .addressLine1: return .addressLine1
        case .addressLine2: return .addressLine2
        case .city: return .city
        case .state: return .state
        case .zipCode: return .zipCode
        case .country: return .country
        case .phoneNumber: return .phoneNumber
        case .houseNumberOrName: return .houseNumberOrName
        case .street: return .street
        case .streetLine2: return .streetLine2
        case .phoneNumberCountryCode: return .phoneNumberCountryCode
        case .phoneNumberAreaCode: return .phoneNumberAreaCode
        case .shippingAddress1: return .shippingAddressLine1
        case .shippingAddress2: return .shippingAddressLine2
        case .shippingCity: return .shippingCity
        case .shippingState: return .shippingState
        case .shippingZip: return .shippingZipCode
        case .shippingCountry: return .shippingCountry
        case .shippingPhoneNumber: return .shippingPhoneNumber
        case .shippingHouseNumberOrName: return .shippingHouseNumberOrName
        case .shippingStreet: return .shippingStreet
        case .shippingStreetLine2: return .shippingStreetLine2
        case .shippingPhoneNumberCountryCode: return .shippingPhoneNumberCountryCode
        case .shippingPhoneNumberAreaCode: return .shippingPhoneNumberAreaCode
        default:
            return nil
        }
    }

    static func displayTitle(for field: CustomValidatableFieldName) -> String {
        switch field {
        case .firstName: return "First name"
        case .lastName: return "Last name"
        case .fullName: return "Full name"
        case .zipCode: return "ZIP code"
        case .shippingZipCode: return "Shipping ZIP code"
        case .addressLine1: return "Address line 1"
        case .addressLine2: return "Address line 2"
        case .phoneNumberCountryCode: return "Phone country code"
        case .phoneNumberAreaCode: return "Phone area code"
        case .shippingAddressLine1: return "Shipping address line 1"
        case .shippingAddressLine2: return "Shipping address line 2"
        case .shippingHouseNumberOrName: return "Shipping house #"
        case .shippingStreetLine2: return "Shipping street 2"
        case .shippingPhoneNumberCountryCode: return "Shipping phone CC"
        case .shippingPhoneNumberAreaCode: return "Shipping phone AC"
        default:
            return field.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Human-readable summary of non-None selections.
    static func activeRulesSummary(
        selections: [CustomValidatableFieldName: DemoCustomValidationKind]
    ) -> String {
        let active = selections
            .filter { $0.value != .none }
            .sorted { displayTitle(for: $0.key) < displayTitle(for: $1.key) }
        if active.isEmpty {
            return "Active rules: None (select a Custom rule to exercise validators)"
        }
        let parts = active.map { "\(displayTitle(for: $0.key)): \($0.value.pickerLabel)" }
        return "Active rules: " + parts.joined(separator: " · ")
    }

    static func removeAllManagedValidations() {
        for field in managedFields {
            Spreedly.shared().removeValidation(field: field)
        }
    }

    /// Clears managed validators, then registers only non-None selections.
    static func applySelections(_ selections: [CustomValidatableFieldName: DemoCustomValidationKind]) {
        removeAllManagedValidations()
        for (field, kind) in selections where kind != .none {
            Spreedly.shared().addValidation(field: field, validator: validator(for: field, kind: kind))
        }
    }

    static func validator(
        for field: CustomValidatableFieldName,
        kind: DemoCustomValidationKind
    ) -> SpreedlyCustomFieldValidator {
        switch kind {
        case .none:
            // Picker keeps None; applySelections never registers this kind.
            preconditionFailure("DemoCustomValidationKind.none is not registerable")
        case .minLength3:
            return { value, _ in
                guard !value.isEmpty else { return .valid }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.count >= 3
                    ? .valid
                    : .invalid("Must be at least 3 characters")
            }
        case .noDigits:
            return { value, _ in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasDigit = trimmed.contains { ("0"..."9").contains($0) }
                return hasDigit
                    ? .invalid("Must not contain digits")
                    : .valid
            }
        case .digitsOnly:
            return { value, _ in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                let ok = trimmed.allSatisfy { ("0"..."9").contains($0) }
                return ok ? .valid : .invalid("Must contain only digits")
            }
        case .noSpecialChars:
            return { value, _ in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                let ok = trimmed.range(of: #"[^a-zA-Z0-9\s]"#, options: .regularExpression) == nil
                return ok
                    ? .valid
                    : .invalid("Must not contain special characters")
            }
        case .onlyWhenCountryUS:
            return { value, fields in
                onlyWhenCountryUS(value: value, field: field, fields: fields)
            }
        case .alwaysInvalid:
            return { _, _ in .invalid("This field is always invalid") }
        }
    }

    /// When country is US: state → 2-letter code; ZIP → `12345` or `12345-6789`. Non-US → pass.
    private static func onlyWhenCountryUS(
        value: String,
        field: CustomValidatableFieldName,
        fields: [CustomValidatableFieldName: String]
    ) -> SpreedlyCustomValidationResult {
        let isShipping = field.rawValue.hasPrefix("shipping_")
        let countryField: CustomValidatableFieldName = isShipping ? .shippingCountry : .country
        guard isUnitedStatesCountry(fields[countryField] ?? "") else {
            return .valid
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch field {
        case .state, .shippingState:
            // Exactly 2 ASCII letters (e.g. CA) — full names like "California" fail.
            let ok = trimmed.range(of: #"^[A-Za-z]{2}$"#, options: .regularExpression) != nil
            return ok
                ? .valid
                : .invalid("Enter a valid 2 letter US state code")
        case .zipCode, .shippingZipCode:
            guard !trimmed.isEmpty else {
                return .invalid("ZIP is required for US addresses")
            }
            // US ZIP: 5 digits or ZIP+4 (`12345` / `12345-6789`).
            let ok = trimmed.range(of: #"^[0-9]{5}(-[0-9]{4})?$"#, options: .regularExpression) != nil
            return ok
                ? .valid
                : .invalid("Enter a valid US ZIP code")
        default:
            // Rule is only offered on state/ZIP pickers; treat other fields as pass-through.
            return .valid
        }
    }

    /// True for common US country inputs (case / whitespace insensitive).
    private static func isUnitedStatesCountry(_ raw: String) -> Bool {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        switch normalized {
        case "US":
            return true
        default:
            return false
        }
    }
}
