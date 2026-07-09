//
//  BraintreePaymentFlowViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  Braintree PayPal/Venmo flow: create purchase (Spreedly API) -> present Braintree checkout (SDK) -> confirm with nonce.
//  Mirrors Swift BraintreePaymentFlowView. Uses SpreedlyPaymentDelegate for result.
//

#import "BraintreePaymentFlowViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <SpreedlyBraintree/SpreedlyBraintree-Swift.h>
#import "SpreedlyConfigManager.h"
#import "PurchaseAPIClient.h"
#import "PurchaseModels.h"
#import "AppConstants.h"
#import "ThemeHelper.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, BraintreeStage) {
    BraintreeStageIdle = 0,
    BraintreeStageCreatingPurchase,
    BraintreeStageCheckout,
    BraintreeStageConfirming
};

@interface BraintreeProduct : NSObject
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, copy) NSString *iconName;
- (NSString *)formattedPriceUSD;
@end
@implementation BraintreeProduct
- (NSString *)formattedPriceUSD {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = @"USD";
    return [formatter stringFromNumber:self.price] ?: [NSString stringWithFormat:@"$%@", self.price];
}
@end

static UIColor *braintreeStageDisabledColor(void) {
    return [UIColor colorWithRed:0.678 green:0.710 blue:0.741 alpha:1.0];
}
static const NSInteger kBraintreeStageCircleTagBase = 900;
static const NSInteger kBraintreeStageNumberTagBase  = 1000;
static const NSInteger kBraintreeStageLabelTagBase   = 1100;
static const NSInteger kBraintreeStageLineTagBase   = 1200;

@interface BraintreePaymentFlowViewController () <SpreedlyPaymentDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *headerSection;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerDescriptionLabel;
@property (nonatomic, strong) UIView *stageIndicatorContainer;
@property (nonatomic, strong) UIView *productSelectionContainer;
@property (nonatomic, strong) UIStackView *productsStackView;
@property (nonatomic, strong) UIView *paymentTypeContainer;
@property (nonatomic, strong) UIStackView *paymentTypeStackView;
@property (nonatomic, strong) UIButton *payButton;
@property (nonatomic, strong) UILabel *successLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UIView *errorContainer;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, assign) BraintreeStage stage;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) NSArray<BraintreeProduct *> *products;
@property (nonatomic, strong) BraintreeProduct *selectedProduct;
@property (nonatomic, copy) NSString *selectedPaymentType;
@property (nonatomic, copy) NSString *pendingTransactionToken;
@property (nonatomic, copy) NSString *pendingPaymentType;
@end

@implementation BraintreePaymentFlowViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Braintree";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.stage = BraintreeStageIdle;
    self.isLoading = NO;
    self.selectedProduct = nil;
    self.selectedPaymentType = @"paypal";
    self.products = [self buildProducts];

    [Spreedly shared].paymentDelegate = self;
    [self setupUI];
    [self updateProductSelection];
    [self updatePaymentTypeSelection];
    [self updatePayButtonState];
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

- (NSArray<BraintreeProduct *> *)buildProducts {
    return @[
        [self productWithId:@"prod_1" name:@"Wireless Earbuds" price:@"99" iconName:@"airpods"],
        [self productWithId:@"prod_2" name:@"Smart Watch" price:@"0.44" iconName:@"applewatch"],
        [self productWithId:@"prod_3" name:@"Tablet" price:@"699" iconName:@"ipad"],
        [self productWithId:@"prod_4" name:@"Laptop" price:@"400" iconName:@"laptopcomputer"],
    ];
}

