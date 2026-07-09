//
//  BankAccountCheckoutViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  Demonstrates the ObjC bridge for `BankAccountFormDropInViewController`.
//  Mirrors the structure of `CheckoutBasicViewController` but stripped down to
//  the essentials — toggles for the optional fields, a "Show Form" button, a
//  success/error display, and `SpreedlyPaymentDelegate` wiring.
//

#import "BankAccountCheckoutViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <objc/runtime.h>
#import "SpreedlyConfigManager.h"
#import "ThemeHelper.h"

@interface BankAccountCheckoutViewController () <SpreedlyPaymentDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UILabel *nameDisplayLabel;
@property (nonatomic, strong) UISegmentedControl *nameDisplayModeControl;
@property (nonatomic, strong) UISwitch *showBankNameSwitch;
@property (nonatomic, strong) UISwitch *showAccountTypeSwitch;
@property (nonatomic, strong) UISwitch *showAccountHolderTypeSwitch;
@property (nonatomic, strong) UIButton *showFormButton;
@property (nonatomic, strong) UILabel *resultLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@property (nonatomic, assign) BOOL isLoading;

@end

@implementation BankAccountCheckoutViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"ACH Bank Account Drop-In";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self setupUI];
    [self setupConstraints];

    [Spreedly.shared setPaymentDelegate:self];
}

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"ACH Bank Account Drop-In";
    self.titleLabel.font = [ThemeHelper screenTitleFont];
    self.titleLabel.textColor = [ThemeHelper textColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.accessibilityIdentifier = @"bankAccountCheckoutTitle";
    self.titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.contentView addSubview:self.titleLabel];

    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = @"Preview only — ACH bank-account flows are in the SDK for internal testing and will not ship in 1.4.1. Do not integrate ACH in production. BankAccountFormDropInViewController collects routing and account numbers (with ABA validation), name, and optional bank name + account type via a UIKit-friendly UIHostingController wrapper.";
    self.descriptionLabel.font = [ThemeHelper screenBodyFont];
    self.descriptionLabel.textColor = [ThemeHelper textColor];
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.descriptionLabel];

    self.nameDisplayLabel = [[UILabel alloc] init];
    self.nameDisplayLabel.text = @"Name display:";
    self.nameDisplayLabel.font = [ThemeHelper screenBodyFont];
    self.nameDisplayLabel.textColor = [ThemeHelper textColor];
    self.nameDisplayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.nameDisplayLabel];

    self.nameDisplayModeControl = [[UISegmentedControl alloc] initWithItems:@[@"Full Name", @"Separate"]];
    self.nameDisplayModeControl.selectedSegmentIndex = 0;
    self.nameDisplayModeControl.accessibilityIdentifier = @"bankAccountNameDisplayModePicker";
    self.nameDisplayModeControl.accessibilityLabel = @"Name display mode";
    self.nameDisplayModeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.nameDisplayModeControl];

    self.showBankNameSwitch = [self addToggleWithText:@"Show bank name field"
                                              identifier:@"bankAccountShowBankNameToggle"];
    self.showAccountTypeSwitch = [self addToggleWithText:@"Show account type (checking/savings)"
                                             identifier:@"bankAccountShowAccountTypeToggle"];
    self.showAccountTypeSwitch.on = YES;
    self.showAccountHolderTypeSwitch = [self addToggleWithText:@"Show holder type (personal/business)"
                                                   identifier:@"bankAccountShowHolderTypeToggle"];
    self.showAccountHolderTypeSwitch.on = YES;

    self.showFormButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.showFormButton setTitle:@"Show Bank Account Form" forState:UIControlStateNormal];
    self.showFormButton.titleLabel.font = [ThemeHelper buttonFont];
    self.showFormButton.backgroundColor = [ThemeHelper primaryColor];
    [self.showFormButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.showFormButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.showFormButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.showFormButton.accessibilityIdentifier = @"bankAccountShowFormButton";
    [self.showFormButton addTarget:self action:@selector(showFormButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.showFormButton];

    self.resultLabel = [[UILabel alloc] init];
    self.resultLabel.font = [ThemeHelper bodyFont];
    self.resultLabel.textColor = [ThemeHelper successColor];
    self.resultLabel.numberOfLines = 0;
    self.resultLabel.hidden = YES;
    self.resultLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultLabel.accessibilityIdentifier = @"bankAccountResultLabel";
    [self.contentView addSubview:self.resultLabel];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.font = [ThemeHelper bodyFont];
    self.errorLabel.textColor = [ThemeHelper errorColor];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.accessibilityIdentifier = @"bankAccountErrorLabel";
    [self.contentView addSubview:self.errorLabel];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
}

- (UISwitch *)addToggleWithText:(NSString *)text identifier:(NSString *)identifier {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [ThemeHelper screenBodyFont];
    label.textColor = [ThemeHelper textColor];
    label.numberOfLines = 0;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:label];

    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.onTintColor = [ThemeHelper primaryColor];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.accessibilityIdentifier = identifier;
    [self.contentView addSubview:toggle];

    objc_setAssociatedObject(toggle, "label", label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return toggle;
}

- (void)setupConstraints {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:[ThemeHelper spacingLG]],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];

    [self installToggleConstraintsAfterAnchor:self.descriptionLabel.bottomAnchor];
}

