//
//  AdditionalFieldCatalogueSupport.swift
//  SpreedlySDKExample
//
//  Shared additional-field catalogue model + Optional address groups /
//  Additional Fields Configuration cards for drop-in and headless demos.
//

import SwiftUI
import SpreedlyCore
import SpreedlyUI

// MARK: - Model

/// Per-field Enable / Required / Custom rule state for catalogue-driven demos.
struct AdditionalFieldToggleRow: Identifiable {
    let id: String
    let title: String
    let type: FormFieldType
    var isEnabled: Bool
    var isRequired: Bool
    var customRule: DemoCustomValidationKind

    func formField() -> FormField? {
        guard isEnabled else { return nil }
        return FormField(id: id, title: title, type: type, placeholder: nil, isRequired: isRequired)
    }
}

enum AdditionalFieldCatalogueDemo {
    /// All mountable additional fields (excludes card PCI + drop-in name modes).
    static func defaultRows() -> [AdditionalFieldToggleRow] {
        [
            row("addressLine1", "Address Line 1", .addressLine1, enabled: false, required: true),
            row("addressLine2", "Address Line 2", .addressLine2, enabled: false, required: false),
            row("city", "City", .city, enabled: false, required: true),
            row("state", "State", .state, enabled: false, required: true),
            row("zipCode", "ZIP Code", .zipCode, enabled: false, required: true),
            row("country", "Country", .country, enabled: false, required: false),
            row("email", "Email", .email, enabled: false, required: false),
            row("company", "Company", .company, enabled: false, required: false),
            row("phoneNumber", "Phone Number", .phoneNumber, enabled: false, required: false),
            row("houseNumberOrName", "House Number or Name", .houseNumberOrName, enabled: false, required: false),
            row("street", "Street", .street, enabled: false, required: false),
            row("streetLine2", "Street Line 2", .streetLine2, enabled: false, required: false),
            row("phoneNumberCountryCode", "Phone Country Code", .phoneNumberCountryCode, enabled: false, required: false),
            row("phoneNumberAreaCode", "Phone Area Code", .phoneNumberAreaCode, enabled: false, required: false),
            row("shippingAddress1", "Shipping Address 1", .shippingAddress1, enabled: false, required: false),
            row("shippingAddress2", "Shipping Address 2", .shippingAddress2, enabled: false, required: false),
            row("shippingCity", "Shipping City", .shippingCity, enabled: false, required: false),
            row("shippingState", "Shipping State", .shippingState, enabled: false, required: false),
            row("shippingZip", "Shipping ZIP", .shippingZip, enabled: false, required: false),
            row("shippingCountry", "Shipping Country", .shippingCountry, enabled: false, required: false),
            row("shippingPhoneNumber", "Shipping Phone", .shippingPhoneNumber, enabled: false, required: false),
            row("shippingHouseNumberOrName", "Shipping House Number", .shippingHouseNumberOrName, enabled: false, required: false),
            row("shippingStreet", "Shipping Street", .shippingStreet, enabled: false, required: false),
            row("shippingStreetLine2", "Shipping Street Line 2", .shippingStreetLine2, enabled: false, required: false),
            row("shippingPhoneNumberCountryCode", "Shipping Phone Country Code", .shippingPhoneNumberCountryCode, enabled: false, required: false),
            row("shippingPhoneNumberAreaCode", "Shipping Phone Area Code", .shippingPhoneNumberAreaCode, enabled: false, required: false)
        ]
    }

    static let billingGroupIds: Set<String> = ["city", "country", "state", "zipCode"]
    static let shippingGroupIds: Set<String> = ["shippingCity", "shippingCountry", "shippingState", "shippingZip"]
    static let emailGroupIds: Set<String> = ["email"]

    static func setEnabled(_ ids: Set<String>, enabled: Bool, rows: inout [AdditionalFieldToggleRow]) {
        for index in rows.indices where ids.contains(rows[index].id) {
            rows[index].isEnabled = enabled
        }
    }

    static func enabling(_ ids: Set<String>, enabled: Bool, in rows: [AdditionalFieldToggleRow]) -> [AdditionalFieldToggleRow] {
        var copy = rows
        setEnabled(ids, enabled: enabled, rows: &copy)
        return copy
    }

    /// Group switch is ON only when every field in that group is enabled.
    static func syncGroupFlags(
        rows: [AdditionalFieldToggleRow],
        billing: inout Bool,
        shipping: inout Bool,
        email: inout Bool
    ) {
        billing = billingGroupIds.allSatisfy { id in
            rows.first(where: { $0.id == id })?.isEnabled == true
        }
        shipping = shippingGroupIds.allSatisfy { id in
            rows.first(where: { $0.id == id })?.isEnabled == true
        }
        email = emailGroupIds.allSatisfy { id in
            rows.first(where: { $0.id == id })?.isEnabled == true
        }
    }

