//
//  CVVRecachingDemoViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  Created on 02/07/25.
//

#import "CVVRecachingDemoViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <SwiftUI/SwiftUI.h>
#import <objc/runtime.h>
#import "SpreedlyConfigManager.h"
#import "FetchPaymentMethodsAPIClient.h"
#import "FetchPaymentMethodsModels.h"
#import "SavedCard.h"
#import "ThemeHelper.h"

// MARK: - Theme Option Enum Helper
typedef NS_ENUM(NSInteger, ThemeOption) {
    ThemeOptionDefault = 0,
    ThemeOptionBlue = 1,
    ThemeOptionGreen = 2,
    ThemeOptionPurple = 3
};

@interface CVVRecachingDemoViewController () <UIScrollViewDelegate, SpreedlyPaymentDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIView *informationContainer;
@property (nonatomic, strong) UIView *configurationContainer;
@property (nonatomic, strong) UIView *themeConfigurationContainer;
@property (nonatomic, strong) UIView *cardsListContainer;
@property (nonatomic, strong) UIButton *recacheButton;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

// Configuration UI
@property (nonatomic, strong) UISegmentedControl *presentationModeSegmentedControl;
@property (nonatomic, strong) UITextField *labelTextField;
@property (nonatomic, strong) UITextField *placeholderTextField;
@property (nonatomic, strong) UITextField *buttonTextField;
@property (nonatomic, strong) UITextField *cancelButtonTextField;
@property (nonatomic, strong) UISwitch *allowBlankNameSwitch;
@property (nonatomic, strong) UISwitch *allowExpiredDateSwitch;
@property (nonatomic, strong) UISwitch *allowBlankDateSwitch;

// Theme Configuration UI
@property (nonatomic, strong) UISwitch *useCustomThemeSwitch;
@property (nonatomic, strong) UILabel *currentThemeLabel;
@property (nonatomic, strong) UILabel *themeNameLabel;
@property (nonatomic, strong) UIView *themeButtonsContainer;
@property (nonatomic, strong) UIButton *blueThemeButton;
@property (nonatomic, strong) UIButton *greenThemeButton;
@property (nonatomic, strong) UIButton *purpleThemeButton;
@property (nonatomic, strong) UIButton *resetThemeButton;
@property (nonatomic, strong) NSLayoutConstraint *themeContainerBottomConstraint;

// Cards List
@property (nonatomic, strong) UIStackView *cardsStackView;

// Data
@property (nonatomic, strong) NSArray<SavedCard *> *savedCards;
@property (nonatomic, strong) SavedCard *selectedCard;
@property (nonatomic, assign) ThemeOption selectedTheme;
@property (nonatomic, strong) SPLThemeConfig *lightThemeConfig;
@property (nonatomic, strong) SPLThemeConfig *darkThemeConfig;
@property (nonatomic, assign) BOOL useCustomTheme;

// State
@property (nonatomic, strong) PaymentResult *paymentResult;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isLoadingCards;

@end

@implementation CVVRecachingDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"CVV Recaching";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // MARK: - Initialize State
    self.selectedTheme = ThemeOptionDefault;
    self.useCustomTheme = NO;
    self.selectedCard = nil;
    self.savedCards = @[];
    self.isLoadingCards = NO;
    
    [self setupUI];
    [self setupConstraints];
    
    // Initialize button state (disabled when no card is selected)
    [self updateRecacheButtonState];
    
    // Initialize theme display and button states
    [self updateCurrentThemeDisplay];
    [self updateThemeButtonStates];
    
    // Set scroll view delegate
    self.scrollView.delegate = self;
    
    // MARK: - Set Up Payment Result Delegate
    // Delegate receives recaching results via paymentDidComplete: method
    [Spreedly.shared setPaymentDelegate:self];
    
    // MARK: - Fetch Payment Methods from API
    [self fetchPaymentMethods];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Ensure button state is correct when view appears
    [self updateRecacheButtonState];
}

- (void)dealloc {
    // Cleanup if needed
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
                if ([error.domain isEqualToString:@"FetchPaymentMethodsAPIError"]) {
                    strongSelf.errorMessage = error.localizedDescription;
                } else {
                    strongSelf.errorMessage = [NSString stringWithFormat:@"Failed to load payment methods: %@", error.localizedDescription];
                }
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
                // Filter only credit cards
                if (![paymentMethod.paymentMethodType isEqualToString:@"credit_card"]) {
                    continue;
                }
                
                // Validate required fields
                if (!paymentMethod.lastFourDigits || !paymentMethod.cardType) {
                    continue;
                }
                
                SavedCard *card = [[SavedCard alloc] init];
                card.cardId = paymentMethod.token;
                card.paymentMethodToken = paymentMethod.token;
                card.lastFourDigits = paymentMethod.lastFourDigits;
                
                // Format card type for display (replace underscores and capitalize)
                NSString *cardType = paymentMethod.cardType;
                cardType = [cardType stringByReplacingOccurrencesOfString:@"_" withString:@" "];
                cardType = [cardType capitalizedString];
                card.cardType = cardType;
                card.cardBrand = [paymentMethod.cardType lowercaseString];
                
                // Format expiry month and year
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

- (void)setupUI {
    // Scroll View
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];
    
    // Content View
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    
    // Title Label
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"CVV Recaching";
    self.titleLabel.font = [ThemeHelper screenTitleFont];
    self.titleLabel.textColor = [ThemeHelper textColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.accessibilityIdentifier = @"cvv-recaching-title";
    self.titleLabel.accessibilityLabel = @"CVV Recaching";
    self.titleLabel.accessibilityHint = @"CVV recaching demonstration screen";
    self.titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.contentView addSubview:self.titleLabel];
    
    // Description Label
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = @"Update CVV for saved payment methods to enable repeat transactions";
    self.descriptionLabel.font = [ThemeHelper screenBodyFont];
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.textColor = [ThemeHelper textSecondaryColor];
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionLabel.accessibilityIdentifier = @"cvv-recaching-description";
    self.descriptionLabel.accessibilityHint = @"Shows how to update CVV for saved payment methods";
    [self.contentView addSubview:self.descriptionLabel];
    
    // Information Container
    self.informationContainer = [self createInformationContainer];
    
    // Configuration Container
    self.configurationContainer = [self createConfigurationContainer];
    
    // Theme Configuration Container
    self.themeConfigurationContainer = [self createThemeConfigurationContainer];
    
    // Cards List Container
    self.cardsListContainer = [self createCardsListContainer];
    
    // Recache Button
    self.recacheButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.recacheButton setTitle:@"Recache CVV" forState:UIControlStateNormal];
    [self.recacheButton setTitle:@"Recache CVV" forState:UIControlStateDisabled];
    self.recacheButton.titleLabel.font = [ThemeHelper buttonFont];
    self.recacheButton.backgroundColor = [ThemeHelper primaryColor];
    [self.recacheButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.recacheButton setTitleColor:[UIColor whiteColor] forState:UIControlStateDisabled];
    self.recacheButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.recacheButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.recacheButton.enabled = NO;
    self.recacheButton.alpha = 0.6;
    self.recacheButton.accessibilityIdentifier = @"cvv-recaching-recache-button";
    self.recacheButton.accessibilityLabel = @"Recache CVV";
    self.recacheButton.accessibilityHint = @"Button to trigger CVV recaching for selected card";
    [self.recacheButton addTarget:self action:@selector(recacheButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.recacheButton];
    
    // Result Container
    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.resultContainer.hidden = YES;
    self.resultContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultContainer.accessibilityIdentifier = @"cvv-recaching-success-result-section";
    [ThemeHelper applySmallShadowToView:self.resultContainer];
    [self.contentView addSubview:self.resultContainer];
    
    // Error Label (will be replaced with error container in updateUI)
    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.textColor = [ThemeHelper errorColor];
    self.errorLabel.font = [ThemeHelper bodyFont];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.accessibilityIdentifier = @"cvv-recaching-error-message";
    self.errorLabel.accessibilityHint = @"Error message from CVV recaching process";
    [self.contentView addSubview:self.errorLabel];
    
    // Loading Indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
}

