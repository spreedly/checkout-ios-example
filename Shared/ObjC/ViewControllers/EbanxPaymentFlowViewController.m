//
//  EbanxPaymentFlowViewController.m
//  SpreedlySDKExampleObjectiveC
//

#import "EbanxPaymentFlowViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <objc/runtime.h>
#import "SpreedlyConfigManager.h"
#import "PurchaseAPIClient.h"
#import "PurchaseModels.h"
#import "AppConstants.h"
#import "ThemeHelper.h"

typedef NS_ENUM(NSInteger, EbanxStage) {
    EbanxStageIdle = 0,
    EbanxStageCreatingPaymentMethod,
    EbanxStagePurchasing,
    EbanxStageCheckout
};

@interface EbanxProduct : NSObject
@property (nonatomic, strong) NSString *productId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, strong) NSString *productDescription;
@property (nonatomic, strong) NSString *iconName;
- (NSString *)formattedPriceWithCurrency:(NSString *)currencyCode;
@end

@implementation EbanxProduct
- (NSString *)formattedPriceWithCurrency:(NSString *)currencyCode {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = currencyCode;
    return [formatter stringFromNumber:self.price] ?: [NSString stringWithFormat:@"%@ %@", currencyCode, self.price];
}
@end

@interface EbanxPaymentFlowViewController () <SpreedlyPaymentDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *headerSection;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerDescriptionLabel;
@property (nonatomic, strong) UIView *stageIndicatorContainer;
@property (nonatomic, strong) UIView *productSelectionContainer;
@property (nonatomic, strong) UIStackView *productsStackView;
@property (nonatomic, strong) UIView *totalAmountContainer;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UILabel *successLabel;
@property (nonatomic, strong) UIView *errorContainer;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, assign) EbanxStage stage;
@property (nonatomic, strong) NSString *transactionToken;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) NSArray<EbanxProduct *> *products;
@property (nonatomic, strong) EbanxProduct *selectedProduct;
@property (nonatomic, assign) OffsitePaymentMethodType selectedProvider;
@property (nonatomic, strong) UIView *providerSelectionContainer;
@property (nonatomic, strong) UIStackView *providerStackView;

@end

@implementation EbanxPaymentFlowViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"EBANX Payment Flow";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.stage = EbanxStageIdle;
    self.isLoading = NO;
    self.selectedProduct = nil;
    self.selectedProvider = OffsitePaymentMethodTypePix;
    self.products = [self buildProducts];

    [Spreedly shared].paymentDelegate = self;

    [self setupUI];
    [self updateProviderSelection];
    [self updateStartButtonState];
    [self updateStageIndicator];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self cleanupPaymentDelegate];
}

- (void)dealloc {
    [self cleanupPaymentDelegate];
}

- (void)cleanupPaymentDelegate {
    if ([Spreedly shared].paymentDelegate == self) {
        [Spreedly shared].paymentDelegate = nil;
    }
}

#pragma mark - Currency

- (NSString *)currentCurrencyCode {
    return (self.selectedProvider == OffsitePaymentMethodTypeOxxo) ? CurrencyCodeMXN : CurrencyCodeBRL;
}

- (NSString *)currentCurrencySymbol {
    return (self.selectedProvider == OffsitePaymentMethodTypeOxxo) ? @"MXN" : @"BRL";
}

#pragma mark - Products

- (NSArray<EbanxProduct *> *)buildProducts {
    return @[
        [self productWithId:@"prod_1" name:@"Wireless Earbuds" price:@"99" description:@"Premium wireless earbuds" iconName:@"airpods"],
        [self productWithId:@"prod_2" name:@"Smart Watch" price:@"0.44" description:@"Feature-rich smartwatch" iconName:@"applewatch"],
        [self productWithId:@"prod_3" name:@"Tablet" price:@"699" description:@"High-performance tablet" iconName:@"ipad"],
        [self productWithId:@"prod_4" name:@"Laptop" price:@"400" description:@"Powerful laptop" iconName:@"laptopcomputer"],
        [self productWithId:@"prod_5" name:@"Smart Speaker" price:@"299" description:@"Voice-controlled speaker" iconName:@"speaker.wave.3"],
        [self productWithId:@"prod_6" name:@"Gaming Console" price:@"399" description:@"Next-gen gaming console" iconName:@"gamecontroller"]
    ];
}

- (EbanxProduct *)productWithId:(NSString *)productId name:(NSString *)name price:(NSString *)price description:(NSString *)desc iconName:(NSString *)iconName {
    EbanxProduct *p = [[EbanxProduct alloc] init];
    p.productId = productId;
    p.name = name;
    p.price = [NSDecimalNumber decimalNumberWithString:price];
    p.productDescription = desc;
    p.iconName = iconName;
    return p;
}

