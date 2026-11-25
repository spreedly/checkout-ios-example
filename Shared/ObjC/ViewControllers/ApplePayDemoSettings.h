//
//  ApplePayDemoSettings.h
//  SpreedlySDKExampleObjectiveC
//
//  Every Apple Pay option the demo screens can change. Each screen makes its own copy, so its
//  changes reset when you go back.
//

#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>

@class ApplePayConfiguration;
@class ApplePayOrder;
@class SpreedlyApplePayWallet;

NS_ASSUME_NONNULL_BEGIN

/// Which Apple Pay checkout a demo screen runs.
typedef NS_ENUM(NSInteger, ApplePayDemoMode) {
    /// Fixed $1.00 payment from the card drop-in.
    ApplePayDemoModeOneTime = 0,
    /// Subscription sheet from the card drop-in.
    ApplePayDemoModeRecurring
};

@class ApplePayPaymentAuthorization;
@class ApplePayPaymentDecision;

typedef NS_ENUM(NSInteger, ApplePayDemoCardTypes) {
    ApplePayDemoCardTypesAny = 0,
    ApplePayDemoCardTypesDebit,
    ApplePayDemoCardTypesCredit
};

typedef NS_ENUM(NSInteger, ApplePayDemoInterval) {
    ApplePayDemoIntervalDay = 0,
    ApplePayDemoIntervalWeek,
    ApplePayDemoIntervalMonth,
    ApplePayDemoIntervalYear
};

@interface ApplePayDemoSettings : NSObject

// Button & theme
@property (nonatomic) PKPaymentButtonType buttonType;
@property (nonatomic) PKPaymentButtonStyle buttonStyle;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGFloat buttonHeight;
@property (nonatomic) NSInteger emptyWalletBehavior; // ApplePayEmptyWalletBehavior raw value
@property (nonatomic, copy) NSString *dividerText;

// Configuration
@property (nonatomic, copy) NSString *countryCode;
@property (nonatomic, copy) NSString *currencyCode;
@property (nonatomic, strong) NSMutableSet<PKPaymentNetwork> *networks;
@property (nonatomic) ApplePayDemoCardTypes cardTypes;
@property (nonatomic, strong) NSMutableSet<PKContactField> *billingContactFields;
@property (nonatomic, strong) NSMutableSet<PKContactField> *shippingContactFields;
@property (nonatomic) BOOL includeMetadata;
/// Card-issuing countries (ISO codes). Empty accepts any country.
@property (nonatomic, strong) NSMutableSet<NSString *> *supportedCountries;
/// Synthetic order ID sent as payment method metadata; fixed for this settings copy.
@property (nonatomic, copy, readonly) NSString *demoOrderId;
/// Prefill the sheet with a synthetic saved billing / shipping contact.
@property (nonatomic) BOOL prefillBillingContact;
@property (nonatomic) BOOL prefillShippingContact;
/// Prefills need their matching field: Apple ignores a saved contact the sheet doesn't ask for.
@property (nonatomic, readonly) BOOL canPrefillBilling;
@property (nonatomic, readonly) BOOL canPrefillShipping;
/// Turns off a prefill whose needed field was turned off.
- (void)clearPrefillsWithoutFields;
/// How the sheet labels the shipping address.
@property (nonatomic) PKShippingType shippingType;
@property (nonatomic) BOOL simulateSlowServer;
/// The demo backend declines with a field error that marks the shipping address in the sheet.
@property (nonatomic) BOOL simulateUndeliverableAddress;
@property (nonatomic) NSTimeInterval processPaymentTimeout;

/// Amount for one-time checkouts that let the shopper type one (Button Only).
@property (nonatomic, copy) NSString *oneTimeAmount;
// Recurring
@property (nonatomic) ApplePayDemoInterval recurringInterval;
@property (nonatomic, copy) NSString *recurringAmount;
@property (nonatomic) BOOL freeTrial;
@property (nonatomic) ApplePayDemoInterval trialInterval;
@property (nonatomic, copy) NSString *billingAgreement;
@property (nonatomic, copy) NSString *managementURL;

/// Delay added to the demo purchase so Apple's ~30 s sheet timeout and the pending flow can be seen.
@property (class, nonatomic, readonly) NSTimeInterval slowServerDelay;

- (ApplePayConfiguration *)configurationForMode:(ApplePayDemoMode)mode;
- (ApplePayOrder *)orderForMode:(ApplePayDemoMode)mode;
/// Wallet for the card drop-in, built from these settings.
- (SpreedlyApplePayWallet *)walletForMode:(ApplePayDemoMode)mode;
- (NSDecimalNumber *)decimalFromString:(NSString *)text;
/// "USD 12.50" — always two decimals for the demo display.
- (NSString *)displayAmount:(NSDecimalNumber *)amount;
/// Amount the  backend charges in processPayment (0 during a free trial).
- (NSDecimalNumber *)chargeAmountForMode:(ApplePayDemoMode)mode;
/// Demo processPayment: charges the token on the demo backend while the sheet is open.
- (void)chargeAuthorization:(ApplePayPaymentAuthorization *)authorization
                       mode:(ApplePayDemoMode)mode
                 completion:(void (^)(ApplePayPaymentDecision *decision))completion;

// Catalogs for pickers: each entry is @{@"title": NSString, @"value": NSNumber or NSString}.
+ (NSArray<NSDictionary *> *)buttonTypeOptions;
+ (NSArray<NSDictionary *> *)buttonStyleOptions;
+ (NSArray<NSDictionary *> *)networkOptions;
+ (NSArray<NSDictionary *> *)contactFieldOptions;
/// Shipping type labels: @{@"title", @"value" (PKShippingType as NSNumber)}.
+ (NSArray<NSDictionary *> *)shippingTypeOptions;
/// Address error shown under Apple's heading on the sheet, worded to match the shipping type.
+ (NSString *)unserviceableAddressMessageForShippingType:(PKShippingType)shippingType;
/// Synthetic saved contact for the prefill demo. Not a real person or address.
+ (PKContact *)syntheticSavedContact;
/// Card-issuing countries offered in the demo: @{@"title", @"value" (ISO code)}.
+ (NSArray<NSDictionary *> *)countryOptions;
+ (NSArray<NSString *> *)intervalTitles;
/// Example subscription terms built from the current amount, interval and trial, for the sheet's billing agreement.
- (NSString *)suggestedBillingTerms;

// Spreedly Test gateway: one switch for every Apple Pay demo, kept in memory for this launch only.
// The demo backend charges on a Spreedly Test gateway, which declines every Apple Pay card unless a
// Spreedly test card number is sent with the token (Apple Pay can't produce test cards).

/// On by default, so every launch works against the demo backend.
@property (class, nonatomic) BOOL testCardEnabled;
@property (class, nonatomic, copy) NSString *testCardNumber;
/// Spreedly's Visa test card that succeeds on the Test gateway.
@property (class, nonatomic, readonly) NSString *defaultTestCardNumber;
/// Shown under the test card field when `testCardNumber` isn't a valid card number (length and
/// Luhn checksum), or nil. An early hint only: the SDK checks again, per card brand, when Apple Pay
/// is tapped and fails the checkout before the sheet opens.
@property (class, nonatomic, readonly, nullable) NSString *testCardNumberProblem;

// Keyboard

/// Toolbar with a Done button for text fields; number and decimal pads have no return key.
+ (UIToolbar *)keyboardToolbarEndingEditingIn:(UIView *)view;
/// Ends editing when the user taps outside a text field in `view`. Taps on controls still go through.
+ (void)installTapToDismissKeyboardIn:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
