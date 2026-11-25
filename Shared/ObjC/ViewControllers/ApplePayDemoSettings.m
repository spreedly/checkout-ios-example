//
//  ApplePayDemoSettings.m
//  SpreedlySDKExampleObjectiveC
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if __has_include(<SpreedlyApplePay/SpreedlyApplePay-Swift.h>)

#import "ApplePayDemoSettings.h"
#import "SpreedlyConfigManager.h"
#import "PurchaseAPIClient.h"
#import "PurchaseModels.h"
#import "AppConstants.h"
#import <SpreedlyApplePay/SpreedlyApplePay-Swift.h>
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <Contacts/Contacts.h>
#import <objc/runtime.h>

static const void *ApplePayDemoTapDismissKey = &ApplePayDemoTapDismissKey;

/// Ignores taps that land on a text field, so tapping another field moves focus instead of closing the keyboard.
@interface ApplePayDemoTapDismissDelegate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIView *view;
@end

@implementation ApplePayDemoTapDismissDelegate

- (void)tapped {
    [self.view endEditing:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    for (UIView *view = touch.view; view != nil; view = view.superview) {
        if ([view isKindOfClass:UITextField.class] || [view isKindOfClass:UITextView.class]) { return NO; }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

@end

static NSString *const ApplePayDemoMerchantLabel = @"Spreedly Demo";

/// Minor-unit digits for a currency (2 for USD, 0 for JPY), as the demo backend expects amounts.
static short ApplePayMinorUnitDigits(NSString *currencyCode) {
    int32_t digits = 2;
    double rounding = 0;
    if (!CFNumberFormatterGetDecimalInfoForCurrencyCode((__bridge CFStringRef)currencyCode, &digits, &rounding)) {
        digits = 2;
    }
    return (short)digits;
}

@implementation ApplePayDemoSettings

/// Address error shown under Apple's heading on the sheet, worded to match the shipping type.
+ (NSString *)unserviceableAddressMessageForShippingType:(PKShippingType)shippingType {
    switch (shippingType) {
        case PKShippingTypeDelivery: return @"We don't deliver to this address";
        case PKShippingTypeStorePickup: return @"Store pickup isn't available for this address";
        case PKShippingTypeServicePickup: return @"Service isn't available at this address";
        default: return @"We don't ship to this address";
    }
}

- (BOOL)canPrefillBilling {
    return [self.billingContactFields containsObject:PKContactFieldPostalAddress];
}

- (BOOL)canPrefillShipping {
    return self.shippingContactFields.count > 0;
}

- (void)clearPrefillsWithoutFields {
    if (!self.canPrefillBilling) { self.prefillBillingContact = NO; }
    if (!self.canPrefillShipping) { self.prefillShippingContact = NO; }
}

+ (NSTimeInterval)slowServerDelay {
    return 40;
}

- (instancetype)init {
    if ((self = [super init])) {
        [self applyDefaults];
    }
    return self;
}

- (void)applyDefaults {
    self.buttonType = PKPaymentButtonTypeBuy;
    self.buttonStyle = PKPaymentButtonStyleAutomatic;
    self.cornerRadius = 8;
    self.buttonHeight = 48;
    // Demo offers Show Pay button or Hide when Wallet has no eligible card.
    self.emptyWalletBehavior = ApplePayEmptyWalletBehaviorShowPayButton;
    self.dividerText = @"";

    self.countryCode = @"US";
    self.currencyCode = @"USD";
    self.networks = [NSMutableSet setWithArray:ApplePayConfiguration.defaultSupportedNetworks];
    self.cardTypes = ApplePayDemoCardTypesAny;
    self.billingContactFields = [NSMutableSet set];
    self.shippingContactFields = [NSMutableSet set];
    self.includeMetadata = NO;
    // On by default: the sheet shows success only after the demo backend charges the card.
    self.prefillBillingContact = NO;
    self.prefillShippingContact = NO;
    self.shippingType = PKShippingTypeShipping;
    self.simulateSlowServer = NO;
    self.simulateUndeliverableAddress = NO;
    self.processPaymentTimeout = ApplePayConfiguration.defaultProcessPaymentTimeout;

    self.oneTimeAmount = @"1.00";
    self.supportedCountries = [NSMutableSet set];
    _demoOrderId = [NSString stringWithFormat:@"synthetic-%ld", (long)NSDate.date.timeIntervalSince1970];

    self.recurringInterval = ApplePayDemoIntervalMonth;
    self.recurringAmount = @"1.00";
    self.freeTrial = NO;
    self.trialInterval = ApplePayDemoIntervalWeek;
    self.billingAgreement = @"";
    self.managementURL = @"https://example.com/account/subscription";
}

#pragma mark - Building SDK objects

- (ApplePayConfiguration *)configurationForMode:(ApplePayDemoMode)mode {
    NSString *merchantId = [SpreedlyConfigManager shared].applePayMerchantId ?: @"";
    ApplePayConfiguration *configuration = [[ApplePayConfiguration alloc] initWithMerchantIdentifier:merchantId
                                                                                         countryCode:self.countryCode
                                                                                        currencyCode:self.currencyCode];
    NSMutableArray<PKPaymentNetwork> *ordered = [NSMutableArray array];
    for (NSDictionary *option in [ApplePayDemoSettings networkOptions]) {
        if ([self.networks containsObject:option[@"value"]]) { [ordered addObject:option[@"value"]]; }
    }
    // Passed as is: with none selected the SDK fails the checkout ("needs at least one supported network").
    configuration.supportedNetworks = ordered;
    switch (self.cardTypes) {
        case ApplePayDemoCardTypesDebit:
            configuration.merchantCapabilities = PKMerchantCapability3DS | PKMerchantCapabilityDebit;
            break;
        case ApplePayDemoCardTypesCredit:
            configuration.merchantCapabilities = PKMerchantCapability3DS | PKMerchantCapabilityCredit;
            break;
        default:
            configuration.merchantCapabilities = PKMerchantCapability3DS;
            break;
    }
    configuration.requiredBillingContactFields = [self.billingContactFields copy];
    configuration.requiredShippingContactFields = [self.shippingContactFields copy];
    // Passed as is: without the matching contact fields the SDK fails the checkout and says which to add.
    configuration.billingContact = self.prefillBillingContact ? [ApplePayDemoSettings syntheticSavedContact] : nil;
    configuration.shippingContact = self.prefillShippingContact ? [ApplePayDemoSettings syntheticSavedContact] : nil;
    configuration.shippingType = self.shippingType;
    // Default Buy becomes Subscribe where that reads better; a picked type is kept.
    configuration.buttonType = self.buttonType;
    if (self.buttonType == PKPaymentButtonTypeBuy && mode == ApplePayDemoModeRecurring) {
        configuration.buttonType = PKPaymentButtonTypeSubscribe;
    }
    configuration.buttonStyle = self.buttonStyle;
    configuration.cornerRadius = self.cornerRadius;
    configuration.emptyWalletBehavior = (ApplePayEmptyWalletBehavior)self.emptyWalletBehavior;
    configuration.processPaymentTimeout = self.processPaymentTimeout;
    configuration.supportedCountries = self.supportedCountries.count > 0 ? [self.supportedCountries copy] : nil;
    if (self.includeMetadata) {
        configuration.metadata = @{@"demo_order_id": self.demoOrderId};
    }
    configuration.testCardNumber = ApplePayDemoSettings.testCardEnabled ? ApplePayDemoSettings.testCardNumber : nil;
    return configuration;
}

- (ApplePayOrder *)orderForMode:(ApplePayDemoMode)mode {
    switch (mode) {
        case ApplePayDemoModeRecurring:
            return [self recurringOrder];
        default:
            return [[ApplePayOrder alloc] initWithLabel:ApplePayDemoMerchantLabel amount:[self oneTimeDecimal]];
    }
}

- (NSString *)displayAmount:(NSDecimalNumber *)amount {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    formatter.minimumIntegerDigits = 1;
    return [NSString stringWithFormat:@"%@ %@", self.currencyCode.uppercaseString, [formatter stringFromNumber:amount]];
}

- (NSDecimalNumber *)decimalFromString:(NSString *)text {
    return [self decimal:text];
}

- (NSDecimalNumber *)chargeAmountForMode:(ApplePayDemoMode)mode {
    switch (mode) {
        case ApplePayDemoModeRecurring:
            return self.freeTrial ? NSDecimalNumber.zero : [self decimal:self.recurringAmount];
        default:
            return [self oneTimeDecimal];
    }
}

- (void)chargeAuthorization:(ApplePayPaymentAuthorization *)authorization
                       mode:(ApplePayDemoMode)mode
                 completion:(void (^)(ApplePayPaymentDecision *decision))completion {
    // The sheet keeps spinning until the backend purchase answers, so Apple's success check means
    // the money moved. A production backend takes the amount from its own order, sends an
    // idempotency key, and for subscriptions sends stored-credential fields. Uses the backend's purchase
    // without Spreedly 3DS: Apple Pay already authenticated the shopper.
    NSDecimalNumber *amount = [self chargeAmountForMode:mode];
    NSString *currency = self.currencyCode.uppercaseString;
    BOOL undeliverable = self.simulateUndeliverableAddress;
    NSString *unserviceableReason = [ApplePayDemoSettings unserviceableAddressMessageForShippingType:self.shippingType];
    NSTimeInterval delay = self.simulateSlowServer ? ApplePayDemoSettings.slowServerDelay : 0;
    // Same order as the Swift demo: server delay, then address check, then free trial, then purchase.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (undeliverable) {
            // A real backend would check the shipping address before charging. The sheet marks the
            // address so the shopper can change it.
            NSError *unserviceable =
                [PKPaymentRequest paymentShippingAddressUnserviceableErrorWithLocalizedDescription:unserviceableReason];
            completion([ApplePayPaymentDecision declinedWithMessage:[unserviceableReason stringByAppendingString:@"."]
                                                             errors:@[unserviceable]]);
            return;
        }
        // Free trial: nothing to charge today; the token is retained for the first renewal.
        if ([amount compare:NSDecimalNumber.zero] != NSOrderedDescending) {
            completion(ApplePayPaymentDecision.approved);
            return;
        }
        PurchaseAPIClient *client = [[SpreedlyConfigManager shared] createPurchaseAPIClient];
        NSDecimalNumber *amountInMinorUnits = [amount decimalNumberByMultiplyingByPowerOf10:ApplePayMinorUnitDigits(currency)];
        [client simplePurchaseWithPaymentMethodToken:authorization.paymentMethodToken
                                              amount:amountInMinorUnits
                                        currencyCode:currency
                                          completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
            if (response.transaction.succeeded) {
                completion(ApplePayPaymentDecision.approved);
                return;
            }
            NSInteger status = [error.userInfo[PurchaseAPIStatusCodeKey] integerValue];
            if (status >= 400 && status < 500) {
                // The server answered and did not charge: a decline the shopper can retry with another card.
                NSString *message = error.userInfo[PurchaseAPIServerMessageKey];
                completion([ApplePayPaymentDecision declinedWithMessage:message.length > 0 ? message : @"Payment was declined"]);
                return;
            }
            if (error) {
                // No confirmed answer from the server: report "status unknown" so the sheet closes
                // and the shopper isn't offered another try while the charge may still go through.
                completion(ApplePayPaymentDecision.statusUnknown);
                return;
            }
            NSString *reason = response.errors.firstObject.message;
            completion([ApplePayPaymentDecision declinedWithMessage:reason.length > 0 ? reason : @"Payment was declined"]);
        }];
    });
}

