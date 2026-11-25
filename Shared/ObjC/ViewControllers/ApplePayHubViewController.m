//
//  ApplePayHubViewController.m
//  SpreedlySDKExampleObjectiveC
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if __has_include(<SpreedlyApplePay/SpreedlyApplePay-Swift.h>)

#import "ApplePayHubViewController.h"
#import "ApplePayDemoSettings.h"
#import "ApplePaySettingsViewController.h"
#import "SpreedlyConfigManager.h"
#import <SpreedlyApplePay/SpreedlyApplePay-Swift.h>

typedef NS_ENUM(NSInteger, ApplePayHubSection) {
    ApplePayHubSectionDevice = 0,
    ApplePayHubSectionTestCard,
    ApplePayHubSectionCheckout,
    ApplePayHubSectionCustomize,
    ApplePayHubSectionCount
};

typedef NS_ENUM(NSInteger, ApplePayHubTestCardRow) {
    ApplePayHubTestCardRowToggle = 0,
    ApplePayHubTestCardRowNumber,
    ApplePayHubTestCardRowProblem,
    ApplePayHubTestCardRowHint,
    ApplePayHubTestCardRowReset
};

@interface ApplePayHubViewController () <UITextFieldDelegate>
@property (nonatomic) ApplePayAvailability availability;
@end

@implementation ApplePayHubViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Apple Pay";
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [ApplePayDemoSettings installTapToDismissKeyboardIn:self.tableView];
    [self refreshAvailability];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshAvailability)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refreshAvailability {
    self.availability = [SpreedlyApplePayWallet availabilityWithNetworks:ApplePayConfiguration.defaultSupportedNetworks
                                                            capabilities:PKMerchantCapability3DS];
    [self.tableView reloadData];
}

- (NSString *)availabilityText {
    switch (self.availability) {
        case ApplePayAvailabilityReady: return @"Ready";
        case ApplePayAvailabilityNeedsSetup: return @"No card in Wallet";
        default: return @"Not supported";
    }
}

#pragma mark - Table view

/// Checkout rows: title, detail, accessibility ID, ApplePaySettingsKind.
- (NSArray<NSArray *> *)checkoutRows {
    return @[
        @[@"One-time Payment", @"Pay USD 1.00 from the checkout sheet, with Apple Pay above the card fields.", @"applePayHubOneTimeLink", @(ApplePaySettingsKindOneTime)],
        @[@"Button Only", @"Just the Apple Pay button on your own screen. No card form.", @"applePayHubButtonOnlyLink", @(ApplePaySettingsKindButtonOnly)],
        @[@"Recurring Payment", @"Subscription sheet with billing interval, free trial and merchant token.", @"applePayHubRecurringLink", @(ApplePaySettingsKindRecurring)]
    ];
}

/// Customize rows, same shape as `checkoutRows`.
- (NSArray<NSArray *> *)customizeRows {
    return @[
        @[@"Button & Theme", @"Button type, style, corner radius, height, empty-Wallet behavior, divider text.", @"applePayHubButtonLink", @(ApplePaySettingsKindButton)],
        @[@"Configure & Try", @"Networks, card types, contact fields, metadata, charge-first, timeout.", @"applePayHubConfigurationLink", @(ApplePaySettingsKindConfiguration)]
    ];
}