#pragma mark - UI Setup

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    // Header
    self.headerSection = [[UIView alloc] init];
    self.headerSection.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerSection.backgroundColor = [ThemeHelper surfaceColor];
    self.headerSection.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    self.headerSection.layer.borderColor = [ThemeHelper borderColor].CGColor;
    self.headerSection.layer.borderWidth = 1.0;
    [ThemeHelper applySmallShadowToView:self.headerSection];
    [self.contentView addSubview:self.headerSection];

    self.headerTitleLabel = [[UILabel alloc] init];
    self.headerTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerTitleLabel.text = @"EBANX Payment Flow";
    self.headerTitleLabel.font = [ThemeHelper titleFont];
    self.headerTitleLabel.textColor = [ThemeHelper textColor];
    self.headerTitleLabel.accessibilityIdentifier = @"ebanx-payment-title";
    self.headerTitleLabel.accessibilityLabel = @"EBANX Payment Flow";
    self.headerTitleLabel.accessibilityHint = @"EBANX payment flow screen";
    self.headerTitleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.headerSection addSubview:self.headerTitleLabel];

    self.headerDescriptionLabel = [[UILabel alloc] init];
    self.headerDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerDescriptionLabel.text = @"Create EBANX offsite payment method, purchase, and complete checkout.";
    self.headerDescriptionLabel.font = [ThemeHelper bodyFont];
    self.headerDescriptionLabel.textColor = [ThemeHelper textSecondaryColor];
    self.headerDescriptionLabel.numberOfLines = 0;
    self.headerDescriptionLabel.accessibilityIdentifier = @"ebanx-payment-description";
    self.headerDescriptionLabel.accessibilityLabel = @"Create EBANX offsite payment and complete checkout";
    [self.headerSection addSubview:self.headerDescriptionLabel];

    // Stage indicator
    self.stageIndicatorContainer = [self createStageIndicatorContainer];
    [self.contentView addSubview:self.stageIndicatorContainer];

    // Product selection
    self.productSelectionContainer = [self createProductSelectionContainer];
    [self.contentView addSubview:self.productSelectionContainer];

    // Provider selection
    self.providerSelectionContainer = [self createProviderSelectionContainer];
    [self.contentView addSubview:self.providerSelectionContainer];

    // Start button
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"Start EBANX Flow" forState:UIControlStateNormal];
    [self.startButton setTitle:@"Processing..." forState:UIControlStateDisabled];
    self.startButton.titleLabel.font = [ThemeHelper buttonFont];
    self.startButton.backgroundColor = [ThemeHelper primaryColor];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateDisabled];
    self.startButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.startButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.startButton.enabled = NO;
    self.startButton.alpha = 0.6;
    [self.startButton addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];
    self.startButton.accessibilityIdentifier = @"ebanx-payment-start-button";
    self.startButton.accessibilityLabel = @"Start EBANX Flow";
    self.startButton.accessibilityHint = @"Tap to start EBANX payment flow";
    [self.contentView addSubview:self.startButton];

    // Loading indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];

    // Success container
    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.resultContainer.hidden = YES;
    self.resultContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:self.resultContainer];
    [self.contentView addSubview:self.resultContainer];

    self.successLabel = [[UILabel alloc] init];
    self.successLabel.textColor = [ThemeHelper successColor];
    self.successLabel.font = [ThemeHelper bodyFont];
    self.successLabel.numberOfLines = 0;
    self.successLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultContainer.accessibilityIdentifier = @"ebanx-payment-success-title";
    self.successLabel.accessibilityIdentifier = @"ebanx-payment-success-message";
    self.successLabel.accessibilityLabel = @"Success";
    [self.resultContainer addSubview:self.successLabel];

    // Error container
    self.errorContainer = [[UIView alloc] init];
    self.errorContainer.backgroundColor = [[ThemeHelper errorColor] colorWithAlphaComponent:0.1];
    self.errorContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.errorContainer.hidden = YES;
    self.errorContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorContainer.accessibilityIdentifier = @"ebanx-payment-error-container";
    [ThemeHelper applySmallShadowToView:self.errorContainer];
    [self.contentView addSubview:self.errorContainer];

    UIStackView *errorStack = [[UIStackView alloc] init];
    errorStack.axis = UILayoutConstraintAxisVertical;
    errorStack.spacing = [ThemeHelper spacingSM];
    errorStack.alignment = UIStackViewAlignmentLeading;
    errorStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.errorContainer addSubview:errorStack];

    UIStackView *errorHeader = [[UIStackView alloc] init];
    errorHeader.axis = UILayoutConstraintAxisHorizontal;
    errorHeader.spacing = [ThemeHelper spacingSM];
    errorHeader.alignment = UIStackViewAlignmentCenter;
    errorHeader.translatesAutoresizingMaskIntoConstraints = NO;
    [errorStack addArrangedSubview:errorHeader];

    UIImageView *errorIcon = [[UIImageView alloc] init];
    errorIcon.image = [UIImage systemImageNamed:@"exclamationmark.circle.fill"];
    errorIcon.tintColor = [ThemeHelper errorColor];
    errorIcon.translatesAutoresizingMaskIntoConstraints = NO;
    errorIcon.accessibilityIdentifier = @"ebanx-payment-error-icon";
    errorIcon.accessibilityLabel = @"Error";
    [errorHeader addArrangedSubview:errorIcon];

    UILabel *errorTitle = [[UILabel alloc] init];
    errorTitle.text = @"Error";
    errorTitle.font = [ThemeHelper subtitleFont];
    errorTitle.textColor = [ThemeHelper errorColor];
    errorTitle.translatesAutoresizingMaskIntoConstraints = NO;
    errorTitle.accessibilityIdentifier = @"ebanx-payment-error-title";
    errorTitle.accessibilityLabel = @"Error";
    [errorHeader addArrangedSubview:errorTitle];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.textColor = [ThemeHelper textColor];
    self.errorLabel.font = [ThemeHelper bodyFont];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.accessibilityIdentifier = @"ebanx-payment-error-message";
    self.errorLabel.accessibilityHint = @"Error message from EBANX payment process";
    [errorStack addArrangedSubview:self.errorLabel];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],

        [self.headerSection.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:[ThemeHelper spacingLG]],
        [self.headerSection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.headerSection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.headerTitleLabel.topAnchor constraintEqualToAnchor:self.headerSection.topAnchor constant:[ThemeHelper spacingMD]],
        [self.headerTitleLabel.leadingAnchor constraintEqualToAnchor:self.headerSection.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.headerTitleLabel.trailingAnchor constraintEqualToAnchor:self.headerSection.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.headerDescriptionLabel.topAnchor constraintEqualToAnchor:self.headerTitleLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [self.headerDescriptionLabel.leadingAnchor constraintEqualToAnchor:self.headerSection.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.headerDescriptionLabel.trailingAnchor constraintEqualToAnchor:self.headerSection.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.headerDescriptionLabel.bottomAnchor constraintEqualToAnchor:self.headerSection.bottomAnchor constant:-[ThemeHelper spacingMD]],

        [self.stageIndicatorContainer.topAnchor constraintEqualToAnchor:self.headerSection.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.stageIndicatorContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.stageIndicatorContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.productSelectionContainer.topAnchor constraintEqualToAnchor:self.stageIndicatorContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.productSelectionContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.productSelectionContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.providerSelectionContainer.topAnchor constraintEqualToAnchor:self.productSelectionContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.providerSelectionContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.providerSelectionContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.startButton.topAnchor constraintEqualToAnchor:self.providerSelectionContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.startButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.startButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.startButton.heightAnchor constraintEqualToConstant:48],

        [self.resultContainer.topAnchor constraintEqualToAnchor:self.startButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.startButton.leadingAnchor],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.startButton.trailingAnchor],

        [self.successLabel.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:12],
        [self.successLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:12],
        [self.successLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-12],
        [self.successLabel.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-12],

        [self.errorContainer.topAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:12],
        [self.errorContainer.leadingAnchor constraintEqualToAnchor:self.startButton.leadingAnchor],
        [self.errorContainer.trailingAnchor constraintEqualToAnchor:self.startButton.trailingAnchor],
        [self.errorContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],

        [errorStack.topAnchor constraintEqualToAnchor:self.errorContainer.topAnchor constant:12],
        [errorStack.leadingAnchor constraintEqualToAnchor:self.errorContainer.leadingAnchor constant:12],
        [errorStack.trailingAnchor constraintEqualToAnchor:self.errorContainer.trailingAnchor constant:-12],
        [errorStack.bottomAnchor constraintEqualToAnchor:self.errorContainer.bottomAnchor constant:-12],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

