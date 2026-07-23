//
//  BankAccountCustomFormViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  ObjC parity for the Swift `BankAccountCustomFormView`; uses
//  `SPLTextFieldViewController` for hosted-field input.
//

#import "BankAccountCustomFormViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <objc/runtime.h>
#import "SpreedlyConfigManager.h"
#import "ThemeHelper.h"

static const NSInteger kACHCustomSwatchUnset = -1;
static const NSUInteger kACHCustomPrimaryCount = 6;
static const NSUInteger kACHCustomFieldCount = 6;

NS_INLINE UIColor *ACHCustomRGB(unsigned r, unsigned g, unsigned b) {
    return [UIColor colorWithRed:(CGFloat)r / 255.0 green:(CGFloat)g / 255.0 blue:(CGFloat)b / 255.0 alpha:1.0];
}

static void ACHCustomPrimaryPair(NSUInteger index, UIColor *__autoreleasing *light, UIColor *__autoreleasing *dark) {
    switch (index) {
        case 0: *light = ACHCustomRGB(0x19, 0x76, 0xD2); *dark = ACHCustomRGB(0x64, 0xB5, 0xF6); break;
        case 1: *light = ACHCustomRGB(0x38, 0x8E, 0x3C); *dark = ACHCustomRGB(0x81, 0xC7, 0x84); break;
        case 2: *light = ACHCustomRGB(0x7B, 0x1F, 0xA2); *dark = ACHCustomRGB(0xBA, 0x68, 0xC8); break;
        case 3: *light = ACHCustomRGB(0xD3, 0x2F, 0x2F); *dark = ACHCustomRGB(0xE5, 0x73, 0x73); break;
        case 4: *light = ACHCustomRGB(0x00, 0x89, 0x7B); *dark = ACHCustomRGB(0x4D, 0xB6, 0xAC); break;
        case 5: *light = ACHCustomRGB(0xE6, 0x4A, 0x19); *dark = ACHCustomRGB(0xFF, 0x8A, 0x65); break;
        default: *light = ACHCustomRGB(0x19, 0x76, 0xD2); *dark = ACHCustomRGB(0x64, 0xB5, 0xF6); break;
    }
}

static void ACHCustomFieldPair(NSUInteger index, UIColor *__autoreleasing *light, UIColor *__autoreleasing *dark) {
    switch (index) {
        case 0: *light = [UIColor whiteColor]; *dark = ACHCustomRGB(0x1C, 0x1C, 0x1E); break;
        case 1: *light = ACHCustomRGB(0xF5, 0xF5, 0xF5); *dark = ACHCustomRGB(0x2C, 0x2C, 0x2C); break;
        case 2: *light = ACHCustomRGB(0xE8, 0xF5, 0xE9); *dark = ACHCustomRGB(0x1B, 0x3A, 0x2A); break;
        case 3: *light = ACHCustomRGB(0xE3, 0xF2, 0xFD); *dark = ACHCustomRGB(0x1A, 0x2C, 0x3D); break;
        case 4: *light = ACHCustomRGB(0xFF, 0xF3, 0xE0); *dark = ACHCustomRGB(0x3D, 0x2E, 0x1A); break;
        case 5: *light = ACHCustomRGB(0xF3, 0xE5, 0xF5); *dark = ACHCustomRGB(0x2E, 0x1A, 0x3D); break;
        default: *light = [UIColor whiteColor]; *dark = ACHCustomRGB(0x1C, 0x1C, 0x1E); break;
    }
}

static NSString *ACHCustomPrimaryLabel(NSUInteger index) {
    NSArray<NSString *> *labels = @[@"Blue", @"Green", @"Purple", @"Red", @"Teal", @"Orange"];
    return (index < labels.count) ? labels[index] : @"";
}

static NSString *ACHCustomFieldLabel(NSUInteger index) {
    NSArray<NSString *> *labels = @[@"Default", @"Gray", @"Pale green", @"Pale blue", @"Pale cream", @"Pale purple"];
    return (index < labels.count) ? labels[index] : @"";
}

typedef NS_ENUM(NSInteger, BankAccountNameDisplayMode) {
    BankAccountNameDisplayModeFullName = 0,
    BankAccountNameDisplayModeSeparate = 1
};

@interface BankAccountCustomFormViewController () <SpreedlyPaymentDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIView *componentsContainer;
@property (nonatomic, strong) UIView *configContainer;
@property (nonatomic, strong) UIView *themeContainer;
@property (nonatomic, strong) UISwitch *useCustomThemeSwitch;
@property (nonatomic, strong) UILabel *currentAccentLabel;
@property (nonatomic, strong) UILabel *currentAccentValueLabel;
@property (nonatomic, strong) UIView *themeCustomizerContainer;
@property (nonatomic, strong) UILabel *uiCustomizationTitleLabel;
@property (nonatomic, strong) UILabel *primarySectionLabel;
@property (nonatomic, strong) UIStackView *primarySwatchStack;
@property (nonatomic, strong) NSMutableArray<UIButton *> *primarySwatchButtons;
@property (nonatomic, strong) UILabel *fieldBackgroundSectionLabel;
@property (nonatomic, strong) UIStackView *fieldBackgroundSwatchStack;
@property (nonatomic, strong) NSMutableArray<UIButton *> *fieldBackgroundSwatchButtons;
@property (nonatomic, strong) UILabel *borderRadiusSectionLabel;
@property (nonatomic, strong) UILabel *borderRadiusValueLabel;
@property (nonatomic, strong) UISlider *cornerRadiusSlider;
@property (nonatomic, strong) UIButton *resetThemeButton;
@property (nonatomic, strong) UIView *formContainer;
@property (nonatomic, strong) UIButton *payButton;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@property (nonatomic, strong, nullable) SPLTextFieldViewController *fullNameField;
@property (nonatomic, strong, nullable) SPLTextFieldViewController *firstNameField;
@property (nonatomic, strong, nullable) SPLTextFieldViewController *lastNameField;
@property (nonatomic, strong) SPLTextFieldViewController *routingNumberField;
@property (nonatomic, strong) SPLTextFieldViewController *accountNumberField;

@property (nonatomic, strong) UISegmentedControl *nameDisplayModeControl;
@property (nonatomic, strong) UISwitch *showBankNameSwitch;
@property (nonatomic, strong) UISwitch *showAccountTypeSwitch;
@property (nonatomic, strong) UISwitch *showAccountHolderTypeSwitch;
@property (nonatomic, strong) UISegmentedControl *accountTypeControl;
@property (nonatomic, strong) UISegmentedControl *holderTypeControl;
@property (nonatomic, strong) UILabel *personalInfoLabel;
@property (nonatomic, strong) UILabel *accountTypeFormLabel;
@property (nonatomic, strong) UILabel *holderTypeFormLabel;
@property (nonatomic, strong, nullable) SPLTextFieldViewController *bankNameField;

@property (nonatomic, assign) BankAccountNameDisplayMode nameDisplayMode;
@property (nonatomic, assign) BOOL showBankName;
@property (nonatomic, assign) BOOL showAccountType;
@property (nonatomic, assign) BOOL showAccountHolderType;
@property (nonatomic, assign) BOOL isLoading;

@property (nonatomic, assign) BOOL fullNameIsValid;
@property (nonatomic, assign) BOOL firstNameIsValid;
@property (nonatomic, assign) BOOL lastNameIsValid;
@property (nonatomic, assign) BOOL bankNameIsValid;
@property (nonatomic, assign) BOOL routingNumberIsValid;
@property (nonatomic, assign) BOOL accountNumberIsValid;