/// Typed one-time amount; falls back to 1.00 when empty or not positive.
- (NSDecimalNumber *)oneTimeDecimal {
    NSDecimalNumber *value = [self decimal:self.oneTimeAmount];
    return [value compare:NSDecimalNumber.zero] == NSOrderedDescending ? value : [NSDecimalNumber decimalNumberWithString:@"1.00"];
}

- (SpreedlyApplePayWallet *)walletForMode:(ApplePayDemoMode)mode {
    // The demo backend charges the card before the sheet shows success.
    __weak typeof(self) weakSelf = self;
    SpreedlyApplePayWallet *wallet =
        [[SpreedlyApplePayWallet alloc] initWithConfiguration:[self configurationForMode:mode]
                                                        order:[self orderForMode:mode]
                                            signedAuthHandler:^(void (^completion)(SpreedlyConfig * _Nullable, NSError * _Nullable)) {
            [[SpreedlyConfigManager shared] fetchSignedAuthWithCompletion:completion];
        }
                                        processPaymentHandler:^(ApplePayPaymentAuthorization *authorization,
                                                                void (^completion)(ApplePayPaymentDecision *)) {
            [weakSelf chargeAuthorization:authorization mode:mode completion:completion];
        }];
    [wallet setPrepareForPresentationHandler:^(void (^completion)(BOOL)) {
        // Signed auth for Apple Pay comes from signedAuthHandler; only set the SDK up if needed.
        if (Spreedly.isInitialized) {
            completion(YES);
            return;
        }
        [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
            completion(success);
        }];
    }];
    return wallet;
}

