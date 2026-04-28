//
//  AppConstants.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// ISO 4217 currency code string constants.
/// Pass one of these values to the SDK which always expects a plain NSString.
typedef NSString *CurrencyCode NS_TYPED_EXTENSIBLE_ENUM;

extern CurrencyCode const CurrencyCodeUSD;
extern CurrencyCode const CurrencyCodeBRL;
extern CurrencyCode const CurrencyCodeMXN;
extern CurrencyCode const CurrencyCodeARS;
extern CurrencyCode const CurrencyCodeEUR;
extern CurrencyCode const CurrencyCodeGBP;
extern CurrencyCode const CurrencyCodeCAD;
extern CurrencyCode const CurrencyCodeCLP;
extern CurrencyCode const CurrencyCodeCOP;
extern CurrencyCode const CurrencyCodePEN;

/// Common constants used across the example app.
@interface AppConstants : NSObject

/// Maximum number of payment cards to display
+ (NSInteger)maxCardsToDisplay;

/// Conversion factor from dollars to cents
/// Used when converting product price to API amount (Forter API expects cents)
+ (NSDecimalNumber *)centsPerDollar;

/// Default currency code for transactions
+ (CurrencyCode)defaultCurrencyCode;

/// Payment method type filter for credit cards
+ (NSString *)creditCardPaymentMethodType;

/// Error message when no transaction data is received
+ (NSString *)noTransactionDataMessage;

@end

NS_ASSUME_NONNULL_END