    static func groupFlags(for rows: [AdditionalFieldToggleRow]) -> (billing: Bool, shipping: Bool, email: Bool) {
        var billing = false
        var shipping = false
        var email = false
        syncGroupFlags(rows: rows, billing: &billing, shipping: &shipping, email: &email)
        return (billing, shipping, email)
    }

    /// Classic billing address set: address1/2, city, state, zip, country.
    static func applyBillingDefaults(to rows: inout [AdditionalFieldToggleRow]) {
        let enabledIds: Set<String> = [
            "addressLine1", "addressLine2", "city", "state", "zipCode", "country"
        ]
        let requiredIds: Set<String> = ["addressLine1", "city", "state", "zipCode"]
        for index in rows.indices {
            let id = rows[index].id
            rows[index].isEnabled = enabledIds.contains(id)
            rows[index].isRequired = requiredIds.contains(id)
            rows[index].customRule = .none
        }
    }

    static func withBillingDefaults(_ rows: [AdditionalFieldToggleRow]) -> [AdditionalFieldToggleRow] {
        var copy = rows
        applyBillingDefaults(to: &copy)
        return copy
    }

    static func disableAll(rows: inout [AdditionalFieldToggleRow]) {
        for index in rows.indices {
            rows[index].isEnabled = false
        }
    }

    static func withAllDisabled(_ rows: [AdditionalFieldToggleRow]) -> [AdditionalFieldToggleRow] {
        var copy = rows
        disableAll(rows: &copy)
        return copy
    }

    /// Catalogue custom-rule map for enabled rows (disabled → `.none`).
    static func customValidationSelections(
        from rows: [AdditionalFieldToggleRow]
    ) -> [CustomValidatableFieldName: DemoCustomValidationKind] {
        var map: [CustomValidatableFieldName: DemoCustomValidationKind] = [:]
        for row in rows {
            guard let field = DemoCustomValidationRecipes.customValidatableField(for: row.type) else { continue }
            var kind = row.isEnabled ? row.customRule : .none
            if kind == .onlyWhenCountryUS,
               !DemoCustomValidationKind.pickerCases(for: row.type).contains(.onlyWhenCountryUS) {
                kind = .none
            }
            map[field] = kind
        }
        return map
    }

    private static func row(
        _ id: String,
        _ title: String,
        _ type: FormFieldType,
        enabled: Bool,
        required: Bool
    ) -> AdditionalFieldToggleRow {
        AdditionalFieldToggleRow(
            id: id,
            title: title,
            type: type,
            isEnabled: enabled,
            isRequired: required,
            customRule: .none
        )
    }
}

// MARK: - Shared cards

/// Optional address groups (always visible) + collapsible per-field catalogue.
struct AdditionalFieldCatalogueCards: View {
    @Binding var catalogueRows: [AdditionalFieldToggleRow]
    @Binding var showConfig: Bool
    @Binding var groupBilling: Bool
    @Binding var groupShipping: Bool
    @Binding var groupEmail: Bool

