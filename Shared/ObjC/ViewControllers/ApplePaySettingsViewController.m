//
//  ApplePaySettingsViewController.m
//  SpreedlySDKExampleObjectiveC
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if __has_include(<SpreedlyApplePay/SpreedlyApplePay-Swift.h>)

#import "ApplePaySettingsViewController.h"
#import "ApplePayDemoSettings.h"
#import "SpreedlyConfigManager.h"
#import <SpreedlyApplePay/SpreedlyApplePay-Swift.h>
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>

typedef NS_ENUM(NSInteger, ApplePaySettingRowType) {
    ApplePaySettingRowTypeToggle,
    ApplePaySettingRowTypeChoice,
    ApplePaySettingRowTypeText,
    ApplePaySettingRowTypeSlider,
    ApplePaySettingRowTypeInfo,
    ApplePaySettingRowTypeButtonSample,
    ApplePaySettingRowTypeAction
};

/// One editable row. `getter` returns NSNumber (toggle, choice index, slider) or NSString (text, info).
@interface ApplePaySettingRow : NSObject
@property (nonatomic) ApplePaySettingRowType type;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy, nullable) NSArray<NSString *> *choices;
@property (nonatomic) float minimum;
@property (nonatomic) float maximum;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic, copy) id (^getter)(void);
@property (nonatomic, copy, nullable) void (^setter)(id value);
/// Secondary text under the title (for action rows, the accessibility hint).
@property (nonatomic, copy, nullable) NSString *detail;
/// SF Symbol shown before an action row's title.
@property (nonatomic, copy, nullable) NSString *symbolName;
/// Info rows: show a small spinner, e.g. while a payment is still being confirmed.
@property (nonatomic) BOOL showsActivity;
/// Toggle rows: greyed out while this returns NO. Nil means always enabled.
@property (nonatomic, copy, nullable) BOOL (^isEnabled)(void);
@end

@implementation ApplePaySettingRow
@end

@interface ApplePaySettingsViewController () <UITextFieldDelegate, SpreedlyPaymentDelegate>
@property (nonatomic) ApplePaySettingsKind kind;
/// This screen's own settings; dropped (reset) when the screen closes.
@property (nonatomic, strong) ApplePayDemoSettings *localSettings;
/// Button Only: one-time or recurring.
@property (nonatomic) ApplePayDemoMode buttonOnlyMode;
/// Last payment outcome, shown under the Apple Pay button or as a row on drop-in screens.
@property (nonatomic, copy, nullable) NSString *statusText;
@property (nonatomic) BOOL statusTextIsError;
/// Apple closed the sheet before the server answered; a final result follows.
@property (nonatomic) BOOL statusIsPending;
/// Last successful token, shown masked until the tester taps the eye button.
@property (nonatomic, copy, nullable) NSString *successToken;
@property (nonatomic, copy, nullable) NSString *successPrefix;
@property (nonatomic, copy, nullable) NSString *successSuffix;
@property (nonatomic) BOOL tokenVisible;
@property (nonatomic, strong) NSArray<NSDictionary *> *sections; // @{@"title", @"footer", @"rows"}
@end

@implementation ApplePaySettingsViewController

- (instancetype)initWithKind:(ApplePaySettingsKind)kind {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _kind = kind;
        _localSettings = [[ApplePayDemoSettings alloc] init];
        _buttonOnlyMode = ApplePayDemoModeOneTime;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    switch (self.kind) {
        case ApplePaySettingsKindButton: self.title = @"Button & Theme"; break;
        case ApplePaySettingsKindConfiguration: self.title = @"Configure & Try"; break;
        case ApplePaySettingsKindRecurring: self.title = @"Recurring Payment"; break;
        case ApplePaySettingsKindOneTime: self.title = @"One-time Payment"; break;
        case ApplePaySettingsKindButtonOnly: self.title = @"Button Only"; break;
    }
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [ApplePayDemoSettings installTapToDismissKeyboardIn:self.tableView];
    [self rebuild];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self hasCheckoutButton] || [self isDropInScreen]) {
        [Spreedly.shared setPaymentDelegate:self];
    }
}

- (ApplePayDemoSettings *)settings {
    return self.localSettings;
}

/// One-time and Recurring show Apple Pay inside the card drop-in instead of a standalone button.
- (BOOL)isDropInScreen {
    return self.kind == ApplePaySettingsKindOneTime || self.kind == ApplePaySettingsKindRecurring;
}

/// Opens CardFormDropInViewController with Apple Pay on top, built from this screen's settings.
- (void)presentDropIn {
    ApplePayDemoSettings *settings = [self settings];
    __weak typeof(self) weakSelf = self;
    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CardFormDropInViewController *dropIn = [[CardFormDropInViewController alloc] init];
            dropIn.walletButtons = @[[settings walletForMode:[weakSelf checkoutMode]]];
            dropIn.walletButtonDividerText = settings.dividerText.length > 0 ? settings.dividerText : nil;
            [weakSelf presentViewController:dropIn animated:YES completion:nil];
        });
    }];
}

- (ApplePaySettingRow *)openDropInRow:(NSString *)identifier {
    __weak typeof(self) weakSelf = self;
    ApplePaySettingRow *row = [self rowOfType:ApplePaySettingRowTypeAction title:@"Open Checkout Sheet" identifier:identifier];
    row.detail = @"Opens the card checkout sheet with Apple Pay above the card fields";
    row.setter = ^(id value) { [weakSelf presentDropIn]; };
    return row;
}

#pragma mark - Model

- (void)rebuild {
    switch (self.kind) {
        case ApplePaySettingsKindButton: self.sections = [self buttonSections]; break;
        case ApplePaySettingsKindConfiguration: self.sections = [self configurationSections]; break;
        case ApplePaySettingsKindRecurring:
            self.sections = [[self recurringSections] arrayByAddingObjectsFromArray:[self dropInSections]];
            break;
        case ApplePaySettingsKindOneTime: {
            NSString *order = [NSString stringWithFormat:@"%@    %@", @"Spreedly Demo",
                               [self displayAmount:[[self settings] chargeAmountForMode:ApplePayDemoModeOneTime]]];
            self.sections = [@[@{@"title": @"Your order", @"rows": @[[self infoRow:order]]}]
                             arrayByAddingObjectsFromArray:[self dropInSections]];
            break;
        }
        case ApplePaySettingsKindButtonOnly: self.sections = [self buttonOnlySections]; break;
    }
    if (self.kind == ApplePaySettingsKindButton) {
        [self updatePreviewHeader];
    }
    if ([self hasCheckoutButton]) {
        [self updateCheckoutFooter];
    }
    [self.tableView reloadData];
}