- (UIView *)createInformationContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.accessibilityIdentifier = @"cvv-recaching-about-section";
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"About CVV Recaching:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"cvv-recaching-about-title";
    titleLabel.accessibilityLabel = @"About CVV Recaching";
    titleLabel.accessibilityHint = @"Section title explaining CVV recaching";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = [ThemeHelper spacingXS];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stackView];
    
    // CVV recaching flow:
    // 1. CVV values cannot be stored (PCI compliance)
    // 2. Customer must re-enter CVV for saved cards
    // 3. SDK provides secure UI for CVV collection
    // 4. After recaching, token is updated and ready for transactions
    NSArray<NSString *> *items = @[
        @"• CVV values cannot be stored for security compliance",
        @"• Recaching updates the CVV for saved payment methods",
        @"• SDK provides secure UI for CVV entry",
        @"• Updated payment method can be used for transactions"
    ];
    
    for (NSString *item in items) {
        UILabel *itemLabel = [[UILabel alloc] init];
        itemLabel.text = item;
        itemLabel.font = [UIFont systemFontOfSize:15];
        itemLabel.textColor = [ThemeHelper textSecondaryColor];
        itemLabel.numberOfLines = 2;
        itemLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [stackView addArrangedSubview:itemLabel];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [stackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [stackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [stackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [stackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    return container;
}

- (UIView *)createConfigurationContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.accessibilityIdentifier = @"cvv-recaching-configuration-section";
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Configuration Options:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"cvv-recaching-configuration-title";
    titleLabel.accessibilityLabel = @"Configuration Options";
    titleLabel.accessibilityHint = @"Section title for configuration options";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    // Presentation Mode
    UILabel *presentationModeLabel = [[UILabel alloc] init];
    presentationModeLabel.text = @"Presentation Mode:";
    presentationModeLabel.font = [ThemeHelper screenSubheadlineFont];
    presentationModeLabel.textColor = [ThemeHelper textColor];
    presentationModeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    presentationModeLabel.accessibilityIdentifier = @"cvv-recaching-presentation-mode-label";
    [container addSubview:presentationModeLabel];
    
    self.presentationModeSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Sheet", @"Alert"]];
    self.presentationModeSegmentedControl.selectedSegmentIndex = 0;
    self.presentationModeSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.presentationModeSegmentedControl.accessibilityIdentifier = @"cvv-recaching-presentation-mode-picker";
    [container addSubview:self.presentationModeSegmentedControl];
    
    // Label Text
    UILabel *labelTextLabel = [[UILabel alloc] init];
    labelTextLabel.text = @"Label Text:";
    labelTextLabel.font = [ThemeHelper screenSubheadlineFont];
    labelTextLabel.textColor = [ThemeHelper textColor];
    labelTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    labelTextLabel.accessibilityIdentifier = @"cvv-recaching-label-text-label";
    [container addSubview:labelTextLabel];
    
    self.labelTextField = [[UITextField alloc] init];
    self.labelTextField.text = @"CVV";
    self.labelTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.labelTextField.font = [ThemeHelper fieldFont];
    self.labelTextField.textColor = [ThemeHelper textColor];
    self.labelTextField.layer.borderColor = [ThemeHelper borderColor].CGColor;
    self.labelTextField.layer.borderWidth = 1.0;
    self.labelTextField.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.labelTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.labelTextField.accessibilityIdentifier = @"cvv-recaching-label-text-field";
    [container addSubview:self.labelTextField];
    
    // Placeholder Text
    UILabel *placeholderTextLabel = [[UILabel alloc] init];
    placeholderTextLabel.text = @"Placeholder Text:";
    placeholderTextLabel.font = [ThemeHelper screenSubheadlineFont];
    placeholderTextLabel.textColor = [ThemeHelper textColor];
    placeholderTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    placeholderTextLabel.accessibilityIdentifier = @"cvv-recaching-placeholder-text-label";
    [container addSubview:placeholderTextLabel];
    
    self.placeholderTextField = [[UITextField alloc] init];
    self.placeholderTextField.text = @"123";
    self.placeholderTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.placeholderTextField.font = [ThemeHelper fieldFont];
    self.placeholderTextField.textColor = [ThemeHelper textColor];
    self.placeholderTextField.layer.borderColor = [ThemeHelper borderColor].CGColor;
    self.placeholderTextField.layer.borderWidth = 1.0;
    self.placeholderTextField.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.placeholderTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderTextField.accessibilityIdentifier = @"cvv-recaching-placeholder-text-field";
    [container addSubview:self.placeholderTextField];
    
    // Button Text
    UILabel *buttonTextLabel = [[UILabel alloc] init];
    buttonTextLabel.text = @"Button Text:";
    buttonTextLabel.font = [ThemeHelper screenSubheadlineFont];
    buttonTextLabel.textColor = [ThemeHelper textColor];
    buttonTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    buttonTextLabel.accessibilityIdentifier = @"cvv-recaching-button-text-label";
    [container addSubview:buttonTextLabel];
    
    self.buttonTextField = [[UITextField alloc] init];
    self.buttonTextField.text = @"Confirm";
    self.buttonTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.buttonTextField.font = [ThemeHelper fieldFont];
    self.buttonTextField.textColor = [ThemeHelper textColor];
    self.buttonTextField.layer.borderColor = [ThemeHelper borderColor].CGColor;
    self.buttonTextField.layer.borderWidth = 1.0;
    self.buttonTextField.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.buttonTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.buttonTextField.accessibilityIdentifier = @"cvv-recaching-button-text-field";
    [container addSubview:self.buttonTextField];
    
    // Cancel Button Text
    UILabel *cancelButtonTextLabel = [[UILabel alloc] init];
    cancelButtonTextLabel.text = @"Cancel Button Text:";
    cancelButtonTextLabel.font = [ThemeHelper screenSubheadlineFont];
    cancelButtonTextLabel.textColor = [ThemeHelper textColor];
    cancelButtonTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    cancelButtonTextLabel.accessibilityIdentifier = @"cvv-recaching-cancel-button-text-label";
    [container addSubview:cancelButtonTextLabel];
    
    self.cancelButtonTextField = [[UITextField alloc] init];
    self.cancelButtonTextField.text = @"Cancel";
    self.cancelButtonTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.cancelButtonTextField.font = [ThemeHelper fieldFont];
    self.cancelButtonTextField.textColor = [ThemeHelper textColor];
    self.cancelButtonTextField.layer.borderColor = [ThemeHelper borderColor].CGColor;
    self.cancelButtonTextField.layer.borderWidth = 1.0;
    self.cancelButtonTextField.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.cancelButtonTextField.translatesAutoresizingMaskIntoConstraints = NO;
    self.cancelButtonTextField.accessibilityIdentifier = @"cvv-recaching-cancel-button-text-field";
    [container addSubview:self.cancelButtonTextField];

    // Allow Blank Name
    UILabel *allowBlankNameLabel = [[UILabel alloc] init];
    allowBlankNameLabel.text = @"Allow Blank Name";
    allowBlankNameLabel.font = [ThemeHelper screenBodyFont];
    allowBlankNameLabel.textColor = [ThemeHelper textColor];
    allowBlankNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    allowBlankNameLabel.accessibilityIdentifier = @"cvv-recaching-allow-blank-name-label";
    [container addSubview:allowBlankNameLabel];
    
    self.allowBlankNameSwitch = [[UISwitch alloc] init];
    self.allowBlankNameSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowBlankNameSwitch.accessibilityIdentifier = @"cvv-recaching-allow-blank-name-toggle";
    self.allowBlankNameSwitch.accessibilityLabel = @"Allow Blank Name";
    self.allowBlankNameSwitch.accessibilityHint = @"Toggle to allow or require name fields";
    [self.allowBlankNameSwitch setOn:NO];
    [container addSubview:self.allowBlankNameSwitch];
    
    // Allow Expired Date
    UILabel *allowExpiredDateLabel = [[UILabel alloc] init];
    allowExpiredDateLabel.text = @"Allow Expired Date";
    allowExpiredDateLabel.font = [ThemeHelper screenBodyFont];
    allowExpiredDateLabel.textColor = [ThemeHelper textColor];
    allowExpiredDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    allowExpiredDateLabel.accessibilityIdentifier = @"cvv-recaching-allow-expired-date-label";
    [container addSubview:allowExpiredDateLabel];
    
    self.allowExpiredDateSwitch = [[UISwitch alloc] init];
    self.allowExpiredDateSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowExpiredDateSwitch.accessibilityIdentifier = @"cvv-recaching-allow-expired-date-toggle";
    self.allowExpiredDateSwitch.accessibilityLabel = @"Allow Expired Date";
    self.allowExpiredDateSwitch.accessibilityHint = @"Toggle to allow or disallow expired dates";
    [self.allowExpiredDateSwitch setOn:NO];
    [container addSubview:self.allowExpiredDateSwitch];
    
    // Allow Blank Date
    UILabel *allowBlankDateLabel = [[UILabel alloc] init];
    allowBlankDateLabel.text = @"Allow Blank Date";
    allowBlankDateLabel.font = [ThemeHelper screenBodyFont];
    allowBlankDateLabel.textColor = [ThemeHelper textColor];
    allowBlankDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    allowBlankDateLabel.accessibilityIdentifier = @"cvv-recaching-allow-blank-date-label";
    [container addSubview:allowBlankDateLabel];
    
    self.allowBlankDateSwitch = [[UISwitch alloc] init];
    self.allowBlankDateSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowBlankDateSwitch.accessibilityIdentifier = @"cvv-recaching-allow-blank-date-toggle";
    self.allowBlankDateSwitch.accessibilityLabel = @"Allow Blank Date";
    self.allowBlankDateSwitch.accessibilityHint = @"Toggle to allow or require expiration date";
    [self.allowBlankDateSwitch setOn:NO];
    [container addSubview:self.allowBlankDateSwitch];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [presentationModeLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [presentationModeLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        
        [self.presentationModeSegmentedControl.centerYAnchor constraintEqualToAnchor:presentationModeLabel.centerYAnchor],
        [self.presentationModeSegmentedControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.presentationModeSegmentedControl.leadingAnchor constraintEqualToAnchor:presentationModeLabel.trailingAnchor constant:[ThemeHelper spacingSM]],
        
        [labelTextLabel.topAnchor constraintEqualToAnchor:presentationModeLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [labelTextLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [labelTextLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [self.labelTextField.topAnchor constraintEqualToAnchor:labelTextLabel.bottomAnchor constant:[ThemeHelper spacingXS]],
        [self.labelTextField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.labelTextField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.labelTextField.heightAnchor constraintEqualToConstant:44],
        
        [placeholderTextLabel.topAnchor constraintEqualToAnchor:self.labelTextField.bottomAnchor constant:[ThemeHelper spacingMD]],
        [placeholderTextLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [placeholderTextLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [self.placeholderTextField.topAnchor constraintEqualToAnchor:placeholderTextLabel.bottomAnchor constant:[ThemeHelper spacingXS]],
        [self.placeholderTextField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.placeholderTextField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.placeholderTextField.heightAnchor constraintEqualToConstant:44],
        
        [buttonTextLabel.topAnchor constraintEqualToAnchor:self.placeholderTextField.bottomAnchor constant:[ThemeHelper spacingMD]],
        [buttonTextLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [buttonTextLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [self.buttonTextField.topAnchor constraintEqualToAnchor:buttonTextLabel.bottomAnchor constant:[ThemeHelper spacingXS]],
        [self.buttonTextField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.buttonTextField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.buttonTextField.heightAnchor constraintEqualToConstant:44],
        
        [cancelButtonTextLabel.topAnchor constraintEqualToAnchor:self.buttonTextField.bottomAnchor constant:[ThemeHelper spacingMD]],
        [cancelButtonTextLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [cancelButtonTextLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [self.cancelButtonTextField.topAnchor constraintEqualToAnchor:cancelButtonTextLabel.bottomAnchor constant:[ThemeHelper spacingXS]],
        [self.cancelButtonTextField.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.cancelButtonTextField.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.cancelButtonTextField.heightAnchor constraintEqualToConstant:44],
        
        [allowBlankNameLabel.topAnchor constraintEqualToAnchor:self.cancelButtonTextField.bottomAnchor constant:[ThemeHelper spacingMD]],
        [allowBlankNameLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [allowBlankNameLabel.centerYAnchor constraintEqualToAnchor:self.allowBlankNameSwitch.centerYAnchor],
        
        [self.allowBlankNameSwitch.topAnchor constraintEqualToAnchor:self.cancelButtonTextField.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowBlankNameSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [allowExpiredDateLabel.topAnchor constraintEqualToAnchor:allowBlankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [allowExpiredDateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [allowExpiredDateLabel.centerYAnchor constraintEqualToAnchor:self.allowExpiredDateSwitch.centerYAnchor],
        
        [self.allowExpiredDateSwitch.topAnchor constraintEqualToAnchor:allowBlankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowExpiredDateSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [allowBlankDateLabel.topAnchor constraintEqualToAnchor:allowExpiredDateLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [allowBlankDateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [allowBlankDateLabel.centerYAnchor constraintEqualToAnchor:self.allowBlankDateSwitch.centerYAnchor],
        
        [self.allowBlankDateSwitch.topAnchor constraintEqualToAnchor:allowExpiredDateLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowBlankDateSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.allowBlankDateSwitch.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    return container;
}

- (UIView *)createThemeConfigurationContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.accessibilityIdentifier = @"cvv-recaching-theme-configuration-section";
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Theme Configuration:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"cvv-recaching-theme-configuration-title";
    titleLabel.accessibilityLabel = @"Theme Configuration";
    titleLabel.accessibilityHint = @"Section title for theme configuration options";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    // Use Custom Theme Switch
    UILabel *useCustomThemeLabel = [[UILabel alloc] init];
    useCustomThemeLabel.text = @"Use Custom Theme";
    useCustomThemeLabel.font = [ThemeHelper screenBodyFont];
    useCustomThemeLabel.textColor = [ThemeHelper textColor];
    useCustomThemeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:useCustomThemeLabel];
    
    self.useCustomThemeSwitch = [[UISwitch alloc] init];
    self.useCustomThemeSwitch.onTintColor = [ThemeHelper primaryColor];
    self.useCustomThemeSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.useCustomThemeSwitch.accessibilityIdentifier = @"cvv-recaching-use-custom-theme-toggle";
    self.useCustomThemeSwitch.accessibilityHint = @"Toggle to enable or disable custom theme";
    [self.useCustomThemeSwitch addTarget:self action:@selector(useCustomThemeToggled:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.useCustomThemeSwitch];
    
    // Current Theme Label
    self.currentThemeLabel = [[UILabel alloc] init];
    self.currentThemeLabel.text = @"Current Theme:";
    self.currentThemeLabel.font = [ThemeHelper screenSubheadlineFont];
    self.currentThemeLabel.textColor = [ThemeHelper textColor];
    self.currentThemeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.currentThemeLabel.accessibilityIdentifier = @"cvv-recaching-current-theme";
    self.currentThemeLabel.accessibilityLabel = @"Current Theme";
    [container addSubview:self.currentThemeLabel];
    
    // Create a container for the theme name to match SwiftUI styling
    self.themeNameLabel = [[UILabel alloc] init];
    self.themeNameLabel.text = @"Default";
    self.themeNameLabel.font = [ThemeHelper screenSubheadlineFont];
    self.themeNameLabel.textColor = [ThemeHelper textSecondaryColor];
    self.themeNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.themeNameLabel.accessibilityIdentifier = @"cvv-recaching-current-theme-name";
    [container addSubview:self.themeNameLabel];
    
    // Theme Buttons Container
    self.themeButtonsContainer = [[UIView alloc] init];
    self.themeButtonsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.themeButtonsContainer.hidden = !self.useCustomTheme;
    [container addSubview:self.themeButtonsContainer];
    
    // Custom Theme Colors Label
    UILabel *customThemeColorsLabel = [[UILabel alloc] init];
    customThemeColorsLabel.text = @"Custom Theme Colors:";
    customThemeColorsLabel.font = [ThemeHelper screenSubheadlineFont];
    customThemeColorsLabel.textColor = [ThemeHelper textColor];
    customThemeColorsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    customThemeColorsLabel.accessibilityIdentifier = @"cvv-recaching-custom-theme-colors-label";
    customThemeColorsLabel.accessibilityLabel = @"Custom Theme Colors";
    [self.themeButtonsContainer addSubview:customThemeColorsLabel];
    
    // Theme Buttons Horizontal Stack
    UIStackView *themeButtonsStack = [[UIStackView alloc] init];
    themeButtonsStack.axis = UILayoutConstraintAxisHorizontal;
    themeButtonsStack.spacing = [ThemeHelper spacingSM];
    themeButtonsStack.distribution = UIStackViewDistributionFillEqually;
    themeButtonsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.themeButtonsContainer addSubview:themeButtonsStack];
    
    self.blueThemeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.blueThemeButton setTitle:@"Blue Theme" forState:UIControlStateNormal];
    self.blueThemeButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.1];
    [self.blueThemeButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.blueThemeButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.blueThemeButton.layer.borderWidth = 1;
    self.blueThemeButton.layer.borderColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.3].CGColor;
    self.blueThemeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.blueThemeButton.accessibilityIdentifier = @"cvv-recaching-blue-theme-button";
    self.blueThemeButton.accessibilityLabel = @"Blue Theme";
    self.blueThemeButton.accessibilityHint = @"Button to apply blue theme";
    [self.blueThemeButton addTarget:self action:@selector(blueThemeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [themeButtonsStack addArrangedSubview:self.blueThemeButton];
    
    self.greenThemeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.greenThemeButton setTitle:@"Green Theme" forState:UIControlStateNormal];
    self.greenThemeButton.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.1];
    [self.greenThemeButton setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
    self.greenThemeButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.greenThemeButton.layer.borderWidth = 1;
    self.greenThemeButton.layer.borderColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.3].CGColor;
    self.greenThemeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.greenThemeButton.accessibilityIdentifier = @"cvv-recaching-green-theme-button";
    self.greenThemeButton.accessibilityLabel = @"Green Theme";
    self.greenThemeButton.accessibilityHint = @"Button to apply green theme";
    [self.greenThemeButton addTarget:self action:@selector(greenThemeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [themeButtonsStack addArrangedSubview:self.greenThemeButton];
    
    self.purpleThemeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.purpleThemeButton setTitle:@"Purple Theme" forState:UIControlStateNormal];
    self.purpleThemeButton.backgroundColor = [[UIColor systemPurpleColor] colorWithAlphaComponent:0.1];
    [self.purpleThemeButton setTitleColor:[UIColor systemPurpleColor] forState:UIControlStateNormal];
    self.purpleThemeButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.purpleThemeButton.layer.borderWidth = 1;
    self.purpleThemeButton.layer.borderColor = [[UIColor systemPurpleColor] colorWithAlphaComponent:0.3].CGColor;
    self.purpleThemeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.purpleThemeButton.accessibilityIdentifier = @"cvv-recaching-purple-theme-button";
    self.purpleThemeButton.accessibilityLabel = @"Purple Theme";
    self.purpleThemeButton.accessibilityHint = @"Button to apply purple theme";
    [self.purpleThemeButton addTarget:self action:@selector(purpleThemeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [themeButtonsStack addArrangedSubview:self.purpleThemeButton];
    
    self.resetThemeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resetThemeButton setTitle:@"Reset to Default" forState:UIControlStateNormal];
    self.resetThemeButton.backgroundColor = [ThemeHelper primaryColor];
    [self.resetThemeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.resetThemeButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.resetThemeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetThemeButton.accessibilityIdentifier = @"cvv-recaching-reset-theme-button";
    self.resetThemeButton.accessibilityLabel = @"Reset to Default";
    self.resetThemeButton.accessibilityHint = @"Button to reset theme to default";
    [self.resetThemeButton addTarget:self action:@selector(resetThemeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [_themeButtonsContainer addSubview:self.resetThemeButton];
    
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
        
        [self.themeButtonsContainer.topAnchor constraintEqualToAnchor:self.currentThemeLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.themeButtonsContainer.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.themeButtonsContainer.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [customThemeColorsLabel.topAnchor constraintEqualToAnchor:self.themeButtonsContainer.topAnchor],
        [customThemeColorsLabel.leadingAnchor constraintEqualToAnchor:self.themeButtonsContainer.leadingAnchor],
        [customThemeColorsLabel.trailingAnchor constraintEqualToAnchor:self.themeButtonsContainer.trailingAnchor],
        
        [themeButtonsStack.topAnchor constraintEqualToAnchor:customThemeColorsLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [themeButtonsStack.leadingAnchor constraintEqualToAnchor:self.themeButtonsContainer.leadingAnchor],
        [themeButtonsStack.trailingAnchor constraintEqualToAnchor:self.themeButtonsContainer.trailingAnchor],
        [self.blueThemeButton.heightAnchor constraintEqualToConstant:36],
        [self.greenThemeButton.heightAnchor constraintEqualToConstant:36],
        [self.purpleThemeButton.heightAnchor constraintEqualToConstant:36],
        
        [self.resetThemeButton.topAnchor constraintEqualToAnchor:themeButtonsStack.bottomAnchor constant:[ThemeHelper spacingSM]],
        [self.resetThemeButton.leadingAnchor constraintEqualToAnchor:self.themeButtonsContainer.leadingAnchor],
        [self.resetThemeButton.trailingAnchor constraintEqualToAnchor:self.themeButtonsContainer.trailingAnchor],
        [self.resetThemeButton.heightAnchor constraintEqualToConstant:36],
        [self.resetThemeButton.bottomAnchor constraintEqualToAnchor:self.themeButtonsContainer.bottomAnchor]
    ]];
    
    // Set up the bottom constraint for the container - initially pinned to currentThemeLabel when buttons are hidden
    self.themeContainerBottomConstraint = [self.currentThemeLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]];
    [self.themeContainerBottomConstraint setActive:YES];
    
    return container;
}

- (UIView *)createCardsListContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper surfaceColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    container.layer.borderColor = [ThemeHelper borderColor].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.accessibilityIdentifier = @"cvv-recaching-cards-list-section";
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Saved Payment Methods";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"cvv-recaching-cards-list-title";
    titleLabel.accessibilityLabel = @"Saved Payment Methods";
    titleLabel.accessibilityHint = @"Section title for saved payment methods list";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    self.cardsStackView = [[UIStackView alloc] init];
    self.cardsStackView.axis = UILayoutConstraintAxisVertical;
    self.cardsStackView.spacing = [ThemeHelper spacingMD];
    self.cardsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cardsStackView];
    
    [self updateCardsList];
    
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

- (void)updateCardsList {
    // Remove all existing arranged subviews
    for (UIView *subview in self.cardsStackView.arrangedSubviews) {
        [self.cardsStackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }
    
    if (self.isLoadingCards) {
        UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [loadingIndicator startAnimating];
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        loadingIndicator.accessibilityIdentifier = @"cvv-recaching-loading-state";
        loadingIndicator.accessibilityLabel = @"Loading payment methods";
        loadingIndicator.accessibilityHint = @"Loading indicator while fetching payment methods";
        [self.cardsStackView addArrangedSubview:loadingIndicator];
        
        [NSLayoutConstraint activateConstraints:@[
            [loadingIndicator.centerXAnchor constraintEqualToAnchor:self.cardsStackView.centerXAnchor]
        ]];
    } else if (self.savedCards.count == 0) {
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = @"No saved payment methods";
        emptyLabel.font = [ThemeHelper screenSubheadlineFont];
        emptyLabel.textColor = [ThemeHelper textSecondaryColor];
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
        emptyLabel.accessibilityIdentifier = @"cvv-recaching-empty-state";
        emptyLabel.accessibilityLabel = @"No saved payment methods";
        emptyLabel.accessibilityHint = @"Message shown when no saved payment methods are available";
        emptyLabel.accessibilityHint = @"Message shown when no saved payment methods are available";
        [self.cardsStackView addArrangedSubview:emptyLabel];
    } else {
        // Show only top 3 cards
        NSInteger maxCards = MIN(3, self.savedCards.count);
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
    cardRow.backgroundColor = isSelected ? [[ThemeHelper primaryColor] colorWithAlphaComponent:0.1] : [UIColor systemGray6Color];
    cardRow.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    if (isSelected) {
        cardRow.layer.borderWidth = 2;
        cardRow.layer.borderColor = [ThemeHelper primaryColor].CGColor;
    } else {
        cardRow.layer.borderWidth = 0;
    }
    cardRow.translatesAutoresizingMaskIntoConstraints = NO;
    cardRow.accessibilityIdentifier = [NSString stringWithFormat:@"cvv-recaching-card-row_%@", card.cardId];
    cardRow.accessibilityLabel = [NSString stringWithFormat:@"%@, expires %@/%@", [card displayName], card.expiryMonth ?: @"", card.expiryYear ?: @""];
    cardRow.accessibilityHint = @"Tap to select this payment method";
    cardRow.accessibilityTraits = UIAccessibilityTraitButton | (isSelected ? UIAccessibilityTraitSelected : 0);
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cardRowTapped:)];
    [cardRow addGestureRecognizer:tapGesture];
    cardRow.userInteractionEnabled = YES;
    
    // HStack equivalent
    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.axis = UILayoutConstraintAxisHorizontal;
    hStack.spacing = 12; // Match SwiftUI spacing
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
    
    // Card Info Stack (VStack)
    UIStackView *infoStack = [[UIStackView alloc] init];
    infoStack.axis = UILayoutConstraintAxisVertical;
    infoStack.spacing = [ThemeHelper spacingXS];
    infoStack.alignment = UIStackViewAlignmentLeading;
    infoStack.translatesAutoresizingMaskIntoConstraints = NO;
    [hStack addArrangedSubview:infoStack];
    
    UILabel *cardNameLabel = [[UILabel alloc] init];
    cardNameLabel.text = [card displayName];
    cardNameLabel.font = [ThemeHelper screenHeadlineFont];
    cardNameLabel.textColor = [ThemeHelper textColor];
    [infoStack addArrangedSubview:cardNameLabel];
    
    if (card.expiryMonth && card.expiryYear) {
        UILabel *expiryLabel = [[UILabel alloc] init];
        expiryLabel.text = [NSString stringWithFormat:@"Expires: %@/%@", card.expiryMonth, card.expiryYear];
        expiryLabel.font = [ThemeHelper screenCaptionFont];
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
    
    // Accessibility
    NSString *accessibilityLabel = [NSString stringWithFormat:@"%@, expires %@/%@", [card displayName], card.expiryMonth ?: @"", card.expiryYear ?: @""];
    cardRow.accessibilityLabel = accessibilityLabel;
    cardRow.accessibilityHint = @"Tap to select this card for CVV recaching";
    cardRow.accessibilityTraits = UIAccessibilityTraitButton;
    if ([self.selectedCard.cardId isEqualToString:card.cardId]) {
        cardRow.accessibilityTraits |= UIAccessibilityTraitSelected;
    }
    
    return cardRow;
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
        
        // Title Label
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:[ThemeHelper spacingLG]],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Description Label
        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Information Container
        [self.informationContainer.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.informationContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.informationContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Configuration Container
        [self.configurationContainer.topAnchor constraintEqualToAnchor:self.informationContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.configurationContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.configurationContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Theme Configuration Container
        [self.themeConfigurationContainer.topAnchor constraintEqualToAnchor:self.configurationContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.themeConfigurationContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.themeConfigurationContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Cards List Container
        [self.cardsListContainer.topAnchor constraintEqualToAnchor:self.themeConfigurationContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.cardsListContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.cardsListContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Recache Button
        [self.recacheButton.topAnchor constraintEqualToAnchor:self.cardsListContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.recacheButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.recacheButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.recacheButton.heightAnchor constraintEqualToConstant:44],
        
        // Result Container
        [self.resultContainer.topAnchor constraintEqualToAnchor:self.recacheButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.resultContainer.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],
        
        // Error Label
        [self.errorLabel.topAnchor constraintEqualToAnchor:self.recacheButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.errorLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],
        
        // Loading Indicator
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

#pragma mark - Actions

- (void)cardRowTapped:(UITapGestureRecognizer *)gesture {
    UIView *cardRow = gesture.view;
    
    // Find which card was tapped
    for (NSInteger i = 0; i < self.cardsStackView.arrangedSubviews.count; i++) {
        UIView *row = self.cardsStackView.arrangedSubviews[i];
        if (row == cardRow) {
            if (i < self.savedCards.count) {
                SavedCard *card = self.savedCards[i];
                
                // Select the card (once selected, it cannot be unselected by tapping again)
                // Only update if the selection actually changed
                if (!self.selectedCard || ![self.selectedCard.cardId isEqualToString:card.cardId]) {
                    self.selectedCard = card;
                    
                    // Update button state based on selection
                    [self updateRecacheButtonState];
                    [self updateCardsList];
                }
                break;
            }
        }
    }
}

- (void)updateRecacheButtonState {
    // Enable button only when a card is selected
    BOOL shouldEnable = (self.selectedCard != nil && !self.isLoading);
    self.recacheButton.enabled = shouldEnable;
    self.recacheButton.userInteractionEnabled = shouldEnable;
    
    // Update visual appearance based on enabled state
    if (shouldEnable) {
        self.recacheButton.backgroundColor = [ThemeHelper primaryColor];
        self.recacheButton.alpha = 1.0;
    } else {
        self.recacheButton.backgroundColor = [[ThemeHelper primaryColor] colorWithAlphaComponent:0.6];
        self.recacheButton.alpha = 0.6;
    }
}

- (void)useCustomThemeToggled:(UISwitch *)sender {
    self.useCustomTheme = sender.isOn;
    
    // Show/hide the theme buttons container
    self.themeButtonsContainer.hidden = !self.useCustomTheme;
    
    // Update the bottom constraint based on whether theme buttons are shown
    [self.themeContainerBottomConstraint setActive:NO];
    
    if (self.useCustomTheme) {
        // When shown, pin container bottom to themeButtonsContainer bottom
        self.themeContainerBottomConstraint = [self.themeButtonsContainer.bottomAnchor constraintEqualToAnchor:self.themeConfigurationContainer.bottomAnchor constant:-12];
    } else {
        // When hidden, pin container bottom to currentThemeLabel bottom
        self.themeContainerBottomConstraint = [self.currentThemeLabel.bottomAnchor constraintEqualToAnchor:self.themeConfigurationContainer.bottomAnchor constant:-12];
    }
    
    [self.themeContainerBottomConstraint setActive:YES];
    
    // Animate the constraint change
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
    }];
    
    if (!self.useCustomTheme) {
        // Reset local theme configs
        self.lightThemeConfig = nil;
        self.darkThemeConfig = nil;
        self.selectedTheme = ThemeOptionDefault;
        
        // Reset global theme to default
        [self resetGlobalThemeToDefault];
        
        [self updateCurrentThemeDisplay];
        [self updateThemeButtonStates];
    }
}

- (NSString *)themeDisplayNameForOption:(ThemeOption)option {
    switch (option) {
        case ThemeOptionDefault:
            return @"Default";
        case ThemeOptionBlue:
            return @"Blue Theme";
        case ThemeOptionGreen:
            return @"Green Theme";
        case ThemeOptionPurple:
            return @"Purple Theme";
    }
}

- (UIColor *)themeColorForOption:(ThemeOption)option {
    switch (option) {
        case ThemeOptionDefault:
            return [UIColor systemGrayColor];
        case ThemeOptionBlue:
            return [UIColor systemBlueColor];
        case ThemeOptionGreen:
            return [UIColor systemGreenColor];
        case ThemeOptionPurple:
            return [UIColor systemPurpleColor];
    }
}

- (void)updateCurrentThemeDisplay {
    NSString *themeName = [self themeDisplayNameForOption:self.selectedTheme];
    UIColor *themeColor = [self themeColorForOption:self.selectedTheme];
    self.themeNameLabel.text = themeName;
    self.themeNameLabel.textColor = self.useCustomTheme ? themeColor : [UIColor systemGrayColor];
}

- (void)blueThemeButtonTapped {
    [self createBlueTheme];
    self.selectedTheme = ThemeOptionBlue;
    [self updateCurrentThemeDisplay];
    [self updateThemeButtonStates];
}

- (void)greenThemeButtonTapped {
    [self createGreenTheme];
    self.selectedTheme = ThemeOptionGreen;
    [self updateCurrentThemeDisplay];
    [self updateThemeButtonStates];
}

- (void)purpleThemeButtonTapped {
    [self createPurpleTheme];
    self.selectedTheme = ThemeOptionPurple;
    [self updateCurrentThemeDisplay];
    [self updateThemeButtonStates];
}

- (void)resetThemeButtonTapped {
    self.lightThemeConfig = nil;
    self.darkThemeConfig = nil;
    self.selectedTheme = ThemeOptionDefault;
    
    // Reset global theme to default
    [self resetGlobalThemeToDefault];
    
    [self updateCurrentThemeDisplay];
    [self updateThemeButtonStates];
}

- (void)resetGlobalThemeToDefault {
    // Create default light theme config matching SpreedlyLightTheme
    // Using UIColor initializer for more control
    UIColor *lightPrimary = [UIColor colorWithRed:0.0/255.0 green:119.0/255.0 blue:200.0/255.0 alpha:1.0]; // #0077C8
    UIColor *lightSecondary = [UIColor colorWithRed:175.0/255.0 green:175.0/255.0 blue:181.0/255.0 alpha:1.0]; // #AFB4B5
    UIColor *lightBorder = [UIColor colorWithRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0]; // #D9D9D9
    UIColor *lightBackground = [UIColor whiteColor]; // #FFFFFF
    UIColor *lightText = [UIColor blackColor]; // #000000
    UIColor *lightTextSecondary = [UIColor colorWithRed:108.0/255.0 green:117.0/255.0 blue:125.0/255.0 alpha:1.0]; // #6C757D
    UIColor *lightError = [UIColor colorWithRed:220.0/255.0 green:53.0/255.0 blue:69.0/255.0 alpha:1.0]; // #DC3545
    
    SPLThemeConfig *defaultLightConfig = [[SPLThemeConfig alloc] 
        initWithPrimaryColor:lightPrimary
        secondaryColor:lightSecondary
        backgroundColor:lightBackground
        surfaceColor:lightBackground
        borderColor:lightBorder
        borderFocusedColor:lightPrimary
        textColor:lightText
        textSecondaryColor:lightTextSecondary
        errorColor:lightError
        placeholderColor:lightSecondary
        borderRadius:8.0];
    
    // Create default dark theme config matching SpreedlyDarkTheme
    UIColor *darkPrimary = [UIColor colorWithRed:0.0/255.0 green:160.0/255.0 blue:255.0/255.0 alpha:1.0]; // #00A0FF
    UIColor *darkSecondary = [UIColor colorWithRed:108.0/255.0 green:117.0/255.0 blue:125.0/255.0 alpha:1.0]; // #6C757D
    UIColor *darkBorder = [UIColor colorWithRed:58.0/255.0 green:58.0/255.0 blue:60.0/255.0 alpha:1.0]; // #3A3A3C
    UIColor *darkBackground = [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:30.0/255.0 alpha:1.0]; // #1C1C1E
    UIColor *darkText = [UIColor whiteColor]; // #FFFFFF
    UIColor *darkTextSecondary = [UIColor colorWithRed:174.0/255.0 green:174.0/255.0 blue:178.0/255.0 alpha:1.0]; // #AEAEB2
    UIColor *darkError = [UIColor colorWithRed:255.0/255.0 green:59.0/255.0 blue:48.0/255.0 alpha:1.0]; // #FF3B30
    
    SPLThemeConfig *defaultDarkConfig = [[SPLThemeConfig alloc] 
        initWithPrimaryColor:darkPrimary
        secondaryColor:darkSecondary
        backgroundColor:darkBackground
        surfaceColor:darkBackground
        borderColor:darkBorder
        borderFocusedColor:darkPrimary
        textColor:darkText
        textSecondaryColor:darkTextSecondary
        errorColor:darkError
        placeholderColor:[UIColor colorWithRed:142.0/255.0 green:142.0/255.0 blue:147.0/255.0 alpha:1.0] // #8E8E93
        borderRadius:8.0];
    
    // Reset global theme to default
    [SpreedlyThemeManagerObjC setGlobalThemeWithLightConfig:defaultLightConfig darkConfig:defaultDarkConfig];
}

- (void)createBlueTheme {
    self.lightThemeConfig = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemBlueColor]
                                                         secondaryColor:[[UIColor systemBlueColor] colorWithAlphaComponent:0.7]
                                                        backgroundColor:[UIColor whiteColor]
                                                           surfaceColor:[UIColor whiteColor]
                                                             borderColor:[[UIColor systemBlueColor] colorWithAlphaComponent:0.3]
                                                      borderFocusedColor:[UIColor systemBlueColor]
                                                               textColor:[UIColor blackColor]
                                                      textSecondaryColor:[UIColor systemGrayColor]
                                                             errorColor:[UIColor systemRedColor]
                                                        placeholderColor:nil
                                                          borderRadius:8.0];
    
    // Dark theme: Use #1C1C1E for surface (matching SwiftUI) instead of pure black
    UIColor *darkSurfaceColor = [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:30.0/255.0 alpha:1.0]; // #1C1C1E
    self.darkThemeConfig = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemBlueColor]
                                                        secondaryColor:[[UIColor systemBlueColor] colorWithAlphaComponent:0.7]
                                                       backgroundColor:darkSurfaceColor
                                                          surfaceColor:darkSurfaceColor
                                                            borderColor:[[UIColor systemBlueColor] colorWithAlphaComponent:0.5]
                                                     borderFocusedColor:[UIColor systemBlueColor]
                                                              textColor:[UIColor whiteColor]
                                                     textSecondaryColor:[[UIColor systemGrayColor] colorWithAlphaComponent:0.8]
                                                            errorColor:[UIColor systemRedColor]
                                                       placeholderColor:nil
                                                         borderRadius:8.0];
    
    // Set global theme
    [SpreedlyThemeManagerObjC setGlobalThemeWithLightConfig:self.lightThemeConfig darkConfig:self.darkThemeConfig];
}

- (void)createGreenTheme {
    self.lightThemeConfig = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemGreenColor]
                                                         secondaryColor:[[UIColor systemGreenColor] colorWithAlphaComponent:0.7]
                                                        backgroundColor:[UIColor whiteColor]
                                                           surfaceColor:[UIColor whiteColor]
                                                             borderColor:[[UIColor systemGreenColor] colorWithAlphaComponent:0.3]
                                                      borderFocusedColor:[UIColor systemGreenColor]
                                                               textColor:[UIColor blackColor]
                                                      textSecondaryColor:[UIColor systemGrayColor]
                                                             errorColor:[UIColor systemRedColor]
                                                        placeholderColor:nil
                                                          borderRadius:8.0];
    
    // Dark theme: Use #1C1C1E for surface (matching SwiftUI) instead of pure black
    UIColor *darkSurfaceColor = [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:30.0/255.0 alpha:1.0]; // #1C1C1E
    self.darkThemeConfig = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemGreenColor]
                                                        secondaryColor:[[UIColor systemGreenColor] colorWithAlphaComponent:0.7]
                                                       backgroundColor:darkSurfaceColor
                                                          surfaceColor:darkSurfaceColor
                                                            borderColor:[[UIColor systemGreenColor] colorWithAlphaComponent:0.5]
                                                     borderFocusedColor:[UIColor systemGreenColor]
                                                              textColor:[UIColor whiteColor]
                                                     textSecondaryColor:[[UIColor systemGrayColor] colorWithAlphaComponent:0.8]
                                                            errorColor:[UIColor systemRedColor]
                                                       placeholderColor:nil
                                                         borderRadius:8.0];
    
    // Set global theme
    [SpreedlyThemeManagerObjC setGlobalThemeWithLightConfig:self.lightThemeConfig darkConfig:self.darkThemeConfig];
}

- (void)createPurpleTheme {
    self.lightThemeConfig = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemPurpleColor]
                                                         secondaryColor:[[UIColor systemPurpleColor] colorWithAlphaComponent:0.7]
                                                        backgroundColor:[UIColor whiteColor]
                                                           surfaceColor:[UIColor whiteColor]
                                                             borderColor:[[UIColor systemPurpleColor] colorWithAlphaComponent:0.3]
                                                      borderFocusedColor:[UIColor systemPurpleColor]
                                                               textColor:[UIColor blackColor]
                                                      textSecondaryColor:[UIColor systemGrayColor]
                                                             errorColor:[UIColor systemRedColor]
                                                        placeholderColor:nil
                                                          borderRadius:8.0];
    
    // Dark theme: Use #1C1C1E for surface (matching SwiftUI) instead of pure black
    UIColor *darkSurfaceColor = [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:30.0/255.0 alpha:1.0]; // #1C1C1E
    self.darkThemeConfig = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemPurpleColor]
                                                        secondaryColor:[[UIColor systemPurpleColor] colorWithAlphaComponent:0.7]
                                                       backgroundColor:darkSurfaceColor
                                                          surfaceColor:darkSurfaceColor
                                                            borderColor:[[UIColor systemPurpleColor] colorWithAlphaComponent:0.5]
                                                     borderFocusedColor:[UIColor systemPurpleColor]
                                                              textColor:[UIColor whiteColor]
                                                     textSecondaryColor:[[UIColor systemGrayColor] colorWithAlphaComponent:0.8]
                                                            errorColor:[UIColor systemRedColor]
                                                       placeholderColor:nil
                                                         borderRadius:8.0];
    
    // Set global theme
    [SpreedlyThemeManagerObjC setGlobalThemeWithLightConfig:self.lightThemeConfig darkConfig:self.darkThemeConfig];
}

- (void)updateThemeButtonStates {
    // Update button appearance based on selected theme - matching SwiftUI styling
    BOOL isBlueSelected = (self.selectedTheme == ThemeOptionBlue);
    self.blueThemeButton.backgroundColor = isBlueSelected ?
        [[UIColor systemBlueColor] colorWithAlphaComponent:0.2] : [[UIColor systemBlueColor] colorWithAlphaComponent:0.1];
    self.blueThemeButton.layer.borderWidth = isBlueSelected ? 2 : 1;
    self.blueThemeButton.layer.borderColor = isBlueSelected ? [UIColor systemBlueColor].CGColor : [[UIColor systemBlueColor] colorWithAlphaComponent:0.3].CGColor;
    
    BOOL isGreenSelected = (self.selectedTheme == ThemeOptionGreen);
    self.greenThemeButton.backgroundColor = isGreenSelected ?
        [[UIColor systemGreenColor] colorWithAlphaComponent:0.2] : [[UIColor systemGreenColor] colorWithAlphaComponent:0.1];
    self.greenThemeButton.layer.borderWidth = isGreenSelected ? 2 : 1;
    self.greenThemeButton.layer.borderColor = isGreenSelected ? [UIColor systemGreenColor].CGColor : [[UIColor systemGreenColor] colorWithAlphaComponent:0.3].CGColor;
    
    BOOL isPurpleSelected = (self.selectedTheme == ThemeOptionPurple);
    self.purpleThemeButton.backgroundColor = isPurpleSelected ?
        [[UIColor systemPurpleColor] colorWithAlphaComponent:0.2] : [[UIColor systemPurpleColor] colorWithAlphaComponent:0.1];
    self.purpleThemeButton.layer.borderWidth = isPurpleSelected ? 2 : 1;
    self.purpleThemeButton.layer.borderColor = isPurpleSelected ? [UIColor systemPurpleColor].CGColor : [[UIColor systemPurpleColor] colorWithAlphaComponent:0.3].CGColor;
}

- (void)recacheButtonTapped {
    // MARK: - Recache Button Action
    // Prepares configuration and presents SDK's CVV recaching UI
    
    if (!self.selectedCard) {
        return;
    }
    
    self.errorMessage = nil;
    self.isLoading = YES;
    [self updateUI];
    
    // Generate signature for Spreedly configuration before showing recaching UI
    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            [self updateUI];
            
            if (success) {
                // Get presentation mode: 0 = sheet, 1 = alert
                NSInteger presentationMode = self.presentationModeSegmentedControl.selectedSegmentIndex;
                
                // Get UI customization values with defaults
                NSString *labelText = self.labelTextField.text.length > 0 ? self.labelTextField.text : @"CVV";
                NSString *placeholderText = self.placeholderTextField.text.length > 0 ? self.placeholderTextField.text : @"123";
                NSString *buttonText = self.buttonTextField.text.length > 0 ? self.buttonTextField.text : @"Confirm";
                NSString *cancelButtonText = self.cancelButtonTextField.text.length > 0 ? self.cancelButtonTextField.text : @"Cancel";
                
                // Present CVV Recaching UI (SDK handles collection, validation, and API communication)
                [self presentCVVRecachingViewWithLastFourDigits:self.selectedCard.lastFourDigits
                                                        cardType:self.selectedCard.cardType
                                                       cardBrand:self.selectedCard.cardBrand
                                              paymentMethodToken:self.selectedCard.paymentMethodToken
                                                 presentationMode:presentationMode
                                                        labelText:labelText
                                                  placeholderText:placeholderText
                                                       buttonText:buttonText
                                                 cancelButtonText:cancelButtonText];
            } else {
                self.errorMessage = error ? error.localizedDescription : @"Failed to generate signature";
                [self updateUI];
            }
        });
    }];
}

- (void)presentCVVRecachingViewWithLastFourDigits:(NSString *)lastFourDigits
                                          cardType:(NSString *)cardType
                                         cardBrand:(NSString *)cardBrand
                                paymentMethodToken:(NSString *)paymentMethodToken
                                   presentationMode:(NSInteger)presentationMode
                                          labelText:(NSString *)labelText
                                    placeholderText:(NSString *)placeholderText
                                         buttonText:(NSString *)buttonText
                                   cancelButtonText:(NSString *)cancelButtonText {
    // MARK: - Present CVV Recaching UI
    // Use SDK's CVVRecachingViewController directly (imported via SpreedlyUI-Swift.h)
    // The SDK handles all CVV collection, validation, and API communication internally
    CVVRecachingViewController *recachingVC = nil;
    
    // MARK: - Initialize with Custom Theme (if configured)
    // If custom themes are configured, use the initializer that accepts theme configs
    // This allows the recaching UI to match your app's design
    if (self.useCustomTheme && self.lightThemeConfig && self.darkThemeConfig) {
        recachingVC = [[CVVRecachingViewController alloc]
                       initWithLastFourDigits:lastFourDigits
                       cardType:cardType
                       cardBrand:cardBrand
                       paymentMethodToken:paymentMethodToken
                       presentationMode:presentationMode
                       labelText:labelText
                       placeholderText:placeholderText
                       buttonText:buttonText
                       cancelButtonText:cancelButtonText
                       lightThemeConfig:self.lightThemeConfig
                       darkThemeConfig:self.darkThemeConfig
                       onProcessingResult:^(PaymentProcessingResult *result) {
                // MARK: - Processing Result Callback
                // Called during recaching: isValidationFailed = validation error, isProcessing = request started
                // Final success/failure comes via paymentDidComplete: delegate method
                __weak typeof(self) weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;
                    
                    if (result.isValidationFailed) {
                        strongSelf.errorMessage = @"CVV validation failed";
                        [strongSelf updateUI];
                    } else if (result.isProcessing) {
                        // Processing started - final result comes via delegate
                    } else if (result.isSuccess) {
                        // Dismiss UI - final result handled in paymentDidComplete:
                        [strongSelf dismissViewControllerAnimated:YES completion:nil];
                    }
                });
            }];
    } else {
        // MARK: - Initialize with Default Theme
        // Use default initializer (will use global theme or SDK default)
        recachingVC = [[CVVRecachingViewController alloc]
                       initWithLastFourDigits:lastFourDigits
                       cardType:cardType
                       cardBrand:cardBrand
                       paymentMethodToken:paymentMethodToken
                       presentationMode:presentationMode
                       labelText:labelText
                       placeholderText:placeholderText
                       buttonText:buttonText
                       cancelButtonText:cancelButtonText
                       onProcessingResult:^(PaymentProcessingResult *result) {
                // MARK: - Processing Result Callback
                // Called during recaching: isValidationFailed = validation error, isProcessing = request started
                // Final success/failure comes via paymentDidComplete: delegate method
                __weak typeof(self) weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;
                    
                    if (result.isValidationFailed) {
                        strongSelf.errorMessage = @"CVV validation failed";
                        [strongSelf updateUI];
                    } else if (result.isProcessing) {
                        // Processing started - final result comes via delegate
                    } else if (result.isSuccess) {
                        // Dismiss UI - final result handled in paymentDidComplete:
                        [strongSelf dismissViewControllerAnimated:YES completion:nil];
                    }
                });
            }];
    }
    
    // Apply validation options from merchant configuration
    recachingVC.allowBlankName = self.allowBlankNameSwitch.isOn;
    recachingVC.allowExpiredDate = self.allowExpiredDateSwitch.isOn;
    recachingVC.allowBlankDate = self.allowBlankDateSwitch.isOn;
    
    // MARK: - Validation and Presentation
    if (!recachingVC) {
        self.errorMessage = @"Failed to initialize CVV Recaching view controller";
        [self updateUI];
        return;
    }
    
    // Set presentation style based on mode
    if (presentationMode == 0) {
        // Sheet mode: form sheet presentation
        recachingVC.modalPresentationStyle = UIModalPresentationFormSheet;
    } else {
        // Alert mode: over full screen with cross-dissolve transition
        recachingVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
        recachingVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        recachingVC.view.backgroundColor = [UIColor clearColor]; // Transparent for dim background
    }
    
    [self presentViewController:recachingVC animated:YES completion:nil];
}


- (void)removeErrorContainer {
    static NSString *errorContainerKey = @"errorContainer";
    UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &errorContainerKey);
    
    if (errorContainer) {
        errorContainer.hidden = YES;
        [errorContainer removeFromSuperview];
        objc_setAssociatedObject(self.errorLabel, &errorContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // Also search for error container in contentView subviews as a fallback
    // (in case the associated object reference was lost)
    for (UIView *subview in self.contentView.subviews) {
        if ([subview.accessibilityIdentifier isEqualToString:@"cvv-recaching-error-message"]) {
            subview.hidden = YES;
            [subview removeFromSuperview];
            break;
        }
    }
}

- (void)updateUI {
    static NSString *errorContainerKey = @"errorContainer";
    UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &errorContainerKey);
    
    // THEN: Show the appropriate one based on state
    if (self.paymentResult && self.paymentResult.isSuccess) {
        // Success state: Ensure error is cleared and show success
        self.errorMessage = nil; // Clear error message
        
        // FIRST: Completely remove error container BEFORE showing success
        [self removeErrorContainer];
        self.errorLabel.hidden = YES;
        
        // Hide success container before setting up (to avoid flicker)
        self.resultContainer.hidden = YES;
        
        // Setup and show success container (this will also ensure error is removed)
        [self setupResultContainer];
        self.resultContainer.hidden = NO;
        
        // Scroll to show the success message
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToResultContainer];
        });
    } else if (self.errorMessage && self.errorMessage.length > 0) {
        // Error state: Ensure success is cleared and show error
        self.paymentResult = nil; // Clear payment result
        
        // FIRST: Hide success container BEFORE showing error
        self.resultContainer.hidden = YES;
        
        // Create error message view with proper styling
        [self setupErrorMessageView];
        self.errorLabel.hidden = YES; // Hide the old simple label
        
        // Get the error container after setup (it might have been recreated)
        errorContainer = objc_getAssociatedObject(self.errorLabel, &errorContainerKey);
        if (errorContainer) {
            errorContainer.hidden = NO;
        }
        
        // Scroll to show the error message
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToErrorContainer];
        });
    } else {
        // No state: Hide both
        self.resultContainer.hidden = YES;
        self.errorLabel.hidden = YES;
        [self removeErrorContainer];
    }
}