#pragma mark - Stage Indicator

static UIColor *ebanxStageDisabledColor(void) {
    return [UIColor colorWithRed:0.678 green:0.710 blue:0.741 alpha:1.0];
}

static const NSInteger kEbanxStageCircleTagBase = 500;
static const NSInteger kEbanxStageLabelTagBase  = 600;
static const NSInteger kEbanxStageLineTagBase   = 700;

- (UIView *)createStageIndicatorContainer {
    NSArray<NSString *> *stepNames = @[@"Idle", @"Tokenize", @"Purchase", @"Checkout"];

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

    [NSLayoutConstraint activateConstraints:@[
        [stepsStack.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [stepsStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingSM]],
        [stepsStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingSM]],
        [stepsStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];

    for (NSInteger i = 0; i < (NSInteger)stepNames.count; i++) {
        BOOL isActive = (i <= (NSInteger)self.stage);
        BOOL isCompleted = (i < (NSInteger)self.stage);

        UIView *stepColumn = [[UIView alloc] init];
        stepColumn.translatesAutoresizingMaskIntoConstraints = NO;

        UIView *circle = [[UIView alloc] init];
        circle.tag = kEbanxStageCircleTagBase + i;
        circle.backgroundColor = isActive ? [ThemeHelper primaryColor] : ebanxStageDisabledColor();
        circle.layer.cornerRadius = 12;
        circle.translatesAutoresizingMaskIntoConstraints = NO;
        [stepColumn addSubview:circle];

        UILabel *numberLabel = [[UILabel alloc] init];
        numberLabel.tag = kEbanxStageCircleTagBase + 100 + i;
        numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        numberLabel.textColor = [UIColor whiteColor];
        numberLabel.textAlignment = NSTextAlignmentCenter;
        numberLabel.translatesAutoresizingMaskIntoConstraints = NO;
        if (isCompleted) {
            numberLabel.text = @"✓";
            numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        } else {
            numberLabel.text = [NSString stringWithFormat:@"%ld", (long)(i + 1)];
        }
        [circle addSubview:numberLabel];

        UILabel *stepLabel = [[UILabel alloc] init];
        stepLabel.tag = kEbanxStageLabelTagBase + i;
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
            [stepLabel.bottomAnchor constraintEqualToAnchor:stepColumn.bottomAnchor]
        ]];

        [stepsStack addArrangedSubview:stepColumn];
    }

    [container layoutIfNeeded];

    for (NSInteger i = 0; i < (NSInteger)stepNames.count - 1; i++) {
        BOOL lineActive = (i < (NSInteger)self.stage);
        UIView *currentCircle = [container viewWithTag:kEbanxStageCircleTagBase + i];
        UIView *nextCircle = [container viewWithTag:kEbanxStageCircleTagBase + (i + 1)];

        UIView *line = [[UIView alloc] init];
        line.tag = kEbanxStageLineTagBase + i;
        line.backgroundColor = lineActive ? [ThemeHelper primaryColor] : ebanxStageDisabledColor();
        line.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:line];

        [NSLayoutConstraint activateConstraints:@[
            [line.leadingAnchor constraintEqualToAnchor:currentCircle.trailingAnchor constant:4],
            [line.trailingAnchor constraintEqualToAnchor:nextCircle.leadingAnchor constant:-4],
            [line.centerYAnchor constraintEqualToAnchor:currentCircle.centerYAnchor],
            [line.heightAnchor constraintEqualToConstant:2]
        ]];
    }

    return container;
}