- (ApplePaySettingRow *)rowOfType:(ApplePaySettingRowType)type title:(NSString *)title identifier:(NSString *)identifier {
    ApplePaySettingRow *row = [[ApplePaySettingRow alloc] init];
    row.type = type;
    row.title = title;
    row.identifier = identifier;
    row.keyboardType = UIKeyboardTypeDefault;
    return row;
}

- (ApplePaySettingRow *)choiceRow:(NSString *)title
                       identifier:(NSString *)identifier
                          options:(NSArray<NSDictionary *> *)options
                         selected:(NSInteger (^)(void))selected
                           select:(void (^)(NSDictionary *option, NSInteger index))select {
    ApplePaySettingRow *row = [self rowOfType:ApplePaySettingRowTypeChoice title:title identifier:identifier];
    row.choices = [options valueForKey:@"title"];
    row.getter = ^id { return @(selected()); };
    row.setter = ^(NSNumber *index) { select(options[index.integerValue], index.integerValue); };
    return row;
}

- (ApplePaySettingRow *)toggleRow:(NSString *)title
                       identifier:(NSString *)identifier
                              get:(BOOL (^)(void))get
                              set:(void (^)(BOOL on))set {
    ApplePaySettingRow *row = [self rowOfType:ApplePaySettingRowTypeToggle title:title identifier:identifier];
    row.getter = ^id { return @(get()); };
    row.setter = ^(NSNumber *value) { set(value.boolValue); };
    return row;
}

- (ApplePaySettingRow *)textRow:(NSString *)title
                     identifier:(NSString *)identifier
                       keyboard:(UIKeyboardType)keyboard
                            get:(NSString * (^)(void))get
                            set:(void (^)(NSString *text))set {
    ApplePaySettingRow *row = [self rowOfType:ApplePaySettingRowTypeText title:title identifier:identifier];
    row.keyboardType = keyboard;
    row.getter = ^id { return get(); };
    row.setter = ^(NSString *text) { set(text); };
    return row;
}

/// Adds a one-line explanation shown under the row's title.
- (ApplePaySettingRow *)describe:(ApplePaySettingRow *)row as:(NSString *)detail {
    row.detail = detail;
    return row;
}

- (ApplePaySettingRow *)infoRow:(NSString *)text {
    ApplePaySettingRow *row = [self rowOfType:ApplePaySettingRowTypeInfo title:text identifier:@""];
    row.getter = ^id { return text; };
    return row;
}

- (ApplePaySettingRow *)membershipToggle:(NSString *)title
                              identifier:(NSString *)identifier
                                   value:(NSString *)value
                                   inSet:(NSMutableSet *)set {
    return [self toggleRow:title identifier:identifier
                       get:^BOOL { return [set containsObject:value]; }
                       set:^(BOOL on) { if (on) { [set addObject:value]; } else { [set removeObject:value]; } }];
}

- (ApplePaySettingRow *)enabledWhen:(BOOL (^)(void))isEnabled row:(ApplePaySettingRow *)row {
    row.isEnabled = isEnabled;
    return row;
}

static NSInteger IndexOfValue(NSArray<NSDictionary *> *options, id value) {
    for (NSUInteger index = 0; index < options.count; index++) {
        if ([options[index][@"value"] isEqual:value]) { return (NSInteger)index; }
    }
    return 0;
}

#pragma mark - Sections

- (NSArray<NSDictionary *> *)buttonSections {
    ApplePayDemoSettings *settings = [self settings];
    NSArray *types = [ApplePayDemoSettings buttonTypeOptions];
    NSArray *styles = [ApplePayDemoSettings buttonStyleOptions];

    ApplePaySettingRow *radius = [self rowOfType:ApplePaySettingRowTypeSlider title:@"Corner radius" identifier:@"applePayDesignerRadiusSlider"];
    radius.minimum = 0; radius.maximum = 24;
    radius.getter = ^id { return @(settings.cornerRadius); };
    radius.setter = ^(NSNumber *value) { settings.cornerRadius = roundf(value.floatValue); };

    ApplePaySettingRow *height = [self rowOfType:ApplePaySettingRowTypeSlider title:@"Height" identifier:@"applePayDesignerHeightSlider"];
    height.minimum = 44; height.maximum = 64;   // 44 pt tap-target minimum
    height.getter = ^id { return @(settings.buttonHeight); };
    height.setter = ^(NSNumber *value) { settings.buttonHeight = roundf(value.floatValue); };

    ApplePaySettingRow *dropInButton = [self rowOfType:ApplePaySettingRowTypeButtonSample title:@"Apple Pay" identifier:@""];
    dropInButton.getter = ^id { return @(settings.buttonType); };
    ApplePaySettingRow *setUpButton = [self rowOfType:ApplePaySettingRowTypeButtonSample title:@"Set Up Apple Pay"
                                           identifier:@"applePayDesignerSetUpPreview"];
    setUpButton.getter = ^id { return @(PKPaymentButtonTypeSetUp); };
    NSString *divider = settings.dividerText.length > 0 ? settings.dividerText : @"or pay with card";

    return @[
        @{@"title": @"Button", @"rows": @[
            [self choiceRow:@"Type" identifier:@"applePayDesignerTypePicker" options:types
                   selected:^NSInteger { return IndexOfValue(types, @(settings.buttonType)); }
                     select:^(NSDictionary *option, NSInteger index) { settings.buttonType = [option[@"value"] integerValue]; }],
            [self choiceRow:@"Style" identifier:@"applePayDesignerStylePicker" options:styles
                   selected:^NSInteger { return IndexOfValue(styles, @(settings.buttonStyle)); }
                     select:^(NSDictionary *option, NSInteger index) { settings.buttonStyle = [option[@"value"] integerValue]; }],
            radius, height]},
        @{@"title": @"Checkout sheet",
          @"footer": @"Apple Pay sits above the card fields with this divider text. Empty uses the localized default.",
          @"rows": @[
            [self textRow:@"Divider" identifier:@"applePayDesignerDividerField" keyboard:UIKeyboardTypeDefault
                      get:^NSString * { return settings.dividerText; }
                      set:^(NSString *text) { settings.dividerText = text; }],
            dropInButton,
            [self infoRow:[NSString stringWithFormat:@"——  %@  ——", divider]],
            [self infoRow:@"Card number · MM/YY · CVC"],
            [self openDropInRow:@"applePayDesignerOpenDropIn"]]},
        @{@"title": @"Set Up Apple Pay button",
          @"footer": @"Preview only. In checkout, SpreedlyApplePaySetUpButtonView shows this when the device supports Apple Pay but Wallet has no eligible card.",
          @"rows": @[setUpButton]}
    ];
}

