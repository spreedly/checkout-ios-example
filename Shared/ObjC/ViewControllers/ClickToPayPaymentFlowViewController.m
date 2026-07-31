//
//  ClickToPayPaymentFlowViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  Merchant-reference Click to Pay checkout — parity with Swift ClickToPayMerchantCheckoutView.
//

#import "ClickToPayPaymentFlowViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyClickToPay/SpreedlyClickToPay-Swift.h>
#import "SpreedlyConfigManager.h"
#import "ThemeHelper.h"
#import "AppConstants.h"
#import <objc/runtime.h>

static NSString * const kScenario1Hint =
    @"Email or phone with country code is required for lookup. Billing name and address prefill tokenize; cardholder name is prefilled in the Click to Pay sheet when provided. Card PAN/CVV stay in the sheet.";
static NSString * const kStableScenario1Email = @"ybhatt@spreedly.com";
static NSString * const kC2PDpaPresentationName = @"Spreedly C2P Sandbox";
static NSString * const kC2PDpaName = @"SpreedlyC2PSandbox";
static NSString * const kC2PLocale = @"en_US";

typedef NS_ENUM(NSInteger, C2PMerchantStage) {
    C2PMerchantStageIdle = 0,
    C2PMerchantStageCheckout = 1,
    C2PMerchantStageTokenizing = 2,
};

@interface C2PProduct : NSObject
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, copy) NSString *iconName;
- (NSString *)formattedPriceUSD;
@end

@implementation C2PProduct
- (NSString *)formattedPriceUSD {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = @"USD";
    return [formatter stringFromNumber:self.price] ?: [NSString stringWithFormat:@"$%@", self.price];
}
@end

static UIColor *c2pStageDisabledColor(void) {
    return [UIColor colorWithRed:0.678 green:0.710 blue:0.741 alpha:1.0];
}

static const NSInteger kC2PStageCircleTagBase = 2000;
static const NSInteger kC2PStageNumberTagBase  = 2100;
static const NSInteger kC2PStageLabelTagBase   = 2200;
static const NSInteger kC2PStageLineTagBase     = 2300;

@interface ClickToPayPaymentFlowViewController () <ClickToPayDelegate, SpreedlyPaymentDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *headerSection;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerDescriptionLabel;
@property (nonatomic, strong) UIView *stageIndicatorContainer;
@property (nonatomic, strong) UIView *statusSection;
@property (nonatomic, strong) UILabel *flowPhaseLabel;
@property (nonatomic, strong) UILabel *flowMessageLabel;
@property (nonatomic, strong) UIView *productSelectionContainer;
@property (nonatomic, strong) UIStackView *productsStackView;
@property (nonatomic, strong) UILabel *totalAmountLabel;
@property (nonatomic, strong) UIView *customerSection;
@property (nonatomic, strong) UILabel *scenarioHintLabel;
@property (nonatomic, strong) UITextField *emailField;
@property (nonatomic, strong) UITextField *phoneCountryField;
@property (nonatomic, strong) UITextField *phoneNumberField;
@property (nonatomic, strong) UILabel *emailErrorLabel;
@property (nonatomic, strong) UILabel *phoneErrorLabel;
@property (nonatomic, strong) UIView *billingSection;
@property (nonatomic, strong) UITextField *firstNameField;
@property (nonatomic, strong) UITextField *lastNameField;
@property (nonatomic, strong) UILabel *firstNameErrorLabel;
@property (nonatomic, strong) UILabel *lastNameErrorLabel;
@property (nonatomic, strong) UITextField *addressLine1Field;
@property (nonatomic, strong) UITextField *addressLine2Field;
@property (nonatomic, strong) UITextField *countryField;
@property (nonatomic, strong) UITextField *cityField;
@property (nonatomic, strong) UITextField *stateField;
@property (nonatomic, strong) UITextField *zipField;
@property (nonatomic, strong) UISwitch *billingToShippingSwitch;
@property (nonatomic, strong) UILabel *cardCollectionNoteLabel;
@property (nonatomic, strong) UIButton *payButton;
@property (nonatomic, strong) UIActivityIndicatorView *paySpinner;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UILabel *successLabel;
@property (nonatomic, strong) UIView *errorContainer;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, assign) C2PMerchantStage stage;
@property (nonatomic, assign) BOOL isLoadingSignature;
@property (nonatomic, assign) BOOL contactValidationAttempted;
@property (nonatomic, strong) NSArray<C2PProduct *> *products;
@property (nonatomic, strong) C2PProduct *selectedProduct;
@property (nonatomic, copy) NSString *flowPhaseText;
@property (nonatomic, copy) NSString *flowMessageText;
@end

@implementation ClickToPayPaymentFlowViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Click to Pay";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.stage = C2PMerchantStageIdle;
    self.isLoadingSignature = NO;
    self.contactValidationAttempted = NO;
    self.flowPhaseText = @"idle";
    self.flowMessageText = @"Ready";
    self.products = [self buildProducts];

    [Spreedly shared].paymentDelegate = self;
    SpreedlyClickToPayCheckout.delegate = self;
    [self configureAutoTokenizeAuthRefresher];

    [self setupUI];
    [self applyScenario1Fields];
    [self updateProductSelection];
    [self updatePayButtonState];
    [self updateStatusSection];
    [self updateStageIndicator];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([Spreedly shared].paymentDelegate == self) {
        [Spreedly shared].paymentDelegate = nil;
    }
    if (SpreedlyClickToPayCheckout.delegate == self) {
        SpreedlyClickToPayCheckout.delegate = nil;
    }
}

#pragma mark - Products

- (NSArray<C2PProduct *> *)buildProducts {
    return @[
        [self productWithId:@"c2p_sunglasses" name:@"Sunglasses" price:@"44" iconName:@"sunglasses"],
        [self productWithId:@"c2p_watch" name:@"Watch" price:@"199" iconName:@"applewatch"],
        [self productWithId:@"c2p_headphones" name:@"Headphones" price:@"299" iconName:@"airpods"],
        [self productWithId:@"c2p_camera" name:@"Camera" price:@"899" iconName:@"camera"],
        [self productWithId:@"c2p_laptop" name:@"Laptop" price:@"1299" iconName:@"laptopcomputer"],
        [self productWithId:@"c2p_phone" name:@"Phone" price:@"999" iconName:@"iphone"],
    ];
}

- (C2PProduct *)productWithId:(NSString *)productId name:(NSString *)name price:(NSString *)price iconName:(NSString *)iconName {
    C2PProduct *product = [[C2PProduct alloc] init];
    product.productId = productId;
    product.name = name;
    product.price = [NSDecimalNumber decimalNumberWithString:price];
    product.iconName = iconName;
    return product;
}