@property (nonatomic, strong, nullable) PaymentResult *paymentResult;
@property (nonatomic, copy, nullable) NSString *errorMessage;

@property (nonatomic, assign) BOOL useCustomTheme;
@property (nonatomic, assign) NSInteger selectedPrimarySwatchID;
@property (nonatomic, assign) NSInteger selectedFieldBackgroundSwatchID;
@property (nonatomic, assign) CGFloat formCornerRadius;
@property (nonatomic, strong, nullable) SPLThemeConfig *lightThemeConfig;
@property (nonatomic, strong, nullable) SPLThemeConfig *darkThemeConfig;

@end

@implementation BankAccountCustomFormViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"ACH Bank Account – Custom Form";
    self.view.backgroundColor = [ThemeHelper surfaceColor];

    self.nameDisplayMode = BankAccountNameDisplayModeFullName;
    self.showBankName = NO;
    self.showAccountType = YES;
    self.showAccountHolderType = YES;
    self.bankNameIsValid = YES;
    self.useCustomTheme = NO;
    self.selectedPrimarySwatchID = kACHCustomSwatchUnset;
    self.selectedFieldBackgroundSwatchID = kACHCustomSwatchUnset;
    self.formCornerRadius = 8.0;

    [self setupUI];
    [self setupConstraints];

    [Spreedly.shared setPaymentDelegate:self];

    if (![Spreedly isDeviceTrusted]) {
        self.errorMessage = Spreedly.initializationError.message ?: @"SDK blocked by security check";
        [self updateUI];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self detachField:self.fullNameField];
    [self detachField:self.firstNameField];
    [self detachField:self.lastNameField];
    [self detachField:self.bankNameField];
    [self detachField:self.routingNumberField];
    [self detachField:self.accountNumberField];
    self.fullNameField = nil;
    self.firstNameField = nil;
    self.lastNameField = nil;
    self.bankNameField = nil;
}