- (NSArray<NSDictionary *> *)configurationSections {
    NSArray *emptyWallet = @[
        @{@"title": @"Pay button", @"value": @(ApplePayEmptyWalletBehaviorShowPayButton)},
        @{@"title": @"Hide", @"value": @(ApplePayEmptyWalletBehaviorHide)}
    ];
    ApplePayDemoSettings *settings = [self settings];
    NSString *merchantId = [SpreedlyConfigManager shared].applePayMerchantId;
    NSArray *cardTypes = @[
        @{@"title": @"Any", @"value": @(ApplePayDemoCardTypesAny)},
        @{@"title": @"Debit only", @"value": @(ApplePayDemoCardTypesDebit)},
        @{@"title": @"Credit only", @"value": @(ApplePayDemoCardTypesCredit)}
    ];

    NSMutableArray *networkRows = [NSMutableArray array];
    for (NSDictionary *option in [ApplePayDemoSettings networkOptions]) {
        NSString *identifier = [NSString stringWithFormat:@"applePayConfigNetwork-%@", option[@"value"]];
        [networkRows addObject:[self membershipToggle:option[@"title"] identifier:identifier
                                                value:option[@"value"] inSet:settings.networks]];
    }
    // Apple only collects the postal address (and the name with it) for billing.
    NSArray *billingRows = @[[self toggleRow:@"Postal address (includes name)" identifier:@"applePayConfigBilling-PostalAddress"
                                         get:^BOOL { return [settings.billingContactFields containsObject:PKContactFieldPostalAddress]; }
                                         set:^(BOOL on) {
                                             [settings.billingContactFields removeAllObjects];
                                             if (on) {
                                                 [settings.billingContactFields addObjectsFromArray:@[PKContactFieldPostalAddress, PKContactFieldName]];
                                             }
                                         }],
                             [self describe:[self enabledWhen:^BOOL { return settings.canPrefillBilling; }
                                                          row:[self toggleRow:@"Prefill a saved billing address" identifier:@"applePayConfigPrefillBilling"
                                                                          get:^BOOL { return settings.prefillBillingContact; }
                                                                          set:^(BOOL on) { settings.prefillBillingContact = on; }]]
                                         as:@"Passes a synthetic saved address as billingContact; the sheet shows it as the default. Turn on Postal address above to use it: Apple only shows a saved billing address when the sheet asks for one."]];
    NSMutableArray *countryRows = [NSMutableArray array];
    for (NSDictionary *option in [ApplePayDemoSettings countryOptions]) {
        NSString *identifier = [@"applePayConfigCountry-" stringByAppendingString:option[@"value"]];
        [countryRows addObject:[self membershipToggle:option[@"title"] identifier:identifier
                                                value:option[@"value"] inSet:settings.supportedCountries]];
    }
    NSMutableArray *shippingRows = [NSMutableArray array];
    for (NSDictionary *option in [ApplePayDemoSettings contactFieldOptions]) {
        [shippingRows addObject:[self membershipToggle:option[@"title"]
                                            identifier:[@"applePayConfigShipping-" stringByAppendingString:option[@"title"]]
                                                 value:option[@"value"] inSet:settings.shippingContactFields]];
    }
    [shippingRows addObject:[self describe:[self enabledWhen:^BOOL { return settings.canPrefillShipping; }
                                                         row:[self toggleRow:@"Prefill a saved shipping contact" identifier:@"applePayConfigPrefillShipping"
                                                                         get:^BOOL { return settings.prefillShippingContact; }
                                                                         set:^(BOOL on) { settings.prefillShippingContact = on; }]]
                                        as:@"Passes a synthetic saved contact as shippingContact. Turn on at least one shipping field above to use it: Apple only shows the saved details the sheet asks for."]];
    NSArray<NSDictionary *> *shippingTypes = [ApplePayDemoSettings shippingTypeOptions];
    [shippingRows addObject:[self describe:[self choiceRow:@"Shipping type" identifier:@"applePayConfigShippingType" options:shippingTypes
                                                  selected:^NSInteger { return IndexOfValue(shippingTypes, @(settings.shippingType)); }
                                                    select:^(NSDictionary *option, NSInteger index) {
                                                        settings.shippingType = (PKShippingType)[option[@"value"] unsignedIntegerValue];
                                                    }]
                                        as:@"Changes only how the sheet labels the address, e.g. \"Delivery Address\". Turn on Postal address to see it."]];

    ApplePaySettingRow *timeout = [self rowOfType:ApplePaySettingRowTypeSlider title:@"processPaymentTimeout" identifier:@"applePayConfigTimeoutSlider"];
    timeout.minimum = 30; timeout.maximum = 300;
    timeout.getter = ^id { return @(settings.processPaymentTimeout); };
    timeout.setter = ^(NSNumber *value) { settings.processPaymentTimeout = roundf(value.floatValue / 10) * 10; };

    NSString *slowTitle = [NSString stringWithFormat:@"Simulate slow server (%.0f s)", ApplePayDemoSettings.slowServerDelay];
    return @[
        @{@"title": @"Order",
          @"footer": @"Amount for this one-time payment, in the currency below. Your server should charge the same amount.",
          @"rows": @[
            [self textRow:[NSString stringWithFormat:@"Amount (%@)", settings.currencyCode.uppercaseString]
               identifier:@"applePayConfigAmount" keyboard:UIKeyboardTypeDecimalPad
                      get:^NSString * { return settings.oneTimeAmount; }
                      set:^(NSString *text) { settings.oneTimeAmount = text; }]]},
        @{@"title": @"Merchant",
          @"footer": @"Merchant ID comes from SpreedlyKeys.xcconfig and must match the app's Apple Pay entitlement.",
          @"rows": @[
            [self infoRow:[NSString stringWithFormat:@"Merchant ID: %@", merchantId.length > 0 ? merchantId : @"Not set"]],
            [self textRow:@"Country (ISO 3166)" identifier:@"applePayConfigCountry" keyboard:UIKeyboardTypeASCIICapable
                      get:^NSString * { return settings.countryCode; }
                      set:^(NSString *text) { settings.countryCode = text.uppercaseString; }],
            [self textRow:@"Currency (ISO 4217)" identifier:@"applePayConfigCurrency" keyboard:UIKeyboardTypeASCIICapable
                      get:^NSString * { return settings.currencyCode; }
                      set:^(NSString *text) { settings.currencyCode = text.uppercaseString; }]]},
        @{@"title": @"Card networks",
          @"footer": settings.networks.count == 0
              ? @"No network selected. Apple Pay won't open: the checkout fails with \"needs at least one supported network\". Select at least one."
              : @"Only the selected networks can pay. Default: every network Spreedly accepts; turn off the ones your gateway doesn't support. At least one is required.",
          @"rows": networkRows},
        @{@"title": @"Card types",
          @"footer": @"Other card types are greyed out in the Apple Pay sheet. The SDK always keeps .threeDSecure (Apple Pay's payment format, not a 3-D Secure challenge).",
          @"rows": @[
            [self choiceRow:@"Accept" identifier:@"applePayConfigCardTypes" options:cardTypes
                   selected:^NSInteger { return settings.cardTypes; }
                     select:^(NSDictionary *option, NSInteger index) { settings.cardTypes = index; }]]},
        @{@"title": @"Billing contact",
          @"footer": @"For billing, Apple only collects the postal address and the name with it. Ask for phone or email under Shipping contact fields.",
          @"rows": billingRows},
        @{@"title": @"Shipping contact fields", @"rows": shippingRows},
        @{@"title": @"Card-issuing countries",
          @"footer": @"Only cards issued in the selected countries can pay. None selected means any country (no restriction).",
          @"rows": countryRows},
        @{@"title": @"Payment method metadata",
          @"footer": @"Stored on the Spreedly payment method, not shown on the sheet. The ID appears in the status after payment.",
          @"rows": @[
            [self toggleRow:@"Attach demo order ID" identifier:@"applePayConfigMetadata"
                        get:^BOOL { return settings.includeMetadata; }
                        set:^(BOOL on) { settings.includeMetadata = on; }]]},
        @{@"title": @"When Wallet has no card",
          @"footer": @"Pay button: Apple's sheet helps the shopper add a card. Hide: no Apple Pay button until a card is added.",
          @"rows": @[
            [self choiceRow:@"Empty Wallet" identifier:@"applePayConfigEmptyWalletPicker" options:emptyWallet
                   selected:^NSInteger { return IndexOfValue(emptyWallet, @(settings.emptyWalletBehavior)); }
                     select:^(NSDictionary *option, NSInteger index) { settings.emptyWalletBehavior = [option[@"value"] integerValue]; }]]},
        @{@"title": @"Server timing",
          @"footer": @"After Face ID, Apple's sheet waits while the demo backend charges the card, and shows success only if the charge works. Apple closes the sheet after about 30 s; the SDK keeps waiting for the backend's answer.",
          @"rows": @[
            [self describe:[self toggleRow:slowTitle identifier:@"applePayConfigSlowServerToggle"
                                       get:^BOOL { return settings.simulateSlowServer; }
                                       set:^(BOOL on) { settings.simulateSlowServer = on; }]
                      as:@"Makes the demo charge take 40 s, longer than Apple's ~30 s. You'll see the sheet close, then \"Your payment is still being processed. Please don't pay again.\", then the real result."],
            [self describe:[self toggleRow:@"Decline: address not deliverable" identifier:@"applePayConfigUndeliverableToggle"
                                       get:^BOOL { return settings.simulateUndeliverableAddress; }
                                       set:^(BOOL on) { settings.simulateUndeliverableAddress = on; }]
                      as:@"The demo backend answers declinedWithMessage:errors: with a shipping-address error instead of charging. Turn on the shipping Postal address: the sheet marks the address. Every attempt is declined while this is on; turn it off to pay."],
            timeout,
            [self infoRow:@"How long the SDK waits for your server's answer (at least 30 s). No answer by then gives \"status unknown\": the charge may still go through, so check the order on your server before the shopper pays again.\n\nTry it:\n• Slow server off: normal success or failure on Apple's sheet.\n• Slow server on, timeout above 40 s (e.g. 120): the sheet closes, then \"Your payment is still being processed. Please don't pay again.\", then success.\n• Slow server on, timeout below 40 s (e.g. 30): \"status unknown\" failure, while the charge may still go through."]]},
        @{@"title": @"Try in the checkout sheet",
          @"footer": @"Same configuration as the Apple Pay button below, passed to SpreedlyApplePayWallet in CardFormDropInViewController.",
          @"rows": @[[self openDropInRow:@"applePayConfigOpenDropIn"]]}
    ];
}

