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

static const NSInteger kACHSwatchUnset = -1;
static const NSUInteger kACHPrimarySwatchCount = 6;
static const NSUInteger kACHFieldSwatchCount = 6;

NS_INLINE UIColor *ACHRGB(unsigned r, unsigned g, unsigned b) {
    return [UIColor colorWithRed:(CGFloat)r / 255.0 green:(CGFloat)g / 255.0 blue:(CGFloat)b / 255.0 alpha:1.0];
}

static void ACHPrimaryPair(NSUInteger index, UIColor *__autoreleasing *light, UIColor *__autoreleasing *dark) {
    switch (index) {
        case 0: *light = ACHRGB(0x19, 0x76, 0xD2); *dark = ACHRGB(0x64, 0xB5, 0xF6); break;
        case 1: *light = ACHRGB(0x38, 0x8E, 0x3C); *dark = ACHRGB(0x81, 0xC7, 0x84); break;
        case 2: *light = ACHRGB(0x7B, 0x1F, 0xA2); *dark = ACHRGB(0xBA, 0x68, 0xC8); break;
        case 3: *light = ACHRGB(0xD3, 0x2F, 0x2F); *dark = ACHRGB(0xE5, 0x73, 0x73); break;
        case 4: *light = ACHRGB(0x00, 0x89, 0x7B); *dark = ACHRGB(0x4D, 0xB6, 0xAC); break;
        case 5: *light = ACHRGB(0xE6, 0x4A, 0x19); *dark = ACHRGB(0xFF, 0x8A, 0x65); break;
        default: *light = ACHRGB(0x19, 0x76, 0xD2); *dark = ACHRGB(0x64, 0xB5, 0xF6); break;
    }
}

static void ACHFieldSurfacePair(NSUInteger index, UIColor *__autoreleasing *light, UIColor *__autoreleasing *dark) {
    switch (index) {
        case 0: *light = [UIColor whiteColor]; *dark = ACHRGB(0x1C, 0x1C, 0x1E); break;
        case 1: *light = ACHRGB(0xF5, 0xF5, 0xF5); *dark = ACHRGB(0x2C, 0x2C, 0x2C); break;
        case 2: *light = ACHRGB(0xE8, 0xF5, 0xE9); *dark = ACHRGB(0x1B, 0x3A, 0x2A); break;
        case 3: *light = ACHRGB(0xE3, 0xF2, 0xFD); *dark = ACHRGB(0x1A, 0x2C, 0x3D); break;
        case 4: *light = ACHRGB(0xFF, 0xF3, 0xE0); *dark = ACHRGB(0x3D, 0x2E, 0x1A); break;
        case 5: *light = ACHRGB(0xF3, 0xE5, 0xF5); *dark = ACHRGB(0x2E, 0x1A, 0x3D); break;
        default: *light = [UIColor whiteColor]; *dark = ACHRGB(0x1C, 0x1C, 0x1E); break;
    }
}

static NSString *ACHPrimaryLabel(NSUInteger index) {
    NSArray<NSString *> *labels = @[@"Blue", @"Green", @"Purple", @"Red", @"Teal", @"Orange"];
    return (index < labels.count) ? labels[index] : @"";
}

static NSString *ACHFieldLabel(NSUInteger index) {
    NSArray<NSString *> *labels = @[@"Default", @"Gray", @"Pale green", @"Pale blue", @"Pale cream", @"Pale purple"];
    return (index < labels.count) ? labels[index] : @"";
}

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

// Theme picker UI
@property (nonatomic, strong) UIView *themeConfigurationContainer;
@property (nonatomic, strong) UISwitch *useCustomThemeSwitch;
@property (nonatomic, strong) UILabel *currentThemeLabel;
@property (nonatomic, strong) UILabel *themeNameLabel;
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

// Theme picker state — `SPLThemeConfig` instances are passed into the themed
// `BankAccountFormDropInViewController` initializer at present-time.
@property (nonatomic, strong) SPLThemeConfig *lightThemeConfig;
@property (nonatomic, strong) SPLThemeConfig *darkThemeConfig;
@property (nonatomic, assign) BOOL useCustomTheme;
@property (nonatomic, assign) NSInteger selectedPrimarySwatchID;
@property (nonatomic, assign) NSInteger selectedFieldBackgroundSwatchID;
@property (nonatomic, assign) CGFloat formCornerRadius;

@property (nonatomic, assign) BOOL isLoading;

@end