- (void)updateStageIndicator {
    NSArray<NSString *> *stepNames = @[@"Idle", @"Tokenize", @"Purchase", @"Checkout"];
    NSInteger currentStep = (NSInteger)self.stage;

    for (NSInteger i = 0; i < (NSInteger)stepNames.count; i++) {
        BOOL isActive = (i <= currentStep);
        BOOL isCompleted = (i < currentStep);

        UIView *circle = [self.stageIndicatorContainer viewWithTag:kEbanxStageCircleTagBase + i];
        circle.backgroundColor = isActive ? [ThemeHelper primaryColor] : ebanxStageDisabledColor();

        UILabel *numberLabel = [self.stageIndicatorContainer viewWithTag:kEbanxStageCircleTagBase + 100 + i];
        if (isCompleted) {
            numberLabel.text = @"✓";
            numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        } else {
            numberLabel.text = [NSString stringWithFormat:@"%ld", (long)(i + 1)];
            numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        }

        UILabel *stepLabel = [self.stageIndicatorContainer viewWithTag:kEbanxStageLabelTagBase + i];
        stepLabel.textColor = isActive ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];

        if (i > 0) {
            UIView *line = [self.stageIndicatorContainer viewWithTag:kEbanxStageLineTagBase + (i - 1)];
            line.backgroundColor = (i <= currentStep) ? [ThemeHelper primaryColor] : ebanxStageDisabledColor();
        }
    }
}

#pragma mark - Product Selection

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
    [container addSubview:titleLabel];

    self.productsStackView = [[UIStackView alloc] init];
    self.productsStackView.axis = UILayoutConstraintAxisVertical;
    self.productsStackView.spacing = [ThemeHelper spacingMD];
    self.productsStackView.distribution = UIStackViewDistributionFillEqually;
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

    self.totalAmountContainer = [[UIView alloc] init];
    self.totalAmountContainer.hidden = YES;
    self.totalAmountContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.totalAmountContainer];

    UIView *divider = [[UIView alloc] init];
    divider.backgroundColor = [ThemeHelper borderColor];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.totalAmountContainer addSubview:divider];

    UILabel *totalLabel = [[UILabel alloc] init];
    totalLabel.text = @"Total Amount:";
    totalLabel.font = [ThemeHelper subtitleFont];
    totalLabel.textColor = [ThemeHelper textColor];
    totalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.totalAmountContainer addSubview:totalLabel];

    UILabel *amountLabel = [[UILabel alloc] init];
    amountLabel.tag = 999;
    amountLabel.font = [ThemeHelper subtitleFont];
    amountLabel.textColor = [ThemeHelper merchantProductPriceColor];
    amountLabel.textAlignment = NSTextAlignmentRight;
    amountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.totalAmountContainer addSubview:amountLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.productsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.productsStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.productsStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.totalAmountContainer.topAnchor constraintEqualToAnchor:self.productsStackView.bottomAnchor constant:[ThemeHelper spacingSM]],
        [self.totalAmountContainer.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.totalAmountContainer.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.totalAmountContainer.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]],
        [divider.topAnchor constraintEqualToAnchor:self.totalAmountContainer.topAnchor],
        [divider.leadingAnchor constraintEqualToAnchor:self.totalAmountContainer.leadingAnchor],
        [divider.trailingAnchor constraintEqualToAnchor:self.totalAmountContainer.trailingAnchor],
        [divider.heightAnchor constraintEqualToConstant:1],
        [totalLabel.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:[ThemeHelper spacingSM]],
        [totalLabel.leadingAnchor constraintEqualToAnchor:self.totalAmountContainer.leadingAnchor],
        [totalLabel.bottomAnchor constraintEqualToAnchor:self.totalAmountContainer.bottomAnchor],
        [amountLabel.centerYAnchor constraintEqualToAnchor:totalLabel.centerYAnchor],
        [amountLabel.trailingAnchor constraintEqualToAnchor:self.totalAmountContainer.trailingAnchor],
        [amountLabel.leadingAnchor constraintEqualToAnchor:totalLabel.trailingAnchor constant:[ThemeHelper spacingSM]]
    ]];

    return container;
}