/// Success line with the token masked, or in full after the eye button is tapped.
- (void)refreshSuccessStatus {
    if (self.successToken == nil) {
        self.statusText = [self.successPrefix ?: @"Success." stringByAppendingString:self.successSuffix ?: @""];
        return;
    }
    NSString *token = self.tokenVisible ? self.successToken : [Spreedly maskedToken:self.successToken];
    self.statusText = [NSString stringWithFormat:@"%@ Token %@%@", self.successPrefix ?: @"Success.", token, self.successSuffix ?: @""];
}

- (void)toggleTokenVisibility {
    self.tokenVisible = !self.tokenVisible;
    [self refreshSuccessStatus];
    if ([self isDropInScreen]) {
        [self rebuild];
    } else {
        [self updateCheckoutFooter];
    }
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                    self.tokenVisible ? @"Token shown" : @"Token masked");
}

- (NSString *)displayAmount:(NSDecimalNumber *)amount {
    return [[self settings] displayAmount:amount];
}

/// Your own screen with just the Apple Pay button below it (in the footer). No card form.
- (NSArray<NSDictionary *> *)buttonOnlySections {
    ApplePayDemoSettings *settings = [self settings];
    __weak typeof(self) weakSelf = self;
    NSArray *modes = @[@{@"title": @"One-time", @"value": @(ApplePayDemoModeOneTime)},
                       @{@"title": @"Recurring", @"value": @(ApplePayDemoModeRecurring)}];
    BOOL recurring = self.buttonOnlyMode == ApplePayDemoModeRecurring;
    NSMutableArray *intervals = [NSMutableArray array];
    [[ApplePayDemoSettings intervalTitles] enumerateObjectsUsingBlock:^(NSString *title, NSUInteger index, BOOL *stop) {
        [intervals addObject:@{@"title": title, @"value": @(index)}];
    }];
    NSMutableArray *rows = [NSMutableArray arrayWithObject:
        [self choiceRow:@"Type" identifier:@"applePayButtonOnlyMode" options:modes
               selected:^NSInteger { return IndexOfValue(modes, @(weakSelf.buttonOnlyMode)); }
                 select:^(NSDictionary *option, NSInteger index) { weakSelf.buttonOnlyMode = [option[@"value"] integerValue]; }]];
    if (recurring) {
        [rows addObject:[self choiceRow:@"Every" identifier:@"applePayButtonOnlyInterval" options:intervals
                               selected:^NSInteger { return (NSInteger)settings.recurringInterval; }
                                 select:^(NSDictionary *option, NSInteger index) { settings.recurringInterval = index; }]];
    }
    NSString *amountTitle = recurring
        ? [NSString stringWithFormat:@"Amount per %@", @[@"day", @"week", @"month", @"year"][settings.recurringInterval]]
        : @"Amount";
    return @[@{@"title": @"Payment", @"rows": [rows arrayByAddingObject:
        [self textRow:amountTitle identifier:@"applePayButtonOnlyAmount"
             keyboard:UIKeyboardTypeDecimalPad
                  get:^NSString * { return recurring ? settings.recurringAmount : settings.oneTimeAmount; }
                  set:^(NSString *text) {
                      if (recurring) { settings.recurringAmount = text; } else { settings.oneTimeAmount = text; }
                  }]]}];
}