@implementation BankAccountCheckoutViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"ACH Bank Account";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.useCustomTheme = NO;
    self.selectedPrimarySwatchID = kACHSwatchUnset;
    self.selectedFieldBackgroundSwatchID = kACHSwatchUnset;
    self.formCornerRadius = 8.0;

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
    self.titleLabel.text = @"ACH Bank Account";
    self.titleLabel.font = [ThemeHelper screenTitleFont];
    self.titleLabel.textColor = [ThemeHelper textColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.accessibilityIdentifier = @"bankAccountCheckoutTitle";
    self.titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.contentView addSubview:self.titleLabel];

    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = @"Tokenize bank account details via ACH";
    self.descriptionLabel.accessibilityIdentifier = @"bank-account-checkout-description";
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
    self.showAccountTypeSwitch = [self addToggleWithText:@"Show account type"
                                             identifier:@"bankAccountShowAccountTypeToggle"];
    self.showAccountTypeSwitch.on = YES;
    self.showAccountHolderTypeSwitch = [self addToggleWithText:@"Show holder type"
                                                   identifier:@"bankAccountShowHolderTypeToggle"];
    self.showAccountHolderTypeSwitch.on = YES;

    self.themeConfigurationContainer = [self buildThemeConfigurationContainer];
    [self.contentView addSubview:self.themeConfigurationContainer];

    self.showFormButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.showFormButton setTitle:@"Add Bank Account" forState:UIControlStateNormal];
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

    [self.themeConfigurationContainer.topAnchor constraintEqualToAnchor:prev constant:[ThemeHelper spacingLG]].active = YES;
    [self.themeConfigurationContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]].active = YES;
    [self.themeConfigurationContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]].active = YES;

    [self.showFormButton.topAnchor constraintEqualToAnchor:self.themeConfigurationContainer.bottomAnchor constant:[ThemeHelper spacingLG]].active = YES;
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

    void (^processingHandler)(PaymentProcessingResult *) = ^(PaymentProcessingResult *processingResult) {
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
    };

    BankAccountFormDropInViewController *dropInVC;
    if (self.useCustomTheme && self.lightThemeConfig && self.darkThemeConfig) {
        dropInVC = [[BankAccountFormDropInViewController alloc]
            initWithFieldConfig:config
               lightThemeConfig:self.lightThemeConfig
                darkThemeConfig:self.darkThemeConfig
             onProcessingResult:processingHandler];
    } else {
        dropInVC = [[BankAccountFormDropInViewController alloc]
            initWithFieldConfig:config
             onProcessingResult:processingHandler];
    }

    // BankAccountFormDropInViewController applies screen prevention internally.
    [self presentViewController:dropInVC animated:YES completion:nil];
}

#pragma mark - Theme picker (chip + slider — matches Swift `BankAccountCheckoutView`)