- (ApplePayOrder *)recurringOrder {
    NSString *label = [NSString stringWithFormat:@"%@ Plan", ApplePayDemoMerchantLabel];
    PKRecurringPaymentSummaryItem *regular =
        [PKRecurringPaymentSummaryItem summaryItemWithLabel:label amount:[self decimal:self.recurringAmount]];
    regular.intervalUnit = [self calendarUnitFor:self.recurringInterval];
    regular.intervalCount = [self intervalCountFor:self.recurringInterval];

    PKRecurringPaymentSummaryItem *trial = nil;
    if (self.freeTrial) {
        trial = [PKRecurringPaymentSummaryItem summaryItemWithLabel:@"Free trial" amount:NSDecimalNumber.zero];
        trial.intervalUnit = [self calendarUnitFor:self.trialInterval];
        trial.intervalCount = [self intervalCountFor:self.trialInterval];
        NSDate *trialEnd = [NSCalendar.currentCalendar dateByAddingUnit:[self calendarUnitFor:self.trialInterval]
                                                                  value:[self intervalCountFor:self.trialInterval]
                                                                 toDate:NSDate.date
                                                                options:0] ?: NSDate.date;
        trial.endDate = trialEnd;
        regular.startDate = trialEnd;
    }

    NSURL *managementURL = [NSURL URLWithString:self.managementURL]
        ?: [NSURL URLWithString:@"https://example.com/account/subscription"];
    NSString *description = [NSString stringWithFormat:@"%@ – %@", label,
                             [ApplePayDemoSettings intervalTitles][self.recurringInterval].lowercaseString];
    PKRecurringPaymentRequest *request = [[PKRecurringPaymentRequest alloc] initWithPaymentDescription:description
                                                                                        regularBilling:regular
                                                                                         managementURL:managementURL];
    request.trialBilling = trial;
    if (self.billingAgreement.length > 0) { request.billingAgreement = self.billingAgreement; }
    return [[ApplePayOrder alloc] initWithRecurringPaymentRequest:request];
}