/// Which checkout the footer button runs on this screen.
- (ApplePayDemoMode)checkoutMode {
    switch (self.kind) {
        case ApplePaySettingsKindButtonOnly: return self.buttonOnlyMode;
        case ApplePaySettingsKindRecurring: return ApplePayDemoModeRecurring;
        default: return ApplePayDemoModeOneTime;
    }
}

/// Open Checkout Sheet and the last result.
- (NSArray<NSDictionary *> *)dropInSections {
    __weak typeof(self) weakSelf = self;
    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:[self openDropInRow:@"applePayDropInOpen"]];
    if (self.statusText) {
        ApplePaySettingRow *status = [self infoRow:self.statusText];
        status.showsActivity = self.statusIsPending;
        [rows addObject:status];
    }
    if (self.successToken != nil && !self.statusTextIsError) {
        ApplePaySettingRow *eye = [self rowOfType:ApplePaySettingRowTypeAction
                                            title:self.tokenVisible ? @"Hide token" : @"Show token"
                                       identifier:@"applePayDropInStatusToggleToken"];
        eye.symbolName = self.tokenVisible ? @"eye.slash" : @"eye";
        eye.detail = self.tokenVisible ? @"Masks the payment method token" : @"Shows the full payment method token";
        eye.setter = ^(id value) { [weakSelf toggleTokenVisibility]; };
        [rows addObject:eye];
    }
    return @[@{@"title": @"Checkout sheet",
               @"footer": @"Set walletButtons on CardFormDropInViewController. Apple Pay and the \"or pay with card\" divider appear above the card fields; both hide when Apple Pay is unavailable. To try what shoppers see when Wallet has no card, use Customize → Configure & Try.",
               @"rows": rows}];
}

/// Fills the terms field with text built from the amount, interval and trial.
- (ApplePaySettingRow *)suggestTermsRow {
    ApplePayDemoSettings *settings = [self settings];
    ApplePaySettingRow *row = [self rowOfType:ApplePaySettingRowTypeAction title:@"Use suggested terms"
                                   identifier:@"applePayRecurringAgreementSuggest"];
    row.symbolName = @"text.badge.plus";
    row.detail = @"Fills in terms from the amount, interval and trial above";
    row.setter = ^(id value) { settings.billingAgreement = [settings suggestedBillingTerms]; };
    return row;
}

