//
//  StripeAPMPaymentFlowViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  Flow: Merchant creates pending purchase (Spreedly API) -> SDK presents PaymentSheet -> Merchant handles result via delegate.
//  Mirrors Swift StripeAPMPaymentFlowView.
//

#import "StripeAPMPaymentFlowViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <SpreedlyStripeAPM/SpreedlyStripeAPM-Swift.h>
#import "SpreedlyConfigManager.h"
#import "PurchaseAPIClient.h"
#import "PurchaseModels.h"
#import "AppConstants.h"
#import "ThemeHelper.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, StripeAPMStage) {
    StripeAPMStageIdle = 0,
    StripeAPMStageCreatingPendingPurchase,
    StripeAPMStageCheckout
};

@interface StripeAPMProduct : NSObject
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, copy) NSString *iconName;
- (NSString *)formattedPriceEUR;
@end
@implementation StripeAPMProduct
- (NSString *)formattedPriceEUR {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = @"EUR";
    return [formatter stringFromNumber:self.price] ?: [NSString stringWithFormat:@"EUR %@", self.price];
}
@end

static NSString * const kStripeAPMReturnURL = @"spreedlyCApp://stripe-redirect";
static NSString * const kStripeAPMRedirectURL = @"https://spreedly.com/stripe-apm/redirect";
static NSString * const kExampleCallbackURL = @"https://www.google.com/";

static UIColor *stripeAPMStageDisabledColor(void) {
    return [UIColor colorWithRed:0.678 green:0.710 blue:0.741 alpha:1.0];
}
static const NSInteger kStripeAPMStageCircleTagBase = 500;
static const NSInteger kStripeAPMStageNumberTagBase  = 600;
static const NSInteger kStripeAPMStageLabelTagBase   = 700;
static const NSInteger kStripeAPMStageLineTagBase    = 800;

@interface StripeAPMPaymentFlowViewController () <SpreedlyPaymentDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *headerSection;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerDescriptionLabel;
@property (nonatomic, strong) UIView *stageIndicatorContainer;
@property (nonatomic, strong) UIView *productSelectionContainer;
@property (nonatomic, strong) UIStackView *productsStackView;
@property (nonatomic, strong) UIView *totalAmountContainer;
@property (nonatomic, strong) UIView *apmSelectionContainer;
@property (nonatomic, strong) UIStackView *apmTypesStackView;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UILabel *successLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UIView *errorContainer;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, assign) StripeAPMStage stage;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) NSArray<StripeAPMProduct *> *products;
@property (nonatomic, strong) StripeAPMProduct *selectedProduct;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedAPMTypes;
@end

@implementation StripeAPMPaymentFlowViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Stripe APM";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.stage = StripeAPMStageIdle;
    self.isLoading = NO;
    self.selectedProduct = nil;
    self.selectedAPMTypes = [NSMutableSet setWithObjects:@"ideal", nil];
    self.products = [self buildProducts];

    [Spreedly shared].paymentDelegate = self;
    [self setupUI];
    [self updateProductSelection];
    [self updateAPMSelection];
    [self updateStartButtonState];
}

- (void)dealloc {
    if ([Spreedly shared].paymentDelegate == self) {
        [Spreedly shared].paymentDelegate = nil;
    }
}

- (NSArray<StripeAPMProduct *> *)buildProducts {
    return @[
        [self productWithId:@"prod_1" name:@"Wireless Earbuds" price:@"99" iconName:@"airpods"],
        [self productWithId:@"prod_2" name:@"Smart Watch" price:@"0.44" iconName:@"applewatch"],
        [self productWithId:@"prod_3" name:@"Tablet" price:@"699" iconName:@"ipad"],
        [self productWithId:@"prod_4" name:@"Laptop" price:@"400" iconName:@"laptopcomputer"],
        [self productWithId:@"prod_5" name:@"Smart Speaker" price:@"299" iconName:@"speaker.wave.3"],
        [self productWithId:@"prod_6" name:@"Gaming Console" price:@"399" iconName:@"gamecontroller"]
    ];
}