- (void)detachField:(SPLTextFieldViewController *)field {
    if (!field) { return; }
    [field willMoveToParentViewController:nil];
    [field.view removeFromSuperview];
    [field removeFromParentViewController];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.accessibilityIdentifier = @"bank-account-custom-form-scroll-view";
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"ACH Bank Account";
    self.titleLabel.font = [ThemeHelper screenTitleFont];
    self.titleLabel.textColor = [ThemeHelper textColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.accessibilityIdentifier = @"bank-account-custom-form-title";
    self.titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.contentView addSubview:self.titleLabel];

    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = @"Tokenize bank account details via ACH";
    self.descriptionLabel.font = [ThemeHelper screenBodyFont];
    self.descriptionLabel.textColor = [ThemeHelper textColor];
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionLabel.accessibilityIdentifier = @"bank-account-custom-form-description";
    [self.contentView addSubview:self.descriptionLabel];

    self.componentsContainer = [self createInfoContainerWithTitle:@"Form components:"
                                                            items:@[
        @"• Account holder name",
        @"• Routing number",
        @"• Account number",
        @"• Bank name (optional)"
    ]];

    self.configContainer = [self createConfigContainer];
    self.themeContainer = [self createThemeContainer];
    self.formContainer = [self createFormContainer];

    self.payButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
    self.payButton.titleLabel.font = [ThemeHelper buttonFont];
    self.payButton.backgroundColor = [ThemeHelper primaryColor];
    [self.payButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.payButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.payButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.payButton.accessibilityIdentifier = @"bank-account-custom-form-pay-button";
    [self.payButton addTarget:self action:@selector(payButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.payButton];

    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.hidden = YES;
    self.resultContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultContainer.accessibilityIdentifier = @"bank-account-custom-form-result-container";
    [self.contentView addSubview:self.resultContainer];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.font = [ThemeHelper bodyFont];
    self.errorLabel.textColor = [ThemeHelper errorColor];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.accessibilityIdentifier = @"bank-account-custom-form-error-message";
    [self.contentView addSubview:self.errorLabel];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.color = [ThemeHelper textColor];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];

    [self updatePayButtonState];
}

- (UIView *)createInfoContainerWithTitle:(NSString *)title items:(NSArray<NSString *> *)items {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = [ThemeHelper spacingXS];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];

    for (NSString *item in items) {
        UILabel *label = [[UILabel alloc] init];
        label.text = item;
        label.font = [ThemeHelper screenBodyFont];
        label.textColor = [ThemeHelper textColor];
        label.numberOfLines = 0;
        [stack addArrangedSubview:label];
    }

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [stack.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    return container;
}

- (UIView *)createConfigContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Configuration:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = @"Name display:";
    nameLabel.font = [ThemeHelper screenBodyFont];
    nameLabel.textColor = [ThemeHelper textColor];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:nameLabel];

    self.nameDisplayModeControl = [[UISegmentedControl alloc] initWithItems:@[@"Full Name", @"Separate"]];
    self.nameDisplayModeControl.selectedSegmentIndex = (NSInteger)self.nameDisplayMode;
    self.nameDisplayModeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameDisplayModeControl.accessibilityIdentifier = @"bank-account-custom-form-name-display-mode-picker";
    [self.nameDisplayModeControl addTarget:self action:@selector(nameDisplayModeChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.nameDisplayModeControl];

    UILabel *bankNameLabel = [[UILabel alloc] init];
    bankNameLabel.text = @"Show bank name field";
    bankNameLabel.font = [ThemeHelper screenBodyFont];
    bankNameLabel.textColor = [ThemeHelper textColor];
    bankNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:bankNameLabel];

    self.showBankNameSwitch = [[UISwitch alloc] init];
    self.showBankNameSwitch.onTintColor = [ThemeHelper primaryColor];
    self.showBankNameSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.showBankNameSwitch.accessibilityIdentifier = @"bank-account-custom-form-show-bank-name-toggle";
    [self.showBankNameSwitch addTarget:self action:@selector(toggleShowBankName:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.showBankNameSwitch];

    UILabel *accountTypeToggleLabel = [[UILabel alloc] init];
    accountTypeToggleLabel.text = @"Show account type";
    accountTypeToggleLabel.font = [ThemeHelper screenBodyFont];
    accountTypeToggleLabel.textColor = [ThemeHelper textColor];
    accountTypeToggleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:accountTypeToggleLabel];

    self.showAccountTypeSwitch = [[UISwitch alloc] init];
    self.showAccountTypeSwitch.on = self.showAccountType;
    self.showAccountTypeSwitch.onTintColor = [ThemeHelper primaryColor];
    self.showAccountTypeSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.showAccountTypeSwitch addTarget:self action:@selector(toggleShowAccountType:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.showAccountTypeSwitch];

    UILabel *holderTypeToggleLabel = [[UILabel alloc] init];
    holderTypeToggleLabel.text = @"Show holder type";
    holderTypeToggleLabel.font = [ThemeHelper screenBodyFont];
    holderTypeToggleLabel.textColor = [ThemeHelper textColor];
    holderTypeToggleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:holderTypeToggleLabel];

    self.showAccountHolderTypeSwitch = [[UISwitch alloc] init];
    self.showAccountHolderTypeSwitch.on = self.showAccountHolderType;
    self.showAccountHolderTypeSwitch.onTintColor = [ThemeHelper primaryColor];
    self.showAccountHolderTypeSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self.showAccountHolderTypeSwitch addTarget:self action:@selector(toggleShowAccountHolderType:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.showAccountHolderTypeSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [nameLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [nameLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],

        [self.nameDisplayModeControl.centerYAnchor constraintEqualToAnchor:nameLabel.centerYAnchor],
        [self.nameDisplayModeControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.nameDisplayModeControl.widthAnchor constraintEqualToConstant:200],

        [bankNameLabel.topAnchor constraintEqualToAnchor:self.nameDisplayModeControl.bottomAnchor constant:[ThemeHelper spacingMD]],
        [bankNameLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.showBankNameSwitch.centerYAnchor constraintEqualToAnchor:bankNameLabel.centerYAnchor],
        [self.showBankNameSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [accountTypeToggleLabel.topAnchor constraintEqualToAnchor:bankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [accountTypeToggleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.showAccountTypeSwitch.centerYAnchor constraintEqualToAnchor:accountTypeToggleLabel.centerYAnchor],
        [self.showAccountTypeSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [holderTypeToggleLabel.topAnchor constraintEqualToAnchor:accountTypeToggleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [holderTypeToggleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.showAccountHolderTypeSwitch.centerYAnchor constraintEqualToAnchor:holderTypeToggleLabel.centerYAnchor],
        [self.showAccountHolderTypeSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [holderTypeToggleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];

    return container;
}

- (UIView *)createFormContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    self.formContainer = container;

    [self attachRoutingAndAccountFields];
    [self setupFormTypePickers];
    [self attachNameFieldsForCurrentMode];
    [self attachBankNameFieldVisible:self.showBankName];
    [self updateFormTypePickersVisibility];
    [self relayoutFormFields];

    return container;
}

#pragma mark - Form Fields

- (void)attachNameFieldsForCurrentMode {
    [self detachField:self.fullNameField];
    [self detachField:self.firstNameField];
    [self detachField:self.lastNameField];
    self.fullNameField = nil;
    self.firstNameField = nil;
    self.lastNameField = nil;

    if (self.nameDisplayMode == BankAccountNameDisplayModeFullName) {
        self.fullNameField = [self makeFieldWithType:FormFieldTypeFullName
                                               title:@"Account Holder Name"
                                          isRequired:YES
                                        keyboardType:UIKeyboardTypeDefault
                                     textContentType:UITextContentTypeName
                                     requiredMessage:[self nameRequiredMessage]
                                          identifier:@"bank-account-custom-form-full-name-field"
                                  onValidationChange:^(BOOL valid) {
            self.fullNameIsValid = valid;
            [self updatePayButtonState];
        }
                                            onSubmit:^{
            if (self.showBankName && self.bankNameField) {
                (void)[self.bankNameField becomeFirstResponder];
            } else {
                (void)[self.routingNumberField becomeFirstResponder];
            }
        }
                                         submitLabel:SpreedlySubmitLabelNext];
    } else {
        self.firstNameField = [self makeFieldWithType:FormFieldTypeFirstName
                                                title:@"First Name"
                                           isRequired:YES
                                         keyboardType:UIKeyboardTypeDefault
                                      textContentType:UITextContentTypeGivenName
                                      requiredMessage:[self nameRequiredMessage]
                                           identifier:@"bank-account-custom-form-first-name-field"
                                   onValidationChange:^(BOOL valid) {
            self.firstNameIsValid = valid;
            [self updatePayButtonState];
        }
                                             onSubmit:^{
            (void)[self.lastNameField becomeFirstResponder];
        }
                                          submitLabel:SpreedlySubmitLabelNext];

        self.lastNameField = [self makeFieldWithType:FormFieldTypeLastName
                                               title:@"Last Name"
                                          isRequired:YES
                                        keyboardType:UIKeyboardTypeDefault
                                     textContentType:UITextContentTypeFamilyName
                                     requiredMessage:[self nameRequiredMessage]
                                          identifier:@"bank-account-custom-form-last-name-field"
                                  onValidationChange:^(BOOL valid) {
            self.lastNameIsValid = valid;
            [self updatePayButtonState];
        }
                                            onSubmit:^{
            if (self.showBankName && self.bankNameField) {
                (void)[self.bankNameField becomeFirstResponder];
            } else {
                (void)[self.routingNumberField becomeFirstResponder];
            }
        }
                                         submitLabel:SpreedlySubmitLabelNext];
    }
}

- (NSString *)nameRequiredMessage {
    // Matches the SDK's `bank_account_holder_name_required` string for parity
    // with the drop-in flow and the Android SDK.
    return @"Name is required";
}

- (void)attachRoutingAndAccountFields {
    if (self.routingNumberField) {
        [self detachField:self.routingNumberField];
        self.routingNumberField = nil;
    }
    if (self.accountNumberField) {
        [self detachField:self.accountNumberField];
        self.accountNumberField = nil;
    }

    self.routingNumberField = [self makeFieldWithType:FormFieldTypeRoutingNumber
                                                 title:@"Routing Number"
                                            isRequired:YES
                                          keyboardType:UIKeyboardTypeNumberPad
                                       textContentType:nil
                                       requiredMessage:nil
                                            identifier:@"bank-account-custom-form-routing-number-field"
                                    onValidationChange:^(BOOL valid) {
        self.routingNumberIsValid = valid;
        [self updatePayButtonState];
    }
                                              onSubmit:^{
        (void)[self.accountNumberField becomeFirstResponder];
    }
                                           submitLabel:SpreedlySubmitLabelNext];

    self.accountNumberField = [self makeFieldWithType:FormFieldTypeAccountNumber
                                                 title:@"Account Number"
                                            isRequired:YES
                                          keyboardType:UIKeyboardTypeNumberPad
                                       textContentType:nil
                                       requiredMessage:nil
                                            identifier:@"bank-account-custom-form-account-number-field"
                                    onValidationChange:^(BOOL valid) {
        self.accountNumberIsValid = valid;
        [self updatePayButtonState];
    }
                                              onSubmit:^{
        [self payButtonTapped];
    }
                                           submitLabel:SpreedlySubmitLabelDone];
}

- (SPLTextFieldViewController *)makeFieldWithType:(FormFieldType)type
                                            title:(NSString *)title
                                       isRequired:(BOOL)required
                                     keyboardType:(UIKeyboardType)keyboardType
                                  textContentType:(nullable UITextContentType)contentType
                                  requiredMessage:(nullable NSString *)requiredMessage
                                       identifier:(NSString *)identifier
                               onValidationChange:(void (^)(BOOL))onValidation
                                         onSubmit:(void (^)(void))onSubmit
                                      submitLabel:(SpreedlySubmitLabel)submitLabel {
    SPLTextFieldViewController *field;
    if (self.useCustomTheme && self.lightThemeConfig && self.darkThemeConfig) {
        field = [[SPLTextFieldViewController alloc]
                 initWithField:type
                         title:title
                    isRequired:required
                   placeholder:requiredMessage ? title : nil
                  keyboardType:keyboardType
               textContentType:contentType
              lightThemeConfig:self.lightThemeConfig
               darkThemeConfig:self.darkThemeConfig
            onValidationChange:onValidation
                      onSubmit:onSubmit
                   submitLabel:submitLabel
                       onFocus:nil];
    } else {
        field = [[SPLTextFieldViewController alloc]
                 initWithField:type
                         title:title
                    isRequired:required
                   placeholder:requiredMessage ? title : nil
                  keyboardType:keyboardType
               textContentType:contentType
            onValidationChange:onValidation
                      onSubmit:onSubmit
                   submitLabel:submitLabel
                       onFocus:nil];
    }
    field.requiredMessage = requiredMessage;

    [self addChildViewController:field];
    field.view.translatesAutoresizingMaskIntoConstraints = NO;
    field.view.accessibilityIdentifier = identifier;
    [self.formContainer addSubview:field.view];
    [field didMoveToParentViewController:self];
    return field;
}

- (void)attachBankNameFieldVisible:(BOOL)visible {
    if (self.bankNameField) {
        [self detachField:self.bankNameField];
        self.bankNameField = nil;
    }
    self.bankNameIsValid = YES;
    if (!visible) { return; }

    self.bankNameField = [self makeFieldWithType:FormFieldTypeBankName
                                           title:@"Bank Name"
                                      isRequired:NO
                                    keyboardType:UIKeyboardTypeDefault
                                 textContentType:nil
                                 requiredMessage:nil
                                      identifier:@"bank-account-custom-form-bank-name-field"
                              onValidationChange:^(BOOL valid) {
        self.bankNameIsValid = valid;
        [self updatePayButtonState];
    }
                                        onSubmit:^{
        (void)[self.routingNumberField becomeFirstResponder];
    }
                                     submitLabel:SpreedlySubmitLabelNext];
}

- (void)setupFormTypePickers {
    if (!self.personalInfoLabel) {
        self.personalInfoLabel = [[UILabel alloc] init];
        self.personalInfoLabel.text = @"Personal information";
        self.personalInfoLabel.font = [ThemeHelper screenHeadlineFont];
        self.personalInfoLabel.textColor = [ThemeHelper textColor];
        self.personalInfoLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.formContainer addSubview:self.personalInfoLabel];
    }

    if (!self.accountTypeFormLabel) {
        self.accountTypeFormLabel = [[UILabel alloc] init];
        self.accountTypeFormLabel.text = @"Account type:";
        self.accountTypeFormLabel.font = [ThemeHelper screenBodyFont];
        self.accountTypeFormLabel.textColor = [ThemeHelper textColor];
        self.accountTypeFormLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.formContainer addSubview:self.accountTypeFormLabel];
    }

    if (!self.accountTypeControl) {
        self.accountTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"Checking", @"Savings"]];
        self.accountTypeControl.selectedSegmentIndex = 0;
        self.accountTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
        self.accountTypeControl.accessibilityIdentifier = @"bank-account-custom-form-account-type-picker";
        [self.formContainer addSubview:self.accountTypeControl];
    }

    if (!self.holderTypeFormLabel) {
        self.holderTypeFormLabel = [[UILabel alloc] init];
        self.holderTypeFormLabel.text = @"Account holder type:";
        self.holderTypeFormLabel.font = [ThemeHelper screenBodyFont];
        self.holderTypeFormLabel.textColor = [ThemeHelper textColor];
        self.holderTypeFormLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.formContainer addSubview:self.holderTypeFormLabel];
    }

    if (!self.holderTypeControl) {
        self.holderTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"Personal", @"Business"]];
        self.holderTypeControl.selectedSegmentIndex = 0;
        self.holderTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
        self.holderTypeControl.accessibilityIdentifier = @"bank-account-custom-form-holder-type-picker";
        [self.formContainer addSubview:self.holderTypeControl];
    }
}