- (NSArray<NSDictionary *> *)recurringSections {
    ApplePayDemoSettings *settings = [self settings];
    NSMutableArray *intervals = [NSMutableArray array];
    NSMutableArray *trialLengths = [NSMutableArray array];
    NSArray<NSString *> *units = @[@"day", @"week", @"month", @"year"];
    [[ApplePayDemoSettings intervalTitles] enumerateObjectsUsingBlock:^(NSString *title, NSUInteger index, BOOL *stop) {
        [intervals addObject:@{@"title": title, @"value": @(index)}];
        [trialLengths addObject:@{@"title": [@"1 " stringByAppendingString:units[index]], @"value": @(index)}];
    }];

    return @[
        @{@"title": @"Billing", @"rows": @[
            [self choiceRow:@"Interval" identifier:@"applePayRecurringIntervalPicker" options:intervals
                   selected:^NSInteger { return settings.recurringInterval; }
                     select:^(NSDictionary *option, NSInteger index) { settings.recurringInterval = index; }],
            [self textRow:@"Amount" identifier:@"applePayRecurringAmountField" keyboard:UIKeyboardTypeDecimalPad
                      get:^NSString * { return settings.recurringAmount; }
                      set:^(NSString *text) { settings.recurringAmount = text; }]]},
        @{@"title": @"Free trial", @"footer": @"Nothing is charged today; the first renewal starts when the trial ends.", @"rows": @[
            [self toggleRow:@"Free trial first" identifier:@"applePayRecurringTrialToggle"
                        get:^BOOL { return settings.freeTrial; }
                        set:^(BOOL on) { settings.freeTrial = on; }],
            [self choiceRow:@"Trial length" identifier:@"applePayRecurringTrialPicker" options:trialLengths
                   selected:^NSInteger { return settings.trialInterval; }
                     select:^(NSDictionary *option, NSInteger index) { settings.trialInterval = index; }]]},
        @{@"title": @"Subscription terms",
          @"footer": @"Shown on Apple's subscription sheet before the shopper pays. Optional.",
          @"rows": @[
            [self textRow:@"Terms" identifier:@"applePayRecurringAgreementField" keyboard:UIKeyboardTypeDefault
                      get:^NSString * { return settings.billingAgreement; }
                      set:^(NSString *text) { settings.billingAgreement = text; }],
            [self suggestTermsRow]]},
        @{@"title": @"Manage subscription link",
          @"footer": @"Required. A page on your site where the shopper manages the subscription: view it, change the plan or payment method, or cancel. Apple links to it from the sheet and from Wallet.\n\nRenewals need a merchant token. The result screen shows which token Apple issued; Apple's sandbox may only issue device tokens.",
          @"rows": @[
            [self textRow:@"Manage subscription link" identifier:@"applePayRecurringManagementURLField" keyboard:UIKeyboardTypeURL
                      get:^NSString * { return settings.managementURL; }
                      set:^(NSString *text) { settings.managementURL = text; }]]}
    ];
}

#pragma mark - Checkout footer

/// Configuration and Button Only use a USD 1.00 order with the current settings.
- (BOOL)hasCheckoutButton {
    return self.kind != ApplePaySettingsKindButton && ![self isDropInScreen];
}

/// Apple Pay button built from the current settings, rebuilt on every change so the sheet matches.
- (void)updateCheckoutFooter {
    ApplePayDemoSettings *settings = [self settings];
    ApplePayDemoMode mode = [self checkoutMode];
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, settings.buttonHeight + 110)];

    SpreedlyApplePayButtonView *button =
        [[SpreedlyApplePayButtonView alloc] initWithConfiguration:[settings configurationForMode:mode]
                                                            order:[settings orderForMode:mode]
                                                signedAuthHandler:^(void (^completion)(SpreedlyConfig * _Nullable, NSError * _Nullable)) {
            [[SpreedlyConfigManager shared] fetchSignedAuthWithCompletion:completion];
        }
                                            processPaymentHandler:^(ApplePayPaymentAuthorization *authorization,
                                                                    void (^completion)(ApplePayPaymentDecision *)) {
            [settings chargeAuthorization:authorization mode:mode completion:completion];
        }];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    BOOL isButtonOnly = self.kind == ApplePaySettingsKindButtonOnly;
    button.accessibilityIdentifier = isButtonOnly ? @"applePayButtonOnlyButton" : @"applePayConfigTryButton";
    [button setPrepareForPresentationHandler:^(void (^completion)(BOOL)) {
        // Signed auth for Apple Pay comes from signedAuthHandler; only set the SDK up if needed.
        if (Spreedly.isInitialized) {
            completion(YES);
            return;
        }
        [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
            completion(success);
        }];
    }];
    [footer addSubview:button];

    UILabel *note = [[UILabel alloc] init];
    note.text = self.statusText ?: [self checkoutHint];
    note.textColor = self.statusText == nil ? UIColor.secondaryLabelColor
        : (self.statusTextIsError ? UIColor.systemRedColor : UIColor.systemGreenColor);
    note.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    note.numberOfLines = 0;
    note.accessibilityIdentifier = isButtonOnly ? @"applePayButtonOnlyStatus" : @"applePayConfigStatus";
    note.translatesAutoresizingMaskIntoConstraints = NO;
    if (self.statusIsPending) {
        note.textColor = UIColor.secondaryLabelColor;
    }
    [footer addSubview:note];

    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.hidden = !self.statusIsPending;
    if (self.statusIsPending) {
        [spinner startAnimating];
    }
    [footer addSubview:spinner];

    [NSLayoutConstraint activateConstraints:@[
        [button.topAnchor constraintEqualToAnchor:footer.topAnchor constant:16],
        [button.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:20],
        [button.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-20],
        [button.heightAnchor constraintEqualToConstant:settings.buttonHeight],
        [note.topAnchor constraintEqualToAnchor:button.bottomAnchor constant:10],
        [spinner.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:20],
        [spinner.centerYAnchor constraintEqualToAnchor:note.firstBaselineAnchor constant:-4],
        [note.leadingAnchor constraintEqualToAnchor:(self.statusIsPending ? spinner.trailingAnchor : footer.leadingAnchor)
                                           constant:(self.statusIsPending ? 8 : 20)],
        [note.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-20]
    ]];

    if (self.successToken != nil && !self.statusTextIsError) {
        UIButton *eye = [UIButton buttonWithType:UIButtonTypeSystem];
        [eye setTitle:self.tokenVisible ? @" Hide token" : @" Show token" forState:UIControlStateNormal];
        [eye setImage:[UIImage systemImageNamed:self.tokenVisible ? @"eye.slash" : @"eye"] forState:UIControlStateNormal];
        eye.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        eye.accessibilityHint = self.tokenVisible ? @"Masks the payment method token" : @"Shows the full payment method token";
        eye.accessibilityIdentifier = isButtonOnly ? @"applePayButtonOnlyStatusToggleToken" : @"applePayConfigStatusToggleToken";
        [eye addTarget:self action:@selector(toggleTokenVisibility) forControlEvents:UIControlEventTouchUpInside];
        eye.translatesAutoresizingMaskIntoConstraints = NO;
        [footer addSubview:eye];
        [NSLayoutConstraint activateConstraints:@[
            [eye.topAnchor constraintEqualToAnchor:note.bottomAnchor constant:6],
            [eye.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:20],
            [eye.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-16]
        ]];
    } else {
        [note.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-16].active = YES;
    }
    [self sizeTableAccessory:footer toWidth:width];
    self.tableView.tableFooterView = footer;
}