/// Apple Pay rejects week units, so a week is sent as 7 days (see intervalCountFor:).
- (NSCalendarUnit)calendarUnitFor:(ApplePayDemoInterval)interval {
    switch (interval) {
        case ApplePayDemoIntervalDay:
        case ApplePayDemoIntervalWeek: return NSCalendarUnitDay;
        case ApplePayDemoIntervalYear: return NSCalendarUnitYear;
        default: return NSCalendarUnitMonth;
    }
}

- (NSInteger)intervalCountFor:(ApplePayDemoInterval)interval {
    return interval == ApplePayDemoIntervalWeek ? 7 : 1;
}

- (NSDecimalNumber *)decimal:(NSString *)text {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSDecimalNumber *value = [NSDecimalNumber decimalNumberWithString:trimmed];
    return [value isEqualToNumber:NSDecimalNumber.notANumber] ? NSDecimalNumber.zero : value;
}

#pragma mark - Catalogs

+ (NSArray<NSDictionary *> *)buttonTypeOptions {
    return @[
        @{@"title": @"Plain", @"value": @(PKPaymentButtonTypePlain)},
        @{@"title": @"Buy", @"value": @(PKPaymentButtonTypeBuy)},
        @{@"title": @"Check Out", @"value": @(PKPaymentButtonTypeCheckout)},
        @{@"title": @"Book", @"value": @(PKPaymentButtonTypeBook)},
        @{@"title": @"Subscribe", @"value": @(PKPaymentButtonTypeSubscribe)},
        @{@"title": @"Donate", @"value": @(PKPaymentButtonTypeDonate)},
        @{@"title": @"Order", @"value": @(PKPaymentButtonTypeOrder)},
        @{@"title": @"Reload", @"value": @(PKPaymentButtonTypeReload)},
        @{@"title": @"Add Money", @"value": @(PKPaymentButtonTypeAddMoney)},
        @{@"title": @"Top Up", @"value": @(PKPaymentButtonTypeTopUp)},
        @{@"title": @"Rent", @"value": @(PKPaymentButtonTypeRent)},
        @{@"title": @"Support", @"value": @(PKPaymentButtonTypeSupport)},
        @{@"title": @"Contribute", @"value": @(PKPaymentButtonTypeContribute)},
        @{@"title": @"Tip", @"value": @(PKPaymentButtonTypeTip)},
        @{@"title": @"Continue", @"value": @(PKPaymentButtonTypeContinue)},
        @{@"title": @"In Store", @"value": @(PKPaymentButtonTypeInStore)}
    ];
}