- (nullable NSArray<NSArray *> *)rowsForSection:(NSInteger)section {
    switch (section) {
        case ApplePayHubSectionCheckout: return [self checkoutRows];
        case ApplePayHubSectionCustomize: return [self customizeRows];
        default: return nil;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return ApplePayHubSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case ApplePayHubSectionDevice: {
            NSInteger rows = 1;
            if ([SpreedlyConfigManager shared].applePayMerchantIdConfigurationError.length > 0) { rows++; }
            if (self.availability == ApplePayAvailabilityNeedsSetup) { rows++; }
            return rows;
        }
        case ApplePayHubSectionTestCard:
            return (NSInteger)[self testCardRows].count;
        default: return (NSInteger)[self rowsForSection:section].count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case ApplePayHubSectionDevice: return @"This device";
        case ApplePayHubSectionTestCard: return @"Spreedly Test gateway";
        case ApplePayHubSectionCheckout: return @"Checkout";
        case ApplePayHubSectionCustomize: return @"Customize";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case ApplePayHubSectionTestCard:
            return @"Apple Pay can't produce test cards, so a Spreedly Test gateway declines every Apple Pay purchase unless a Spreedly test card number is sent with the token. Applies to every Apple Pay demo until the app quits. Turn it off to pay with the real card against a real gateway. Works in Xcode and TestFlight builds only.";
        case ApplePayHubSectionCustomize: return @"Try options here; they reset when you go back and do not change the checkouts above.";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;

    switch (indexPath.section) {
        case ApplePayHubSectionDevice:
            return [self deviceCellForRow:indexPath.row];
        case ApplePayHubSectionTestCard:
            return [self testCardCellForRow:[[self testCardRows][indexPath.row] integerValue]];
        default: {
            NSArray *row = [self rowsForSection:indexPath.section][indexPath.row];
            cell.textLabel.text = row[0];
            cell.detailTextLabel.text = row[1];
            cell.accessibilityIdentifier = row[2];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        }
    }
    return cell;
}

- (UITableViewCell *)deviceCellForRow:(NSInteger)row {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    NSString *configError = [SpreedlyConfigManager shared].applePayMerchantIdConfigurationError;
    if (row == 0) {
        cell.textLabel.text = @"Apple Pay";
        cell.detailTextLabel.text = [self availabilityText];
    } else if (row == 1 && configError.length > 0) {
        cell.textLabel.text = configError;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        cell.textLabel.textColor = UIColor.systemRedColor;
        cell.accessibilityIdentifier = @"applePayHubMerchantIdError";
    } else {
        SpreedlyApplePaySetUpButtonView *setUp = [[SpreedlyApplePaySetUpButtonView alloc] init];
        setUp.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:setUp];
        [NSLayoutConstraint activateConstraints:@[
            [setUp.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
            [setUp.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
            [setUp.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [setUp.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [setUp.heightAnchor constraintEqualToConstant:44]
        ]];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == ApplePayHubSectionTestCard) {
        if ([[self testCardRows][indexPath.row] integerValue] == ApplePayHubTestCardRowReset) {
            ApplePayDemoSettings.testCardNumber = ApplePayDemoSettings.defaultTestCardNumber;
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:ApplePayHubSectionTestCard]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        return;
    }
    NSArray<NSArray *> *rows = [self rowsForSection:indexPath.section];
    if (rows == nil) { return; }
    ApplePaySettingsKind kind = [rows[indexPath.row][3] integerValue];
    [self.navigationController pushViewController:[[ApplePaySettingsViewController alloc] initWithKind:kind] animated:YES];
}

#pragma mark - Spreedly Test gateway

/// Rows shown in the test card section, as ApplePayHubTestCardRow values.
- (NSArray<NSNumber *> *)testCardRows {
    if (!ApplePayDemoSettings.testCardEnabled) { return @[@(ApplePayHubTestCardRowToggle)]; }
    NSMutableArray *rows = [@[@(ApplePayHubTestCardRowToggle), @(ApplePayHubTestCardRowNumber)] mutableCopy];
    if (ApplePayDemoSettings.testCardNumberProblem != nil) {
        [rows addObject:@(ApplePayHubTestCardRowProblem)];
    }
    [rows addObject:@(ApplePayHubTestCardRowHint)];
    if (![ApplePayDemoSettings.testCardNumber isEqualToString:ApplePayDemoSettings.defaultTestCardNumber]) {
        [rows addObject:@(ApplePayHubTestCardRowReset)];
    }
    return rows;
}

- (UITableViewCell *)testCardCellForRow:(ApplePayHubTestCardRow)row {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.numberOfLines = 0;
    switch (row) {
        case ApplePayHubTestCardRowToggle: {
            cell.textLabel.text = @"Send Spreedly test card";
            UISwitch *toggle = [[UISwitch alloc] init];
            toggle.on = ApplePayDemoSettings.testCardEnabled;
            toggle.accessibilityIdentifier = @"applePayHubTestCardToggle";
            toggle.accessibilityHint = @"Sends a Spreedly test card number with the Apple Pay token in every demo";
            [toggle addTarget:self action:@selector(testCardToggleChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case ApplePayHubTestCardRowNumber: {
            cell.textLabel.text = @"Test card number";
            UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 190, 32)];
            field.text = ApplePayDemoSettings.testCardNumber;
            field.placeholder = ApplePayDemoSettings.defaultTestCardNumber;
            field.textAlignment = NSTextAlignmentRight;
            field.keyboardType = UIKeyboardTypeNumberPad;
            field.inputAccessoryView = [ApplePayDemoSettings keyboardToolbarEndingEditingIn:self.view];
            field.accessibilityIdentifier = @"applePayHubTestCardNumber";
            field.accessibilityLabel = @"Test card number";
            field.delegate = self;
            [field addTarget:self action:@selector(testCardNumberChanged:) forControlEvents:UIControlEventEditingChanged];
            [field addTarget:self action:@selector(testCardNumberEnded:) forControlEvents:UIControlEventEditingDidEnd];
            cell.accessoryView = field;
            break;
        }
        case ApplePayHubTestCardRowProblem: {
            cell.textLabel.text = ApplePayDemoSettings.testCardNumberProblem;
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
            cell.textLabel.textColor = UIColor.systemRedColor;
            UIImageSymbolConfiguration *symbol =
                [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleFootnote];
            cell.imageView.image = [UIImage systemImageNamed:@"exclamationmark.triangle" withConfiguration:symbol];
            cell.imageView.tintColor = UIColor.systemRedColor;
            cell.accessibilityIdentifier = @"applePayHubTestCardProblem";
            break;
        }
        case ApplePayHubTestCardRowHint:
            cell.textLabel.text = @"4111 1111 1111 1111 succeeds; 4012 8888 8888 1881 is declined. Any number on Spreedly's test card list works.";
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
            cell.textLabel.textColor = UIColor.secondaryLabelColor;
            break;
        case ApplePayHubTestCardRowReset:
            cell.textLabel.text = [@"Reset to " stringByAppendingString:ApplePayDemoSettings.defaultTestCardNumber];
            cell.textLabel.textColor = self.view.tintColor;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessibilityTraits = UIAccessibilityTraitButton;
            cell.accessibilityIdentifier = @"applePayHubTestCardReset";
            break;
    }
    return cell;
}

- (void)testCardToggleChanged:(UISwitch *)sender {
    ApplePayDemoSettings.testCardEnabled = sender.isOn;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:ApplePayHubSectionTestCard]
                  withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)testCardNumberChanged:(UITextField *)sender {
    ApplePayDemoSettings.testCardNumber = sender.text ?: @"";
}

- (void)testCardNumberEnded:(UITextField *)sender {
    // Show or hide the problem and reset rows once editing finishes; reloading while typing would drop focus.
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:ApplePayHubSectionTestCard]
                  withRowAnimation:UITableViewRowAnimationNone];
}

@end

#endif