- (UIView *)createProductView:(EbanxProduct *)product {
    BOOL isSelected = (self.selectedProduct && [self.selectedProduct.productId isEqualToString:product.productId]);
    UIView *productView = [[UIView alloc] init];
    productView.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
    productView.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    if (isSelected) {
        productView.layer.borderWidth = 2;
        productView.layer.borderColor = [ThemeHelper primaryColor].CGColor;
    } else {
        productView.layer.borderWidth = 0;
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

    UIStackView *textStack = [[UIStackView alloc] init];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = [ThemeHelper spacingXS];
    textStack.alignment = UIStackViewAlignmentCenter;

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = product.name;
    nameLabel.font = [ThemeHelper captionFont];
    nameLabel.textColor = [ThemeHelper textColor];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.numberOfLines = 2;
    [textStack addArrangedSubview:nameLabel];

    UILabel *priceLabel = [[UILabel alloc] init];
    priceLabel.text = [product formattedPriceWithCurrency:[self currentCurrencyCode]];
    priceLabel.font = [ThemeHelper subtitleFont];
    priceLabel.textColor = [ThemeHelper merchantProductPriceColor];
    [textStack addArrangedSubview:priceLabel];
    [contentStack addArrangedSubview:textStack];

    UIImageView *checkView = [[UIImageView alloc] init];
    checkView.image = [UIImage systemImageNamed:isSelected ? @"checkmark.circle.fill" : @"circle"];
    checkView.tintColor = isSelected ? [ThemeHelper primaryColor] : [UIColor clearColor];
    [contentStack addArrangedSubview:checkView];

    [NSLayoutConstraint activateConstraints:@[
        [contentStack.topAnchor constraintEqualToAnchor:productView.topAnchor constant:[ThemeHelper spacingMD]],
        [contentStack.leadingAnchor constraintEqualToAnchor:productView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [contentStack.trailingAnchor constraintEqualToAnchor:productView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [contentStack.bottomAnchor constraintEqualToAnchor:productView.bottomAnchor constant:-[ThemeHelper spacingMD]],
        [iconView.heightAnchor constraintEqualToConstant:30],
        [productView.heightAnchor constraintEqualToConstant:140]
    ]];
    return productView;
}

- (void)productTapped:(UITapGestureRecognizer *)gesture {
    EbanxProduct *product = objc_getAssociatedObject(gesture.view, "product");
    if (product) {
        self.selectedProduct = product;
        [self updateProductSelection];
        [self updateStartButtonState];
    }
}

- (void)updateProductSelection {
    for (UIStackView *rowStack in self.productsStackView.arrangedSubviews) {
        for (UIView *productView in rowStack.arrangedSubviews) {
            EbanxProduct *product = objc_getAssociatedObject(productView, "product");
            if (product) {
                BOOL isSelected = (self.selectedProduct && [self.selectedProduct.productId isEqualToString:product.productId]);
                productView.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
                productView.layer.borderWidth = isSelected ? 2 : 0;
                productView.layer.borderColor = isSelected ? [ThemeHelper primaryColor].CGColor : nil;
            }
        }
    }
    self.totalAmountContainer.hidden = (self.selectedProduct == nil);
    if (self.selectedProduct) {
        UILabel *amountLabel = [self.totalAmountContainer viewWithTag:999];
        amountLabel.text = [self.selectedProduct formattedPriceWithCurrency:[self currentCurrencyCode]];
    }
}

#pragma mark - Provider Selection

- (UIView *)createProviderSelectionContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Select EBANX payment method";
    titleLabel.font = [ThemeHelper subtitleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"ebanx-payment-provider-section-title";
    titleLabel.accessibilityLabel = @"Select EBANX payment method";
    titleLabel.accessibilityHint = @"Section title for EBANX payment method selection";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];

    self.providerStackView = [[UIStackView alloc] init];
    self.providerStackView.axis = UILayoutConstraintAxisVertical;
    self.providerStackView.spacing = [ThemeHelper spacingSM];
    self.providerStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.providerStackView];

    UIView *pixRow = [self createProviderRowWithTitle:@"Pix"
                                             subtitle:@"Pay with QR code via banking app (Brazil)"
                                             iconName:@"qrcode"
                                         providerType:OffsitePaymentMethodTypePix
                              accessibilityIdentifier:@"ebanx-payment-provider-row-pix"
                                   accessibilityLabel:@"Pix, Pay with QR code via banking app"
                                    accessibilityHint:@"Select Pix as payment method"];

    UIView *boletoRow = [self createProviderRowWithTitle:@"Boleto Bancario"
                                               subtitle:@"Pay with bank slip at bank or ATM (Brazil)"
                                               iconName:@"doc.text"
                                           providerType:OffsitePaymentMethodTypeBoletoBancario
                                accessibilityIdentifier:@"ebanx-payment-provider-row-boleto"
                                     accessibilityLabel:@"Boleto Bancario, Pay at bank or ATM"
                                      accessibilityHint:@"Select Boleto Bancario as payment method"];

    UIView *oxxoRow = [self createProviderRowWithTitle:@"OXXO"
                                              subtitle:@"Pay with cash at any OXXO store (Mexico)"
                                              iconName:@"banknote"
                                          providerType:OffsitePaymentMethodTypeOxxo
                               accessibilityIdentifier:@"ebanx-payment-provider-row-oxxo"
                                    accessibilityLabel:@"OXXO, Pay with cash at OXXO store"
                                     accessibilityHint:@"Select OXXO as payment method"];

    UIView *nupayRow = [self createProviderRowWithTitle:@"NuPay"
                                              subtitle:@"Pay via Nubank app (Brazil)"
                                              iconName:@"iphone"
                                          providerType:OffsitePaymentMethodTypeNupay
                               accessibilityIdentifier:@"ebanx-payment-provider-row-nupay"
                                    accessibilityLabel:@"NuPay, Pay via Nubank app"
                                     accessibilityHint:@"Select NuPay as payment method"];

    [self.providerStackView addArrangedSubview:pixRow];
    [self.providerStackView addArrangedSubview:boletoRow];
    [self.providerStackView addArrangedSubview:oxxoRow];
    [self.providerStackView addArrangedSubview:nupayRow];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.providerStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.providerStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.providerStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.providerStackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]],
        [pixRow.heightAnchor constraintGreaterThanOrEqualToConstant:56],
        [boletoRow.heightAnchor constraintGreaterThanOrEqualToConstant:56],
        [oxxoRow.heightAnchor constraintGreaterThanOrEqualToConstant:56],
        [nupayRow.heightAnchor constraintGreaterThanOrEqualToConstant:56]
    ]];

    return container;
}