#pragma mark - Scenario

- (void)configureAutoTokenizeAuthRefresher {
    [SpreedlyClickToPayCheckout setAutoTokenizeAuthRefresherBlocking:^BOOL {
        __block BOOL success = NO;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL ok, NSError * _Nullable error) {
            (void)error;
            success = ok;
            dispatch_semaphore_signal(sem);
        }];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        return success;
    }];
}

- (void)applyScenario1Fields {
    self.emailField.text = kStableScenario1Email;
    self.scenarioHintLabel.text = kScenario1Hint;
    self.phoneCountryField.text = @"1";
    self.phoneNumberField.text = @"";
    self.firstNameField.text = @"Lee";
    self.lastNameField.text = @"Cardholder";
    self.addressLine1Field.text = @"123 Main St.";
    self.addressLine2Field.text = @"";
    self.countryField.text = @"US";
    self.cityField.text = @"New York";
    self.stateField.text = @"NY";
    self.zipField.text = @"10011";
    self.billingToShippingSwitch.on = YES;
}

- (NSString *)sandboxSrcDpaId {
    NSString *fromPlist = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SpreedlyC2PSandboxSrcDpaId"];
    if (fromPlist.length > 0 && ![fromPlist hasPrefix:@"$("]) {
        return fromPlist;
    }
    return @"";
}

#pragma mark - UI Setup

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    self.headerSection = [[UIView alloc] init];
    self.headerSection.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.headerSection];

    self.headerTitleLabel = [[UILabel alloc] init];
    self.headerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTitleLabel.text = @"Checkout with Click to Pay";
    self.headerTitleLabel.font = [ThemeHelper titleFont];
    self.headerTitleLabel.textColor = [ThemeHelper textColor];
    self.headerTitleLabel.numberOfLines = 0;
    [self.headerSection addSubview:self.headerTitleLabel];

    self.headerDescriptionLabel = [[UILabel alloc] init];
    self.headerDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerDescriptionLabel.text = @"Select a product, contact, and billing address. Card PAN/CVV are collected inside the Click to Pay sheet only.";
    self.headerDescriptionLabel.font = [ThemeHelper bodyFont];
    self.headerDescriptionLabel.textColor = [ThemeHelper textSecondaryColor];
    self.headerDescriptionLabel.numberOfLines = 0;
    [self.headerSection addSubview:self.headerDescriptionLabel];

    self.stageIndicatorContainer = [self createStageIndicatorContainer];
    [self.contentView addSubview:self.stageIndicatorContainer];

    self.statusSection = [self createStatusSection];
    [self.contentView addSubview:self.statusSection];

    self.productSelectionContainer = [self createProductSelectionContainer];
    [self.contentView addSubview:self.productSelectionContainer];

    self.customerSection = [self createCustomerSection];
    [self.contentView addSubview:self.customerSection];

    self.billingSection = [self createBillingSection];
    [self.contentView addSubview:self.billingSection];

    self.cardCollectionNoteLabel = [[UILabel alloc] init];
    self.cardCollectionNoteLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardCollectionNoteLabel.text = @"Card details are collected inside Click to Pay checkout (not on this screen).";
    self.cardCollectionNoteLabel.font = [ThemeHelper captionFont];
    self.cardCollectionNoteLabel.textColor = [ThemeHelper textSecondaryColor];
    self.cardCollectionNoteLabel.numberOfLines = 0;
    [self.contentView addSubview:self.cardCollectionNoteLabel];

    self.payButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.payButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.payButton.backgroundColor = [ThemeHelper primaryColor];
    [self.payButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.payButton setTitle:@"Pay with Click to Pay" forState:UIControlStateNormal];
    self.payButton.titleLabel.font = [ThemeHelper buttonFont];
    self.payButton.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.payButton.accessibilityIdentifier = @"c2p_merchant_pay_button";
    [self.payButton addTarget:self action:@selector(payTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.payButton];

    self.paySpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.paySpinner.color = [UIColor whiteColor];
    self.paySpinner.hidesWhenStopped = YES;
    self.paySpinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.payButton addSubview:self.paySpinner];

    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.resultContainer.hidden = YES;
    [self.contentView addSubview:self.resultContainer];

    self.successLabel = [[UILabel alloc] init];
    self.successLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.successLabel.font = [ThemeHelper bodyFont];
    self.successLabel.textColor = [ThemeHelper successColor];
    self.successLabel.numberOfLines = 0;
    [self.resultContainer addSubview:self.successLabel];

    self.errorContainer = [[UIView alloc] init];
    self.errorContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorContainer.backgroundColor = [[ThemeHelper errorColor] colorWithAlphaComponent:0.1];
    self.errorContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.errorContainer.hidden = YES;
    [self.contentView addSubview:self.errorContainer];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.font = [ThemeHelper bodyFont];
    self.errorLabel.textColor = [ThemeHelper errorColor];
    self.errorLabel.numberOfLines = 0;
    [self.errorContainer addSubview:self.errorLabel];

    [self activateLayoutConstraints];
}