- (void)scrollToResultContainer {
    if (self.resultContainer && !self.resultContainer.hidden) {
        CGRect rect = [self.scrollView convertRect:self.resultContainer.bounds fromView:self.resultContainer];
        [self.scrollView scrollRectToVisible:rect animated:YES];
    }
}

- (void)scrollToErrorContainer {
    static NSString *errorContainerKey = @"errorContainer";
    UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &errorContainerKey);
    if (errorContainer && !errorContainer.hidden) {
        CGRect rect = [self.scrollView convertRect:errorContainer.bounds fromView:errorContainer];
        [self.scrollView scrollRectToVisible:rect animated:YES];
    }
}

- (void)setupResultContainer {
    // Remove existing subviews
    for (UIView *subview in self.resultContainer.subviews) {
        [subview removeFromSuperview];
    }
    
    // Completely remove error container when showing success
    static NSString *errorContainerKey = @"errorContainer";
    UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &errorContainerKey);
    if (errorContainer) {
        errorContainer.hidden = YES;
        [errorContainer removeFromSuperview];
        objc_setAssociatedObject(self.errorLabel, &errorContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    self.errorLabel.hidden = YES;
    
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
    
    // Success icon
    UIImageView *successIcon = [[UIImageView alloc] init];
    successIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    successIcon.tintColor = [ThemeHelper successColor];
    successIcon.translatesAutoresizingMaskIntoConstraints = NO;
    successIcon.accessibilityIdentifier = @"cvv-recaching-success-icon";
    successIcon.accessibilityLabel = @"Success";
    successIcon.accessibilityHint = @"Success indicator icon";
    successIcon.accessibilityTraits = UIAccessibilityTraitImage;
    [hStack addArrangedSubview:successIcon];
    
    // Success title
    UILabel *successLabel = [[UILabel alloc] init];
    successLabel.text = @"CVV Recached Successfully!";
    successLabel.font = [ThemeHelper subtitleFont];
    successLabel.textColor = [ThemeHelper successColor];
    successLabel.translatesAutoresizingMaskIntoConstraints = NO;
    successLabel.accessibilityIdentifier = @"cvv-recaching-success-title";
    successLabel.accessibilityLabel = @"CVV Recached Successfully!";
    successLabel.accessibilityHint = @"CVV recaching success message";
    successLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [hStack addArrangedSubview:successLabel];
    
    [vStack addArrangedSubview:hStack];
    
    // Message text
    UILabel *messageLabel = [[UILabel alloc] init];
    messageLabel.text = @"Your payment method has been updated.";
    messageLabel.font = [ThemeHelper bodyFont];
    messageLabel.textColor = [ThemeHelper textColor];
    messageLabel.numberOfLines = 0;
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vStack addArrangedSubview:messageLabel];
    
    // Updated token (if available)
    if (self.paymentResult.token) {
        UILabel *tokenLabel = [[UILabel alloc] init];
        NSString *masked = [Spreedly maskedToken:self.paymentResult.token];
        tokenLabel.text = [NSString stringWithFormat:@"Updated Token: %@", masked];
        tokenLabel.font = [ThemeHelper captionFont];
        tokenLabel.textColor = [ThemeHelper textSecondaryColor];
        tokenLabel.numberOfLines = 0;
        tokenLabel.translatesAutoresizingMaskIntoConstraints = NO;
        tokenLabel.accessibilityIdentifier = @"cvv-recaching-updated-token-text";
        tokenLabel.accessibilityLabel = [NSString stringWithFormat:@"Updated Token: %@", masked];
        tokenLabel.accessibilityHint = @"Updated payment method token after recaching";
        [vStack addArrangedSubview:tokenLabel];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [vStack.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:[ThemeHelper spacingMD]],
        [vStack.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
        [vStack.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [vStack.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
}

#pragma mark - SpreedlyPaymentDelegate

// MARK: - Payment Result Delegate Method
// Called when recaching completes with final PaymentResult (success or failure)
- (void)paymentDidComplete:(PaymentResult *)result {
    self.isLoading = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimating];
        
        if (result.isSuccess) {
            // MARK: - Recaching Success
            // Payment method token updated with new CVV - ready for transactions
            
            // Clear error state FIRST before setting success
            self.errorMessage = nil;
            
            // Explicitly hide and remove error container before setting payment result
            static NSString *errorContainerKey = @"errorContainer";
            UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &errorContainerKey);
            if (errorContainer) {
                errorContainer.hidden = YES;
                [errorContainer removeFromSuperview];
                objc_setAssociatedObject(self.errorLabel, &errorContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            self.errorLabel.hidden = YES;
            
            // Now set success result
            self.paymentResult = result;
            
            if (self.presentedViewController) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
        } else if (result.isFailure) {
            // MARK: - Recaching Failure
            // Handle error (common causes: invalid CVV, network error, expired token)
            
            // Clear success state FIRST before setting error
            self.paymentResult = nil;
            
            // Explicitly hide success container before setting error
            self.resultContainer.hidden = YES;
            
            // Now set error message
            if (result.failureDetails) {
                self.errorMessage = [result.failureDetails getDescription];
            } else {
                self.errorMessage = @"CVV Recaching failed";
            }
            
            if (self.presentedViewController) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
        }
        
        [self updateUI];
    });
}

- (void)setupErrorMessageView {
    // Create error container view if it doesn't exist
    static NSString *errorContainerKey = @"errorContainer";
    UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &errorContainerKey);
    
    if (!errorContainer || errorContainer.superview == nil) {
        // Remove old container if it exists but was removed from superview
        if (errorContainer && errorContainer.superview == nil) {
            objc_setAssociatedObject(self.errorLabel, &errorContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            errorContainer = nil;
        }
        
        // Create new error container
        errorContainer = [[UIView alloc] init];
        errorContainer.backgroundColor = [[ThemeHelper errorColor] colorWithAlphaComponent:0.1];
        errorContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
        errorContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [ThemeHelper applySmallShadowToView:errorContainer];
        errorContainer.accessibilityIdentifier = @"cvv-recaching-error-message";
        [self.contentView insertSubview:errorContainer belowSubview:self.errorLabel];
        objc_setAssociatedObject(self.errorLabel, &errorContainerKey, errorContainer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Update constraints for error container
        [NSLayoutConstraint activateConstraints:@[
            [errorContainer.topAnchor constraintEqualToAnchor:self.recacheButton.bottomAnchor constant:[ThemeHelper spacingLG]],
            [errorContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
            [errorContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
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
    errorIcon.accessibilityIdentifier = @"cvv-recaching-error-icon";
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
    errorTitle.accessibilityIdentifier = @"cvv-recaching-error-title";
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
    errorMessageLabel.accessibilityIdentifier = @"cvv-recaching-error-message-text";
    errorMessageLabel.accessibilityHint = @"Error message from CVV recaching process";
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
    
    // Ensure result container is hidden when showing error
    self.resultContainer.hidden = YES;
}

@end