+ (NSArray<NSDictionary *> *)buttonStyleOptions {
    return @[
        @{@"title": @"Automatic", @"value": @(PKPaymentButtonStyleAutomatic)},
        @{@"title": @"Black", @"value": @(PKPaymentButtonStyleBlack)},
        @{@"title": @"White", @"value": @(PKPaymentButtonStyleWhite)},
        @{@"title": @"Outline", @"value": @(PKPaymentButtonStyleWhiteOutline)}
    ];
}

+ (NSArray<NSDictionary *> *)networkOptions {
    return @[
        @{@"title": @"Visa", @"value": PKPaymentNetworkVisa},
        @{@"title": @"Mastercard", @"value": PKPaymentNetworkMasterCard},
        @{@"title": @"American Express", @"value": PKPaymentNetworkAmex},
        @{@"title": @"Discover", @"value": PKPaymentNetworkDiscover},
        @{@"title": @"JCB (Japan)", @"value": PKPaymentNetworkJCB},
        @{@"title": @"Maestro", @"value": PKPaymentNetworkMaestro},
        @{@"title": @"Cartes Bancaires (France)", @"value": PKPaymentNetworkCartesBancaires},
        @{@"title": @"Interac (Canada)", @"value": PKPaymentNetworkInterac},
        @{@"title": @"mada (Saudi Arabia)", @"value": PKPaymentNetworkMada},
        @{@"title": @"Elo (Brazil)", @"value": PKPaymentNetworkElo},
        @{@"title": @"Bancontact (Belgium)", @"value": PKPaymentNetworkBancontact},
        @{@"title": @"Dankort (Denmark)", @"value": PKPaymentNetworkDankort}
    ];
}

+ (NSArray<NSDictionary *> *)countryOptions {
    return @[
        @{@"title": @"United States", @"value": @"US"}, @{@"title": @"Canada", @"value": @"CA"},
        @{@"title": @"United Kingdom", @"value": @"GB"}, @{@"title": @"Australia", @"value": @"AU"},
        @{@"title": @"Germany", @"value": @"DE"}, @{@"title": @"France", @"value": @"FR"},
        @{@"title": @"India", @"value": @"IN"}, @{@"title": @"Japan", @"value": @"JP"}
    ];
}

+ (NSArray<NSDictionary *> *)contactFieldOptions {
    return @[
        @{@"title": @"Name", @"value": PKContactFieldName},
        @{@"title": @"Postal address", @"value": PKContactFieldPostalAddress},
        @{@"title": @"Email", @"value": PKContactFieldEmailAddress},
        @{@"title": @"Phone", @"value": PKContactFieldPhoneNumber}
    ];
}

+ (NSArray<NSDictionary *> *)shippingTypeOptions {
    return @[
        @{@"title": @"Shipping", @"value": @(PKShippingTypeShipping)},
        @{@"title": @"Delivery", @"value": @(PKShippingTypeDelivery)},
        @{@"title": @"Store pickup", @"value": @(PKShippingTypeStorePickup)},
        @{@"title": @"Service pickup", @"value": @(PKShippingTypeServicePickup)}
    ];
}

+ (PKContact *)syntheticSavedContact {
    PKContact *contact = [[PKContact alloc] init];
    NSPersonNameComponents *name = [[NSPersonNameComponents alloc] init];
    name.givenName = @"Test";
    name.familyName = @"Shopper";
    contact.name = name;
    CNMutablePostalAddress *address = [[CNMutablePostalAddress alloc] init];
    address.street = @"1 Example Street";
    address.city = @"Springfield";
    address.state = @"IL";
    address.postalCode = @"62701";
    address.ISOCountryCode = @"US";
    address.country = @"United States";
    contact.postalAddress = address;
    contact.emailAddress = @"test.shopper@example.com";
    // 555-01xx numbers are reserved for fiction.
    contact.phoneNumber = [CNPhoneNumber phoneNumberWithStringValue:@"+1 555 010 0123"];
    return contact;
}

