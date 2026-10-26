//
//  DemoCustomValidationRecipes.m
//  SpreedlySDKExampleObjectiveC
//

#import "DemoCustomValidationRecipes.h"

@implementation DemoCustomValidationRecipes

+ (NSArray<NSString *> *)managedWireKeys {
    return @[
        @"first_name", @"last_name", @"full_name", @"email", @"company",
        @"address1", @"address2", @"city", @"state", @"zip", @"country",
        @"phone_number", @"house_number_or_name", @"street", @"street_line2",
        @"phone_number_country_code", @"phone_number_area_code",
        @"shipping_address1", @"shipping_address2", @"shipping_city", @"shipping_state",
        @"shipping_zip", @"shipping_country", @"shipping_phone_number",
        @"shipping_house_number_or_name", @"shipping_street", @"shipping_street_line2",
        @"shipping_phone_number_country_code", @"shipping_phone_number_area_code"
    ];
}

+ (NSString *)pickerLabelForKind:(DemoCustomValidationKind)kind {
    switch (kind) {
        case DemoCustomValidationKindNone: return @"None";
        case DemoCustomValidationKindMinLength3: return @"Min length 3";
        case DemoCustomValidationKindNoDigits: return @"No digits";
        case DemoCustomValidationKindDigitsOnly: return @"Digits only";
        case DemoCustomValidationKindNoSpecialChars: return @"No special characters";
        case DemoCustomValidationKindOnlyWhenCountryUS: return @"Only when country = US";
        case DemoCustomValidationKindAlwaysInvalid: return @"Always invalid";
    }
    return @"None";
}

/// `Only when country = US` is only offered on state / ZIP (billing + shipping).
+ (NSArray<NSNumber *> *)pickerKindsForFormFieldType:(FormFieldType)type {
    NSMutableArray<NSNumber *> *kinds = [NSMutableArray arrayWithArray:@[
        @(DemoCustomValidationKindNone),
        @(DemoCustomValidationKindMinLength3),
        @(DemoCustomValidationKindNoDigits),
        @(DemoCustomValidationKindDigitsOnly),
        @(DemoCustomValidationKindNoSpecialChars),
        @(DemoCustomValidationKindAlwaysInvalid)
    ]];
    BOOL isStateOrZip = (type == FormFieldTypeState
                         || type == FormFieldTypeZipCode
                         || type == FormFieldTypeShippingState
                         || type == FormFieldTypeShippingZip);
    if (isStateOrZip) {
        // Insert before Always invalid so order matches Swift pickers.
        NSUInteger alwaysIdx = [kinds indexOfObject:@(DemoCustomValidationKindAlwaysInvalid)];
        [kinds insertObject:@(DemoCustomValidationKindOnlyWhenCountryUS) atIndex:alwaysIdx];
    }
    return kinds;
}

/// Name-only pickers (e.g. full name / first / last) omit the US country rule.
+ (NSArray<NSNumber *> *)pickerKindsForNameFields {
    return @[
        @(DemoCustomValidationKindNone),
        @(DemoCustomValidationKindMinLength3),
        @(DemoCustomValidationKindNoDigits),
        @(DemoCustomValidationKindDigitsOnly),
        @(DemoCustomValidationKindNoSpecialChars),
        @(DemoCustomValidationKindAlwaysInvalid)
    ];
}

+ (NSString *)displayTitleForWireKey:(NSString *)wireKey {
    static NSDictionary<NSString *, NSString *> *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"first_name": @"First name",
            @"last_name": @"Last name",
            @"full_name": @"Full name",
            @"zip": @"ZIP code",
            @"shipping_zip": @"Shipping ZIP code",
            @"address1": @"Address line 1",
            @"address2": @"Address line 2",
            @"state": @"State",
            @"email": @"Email",
            @"city": @"City",
            @"country": @"Country"
        };
    });
    NSString *title = map[wireKey];
    if (title.length > 0) { return title; }
    return [[wireKey stringByReplacingOccurrencesOfString:@"_" withString:@" "] capitalizedString];
}