- (UIView *)createProviderRowWithTitle:(NSString *)title subtitle:(NSString *)subtitle iconName:(NSString *)iconName providerType:(OffsitePaymentMethodType)providerType accessibilityIdentifier:(NSString *)accessibilityIdentifier accessibilityLabel:(NSString *)accessibilityLabel accessibilityHint:(NSString *)accessibilityHint {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [ThemeHelper cellBackgroundColor];
    row.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.accessibilityIdentifier = accessibilityIdentifier;
    row.accessibilityLabel = accessibilityLabel;
    row.accessibilityHint = accessibilityHint;
    row.isAccessibilityElement = YES;
    row.accessibilityTraits = UIAccessibilityTraitButton;
    objc_setAssociatedObject(row, "providerType", @(providerType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(providerTapped:)];
    [row addGestureRecognizer:tap];
    row.userInteractionEnabled = YES;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.image = [UIImage systemImageNamed:iconName];
    iconView.tintColor = [ThemeHelper textSecondaryColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tag = 99;
    [row addSubview:iconView];

    UIStackView *textStack = [[UIStackView alloc] init];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = [ThemeHelper spacingXS];
    textStack.alignment = UIStackViewAlignmentLeading;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:textStack];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [ThemeHelper subtitleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [textStack addArrangedSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [ThemeHelper captionFont];
    subtitleLabel.textColor = [ThemeHelper textSecondaryColor];
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [textStack addArrangedSubview:subtitleLabel];

    UIImageView *checkView = [[UIImageView alloc] init];
    checkView.image = [UIImage systemImageNamed:@"circle"];
    checkView.tintColor = [ThemeHelper textSecondaryColor];
    checkView.translatesAutoresizingMaskIntoConstraints = NO;
    checkView.tag = 100;
    [row addSubview:checkView];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:[ThemeHelper spacingMD]],
        [iconView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:32],
        [iconView.heightAnchor constraintEqualToConstant:32],
        [textStack.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:[ThemeHelper spacingMD]],
        [textStack.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [textStack.trailingAnchor constraintLessThanOrEqualToAnchor:checkView.leadingAnchor constant:-[ThemeHelper spacingMD]],
        [checkView.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [checkView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [checkView.widthAnchor constraintEqualToConstant:24],
        [checkView.heightAnchor constraintEqualToConstant:24]
    ]];

    return row;
}

- (void)providerTapped:(UITapGestureRecognizer *)gesture {
    NSNumber *num = objc_getAssociatedObject(gesture.view, "providerType");
    if (num) {
        self.selectedProvider = (OffsitePaymentMethodType)[num integerValue];
        [self updateProviderSelection];
        [self updateProductSelection];
        [self updateStartButtonState];
    }
}

- (void)updateProviderSelection {
    for (UIView *row in self.providerStackView.arrangedSubviews) {
        NSNumber *num = objc_getAssociatedObject(row, "providerType");
        BOOL isSelected = num && (OffsitePaymentMethodType)[num integerValue] == self.selectedProvider;
        row.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
        row.layer.borderWidth = isSelected ? 2 : 0;
        row.layer.borderColor = isSelected ? [ThemeHelper primaryColor].CGColor : nil;
        if (isSelected) {
            row.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitSelected;
        } else {
            row.accessibilityTraits = UIAccessibilityTraitButton;
        }
        UIImageView *iconView = [row viewWithTag:99];
        if ([iconView isKindOfClass:[UIImageView class]]) {
            iconView.tintColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
        }
        UIImageView *checkView = [row viewWithTag:100];
        if ([checkView isKindOfClass:[UIImageView class]]) {
            checkView.image = [UIImage systemImageNamed:isSelected ? @"checkmark.circle.fill" : @"circle"];
            checkView.tintColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
        }
    }
}

#pragma mark - Button State

- (NSString *)buttonTitle {
    if (!self.selectedProduct) {
        return @"Select a product";
    }
    switch (self.stage) {
        case EbanxStageIdle:
            return [NSString stringWithFormat:@"Pay %@ %.2f", [self currentCurrencySymbol], self.selectedProduct.price.doubleValue];
        case EbanxStageCreatingPaymentMethod:
            return @"Creating payment method...";
        case EbanxStagePurchasing:
            return @"Processing purchase...";
        case EbanxStageCheckout:
            return @"Waiting for checkout...";
    }
}

- (void)updateStartButtonState {
    BOOL shouldEnable = (self.selectedProduct != nil && !self.isLoading);
    self.startButton.enabled = shouldEnable;
    self.startButton.userInteractionEnabled = shouldEnable;
    if (shouldEnable) {
        self.startButton.backgroundColor = [ThemeHelper primaryColor];
        self.startButton.alpha = 1.0;
    } else {
        self.startButton.backgroundColor = [[ThemeHelper primaryColor] colorWithAlphaComponent:0.6];
        self.startButton.alpha = 0.6;
    }
    NSString *title = [self buttonTitle];
    [self.startButton setTitle:title forState:UIControlStateNormal];
    [self.startButton setTitle:title forState:UIControlStateDisabled];
    [self updateStageIndicator];
}

#pragma mark - Start Flow

- (void)startTapped {
    if (!self.selectedProduct) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.stage = EbanxStageCreatingPaymentMethod;
        self.isLoading = YES;
        [self updateStartButtonState];
        [self.loadingIndicator startAnimating];
        [self hideResultMessages];
    });

    __weak typeof(self) weakSelf = self;
    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (!success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showErrorMessage:@"Failed to generate signature"];
                self.stage = EbanxStageIdle;
                self.isLoading = NO;
                [self updateStartButtonState];
                [self.loadingIndicator stopAnimating];
            });
            return;
        }

        OffsitePaymentConfig *config = [self buildOffsitePaymentConfig];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[Spreedly shared] submitOffsitePaymentWithConfig:config];
        });
    }];
}