- (BraintreeProduct *)productWithId:(NSString *)productId name:(NSString *)name price:(NSString *)price iconName:(NSString *)iconName {
    BraintreeProduct *p = [[BraintreeProduct alloc] init];
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
    self.headerTitleLabel.text = @"Braintree Payment Flow";
    self.headerTitleLabel.font = [ThemeHelper titleFont];
    self.headerTitleLabel.textColor = [ThemeHelper textColor];
    [self.headerSection addSubview:self.headerTitleLabel];

    self.headerDescriptionLabel = [[UILabel alloc] init];
    self.headerDescriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerDescriptionLabel.text = @"Create a purchase on the Braintree gateway, then authorize via PayPal or Venmo using the SDK's Braintree checkout.";
    self.headerDescriptionLabel.font = [ThemeHelper bodyFont];
    self.headerDescriptionLabel.textColor = [ThemeHelper textSecondaryColor];
    self.headerDescriptionLabel.numberOfLines = 0;
    [self.headerSection addSubview:self.headerDescriptionLabel];

    self.stageIndicatorContainer = [self createStageIndicatorContainer];
    [self.contentView addSubview:self.stageIndicatorContainer];

    self.productSelectionContainer = [self createProductSelectionContainer];
    [self.contentView addSubview:self.productSelectionContainer];

    self.paymentTypeContainer = [self createPaymentTypeContainer];
    [self.contentView addSubview:self.paymentTypeContainer];

    self.payButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.payButton setTitle:@"Select a product" forState:UIControlStateNormal];
    self.payButton.titleLabel.font = [ThemeHelper buttonFont];
    self.payButton.backgroundColor = [ThemeHelper primaryColor];
    [self.payButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.payButton setTitleColor:[UIColor whiteColor] forState:UIControlStateDisabled];
    self.payButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.payButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.payButton.enabled = NO;
    self.payButton.alpha = 0.6;
    [self.payButton addTarget:self action:@selector(payTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.payButton];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];

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

    self.errorContainer = [[UIView alloc] init];
    self.errorContainer.backgroundColor = [[ThemeHelper errorColor] colorWithAlphaComponent:0.1];
    self.errorContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.errorContainer.hidden = YES;
    self.errorContainer.translatesAutoresizingMaskIntoConstraints = NO;
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
        [self.paymentTypeContainer.topAnchor constraintEqualToAnchor:self.productSelectionContainer.bottomAnchor constant:lg],
        [self.paymentTypeContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.paymentTypeContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],
        [self.payButton.topAnchor constraintEqualToAnchor:self.paymentTypeContainer.bottomAnchor constant:lg],
        [self.payButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:spacing],
        [self.payButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-spacing],
        [self.payButton.heightAnchor constraintEqualToConstant:48],
        [self.resultContainer.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:lg],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.payButton.leadingAnchor],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.payButton.trailingAnchor],
        [self.successLabel.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:12],
        [self.successLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:12],
        [self.successLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-12],
        [self.successLabel.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-12],
        [self.errorContainer.topAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:12],
        [self.errorContainer.leadingAnchor constraintEqualToAnchor:self.payButton.leadingAnchor],
        [self.errorContainer.trailingAnchor constraintEqualToAnchor:self.payButton.trailingAnchor],
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
    NSArray<NSString *> *stepNames = @[@"Idle", @"Purchase", @"Checkout", @"Confirm"];
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
        circle.tag = kBraintreeStageCircleTagBase + i;
        circle.backgroundColor = isActive ? [ThemeHelper primaryColor] : braintreeStageDisabledColor();
        circle.layer.cornerRadius = 12;
        circle.translatesAutoresizingMaskIntoConstraints = NO;
        [stepColumn addSubview:circle];

        UILabel *numberLabel = [[UILabel alloc] init];
        numberLabel.tag = kBraintreeStageNumberTagBase + i;
        numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        numberLabel.textColor = [UIColor whiteColor];
        numberLabel.textAlignment = NSTextAlignmentCenter;
        numberLabel.translatesAutoresizingMaskIntoConstraints = NO;
        numberLabel.text = isCompleted ? @"✓" : [NSString stringWithFormat:@"%ld", (long)(i + 1)];
        if (isCompleted) numberLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        [circle addSubview:numberLabel];

        UILabel *stepLabel = [[UILabel alloc] init];
        stepLabel.tag = kBraintreeStageLabelTagBase + i;
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

    for (NSInteger i = 0; i < (NSInteger)stepNames.count - 1; i++) {
        UIView *currentCircle = [container viewWithTag:kBraintreeStageCircleTagBase + i];
        UIView *nextCircle = [container viewWithTag:kBraintreeStageCircleTagBase + (i + 1)];
        UIView *line = [[UIView alloc] init];
        line.tag = kBraintreeStageLineTagBase + i;
        line.backgroundColor = (i < (NSInteger)self.stage) ? [ThemeHelper primaryColor] : braintreeStageDisabledColor();
        line.translatesAutoresizingMaskIntoConstraints = NO;
        [container addSubview:line];
        [NSLayoutConstraint activateConstraints:@[
            [line.leadingAnchor constraintEqualToAnchor:currentCircle.trailingAnchor constant:4],
            [line.trailingAnchor constraintEqualToAnchor:nextCircle.leadingAnchor constant:-4],
            [line.centerYAnchor constraintEqualToAnchor:currentCircle.centerYAnchor],
            [line.heightAnchor constraintEqualToConstant:2]
        ]];
    }

    [NSLayoutConstraint activateConstraints:@[
        [stepsStack.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [stepsStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingSM]],
        [stepsStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingSM]],
        [stepsStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
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

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.productsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.productsStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.productsStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.productsStackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    return container;
}

- (UIView *)createProductView:(BraintreeProduct *)product {
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
    priceLabel.textColor = [ThemeHelper primaryColor];
    [contentStack addArrangedSubview:priceLabel];

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

- (UIView *)createPaymentTypeContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Payment Type";
    titleLabel.font = [ThemeHelper subtitleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:titleLabel];

    self.paymentTypeStackView = [[UIStackView alloc] init];
    self.paymentTypeStackView.axis = UILayoutConstraintAxisHorizontal;
    self.paymentTypeStackView.spacing = [ThemeHelper spacingMD];
    self.paymentTypeStackView.distribution = UIStackViewDistributionFillEqually;
    self.paymentTypeStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.paymentTypeStackView];

    UIView *paypalRow = [self createPaymentTypeRowWithId:@"paypal" name:@"PayPal" iconName:@"dollarsign.circle"];
    UIView *venmoRow = [self createPaymentTypeRowWithId:@"venmo" name:@"Venmo" iconName:@"v.circle"];
    [self.paymentTypeStackView addArrangedSubview:paypalRow];
    [self.paymentTypeStackView addArrangedSubview:venmoRow];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.paymentTypeStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.paymentTypeStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.paymentTypeStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.paymentTypeStackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    return container;
}

