//
//  MerchantCatalogueFieldValidation.m
//  SpreedlySDKExampleObjectiveC
//
//  Example-app only — sample validators (no ASCII-only charset; non-Latin OK).
//

#import "MerchantCatalogueFieldValidation.h"

@implementation MerchantCatalogueFieldValidation

+ (NSString *)trimmed:(NSString *)value {
    return [(value ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (nullable NSString *)nameErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired {
    NSString *trimmed = [self trimmed:value];
    if (trimmed.length == 0) {
        return isRequired ? @"Name is required" : nil;
    }
    if (trimmed.length < 2) {
        return @"Name must be at least 2 characters";
    }
    return nil;
}

+ (nullable NSString *)addressErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired {
    NSString *trimmed = [self trimmed:value];
    if (trimmed.length == 0) {
        return isRequired ? @"Address line 1 is required" : nil;
    }
    if (trimmed.length < 5) {
        return @"Address must be at least 5 characters";
    }
    return nil;
}

+ (nullable NSString *)cityErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired {
    NSString *trimmed = [self trimmed:value];
    if (trimmed.length == 0) {
        return isRequired ? @"City is required" : nil;
    }
    if (trimmed.length < 2) {
        return @"City must be at least 2 characters";
    }
    return nil;
}

+ (nullable NSString *)stateErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired {
    // Demo-only US-style region codes (2–3 letters). Accepts lowercase (e.g. ca).
    NSString *trimmed = [self trimmed:value];
    if (trimmed.length == 0) {
        return isRequired ? @"State is required" : nil;
    }
    if (trimmed.length < 2 || trimmed.length > 3) {
        return @"State must be 2-3 characters";
    }
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^[A-Za-z]+$"];
    if (![pred evaluateWithObject:trimmed]) {
        return @"State must be letters only (e.g., CA, NY, or ca)";
    }
    return nil;
}

+ (nullable NSString *)zipErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired {
    NSString *trimmed = [self trimmed:value];
    if (trimmed.length == 0) {
        return isRequired ? @"ZIP code is required" : nil;
    }
    if (trimmed.length > 15) {
        return @"Postal code is too long (max 15 characters)";
    }
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^[A-Za-z0-9\\s-]+$"];
    if (![pred evaluateWithObject:trimmed]) {
        return @"Invalid postal code format";
    }
    return nil;
}

@end