- (StripeAPMProduct *)productWithId:(NSString *)productId name:(NSString *)name price:(NSString *)price iconName:(NSString *)iconName {
    StripeAPMProduct *p = [[StripeAPMProduct alloc] init];
    p.productId = productId;
    p.name = name;
    p.price = [NSDecimalNumber decimalNumberWithString:price];
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

    // Header (EBANX-style)
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
    self.headerTitleLabel.text = @"Stripe APM Payment Flow";
    self.headerTitleLabel.font = [ThemeHelper titleFont];
    self.headerTitleLabel.textColor = [ThemeHelper textColor];
    self.headerTitleLabel.accessibilityIdentifier = @"stripe-apm-payment-title";
    [self.headerSection addSubview:self.headerTitleLabel];

    self.headerDescriptionLabel = [[UILabel alloc] init];
    self.headerDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerDescriptionLabel.text = @"Create a pending purchase via Spreedly, then complete checkout using Stripe PaymentSheet.";
    self.headerDescriptionLabel.font = [ThemeHelper bodyFont];
    self.headerDescriptionLabel.textColor = [ThemeHelper textSecondaryColor];
    self.headerDescriptionLabel.numberOfLines = 0;
    [self.headerSection addSubview:self.headerDescriptionLabel];

    // Stage indicator (EBANX-style: circles, labels, connecting lines)
    self.stageIndicatorContainer = [self createStageIndicatorContainer];
    [self.contentView addSubview:self.stageIndicatorContainer];

    // Product selection (EBANX-style: 2-column grid + total amount)
    self.productSelectionContainer = [self createProductSelectionContainer];
    [self.contentView addSubview:self.productSelectionContainer];

    // APM types (EBANX-style: rows with icon, title, subtitle, checkmark)
    self.apmSelectionContainer = [self createAPMSelectionContainer];
    [self.contentView addSubview:self.apmSelectionContainer];

    // Start button
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"Start Stripe APM Flow" forState:UIControlStateNormal];
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
    self.startButton.accessibilityIdentifier = @"stripe-apm-payment-start-button";
    [self.contentView addSubview:self.startButton];

    // Loading indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];

    // Success container (EBANX-style: tinted background, shadow)
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
    [self.resultContainer addSubview:self.successLabel];

    // Error container (EBANX-style: icon + "Error" title + message)
    self.errorContainer = [[UIView alloc] init];
    self.errorContainer.backgroundColor = [[ThemeHelper errorColor] colorWithAlphaComponent:0.1];
    self.errorContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.errorContainer.hidden = YES;
    self.errorContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorContainer.accessibilityIdentifier = @"stripe-apm-payment-error-container";
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
    [errorHeader addArrangedSubview:errorIcon];

    UILabel *errorTitle = [[UILabel alloc] init];
    errorTitle.text = @"Error";
    errorTitle.font = [ThemeHelper subtitleFont];
    errorTitle.textColor = [ThemeHelper errorColor];
    errorTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [errorHeader addArrangedSubview:errorTitle];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.textColor = [ThemeHelper textColor];
    self.errorLabel.font = [ThemeHelper bodyFont];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [errorStack addArrangedSubview:self.errorLabel];

    // Constraints
    CGFloat spacing = [ThemeHelper spacingMD];
    CGFloat lg = [ThemeHelper spacingLG];
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

        [self.headerSection.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:lg],
        [self.headerSection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.headerSection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.headerTitleLabel.topAnchor constraintEqualToAnchor:self.headerSection.topAnchor constant:spacing],
        [self.headerTitleLabel.leadingAnchor constraintEqualToAnchor:self.headerSection.leadingAnchor constant:spacing],
        [self.headerTitleLabel.trailingAnchor constraintEqualToAnchor:self.headerSection.trailingAnchor constant:-spacing],
        [self.headerDescriptionLabel.topAnchor constraintEqualToAnchor:self.headerTitleLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [self.headerDescriptionLabel.leadingAnchor constraintEqualToAnchor:self.headerSection.leadingAnchor constant:spacing],
        [self.headerDescriptionLabel.trailingAnchor constraintEqualToAnchor:self.headerSection.trailingAnchor constant:-spacing],
        [self.headerDescriptionLabel.bottomAnchor constraintEqualToAnchor:self.headerSection.bottomAnchor constant:-spacing],

        [self.stageIndicatorContainer.topAnchor constraintEqualToAnchor:self.headerSection.bottomAnchor constant:lg],
        [self.stageIndicatorContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.stageIndicatorContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.productSelectionContainer.topAnchor constraintEqualToAnchor:self.stageIndicatorContainer.bottomAnchor constant:lg],
        [self.productSelectionContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.productSelectionContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.apmSelectionContainer.topAnchor constraintEqualToAnchor:self.productSelectionContainer.bottomAnchor constant:lg],
        [self.apmSelectionContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.apmSelectionContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],

        [self.startButton.topAnchor constraintEqualToAnchor:self.apmSelectionContainer.bottomAnchor constant:lg],
        [self.startButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.startButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],
        [self.startButton.heightAnchor constraintEqualToConstant:48],

        [self.resultContainer.topAnchor constraintEqualToAnchor:self.startButton.bottomAnchor constant:lg],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.startButton.leadingAnchor],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.startButton.trailingAnchor],
        [self.successLabel.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:12],
        [self.successLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:12],
        [self.successLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-12],
        [self.successLabel.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-12],

        [self.errorContainer.topAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:12],
        [self.errorContainer.leadingAnchor constraintEqualToAnchor:self.startButton.leadingAnchor],
        [self.errorContainer.trailingAnchor constraintEqualToAnchor:self.startButton.trailingAnchor],
        [self.errorContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-lg],
        [errorStack.topAnchor constraintEqualToAnchor:self.errorContainer.topAnchor constant:12],
        [errorStack.leadingAnchor constraintEqualToAnchor:self.errorContainer.leadingAnchor constant:12],
        [errorStack.trailingAnchor constraintEqualToAnchor:self.errorContainer.trailingAnchor constant:-12],
        [errorStack.bottomAnchor constraintEqualToAnchor:self.errorContainer.bottomAnchor constant:-12],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (UIView *)createStageIndicatorContainer {
    NSArray<NSString *> *stepNames = @[@"Idle", @"Pending Purchase", @"Checkout"];

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
        circle.tag = kStripeAPMStageCircleTagBase + i;
        circle.backgroundColor = isActive ? [ThemeHelper primaryColor] : stripeAPMStageDisabledColor();
        circle.layer.cornerRadius = 12;
        circle.translatesAutoresizingMaskIntoConstraints = NO;
        [stepColumn addSubview:circle];

        UILabel *numberLabel = [[UILabel alloc] init];
        numberLabel.tag = kStripeAPMStageNumberTagBase + i;
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
        stepLabel.tag = kStripeAPMStageLabelTagBase + i;
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

    [NSLayoutConstraint activateConstraints:@[
        [stepsStack.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [stepsStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingSM]],
        [stepsStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingSM]],
        [stepsStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];

    [container layoutIfNeeded];

    for (NSInteger i = 0; i < (NSInteger)stepNames.count - 1; i++) {
        UIView *currentCircle = [container viewWithTag:kStripeAPMStageCircleTagBase + i];
        UIView *nextCircle = [container viewWithTag:kStripeAPMStageCircleTagBase + (i + 1)];
        BOOL lineActive = (i < (NSInteger)self.stage);

        UIView *line = [[UIView alloc] init];
        line.tag = kStripeAPMStageLineTagBase + i;
        line.backgroundColor = lineActive ? [ThemeHelper primaryColor] : stripeAPMStageDisabledColor();
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
    amountLabel.textColor = [ThemeHelper primaryColor];
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

- (UIView *)createProductView:(StripeAPMProduct *)product {
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
    priceLabel.text = [product formattedPriceEUR];
    priceLabel.font = [ThemeHelper subtitleFont];
    priceLabel.textColor = [ThemeHelper primaryColor];
    [textStack addArrangedSubview:priceLabel];
    [contentStack addArrangedSubview:textStack];

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

- (UIView *)createAPMSelectionContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Select Stripe APM types";
    titleLabel.font = [ThemeHelper subtitleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"stripe-apm-provider-section-title";
    [container addSubview:titleLabel];

    self.apmTypesStackView = [[UIStackView alloc] init];
    self.apmTypesStackView.axis = UILayoutConstraintAxisVertical;
    self.apmTypesStackView.spacing = [ThemeHelper spacingSM];
    self.apmTypesStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.apmTypesStackView];

    UIView *idealRow = [self createAPMRowWithId:@"ideal" title:@"iDEAL" subtitle:@"Pay via iDEAL (Netherlands)" iconName:@"building.2"];
    UIView *bancontactRow = [self createAPMRowWithId:@"bancontact" title:@"Bancontact" subtitle:@"Pay via Bancontact (Belgium)" iconName:@"creditcard"];
    UIView *epsRow = [self createAPMRowWithId:@"eps" title:@"EPS" subtitle:@"Pay via EPS (Austria)" iconName:@"building.2"];
    UIView *p24Row = [self createAPMRowWithId:@"p24" title:@"Przelewy24 (P24)" subtitle:@"Pay via P24 (Poland)" iconName:@"creditcard"];
    UIView *sepaRow = [self createAPMRowWithId:@"sepa_debit" title:@"SEPA Debit" subtitle:@"Pay via SEPA Direct Debit (SEPA countries)" iconName:@"building.2"];
    [self.apmTypesStackView addArrangedSubview:idealRow];
    [self.apmTypesStackView addArrangedSubview:bancontactRow];
    [self.apmTypesStackView addArrangedSubview:epsRow];
    [self.apmTypesStackView addArrangedSubview:p24Row];
    [self.apmTypesStackView addArrangedSubview:sepaRow];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.apmTypesStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.apmTypesStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.apmTypesStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.apmTypesStackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]],
        [idealRow.heightAnchor constraintGreaterThanOrEqualToConstant:56],
        [bancontactRow.heightAnchor constraintGreaterThanOrEqualToConstant:56],
        [epsRow.heightAnchor constraintGreaterThanOrEqualToConstant:56],
        [p24Row.heightAnchor constraintGreaterThanOrEqualToConstant:56],
        [sepaRow.heightAnchor constraintGreaterThanOrEqualToConstant:56]
    ]];

    return container;
}