/// Table header and footer views don't size themselves; fit the height to the content so long
/// text wraps instead of being clipped.
- (void)sizeTableAccessory:(UIView *)view toWidth:(CGFloat)width {
    CGSize fitted = [view systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                        withHorizontalFittingPriority:UILayoutPriorityRequired
                              verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    view.frame = CGRectMake(0, 0, width, fitted.height);
}

/// Text under the footer button until a result arrives.
- (NSString *)checkoutHint {
    switch (self.kind) {
        case ApplePaySettingsKindButtonOnly:
            return @"Place SpreedlyApplePayButtonView anywhere in your layout. Results arrive on paymentDelegate.";
        case ApplePaySettingsKindConfiguration:
            return [NSString stringWithFormat:@"Try this configuration: opens Apple's sheet for %@ with the networks, card types, contact fields, metadata and server timing above.",
                    [self displayAmount:[[self settings] chargeAmountForMode:ApplePayDemoModeOneTime]]];
        default:
            return @"";
    }
}

- (void)paymentDidComplete:(PaymentResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusIsPending = result.isPending;
        if (result.isPending) {
            self.statusText = @"Your payment is still being processed. Please don't pay again.";
            self.statusTextIsError = NO;
        } else if (result.isSuccess) {
            NSDecimalNumber *amount = [[self settings] chargeAmountForMode:[self checkoutMode]];
            self.successToken = result.token.length > 0 ? result.token : nil;
            // The drop-in's card fields only save the card; only an Apple Pay result was charged.
            NSDictionary *paymentMethod = result.paymentResponseDictionary[@"transaction"][@"paymentMethod"];
            BOOL isApplePay = [paymentMethod[@"paymentMethodType"] isEqual:@"apple_pay"];
            self.successPrefix = isApplePay
                ? [NSString stringWithFormat:@"Paid %@.", [self displayAmount:amount]]
                : @"Card saved.";
            self.successSuffix = (self.kind == ApplePaySettingsKindConfiguration && [self settings].includeMetadata)
                ? [NSString stringWithFormat:@" · order ID %@", [self settings].demoOrderId] : nil;
            self.tokenVisible = NO;
            [self refreshSuccessStatus];
            self.statusTextIsError = NO;
        } else if (result.isCanceled) {
            self.statusText = nil;
            self.successToken = nil;
        } else if (result.isStatusUnknown) {
            self.successToken = nil;
            self.statusText = @"Payment not confirmed. Check the order before paying again.";
            self.statusTextIsError = YES;
        } else if (result.isFailure) {
            self.successToken = nil;
            self.statusText = result.failureDetails.message ?: @"Payment failed";
            self.statusTextIsError = YES;
        }
        // Drop-in screens show the result as a row.
        if ([self isDropInScreen]) {
            [self rebuild];
        } else {
            [self updateCheckoutFooter];
        }
    });
}

#pragma mark - Preview