- (void)updateFormTypePickersVisibility {
    self.accountTypeFormLabel.hidden = !self.showAccountType;
    self.accountTypeControl.hidden = !self.showAccountType;
    self.holderTypeFormLabel.hidden = !self.showAccountHolderType;
    self.holderTypeControl.hidden = !self.showAccountHolderType;
}

- (void)relayoutFormFields {
    NSMutableArray<NSLayoutConstraint *> *toRemove = [NSMutableArray array];
    for (NSLayoutConstraint *c in self.formContainer.constraints) {
        if ([self constraintReferencesFormChild:c]) {
            [toRemove addObject:c];
        }
    }
    [NSLayoutConstraint deactivateConstraints:toRemove];

    NSMutableArray<UIView *> *order = [NSMutableArray array];
    if (self.routingNumberField.view) { [order addObject:self.routingNumberField.view]; }
    if (self.accountNumberField.view) { [order addObject:self.accountNumberField.view]; }
    if (self.personalInfoLabel) { [order addObject:self.personalInfoLabel]; }
    if (self.fullNameField.view) { [order addObject:self.fullNameField.view]; }
    if (self.firstNameField.view) { [order addObject:self.firstNameField.view]; }
    if (self.lastNameField.view) { [order addObject:self.lastNameField.view]; }
    if (self.bankNameField.view) { [order addObject:self.bankNameField.view]; }
    if (self.showAccountType && self.accountTypeFormLabel) { [order addObject:self.accountTypeFormLabel]; }
    if (self.showAccountType && self.accountTypeControl) { [order addObject:self.accountTypeControl]; }
    if (self.showAccountHolderType && self.holderTypeFormLabel) { [order addObject:self.holderTypeFormLabel]; }
    if (self.showAccountHolderType && self.holderTypeControl) { [order addObject:self.holderTypeControl]; }

    NSLayoutAnchor<NSLayoutYAxisAnchor *> *previousBottom = nil;
    for (UIView *view in order) {
        if (!previousBottom) {
            [view.topAnchor constraintEqualToAnchor:self.formContainer.topAnchor constant:[ThemeHelper spacingMD]].active = YES;
        } else {
            [view.topAnchor constraintEqualToAnchor:previousBottom constant:[ThemeHelper spacingMD]].active = YES;
        }
        [view.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor constant:[ThemeHelper spacingMD]].active = YES;
        [view.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor constant:-[ThemeHelper spacingMD]].active = YES;
        if ([view isKindOfClass:[UIView class]] && view.subviews.count > 0) {
            [view.heightAnchor constraintGreaterThanOrEqualToConstant:60].active = YES;
        }
        previousBottom = view.bottomAnchor;
    }
    if (previousBottom) {
        [self.formContainer.bottomAnchor constraintEqualToAnchor:previousBottom constant:[ThemeHelper spacingMD]].active = YES;
    }
}