- (OffsitePaymentConfig *)buildOffsitePaymentConfig {
    switch (self.selectedProvider) {
        case OffsitePaymentMethodTypeOxxo:
            return [[OffsitePaymentConfig alloc]
                initWithPaymentMethodType:OffsitePaymentMethodTypeOxxo
                redirectUrl:nil
                email:@"test@test.com"
                fullName:@"Manuela E. Beyer Rocabado"
                firstName:nil lastName:nil documentId:nil
                country:@"MX" countryCode:nil
                phoneNumber:@"(040) 577-7687"
                address1:@"Oyono, 882" address2:nil
                city:@"Hermosillo" state:@"Sonora" zip:@"48822"];

        case OffsitePaymentMethodTypeNupay: {
            DocumentId *documentId = [[DocumentId alloc] initWithKey:DocumentIdKeyDocumentId
                                                               value:@"853.513.468-93"
                                                           customKey:nil];
            return [[OffsitePaymentConfig alloc]
                initWithPaymentMethodType:OffsitePaymentMethodTypeNupay
                redirectUrl:nil
                email:@"test@test.com"
                fullName:@"Ana Santos Araujo"
                firstName:nil lastName:nil
                documentId:documentId
                country:@"BR" countryCode:nil
                phoneNumber:@"8522847035"
                address1:nil address2:nil
                city:nil state:nil zip:nil];
        }

        default: {
            DocumentId *documentId = [[DocumentId alloc] initWithKey:DocumentIdKeyDocumentId
                                                               value:@"853.513.468-93"
                                                           customKey:nil];
            return [[OffsitePaymentConfig alloc]
                initWithPaymentMethodType:self.selectedProvider
                redirectUrl:nil
                email:@"test@test.com"
                fullName:@"Ana Santos Araujo"
                firstName:nil lastName:nil
                documentId:documentId
                country:@"BR" countryCode:nil
                phoneNumber:@"8522847035"
                address1:@"Rua E, 1040" address2:nil
                city:@"Maracanaú" state:@"CE" zip:@"12345"];
        }
    }
}

#pragma mark - SpreedlyPaymentDelegate (same messaging as Stripe APM)