- (UIView *)createAPMRowWithId:(NSString *)apmId title:(NSString *)title subtitle:(NSString *)subtitle iconName:(NSString *)iconName {
    BOOL isSelected = [self.selectedAPMTypes containsObject:apmId];
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
    row.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    if (isSelected) {
        row.layer.borderWidth = 2;
        row.layer.borderColor = [ThemeHelper primaryColor].CGColor;
    }
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.accessibilityIdentifier = [NSString stringWithFormat:@"stripe-apm-provider-row-%@", apmId];
    row.isAccessibilityElement = YES;
    row.accessibilityTraits = UIAccessibilityTraitButton;
    objc_setAssociatedObject(row, "apmId", apmId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(apmTypeTapped:)];
    [row addGestureRecognizer:tap];
    row.userInteractionEnabled = YES;

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.image = [UIImage systemImageNamed:iconName];
    iconView.tintColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
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
    checkView.image = [UIImage systemImageNamed:isSelected ? @"checkmark.circle.fill" : @"circle"];
    checkView.tintColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
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

- (void)productTapped:(UITapGestureRecognizer *)gesture {
    StripeAPMProduct *product = objc_getAssociatedObject(gesture.view, "product");
    if (product) {
        self.selectedProduct = product;
        [self updateProductSelection];
        [self updateStartButtonState];
    }
}

- (void)apmTypeTapped:(UITapGestureRecognizer *)gesture {
    NSString *apmId = objc_getAssociatedObject(gesture.view, "apmId");
    if (apmId) {
        if ([self.selectedAPMTypes containsObject:apmId]) {
            [self.selectedAPMTypes removeObject:apmId];
        } else {
            [self.selectedAPMTypes addObject:apmId];
        }
        [self updateAPMSelection];
        [self updateStartButtonState];
    }
}

- (void)updateProductSelection {
    for (UIStackView *rowStack in self.productsStackView.arrangedSubviews) {
        if (![rowStack isKindOfClass:[UIStackView class]]) continue;
        for (UIView *productView in rowStack.arrangedSubviews) {
            StripeAPMProduct *product = objc_getAssociatedObject(productView, "product");
            if (product) {
                BOOL isSelected = (self.selectedProduct && [self.selectedProduct.productId isEqualToString:product.productId]);
                productView.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
                productView.layer.borderWidth = isSelected ? 2 : 0;
                productView.layer.borderColor = isSelected ? [ThemeHelper primaryColor].CGColor : nil;
                UIImageView *iconView = nil;
                for (UIView *sub in productView.subviews) {
                    if ([sub isKindOfClass:[UIStackView class]]) {
                        for (UIView *item in [(UIStackView *)sub arrangedSubviews]) {
                            if ([item isKindOfClass:[UIImageView class]]) {
                                iconView = (UIImageView *)item;
                                break;
                            }
                        }
                    }
                }
                if (iconView) iconView.tintColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
            }
        }
    }
    self.totalAmountContainer.hidden = (self.selectedProduct == nil);
    if (self.selectedProduct) {
        UILabel *amountLabel = [self.totalAmountContainer viewWithTag:999];
        if ([amountLabel isKindOfClass:[UILabel class]]) {
            amountLabel.text = [self.selectedProduct formattedPriceEUR];
        }
    }
}

- (void)updateAPMSelection {
    for (UIView *row in self.apmTypesStackView.arrangedSubviews) {
        NSString *apmId = objc_getAssociatedObject(row, "apmId");
        if (apmId) {
            BOOL isSelected = [self.selectedAPMTypes containsObject:apmId];
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
}

- (void)updateStartButtonState {
    BOOL enable = (self.selectedProduct != nil && self.selectedAPMTypes.count > 0 && !self.isLoading);
    self.startButton.enabled = enable;
    self.startButton.userInteractionEnabled = enable;
    if (enable) {
        self.startButton.backgroundColor = [ThemeHelper primaryColor];
        self.startButton.alpha = 1.0;
    } else {
        self.startButton.backgroundColor = [[ThemeHelper primaryColor] colorWithAlphaComponent:0.6];
        self.startButton.alpha = 0.6;
    }
    NSString *title = @"Select a product";
    if (self.selectedProduct) {
        switch (self.stage) {
            case StripeAPMStageIdle:
                title = [NSString stringWithFormat:@"Pay EUR %.2f", self.selectedProduct.price.doubleValue];
                break;
            case StripeAPMStageCreatingPendingPurchase:
                title = @"Creating pending purchase...";
                break;
            case StripeAPMStageCheckout:
                title = @"Completing checkout...";
                break;
        }
    }
    [self.startButton setTitle:title forState:UIControlStateNormal];
    [self.startButton setTitle:title forState:UIControlStateDisabled];
    [self updateStageIndicator];
}

- (void)updateStageIndicator {
    NSArray<NSString *> *stepNames = @[@"Idle", @"Pending Purchase", @"Checkout"];
    NSInteger currentStep = (NSInteger)self.stage;

    for (NSInteger i = 0; i < (NSInteger)stepNames.count; i++) {
        BOOL isActive = (i <= currentStep);
        BOOL isCompleted = (i < currentStep);

        UIView *circle = [self.stageIndicatorContainer viewWithTag:kStripeAPMStageCircleTagBase + i];
        if (circle) {
            circle.backgroundColor = isActive ? [ThemeHelper primaryColor] : stripeAPMStageDisabledColor();
        }

        UILabel *numberLabel = [self.stageIndicatorContainer viewWithTag:kStripeAPMStageNumberTagBase + i];
        if ([numberLabel isKindOfClass:[UILabel class]]) {
            if (isCompleted) {
                numberLabel.text = @"✓";
                numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
            } else {
                numberLabel.text = [NSString stringWithFormat:@"%ld", (long)(i + 1)];
                numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
            }
        }

        UILabel *stepLabel = [self.stageIndicatorContainer viewWithTag:kStripeAPMStageLabelTagBase + i];
        if ([stepLabel isKindOfClass:[UILabel class]]) {
            stepLabel.textColor = isActive ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
        }

        if (i > 0) {
            UIView *line = [self.stageIndicatorContainer viewWithTag:kStripeAPMStageLineTagBase + (i - 1)];
            if (line) {
                line.backgroundColor = (i <= currentStep) ? [ThemeHelper primaryColor] : stripeAPMStageDisabledColor();
            }
        }
    }
}

#pragma mark - Flow

- (void)startTapped {
    if (!self.selectedProduct || self.selectedAPMTypes.count == 0) return;

    self.stage = StripeAPMStageCreatingPendingPurchase;
    self.isLoading = YES;
    [self updateStartButtonState];
    [self.loadingIndicator startAnimating];
    [self hideResultMessages];

    NSDecimalNumber *amountInCents = [self.selectedProduct.price decimalNumberByMultiplyingBy:[AppConstants centsPerDollar]];
    NSArray<NSString *> *apmTypes = [self.selectedAPMTypes allObjects];

    __weak typeof(self) weakSelf = self;
    PurchaseAPIClient *client = [[SpreedlyConfigManager shared] createPurchaseAPIClient];
    [client stripeAPMPendingPurchaseWithAmount:amountInCents
                                 currencyCode:@"EUR"
                                  redirectUrl:kStripeAPMRedirectURL
                                 callbackUrl:kExampleCallbackURL
                                    apmTypes:apmTypes
                                  completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self showError:error.localizedDescription.length > 0 ? [NSString stringWithFormat:@"Pending purchase failed: %@", error.localizedDescription] : @"Pending purchase failed"];
                self.stage = StripeAPMStageIdle;
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                [self updateStartButtonState];
                return;
            }
            if (!response || !response.transaction) {
                [self showError:@"Failed to create pending purchase"];
                self.stage = StripeAPMStageIdle;
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                [self updateStartButtonState];
                return;
            }
            PurchaseTransaction *tx = response.transaction;
            if (![tx.state isEqualToString:@"pending"]) {
                [self showError:[NSString stringWithFormat:@"Transaction not in pending state: %@. Message: %@", tx.state ?: @"unknown", tx.message ?: @"none"]];
                self.stage = StripeAPMStageIdle;
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                [self updateStartButtonState];
                return;
            }
            NSString *clientSecret = tx.stripePaymentIntentClientSecret;
            if (!clientSecret.length) {
                [self showError:@"Missing client_secret in pending purchase response"];
                self.stage = StripeAPMStageIdle;
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                [self updateStartButtonState];
                return;
            }

            self.stage = StripeAPMStageCheckout;
            self.isLoading = NO;
            [self.loadingIndicator stopAnimating];
            [self updateStartButtonState];

            StripeAPMConfig *config = [[StripeAPMConfig alloc] initWithPublishableKey:[[SpreedlyConfigManager shared] stripePublishableKey]
                                                                        clientSecret:clientSecret
                                                                   transactionToken:tx.token
                                                                  merchantDisplayName:@"Spreedly Example"
                                                                              returnURL:kStripeAPMReturnURL];
            [SpreedlyStripeAPMCheckout presentWithConfig:config];
        });
    }];
}