- (void)installToggleConstraintsAfterAnchor:(NSLayoutAnchor<NSLayoutYAxisAnchor *> *)anchor {
    NSArray<UISwitch *> *toggles = @[self.showBankNameSwitch, self.showAccountTypeSwitch, self.showAccountHolderTypeSwitch];

    [self.nameDisplayLabel.topAnchor constraintEqualToAnchor:anchor constant:[ThemeHelper spacingLG]].active = YES;
    [self.nameDisplayLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]].active = YES;
    [self.nameDisplayLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]].active = YES;

    [self.nameDisplayModeControl.topAnchor constraintEqualToAnchor:self.nameDisplayLabel.bottomAnchor constant:[ThemeHelper spacingSM]].active = YES;
    [self.nameDisplayModeControl.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]].active = YES;
    [self.nameDisplayModeControl.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]].active = YES;

    NSLayoutAnchor<NSLayoutYAxisAnchor *> *prev = self.nameDisplayModeControl.bottomAnchor;

    for (UISwitch *toggle in toggles) {
        UILabel *label = objc_getAssociatedObject(toggle, "label");
        [label.topAnchor constraintEqualToAnchor:prev constant:[ThemeHelper spacingMD]].active = YES;
        [label.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]].active = YES;
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-[ThemeHelper spacingSM]].active = YES;

        [toggle.centerYAnchor constraintEqualToAnchor:label.centerYAnchor].active = YES;
        [toggle.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]].active = YES;

        prev = label.bottomAnchor;
    }

    [self.showFormButton.topAnchor constraintEqualToAnchor:prev constant:[ThemeHelper spacingLG]].active = YES;
    [self.showFormButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]].active = YES;
    [self.showFormButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]].active = YES;
    [self.showFormButton.heightAnchor constraintEqualToConstant:44].active = YES;

    [self.resultLabel.topAnchor constraintEqualToAnchor:self.showFormButton.bottomAnchor constant:[ThemeHelper spacingMD]].active = YES;
    [self.resultLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]].active = YES;
    [self.resultLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]].active = YES;

    [self.errorLabel.topAnchor constraintEqualToAnchor:self.resultLabel.bottomAnchor constant:[ThemeHelper spacingSM]].active = YES;
    [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]].active = YES;
    [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]].active = YES;
    [self.errorLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]].active = YES;
}

#pragma mark - Actions

- (void)showFormButtonTapped {
    self.isLoading = YES;
    [self.loadingIndicator startAnimating];
    self.showFormButton.enabled = NO;

    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            [self.loadingIndicator stopAnimating];
            self.showFormButton.enabled = YES;

            if (success) {
                [self presentBankAccountForm];
            } else {
                self.errorLabel.text = error.localizedDescription ?: @"Signature generation failed";
                self.errorLabel.hidden = NO;
                self.resultLabel.hidden = YES;
            }
        });
    }];
}

- (void)presentBankAccountForm {
    BankAccountFieldConfig *config =
        [[BankAccountFieldConfig alloc] initWithNameDisplayMode:(self.nameDisplayModeControl.selectedSegmentIndex == 0
                                                                  ? DropInNameDisplayModeSingleField
                                                                  : DropInNameDisplayModeSeparateFields)
                                                  showBankName:self.showBankNameSwitch.isOn
                                                 bankNameLabel:nil
                                              bankNameRequired:NO
                                               showAccountType:self.showAccountTypeSwitch.isOn
                                              accountTypeLabel:nil
                                         showAccountHolderType:self.showAccountHolderTypeSwitch.isOn
                                        accountHolderTypeLabel:nil];

    BankAccountFormDropInViewController *dropInVC = [[BankAccountFormDropInViewController alloc]
        initWithFieldConfig:config
         onProcessingResult:^(PaymentProcessingResult *processingResult) {
            if (processingResult.isProcessing) {
                self.isLoading = YES;
                [self.loadingIndicator startAnimating];
                self.showFormButton.enabled = NO;
            } else if (processingResult.isValidationFailed) {
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                self.showFormButton.enabled = YES;
                self.errorLabel.text = [NSString stringWithFormat:@"Validation failed: %@", [processingResult getDescription]];
                self.errorLabel.hidden = NO;
            }
        }];

    UIViewController *secureVC = [dropInVC wrapInSecureViewControllerWithPlaceholderText:@""];
    [self presentViewController:secureVC animated:YES completion:nil];
}

#pragma mark - SpreedlyPaymentDelegate

- (void)paymentDidComplete:(PaymentResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.presentedViewController) {
            [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        }
        if (result.isSuccess) {
            NSString *masked = result.token ? [Spreedly maskedToken:result.token] : @"<no token>";
            self.resultLabel.text = [NSString stringWithFormat:@"Bank account tokenized. Token: %@", masked];
            self.resultLabel.hidden = NO;
            self.errorLabel.hidden = YES;
        } else if (result.isFailure) {
            NSString *errorMessage = @"Payment failed";
            if (result.failureDetails) {
                errorMessage = [result.failureDetails getDescription];
            }
            self.errorLabel.text = errorMessage;
            self.errorLabel.hidden = NO;
            self.resultLabel.hidden = YES;
        }
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [Spreedly.shared setPaymentDelegate:nil];
    [[Spreedly shared] reset];
}

@end