- (void)paymentDidComplete:(PaymentResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.stage == EbanxStageCreatingPaymentMethod) {
            if (result.isSuccess && result.token.length > 0) {
                self.stage = EbanxStagePurchasing;
                [self updateStartButtonState];
                [self purchaseWithToken:result.token];
            } else {
                NSString *detail = result.failureDetails ? [result.failureDetails getDescription] : nil;
                NSString *msg = detail ? [NSString stringWithFormat:@"Failed to create payment method: %@", detail] : @"Failed to create payment method";
                [self showErrorMessage:msg];
                self.stage = EbanxStageIdle;
                self.isLoading = NO;
                [self updateStartButtonState];
                [self.loadingIndicator stopAnimating];
            }
            return;
        }

        if (self.stage == EbanxStageCheckout) {
            NSString *methodName = [self ebanxMethodDisplayName];
            if (result.isSuccess) {
                if ([result.state isEqualToString:@"processing"]) {
                    [self showPendingMessage:@"Payment accepted and is being processed. Final confirmation may take a few days."];
                } else if ([result.state isEqualToString:@"pending"]) {
                    [self showPendingMessage:@"Payment submitted. Awaiting final confirmation from the payment provider."];
                } else {
                    [self showSuccessMessage:@"Payment successful. The transaction has been completed."];
                }
            } else if (result.isFailure) {
                NSString *errorMsg = nil;
                if ([result.state isEqualToString:@"pending"]) {
                    [self showPendingMessage:@"Payment submitted. Awaiting final confirmation from the payment provider."];
                } else if ([result.state isEqualToString:@"processing"]) {
                    [self showPendingMessage:@"Payment accepted and is being processed. Final confirmation may take a few days."];
                } else if ([result.state isEqualToString:@"gateway_processing_failed"]) {
                    errorMsg = [NSString stringWithFormat:@"We couldn't complete your %@ payment. Please try again.", methodName];
                    [self showErrorMessage:errorMsg];
                } else {
                    NSString *desc = (result.failureDetails ? [result.failureDetails getDescription] : nil) ?: [NSString stringWithFormat:@"%@ payment failed.", methodName];
                    if ([desc rangeOfString:@"canceled" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        [self showErrorMessage:[NSString stringWithFormat:@"%@ payment was canceled.", methodName]];
                    } else {
                        [self showErrorMessage:desc];
                    }
                }
            }
            self.stage = EbanxStageIdle;
            self.isLoading = NO;
            [self updateStartButtonState];
            [self.loadingIndicator stopAnimating];
        }
    });
}

#pragma mark - Purchase

- (void)purchaseWithToken:(NSString *)paymentMethodToken {
    if (!self.selectedProduct) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showErrorMessage:@"Please select a product"];
            self.stage = EbanxStageIdle;
            self.isLoading = NO;
            [self updateStartButtonState];
            [self.loadingIndicator stopAnimating];
        });
        return;
    }

    NSDecimalNumber *priceInDollars = self.selectedProduct.price;
    NSDecimalNumber *amountInCents = [priceInDollars decimalNumberByMultiplyingBy:[AppConstants centsPerDollar]];
    NSString *redirectUrl = @"spreedlyCApp://com.spreedly-example.sdk.SpreedlySDKExampleObjectiveC/ebanx/checkout";
    NSString *callbackUrl = @"https://www.google.com/";
    NSString *currency = [self currentCurrencyCode];
    NSString *document = (self.selectedProvider == OffsitePaymentMethodTypeOxxo) ? nil : @"853.513.468-93";

    __weak typeof(self) weakSelf = self;
    PurchaseAPIClient *client = [[SpreedlyConfigManager shared] createPurchaseAPIClient];
    [client ebanxPurchaseWithPaymentMethodToken:paymentMethodToken
                                         amount:amountInCents
                                   currencyCode:currency
                                    redirectUrl:redirectUrl
                                    callbackUrl:callbackUrl
                                       document:document
                                     completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !response || !response.transaction) {
                NSString *errMsg = nil;
                if (error) {
                    if ([error.localizedDescription isEqualToString:@"gateway_setup_failed"]) {
                        errMsg = @"Purchase failed while setting up a transaction";
                    } else {
                        errMsg = error.localizedDescription.length > 0
                            ? [NSString stringWithFormat:@"Purchase failed: %@", error.localizedDescription]
                            : @"Purchase failed";
                    }
                } else {
                    errMsg = @"Purchase failed while setting up a transaction";
                }
                [self showErrorMessage:errMsg];
                self.stage = EbanxStageIdle;
                self.isLoading = NO;
                [self updateStartButtonState];
                [self.loadingIndicator stopAnimating];
                return;
            }

            self.transactionToken = response.transaction.token;
            self.stage = EbanxStageCheckout;
            self.isLoading = NO;
            [self updateStartButtonState];
            [self.loadingIndicator stopAnimating];

            [SpreedlyOffsiteCheckout presentWithTransactionToken:self.transactionToken];
        });
    }];
}

#pragma mark - Display Name (matches Swift ebanxMethodDisplayName)

- (NSString *)ebanxMethodDisplayName {
    switch (self.selectedProvider) {
        case OffsitePaymentMethodTypePix: return @"Pix";
        case OffsitePaymentMethodTypeBoletoBancario: return @"Boleto Bancario";
        case OffsitePaymentMethodTypeOxxo: return @"OXXO";
        case OffsitePaymentMethodTypeNupay: return @"NuPay";
        default: return @"Pix";
    }
}

#pragma mark - Result Messages

- (void)showSuccessMessage:(NSString *)message {
    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.successLabel.textColor = [ThemeHelper successColor];
    self.resultContainer.hidden = NO;
    self.successLabel.text = message;
    self.errorContainer.hidden = YES;
}

- (void)showPendingMessage:(NSString *)message {
    self.resultContainer.backgroundColor = [[ThemeHelper warningColor] colorWithAlphaComponent:0.1];
    self.successLabel.textColor = [ThemeHelper warningColor];
    self.resultContainer.hidden = NO;
    self.successLabel.text = message;
    self.errorContainer.hidden = YES;
}

- (void)showErrorMessage:(NSString *)message {
    self.resultContainer.hidden = YES;
    self.errorContainer.hidden = NO;
    self.errorLabel.text = message;
}

- (void)hideResultMessages {
    self.resultContainer.hidden = YES;
    self.errorContainer.hidden = YES;
    self.successLabel.text = @"";
    self.errorLabel.text = @"";
}

@end