- (BOOL)constraintReferencesFormChild:(NSLayoutConstraint *)constraint {
    NSArray *children = @[
        self.routingNumberField.view ?: [NSNull null],
        self.accountNumberField.view ?: [NSNull null],
        self.personalInfoLabel ?: [NSNull null],
        self.fullNameField.view ?: [NSNull null],
        self.firstNameField.view ?: [NSNull null],
        self.lastNameField.view ?: [NSNull null],
        self.bankNameField.view ?: [NSNull null],
        self.accountTypeFormLabel ?: [NSNull null],
        self.accountTypeControl ?: [NSNull null],
        self.holderTypeFormLabel ?: [NSNull null],
        self.holderTypeControl ?: [NSNull null]
    ];
    for (id child in children) {
        if (child == [NSNull null]) { continue; }
        if (constraint.firstItem == child || constraint.secondItem == child) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Constraints

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
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.componentsContainer.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.componentsContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.componentsContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.configContainer.topAnchor constraintEqualToAnchor:self.componentsContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.configContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.configContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.themeContainer.topAnchor constraintEqualToAnchor:self.configContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.themeContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.themeContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.formContainer.topAnchor constraintEqualToAnchor:self.themeContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.formContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.formContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.payButton.topAnchor constraintEqualToAnchor:self.formContainer.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.payButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.payButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        [self.payButton.heightAnchor constraintEqualToConstant:44],

        [self.resultContainer.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.errorLabel.topAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        [self.errorLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

#pragma mark - Toggles

- (void)nameDisplayModeChanged:(UISegmentedControl *)sender {
    self.nameDisplayMode = sender.selectedSegmentIndex == 0 ? BankAccountNameDisplayModeFullName : BankAccountNameDisplayModeSeparate;
    self.fullNameIsValid = NO;
    self.firstNameIsValid = NO;
    self.lastNameIsValid = NO;
    [self attachNameFieldsForCurrentMode];
    [self relayoutFormFields];
    [self updatePayButtonState];
}

- (void)toggleShowBankName:(UISwitch *)sender {
    self.showBankName = sender.isOn;
    [self attachBankNameFieldVisible:self.showBankName];
    [self relayoutFormFields];
    [self updatePayButtonState];
}

- (void)toggleShowAccountType:(UISwitch *)sender {
    self.showAccountType = sender.isOn;
    [self updateFormTypePickersVisibility];
    [self relayoutFormFields];
}

- (void)toggleShowAccountHolderType:(UISwitch *)sender {
    self.showAccountHolderType = sender.isOn;
    [self updateFormTypePickersVisibility];
    [self relayoutFormFields];
}

#pragma mark - Validation

- (BOOL)isFormValid {
    BOOL nameValid;
    if (self.nameDisplayMode == BankAccountNameDisplayModeFullName) {
        nameValid = self.fullNameIsValid;
    } else {
        nameValid = self.firstNameIsValid && self.lastNameIsValid;
    }

    BOOL bankNameValid = self.showBankName ? self.bankNameIsValid : YES;
    return nameValid && bankNameValid && self.routingNumberIsValid && self.accountNumberIsValid;
}

- (void)updatePayButtonState {
    BOOL formValid = [self isFormValid];
    self.payButton.enabled = formValid && !self.isLoading;
    UIColor *fill = [ThemeHelper primaryColor];
    if (self.useCustomTheme && self.lightThemeConfig && self.lightThemeConfig.primaryColor) {
        fill = self.lightThemeConfig.primaryColor;
    }
    self.payButton.backgroundColor = (formValid && !self.isLoading)
        ? fill
        : [fill colorWithAlphaComponent:0.6];
}

#pragma mark - Submit

- (void)payButtonTapped {
    if (![self isFormValid]) { return; }

    self.isLoading = YES;
    [self.loadingIndicator startAnimating];
    [self.payButton setTitle:@"Processing..." forState:UIControlStateNormal];
    self.errorMessage = nil;
    self.paymentResult = nil;
    [self updatePayButtonState];

    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self submitBankAccount];
            } else {
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
                self.errorMessage = error.localizedDescription ?: @"Signature generation failed";
                [self updateUI];
                [self updatePayButtonState];
            }
        });
    }];
}

- (void)submitBankAccount {
    NSString *bankAccountTypeRaw = self.showAccountType
        ? (self.accountTypeControl.selectedSegmentIndex == 0 ? @"checking" : @"savings")
        : nil;
    NSString *bankAccountHolderTypeRaw = self.showAccountHolderType
        ? (self.holderTypeControl.selectedSegmentIndex == 0 ? @"personal" : @"business")
        : nil;

    PaymentProcessingResult *processingResult =
        [[Spreedly shared] createBankAccountObjCWithAdditionalFields:@{}
                                                     bankAccountType:bankAccountTypeRaw
                                               bankAccountHolderType:bankAccountHolderTypeRaw
                                                            bankName:nil
                                                            metadata:nil
                                                      allowBlankName:nil
                                                       shouldRetain:nil];

    if (processingResult.isValidationFailed) {
        self.isLoading = NO;
        [self.loadingIndicator stopAnimating];
        [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
        self.errorMessage = [processingResult getDescription];
        self.paymentResult = nil;
        [self updateUI];
        [self updatePayButtonState];
    }
}

#pragma mark - Result UI

- (void)updateUI {
    if (self.paymentResult && self.paymentResult.isSuccess) {
        [self renderSuccessContainer];
        self.resultContainer.hidden = NO;
        self.errorLabel.hidden = YES;
    } else if (self.errorMessage.length > 0) {
        self.errorLabel.text = [NSString stringWithFormat:@"Error: %@", self.errorMessage];
        self.errorLabel.hidden = NO;
        self.resultContainer.hidden = YES;
    } else {
        self.resultContainer.hidden = YES;
        self.errorLabel.hidden = YES;
    }
}

- (void)renderSuccessContainer {
    for (UIView *subview in self.resultContainer.subviews) {
        [subview removeFromSuperview];
    }

    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    [ThemeHelper applySmallShadowToView:self.resultContainer];

    UIStackView *headerStack = [[UIStackView alloc] init];
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.spacing = [ThemeHelper spacingSM];
    headerStack.alignment = UIStackViewAlignmentCenter;
    headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultContainer addSubview:headerStack];

    UIImageView *successIcon = [[UIImageView alloc] init];
    successIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    successIcon.tintColor = [ThemeHelper successColor];
    successIcon.accessibilityIdentifier = @"bank-account-custom-form-success-icon";
    [headerStack addArrangedSubview:successIcon];

    UILabel *successTitle = [[UILabel alloc] init];
    successTitle.text = @"Bank Account Tokenized!";
    successTitle.font = [ThemeHelper subtitleFont];
    successTitle.textColor = [ThemeHelper successColor];
    successTitle.accessibilityIdentifier = @"bank-account-custom-form-success-title";
    successTitle.accessibilityTraits = UIAccessibilityTraitHeader;
    [headerStack addArrangedSubview:successTitle];

    UILabel *tokenLabel = nil;
    if (self.paymentResult.token) {
        tokenLabel = [[UILabel alloc] init];
        NSString *masked = [Spreedly maskedToken:self.paymentResult.token];
        tokenLabel.text = [NSString stringWithFormat:@"Payment Token: %@", masked];
        tokenLabel.font = [ThemeHelper captionFont];
        tokenLabel.textColor = [ThemeHelper textSecondaryColor];
        tokenLabel.numberOfLines = 0;
        tokenLabel.translatesAutoresizingMaskIntoConstraints = NO;
        tokenLabel.accessibilityIdentifier = @"bank-account-custom-form-token-text";
        [self.resultContainer addSubview:tokenLabel];
    }

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [headerStack.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:[ThemeHelper spacingMD]],
        [headerStack.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
        [headerStack.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]]
    ]];

    UIView *lastView = headerStack;
    if (tokenLabel) {
        [constraints addObjectsFromArray:@[
            [tokenLabel.topAnchor constraintEqualToAnchor:lastView.bottomAnchor constant:[ThemeHelper spacingSM]],
            [tokenLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
            [tokenLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]]
        ]];
        lastView = tokenLabel;
    }
    [constraints addObject:[lastView.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-[ThemeHelper spacingMD]]];
    [NSLayoutConstraint activateConstraints:constraints];
}

#pragma mark - SpreedlyPaymentDelegate