    /// Prefix for accessibility IDs (`additionalFields` / `customForm`).
    var accessibilityPrefix: String = "additionalFields"
    /// Optional override for the config card title (drop-in uses SPLAccessibility constant).
    var configTitleAccessibilityId: String? = nil
    var toggleTint: Color = Color(red: 0.0 / 255.0, green: 119.0 / 255.0, blue: 200.0 / 255.0)
    /// Fired after Enable / Required / Custom rule / group / defaults change.
    var onCatalogueChanged: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            groupsCard
            configCard
        }
    }

    private var groupsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optional address groups")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("Turn on a group to enable its fields. Groups also turn on when you Enable every field in that group below.")
                .font(.caption)
                .foregroundColor(.secondary)

            groupToggleRow(
                title: "Billing address",
                subtitle: "City, country, state, zip",
                isOn: $groupBilling,
                accessibilityId: "\(accessibilityPrefix)_group_billing"
            ) { enabled in
                catalogueRows = AdditionalFieldCatalogueDemo.enabling(
                    AdditionalFieldCatalogueDemo.billingGroupIds,
                    enabled: enabled,
                    in: catalogueRows
                )
                syncGroups()
                onCatalogueChanged()
            }
            groupToggleRow(
                title: "Shipping address",
                subtitle: "Shipping city, country, state, zip",
                isOn: $groupShipping,
                accessibilityId: "\(accessibilityPrefix)_group_shipping"
            ) { enabled in
                catalogueRows = AdditionalFieldCatalogueDemo.enabling(
                    AdditionalFieldCatalogueDemo.shippingGroupIds,
                    enabled: enabled,
                    in: catalogueRows
                )
                syncGroups()
                onCatalogueChanged()
            }
            groupToggleRow(
                title: "Email",
                subtitle: "Contact email field",
                isOn: $groupEmail,
                accessibilityId: "\(accessibilityPrefix)_group_email"
            ) { enabled in
                catalogueRows = AdditionalFieldCatalogueDemo.enabling(
                    AdditionalFieldCatalogueDemo.emailGroupIds,
                    enabled: enabled,
                    in: catalogueRows
                )
                syncGroups()
                onCatalogueChanged()
            }
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

    private var configCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Additional Fields Configuration")
                    .font(.headline)
                    .accessibilityIdentifier(configTitleAccessibilityId ?? "\(accessibilityPrefix)AdditionalFieldsTitle")
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(showConfig ? "Hide" : "Show") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showConfig.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("\(accessibilityPrefix)_configShowHide")
            }

            if !showConfig {
                Text("Hidden to shorten this screen. Tap Show for Enable billing defaults, Disable all, and per-field Enable / Required / Custom rule.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if showConfig {
                HStack(spacing: 12) {
                    Button("Enable billing defaults") {
                        catalogueRows = AdditionalFieldCatalogueDemo.withBillingDefaults(catalogueRows)
                        syncGroups()
                        onCatalogueChanged()
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("\(accessibilityPrefix)_enableBillingDefaults")
                    Button("Disable all") {
                        catalogueRows = AdditionalFieldCatalogueDemo.withAllDisabled(catalogueRows)
                        groupBilling = false
                        groupShipping = false
                        groupEmail = false
                        onCatalogueChanged()
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("\(accessibilityPrefix)_disableAll")
                }

                Text("Individual fields")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)

                ForEach($catalogueRows) { $row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.title)
                            .font(.subheadline.weight(.medium))
                        HStack {
                            HStack(spacing: 8) {
                                Text("Enable")
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { row.isEnabled },
                                        set: { newValue in
                                            row.isEnabled = newValue
                                            syncGroups()
                                            onCatalogueChanged()
                                        }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: toggleTint))
                                .accessibilityIdentifier("\(accessibilityPrefix)_\(row.id)_enable")
                            }.scaleEffect(0.8)
                            Spacer()
                            HStack(spacing: 8) {
                                Text("Required")
                                    .opacity(row.isEnabled ? 1 : 0.45)
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { row.isRequired },
                                        set: { newValue in
                                            row.isRequired = newValue
                                            onCatalogueChanged()
                                        }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: toggleTint))
                                .disabled(!row.isEnabled)
                                .opacity(row.isEnabled ? 1 : 0.45)
                                .accessibilityIdentifier("\(accessibilityPrefix)_\(row.id)_required")
                            }.scaleEffect(0.8)
                        }
                        customRulePickerRow(
                            title: "Custom rule",
                            selection: Binding(
                                get: {
                                    let allowed = DemoCustomValidationKind.pickerCases(for: row.type)
                                    return allowed.contains(row.customRule) ? row.customRule : .none
                                },
                                set: { newValue in
                                    row.customRule = newValue
                                    onCatalogueChanged()
                                }
                            ),
                            enabled: row.isEnabled,
                            formFieldType: row.type,
                            accessibilityId: "\(accessibilityPrefix)_\(row.id)_customRule"
                        )
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
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

    private func syncGroups() {
        let flags = AdditionalFieldCatalogueDemo.groupFlags(for: catalogueRows)
        groupBilling = flags.billing
        groupShipping = flags.shipping
        groupEmail = flags.email
    }

    @ViewBuilder
    private func groupToggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        accessibilityId: String,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { isOn.wrappedValue },
                    set: { newValue in
                        isOn.wrappedValue = newValue
                        onChange(newValue)
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: toggleTint))
            .accessibilityIdentifier(accessibilityId)
        }
    }

    @ViewBuilder
    private func customRulePickerRow(
        title: String,
        selection: Binding<DemoCustomValidationKind>,
        enabled: Bool,
        formFieldType: FormFieldType,
        accessibilityId: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(enabled ? 1 : 0.45)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(DemoCustomValidationKind.pickerCases(for: formFieldType)) { kind in
                    Text(kind.pickerLabel).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
            .accessibilityIdentifier(accessibilityId)
        }
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "#1C1C1E") : Color(hex: "#FFFFFF")
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color(hex: "#3A3A3C") : Color(hex: "#EFEDEA")
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color(hex: "#AFB4B5").opacity(0.8)
    }
}