- (void)activateLayoutConstraints {
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    CGFloat spacing = [ThemeHelper spacingMD];
    CGFloat lg = [ThemeHelper spacingLG];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor constant:-lg],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],

        [self.headerSection.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:spacing],
        [self.headerSection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.headerSection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.headerTitleLabel.topAnchor constraintEqualToAnchor:self.headerSection.topAnchor],
        [self.headerTitleLabel.leadingAnchor constraintEqualToAnchor:self.headerSection.leadingAnchor],
        [self.headerTitleLabel.trailingAnchor constraintEqualToAnchor:self.headerSection.trailingAnchor],
        [self.headerDescriptionLabel.topAnchor constraintEqualToAnchor:self.headerTitleLabel.bottomAnchor constant:spacing],
        [self.headerDescriptionLabel.leadingAnchor constraintEqualToAnchor:self.headerSection.leadingAnchor],
        [self.headerDescriptionLabel.trailingAnchor constraintEqualToAnchor:self.headerSection.trailingAnchor],
        [self.headerDescriptionLabel.bottomAnchor constraintEqualToAnchor:self.headerSection.bottomAnchor],

        [self.stageIndicatorContainer.topAnchor constraintEqualToAnchor:self.headerSection.bottomAnchor constant:lg],
        [self.stageIndicatorContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.stageIndicatorContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.statusSection.topAnchor constraintEqualToAnchor:self.stageIndicatorContainer.bottomAnchor constant:lg],
        [self.statusSection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.statusSection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.productSelectionContainer.topAnchor constraintEqualToAnchor:self.statusSection.bottomAnchor constant:lg],
        [self.productSelectionContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.productSelectionContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.customerSection.topAnchor constraintEqualToAnchor:self.productSelectionContainer.bottomAnchor constant:lg],
        [self.customerSection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.customerSection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.billingSection.topAnchor constraintEqualToAnchor:self.customerSection.bottomAnchor constant:lg],
        [self.billingSection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.billingSection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.cardCollectionNoteLabel.topAnchor constraintEqualToAnchor:self.billingSection.bottomAnchor constant:spacing],
        [self.cardCollectionNoteLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.cardCollectionNoteLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.payButton.topAnchor constraintEqualToAnchor:self.cardCollectionNoteLabel.bottomAnchor constant:lg],
        [self.payButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.payButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],
        [self.payButton.heightAnchor constraintEqualToConstant:48],

        [self.paySpinner.centerYAnchor constraintEqualToAnchor:self.payButton.centerYAnchor],
        [self.paySpinner.trailingAnchor constraintEqualToAnchor:self.payButton.trailingAnchor constant:-16],

        [self.resultContainer.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:lg],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],
        [self.successLabel.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:12],
        [self.successLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:12],
        [self.successLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-12],
        [self.successLabel.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-12],

        [self.errorContainer.topAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:spacing],
        [self.errorContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.errorContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],
        [self.errorContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-lg],
        [self.errorLabel.topAnchor constraintEqualToAnchor:self.errorContainer.topAnchor constant:12],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.errorContainer.leadingAnchor constant:12],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.errorContainer.trailingAnchor constant:-12],
        [self.errorLabel.bottomAnchor constraintEqualToAnchor:self.errorContainer.bottomAnchor constant:-12],
    ]];
}

- (UIView *)createStageIndicatorContainer {
    NSArray<NSString *> *stepNames = @[@"Idle", @"Checkout", @"Tokenize"];
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];

    UIStackView *stepsStack = [[UIStackView alloc] init];
    stepsStack.axis = UILayoutConstraintAxisHorizontal;
    stepsStack.distribution = UIStackViewDistributionFillEqually;
    stepsStack.alignment = UIStackViewAlignmentCenter;
    stepsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stepsStack];

    for (NSInteger i = 0; i < (NSInteger)stepNames.count; i++) {
        BOOL isActive = (i <= (NSInteger)self.stage);
        BOOL isCompleted = (i < (NSInteger)self.stage);

        UIView *stepColumn = [[UIView alloc] init];
        stepColumn.translatesAutoresizingMaskIntoConstraints = NO;

        UIView *circle = [[UIView alloc] init];
        circle.tag = kC2PStageCircleTagBase + i;
        circle.backgroundColor = isActive ? [ThemeHelper primaryColor] : c2pStageDisabledColor();
        circle.layer.cornerRadius = 12;
        circle.translatesAutoresizingMaskIntoConstraints = NO;
        [stepColumn addSubview:circle];

        UILabel *numberLabel = [[UILabel alloc] init];
        numberLabel.tag = kC2PStageNumberTagBase + i;
        numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        numberLabel.textColor = [UIColor whiteColor];
        numberLabel.textAlignment = NSTextAlignmentCenter;
        numberLabel.translatesAutoresizingMaskIntoConstraints = NO;
        numberLabel.text = isCompleted ? @"✓" : [NSString stringWithFormat:@"%ld", (long)(i + 1)];
        if (isCompleted) {
            numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        }
        [circle addSubview:numberLabel];

        UILabel *stepLabel = [[UILabel alloc] init];
        stepLabel.tag = kC2PStageLabelTagBase + i;
        stepLabel.text = stepNames[i];
        stepLabel.font = [ThemeHelper captionFont];
        stepLabel.textColor = isActive ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
        stepLabel.textAlignment = NSTextAlignmentCenter;
        stepLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [stepColumn addSubview:stepLabel];

        [NSLayoutConstraint activateConstraints:@[
            [circle.widthAnchor constraintEqualToConstant:24],
            [circle.heightAnchor constraintEqualToConstant:24],
            [circle.topAnchor constraintEqualToAnchor:stepColumn.topAnchor],
            [circle.centerXAnchor constraintEqualToAnchor:stepColumn.centerXAnchor],
            [numberLabel.centerXAnchor constraintEqualToAnchor:circle.centerXAnchor],
            [numberLabel.centerYAnchor constraintEqualToAnchor:circle.centerYAnchor],
            [stepLabel.topAnchor constraintEqualToAnchor:circle.bottomAnchor constant:4],
            [stepLabel.centerXAnchor constraintEqualToAnchor:stepColumn.centerXAnchor],
            [stepLabel.bottomAnchor constraintEqualToAnchor:stepColumn.bottomAnchor],
        ]];
        [stepsStack addArrangedSubview:stepColumn];
    }

    for (NSInteger i = 0; i < (NSInteger)stepNames.count - 1; i++) {
        UIView *currentCircle = [container viewWithTag:kC2PStageCircleTagBase + i];
        UIView *nextCircle = [container viewWithTag:kC2PStageCircleTagBase + (i + 1)];
        UIView *line = [[UIView alloc] init];
        line.tag = kC2PStageLineTagBase + i;
        line.backgroundColor = (i < (NSInteger)self.stage) ? [ThemeHelper primaryColor] : c2pStageDisabledColor();
        line.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:line];
        [NSLayoutConstraint activateConstraints:@[
            [line.leadingAnchor constraintEqualToAnchor:currentCircle.trailingAnchor constant:4],
            [line.trailingAnchor constraintEqualToAnchor:nextCircle.leadingAnchor constant:-4],
            [line.centerYAnchor constraintEqualToAnchor:currentCircle.centerYAnchor],
            [line.heightAnchor constraintEqualToConstant:2],
        ]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stepsStack.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [stepsStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingSM]],
        [stepsStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingSM]],
        [stepsStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]],
    ]];
    return container;
}