- (void)paymentDidComplete:(PaymentResult *)result {
    self.paymentResult = result;
    self.isLoading = NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimating];
        [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];

        if (result.isSuccess) {
            self.errorMessage = nil;
        } else if (result.isFailure) {
            if (result.failureDetails) {
                self.errorMessage = [result.failureDetails getDescription];
            } else {
                self.errorMessage = @"Payment failed";
            }
        }

        [self updateUI];
        [self updatePayButtonState];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [Spreedly.shared setPaymentDelegate:nil];
    [[Spreedly shared] reset];
}

#pragma mark - Theme Configuration (chip + slider — matches Swift `BankAccountCustomFormView`)

- (UIView *)createThemeContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Theme Configuration:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    titleLabel.accessibilityIdentifier = @"bankAccountCustomThemeTitle";
    titleLabel.accessibilityLabel = @"Theme Configuration";
    [container addSubview:titleLabel];

    UILabel *toggleLabel = [[UILabel alloc] init];
    toggleLabel.text = @"Use Custom Theme";
    toggleLabel.font = [ThemeHelper screenBodyFont];
    toggleLabel.textColor = [ThemeHelper textColor];
    toggleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:toggleLabel];

    self.useCustomThemeSwitch = [[UISwitch alloc] init];
    self.useCustomThemeSwitch.onTintColor = [ThemeHelper primaryColor];
    self.useCustomThemeSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.useCustomThemeSwitch.accessibilityIdentifier = @"bankAccountCustomThemeToggle";
    self.useCustomThemeSwitch.accessibilityLabel = @"Use Custom Theme";
    self.useCustomThemeSwitch.accessibilityHint = @"Toggle a custom theme for the headless ACH form fields";
    [self.useCustomThemeSwitch addTarget:self action:@selector(useCustomThemeToggled:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.useCustomThemeSwitch];

    self.currentAccentLabel = [[UILabel alloc] init];
    self.currentAccentLabel.text = @"Current accent:";
    self.currentAccentLabel.font = [ThemeHelper screenBodyFont];
    self.currentAccentLabel.textColor = [ThemeHelper textColor];
    self.currentAccentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.currentAccentLabel];

    self.currentAccentValueLabel = [[UILabel alloc] init];
    self.currentAccentValueLabel.text = @"Default";
    self.currentAccentValueLabel.font = [ThemeHelper screenBodyFont];
    self.currentAccentValueLabel.textColor = [UIColor systemGrayColor];
    self.currentAccentValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.currentAccentValueLabel.accessibilityIdentifier = @"bankAccountCustomCurrentTheme";
    [container addSubview:self.currentAccentValueLabel];

    self.themeCustomizerContainer = [[UIView alloc] init];
    self.themeCustomizerContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.themeCustomizerContainer.hidden = YES;
    [container addSubview:self.themeCustomizerContainer];

    self.uiCustomizationTitleLabel = [[UILabel alloc] init];
    self.uiCustomizationTitleLabel.text = @"UI customization";
    self.uiCustomizationTitleLabel.font = [ThemeHelper screenSubheadlineFont];
    self.uiCustomizationTitleLabel.textColor = [ThemeHelper textColor];
    self.uiCustomizationTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCustomizerContainer addSubview:self.uiCustomizationTitleLabel];

    self.primarySectionLabel = [[UILabel alloc] init];
    self.primarySectionLabel.text = @"Primary color";
    self.primarySectionLabel.font = [ThemeHelper screenCaptionFont];
    self.primarySectionLabel.textColor = [ThemeHelper textSecondaryColor];
    self.primarySectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCustomizerContainer addSubview:self.primarySectionLabel];

    self.primarySwatchStack = [[UIStackView alloc] init];
    self.primarySwatchStack.axis = UILayoutConstraintAxisHorizontal;
    self.primarySwatchStack.spacing = 12.0;
    self.primarySwatchStack.alignment = UIStackViewAlignmentCenter;
    self.primarySwatchStack.distribution = UIStackViewDistributionEqualSpacing;
    self.primarySwatchStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCustomizerContainer addSubview:self.primarySwatchStack];

    self.primarySwatchButtons = [NSMutableArray arrayWithCapacity:kACHCustomPrimaryCount];
    for (NSUInteger i = 0; i < kACHCustomPrimaryCount; i++) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeCustom];
        chip.tag = (NSInteger)i;
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        chip.layer.cornerRadius = 18.0;
        chip.clipsToBounds = YES;
        chip.accessibilityIdentifier = [NSString stringWithFormat:@"bankAccountCustomPrimarySwatch_%lu", (unsigned long)i];
        chip.accessibilityLabel = [NSString stringWithFormat:@"Primary %@", ACHCustomPrimaryLabel(i)];
        [chip addTarget:self action:@selector(customPrimarySwatchTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chip.widthAnchor constraintEqualToConstant:36].active = YES;
        [chip.heightAnchor constraintEqualToConstant:36].active = YES;
        [self.primarySwatchStack addArrangedSubview:chip];
        [self.primarySwatchButtons addObject:chip];
    }

    self.fieldBackgroundSectionLabel = [[UILabel alloc] init];
    self.fieldBackgroundSectionLabel.text = @"Field background";
    self.fieldBackgroundSectionLabel.font = [ThemeHelper screenCaptionFont];
    self.fieldBackgroundSectionLabel.textColor = [ThemeHelper textSecondaryColor];
    self.fieldBackgroundSectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCustomizerContainer addSubview:self.fieldBackgroundSectionLabel];

    self.fieldBackgroundSwatchStack = [[UIStackView alloc] init];
    self.fieldBackgroundSwatchStack.axis = UILayoutConstraintAxisHorizontal;
    self.fieldBackgroundSwatchStack.spacing = 12.0;
    self.fieldBackgroundSwatchStack.alignment = UIStackViewAlignmentCenter;
    self.fieldBackgroundSwatchStack.distribution = UIStackViewDistributionEqualSpacing;
    self.fieldBackgroundSwatchStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCustomizerContainer addSubview:self.fieldBackgroundSwatchStack];

    self.fieldBackgroundSwatchButtons = [NSMutableArray arrayWithCapacity:kACHCustomFieldCount];
    for (NSUInteger i = 0; i < kACHCustomFieldCount; i++) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeCustom];
        chip.tag = (NSInteger)i;
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        chip.layer.cornerRadius = 18.0;
        chip.clipsToBounds = YES;
        chip.accessibilityIdentifier = [NSString stringWithFormat:@"bankAccountCustomFieldBackgroundSwatch_%lu", (unsigned long)i];
        chip.accessibilityLabel = [NSString stringWithFormat:@"Field background %@", ACHCustomFieldLabel(i)];
        [chip addTarget:self action:@selector(customFieldSwatchTapped:) forControlEvents:UIControlEventTouchUpInside];
        [chip.widthAnchor constraintEqualToConstant:36].active = YES;
        [chip.heightAnchor constraintEqualToConstant:36].active = YES;
        [self.fieldBackgroundSwatchStack addArrangedSubview:chip];
        [self.fieldBackgroundSwatchButtons addObject:chip];
    }

    self.borderRadiusSectionLabel = [[UILabel alloc] init];
    self.borderRadiusSectionLabel.text = @"Border radius";
    self.borderRadiusSectionLabel.font = [ThemeHelper screenCaptionFont];
    self.borderRadiusSectionLabel.textColor = [ThemeHelper textSecondaryColor];
    self.borderRadiusSectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCustomizerContainer addSubview:self.borderRadiusSectionLabel];

    self.borderRadiusValueLabel = [[UILabel alloc] init];
    self.borderRadiusValueLabel.text = @"8 pt";
    self.borderRadiusValueLabel.font = [ThemeHelper screenSubheadlineFont];
    self.borderRadiusValueLabel.textColor = [ThemeHelper textSecondaryColor];
    self.borderRadiusValueLabel.textAlignment = NSTextAlignmentRight;
    self.borderRadiusValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeCustomizerContainer addSubview:self.borderRadiusValueLabel];

    self.cornerRadiusSlider = [[UISlider alloc] init];
    self.cornerRadiusSlider.minimumValue = 4.0f;
    self.cornerRadiusSlider.maximumValue = 24.0f;
    self.cornerRadiusSlider.value = 8.0f;
    self.cornerRadiusSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.cornerRadiusSlider.accessibilityIdentifier = @"bankAccountCustomFormCornerRadiusSlider";
    self.cornerRadiusSlider.accessibilityLabel = @"Border radius";
    [self.cornerRadiusSlider addTarget:self action:@selector(customCornerRadiusChanged:) forControlEvents:UIControlEventValueChanged];
    [self.themeCustomizerContainer addSubview:self.cornerRadiusSlider];

    self.resetThemeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resetThemeButton setTitle:@"Reset to Default" forState:UIControlStateNormal];
    [self.resetThemeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.resetThemeButton.backgroundColor = [UIColor systemBlueColor];
    self.resetThemeButton.layer.cornerRadius = 8.0;
    self.resetThemeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetThemeButton.accessibilityIdentifier = @"bankAccountCustomResetThemeButton";
    self.resetThemeButton.accessibilityLabel = @"Reset to Default Theme";
    self.resetThemeButton.accessibilityHint = @"Reset the headless ACH form to the default theme";
    [self.resetThemeButton addTarget:self action:@selector(resetThemeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.themeCustomizerContainer addSubview:self.resetThemeButton];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [toggleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [toggleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],

        [self.useCustomThemeSwitch.centerYAnchor constraintEqualToAnchor:toggleLabel.centerYAnchor],
        [self.useCustomThemeSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.currentAccentLabel.topAnchor constraintEqualToAnchor:toggleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.currentAccentLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],

        [self.currentAccentValueLabel.centerYAnchor constraintEqualToAnchor:self.currentAccentLabel.centerYAnchor],
        [self.currentAccentValueLabel.leadingAnchor constraintEqualToAnchor:self.currentAccentLabel.trailingAnchor constant:[ThemeHelper spacingSM]],
        [self.currentAccentValueLabel.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.themeCustomizerContainer.topAnchor constraintEqualToAnchor:self.currentAccentLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.themeCustomizerContainer.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.themeCustomizerContainer.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.themeCustomizerContainer.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]],

        [self.uiCustomizationTitleLabel.topAnchor constraintEqualToAnchor:self.themeCustomizerContainer.topAnchor],
        [self.uiCustomizationTitleLabel.leadingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.leadingAnchor],
        [self.uiCustomizationTitleLabel.trailingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.trailingAnchor],

        [self.primarySectionLabel.topAnchor constraintEqualToAnchor:self.uiCustomizationTitleLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [self.primarySectionLabel.leadingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.leadingAnchor],
        [self.primarySectionLabel.trailingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.trailingAnchor],

        [self.primarySwatchStack.topAnchor constraintEqualToAnchor:self.primarySectionLabel.bottomAnchor constant:4],
        [self.primarySwatchStack.leadingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.leadingAnchor],
        [self.primarySwatchStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.themeCustomizerContainer.trailingAnchor],

        [self.fieldBackgroundSectionLabel.topAnchor constraintEqualToAnchor:self.primarySwatchStack.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.fieldBackgroundSectionLabel.leadingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.leadingAnchor],
        [self.fieldBackgroundSectionLabel.trailingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.trailingAnchor],

        [self.fieldBackgroundSwatchStack.topAnchor constraintEqualToAnchor:self.fieldBackgroundSectionLabel.bottomAnchor constant:4],
        [self.fieldBackgroundSwatchStack.leadingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.leadingAnchor],
        [self.fieldBackgroundSwatchStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.themeCustomizerContainer.trailingAnchor],

        [self.borderRadiusSectionLabel.topAnchor constraintEqualToAnchor:self.fieldBackgroundSwatchStack.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.borderRadiusSectionLabel.leadingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.leadingAnchor],

        [self.borderRadiusValueLabel.centerYAnchor constraintEqualToAnchor:self.borderRadiusSectionLabel.centerYAnchor],
        [self.borderRadiusValueLabel.leadingAnchor constraintEqualToAnchor:self.borderRadiusSectionLabel.trailingAnchor constant:[ThemeHelper spacingSM]],
        [self.borderRadiusValueLabel.trailingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.trailingAnchor],

        [self.cornerRadiusSlider.topAnchor constraintEqualToAnchor:self.borderRadiusSectionLabel.bottomAnchor constant:4],
        [self.cornerRadiusSlider.leadingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.leadingAnchor],
        [self.cornerRadiusSlider.trailingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.trailingAnchor],

        [self.resetThemeButton.topAnchor constraintEqualToAnchor:self.cornerRadiusSlider.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.resetThemeButton.leadingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.leadingAnchor],
        [self.resetThemeButton.trailingAnchor constraintEqualToAnchor:self.themeCustomizerContainer.trailingAnchor],
        [self.resetThemeButton.heightAnchor constraintEqualToConstant:40],
        [self.resetThemeButton.bottomAnchor constraintEqualToAnchor:self.themeCustomizerContainer.bottomAnchor]
    ]];

    [self refreshCustomSwatchFills];
    [self refreshCustomSwatchRings];
    [self refreshCustomAccentSummary];

    return container;
}