- (UIView *)createPaymentTypeRowWithId:(NSString *)typeId name:(NSString *)name iconName:(NSString *)iconName {
    BOOL isSelected = [self.selectedPaymentType isEqualToString:typeId];
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
    row.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    if (isSelected) {
        row.layer.borderWidth = 2;
        row.layer.borderColor = [ThemeHelper primaryColor].CGColor;
    }
    row.translatesAutoresizingMaskIntoConstraints = NO;
    objc_setAssociatedObject(row, "paymentTypeId", typeId, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(paymentTypeTapped:)];
    [row addGestureRecognizer:tap];
    row.userInteractionEnabled = YES;

    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.axis = UILayoutConstraintAxisHorizontal;
    hStack.spacing = [ThemeHelper spacingSM];
    hStack.alignment = UIStackViewAlignmentCenter;
    hStack.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:hStack];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.image = [UIImage systemImageNamed:iconName];
    iconView.tintColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [hStack addArrangedSubview:iconView];

    UILabel *label = [[UILabel alloc] init];
    label.text = name;
    label.font = [ThemeHelper subtitleFont];
    label.textColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
    [hStack addArrangedSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [hStack.topAnchor constraintEqualToAnchor:row.topAnchor constant:[ThemeHelper spacingMD]],
        [hStack.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:[ThemeHelper spacingMD]],
        [hStack.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [hStack.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    return row;
}

- (void)productTapped:(UITapGestureRecognizer *)gesture {
    BraintreeProduct *product = objc_getAssociatedObject(gesture.view, "product");
    if (product) {
        self.selectedProduct = product;
        [self hideResultMessages];
        [self updateProductSelection];
        [self updatePayButtonState];
    }
}

- (void)paymentTypeTapped:(UITapGestureRecognizer *)gesture {
    NSString *typeId = objc_getAssociatedObject(gesture.view, "paymentTypeId");
    if (typeId) {
        self.selectedPaymentType = typeId;
        [self hideResultMessages];
        [self updatePaymentTypeSelection];
        [self updatePayButtonState];
    }
}

- (void)updateProductSelection {
    for (UIStackView *rowStack in self.productsStackView.arrangedSubviews) {
        if (![rowStack isKindOfClass:[UIStackView class]]) continue;
        for (UIView *productView in rowStack.arrangedSubviews) {
            BraintreeProduct *product = objc_getAssociatedObject(productView, "product");
            if (product) {
                BOOL isSelected = (self.selectedProduct && [self.selectedProduct.productId isEqualToString:product.productId]);
                productView.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
                productView.layer.borderWidth = isSelected ? 2 : 0;
                productView.layer.borderColor = isSelected ? [ThemeHelper primaryColor].CGColor : nil;
                for (UIView *sub in productView.subviews) {
                    if ([sub isKindOfClass:[UIStackView class]]) {
                        for (UIView *item in [(UIStackView *)sub arrangedSubviews]) {
                            if ([item isKindOfClass:[UIImageView class]]) {
                                ((UIImageView *)item).tintColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
                            }
                        }
                    }
                }
            }
        }
    }
}

- (void)updatePaymentTypeSelection {
    for (UIView *row in self.paymentTypeStackView.arrangedSubviews) {
        NSString *typeId = objc_getAssociatedObject(row, "paymentTypeId");
        if (typeId) {
            BOOL isSelected = [self.selectedPaymentType isEqualToString:typeId];
            row.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
            row.layer.borderWidth = isSelected ? 2 : 0;
            row.layer.borderColor = isSelected ? [ThemeHelper primaryColor].CGColor : nil;
            for (UIView *sub in row.subviews) {
                if ([sub isKindOfClass:[UIStackView class]]) {
                    for (UIView *item in [(UIStackView *)sub arrangedSubviews]) {
                        if ([item isKindOfClass:[UIImageView class]]) {
                            ((UIImageView *)item).tintColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
                        } else if ([item isKindOfClass:[UILabel class]]) {
                            ((UILabel *)item).textColor = isSelected ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
                        }
                    }
                }
            }
        }
    }
}

- (void)updatePayButtonState {
    BOOL enable = (self.selectedProduct != nil && !self.isLoading);
    self.payButton.enabled = enable;
    self.payButton.userInteractionEnabled = enable;
    self.payButton.alpha = enable ? 1.0 : 0.6;
    if (enable) {
        self.payButton.backgroundColor = [ThemeHelper primaryColor];
    } else {
        self.payButton.backgroundColor = [[ThemeHelper primaryColor] colorWithAlphaComponent:0.6];
    }
    NSString *title = @"Select a product";
    if (self.selectedProduct) {
        switch (self.stage) {
            case BraintreeStageIdle:
                title = [NSString stringWithFormat:@"Pay %@ with %@", [self.selectedProduct formattedPriceUSD], [self.selectedPaymentType isEqualToString:@"venmo"] ? @"Venmo" : @"PayPal"];
                break;
            case BraintreeStageCreatingPurchase:
                title = @"Creating purchase...";
                break;
            case BraintreeStageCheckout:
                title = @"Authorizing payment...";
                break;
            case BraintreeStageConfirming:
                title = @"Confirming...";
                break;
        }
    }
    [self.payButton setTitle:title forState:UIControlStateNormal];
    [self.payButton setTitle:title forState:UIControlStateDisabled];
    [self updateStageIndicator];
}

- (void)updateStageIndicator {
    NSArray<NSString *> *stepNames = @[@"Idle", @"Purchase", @"Checkout", @"Confirm"];
    NSInteger currentStep = (NSInteger)self.stage;
    for (NSInteger i = 0; i < (NSInteger)stepNames.count; i++) {
        BOOL isActive = (i <= currentStep);
        BOOL isCompleted = (i < currentStep);
        UIView *circle = [self.stageIndicatorContainer viewWithTag:kBraintreeStageCircleTagBase + i];
        if (circle) {
            circle.backgroundColor = isActive ? [ThemeHelper primaryColor] : braintreeStageDisabledColor();
        }
        UILabel *numberLabel = [self.stageIndicatorContainer viewWithTag:kBraintreeStageNumberTagBase + i];
        if ([numberLabel isKindOfClass:[UILabel class]]) {
            numberLabel.text = isCompleted ? @"✓" : [NSString stringWithFormat:@"%ld", (long)(i + 1)];
            numberLabel.font = isCompleted ? [UIFont systemFontOfSize:10 weight:UIFontWeightBold] : [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        }
        UILabel *stepLabel = [self.stageIndicatorContainer viewWithTag:kBraintreeStageLabelTagBase + i];
        if ([stepLabel isKindOfClass:[UILabel class]]) {
            stepLabel.textColor = isActive ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
        }
        if (i > 0) {
            UIView *line = [self.stageIndicatorContainer viewWithTag:kBraintreeStageLineTagBase + (i - 1)];
            if (line) {
                line.backgroundColor = (i <= currentStep) ? [ThemeHelper primaryColor] : braintreeStageDisabledColor();
            }
        }
    }
}

#pragma mark - Flow

- (void)payTapped {
    if (!self.selectedProduct || self.isLoading) return;
    if ([self.selectedProduct.price compare:[NSDecimalNumber zero]] != NSOrderedDescending) {
        [self showError:@"Invalid product price"];
        return;
    }

    self.isLoading = YES;
    [self hideResultMessages];
    self.stage = BraintreeStageCreatingPurchase;
    [self updatePayButtonState];
    [self.loadingIndicator startAnimating];

    NSDecimalNumber *amountInCents = [self.selectedProduct.price decimalNumberByMultiplyingBy:[AppConstants centsPerDollar]];
    NSString *redirectUrl = @"spreedlyCApp://com.spreedly-example.sdk.SpreedlySDKExampleObjectiveC/braintree/checkout";
    NSString *callbackUrl = @"https://www.google.com/";
    __weak typeof(self) weakSelf = self;
    PurchaseAPIClient *client = [[SpreedlyConfigManager shared] createPurchaseAPIClient];
    [client braintreePurchaseWithAmount:amountInCents
                          currencyCode:@"USD"
                           redirectUrl:redirectUrl
                          callbackUrl:callbackUrl
                     paymentMethodType:self.selectedPaymentType
                            completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self resetWithError:error.localizedDescription.length > 0 ? [NSString stringWithFormat:@"Purchase failed: %@", error.localizedDescription] : @"Purchase failed"];
                return;
            }
            if (!response || !response.transaction) {
                [self resetWithError:@"Failed to create purchase"];
                return;
            }
            PurchaseTransaction *tx = response.transaction;
            NSArray *validStates = @[@"processing", @"pending"];
            if (!tx.state || ![validStates containsObject:tx.state]) {
                [self resetWithError:[NSString stringWithFormat:@"Transaction not in expected state: %@. Message: %@", tx.state ?: @"unknown", tx.message ?: @"none"]];
                return;
            }
            NSString *clientToken = tx.braintreeClientToken;
            NSString *transactionToken = tx.token;
            NSString *amount = [NSString stringWithFormat:@"%.2f", self.selectedProduct.price.doubleValue];

            self.stage = BraintreeStageCheckout;
            self.pendingTransactionToken = transactionToken;
            self.pendingPaymentType = self.selectedPaymentType;
            [self.loadingIndicator stopAnimating];
            [self updatePayButtonState];

            BraintreePaymentType paymentType = [self.selectedPaymentType isEqualToString:@"venmo"] ? BraintreePaymentTypeVenmo : BraintreePaymentTypePaypal;
            BraintreeCheckoutConfig *config = [[BraintreeCheckoutConfig alloc] initWithTransactionToken:transactionToken
                                                                                          paymentType:paymentType
                                                                                   merchantDisplayName:@""
                                                                                          clientToken:clientToken
                                                                                               amount:amount
                                                                                         currencyCode:@"USD"];
            [SpreedlyBraintreeCheckout presentWithConfig:config];
        });
    }];
}