+ (NSString *)activeRulesSummaryFromSelections:(NSDictionary<NSString *, NSNumber *> *)selections {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSArray<NSString *> *keys = [[selections allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in keys) {
        DemoCustomValidationKind kind = (DemoCustomValidationKind)selections[key].integerValue;
        if (kind == DemoCustomValidationKindNone) { continue; }
        [parts addObject:[NSString stringWithFormat:@"%@: %@",
                          [self displayTitleForWireKey:key],
                          [self pickerLabelForKind:kind]]];
    }
    if (parts.count == 0) {
        return @"Active rules: None (select a Custom rule to exercise validators)";
    }
    return [NSString stringWithFormat:@"Active rules: %@", [parts componentsJoinedByString:@" · "]];
}

+ (nullable NSString *)wireKeyForFormFieldType:(FormFieldType)type {
    switch (type) {
        case FormFieldTypeFirstName: return @"first_name";
        case FormFieldTypeLastName: return @"last_name";
        case FormFieldTypeFullName: return @"full_name";
        case FormFieldTypeEmail: return @"email";
        case FormFieldTypeCompany: return @"company";
        case FormFieldTypeAddressLine1: return @"address1";
        case FormFieldTypeAddressLine2: return @"address2";
        case FormFieldTypeCity: return @"city";
        case FormFieldTypeState: return @"state";
        case FormFieldTypeZipCode: return @"zip";
        case FormFieldTypeCountry: return @"country";
        case FormFieldTypePhoneNumber: return @"phone_number";
        case FormFieldTypeHouseNumberOrName: return @"house_number_or_name";
        case FormFieldTypeStreet: return @"street";
        case FormFieldTypeStreetLine2: return @"street_line2";
        case FormFieldTypePhoneNumberCountryCode: return @"phone_number_country_code";
        case FormFieldTypePhoneNumberAreaCode: return @"phone_number_area_code";
        case FormFieldTypeShippingAddress1: return @"shipping_address1";
        case FormFieldTypeShippingAddress2: return @"shipping_address2";
        case FormFieldTypeShippingCity: return @"shipping_city";
        case FormFieldTypeShippingState: return @"shipping_state";
        case FormFieldTypeShippingZip: return @"shipping_zip";
        case FormFieldTypeShippingCountry: return @"shipping_country";
        case FormFieldTypeShippingPhoneNumber: return @"shipping_phone_number";
        case FormFieldTypeShippingHouseNumberOrName: return @"shipping_house_number_or_name";
        case FormFieldTypeShippingStreet: return @"shipping_street";
        case FormFieldTypeShippingStreetLine2: return @"shipping_street_line2";
        case FormFieldTypeShippingPhoneNumberCountryCode: return @"shipping_phone_number_country_code";
        case FormFieldTypeShippingPhoneNumberAreaCode: return @"shipping_phone_number_area_code";
        default: return nil;
    }
}

+ (void)removeAllManagedValidations {
    Spreedly *sdk = [Spreedly shared];
    for (NSString *key in [self managedWireKeys]) {
        [sdk removeValidationForField:key];
    }
}

/// When country is US: state → 2-letter code; ZIP → `12345` or `12345-6789`. Non-US → pass.
+ (SpreedlyCustomValidationResult *)evaluateOnlyWhenCountryUSForWireKey:(NSString *)wireKey
                                                                  value:(NSString *)value
                                                                 fields:(NSDictionary<NSString *, NSString *> *)fields {
    BOOL isShipping = [wireKey hasPrefix:@"shipping_"];
    NSString *countryKey = isShipping ? SpreedlyCustomValidatableField.shippingCountry : SpreedlyCustomValidatableField.country;
    if (![DemoCustomValidationRecipes isUnitedStatesCountry:fields[countryKey] ?: @""]) {
        return [SpreedlyCustomValidationResult valid];
    }

    NSString *trimmed = [(value ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([wireKey isEqualToString:SpreedlyCustomValidatableField.state]
        || [wireKey isEqualToString:SpreedlyCustomValidatableField.shippingState]) {
        // Exactly 2 ASCII letters (e.g. CA) — full names like "California" fail.
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^[A-Za-z]{2}$"];
        return [pred evaluateWithObject:trimmed]
            ? [SpreedlyCustomValidationResult valid]
            : [SpreedlyCustomValidationResult invalid:@"Enter a valid 2 letter US state code"];
    }

    if ([wireKey isEqualToString:SpreedlyCustomValidatableField.zipCode]
        || [wireKey isEqualToString:SpreedlyCustomValidatableField.shippingZipCode]) {
        if (trimmed.length == 0) {
            return [SpreedlyCustomValidationResult invalid:@"ZIP is required for US addresses"];
        }
        // US ZIP: 5 digits or ZIP+4 (`12345` / `12345-6789`).
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^[0-9]{5}(-[0-9]{4})?$"];
        return [pred evaluateWithObject:trimmed]
            ? [SpreedlyCustomValidationResult valid]
            : [SpreedlyCustomValidationResult invalid:@"Enter a valid US ZIP code"];
    }

    // Rule is only offered on state/ZIP pickers; treat other fields as pass-through.
    return [SpreedlyCustomValidationResult valid];
}

/// True for common US country inputs (case / whitespace insensitive).
+ (BOOL)isUnitedStatesCountry:(NSString *)raw {
    NSString *normalized = [[(raw ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    return [normalized isEqualToString:@"US"];
}

+ (BOOL)stringContainsDigit:(NSString *)string {
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    return [string rangeOfCharacterFromSet:digits].location != NSNotFound;
}

+ (BOOL)stringIsDigitsOnly:(NSString *)string {
    NSCharacterSet *nonDigits = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    return [string rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

+ (BOOL)stringHasOnlyLettersDigitsOrWhitespace:(NSString *)string {
    return [string rangeOfString:@"[^a-zA-Z0-9\\s]" options:NSRegularExpressionSearch].location == NSNotFound;
}

+ (SpreedlyCustomValidationResult * _Nullable (^)(NSString *, NSDictionary<NSString *, NSString *> *))validatorForWireKey:(NSString *)wireKey
                                                   kind:(DemoCustomValidationKind)kind {
    switch (kind) {
        case DemoCustomValidationKindNone:
            // Picker keeps None; applySelections never registers this kind.
            NSCAssert(NO, @"DemoCustomValidationKindNone is not registerable");
            return ^SpreedlyCustomValidationResult * _Nullable(NSString *value, NSDictionary<NSString *, NSString *> *fields) {
                return [SpreedlyCustomValidationResult valid];
            };
        case DemoCustomValidationKindMinLength3:
            return ^SpreedlyCustomValidationResult * _Nullable(NSString *value, NSDictionary<NSString *, NSString *> *fields) {
                if (value.length == 0) {
                    return [SpreedlyCustomValidationResult valid];
                }
                NSString *trimmed = [(value ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmed.length >= 3) {
                    return [SpreedlyCustomValidationResult valid];
                }
                return [SpreedlyCustomValidationResult invalid:@"Must be at least 3 characters"];
            };
        case DemoCustomValidationKindNoDigits:
            return ^SpreedlyCustomValidationResult * _Nullable(NSString *value, NSDictionary<NSString *, NSString *> *fields) {
                NSString *trimmed = [(value ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([DemoCustomValidationRecipes stringContainsDigit:trimmed]) {
                    return [SpreedlyCustomValidationResult invalid:@"Must not contain digits"];
                }
                return [SpreedlyCustomValidationResult valid];
            };
        case DemoCustomValidationKindDigitsOnly:
            return ^SpreedlyCustomValidationResult * _Nullable(NSString *value, NSDictionary<NSString *, NSString *> *fields) {
                NSString *trimmed = [(value ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([DemoCustomValidationRecipes stringIsDigitsOnly:trimmed]) {
                    return [SpreedlyCustomValidationResult valid];
                }
                return [SpreedlyCustomValidationResult invalid:@"Must contain only digits"];
            };
        case DemoCustomValidationKindNoSpecialChars:
            return ^SpreedlyCustomValidationResult * _Nullable(NSString *value, NSDictionary<NSString *, NSString *> *fields) {
                NSString *trimmed = [(value ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([DemoCustomValidationRecipes stringHasOnlyLettersDigitsOrWhitespace:trimmed]) {
                    return [SpreedlyCustomValidationResult valid];
                }
                return [SpreedlyCustomValidationResult invalid:@"Must not contain special characters"];
            };
        case DemoCustomValidationKindOnlyWhenCountryUS: {
            NSString *key = [wireKey copy];
            return ^SpreedlyCustomValidationResult * _Nullable(NSString *value, NSDictionary<NSString *, NSString *> *fields) {
                return [DemoCustomValidationRecipes evaluateOnlyWhenCountryUSForWireKey:key
                                                                                  value:value ?: @""
                                                                                 fields:fields ?: @{}];
            };
        }
        case DemoCustomValidationKindAlwaysInvalid:
            return ^SpreedlyCustomValidationResult * _Nullable(NSString *value, NSDictionary<NSString *, NSString *> *fields) {
                return [SpreedlyCustomValidationResult invalid:@"This field is always invalid"];
            };
    }
    return ^SpreedlyCustomValidationResult * _Nullable(NSString *value, NSDictionary<NSString *, NSString *> *fields) {
        return [SpreedlyCustomValidationResult valid];
    };
}

+ (void)applySelections:(NSDictionary<NSString *, NSNumber *> *)selections {
    [self removeAllManagedValidations];
    Spreedly *sdk = [Spreedly shared];
    [selections enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *boxed, BOOL *stop) {
        DemoCustomValidationKind kind = (DemoCustomValidationKind)boxed.integerValue;
        if (kind == DemoCustomValidationKindNone) { return; }
        [sdk addValidationForField:key validator:[self validatorForWireKey:key kind:kind]];
    }];
}

@end