- (void)showError:(NSString *)message {
    self.resultContainer.hidden = YES;
    self.errorContainer.hidden = NO;
    self.errorLabel.text = message;
}

- (void)showSuccess:(NSString *)message {
    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.successLabel.textColor = [ThemeHelper successColor];
    self.resultContainer.hidden = NO;
    self.successLabel.text = message;
    self.errorContainer.hidden = YES;
}

- (void)showPending:(NSString *)message {
    self.resultContainer.backgroundColor = [[ThemeHelper warningColor] colorWithAlphaComponent:0.1];
    self.successLabel.textColor = [ThemeHelper warningColor];
    self.resultContainer.hidden = NO;
    self.successLabel.text = message;
    self.errorContainer.hidden = YES;
}

- (void)hideResultMessages {
    self.resultContainer.hidden = YES;
    self.errorContainer.hidden = YES;
    self.successLabel.text = @"";
    self.errorLabel.text = @"";
}

#pragma mark - SpreedlyPaymentDelegate

- (void)paymentDidComplete:(PaymentResult *)result {
    if (self.stage != StripeAPMStageCheckout) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        self.stage = StripeAPMStageIdle;
        self.isLoading = NO;
        [self updateStartButtonState];

        if (result.isSuccess) {
            NSString *state = result.state ?: @"";
            if ([state isEqualToString:@"processing"]) {
                [self showPending:@"Payment accepted and is being processed. Final confirmation may take a few days."];
            } else if ([state isEqualToString:@"pending"]) {
                [self showPending:@"Payment submitted. Awaiting final confirmation from the payment provider."];
            } else {
                [self showSuccess:@"Payment successful. The transaction has been completed."];
            }
        } else {
            NSString *desc = [result.failureDetails getDescription] ?: @"Stripe APM payment failed.";
            if ([desc rangeOfString:@"canceled" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [self showError:@"Stripe APM payment was canceled."];
            } else {
                [self showError:desc];
            }
        }
    });
}

@end