- (UIView *)createStatusSection {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusMD];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"SDK status";
    titleLabel.font = [ThemeHelper captionFont];
    titleLabel.textColor = [ThemeHelper textSecondaryColor];
    [container addSubview:titleLabel];

    self.flowPhaseLabel = [[UILabel alloc] init];
    self.flowPhaseLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.flowPhaseLabel.font = [ThemeHelper captionFont];
    self.flowPhaseLabel.textColor = [ThemeHelper textSecondaryColor];
    [container addSubview:self.flowPhaseLabel];

    self.flowMessageLabel = [[UILabel alloc] init];
    self.flowMessageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.flowMessageLabel.font = [ThemeHelper captionFont];
    self.flowMessageLabel.textColor = [ThemeHelper textSecondaryColor];
    self.flowMessageLabel.numberOfLines = 0;
    [container addSubview:self.flowMessageLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.flowPhaseLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [self.flowPhaseLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [self.flowPhaseLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [self.flowMessageLabel.topAnchor constraintEqualToAnchor:self.flowPhaseLabel.bottomAnchor constant:4],
        [self.flowMessageLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [self.flowMessageLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [self.flowMessageLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]],
    ]];
    return container;
}

- (UIView *)createProductSelectionContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Select Product";
    titleLabel.font = [ThemeHelper subtitleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"product-selection-title";
    [container addSubview:titleLabel];

    self.productsStackView = [[UIStackView alloc] init];
    self.productsStackView.axis = UILayoutConstraintAxisVertical;
    self.productsStackView.spacing = [ThemeHelper spacingMD];
    self.productsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.productsStackView];

    NSInteger productCount = MIN([AppConstants maxCardsToDisplay], self.products.count);
    for (NSInteger i = 0; i < productCount; i += 2) {
        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.spacing = [ThemeHelper spacingMD];
        rowStack.distribution = UIStackViewDistributionFillEqually;
        if (i < self.products.count) {
            [rowStack addArrangedSubview:[self createProductView:self.products[i]]];
        }
        if (i + 1 < self.products.count) {
            [rowStack addArrangedSubview:[self createProductView:self.products[i + 1]]];
        }
        [self.productsStackView addArrangedSubview:rowStack];
    }

    self.totalAmountLabel = [[UILabel alloc] init];
    self.totalAmountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.totalAmountLabel.font = [ThemeHelper subtitleFont];
    self.totalAmountLabel.textColor = [ThemeHelper textColor];
    self.totalAmountLabel.hidden = YES;
    self.totalAmountLabel.accessibilityIdentifier = @"product-total-amount";
    [container addSubview:self.totalAmountLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.productsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.productsStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.productsStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.totalAmountLabel.topAnchor constraintEqualToAnchor:self.productsStackView.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.totalAmountLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.totalAmountLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.totalAmountLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]],
    ]];
    return container;
}