- (void)useCustomThemeToggled:(UISwitch *)sender {
    self.useCustomTheme = sender.isOn;
    self.themeCustomizerContainer.hidden = !self.useCustomTheme;

    if (self.useCustomTheme) {
        self.selectedPrimarySwatchID = 0;
        self.selectedFieldBackgroundSwatchID = 0;
        self.formCornerRadius = 8.0;
        self.cornerRadiusSlider.value = 8.0f;
        [self updateCustomBorderRadiusLabel];
        [self applyCustomThemeFromSwatches];
    } else {
        self.lightThemeConfig = nil;
        self.darkThemeConfig = nil;
        self.selectedPrimarySwatchID = kACHCustomSwatchUnset;
        self.selectedFieldBackgroundSwatchID = kACHCustomSwatchUnset;
    }

    [self refreshCustomSwatchFills];
    [self refreshCustomSwatchRings];
    [self refreshCustomAccentSummary];
    [self rebuildAllFields];
}

- (void)customPrimarySwatchTapped:(UIButton *)sender {
    self.selectedPrimarySwatchID = sender.tag;
    if (self.selectedFieldBackgroundSwatchID < 0) {
        self.selectedFieldBackgroundSwatchID = 0;
    }
    [self applyCustomThemeFromSwatches];
    [self refreshCustomSwatchFills];
    [self refreshCustomSwatchRings];
    [self refreshCustomAccentSummary];
    [self rebuildAllFields];
}

- (void)customFieldSwatchTapped:(UIButton *)sender {
    self.selectedFieldBackgroundSwatchID = sender.tag;
    if (self.selectedPrimarySwatchID < 0) {
        self.selectedPrimarySwatchID = 0;
    }
    [self applyCustomThemeFromSwatches];
    [self refreshCustomSwatchFills];
    [self refreshCustomSwatchRings];
    [self refreshCustomAccentSummary];
    [self rebuildAllFields];
}