- (void)updatePreviewHeader {
    ApplePayDemoSettings *settings = [self settings];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), settings.buttonHeight + 88)];

    ApplePayConfiguration *configuration = [settings configurationForMode:ApplePayDemoModeOneTime];
    SpreedlyApplePayButtonView *button =
        [[SpreedlyApplePayButtonView alloc] initWithConfiguration:configuration
                                                            order:[settings orderForMode:ApplePayDemoModeOneTime]
                                                signedAuthHandler:^(void (^completion)(SpreedlyConfig * _Nullable, NSError * _Nullable)) {
            [[SpreedlyConfigManager shared] fetchSignedAuthWithCompletion:completion];
        }
                                            processPaymentHandler:^(ApplePayPaymentAuthorization *authorization,
                                                                    void (^completion)(ApplePayPaymentDecision *)) {
            [settings chargeAuthorization:authorization mode:ApplePayDemoModeOneTime completion:completion];
        }];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityIdentifier = @"applePayDesignerPreview";
    [button setPrepareForPresentationHandler:^(void (^completion)(BOOL)) {
        // Signed auth for Apple Pay comes from signedAuthHandler; only set the SDK up if needed.
        if (Spreedly.isInitialized) {
            completion(YES);
            return;
        }
        [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
            completion(success);
        }];
    }];
    [header addSubview:button];

    UILabel *note = [[UILabel alloc] init];
    note.text = @"Live preview. The SDK hides the button when Apple Pay is unavailable on this device.";
    note.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    note.textColor = UIColor.secondaryLabelColor;
    note.numberOfLines = 0;
    note.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:note];

    [NSLayoutConstraint activateConstraints:@[
        [button.topAnchor constraintEqualToAnchor:header.topAnchor constant:16],
        [button.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [button.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [button.heightAnchor constraintEqualToConstant:settings.buttonHeight],
        [note.topAnchor constraintEqualToAnchor:button.bottomAnchor constant:8],
        [note.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [note.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20]
    ]];
    self.tableView.tableHeaderView = header;
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.sections[section][@"footer"];
}

- (ApplePaySettingRow *)rowAtIndexPath:(NSIndexPath *)indexPath {
    return self.sections[indexPath.section][@"rows"][indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ApplePaySettingRow *row = [self rowAtIndexPath:indexPath];
    UITableViewCellStyle style = (row.type == ApplePaySettingRowTypeToggle && row.detail.length > 0)
        ? UITableViewCellStyleSubtitle : UITableViewCellStyleValue1;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:nil];
    cell.textLabel.text = row.title;
    if (style == UITableViewCellStyleSubtitle) {
        cell.detailTextLabel.text = row.detail;
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    }
    cell.textLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessibilityIdentifier = row.identifier;

    switch (row.type) {
        case ApplePaySettingRowTypeToggle: {
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = [row.getter() boolValue];
            toggle.enabled = row.isEnabled ? row.isEnabled() : YES;
            cell.textLabel.enabled = toggle.enabled;
            toggle.accessibilityIdentifier = row.identifier;
            toggle.tag = [self tagForIndexPath:indexPath];
            [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case ApplePaySettingRowTypeChoice: {
            NSInteger index = [row.getter() integerValue];
            cell.detailTextLabel.text = index >= 0 && index < (NSInteger)row.choices.count ? row.choices[index] : @"";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        }
        case ApplePaySettingRowTypeText: {
            UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 170, 32)];
            field.text = row.getter();
            field.placeholder = row.title;
            field.textAlignment = NSTextAlignmentRight;
            field.keyboardType = row.keyboardType;
            field.autocorrectionType = UITextAutocorrectionTypeNo;
            field.autocapitalizationType = UITextAutocapitalizationTypeNone;
            field.returnKeyType = UIReturnKeyDone;
            field.inputAccessoryView = [ApplePayDemoSettings keyboardToolbarEndingEditingIn:self.view];
            field.delegate = self;
            field.accessibilityIdentifier = row.identifier;
            field.tag = [self tagForIndexPath:indexPath];
            [field addTarget:self action:@selector(textChanged:) forControlEvents:UIControlEventEditingChanged];
            [field addTarget:self action:@selector(textEnded:) forControlEvents:UIControlEventEditingDidEnd];
            cell.accessoryView = field;
            break;
        }
        case ApplePaySettingRowTypeSlider: {
            float value = [row.getter() floatValue];
            cell.textLabel.text = [NSString stringWithFormat:@"%@: %.0f", row.title, value];
            UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 150, 32)];
            slider.minimumValue = row.minimum;
            slider.maximumValue = row.maximum;
            slider.value = value;
            slider.accessibilityIdentifier = row.identifier;
            slider.tag = [self tagForIndexPath:indexPath];
            [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
            [slider addTarget:self action:@selector(sliderEnded:)
             forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
            cell.accessoryView = slider;
            break;
        }
        case ApplePaySettingRowTypeInfo:
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
            if (row.showsActivity) {
                UIActivityIndicatorView *spinner =
                    [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
                [spinner startAnimating];
                cell.accessoryView = spinner;
            }
            break;
        case ApplePaySettingRowTypeAction: {
            UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
            font = [UIFont fontWithDescriptor:[font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:0];
            NSMutableAttributedString *title = [[NSMutableAttributedString alloc] init];
            UIImage *icon = [UIImage systemImageNamed:row.symbolName ?: @"creditcard"
                                    withConfiguration:[UIImageSymbolConfiguration configurationWithFont:font]];
            if (icon) {
                NSTextAttachment *attachment = [NSTextAttachment textAttachmentWithImage:
                                                [icon imageWithTintColor:self.view.tintColor renderingMode:UIImageRenderingModeAlwaysOriginal]];
                [title appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
                [title appendAttributedString:[[NSAttributedString alloc] initWithString:@"  "]];
            }
            [title appendAttributedString:[[NSAttributedString alloc] initWithString:row.title]];
            [title addAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: self.view.tintColor}
                           range:NSMakeRange(0, title.length)];
            cell.textLabel.attributedText = title;
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.adjustsFontForContentSizeCategory = YES;
            cell.accessibilityLabel = row.title;
            cell.accessibilityHint = row.detail;
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        }
        case ApplePaySettingRowTypeButtonSample: {
            PKPaymentButton *sample = [PKPaymentButton buttonWithType:[row.getter() integerValue]
                                                                style:[self settings].buttonStyle];
            sample.cornerRadius = [self settings].cornerRadius;
            sample.frame = CGRectMake(0, 0, 160, 34);
            sample.userInteractionEnabled = NO;
            cell.accessoryView = sample;
            cell.isAccessibilityElement = YES;
            cell.accessibilityLabel = [row.title stringByAppendingString:@" button sample"];
            break;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ApplePaySettingRow *row = [self rowAtIndexPath:indexPath];
    if (row.type == ApplePaySettingRowTypeAction) {
        row.setter(@YES);
        [self rebuild];
        return;
    }
    if (row.type != ApplePaySettingRowTypeChoice) { return; }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:row.title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    [row.choices enumerateObjectsUsingBlock:^(NSString *choice, NSUInteger index, BOOL *stop) {
        [sheet addAction:[UIAlertAction actionWithTitle:choice style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            row.setter(@(index));
            [weakSelf rebuild];
        }]];
    }];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    sheet.popoverPresentationController.sourceView = cell;
    sheet.popoverPresentationController.sourceRect = cell.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Control events

- (NSInteger)tagForIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section * 1000 + indexPath.row;
}

- (ApplePaySettingRow *)rowForTag:(NSInteger)tag {
    return [self rowAtIndexPath:[NSIndexPath indexPathForRow:tag % 1000 inSection:tag / 1000]];
}

- (void)toggleChanged:(UISwitch *)sender {
    [self rowForTag:sender.tag].setter(@(sender.isOn));
    [[self settings] clearPrefillsWithoutFields];
    [self rebuild];
}

- (void)textChanged:(UITextField *)sender {
    [self rowForTag:sender.tag].setter(sender.text ?: @"");
}

- (void)textEnded:(UITextField *)sender {
    // A full reload would steal focus from the next field, so refresh only the footer button.
    if ([self hasCheckoutButton]) { [self updateCheckoutFooter]; }
}

- (void)sliderChanged:(UISlider *)sender {
    ApplePaySettingRow *row = [self rowForTag:sender.tag];
    row.setter(@(sender.value));
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:
                             [NSIndexPath indexPathForRow:sender.tag % 1000 inSection:sender.tag / 1000]];
    cell.textLabel.text = [NSString stringWithFormat:@"%@: %.0f", row.title, [row.getter() floatValue]];
}

- (void)sliderEnded:(UISlider *)sender {
    [self rebuild];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end

#endif