- (NSString *)braintreeMethodDisplayName {
    return [self.selectedPaymentType isEqualToString:@"venmo"] ? @"Venmo" : @"PayPal";
}

- (void)resetWithError:(NSString *)message {
    self.isLoading = NO;
    self.stage = BraintreeStageIdle;
    self.pendingTransactionToken = nil;
    self.pendingPaymentType = nil;
    [self.loadingIndicator stopAnimating];
    [self updatePayButtonState];
    [self showError:message];
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

- (void)confirmNonSuccessfulWithTransactionToken:(NSString *)transactionToken
                                           state:(NSString *)state
                                         message:(NSString *)message
                               paymentMethodType:(NSString *)paymentMethodType {
    PurchaseAPIClient *client = [[SpreedlyConfigManager shared] createPurchaseAPIClient];
    [client braintreeConfirmWithTransactionToken:transactionToken
                                           state:state
                                           nonce:nil
                                      deviceData:nil
                                         message:message
                               paymentMethodType:paymentMethodType
                                      completion:^(__unused PurchaseResponse * _Nullable response, __unused NSError * _Nullable error) {
        // Best-effort: backend notification failure does not affect user experience.
    }];
}

#pragma mark - SpreedlyPaymentDelegate

- (void)paymentDidComplete:(PaymentResult *)result {
    if (self.stage != BraintreeStageCheckout && self.stage != BraintreeStageConfirming) return;
    NSString *transactionToken = [self.pendingTransactionToken copy];
    NSString *paymentType = [self.pendingPaymentType copy];

    dispatch_async(dispatch_get_main_queue(), ^{
        self.stage = BraintreeStageConfirming;

        if (result.isSuccess && result.nonce.length > 0) {
            __weak typeof(self) weakSelf = self;
            NSString *confirmPaymentType = paymentType;
            PurchaseAPIClient *client = [[SpreedlyConfigManager shared] createPurchaseAPIClient];
            [client braintreeConfirmWithTransactionToken:transactionToken
                                                   state:@"Successful"
                                                   nonce:result.nonce
                                              deviceData:result.deviceData
                                                 message:nil
                                       paymentMethodType:confirmPaymentType
                                              completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
                __strong typeof(weakSelf) self = weakSelf;
                if (!self) return;
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.isLoading = NO;
                    self.stage = BraintreeStageIdle;
                    self.pendingTransactionToken = nil;
                    self.pendingPaymentType = nil;
                    [self updatePayButtonState];

                    if (error) {
                        [self showError:[NSString stringWithFormat:@"Confirmation failed: %@", error.localizedDescription]];
                        return;
                    }
                    if (!response || !response.transaction) {
                        [self showError:@"Confirmation response missing transaction data."];
                        return;
                    }
                    PurchaseTransaction *tx = response.transaction;
                    if (tx.succeeded) {
                        [self showSuccess:@"Payment successful. The transaction has been completed successfully."];
                    } else if ([tx.state isEqualToString:@"processing"] || [tx.state isEqualToString:@"pending"]) {
                        [self showSuccess:@"Payment is being processed. Final confirmation may take a moment."];
                    } else {
                        [self showError:[NSString stringWithFormat:@"Confirmation returned state: %@. Message: %@",
                                         tx.state ?: @"", tx.message ?: @""]];
                    }
                });
            }];
        } else if (result.isCanceled) {
            NSString *cancelMsg = [NSString stringWithFormat:@"%@ payment was canceled.",
                                   [self braintreeMethodDisplayName]];
            [self confirmNonSuccessfulWithTransactionToken:transactionToken
                                                     state:@"Cancelled"
                                                   message:cancelMsg
                                         paymentMethodType:paymentType];
            self.isLoading = NO;
            self.stage = BraintreeStageIdle;
            self.pendingTransactionToken = nil;
            self.pendingPaymentType = nil;
            [self updatePayButtonState];
            [self showError:cancelMsg];
        } else {
            NSString *methodName = [self braintreeMethodDisplayName];
            NSString *sdkMessage = result.failureDetails.message;
            NSString *desc = (sdkMessage.length > 0)
                ? sdkMessage
                : [NSString stringWithFormat:@"%@ payment failed.", methodName];
            [self confirmNonSuccessfulWithTransactionToken:transactionToken
                                                     state:@"Failed"
                                                   message:desc
                                         paymentMethodType:paymentType];
            self.isLoading = NO;
            self.stage = BraintreeStageIdle;
            self.pendingTransactionToken = nil;
            self.pendingPaymentType = nil;
            [self updatePayButtonState];
            [self showError:desc];
        }
    });
}

@end