- (UIView *)buildThemeConfigurationContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    container.layer.borderColor = resolvedBorderColor.CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.accessibilityIdentifier = @"bankAccountThemeConfigurationSection";
    [ThemeHelper applySmallShadowToView:container];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Theme Configuration:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"bankAccountThemeTitle";
    titleLabel.accessibilityLabel = @"Theme Configuration";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];

    UILabel *useCustomThemeLabel = [[UILabel alloc] init];
    useCustomThemeLabel.text = @"Use Custom Theme";
    useCustomThemeLabel.font = [ThemeHelper screenBodyFont];
    useCustomThemeLabel.textColor = [ThemeHelper textColor];
    useCustomThemeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:useCustomThemeLabel];

    self.useCustomThemeSwitch = [[UISwitch alloc] init];
    self.useCustomThemeSwitch.onTintColor = [ThemeHelper primaryColor];
    self.useCustomThemeSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.useCustomThemeSwitch.accessibilityIdentifier = @"bankAccountCustomThemeToggle";
    self.useCustomThemeSwitch.accessibilityHint = @"Toggle to enable or disable custom theme";
    [self.useCustomThemeSwitch addTarget:self action:@selector(useCustomThemeToggled:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.useCustomThemeSwitch];

    self.currentThemeLabel = [[UILabel alloc] init];
    self.currentThemeLabel.text = @"Current accent:";
    self.currentThemeLabel.font = [ThemeHelper screenSubheadlineFont];
    self.currentThemeLabel.textColor = [ThemeHelper textColor];
    self.currentThemeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.currentThemeLabel];

    self.themeNameLabel = [[UILabel alloc] init];
    self.themeNameLabel.text = @"Default";
    self.themeNameLabel.font = [ThemeHelper screenSubheadlineFont];
    self.themeNameLabel.textColor = [ThemeHelper textSecondaryColor];
    self.themeNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.themeNameLabel.accessibilityIdentifier = @"bankAccountCurrentTheme";
    [container addSubview:self.themeNameLabel];

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

    self.primarySwatchButtons = [NSMutableArray arrayWithCapacity:kACHPrimarySwatchCount];
    for (NSUInteger i = 0; i < kACHPrimarySwatchCount; i++) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeCustom];
        chip.tag = (NSInteger)i;
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        chip.layer.cornerRadius = 18.0;
        chip.clipsToBounds = YES;
        chip.accessibilityIdentifier = [NSString stringWithFormat:@"bankAccountPrimarySwatch_%lu", (unsigned long)i];
        chip.accessibilityLabel = [NSString stringWithFormat:@"Primary %@", ACHPrimaryLabel(i)];
        chip.accessibilityHint = [NSString stringWithFormat:@"Sets Checkout button and focus accents to %@", ACHPrimaryLabel(i)];
        [chip addTarget:self action:@selector(primarySwatchTapped:) forControlEvents:UIControlEventTouchUpInside];
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

    self.fieldBackgroundSwatchButtons = [NSMutableArray arrayWithCapacity:kACHFieldSwatchCount];
    for (NSUInteger i = 0; i < kACHFieldSwatchCount; i++) {
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeCustom];
        chip.tag = (NSInteger)i;
        chip.translatesAutoresizingMaskIntoConstraints = NO;
        chip.layer.cornerRadius = 18.0;
        chip.clipsToBounds = YES;
        chip.accessibilityIdentifier = [NSString stringWithFormat:@"bankAccountFieldBackgroundSwatch_%lu", (unsigned long)i];
        chip.accessibilityLabel = [NSString stringWithFormat:@"Field background %@", ACHFieldLabel(i)];
        chip.accessibilityHint = [NSString stringWithFormat:@"Sets SPLTextField surface fill to %@", ACHFieldLabel(i)];
        [chip addTarget:self action:@selector(fieldBackgroundSwatchTapped:) forControlEvents:UIControlEventTouchUpInside];
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
    self.cornerRadiusSlider.accessibilityIdentifier = @"bankAccountFormCornerRadiusSlider";
    self.cornerRadiusSlider.accessibilityLabel = @"Border radius";
    [self.cornerRadiusSlider addTarget:self action:@selector(cornerRadiusSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.themeCustomizerContainer addSubview:self.cornerRadiusSlider];

    self.resetThemeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resetThemeButton setTitle:@"Reset to Default" forState:UIControlStateNormal];
    self.resetThemeButton.backgroundColor = [UIColor systemBlueColor];
    [self.resetThemeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.resetThemeButton.layer.cornerRadius = 8.0;
    self.resetThemeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetThemeButton.accessibilityIdentifier = @"bankAccountResetThemeButton";
    self.resetThemeButton.accessibilityLabel = @"Reset to Default Theme";
    self.resetThemeButton.accessibilityHint = @"Reset the bank account form to the default theme";
    [self.resetThemeButton addTarget:self action:@selector(resetThemeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.themeCustomizerContainer addSubview:self.resetThemeButton];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [useCustomThemeLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [useCustomThemeLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [useCustomThemeLabel.centerYAnchor constraintEqualToAnchor:self.useCustomThemeSwitch.centerYAnchor],

        [self.useCustomThemeSwitch.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.useCustomThemeSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.currentThemeLabel.topAnchor constraintEqualToAnchor:useCustomThemeLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.currentThemeLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],

        [self.themeNameLabel.centerYAnchor constraintEqualToAnchor:self.currentThemeLabel.centerYAnchor],
        [self.themeNameLabel.leadingAnchor constraintEqualToAnchor:self.currentThemeLabel.trailingAnchor constant:[ThemeHelper spacingXS]],
        [self.themeNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.themeCustomizerContainer.topAnchor constraintEqualToAnchor:self.currentThemeLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
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

    [self refreshSwatchFillColors];
    [self refreshSwatchSelectionOutlines];
    [self refreshAccentSummaryLabel];

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
        [self updateBorderRadiusValueLabel];
        [self applyACHThemeFromSwatchSelection];
    } else {
        self.lightThemeConfig = nil;
        self.darkThemeConfig = nil;
        self.selectedPrimarySwatchID = kACHSwatchUnset;
        self.selectedFieldBackgroundSwatchID = kACHSwatchUnset;
    }

    [self refreshSwatchFillColors];
    [self refreshSwatchSelectionOutlines];
    [self refreshAccentSummaryLabel];

    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)primarySwatchTapped:(UIButton *)sender {
    self.selectedPrimarySwatchID = sender.tag;
    if (self.selectedFieldBackgroundSwatchID < 0) {
        self.selectedFieldBackgroundSwatchID = 0;
    }
    [self applyACHThemeFromSwatchSelection];
    [self refreshSwatchFillColors];
    [self refreshSwatchSelectionOutlines];
    [self refreshAccentSummaryLabel];
}

- (void)fieldBackgroundSwatchTapped:(UIButton *)sender {
    self.selectedFieldBackgroundSwatchID = sender.tag;
    if (self.selectedPrimarySwatchID < 0) {
        self.selectedPrimarySwatchID = 0;
    }
    [self applyACHThemeFromSwatchSelection];
    [self refreshSwatchFillColors];
    [self refreshSwatchSelectionOutlines];
    [self refreshAccentSummaryLabel];
}

- (void)cornerRadiusSliderChanged:(UISlider *)sender {
    self.formCornerRadius = (CGFloat)lround((double)sender.value);
    sender.value = (float)self.formCornerRadius;
    [self updateBorderRadiusValueLabel];
    [self applyACHThemeFromSwatchSelection];
}

- (void)updateBorderRadiusValueLabel {
    self.borderRadiusValueLabel.text = [NSString stringWithFormat:@"%.0f pt", self.formCornerRadius];
}

- (void)resetThemeButtonTapped {
    self.lightThemeConfig = nil;
    self.darkThemeConfig = nil;
    self.selectedPrimarySwatchID = kACHSwatchUnset;
    self.selectedFieldBackgroundSwatchID = kACHSwatchUnset;
    self.formCornerRadius = 8.0;
    self.cornerRadiusSlider.value = 8.0f;
    [self updateBorderRadiusValueLabel];
    [self refreshSwatchFillColors];
    [self refreshSwatchSelectionOutlines];
    [self refreshAccentSummaryLabel];
}

- (void)applyACHThemeFromSwatchSelection {
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
    ACHPrimaryPair((NSUInteger)self.selectedPrimarySwatchID, &lightP, &darkP);
    ACHFieldSurfacePair((NSUInteger)self.selectedFieldBackgroundSwatchID, &lightS, &darkS);
    CGFloat br = self.formCornerRadius;

    UIColor *lightSecondary = [lightP colorWithAlphaComponent:0.75];
    UIColor *lightBorder = [lightP colorWithAlphaComponent:0.32];
    UIColor *lightTextSecondary = ACHRGB(51, 51, 56);
    UIColor *lightPlaceholder = [[UIColor grayColor] colorWithAlphaComponent:0.65];

    self.lightThemeConfig = [[SPLThemeConfig alloc] initWithPrimaryColor:lightP
                                                        secondaryColor:lightSecondary
                                                       backgroundColor:[UIColor whiteColor]
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
                                                      backgroundColor:[UIColor blackColor]
                                                         surfaceColor:darkS
                                                          borderColor:darkBorder
                                                   borderFocusedColor:darkP
                                                            textColor:[UIColor whiteColor]
                                                   textSecondaryColor:darkTextSecondary
                                                           errorColor:[UIColor systemRedColor]
                                                     placeholderColor:darkPlaceholder
                                                         borderRadius:br];
}

- (void)refreshAccentSummaryLabel {
    if (!self.useCustomTheme) {
        self.themeNameLabel.text = @"Default";
        self.themeNameLabel.textColor = [ThemeHelper textSecondaryColor];
        return;
    }
    if (self.selectedPrimarySwatchID < 0 || self.selectedFieldBackgroundSwatchID < 0) {
        self.themeNameLabel.text = @"Pick colors";
        self.themeNameLabel.textColor = [UIColor systemGrayColor];
        return;
    }
    NSString *p = ACHPrimaryLabel((NSUInteger)self.selectedPrimarySwatchID);
    NSString *f = ACHFieldLabel((NSUInteger)self.selectedFieldBackgroundSwatchID);
    self.themeNameLabel.text = [NSString stringWithFormat:@"%@ · %@", p, f];
    self.themeNameLabel.textColor = [UIColor labelColor];
}

- (void)refreshSwatchFillColors {
    BOOL dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    for (NSUInteger i = 0; i < self.primarySwatchButtons.count; i++) {
        UIButton *b = self.primarySwatchButtons[i];
        UIColor *lightP = nil;
        UIColor *darkP = nil;
        ACHPrimaryPair(i, &lightP, &darkP);
        b.backgroundColor = dark ? darkP : lightP;
    }
    for (NSUInteger i = 0; i < self.fieldBackgroundSwatchButtons.count; i++) {
        UIButton *b = self.fieldBackgroundSwatchButtons[i];
        UIColor *lightS = nil;
        UIColor *darkS = nil;
        ACHFieldSurfacePair(i, &lightS, &darkS);
        b.backgroundColor = dark ? darkS : lightS;
    }
}

- (void)refreshSwatchSelectionOutlines {
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
            [self refreshSwatchFillColors];
            [self refreshSwatchSelectionOutlines];
        }
    }
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