- (void)customCornerRadiusChanged:(UISlider *)sender {
    self.formCornerRadius = (CGFloat)lround((double)sender.value);
    sender.value = (float)self.formCornerRadius;
    [self updateCustomBorderRadiusLabel];
    [self applyCustomThemeFromSwatches];
    [self rebuildAllFields];
}

- (void)updateCustomBorderRadiusLabel {
    self.borderRadiusValueLabel.text = [NSString stringWithFormat:@"%.0f pt", self.formCornerRadius];
}

- (void)resetThemeButtonTapped {
    self.lightThemeConfig = nil;
    self.darkThemeConfig = nil;
    self.selectedPrimarySwatchID = kACHCustomSwatchUnset;
    self.selectedFieldBackgroundSwatchID = kACHCustomSwatchUnset;
    self.formCornerRadius = 8.0;
    self.cornerRadiusSlider.value = 8.0f;
    [self updateCustomBorderRadiusLabel];
    [self refreshCustomSwatchFills];
    [self refreshCustomSwatchRings];
    [self refreshCustomAccentSummary];
    [self rebuildAllFields];
}

- (void)applyCustomThemeFromSwatches {
    if (!self.useCustomTheme) { return; }
    if (self.selectedPrimarySwatchID < 0 || self.selectedFieldBackgroundSwatchID < 0) {
        self.lightThemeConfig = nil;
        self.darkThemeConfig = nil;
        return;
    }

    UIColor *lightP = nil;
    UIColor *darkP = nil;
    UIColor *lightS = nil;
    UIColor *darkS = nil;
    ACHCustomPrimaryPair((NSUInteger)self.selectedPrimarySwatchID, &lightP, &darkP);
    ACHCustomFieldPair((NSUInteger)self.selectedFieldBackgroundSwatchID, &lightS, &darkS);
    CGFloat br = self.formCornerRadius;

    UIColor *lightSecondary = [lightP colorWithAlphaComponent:0.75];
    UIColor *lightBorder = [lightP colorWithAlphaComponent:0.32];
    UIColor *lightTextSecondary = ACHCustomRGB(51, 51, 56);
    UIColor *lightPlaceholder = [[UIColor grayColor] colorWithAlphaComponent:0.65];

    self.lightThemeConfig = [[SPLThemeConfig alloc] initWithPrimaryColor:lightP
                                                        secondaryColor:lightSecondary
                                                       backgroundColor:[UIColor clearColor]
                                                          surfaceColor:lightS
                                                           borderColor:lightBorder
                                                    borderFocusedColor:lightP
                                                             textColor:[UIColor blackColor]
                                                    textSecondaryColor:lightTextSecondary
                                                            errorColor:[UIColor systemRedColor]
                                                      placeholderColor:lightPlaceholder
                                                          borderRadius:br];

    UIColor *darkSecondary = [darkP colorWithAlphaComponent:0.85];
    UIColor *darkBorder = [darkP colorWithAlphaComponent:0.5];
    UIColor *darkTextSecondary = [[UIColor whiteColor] colorWithAlphaComponent:0.72];
    UIColor *darkPlaceholder = [[UIColor whiteColor] colorWithAlphaComponent:0.55];

    self.darkThemeConfig = [[SPLThemeConfig alloc] initWithPrimaryColor:darkP
                                                       secondaryColor:darkSecondary
                                                      backgroundColor:[UIColor clearColor]
                                                         surfaceColor:darkS
                                                          borderColor:darkBorder
                                                   borderFocusedColor:darkP
                                                            textColor:[UIColor whiteColor]
                                                   textSecondaryColor:darkTextSecondary
                                                           errorColor:[UIColor systemRedColor]
                                                     placeholderColor:darkPlaceholder
                                                         borderRadius:br];
}

- (void)refreshCustomAccentSummary {
    if (!self.useCustomTheme) {
        self.currentAccentValueLabel.text = @"Default";
        self.currentAccentValueLabel.textColor = [ThemeHelper textSecondaryColor];
        return;
    }
    if (self.selectedPrimarySwatchID < 0 || self.selectedFieldBackgroundSwatchID < 0) {
        self.currentAccentValueLabel.text = @"Pick colors";
        self.currentAccentValueLabel.textColor = [UIColor systemGrayColor];
        return;
    }
    NSString *p = ACHCustomPrimaryLabel((NSUInteger)self.selectedPrimarySwatchID);
    NSString *f = ACHCustomFieldLabel((NSUInteger)self.selectedFieldBackgroundSwatchID);
    self.currentAccentValueLabel.text = [NSString stringWithFormat:@"%@ · %@", p, f];
    self.currentAccentValueLabel.textColor = [UIColor labelColor];
}

- (void)refreshCustomSwatchFills {
    BOOL dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    for (NSUInteger i = 0; i < self.primarySwatchButtons.count; i++) {
        UIButton *b = self.primarySwatchButtons[i];
        UIColor *lightP = nil;
        UIColor *darkP = nil;
        ACHCustomPrimaryPair(i, &lightP, &darkP);
        b.backgroundColor = dark ? darkP : lightP;
    }
    for (NSUInteger i = 0; i < self.fieldBackgroundSwatchButtons.count; i++) {
        UIButton *b = self.fieldBackgroundSwatchButtons[i];
        UIColor *lightS = nil;
        UIColor *darkS = nil;
        ACHCustomFieldPair(i, &lightS, &darkS);
        b.backgroundColor = dark ? darkS : lightS;
    }
}

- (void)refreshCustomSwatchRings {
    UIColor *ring = [UIColor labelColor];
    UIColor *subtle = [[UIColor blackColor] colorWithAlphaComponent:0.12];
    for (NSUInteger i = 0; i < self.primarySwatchButtons.count; i++) {
        UIButton *b = self.primarySwatchButtons[i];
        BOOL sel = (self.selectedPrimarySwatchID == (NSInteger)i);
        b.layer.borderWidth = sel ? 3.0 : 1.0;
        b.layer.borderColor = (sel ? ring : subtle).CGColor;
        b.accessibilityTraits = sel ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
    }
    for (NSUInteger i = 0; i < self.fieldBackgroundSwatchButtons.count; i++) {
        UIButton *b = self.fieldBackgroundSwatchButtons[i];
        BOOL sel = (self.selectedFieldBackgroundSwatchID == (NSInteger)i);
        b.layer.borderWidth = sel ? 3.0 : 1.0;
        b.layer.borderColor = (sel ? ring : subtle).CGColor;
        b.accessibilityTraits = sel ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [self refreshCustomSwatchFills];
            [self refreshCustomSwatchRings];
        }
    }
}

- (void)rebuildAllFields {
    // Re-attach all hosted text fields so they pick up the new theme config.
    self.fullNameIsValid = NO;
    self.firstNameIsValid = NO;
    self.lastNameIsValid = NO;
    self.bankNameIsValid = YES;
    self.routingNumberIsValid = NO;
    self.accountNumberIsValid = NO;
    [self attachRoutingAndAccountFields];
    [self setupFormTypePickers];
    [self attachNameFieldsForCurrentMode];
    [self attachBankNameFieldVisible:self.showBankName];
    [self updateFormTypePickersVisibility];
    [self relayoutFormFields];
    [self updatePayButtonState];
}

@end
