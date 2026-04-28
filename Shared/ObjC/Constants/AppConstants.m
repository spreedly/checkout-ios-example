//
//  AppConstants.m
//  MerchantExample
//
//
//

#import "AppConstants.h"

CurrencyCode const CurrencyCodeUSD = @"USD";
CurrencyCode const CurrencyCodeBRL = @"BRL";
CurrencyCode const CurrencyCodeMXN = @"MXN";
CurrencyCode const CurrencyCodeARS = @"ARS";
CurrencyCode const CurrencyCodeEUR = @"EUR";
CurrencyCode const CurrencyCodeGBP = @"GBP";
CurrencyCode const CurrencyCodeCAD = @"CAD";
CurrencyCode const CurrencyCodeCLP = @"CLP";
CurrencyCode const CurrencyCodeCOP = @"COP";
CurrencyCode const CurrencyCodePEN = @"PEN";

@implementation AppConstants

+ (NSInteger)maxCardsToDisplay {
    return 6;
}

+ (NSDecimalNumber *)centsPerDollar {
    return [NSDecimalNumber decimalNumberWithString:@"100"];
}

+ (CurrencyCode)defaultCurrencyCode {
    return CurrencyCodeUSD;
}

+ (NSString *)creditCardPaymentMethodType {
    return @"credit_card";
}

+ (NSString *)noTransactionDataMessage {
    return @"No transaction data received";
}

@end

