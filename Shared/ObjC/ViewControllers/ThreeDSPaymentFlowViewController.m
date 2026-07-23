//
//  ThreeDSPaymentFlowViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import "ThreeDSPaymentFlowViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <objc/runtime.h>
#import "SpreedlyConfigManager.h"
#import "FetchPaymentMethodsAPIClient.h"
#import "FetchPaymentMethodsModels.h"
#import "PurchaseAPIClient.h"
#import "PurchaseModels.h"
#import "SavedCard.h"
#import "AppConstants.h"
#import "ThemeHelper.h"

static NSString * const GatewaySpecific3DSTriggerNotification = @"GatewaySpecific3DSTriggerCompletion";
static char ThreeDSErrorContainerKey;

// MARK: - Product Model
@interface Product : NSObject
@property (nonatomic, strong) NSString *productId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, strong) NSString *productDescription;
@property (nonatomic, strong) NSString *iconName;
- (NSString *)formattedPrice;
@end

@implementation Product
- (NSString *)formattedPrice {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.currencyCode = CurrencyCodeUSD;
    return [formatter stringFromNumber:self.price] ?: [NSString stringWithFormat:@"$%@", self.price];
}
@end

// MARK: - ThreeDSPaymentFlowViewController Implementation
@interface ThreeDSPaymentFlowViewController () <UIScrollViewDelegate, SpreedlyThreeDSChallengeDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIView *headerSection;
@property (nonatomic, strong) UIView *productSelectionContainer;
@property (nonatomic, strong) UIView *paymentMethodSelectionContainer;
@property (nonatomic, strong) UIButton *payButton;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

// Product Selection UI
@property (nonatomic, strong) UIStackView *productsStackView;
@property (nonatomic, strong) UIView *totalAmountContainer;

// Payment Method Selection UI
@property (nonatomic, strong) UIStackView *cardsStackView;

// Data
@property (nonatomic, strong) NSArray<Product *> *products;
@property (nonatomic, strong) Product *selectedProduct;
@property (nonatomic, strong) NSArray<SavedCard *> *savedCards;
@property (nonatomic, strong) SavedCard *selectedCard;

// State
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isLoadingCards;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, strong) NSString *successMessage;
@property (nonatomic, strong) NSString *transactionToken;
@property (nonatomic, assign) BOOL useGatewaySpecific3DS;
@property (nonatomic, strong) id gatewaySpecificTriggerObserver;

@end

@implementation ThreeDSPaymentFlowViewController

- (instancetype)init {
    return [self initWithGatewaySpecificFlow:NO];
}

- (instancetype)initWithGatewaySpecificFlow:(BOOL)useGatewaySpecific3DS {
    if (self = [super init]) {
        _useGatewaySpecific3DS = useGatewaySpecific3DS;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = self.useGatewaySpecific3DS ? @"Gateway-Specific 3DS Challenge" : @"3DS Challenge Demo";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Initialize state
    self.selectedProduct = nil;
    self.selectedCard = nil;
    self.savedCards = @[];
    self.isLoadingCards = NO;
    self.isLoading = NO;
    
    // Initialize products
    self.products = [self buildProducts];
    
    [self setupUI];
    [self setupConstraints];
    
    // Set 3DS challenge delegate
    [Spreedly shared].threeDSChallengeDelegate = self;

    if (self.useGatewaySpecific3DS) {
        [self setupGatewaySpecificObservers];
    }
    
    // Fetch payment methods
    [self fetchPaymentMethods];
}

- (Product *)createProductWithId:(NSString *)productId name:(NSString *)name price:(NSDecimalNumber *)price description:(NSString *)description iconName:(NSString *)iconName {
    Product *product = [[Product alloc] init];
    product.productId = productId;
    product.name = name;
    product.price = price;
    product.productDescription = description;
    product.iconName = iconName;
    return product;
}

- (NSArray<Product *> *)buildProducts {
    if (self.useGatewaySpecific3DS) {
        return @[
            [self createProductWithId:@"prod_1" name:@"Frictionless" price:[NSDecimalNumber decimalNumberWithString:@"3001"] description:@"3DS2 frictionless (immediate success)" iconName:@"airpods"],
            [self createProductWithId:@"prod_2" name:@"Fingerprint + Direct Auth" price:[NSDecimalNumber decimalNumberWithString:@"3003"] description:@"Device fingerprint + direct authorize" iconName:@"applewatch"],
            [self createProductWithId:@"prod_3" name:@"Fingerprint + Challenge" price:[NSDecimalNumber decimalNumberWithString:@"3004"] description:@"Device fingerprint + challenge" iconName:@"ipad"],
            [self createProductWithId:@"prod_4" name:@"Direct Challenge" price:[NSDecimalNumber decimalNumberWithString:@"3005"] description:@"Challenge without fingerprint" iconName:@"laptopcomputer"],
            [self createProductWithId:@"prod_5" name:@"Fingerprint + Forced Failure" price:[NSDecimalNumber decimalNumberWithString:@"3103"] description:@"Device fingerprint + forced failure" iconName:@"speaker.wave.3"],
            [self createProductWithId:@"prod_6" name:@"Challenge + Forced Failure" price:[NSDecimalNumber decimalNumberWithString:@"3104"] description:@"Challenge + forced failure" iconName:@"gamecontroller"]
        ];
    }

    return @[
        [self createProductWithId:@"prod_1" name:@"Wireless Earbuds" price:[NSDecimalNumber decimalNumberWithString:@"129"] description:@"Premium wireless earbuds with active noise cancellation" iconName:@"airpods"],
        [self createProductWithId:@"prod_2" name:@"Smart Watch" price:[NSDecimalNumber decimalNumberWithString:@"399"] description:@"Feature-rich smartwatch with health tracking and fitness monitoring" iconName:@"applewatch"],
        [self createProductWithId:@"prod_3" name:@"Tablet" price:[NSDecimalNumber decimalNumberWithString:@"499"] description:@"High-performance tablet with stunning display" iconName:@"ipad"],
        [self createProductWithId:@"prod_4" name:@"Laptop" price:[NSDecimalNumber decimalNumberWithString:@"1299"] description:@"Powerful laptop for work and creativity" iconName:@"laptopcomputer"],
        [self createProductWithId:@"prod_5" name:@"Smart Speaker" price:[NSDecimalNumber decimalNumberWithString:@"99"] description:@"Voice-controlled smart speaker with premium sound" iconName:@"speaker.wave.3"],
        [self createProductWithId:@"prod_6" name:@"Gaming Console" price:[NSDecimalNumber decimalNumberWithString:@"499"] description:@"Next-generation gaming console with immersive gameplay" iconName:@"gamecontroller"]
    ];
}

- (void)setupUI {
    // Scroll View
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    // Content View
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    
    // Header Section
    self.headerSection = [self createHeaderSection];
    
    // Product Selection Container
    self.productSelectionContainer = [self createProductSelectionContainer];
    
    // Payment Method Selection Container
    self.paymentMethodSelectionContainer = [self createPaymentMethodSelectionContainer];
    
    // Pay Button
    self.payButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.payButton setTitle:@"Pay" forState:UIControlStateNormal];
    [self.payButton setTitle:@"Pay" forState:UIControlStateDisabled];
    self.payButton.titleLabel.font = [ThemeHelper buttonFont];
    self.payButton.backgroundColor = [ThemeHelper primaryColor];
    [self.payButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.payButton setTitleColor:[UIColor whiteColor] forState:UIControlStateDisabled];
    self.payButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.payButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.payButton.enabled = NO;
    self.payButton.alpha = 0.6;
    self.payButton.accessibilityIdentifier = @"three-ds-challenge-pay-button";
    self.payButton.accessibilityLabel = @"Pay";
    self.payButton.accessibilityHint = @"Tap to proceed with payment and 3DS challenge";
    [self.payButton addTarget:self action:@selector(payButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.payButton];
    
    // Result Container (for success messages)
    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.resultContainer.hidden = YES;
    self.resultContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:self.resultContainer];
    [self.contentView addSubview:self.resultContainer];
    
    // Error Container (for error messages)
    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.textColor = [ThemeHelper errorColor];
    self.errorLabel.font = [ThemeHelper bodyFont];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.accessibilityIdentifier = @"three-ds-challenge-error-message";
    self.errorLabel.accessibilityHint = @"Error message from 3DS challenge process";
    [self.contentView addSubview:self.errorLabel];
    
    // Loading Indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
}