- (NSString *)suggestedBillingTerms {
    NSArray<NSString *> *units = @[@"day", @"week", @"month", @"year"];
    NSString *charge = [NSString stringWithFormat:@"%@ %@ every %@", self.currencyCode.uppercaseString,
                        self.recurringAmount, units[self.recurringInterval]];
    NSString *start = self.freeTrial
        ? [NSString stringWithFormat:@"Free for 1 %@, then you'll be charged %@", units[self.trialInterval], charge]
        : [NSString stringWithFormat:@"You'll be charged %@", charge];
    return [start stringByAppendingString:@" until you cancel. Cancel anytime from the manage subscription link."];
}

+ (NSArray<NSString *> *)intervalTitles {
    return @[@"Daily", @"Weekly", @"Monthly", @"Yearly"];
}

#pragma mark - Spreedly Test gateway

// Kept in memory for this launch only: a card number, even a test one, isn't saved to disk.
static BOOL ApplePayDemoTestCardDisabled = NO;
static NSString *ApplePayDemoTestCardNumberValue = nil;

+ (BOOL)testCardEnabled {
    return !ApplePayDemoTestCardDisabled;
}

+ (void)setTestCardEnabled:(BOOL)testCardEnabled {
    ApplePayDemoTestCardDisabled = !testCardEnabled;
}

+ (NSString *)testCardNumber {
    return ApplePayDemoTestCardNumberValue ?: self.defaultTestCardNumber;
}

+ (void)setTestCardNumber:(NSString *)testCardNumber {
    ApplePayDemoTestCardNumberValue = [testCardNumber copy];
}

+ (NSString *)defaultTestCardNumber {
    return @"4111 1111 1111 1111";
}

+ (nullable NSString *)testCardNumberProblem {
    NSString *digits = [[self.testCardNumber componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
                        componentsJoinedByString:@""];
    NSCharacterSet *nonDigits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"].invertedSet;
    BOOL valid = digits.length >= 12 && digits.length <= 19
        && [digits rangeOfCharacterFromSet:nonDigits].location == NSNotFound
        && [self passesLuhn:digits];
    if (valid) { return nil; }
    return [NSString stringWithFormat:@"Not a valid card number. Use a Spreedly test card such as %@.",
            self.defaultTestCardNumber];
}

/// Card number checksum used by most card brands. `digits` holds ASCII digits only.
+ (BOOL)passesLuhn:(NSString *)digits {
    NSInteger sum = 0;
    BOOL doubleIt = NO;
    for (NSInteger index = (NSInteger)digits.length - 1; index >= 0; index--) {
        NSInteger digit = [digits characterAtIndex:(NSUInteger)index] - '0';
        if (doubleIt) {
            digit *= 2;
            if (digit > 9) { digit -= 9; }
        }
        sum += digit;
        doubleIt = !doubleIt;
    }
    return sum % 10 == 0;
}

#pragma mark - Keyboard

+ (UIToolbar *)keyboardToolbarEndingEditingIn:(UIView *)view {
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    __weak UIView *weakView = view;
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                  primaryAction:[UIAction actionWithHandler:^(UIAction *action) {
        [weakView endEditing:YES];
    }]];
    done.accessibilityHint = @"Hides the keyboard";
    done.accessibilityIdentifier = @"applePayKeyboardDone";
    toolbar.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], done];
    [toolbar sizeToFit];
    return toolbar;
}

+ (void)installTapToDismissKeyboardIn:(UIView *)view {
    if (objc_getAssociatedObject(view, ApplePayDemoTapDismissKey) != nil) { return; }
    ApplePayDemoTapDismissDelegate *delegate = [[ApplePayDemoTapDismissDelegate alloc] init];
    delegate.view = view;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:delegate action:@selector(tapped)];
    tap.cancelsTouchesInView = NO;
    tap.delegate = delegate;
    [view addGestureRecognizer:tap];
    objc_setAssociatedObject(view, ApplePayDemoTapDismissKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#endif