- (UIView *)createProductView:(C2PProduct *)product {
    BOOL isSelected = (self.selectedProduct && [self.selectedProduct.productId isEqualToString:product.productId]);
    UIView *productView = [[UIView alloc] init];
    productView.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
    productView.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    if (isSelected) {
        productView.layer.borderWidth = 2;
        productView.layer.borderColor = [ThemeHelper primaryColor].CGColor;
    }
    productView.translatesAutoresizingMaskIntoConstraints = NO;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(productTapped:)];
    [productView addGestureRecognizer:tap];
    productView.userInteractionEnabled = YES;
    objc_setAssociatedObject(productView, "product", product, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = [ThemeHelper spacingXS];
    contentStack.alignment = UIStackViewAlignmentCenter;
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [productView addSubview:contentStack];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.image = [UIImage systemImageNamed:product.iconName];
    iconView.tintColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [contentStack addArrangedSubview:iconView];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = product.name;
    nameLabel.font = [ThemeHelper captionFont];
    nameLabel.textColor = [ThemeHelper textColor];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.numberOfLines = 2;
    [contentStack addArrangedSubview:nameLabel];

    UILabel *priceLabel = [[UILabel alloc] init];
    priceLabel.text = [product formattedPriceUSD];
    priceLabel.font = [ThemeHelper subtitleFont];
    priceLabel.textColor = [ThemeHelper merchantProductPriceColor];
    [contentStack addArrangedSubview:priceLabel];

    [NSLayoutConstraint activateConstraints:@[
        [contentStack.topAnchor constraintEqualToAnchor:productView.topAnchor constant:[ThemeHelper spacingMD]],
        [contentStack.leadingAnchor constraintEqualToAnchor:productView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [contentStack.trailingAnchor constraintEqualToAnchor:productView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [contentStack.bottomAnchor constraintEqualToAnchor:productView.bottomAnchor constant:-[ThemeHelper spacingMD]],
        [iconView.heightAnchor constraintEqualToConstant:30],
        [productView.heightAnchor constraintEqualToConstant:140],
    ]];
    return productView;
}

- (UIView *)createCustomerSection {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"Contact information";
    titleLabel.font = [ThemeHelper subtitleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    [container addSubview:titleLabel];

    self.scenarioHintLabel = [[UILabel alloc] init];
    self.scenarioHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.scenarioHintLabel.font = [ThemeHelper captionFont];
    self.scenarioHintLabel.textColor = [ThemeHelper textSecondaryColor];
    self.scenarioHintLabel.numberOfLines = 0;
    [container addSubview:self.scenarioHintLabel];

    self.emailField = [self c2pTextFieldWithPlaceholder:@"Email address" identifier:@"c2p_merchant_email"];
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailField.delegate = self;
    [self.emailField addTarget:self action:@selector(emailFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [container addSubview:self.emailField];

    UIStackView *phoneRow = [[UIStackView alloc] init];
    phoneRow.translatesAutoresizingMaskIntoConstraints = NO;
    phoneRow.axis = UILayoutConstraintAxisHorizontal;
    phoneRow.spacing = [ThemeHelper spacingSM];
    phoneRow.distribution = UIStackViewDistributionFill;

    self.phoneCountryField = [self c2pTextFieldWithPlaceholder:@"Country code" identifier:@"c2p_merchant_phone_country"];
    self.phoneCountryField.keyboardType = UIKeyboardTypePhonePad;
    self.phoneCountryField.delegate = self;
    [self.phoneCountryField addTarget:self action:@selector(phoneFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [self.phoneCountryField.widthAnchor constraintEqualToConstant:100].active = YES;
    [phoneRow addArrangedSubview:self.phoneCountryField];

    self.phoneNumberField = [self c2pTextFieldWithPlaceholder:@"Mobile number" identifier:@"c2p_merchant_phone"];
    self.phoneNumberField.keyboardType = UIKeyboardTypePhonePad;
    self.phoneNumberField.delegate = self;
    [self.phoneNumberField addTarget:self action:@selector(phoneFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [phoneRow addArrangedSubview:self.phoneNumberField];
    [container addSubview:phoneRow];

    self.emailErrorLabel = [[UILabel alloc] init];
    self.emailErrorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emailErrorLabel.font = [ThemeHelper captionFont];
    self.emailErrorLabel.textColor = [ThemeHelper errorColor];
    self.emailErrorLabel.numberOfLines = 0;
    self.emailErrorLabel.hidden = YES;
    [container addSubview:self.emailErrorLabel];

    self.phoneErrorLabel = [[UILabel alloc] init];
    self.phoneErrorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.phoneErrorLabel.font = [ThemeHelper captionFont];
    self.phoneErrorLabel.textColor = [ThemeHelper errorColor];
    self.phoneErrorLabel.numberOfLines = 0;
    self.phoneErrorLabel.hidden = YES;
    [container addSubview:self.phoneErrorLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.scenarioHintLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.scenarioHintLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.scenarioHintLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.emailField.topAnchor constraintEqualToAnchor:self.scenarioHintLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.emailField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.emailField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.emailErrorLabel.topAnchor constraintEqualToAnchor:self.emailField.bottomAnchor constant:4],
        [self.emailErrorLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.emailErrorLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [phoneRow.topAnchor constraintEqualToAnchor:self.emailErrorLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [phoneRow.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [phoneRow.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.phoneErrorLabel.topAnchor constraintEqualToAnchor:phoneRow.bottomAnchor constant:4],
        [self.phoneErrorLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.phoneErrorLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.phoneErrorLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    return container;
}

- (UIView *)createBillingSection {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = @"Billing / shipping address";
    titleLabel.font = [ThemeHelper subtitleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    [container addSubview:titleLabel];

    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.text = @"First and last name are required for tokenize and prefilled as cardholder name in the Click to Pay sheet. Other address fields are optional.";
    hintLabel.font = [ThemeHelper captionFont];
    hintLabel.textColor = [ThemeHelper textSecondaryColor];
    hintLabel.numberOfLines = 0;
    [container addSubview:hintLabel];

    UIStackView *nameRow = [[UIStackView alloc] init];
    nameRow.translatesAutoresizingMaskIntoConstraints = NO;
    nameRow.axis = UILayoutConstraintAxisHorizontal;
    nameRow.spacing = [ThemeHelper spacingSM];
    nameRow.distribution = UIStackViewDistributionFillEqually;

    UIStackView *firstNameColumn = [[UIStackView alloc] init];
    firstNameColumn.axis = UILayoutConstraintAxisVertical;
    firstNameColumn.spacing = 4;
    self.firstNameField = [self c2pTextFieldWithPlaceholder:@"First name" identifier:@"c2p_merchant_first_name"];
    self.firstNameErrorLabel = [self c2pFieldErrorLabel];
    [self.firstNameField addTarget:self action:@selector(billingFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [firstNameColumn addArrangedSubview:self.firstNameField];
    [firstNameColumn addArrangedSubview:self.firstNameErrorLabel];

    UIStackView *lastNameColumn = [[UIStackView alloc] init];
    lastNameColumn.axis = UILayoutConstraintAxisVertical;
    lastNameColumn.spacing = 4;
    self.lastNameField = [self c2pTextFieldWithPlaceholder:@"Last name" identifier:@"c2p_merchant_last_name"];
    self.lastNameErrorLabel = [self c2pFieldErrorLabel];
    [self.lastNameField addTarget:self action:@selector(billingFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [lastNameColumn addArrangedSubview:self.lastNameField];
    [lastNameColumn addArrangedSubview:self.lastNameErrorLabel];

    [nameRow addArrangedSubview:firstNameColumn];
    [nameRow addArrangedSubview:lastNameColumn];
    [container addSubview:nameRow];

    self.addressLine1Field = [self c2pTextFieldWithPlaceholder:@"Street address 1" identifier:@"c2p_merchant_address1"];
    [container addSubview:self.addressLine1Field];
    self.addressLine2Field = [self c2pTextFieldWithPlaceholder:@"Street address 2 (optional)" identifier:@"c2p_merchant_address2"];
    [container addSubview:self.addressLine2Field];
    self.countryField = [self c2pTextFieldWithPlaceholder:@"Country (ISO)" identifier:@"c2p_merchant_country"];
    [container addSubview:self.countryField];
    self.cityField = [self c2pTextFieldWithPlaceholder:@"City" identifier:@"c2p_merchant_city"];
    [container addSubview:self.cityField];

    UIStackView *stateZipRow = [[UIStackView alloc] init];
    stateZipRow.translatesAutoresizingMaskIntoConstraints = NO;
    stateZipRow.axis = UILayoutConstraintAxisHorizontal;
    stateZipRow.spacing = [ThemeHelper spacingSM];
    stateZipRow.distribution = UIStackViewDistributionFillEqually;
    self.stateField = [self c2pTextFieldWithPlaceholder:@"State" identifier:@"c2p_merchant_state"];
    self.zipField = [self c2pTextFieldWithPlaceholder:@"ZIP" identifier:@"c2p_merchant_zip"];
    self.zipField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    [stateZipRow addArrangedSubview:self.stateField];
    [stateZipRow addArrangedSubview:self.zipField];
    [container addSubview:stateZipRow];

    UILabel *copyLabel = [[UILabel alloc] init];
    copyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    copyLabel.text = @"Copy billing to shipping on tokenize";
    copyLabel.font = [ThemeHelper bodyFont];
    copyLabel.textColor = [ThemeHelper textColor];
    [container addSubview:copyLabel];
    self.billingToShippingSwitch = [[UISwitch alloc] init];
    self.billingToShippingSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.billingToShippingSwitch.on = YES;
    [container addSubview:self.billingToShippingSwitch];

    NSArray<UIView *> *stackedFields = @[
        nameRow, self.addressLine1Field, self.addressLine2Field, self.countryField, self.cityField, stateZipRow
    ];
    UIView *previous = hintLabel;
    for (UIView *field in stackedFields) {
        [NSLayoutConstraint activateConstraints:@[
            [field.topAnchor constraintEqualToAnchor:previous.bottomAnchor constant:[ThemeHelper spacingMD]],
            [field.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [field.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        ]];
        previous = field;
    }

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [hintLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [hintLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [hintLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [copyLabel.topAnchor constraintEqualToAnchor:previous.bottomAnchor constant:[ThemeHelper spacingMD]],
        [copyLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.billingToShippingSwitch.centerYAnchor constraintEqualToAnchor:copyLabel.centerYAnchor],
        [self.billingToShippingSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [copyLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
    ]];
    return container;
}

- (UILabel *)c2pFieldErrorLabel {
    UILabel *label = [[UILabel alloc] init];
    label.font = [ThemeHelper captionFont];
    label.textColor = [ThemeHelper errorColor];
    label.numberOfLines = 0;
    label.hidden = YES;
    return label;
}

- (UITextField *)c2pTextFieldWithPlaceholder:(NSString *)placeholder identifier:(NSString *)identifier {
    UITextField *field = [[UITextField alloc] init];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.placeholder = placeholder;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.accessibilityIdentifier = identifier;
    return field;
}

- (NSString *)trimmedTextFromField:(UITextField *)field {
    return [field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)nonEmptyTrimmedTextFromField:(UITextField *)field {
    NSString *trimmed = [self trimmedTextFromField:field];
    return trimmed.length > 0 ? trimmed : nil;
}

- (ClickToPayTokenizeBilling *)tokenizeBillingFromFormWithEmail:(NSString *)email {
    ClickToPayTokenizeBilling *billing = [[ClickToPayTokenizeBilling alloc] init];
    billing.email = email;
    billing.firstName = [self nonEmptyTrimmedTextFromField:self.firstNameField];
    billing.lastName = [self nonEmptyTrimmedTextFromField:self.lastNameField];
    billing.phoneNumber = [self nonEmptyTrimmedTextFromField:self.phoneNumberField];
    billing.addressLine1 = [self nonEmptyTrimmedTextFromField:self.addressLine1Field];
    billing.addressLine2 = [self nonEmptyTrimmedTextFromField:self.addressLine2Field];
    billing.city = [self nonEmptyTrimmedTextFromField:self.cityField];
    billing.state = [self nonEmptyTrimmedTextFromField:self.stateField];
    billing.zip = [self nonEmptyTrimmedTextFromField:self.zipField];
    billing.country = [self nonEmptyTrimmedTextFromField:self.countryField];
    billing.month = nil;
    billing.year = nil;
    if (self.billingToShippingSwitch.isOn) {
        billing.shippingAddressLine1 = billing.addressLine1;
        billing.shippingAddressLine2 = billing.addressLine2;
        billing.shippingCity = billing.city;
        billing.shippingState = billing.state;
        billing.shippingZip = billing.zip;
        billing.shippingCountry = billing.country;
        billing.shippingPhoneNumber = billing.phoneNumber;
    }
    return billing;
}

#pragma mark - UI Updates

- (void)productTapped:(UITapGestureRecognizer *)gesture {
    C2PProduct *product = objc_getAssociatedObject(gesture.view, "product");
    if (!product) { return; }
    self.selectedProduct = product;
    [self hideResultMessages];
    [self updateProductSelection];
    [self updatePayButtonState];
}

- (void)updateProductSelection {
    for (UIStackView *rowStack in self.productsStackView.arrangedSubviews) {
        if (![rowStack isKindOfClass:[UIStackView class]]) { continue; }
        for (UIView *productView in rowStack.arrangedSubviews) {
            C2PProduct *product = objc_getAssociatedObject(productView, "product");
            if (!product) { continue; }
            BOOL isSelected = (self.selectedProduct && [self.selectedProduct.productId isEqualToString:product.productId]);
            productView.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
            productView.layer.borderWidth = isSelected ? 2 : 0;
            productView.layer.borderColor = isSelected ? [ThemeHelper primaryColor].CGColor : nil;
        }
    }

    if (self.selectedProduct) {
        self.totalAmountLabel.hidden = NO;
        self.totalAmountLabel.text = [NSString stringWithFormat:@"Total Amount: %@", [self.selectedProduct formattedPriceUSD]];
    } else {
        self.totalAmountLabel.hidden = YES;
        self.totalAmountLabel.text = nil;
    }
}

- (void)emailFieldChanged {
    [self refreshCustomerIdentityValidity];
    [self updatePayButtonState];
}

- (void)phoneFieldChanged {
    self.phoneCountryField.text = [self digitsOnlyFromString:self.phoneCountryField.text];
    self.phoneNumberField.text = [self digitsOnlyFromString:self.phoneNumberField.text];
    [self refreshCustomerIdentityValidity];
    [self updatePayButtonState];
}

- (void)refreshCustomerIdentityValidity {
    if (self.contactValidationAttempted
        || !self.emailErrorLabel.hidden
        || !self.phoneErrorLabel.hidden) {
        [self validateCustomerIdentity];
    }
}

- (BOOL)validateCustomerIdentity {
    NSString *trimmedEmail = [self trimmedTextFromField:self.emailField];
    NSString *phone = [self trimmedTextFromField:self.phoneNumberField];
    NSString *countryCode = [self trimmedTextFromField:self.phoneCountryField];

    BOOL hasValidEmail = trimmedEmail.length > 0 && [EmailValidator isValid:trimmedEmail];
    BOOL hasPhoneLookup = phone.length > 0 && countryCode.length > 0;
    BOOL partialPhone = (phone.length > 0) ^ (countryCode.length > 0);

    if (hasValidEmail || hasPhoneLookup) {
        self.emailErrorLabel.hidden = YES;
        self.emailErrorLabel.text = nil;
        self.phoneErrorLabel.hidden = YES;
        self.phoneErrorLabel.text = nil;
        return YES;
    }

    if (trimmedEmail.length > 0 && ![EmailValidator isValid:trimmedEmail]) {
        self.emailErrorLabel.text = @"Invalid email format";
        self.emailErrorLabel.hidden = !self.contactValidationAttempted;
    } else {
        self.emailErrorLabel.hidden = YES;
        self.emailErrorLabel.text = nil;
    }

    self.phoneErrorLabel.text = partialPhone
        ? @"Country code and mobile number are both required for phone lookup"
        : @"Email or phone with country code is required";
    self.phoneErrorLabel.hidden = !self.contactValidationAttempted;
    return NO;
}

- (BOOL)hasValidCustomerIdentity {
    return [ClickToPayPaymentFlowViewController hasValidCustomerIdentityWithEmail:self.emailField.text
                                                                    phoneNumber:self.phoneNumberField.text
                                                                phoneCountryCode:self.phoneCountryField.text];
}

+ (BOOL)hasValidCustomerIdentityWithEmail:(NSString *)email
                              phoneNumber:(NSString *)phoneNumber
                          phoneCountryCode:(NSString *)phoneCountryCode {
    NSString *trimmedEmail = [email stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    ClickToPayCustomer *customer = [[ClickToPayCustomer alloc] initWithEmail:trimmedEmail.length > 0 ? trimmedEmail : nil
                                                                 phoneNumber:phoneNumber.length > 0 ? phoneNumber : nil
                                                                 countryCode:phoneCountryCode.length > 0 ? phoneCountryCode : nil
                                                            mainLookupMethod:ClickToPayMainLookupMethodEmail];
    BOOL emailValid = trimmedEmail.length == 0 || [EmailValidator isValid:trimmedEmail];
    return emailValid && [customer isValidForLookup];
}

- (NSString *)digitsOnlyFromString:(NSString *)value {
    if (value.length == 0) { return @""; }
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [[value componentsSeparatedByCharactersInSet:nonDigits] componentsJoinedByString:@""];
}

- (void)billingFieldChanged {
    if (!self.firstNameErrorLabel.hidden) {
        [self validateBillingNames];
    } else if (!self.lastNameErrorLabel.hidden) {
        [self validateBillingNames];
    }
    [self updatePayButtonState];
}

- (BOOL)validateBillingNames {
    BOOL firstValid = [self trimmedTextFromField:self.firstNameField].length > 0;
    BOOL lastValid = [self trimmedTextFromField:self.lastNameField].length > 0;

    if (firstValid) {
        self.firstNameErrorLabel.hidden = YES;
        self.firstNameErrorLabel.text = nil;
    } else {
        self.firstNameErrorLabel.text = @"First name is required";
        self.firstNameErrorLabel.hidden = NO;
    }

    if (lastValid) {
        self.lastNameErrorLabel.hidden = YES;
        self.lastNameErrorLabel.text = nil;
    } else {
        self.lastNameErrorLabel.text = @"Last name is required";
        self.lastNameErrorLabel.hidden = NO;
    }

    return firstValid && lastValid;
}

- (BOOL)hasValidBillingNames {
    return [self trimmedTextFromField:self.firstNameField].length > 0
        && [self trimmedTextFromField:self.lastNameField].length > 0;
}

- (BOOL)isPayEnabled {
    return self.selectedProduct != nil
        && !self.isLoadingSignature
        && self.stage == C2PMerchantStageIdle;
}

- (BOOL)validateMerchantContactOnPay {
    self.contactValidationAttempted = YES;
    BOOL identityValid = [self validateCustomerIdentity];
    BOOL namesValid = [self validateBillingNames];
    return identityValid && namesValid;
}

- (void)updatePayButtonState {
    BOOL enabled = [self isPayEnabled];
    self.payButton.enabled = enabled;
    self.payButton.alpha = enabled ? 1.0 : 0.6;
    self.payButton.backgroundColor = enabled ? [ThemeHelper primaryColor] : [ThemeHelper borderColor];

    if (self.isLoadingSignature) {
        [self.paySpinner startAnimating];
    } else {
        [self.paySpinner stopAnimating];
    }

    NSString *title = @"Pay with Click to Pay";
    if (self.selectedProduct) {
        title = [NSString stringWithFormat:@"Pay %@ with Click to Pay", [self.selectedProduct formattedPriceUSD]];
    }
    [self.payButton setTitle:title forState:UIControlStateNormal];
    [self.payButton setTitle:title forState:UIControlStateDisabled];
    [self updateStageIndicator];
}

- (void)updateStatusSection {
    self.flowPhaseLabel.text = [NSString stringWithFormat:@"SDK phase: %@", self.flowPhaseText ?: @"idle"];
    self.flowMessageLabel.text = self.flowMessageText ?: @"Ready";
}

- (void)updateStageIndicator {
    NSArray<NSString *> *stepNames = @[@"Idle", @"Checkout", @"Tokenize"];
    NSInteger currentStep = (NSInteger)self.stage;
    for (NSInteger i = 0; i < (NSInteger)stepNames.count; i++) {
        BOOL isActive = (i <= currentStep);
        BOOL isCompleted = (i < currentStep);
        UIView *circle = [self.stageIndicatorContainer viewWithTag:kC2PStageCircleTagBase + i];
        if (circle) {
            circle.backgroundColor = isActive ? [ThemeHelper primaryColor] : c2pStageDisabledColor();
        }
        UILabel *numberLabel = [self.stageIndicatorContainer viewWithTag:kC2PStageNumberTagBase + i];
        if ([numberLabel isKindOfClass:[UILabel class]]) {
            numberLabel.text = isCompleted ? @"✓" : [NSString stringWithFormat:@"%ld", (long)(i + 1)];
            numberLabel.font = isCompleted ? [UIFont systemFontOfSize:10 weight:UIFontWeightBold] : [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        }
        UILabel *stepLabel = [self.stageIndicatorContainer viewWithTag:kC2PStageLabelTagBase + i];
        if ([stepLabel isKindOfClass:[UILabel class]]) {
            stepLabel.textColor = isActive ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
        }
        if (i > 0) {
            UIView *line = [self.stageIndicatorContainer viewWithTag:kC2PStageLineTagBase + (i - 1)];
            if (line) {
                line.backgroundColor = (i <= currentStep) ? [ThemeHelper primaryColor] : c2pStageDisabledColor();
            }
        }
    }
}

- (void)hideResultMessages {
    self.resultContainer.hidden = YES;
    self.errorContainer.hidden = YES;
    self.successLabel.text = nil;
    self.errorLabel.text = nil;
}

- (void)showSuccess:(NSString *)message {
    self.successLabel.text = [NSString stringWithFormat:@"Payment successful\n%@", message];
    self.resultContainer.hidden = NO;
    self.errorContainer.hidden = YES;
    self.errorLabel.text = nil;
}

- (void)showError:(NSString *)message {
    self.errorLabel.text = [NSString stringWithFormat:@"Payment failed\n%@", message];
    self.errorContainer.hidden = NO;
}

#pragma mark - Actions

- (void)payTapped {
    if (self.isLoadingSignature) { return; }
    if (!self.selectedProduct) {
        [self showError:@"Please select a product"];
        return;
    }

    NSString *email = [self.emailField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![self validateMerchantContactOnPay]) {
        return;
    }

    NSString *dpaId = [self sandboxSrcDpaId];
    if (dpaId.length == 0) {
        [self showError:@"Missing SpreedlyC2PSandboxSrcDpaId in Info.plist."];
        return;
    }

    [self hideResultMessages];
    self.isLoadingSignature = YES;
    [self updatePayButtonState];

    __weak typeof(self) weakSelf = self;
    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) { return; }
            self.isLoadingSignature = NO;
            [self updatePayButtonState];
            if (!success) {
                [self showError:error.localizedDescription ?: @"Failed to refresh auth params"];
                return;
            }
            [self presentCheckoutWithEmail:email dpaId:dpaId];
        });
    }];
}

- (void)presentCheckoutWithEmail:(NSString *)email dpaId:(NSString *)dpaId {
    C2PProduct *product = self.selectedProduct;
    if (!product) {
        [self showError:@"Please select a product"];
        return;
    }

    NSDecimalNumber *amountCents = [product.price decimalNumberByMultiplyingBy:[AppConstants centsPerDollar]];
    NSInteger cents = amountCents.integerValue;

    ClickToPayInitConfig *initConfig = [[ClickToPayInitConfig alloc] initWithAmountCents:cents
                                                                transactionCurrencyCode:@"USD"];
    ClickToPayCheckoutConfig *config = [[ClickToPayCheckoutConfig alloc] init];
    config.initConfig = initConfig;
    config.srcDpaId = dpaId;
    config.locale = kC2PLocale;
    config.isSandbox = YES;
    config.dpaPresentationName = kC2PDpaPresentationName;
    config.dpaName = kC2PDpaName;
    NSString *phone = [self trimmedTextFromField:self.phoneNumberField];
    NSString *countryCode = [self trimmedTextFromField:self.phoneCountryField];
    config.customer = [[ClickToPayCustomer alloc] initWithEmail:email
                                                    phoneNumber:phone.length > 0 ? phone : nil
                                                    countryCode:countryCode.length > 0 ? countryCode : nil
                                               mainLookupMethod:ClickToPayMainLookupMethodEmail];
    config.doLookup = YES;
    config.tokenizeBilling = [self tokenizeBillingFromFormWithEmail:email];

    self.stage = C2PMerchantStageCheckout;
    self.flowPhaseText = @"checkoutInProgress";
    self.flowMessageText = @"Opening Click to Pay checkout";
    [self updateStageIndicator];
    [self updateStatusSection];

    SpreedlyClickToPayCheckout.delegate = self;
    [SpreedlyClickToPayCheckout presentWithConfig:config from:self];
}

#pragma mark - ClickToPayDelegate

- (void)clickToPay:(ClickToPayCheckoutViewController * _Nullable)checkout
   didReceiveEvent:(ClickToPayEventKind)event
          userInfo:(NSDictionary * _Nullable)userInfo {
    NSString *eventName = [self eventNameForKind:event];
    self.flowPhaseText = eventName;
    self.flowMessageText = [NSString stringWithFormat:@"Received %@ event", eventName];
    [self updateStatusSection];

    switch (event) {
        case ClickToPayEventKindCheckoutComplete:
            self.stage = C2PMerchantStageTokenizing;
            self.flowPhaseText = @"tokenizing";
            self.flowMessageText = @"Checkout complete — tokenizing payment method";
            [self updateStageIndicator];
            [self updateStatusSection];
            break;
        case ClickToPayEventKindCheckoutCancelled:
            if (self.stage == C2PMerchantStageCheckout) {
                [self resetFlowWithError:@"Checkout was canceled."];
            }
            break;
        case ClickToPayEventKindCheckoutError: {
            NSString *actionCode = userInfo[@"actionCode"];
            NSString *message = actionCode.length > 0
                ? [NSString stringWithFormat:@"Checkout error (%@).", actionCode]
                : @"Checkout error.";
            if (self.stage != C2PMerchantStageIdle) {
                [self resetFlowWithError:message];
            }
            break;
        }
        case ClickToPayEventKindSessionDeleted:
            if (self.stage == C2PMerchantStageCheckout || self.stage == C2PMerchantStageTokenizing) {
                [self resetFlowToIdle];
            }
            break;
        case ClickToPayEventKindError:
        case ClickToPayEventKindValidationErrors: {
            NSString *message = nil;
            if (event == ClickToPayEventKindValidationErrors) {
                NSArray *errors = userInfo[@"errors"];
                NSDictionary *first = [errors isKindOfClass:[NSArray class]] ? errors.firstObject : nil;
                if ([first isKindOfClass:[NSDictionary class]]) {
                    message = first[@"message"];
                }
            }
            if (message.length == 0) {
                message = userInfo[@"message"];
            }
            if (message.length == 0) {
                message = @"Click to Pay checkout failed.";
            }
            if (self.stage != C2PMerchantStageIdle) {
                [self resetFlowWithError:message];
            }
            break;
        }
        default:
            break;
    }
}

- (NSString *)eventNameForKind:(ClickToPayEventKind)kind {
    switch (kind) {
        case ClickToPayEventKindCheckoutStarted: return @"checkoutStarted";
        case ClickToPayEventKindInitialized: return @"initialized";
        case ClickToPayEventKindNewUser: return @"newUser";
        case ClickToPayEventKindExistingUser: return @"existingUser";
        case ClickToPayEventKindVerifiedUser: return @"verifiedUser";
        case ClickToPayEventKindOtpInitiated: return @"otpInitiated";
        case ClickToPayEventKindOtpResponse: return @"otpResponse";
        case ClickToPayEventKindOtpResend: return @"otpResend";
        case ClickToPayEventKindOtpNotYou: return @"otpNotYou";
        case ClickToPayEventKindDisplayCardsReady: return @"displayCardsReady";
        case ClickToPayEventKindAddNewCard: return @"addNewCard";
        case ClickToPayEventKindCheckoutWindowOpened: return @"checkoutWindowOpened";
        case ClickToPayEventKindCheckoutWindowClosed: return @"checkoutWindowClosed";
        case ClickToPayEventKindCheckoutCancelled: return @"checkoutCancelled";
        case ClickToPayEventKindCheckoutDifferentPaymentMethod: return @"checkoutDifferentPaymentMethod";
        case ClickToPayEventKindCheckoutError: return @"checkoutError";
        case ClickToPayEventKindSessionDeleted: return @"sessionDeleted";
        case ClickToPayEventKindCheckoutComplete: return @"checkoutComplete";
        case ClickToPayEventKindPaymentMethodTokenized: return @"paymentMethodTokenized";
        case ClickToPayEventKindError: return @"error";
        case ClickToPayEventKindValidationErrors: return @"validationErrors";
        case ClickToPayEventKindOtpChannelSelectionRequired: return @"otpChannelSelectionRequired";
    }
}

#pragma mark - SpreedlyPaymentDelegate

- (void)paymentDidComplete:(PaymentResult *)result {
    if (result.isSuccess && result.token.length > 0) {
        NSString *masked = [Spreedly maskedToken:result.token];
        [self showSuccess:[NSString stringWithFormat:@"Payment method tokenized: %@", masked]];
        self.stage = C2PMerchantStageIdle;
        self.flowPhaseText = @"finished";
        self.flowMessageText = @"Ready";
        [self updateStageIndicator];
        [self updateStatusSection];
        return;
    }

    if (result.failureDetails.message.length > 0 && self.stage != C2PMerchantStageIdle) {
        [self resetFlowWithError:result.failureDetails.message];
    }
}

- (void)resetFlowWithError:(NSString *)message {
    self.stage = C2PMerchantStageIdle;
    self.flowPhaseText = @"idle";
    self.flowMessageText = @"Ready";
    [self showError:message];
    [self updateStageIndicator];
    [self updateStatusSection];
}

- (void)resetFlowToIdle {
    [self hideResultMessages];
    self.stage = C2PMerchantStageIdle;
    self.flowPhaseText = @"idle";
    self.flowMessageText = @"Ready";
    [self updateStageIndicator];
    [self updateStatusSection];
}

@end