- (UIView *)createHeaderSection {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = [self headerTitleText];
    titleLabel.font = [ThemeHelper titleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"three-ds-challenge-title";
    titleLabel.accessibilityLabel = @"3DS Challenge Flow";
    titleLabel.accessibilityHint = @"3DS Challenge demonstration screen";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    UILabel *descriptionLabel = [[UILabel alloc] init];
    descriptionLabel.text = [self headerDescriptionText];
    descriptionLabel.font = [ThemeHelper bodyFont];
    descriptionLabel.textColor = [ThemeHelper textSecondaryColor];
    descriptionLabel.numberOfLines = 0;
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    descriptionLabel.accessibilityIdentifier = @"three-ds-challenge-description";
    descriptionLabel.accessibilityHint = @"Select a product and payment method, then proceed with the 3DS challenge flow";
    [container addSubview:descriptionLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [descriptionLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [descriptionLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [descriptionLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [descriptionLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    return container;
}

- (NSString *)headerTitleText {
    return self.useGatewaySpecific3DS ? @"3DS Gateway-Specific Flow" : @"3DS Challenge Flow";
}

- (NSString *)headerDescriptionText {
    if (self.useGatewaySpecific3DS) {
        return @"Gateway-specific 3DS: select a product and payment method, then complete the gateway challenge flow.";
    }
    return @"Select a product and payment method, then proceed with the 3DS challenge flow.";
}

- (UIView *)createProductSelectionContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Select Product";
    titleLabel.font = [ThemeHelper subtitleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"product-selection-title";
    titleLabel.accessibilityLabel = @"Select Product";
    titleLabel.accessibilityHint = @"Choose a product from the grid";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    // Products Grid (2 columns)
    self.productsStackView = [[UIStackView alloc] init];
    self.productsStackView.axis = UILayoutConstraintAxisVertical;
    self.productsStackView.spacing = [ThemeHelper spacingMD];
    self.productsStackView.distribution = UIStackViewDistributionFillEqually;
    self.productsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.productsStackView];
    
    // Create product rows (2 columns per row)
    NSInteger productCount = MIN([AppConstants maxCardsToDisplay], self.products.count);
    for (NSInteger i = 0; i < productCount; i += 2) {
        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.axis = UILayoutConstraintAxisHorizontal;
        rowStack.spacing = [ThemeHelper spacingMD];
        rowStack.distribution = UIStackViewDistributionFillEqually;
        
        // Add first product in row
        if (i < self.products.count) {
            UIView *productView = [self createProductView:self.products[i]];
            [rowStack addArrangedSubview:productView];
        }
        
        // Add second product in row
        if (i + 1 < self.products.count) {
            UIView *productView = [self createProductView:self.products[i + 1]];
            [rowStack addArrangedSubview:productView];
        }
        
        [self.productsStackView addArrangedSubview:rowStack];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [self.productsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.productsStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.productsStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    // Total Amount Container (initially hidden)
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
    amountLabel.tag = 999; // Tag to identify this label for updates
    amountLabel.font = [ThemeHelper subtitleFont];
    amountLabel.textColor = [ThemeHelper merchantProductPriceColor];
    amountLabel.textAlignment = NSTextAlignmentRight;
    amountLabel.translatesAutoresizingMaskIntoConstraints = NO;
    amountLabel.accessibilityIdentifier = @"product-total-amount";
    [self.totalAmountContainer addSubview:amountLabel];
    
    [NSLayoutConstraint activateConstraints:@[
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

- (UIView *)createProductView:(Product *)product {
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
    productView.accessibilityIdentifier = [NSString stringWithFormat:@"product-row-%@", product.productId];
    productView.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", product.name, [product formattedPrice]];
    productView.accessibilityHint = @"Tap to select this product";
    productView.accessibilityTraits = UIAccessibilityTraitButton | (isSelected ? UIAccessibilityTraitSelected : 0);
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(productTapped:)];
    [productView addGestureRecognizer:tapGesture];
    productView.userInteractionEnabled = YES;
    
    // Store product reference in view tag (using pointer value)
    objc_setAssociatedObject(productView, "product", product, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = [ThemeHelper spacingXS];
    contentStack.alignment = UIStackViewAlignmentCenter;
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [productView addSubview:contentStack];
    
    // Product Icon
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.image = [UIImage systemImageNamed:product.iconName];
    iconView.tintColor = isSelected ? [ThemeHelper primaryColor] : [UIColor grayColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    // Use title font size (approximately 28pt)
    iconView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightRegular];
    [contentStack addArrangedSubview:iconView];
    
    // Product Name and Price Container
    UIStackView *textStack = [[UIStackView alloc] init];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = [ThemeHelper spacingXS];
    textStack.alignment = UIStackViewAlignmentCenter;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Product Name
    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = product.name;
    nameLabel.font = [ThemeHelper captionFont];
    nameLabel.textColor = [ThemeHelper textColor];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.numberOfLines = 2;
    nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [textStack addArrangedSubview:nameLabel];
    
    // Product Price
    UILabel *priceLabel = [[UILabel alloc] init];
    priceLabel.text = [product formattedPrice];
    priceLabel.font = [ThemeHelper subtitleFont];
    priceLabel.textColor = [ThemeHelper merchantProductPriceColor];
    priceLabel.textAlignment = NSTextAlignmentCenter;
    priceLabel.numberOfLines = 1;
    priceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [textStack addArrangedSubview:priceLabel];
    
    [contentStack addArrangedSubview:textStack];
    
    // Selection Indicator
    UIImageView *checkmarkView = [[UIImageView alloc] init];
    if (isSelected) {
        checkmarkView.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        checkmarkView.tintColor = [ThemeHelper primaryColor];
    } else {
        // Invisible placeholder to maintain consistent height
        checkmarkView.image = [UIImage systemImageNamed:@"circle"];
        checkmarkView.tintColor = [UIColor clearColor];
    }
    checkmarkView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
    checkmarkView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentStack addArrangedSubview:checkmarkView];
    
    [NSLayoutConstraint activateConstraints:@[
        [contentStack.topAnchor constraintEqualToAnchor:productView.topAnchor constant:[ThemeHelper spacingMD]],
        [contentStack.leadingAnchor constraintEqualToAnchor:productView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [contentStack.trailingAnchor constraintEqualToAnchor:productView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [contentStack.bottomAnchor constraintEqualToAnchor:productView.bottomAnchor constant:-[ThemeHelper spacingMD]],
        
        [iconView.heightAnchor constraintEqualToConstant:30],
        [textStack.widthAnchor constraintEqualToAnchor:contentStack.widthAnchor],
        [nameLabel.heightAnchor constraintGreaterThanOrEqualToConstant:36],
        [priceLabel.heightAnchor constraintEqualToConstant:20],
        [checkmarkView.heightAnchor constraintEqualToConstant:24],
        [productView.heightAnchor constraintEqualToConstant:140]
    ]];
    
    return productView;
}

- (UIView *)createPaymentMethodSelectionContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Select Payment Method";
    titleLabel.font = [ThemeHelper subtitleFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"payment-method-selection-title";
    titleLabel.accessibilityLabel = @"Select Payment Method";
    titleLabel.accessibilityHint = @"Choose a payment method from the list";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    self.cardsStackView = [[UIStackView alloc] init];
    self.cardsStackView.axis = UILayoutConstraintAxisVertical;
    self.cardsStackView.spacing = [ThemeHelper spacingMD];
    self.cardsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cardsStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [self.cardsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.cardsStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.cardsStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.cardsStackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    return container;
}

- (void)setupConstraints {
    [NSLayoutConstraint activateConstraints:@[
        // Scroll View
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        // Content View
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
        
        // Header Section
        [self.headerSection.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:[ThemeHelper spacingLG]],
        [self.headerSection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.headerSection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Product Selection Container
        [self.productSelectionContainer.topAnchor constraintEqualToAnchor:self.headerSection.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.productSelectionContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.productSelectionContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Payment Method Selection Container
        [self.paymentMethodSelectionContainer.topAnchor constraintEqualToAnchor:self.productSelectionContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.paymentMethodSelectionContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.paymentMethodSelectionContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Pay Button
        [self.payButton.topAnchor constraintEqualToAnchor:self.paymentMethodSelectionContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.payButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.payButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.payButton.heightAnchor constraintEqualToConstant:44],
        
        // Result Container
        [self.resultContainer.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.payButton.leadingAnchor],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.payButton.trailingAnchor],
        [self.resultContainer.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],
        
        // Error Label
        [self.errorLabel.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.payButton.leadingAnchor],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.payButton.trailingAnchor],
        [self.errorLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],
        
        // Loading Indicator
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)productTapped:(UITapGestureRecognizer *)gesture {
    Product *product = objc_getAssociatedObject(gesture.view, "product");
    if (product) {
        self.selectedProduct = product;
        [self updateProductSelection];
        [self updatePayButtonState];
    }
}

- (void)updateProductSelection {
    // Update visual selection state for products
    // Recreate product views to ensure all styling is correct
    for (UIStackView *rowStack in self.productsStackView.arrangedSubviews) {
        for (UIView *productView in rowStack.arrangedSubviews) {
            Product *product = objc_getAssociatedObject(productView, "product");
            if (product) {
                BOOL isSelected = (self.selectedProduct && [self.selectedProduct.productId isEqualToString:product.productId]);
            
                // Update background and border
                productView.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
                productView.layer.cornerRadius = [ThemeHelper borderRadiusSM];
            
            if (isSelected) {
                productView.layer.borderWidth = 2;
                    productView.layer.borderColor = [ThemeHelper primaryColor].CGColor;
            } else {
                productView.layer.borderWidth = 0;
            }
                
                // Update accessibility
                productView.accessibilityTraits = UIAccessibilityTraitButton | (isSelected ? UIAccessibilityTraitSelected : 0);
                
                // Update icon, text, and checkmark colors
                for (UIView *subview in productView.subviews) {
                    if ([subview isKindOfClass:[UIStackView class]]) {
                        UIStackView *stack = (UIStackView *)subview;
                        for (UIView *item in stack.arrangedSubviews) {
                            if ([item isKindOfClass:[UIImageView class]]) {
                                UIImageView *icon = (UIImageView *)item;
                                // First icon is the product icon
                                if (icon.image && [icon.image isEqual:[UIImage systemImageNamed:product.iconName]]) {
                                    icon.tintColor = isSelected ? [ThemeHelper primaryColor] : [UIColor grayColor];
                                } else if ([icon.image isEqual:[UIImage systemImageNamed:@"checkmark.circle.fill"]] || 
                                          [icon.image isEqual:[UIImage systemImageNamed:@"circle"]]) {
                                    // Checkmark indicator
                                    if (isSelected) {
                                        icon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
                                        icon.tintColor = [ThemeHelper primaryColor];
                                    } else {
                                        icon.image = [UIImage systemImageNamed:@"circle"];
                                        icon.tintColor = [UIColor clearColor];
                                    }
                                }
                            } else if ([item isKindOfClass:[UIStackView class]]) {
                                // Text stack
                                UIStackView *textStack = (UIStackView *)item;
                                for (UIView *textItem in textStack.arrangedSubviews) {
                                    if ([textItem isKindOfClass:[UILabel class]]) {
                                        UILabel *label = (UILabel *)textItem;
                                        if ([label.text containsString:@"$"]) {
                                            // Price label
                                            label.textColor = [ThemeHelper primaryColor];
                                        } else {
                                            // Name label
                                            label.textColor = [ThemeHelper textColor];
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Update total amount section
    if (self.selectedProduct) {
        self.totalAmountContainer.hidden = NO;
        UILabel *amountLabel = [self.totalAmountContainer viewWithTag:999];
        if (amountLabel) {
            amountLabel.text = [self.selectedProduct formattedPrice];
            amountLabel.accessibilityLabel = [NSString stringWithFormat:@"Total amount: %@", [self.selectedProduct formattedPrice]];
        }
    } else {
        self.totalAmountContainer.hidden = YES;
    }
}

- (void)updatePayButtonState {
    BOOL shouldEnable = (self.selectedProduct != nil && self.selectedCard != nil && !self.isLoading);
    self.payButton.enabled = shouldEnable;
    self.payButton.userInteractionEnabled = shouldEnable;
    
    // Update button title and accessibility label based on loading state
    if (self.isLoading) {
        [self.payButton setTitle:@"Processing..." forState:UIControlStateNormal];
        [self.payButton setTitle:@"Processing..." forState:UIControlStateDisabled];
        self.payButton.accessibilityLabel = @"Processing";
    } else {
        [self.payButton setTitle:@"Pay" forState:UIControlStateNormal];
        [self.payButton setTitle:@"Pay" forState:UIControlStateDisabled];
        self.payButton.accessibilityLabel = @"Pay";
    }
    
    if (shouldEnable) {
        self.payButton.backgroundColor = [ThemeHelper primaryColor];
        self.payButton.alpha = 1.0;
    } else {
        self.payButton.backgroundColor = [[ThemeHelper primaryColor] colorWithAlphaComponent:0.6];
        self.payButton.alpha = 0.6;
    }
}

- (void)fetchPaymentMethods {
    self.isLoadingCards = YES;
    self.errorMessage = nil;
    [self updateCardsList];
    
    FetchPaymentMethodsAPIClient *client = [[SpreedlyConfigManager shared] createFetchPaymentMethodsAPIClient];
    
    __weak typeof(self) weakSelf = self;
    [client fetchPaymentMethodsWithCompletion:^(FetchPaymentMethodsResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.isLoadingCards = NO;
            
            if (error) {
                strongSelf.errorMessage = error.localizedDescription;
                [strongSelf updateUI];
                [strongSelf updateCardsList];
                return;
            }
            
            if (!response) {
                strongSelf.errorMessage = @"Failed to load payment methods: Invalid response";
                [strongSelf updateUI];
                [strongSelf updateCardsList];
                return;
            }
            
            // Convert PaymentMethod to SavedCard, filtering only credit cards
            NSMutableArray<SavedCard *> *cards = [NSMutableArray array];
            
            for (PaymentMethod *paymentMethod in response.paymentMethods) {
                if (![paymentMethod.paymentMethodType isEqualToString:[AppConstants creditCardPaymentMethodType]]) {
                    continue;
                }
                
                if (!paymentMethod.lastFourDigits || !paymentMethod.cardType) {
                    continue;
                }
                
                SavedCard *card = [[SavedCard alloc] init];
                card.cardId = paymentMethod.token;
                card.paymentMethodToken = paymentMethod.token;
                card.lastFourDigits = paymentMethod.lastFourDigits;
                
                NSString *cardType = paymentMethod.cardType;
                cardType = [cardType stringByReplacingOccurrencesOfString:@"_" withString:@" "];
                cardType = [cardType capitalizedString];
                card.cardType = cardType;
                card.cardBrand = [paymentMethod.cardType lowercaseString];
                
                if (paymentMethod.month) {
                    card.expiryMonth = [NSString stringWithFormat:@"%02ld", (long)paymentMethod.month.integerValue];
                }
                if (paymentMethod.year) {
                    card.expiryYear = [NSString stringWithFormat:@"%ld", (long)paymentMethod.year.integerValue];
                }
                
                [cards addObject:card];
            }
            
            strongSelf.savedCards = [cards copy];
            [strongSelf updateCardsList];
        });
    }];
}

- (void)updateCardsList {
    // Remove all existing arranged subviews
    for (UIView *subview in self.cardsStackView.arrangedSubviews) {
        [self.cardsStackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }
    
    if (self.isLoadingCards) {
        UILabel *loadingLabel = [[UILabel alloc] init];
        loadingLabel.text = @"Loading payment methods...";
        loadingLabel.font = [ThemeHelper captionFont];
        loadingLabel.textColor = [ThemeHelper textSecondaryColor];
        loadingLabel.textAlignment = NSTextAlignmentCenter;
        loadingLabel.accessibilityIdentifier = @"payment-method-loading-state";
        loadingLabel.accessibilityLabel = @"Loading payment methods";
        loadingLabel.accessibilityHint = @"Loading indicator while fetching payment methods";
        [self.cardsStackView addArrangedSubview:loadingLabel];
        
        UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        loadingIndicator.color = [ThemeHelper textSecondaryColor];
        [loadingIndicator startAnimating];
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        [self.cardsStackView addArrangedSubview:loadingIndicator];
    } else if (self.savedCards.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = @"No payment methods available";
        emptyLabel.font = [ThemeHelper captionFont];
        emptyLabel.textColor = [ThemeHelper textSecondaryColor];
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.accessibilityIdentifier = @"payment-method-empty-state";
        emptyLabel.accessibilityLabel = @"No payment methods available";
        emptyLabel.accessibilityHint = @"Message shown when no saved payment methods are available";
        [self.cardsStackView addArrangedSubview:emptyLabel];
    } else {
        // Show only top cards (limited by constant)
        NSInteger maxCards = MIN([AppConstants maxCardsToDisplay], self.savedCards.count);
        NSArray<SavedCard *> *displayedCards = [self.savedCards subarrayWithRange:NSMakeRange(0, maxCards)];
        for (SavedCard *card in displayedCards) {
            UIView *cardRow = [self createCardRow:card];
            [self.cardsStackView addArrangedSubview:cardRow];
        }
    }
}

- (UIView *)createCardRow:(SavedCard *)card {
    BOOL isSelected = (self.selectedCard && [self.selectedCard.cardId isEqualToString:card.cardId]);
    
    UIView *cardRow = [[UIView alloc] init];
    cardRow.backgroundColor = isSelected ? [ThemeHelper selectedCellBackgroundColor] : [ThemeHelper cellBackgroundColor];
    cardRow.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    if (isSelected) {
        cardRow.layer.borderWidth = 2;
        cardRow.layer.borderColor = [ThemeHelper primaryColor].CGColor;
    } else {
        cardRow.layer.borderWidth = 0;
    }
    cardRow.translatesAutoresizingMaskIntoConstraints = NO;
    cardRow.accessibilityIdentifier = [NSString stringWithFormat:@"payment-method-row-%@", card.cardId];
    cardRow.accessibilityLabel = [NSString stringWithFormat:@"%@, expires %@/%@", [card displayName], card.expiryMonth ?: @"", card.expiryYear ?: @""];
    cardRow.accessibilityHint = @"Tap to select this payment method";
    cardRow.accessibilityTraits = UIAccessibilityTraitButton | (isSelected ? UIAccessibilityTraitSelected : 0);
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cardRowTapped:)];
    [cardRow addGestureRecognizer:tapGesture];
    cardRow.userInteractionEnabled = YES;
    
    // Store card reference
    objc_setAssociatedObject(cardRow, "card", card, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // HStack equivalent - using horizontal stack view
    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.axis = UILayoutConstraintAxisHorizontal;
    hStack.spacing = 12; // SwiftUI uses spacing: 12, which is close to spacingMD (16), but keeping 12 to match exactly
    hStack.alignment = UIStackViewAlignmentCenter;
    hStack.translatesAutoresizingMaskIntoConstraints = NO;
    [cardRow addSubview:hStack];
    
    // Card Icon
    UIImageView *cardIcon = [[UIImageView alloc] init];
    cardIcon.image = [UIImage systemImageNamed:@"creditcard.fill"];
    cardIcon.tintColor = isSelected ? [ThemeHelper primaryColor] : [UIColor grayColor];
    cardIcon.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular]; // title2 font size
    cardIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [hStack addArrangedSubview:cardIcon];
    
    // Info Stack (VStack)
    UIStackView *infoStack = [[UIStackView alloc] init];
    infoStack.axis = UILayoutConstraintAxisVertical;
    infoStack.spacing = [ThemeHelper spacingXS];
    infoStack.alignment = UIStackViewAlignmentLeading;
    infoStack.translatesAutoresizingMaskIntoConstraints = NO;
    [hStack addArrangedSubview:infoStack];
    
    UILabel *cardNameLabel = [[UILabel alloc] init];
    cardNameLabel.text = [card displayName];
    cardNameLabel.font = [ThemeHelper subtitleFont];
    cardNameLabel.textColor = [ThemeHelper textColor];
    [infoStack addArrangedSubview:cardNameLabel];
    
    if (card.expiryMonth && card.expiryYear) {
        UILabel *expiryLabel = [[UILabel alloc] init];
        expiryLabel.text = [NSString stringWithFormat:@"Expires: %@/%@", card.expiryMonth, card.expiryYear];
        expiryLabel.font = [ThemeHelper captionFont];
        expiryLabel.textColor = [ThemeHelper textSecondaryColor];
        [infoStack addArrangedSubview:expiryLabel];
    }
    
    // Spacer
    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;
    [hStack addArrangedSubview:spacer];
    
    // Selection Indicator
    UIImageView *checkmark = nil;
    if (isSelected) {
        checkmark = [[UIImageView alloc] init];
        checkmark.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
        checkmark.tintColor = [ThemeHelper primaryColor];
        checkmark.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular]; // title3 font size
        checkmark.translatesAutoresizingMaskIntoConstraints = NO;
        [hStack addArrangedSubview:checkmark];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [hStack.topAnchor constraintEqualToAnchor:cardRow.topAnchor constant:[ThemeHelper spacingMD]],
        [hStack.leadingAnchor constraintEqualToAnchor:cardRow.leadingAnchor constant:[ThemeHelper spacingMD]],
        [hStack.trailingAnchor constraintEqualToAnchor:cardRow.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [hStack.bottomAnchor constraintEqualToAnchor:cardRow.bottomAnchor constant:-[ThemeHelper spacingMD]],
        
        [spacer.widthAnchor constraintGreaterThanOrEqualToConstant:0],
        [cardRow.heightAnchor constraintGreaterThanOrEqualToConstant:60]
    ]];
    
    return cardRow;
}

- (void)cardRowTapped:(UITapGestureRecognizer *)gesture {
    SavedCard *card = objc_getAssociatedObject(gesture.view, "card");
    if (card) {
        self.selectedCard = card;
        [self updateCardsList];
        [self updatePayButtonState];
    }
}

- (void)payButtonTapped {
    if (!self.selectedProduct || !self.selectedCard) {
        return;
    }
    
    self.isLoading = YES;
    self.errorMessage = nil;
    self.successMessage = nil;
    [self updatePayButtonState];
    [self.loadingIndicator startAnimating];
    
    // Generate signature first
    __weak typeof(self) weakSelf = self;
    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (!success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.isLoading = NO;
                strongSelf.errorMessage = error ? error.localizedDescription : @"Failed to generate signature";
                [strongSelf.loadingIndicator stopAnimating];
                [strongSelf updatePayButtonState];
                [strongSelf resetSelections];
                [strongSelf updateUI];
            });
            return;
        }
        
        // Call purchase API
        // Convert price to cents for API (global 3DS uses dollars; gateway-specific uses cents)
        NSDecimalNumber *priceInCents = strongSelf.useGatewaySpecific3DS
            ? strongSelf.selectedProduct.price
            : [strongSelf.selectedProduct.price decimalNumberByMultiplyingBy:[AppConstants centsPerDollar]];
        
        PurchaseAPIClient *client = [[SpreedlyConfigManager shared] createPurchaseAPIClient];
        [client purchaseWithPaymentMethodToken:strongSelf.selectedCard.paymentMethodToken
                                         amount:priceInCents
                                   currencyCode:[AppConstants defaultCurrencyCode]
                           useGatewaySpecific3DS:strongSelf.useGatewaySpecific3DS
                                     completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf.isLoading = NO;
                [strongSelf.loadingIndicator stopAnimating];
                [strongSelf updatePayButtonState];
                
                if (error) {
                    strongSelf.errorMessage = error.localizedDescription;
                    [strongSelf resetSelections];
                    [strongSelf updateUI];
                    return;
                }
                
                if (!response) {
                    strongSelf.errorMessage = @"No response received";
                    [strongSelf resetSelections];
                    [strongSelf updateUI];
                    return;
                }
                
                // Check for errors in response
                if (response.errors && response.errors.count > 0) {
                    NSMutableArray<NSString *> *messages = [NSMutableArray array];
                    for (PurchaseError *error in response.errors) {
                        if (error.message.length > 0) {
                            [messages addObject:error.message];
                        }
                    }
                    strongSelf.errorMessage = messages.count > 0 ? [messages componentsJoinedByString:@", "] : @"Purchase failed";
                    [strongSelf resetSelections];
                    [strongSelf updateUI];
                    return;
                }
                
                // Extract transaction token and check for 3DS
                if (response.transaction) {
                    strongSelf.transactionToken = response.transaction.token;
                    
                    if (strongSelf.useGatewaySpecific3DS) {
                        NSString *state = [response.transaction.state lowercaseString] ?: @"";
                        NSString *requiredAction = response.transaction.requiredAction ?: response.transaction.scaAuthentication.requiredAction;
                        requiredAction = [requiredAction lowercaseString];
                        BOOL requiresDeviceFingerprint = [requiredAction isEqualToString:@"device_fingerprint"];
                        
                        if ([state isEqualToString:@"pending"] || requiresDeviceFingerprint) {
                            // Gateway-specific flow: present challenge container and wait for trigger completion
                            [strongSelf present3DSChallenge];
                        } else if ([state isEqualToString:@"succeeded"]) {
                            strongSelf.successMessage = @"Payment successful. The transaction has been completed.";
                            [strongSelf resetSelections];
                            [strongSelf updateUI];
                        } else {
                            strongSelf.errorMessage = @"Purchase failed";
                            [strongSelf resetSelections];
                            [strongSelf updateUI];
                        }
                    } else {
                        // Check if 3DS is required
                        if (response.transaction.scaAuthentication) {
                            [strongSelf present3DSChallenge];
                        } else {
                            // No 3DS required - transaction complete
                            strongSelf.successMessage = @"Payment successful. The transaction has been completed.";
                            [strongSelf resetSelections];
                            [strongSelf updateUI];
                        }
                    }
                } else {
                    strongSelf.errorMessage = [AppConstants noTransactionDataMessage];
                    [strongSelf resetSelections];
                    [strongSelf updateUI];
                }
            });
        }];
    }];
}

- (void)present3DSChallenge {
    if (!self.transactionToken) {
        self.errorMessage = @"Missing 3DS challenge transaction token";
        [self updateUI];
        return;
    }
    
    DoChallengeIfNeededViewController *challengeVC = [[DoChallengeIfNeededViewController alloc]
        initWithTransactionToken:self.transactionToken
        onDismiss:^{
            // Challenge dismissed
        }];
    
    [self presentViewController:challengeVC animated:YES completion:nil];
}

- (void)setupGatewaySpecificObservers {
    __weak typeof(self) weakSelf = self;
    self.gatewaySpecificTriggerObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:GatewaySpecific3DSTriggerNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification * _Nonnull note) {
                    NSString *transactionToken = note.userInfo[@"transactionToken"];
                    // Only handle trigger for the current flow - ignore triggers from other flows (e.g. SwiftUI tab)
                    if (transactionToken.length > 0 && weakSelf.transactionToken.length > 0 &&
                        [transactionToken isEqualToString:weakSelf.transactionToken]) {
                        [weakSelf handleGatewaySpecificTriggerCompletionWithToken:transactionToken];
                    }
                }];
}

- (void)handleGatewaySpecificTriggerCompletionWithToken:(NSString *)transactionToken {
    if (!transactionToken.length) {
        return;
    }
    
    PurchaseAPIClient *client = [[SpreedlyConfigManager shared] createPurchaseAPIClient];
    __weak typeof(self) weakSelf = self;
    [client completeTransactionWithToken:transactionToken completion:^(NSData * _Nullable responseData, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            if (error) {
                strongSelf.successMessage = nil;
                if ([[error.localizedDescription lowercaseString] containsString:@"forced failure"]) {
                    strongSelf.errorMessage = @"Forced Failure";
                } else {
                    strongSelf.errorMessage = [NSString stringWithFormat:@"Failed to complete 3DS flow: %@", error.localizedDescription];
                }
                if (strongSelf.presentedViewController) {
                    [strongSelf.presentedViewController dismissViewControllerAnimated:YES completion:nil];
                }
                [strongSelf resetSelections];
                [strongSelf updateUI];
                return;
            }
            
            if (!responseData) {
                strongSelf.successMessage = nil;
                strongSelf.errorMessage = @"Failed to complete 3DS flow: empty response";
                [strongSelf resetSelections];
                [strongSelf updateUI];
                return;
            }

            NSError *parseError = nil;
            PurchaseResponse *completeResponse = [PurchaseResponse fromJSONData:responseData error:&parseError];
            PurchaseTransaction *transaction = completeResponse.transaction;
            if (transaction) {
                NSString *state = [transaction.state lowercaseString] ?: @"";
                if ([state isEqualToString:@"succeeded"]) {
                    strongSelf.errorMessage = nil;
                    strongSelf.successMessage = @"Payment successful. The transaction has been completed.";
                    if (strongSelf.presentedViewController) {
                        [strongSelf.presentedViewController dismissViewControllerAnimated:YES completion:nil];
                    }
                    [strongSelf resetSelections];
                    [strongSelf updateUI];
                    return;
                }
            }
            
            NSError *finalizeError = nil;
            [GatewaySpecific3DSObjCBridge finalizeTransactionForTransactionToken:transactionToken
                                                              completeResponseData:responseData
                                                                             error:&finalizeError];
            if (finalizeError) {
                strongSelf.successMessage = nil;
                strongSelf.errorMessage = [NSString stringWithFormat:@"Failed to finalize 3DS flow: %@", finalizeError.localizedDescription];
                [strongSelf resetSelections];
                [strongSelf updateUI];
            } else {
                // Do NOT dismiss or mark success here; gateway-specific flows may still require a challenge.
                // Final result is delivered via ThreeDSChallengeDelegate.
            }
        });
    }];
}

- (void)updateUI {
    UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &ThreeDSErrorContainerKey);
    
    // Update result container
    if (self.successMessage) {
        // Clear error state before showing success
        self.errorMessage = nil;
        if (errorContainer) {
            errorContainer.hidden = YES;
            [errorContainer removeFromSuperview];
            objc_setAssociatedObject(self.errorLabel, &ThreeDSErrorContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            errorContainer = nil;
        }
        self.errorLabel.hidden = YES;
        
        [self setupResultContainer];
        self.resultContainer.hidden = NO;
    } else if (self.errorMessage) {
        // Clear success state before showing error
        self.successMessage = nil;
        self.resultContainer.hidden = YES;
        // Create error message view with proper styling
        [self setupErrorMessageView];
        self.errorLabel.hidden = YES; // Hide the old simple label
    } else {
        self.resultContainer.hidden = YES;
        self.errorLabel.hidden = YES;
        if (errorContainer) {
            errorContainer.hidden = YES;
        }
    }
}

- (void)setupErrorMessageView {
    // Remove existing subviews from error label's superview if it's a container
    // For now, we'll use a simple label approach matching the Swift MessageView pattern
    // In a more complex implementation, we could create a container view similar to resultContainer
    
    // Create error container view if it doesn't exist
    UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &ThreeDSErrorContainerKey);
    
    if (!errorContainer || errorContainer.superview == nil) {
        if (errorContainer && errorContainer.superview == nil) {
            objc_setAssociatedObject(self.errorLabel, &ThreeDSErrorContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            errorContainer = nil;
        }
        errorContainer = [[UIView alloc] init];
        errorContainer.backgroundColor = [[ThemeHelper errorColor] colorWithAlphaComponent:0.1];
        errorContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
        errorContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [ThemeHelper applySmallShadowToView:errorContainer];
        errorContainer.accessibilityIdentifier = @"three-ds-challenge-error-message";
        [self.contentView insertSubview:errorContainer belowSubview:self.errorLabel];
        objc_setAssociatedObject(self.errorLabel, &ThreeDSErrorContainerKey, errorContainer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Update constraints for error container - add horizontal padding like MessageView
        [NSLayoutConstraint activateConstraints:@[
            [errorContainer.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:[ThemeHelper spacingLG]],
            [errorContainer.leadingAnchor constraintEqualToAnchor:self.payButton.leadingAnchor],
            [errorContainer.trailingAnchor constraintEqualToAnchor:self.payButton.trailingAnchor],
            [errorContainer.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]]
        ]];
    }
    
    // Remove existing subviews from error container
    for (UIView *subview in errorContainer.subviews) {
        [subview removeFromSuperview];
    }
    
    // VStack equivalent
    UIStackView *vStack = [[UIStackView alloc] init];
    vStack.axis = UILayoutConstraintAxisVertical;
    vStack.spacing = [ThemeHelper spacingSM];
    vStack.alignment = UIStackViewAlignmentLeading;
    vStack.translatesAutoresizingMaskIntoConstraints = NO;
    [errorContainer addSubview:vStack];
    
    // HStack for icon and title
    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.axis = UILayoutConstraintAxisHorizontal;
    hStack.spacing = [ThemeHelper spacingSM];
    hStack.alignment = UIStackViewAlignmentCenter;
    hStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create error icon
    UIImageView *errorIcon = [[UIImageView alloc] init];
    errorIcon.image = [UIImage systemImageNamed:@"exclamationmark.circle.fill"];
    errorIcon.tintColor = [ThemeHelper errorColor];
    errorIcon.translatesAutoresizingMaskIntoConstraints = NO;
    errorIcon.accessibilityIdentifier = @"three-ds-challenge-error-icon";
    errorIcon.accessibilityLabel = @"Error";
    errorIcon.accessibilityHint = @"Error indicator icon";
    errorIcon.accessibilityTraits = UIAccessibilityTraitImage;
    [hStack addArrangedSubview:errorIcon];
    
    // Create error title
    UILabel *errorTitle = [[UILabel alloc] init];
    errorTitle.text = @"Error";
    errorTitle.font = [ThemeHelper subtitleFont];
    errorTitle.textColor = [ThemeHelper errorColor];
    errorTitle.translatesAutoresizingMaskIntoConstraints = NO;
    errorTitle.accessibilityIdentifier = @"three-ds-challenge-error-title";
    errorTitle.accessibilityLabel = @"Error";
    errorTitle.accessibilityHint = @"Error message title";
    errorTitle.accessibilityTraits = UIAccessibilityTraitHeader;
    [hStack addArrangedSubview:errorTitle];
    
    [vStack addArrangedSubview:hStack];
    
    // Create error message
    UILabel *errorMessageLabel = [[UILabel alloc] init];
    errorMessageLabel.text = self.errorMessage;
    errorMessageLabel.font = [ThemeHelper bodyFont];
    errorMessageLabel.textColor = [ThemeHelper textColor];
    errorMessageLabel.numberOfLines = 0;
    errorMessageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    errorMessageLabel.accessibilityIdentifier = @"three-ds-challenge-error-message-text";
    errorMessageLabel.accessibilityHint = @"Error message from 3DS challenge process";
    [vStack addArrangedSubview:errorMessageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [vStack.topAnchor constraintEqualToAnchor:errorContainer.topAnchor constant:[ThemeHelper spacingMD]],
        [vStack.leadingAnchor constraintEqualToAnchor:errorContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
        [vStack.trailingAnchor constraintEqualToAnchor:errorContainer.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [vStack.bottomAnchor constraintEqualToAnchor:errorContainer.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    // Hide the old error label and show the container
    self.errorLabel.hidden = YES;
    errorContainer.hidden = NO;
}

- (void)setupResultContainer {
    // Remove existing subviews
    for (UIView *subview in self.resultContainer.subviews) {
        [subview removeFromSuperview];
    }
    
    // Update container styling to match MessageView
    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    [ThemeHelper applySmallShadowToView:self.resultContainer];
    
    // VStack equivalent
    UIStackView *vStack = [[UIStackView alloc] init];
    vStack.axis = UILayoutConstraintAxisVertical;
    vStack.spacing = [ThemeHelper spacingSM];
    vStack.alignment = UIStackViewAlignmentLeading;
    vStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultContainer addSubview:vStack];
    
    // HStack for icon and title
    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.axis = UILayoutConstraintAxisHorizontal;
    hStack.spacing = [ThemeHelper spacingSM];
    hStack.alignment = UIStackViewAlignmentCenter;
    hStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIImageView *successIcon = [[UIImageView alloc] init];
    successIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    successIcon.tintColor = [ThemeHelper successColor];
    successIcon.translatesAutoresizingMaskIntoConstraints = NO;
    successIcon.accessibilityIdentifier = @"three-ds-challenge-success-icon";
    successIcon.accessibilityLabel = @"Success";
    successIcon.accessibilityHint = @"Success indicator icon";
    successIcon.accessibilityTraits = UIAccessibilityTraitImage;
    [hStack addArrangedSubview:successIcon];
    
    UILabel *successLabel = [[UILabel alloc] init];
    successLabel.text = @"Success!";
    successLabel.font = [ThemeHelper subtitleFont];
    successLabel.textColor = [ThemeHelper successColor];
    successLabel.translatesAutoresizingMaskIntoConstraints = NO;
    successLabel.accessibilityIdentifier = @"three-ds-challenge-success-title";
    successLabel.accessibilityLabel = @"Success!";
    successLabel.accessibilityHint = @"Transaction success message";
    successLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [hStack addArrangedSubview:successLabel];
    
    [vStack addArrangedSubview:hStack];
    
    UILabel *messageLabel = [[UILabel alloc] init];
    messageLabel.text = self.successMessage;
    messageLabel.font = [ThemeHelper bodyFont];
    messageLabel.textColor = [ThemeHelper textColor];
    messageLabel.numberOfLines = 0;
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vStack addArrangedSubview:messageLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [vStack.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:[ThemeHelper spacingMD]],
        [vStack.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
        [vStack.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [vStack.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
}

// MARK: - Helper Methods

/// Resets the selected product and card after API response
/// This method must be called on the main thread as it modifies UI state
- (void)resetSelections {
    self.selectedProduct = nil;
    self.selectedCard = nil;
    [self updateProductSelection];
    [self updateCardsList];
    [self updatePayButtonState];
}

#pragma mark - Cleanup

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self cleanupThreeDSDelegate];
}

- (void)dealloc {
    [self cleanupThreeDSDelegate];
    if (self.gatewaySpecificTriggerObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.gatewaySpecificTriggerObserver];
        self.gatewaySpecificTriggerObserver = nil;
    }
}

- (void)cleanupThreeDSDelegate {
    if ([Spreedly shared].threeDSChallengeDelegate == self) {
        [Spreedly shared].threeDSChallengeDelegate = nil;
    }
}

#pragma mark - SpreedlyThreeDSChallengeDelegate

- (void)threeDSChallengeDidComplete:(ThreeDSChallengeResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isLoading = NO;
        [self.loadingIndicator stopAnimating];
        [self updatePayButtonState];
        
        if (result.isSuccess) {
            // 3DS Challenge completed successfully
            self.errorMessage = nil;
            
            // Dismiss challenge view controller
            if (self.presentedViewController) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
            
            // The SDK has already called three_ds_automated_complete API and status API internally
            // Result is based on status API response
            self.successMessage = @"Payment successful. The transaction has been completed.";
            [self resetSelections];
            [self updateUI];
            
        } else if (result.isFailure) {
            // 3DS Challenge failed
            // Check for specific error codes from status API and show human-readable messages
            NSString *errorMsg = @"Payment failed";
            if (result.failureDetails && result.failureDetails.message) {
                if ([[result.failureDetails.message lowercaseString] containsString:@"forced failure"]) {
                    errorMsg = @"Forced Failure";
                } else if ([result.failureDetails.message isEqualToString:@"messages.failed_sca_authentication"]) {
                    errorMsg = @"Transaction failed due to failed authentication. Please try again.";
                } else {
                    errorMsg = [NSString stringWithFormat:@"Payment failed: %@", result.failureDetails.message];
                }
            } else if (result.error) {
                errorMsg = [NSString stringWithFormat:@"Payment failed: %@", result.error.localizedDescription];
            }
            self.errorMessage = errorMsg;
            
            if (self.presentedViewController) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
            
            [self resetSelections];
            [self updateUI];
            
        } else if (result.isCanceled) {
            // User canceled 3DS challenge
            if (result.failureDetails.message &&
                [[result.failureDetails.message lowercaseString] containsString:@"forced failure"]) {
                self.errorMessage = @"Forced Failure";
            } else if (result.error.localizedDescription &&
                       [[result.error.localizedDescription lowercaseString] containsString:@"forced failure"]) {
                self.errorMessage = @"Forced Failure";
            } else {
                self.errorMessage = @"Payment canceled by user";
            }
            
            if (self.presentedViewController) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
            
            [self resetSelections];
            [self updateUI];
        }
    });
}

@end

