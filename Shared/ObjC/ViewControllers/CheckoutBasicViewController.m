//
//  CheckoutBasicViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  Created by Vinay Naikade on 12/08/25.
//

#import "CheckoutBasicViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <objc/runtime.h>
#import "SpreedlyConfigManager.h"
#import "RetainPaymentMethodAPIClient.h"
#import "RetainPaymentMethodModels.h"
#import "ThemeHelper.h"

// MARK: - Theme Option Enum Helper
typedef NS_ENUM(NSInteger, ThemeOption) {
    ThemeOptionDefault = 0,
    ThemeOptionBlue = 1,
    ThemeOptionGreen = 2,
    ThemeOptionPurple = 3
};

@interface CheckoutBasicViewController () <UIScrollViewDelegate, SpreedlyPaymentDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIView *fieldsContainer;
@property (nonatomic, strong) UIStackView *fieldsStackView;
@property (nonatomic, strong) UIView *configContainer;
@property (nonatomic, strong) UIView *themeConfigurationContainer;
@property (nonatomic, strong) UIButton *showFormButton;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@property (nonatomic, strong) UISwitch *allowBlankNameSwitch;
@property (nonatomic, strong) UISwitch *allowExpiredDateSwitch;
@property (nonatomic, strong) UISwitch *allowBlankDateSwitch;
@property (nonatomic, strong) UISegmentedControl *yearFormatSegmentedControl;
@property (nonatomic, strong) UISegmentedControl *nameDisplayModeSegmentedControl;

// Theme configuration UI
@property (nonatomic, strong) UISwitch *useCustomThemeSwitch;
@property (nonatomic, strong) UILabel *currentThemeLabel;
@property (nonatomic, strong) UILabel *themeNameLabel;
@property (nonatomic, strong) UIView *themeButtonsContainer;
@property (nonatomic, strong) UIButton *blueThemeButton;
@property (nonatomic, strong) UIButton *greenThemeButton;
@property (nonatomic, strong) UIButton *purpleThemeButton;
@property (nonatomic, strong) UIButton *resetThemeButton;
@property (nonatomic, strong) NSLayoutConstraint *themeContainerBottomConstraint;

// Theme state
@property (nonatomic, assign) ThemeOption selectedTheme;
@property (nonatomic, strong) SPLThemeConfig *lightThemeConfig;
@property (nonatomic, strong) SPLThemeConfig *darkThemeConfig;
@property (nonatomic, assign) BOOL useCustomTheme;

@property (nonatomic, strong) PaymentResult *paymentResult;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, assign) BOOL isLoading;

@end

@implementation CheckoutBasicViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Basic Checkout Component";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // Theme state defaults
    self.selectedTheme = ThemeOptionDefault;
    self.useCustomTheme = NO;
    
    [self setupUI];
    [self setupConstraints];

    // Initialize theme display and button states
    [self updateCurrentThemeDisplay];
    [self updateThemeButtonStates];
    
    // Set scroll view delegate
    self.scrollView.delegate = self;
    
    // Set up payment result delegate
    [Spreedly.shared setPaymentDelegate:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Update dynamic colors when trait collection changes (e.g., dark/light mode switch)
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        // Update all container views with dynamic colors
        [self updateDynamicColors];
    }
}

- (void)updateDynamicColors {
    // Update border colors for containers (CGColor needs to be resolved for current trait collection)
    if (self.fieldsContainer) {
        self.fieldsContainer.backgroundColor = [ThemeHelper cardBackgroundColor];
        UIColor *borderColor = [ThemeHelper cardBorderColor];
        UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
        self.fieldsContainer.layer.borderColor = resolvedBorderColor.CGColor;
        [ThemeHelper updateShadowForView:self.fieldsContainer];
    }
    if (self.configContainer) {
        self.configContainer.backgroundColor = [ThemeHelper cardBackgroundColor];
        UIColor *borderColor = [ThemeHelper cardBorderColor];
        UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
        self.configContainer.layer.borderColor = resolvedBorderColor.CGColor;
        [ThemeHelper updateShadowForView:self.configContainer];
    }
    if (self.themeConfigurationContainer) {
        self.themeConfigurationContainer.backgroundColor = [ThemeHelper cardBackgroundColor];
        UIColor *borderColor = [ThemeHelper cardBorderColor];
        UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
        self.themeConfigurationContainer.layer.borderColor = resolvedBorderColor.CGColor;
        [ThemeHelper updateShadowForView:self.themeConfigurationContainer];
    }
    
    // Update text colors
    if (self.titleLabel) {
        self.titleLabel.textColor = [ThemeHelper textColor];
    }
    if (self.descriptionLabel) {
        self.descriptionLabel.textColor = [ThemeHelper textColor];
    }
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
    self.titleLabel.text = @"Basic Checkout Component";
    self.titleLabel.font = [ThemeHelper screenTitleFont];
    self.titleLabel.textColor = [ThemeHelper textColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.accessibilityIdentifier = @"basicCheckoutTitle";
    self.titleLabel.accessibilityLabel = @"Basic Checkout Component";
    self.titleLabel.accessibilityHint = @"Basic checkout component demonstration";
    self.titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.contentView addSubview:self.titleLabel];
    
    // Description Label
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = @"This demonstrates the CardFormDropIn component with configurable name display modes and default fields.";
    self.descriptionLabel.font = [ThemeHelper screenBodyFont];
    self.descriptionLabel.textColor = [ThemeHelper textColor];
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionLabel.accessibilityIdentifier = @"basicCheckoutDescription";
    self.descriptionLabel.accessibilityHint = @"Description of the basic checkout component";
    [self.contentView addSubview:self.descriptionLabel];
    
    // Fields Container
    self.fieldsContainer = [self createFieldsContainer];
    
    // Config Container
    self.configContainer = [self createConfigContainer];

    // Theme Configuration Container
    self.themeConfigurationContainer = [self createThemeConfigurationContainer];
    
    // Show Form Button
    self.showFormButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.showFormButton setTitle:@"Show Basic Checkout Form" forState:UIControlStateNormal];
    self.showFormButton.titleLabel.font = [ThemeHelper buttonFont];
    self.showFormButton.backgroundColor = [ThemeHelper primaryColor];
    [self.showFormButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.showFormButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.showFormButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.showFormButton.accessibilityIdentifier = @"basicCheckoutShowFormButton";
    self.showFormButton.accessibilityLabel = @"Show Basic Checkout Form";
    self.showFormButton.accessibilityHint = @"Button to show the basic checkout form";
    [self.showFormButton addTarget:self action:@selector(showFormButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.showFormButton];
    
    // Result Container
    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    self.resultContainer.hidden = YES;
    self.resultContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:self.resultContainer];
    [self.contentView addSubview:self.resultContainer];
    
    // Error Label (will be replaced with error container in updateUI)
    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.textColor = [ThemeHelper errorColor];
    self.errorLabel.font = [ThemeHelper bodyFont];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.accessibilityIdentifier = @"basicCheckoutErrorMessage";
    [self.contentView addSubview:self.errorLabel];
    
    // Loading Indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
}

- (UIView *)createInfoContainerWithTitle:(NSString *)title items:(NSArray<NSString *> *)items backgroundColor:(UIColor *)backgroundColor {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    // Resolve border color for current trait collection
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    container.layer.borderColor = resolvedBorderColor.CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"basicCheckoutDefaultFieldsTitle";
    titleLabel.accessibilityLabel = title;
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = [ThemeHelper spacingXS];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stackView];
    
    for (NSString *item in items) {
        UILabel *itemLabel = [[UILabel alloc] init];
        itemLabel.text = item;
        itemLabel.font = [ThemeHelper screenBodyFont];
        itemLabel.textColor = [ThemeHelper textColor];
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

- (UIView *)createThemeConfigurationContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    container.layer.borderColor = resolvedBorderColor.CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.accessibilityIdentifier = @"basicCheckoutThemeConfigurationSection";
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Theme Configuration:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"basicCheckoutThemeTitle";
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
    self.useCustomThemeSwitch.accessibilityIdentifier = @"basicCheckoutCustomThemeToggle";
    self.useCustomThemeSwitch.accessibilityHint = @"Toggle to enable or disable custom theme";
    [self.useCustomThemeSwitch addTarget:self action:@selector(useCustomThemeToggled:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.useCustomThemeSwitch];
    
    self.currentThemeLabel = [[UILabel alloc] init];
    self.currentThemeLabel.text = @"Current Theme:";
    self.currentThemeLabel.font = [ThemeHelper screenSubheadlineFont];
    self.currentThemeLabel.textColor = [ThemeHelper textColor];
    self.currentThemeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.currentThemeLabel.accessibilityIdentifier = @"basicCheckoutCurrentThemeLabel";
    [container addSubview:self.currentThemeLabel];
    
    self.themeNameLabel = [[UILabel alloc] init];
    self.themeNameLabel.text = @"Default";
    self.themeNameLabel.font = [ThemeHelper screenSubheadlineFont];
    self.themeNameLabel.textColor = [ThemeHelper textSecondaryColor];
    self.themeNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.themeNameLabel.accessibilityIdentifier = @"basicCheckoutCurrentTheme";
    [container addSubview:self.themeNameLabel];
    
    self.themeButtonsContainer = [[UIView alloc] init];
    self.themeButtonsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.themeButtonsContainer.hidden = !self.useCustomTheme;
    [container addSubview:self.themeButtonsContainer];
    
    UILabel *customThemeColorsLabel = [[UILabel alloc] init];
    customThemeColorsLabel.text = @"Custom Theme Colors:";
    customThemeColorsLabel.font = [ThemeHelper screenSubheadlineFont];
    customThemeColorsLabel.textColor = [ThemeHelper textColor];
    customThemeColorsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    customThemeColorsLabel.accessibilityIdentifier = @"basicCheckoutCustomThemeColorsLabel";
    [self.themeButtonsContainer addSubview:customThemeColorsLabel];
    
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
    self.blueThemeButton.accessibilityIdentifier = @"basicCheckoutBlueThemeButton";
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
    self.greenThemeButton.accessibilityIdentifier = @"basicCheckoutGreenThemeButton";
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
    self.purpleThemeButton.accessibilityIdentifier = @"basicCheckoutPurpleThemeButton";
    [self.purpleThemeButton addTarget:self action:@selector(purpleThemeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [themeButtonsStack addArrangedSubview:self.purpleThemeButton];
    
    self.resetThemeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resetThemeButton setTitle:@"Reset to Default" forState:UIControlStateNormal];
    self.resetThemeButton.backgroundColor = [ThemeHelper primaryColor];
    [self.resetThemeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.resetThemeButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.resetThemeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetThemeButton.accessibilityIdentifier = @"basicCheckoutResetThemeButton";
    [self.resetThemeButton addTarget:self action:@selector(resetThemeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.themeButtonsContainer addSubview:self.resetThemeButton];
    
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
    
    self.themeContainerBottomConstraint = [self.currentThemeLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]];
    [self.themeContainerBottomConstraint setActive:YES];
    
    return container;
}

- (UIView *)createFieldsContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    container.layer.borderColor = resolvedBorderColor.CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Default Fields:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"basicCheckoutDefaultFieldsTitle";
    titleLabel.accessibilityLabel = @"Default Fields";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    self.fieldsStackView = [[UIStackView alloc] init];
    self.fieldsStackView.axis = UILayoutConstraintAxisVertical;
    self.fieldsStackView.spacing = [ThemeHelper spacingXS];
    self.fieldsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.fieldsStackView];
    
    [self updateFieldItemsForNameDisplayMode];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [self.fieldsStackView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [self.fieldsStackView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.fieldsStackView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.fieldsStackView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    return container;
}

- (void)updateFieldItemsForNameDisplayMode {
    if (!self.fieldsStackView) {
        return;
    }
    
    for (UIView *subview in self.fieldsStackView.arrangedSubviews) {
        [self.fieldsStackView removeArrangedSubview:subview];
        [subview removeFromSuperview];
    }
    
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    NSInteger selectedIndex = self.nameDisplayModeSegmentedControl ? self.nameDisplayModeSegmentedControl.selectedSegmentIndex : 0;
    if (selectedIndex == 1) {
        [items addObject:@"• Full Name"];
    } else {
        [items addObject:@"• First Name"];
        [items addObject:@"• Last Name"];
    }
    [items addObject:@"• Card Number"];
    [items addObject:@"• Expiry Month"];
    [items addObject:@"• Expiry Year"];
    [items addObject:@"• CVC"];
    
    for (NSString *item in items) {
        UILabel *itemLabel = [[UILabel alloc] init];
        itemLabel.text = item;
        itemLabel.font = [ThemeHelper screenBodyFont];
        itemLabel.textColor = [ThemeHelper textColor];
        [self.fieldsStackView addArrangedSubview:itemLabel];
    }
}

- (UIView *)createConfigContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    // Resolve border color for current trait collection
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    container.layer.borderColor = resolvedBorderColor.CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Configuration Options:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"basicCheckoutConfigurationTitle";
    titleLabel.accessibilityLabel = @"Configuration Options";
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];
    
    // Allow Blank Name Switch
    UILabel *blankNameLabel = [[UILabel alloc] init];
    blankNameLabel.text = @"Allow Blank Name";
    blankNameLabel.font = [ThemeHelper screenBodyFont];
    blankNameLabel.textColor = [ThemeHelper textColor];
    blankNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    blankNameLabel.accessibilityIdentifier = @"basicCheckoutAllowBlankNameLabel";
    [container addSubview:blankNameLabel];
    
    self.allowBlankNameSwitch = [[UISwitch alloc] init];
    self.allowBlankNameSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowBlankNameSwitch.accessibilityIdentifier = @"basicCheckoutAllowBlankNameToggle";
    [self.allowBlankNameSwitch setOn:[[Spreedly shared].paramsManager getParamWithParameter:ValidationParamAllowBlankName]];
    [self.allowBlankNameSwitch addTarget:self action:@selector(allowBlankNameToggled:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.allowBlankNameSwitch];
    
    // Allow Expired Date Switch
    UILabel *expiredDateLabel = [[UILabel alloc] init];
    expiredDateLabel.text = @"Allow Expired Date";
    expiredDateLabel.font = [ThemeHelper screenBodyFont];
    expiredDateLabel.textColor = [ThemeHelper textColor];
    expiredDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    expiredDateLabel.accessibilityIdentifier = @"basicCheckoutAllowExpiredDateLabel";
    [container addSubview:expiredDateLabel];
    
    self.allowExpiredDateSwitch = [[UISwitch alloc] init];
    self.allowExpiredDateSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowExpiredDateSwitch.accessibilityIdentifier = @"basicCheckoutAllowExpiredDateToggle";
    self.allowExpiredDateSwitch.accessibilityLabel = @"Allow Expired Date";
    self.allowExpiredDateSwitch.accessibilityHint = @"Toggle to allow or disallow expired dates";
    [self.allowExpiredDateSwitch setOn:[[Spreedly shared].paramsManager getParamWithParameter:ValidationParamAllowExpiredDate]];
    [self.allowExpiredDateSwitch addTarget:self action:@selector(allowExpiredDateToggled:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.allowExpiredDateSwitch];
    
    // Allow Blank Date Switch
    UILabel *blankDateLabel = [[UILabel alloc] init];
    blankDateLabel.text = @"Allow Blank Date";
    blankDateLabel.font = [ThemeHelper screenBodyFont];
    blankDateLabel.textColor = [ThemeHelper textColor];
    blankDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    blankDateLabel.accessibilityIdentifier = @"basicCheckoutAllowBlankDateLabel";
    [container addSubview:blankDateLabel];
    
    self.allowBlankDateSwitch = [[UISwitch alloc] init];
    self.allowBlankDateSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowBlankDateSwitch.accessibilityIdentifier = @"basicCheckoutAllowBlankDateToggle";
    self.allowBlankDateSwitch.accessibilityLabel = @"Allow Blank Date";
    self.allowBlankDateSwitch.accessibilityHint = @"Toggle to allow or require expiration date";
    [self.allowBlankDateSwitch setOn:[[Spreedly shared].paramsManager getParamWithParameter:ValidationParamAllowBlankDate]];
    [self.allowBlankDateSwitch addTarget:self action:@selector(allowBlankDateToggled:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.allowBlankDateSwitch];
    
    // Year Format Segmented Control
    UILabel *yearFormatLabel = [[UILabel alloc] init];
    yearFormatLabel.text = @"Year Format:";
    yearFormatLabel.font = [ThemeHelper screenBodyFont];
    yearFormatLabel.textColor = [ThemeHelper textColor];
    yearFormatLabel.translatesAutoresizingMaskIntoConstraints = NO;
    yearFormatLabel.accessibilityIdentifier = @"basicCheckoutYearFormatLabel";
    [container addSubview:yearFormatLabel];
    
    self.yearFormatSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"YY", @"YYYY"]];
    self.yearFormatSegmentedControl.selectedSegmentIndex = 1; // Default to 4-digit
    self.yearFormatSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.yearFormatSegmentedControl.accessibilityIdentifier = @"basicCheckoutYearFormatSegmentedControl";
    [container addSubview:self.yearFormatSegmentedControl];
    
    // Name Display Mode Segmented Control
    UILabel *nameDisplayModeLabel = [[UILabel alloc] init];
    nameDisplayModeLabel.text = @"Name Display Mode:";
    nameDisplayModeLabel.font = [ThemeHelper screenBodyFont];
    nameDisplayModeLabel.textColor = [ThemeHelper textColor];
    nameDisplayModeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameDisplayModeLabel.accessibilityIdentifier = @"basicCheckoutNameDisplayModeLabel";
    [container addSubview:nameDisplayModeLabel];
    
    self.nameDisplayModeSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Separate Fields", @"Single Field"]];
    self.nameDisplayModeSegmentedControl.selectedSegmentIndex = 0;
    self.nameDisplayModeSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameDisplayModeSegmentedControl.accessibilityIdentifier = @"basicCheckoutNameDisplayModePicker";
    [self.nameDisplayModeSegmentedControl addTarget:self action:@selector(nameDisplayModeChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.nameDisplayModeSegmentedControl];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [blankNameLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [blankNameLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [blankNameLabel.centerYAnchor constraintEqualToAnchor:self.allowBlankNameSwitch.centerYAnchor],
        
        [self.allowBlankNameSwitch.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowBlankNameSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [expiredDateLabel.topAnchor constraintEqualToAnchor:blankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [expiredDateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [expiredDateLabel.centerYAnchor constraintEqualToAnchor:self.allowExpiredDateSwitch.centerYAnchor],
        
        [self.allowExpiredDateSwitch.topAnchor constraintEqualToAnchor:blankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowExpiredDateSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [blankDateLabel.topAnchor constraintEqualToAnchor:expiredDateLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [blankDateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [blankDateLabel.centerYAnchor constraintEqualToAnchor:self.allowBlankDateSwitch.centerYAnchor],
        
        [self.allowBlankDateSwitch.topAnchor constraintEqualToAnchor:expiredDateLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowBlankDateSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [yearFormatLabel.topAnchor constraintEqualToAnchor:self.allowBlankDateSwitch.bottomAnchor constant:[ThemeHelper spacingMD]],
        [yearFormatLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [yearFormatLabel.centerYAnchor constraintEqualToAnchor:self.yearFormatSegmentedControl.centerYAnchor],
        
        [self.yearFormatSegmentedControl.topAnchor constraintEqualToAnchor:self.allowBlankDateSwitch.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.yearFormatSegmentedControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [nameDisplayModeLabel.topAnchor constraintEqualToAnchor:self.yearFormatSegmentedControl.bottomAnchor constant:[ThemeHelper spacingMD]],
        [nameDisplayModeLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [nameDisplayModeLabel.centerYAnchor constraintEqualToAnchor:self.nameDisplayModeSegmentedControl.centerYAnchor],
        
        [self.nameDisplayModeSegmentedControl.topAnchor constraintEqualToAnchor:self.yearFormatSegmentedControl.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.nameDisplayModeSegmentedControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.nameDisplayModeSegmentedControl.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
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
        
        // Title Label
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:[ThemeHelper spacingLG]],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Description Label
        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Fields Container
        [self.fieldsContainer.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.fieldsContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.fieldsContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Config Container
        [self.configContainer.topAnchor constraintEqualToAnchor:self.fieldsContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.configContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.configContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Theme Configuration Container
        [self.themeConfigurationContainer.topAnchor constraintEqualToAnchor:self.configContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.themeConfigurationContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.themeConfigurationContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Show Form Button
        [self.showFormButton.topAnchor constraintEqualToAnchor:self.themeConfigurationContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.showFormButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.showFormButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.showFormButton.heightAnchor constraintEqualToConstant:44],
        
        // Result Container
        [self.resultContainer.topAnchor constraintEqualToAnchor:self.showFormButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        // Error Label
        [self.errorLabel.topAnchor constraintEqualToAnchor:self.showFormButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.errorLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],
        
        // Loading Indicator
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)allowBlankNameToggled:(UISwitch *)sender {
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankName value:sender.isOn];
}

- (void)allowExpiredDateToggled:(UISwitch *)sender {
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowExpiredDate value:sender.isOn];
}

- (void)allowBlankDateToggled:(UISwitch *)sender {
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankDate value:sender.isOn];
}

- (void)nameDisplayModeChanged:(UISegmentedControl *)sender {
    [self updateFieldItemsForNameDisplayMode];
}

- (void)useCustomThemeToggled:(UISwitch *)sender {
    self.useCustomTheme = sender.isOn;
    self.themeButtonsContainer.hidden = !self.useCustomTheme;
    
    [self.themeContainerBottomConstraint setActive:NO];
    if (self.useCustomTheme) {
        self.themeContainerBottomConstraint = [self.themeButtonsContainer.bottomAnchor constraintEqualToAnchor:self.themeConfigurationContainer.bottomAnchor constant:-[ThemeHelper spacingMD]];
    } else {
        self.themeContainerBottomConstraint = [self.currentThemeLabel.bottomAnchor constraintEqualToAnchor:self.themeConfigurationContainer.bottomAnchor constant:-[ThemeHelper spacingMD]];
    }
    [self.themeContainerBottomConstraint setActive:YES];
    
    [UIView animateWithDuration:0.3 animations:^{
        [self.view layoutIfNeeded];
    }];
    
    if (!self.useCustomTheme) {
        self.lightThemeConfig = nil;
        self.darkThemeConfig = nil;
        self.selectedTheme = ThemeOptionDefault;
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
    [self updateCurrentThemeDisplay];
    [self updateThemeButtonStates];
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
}

- (void)updateThemeButtonStates {
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

- (void)showFormButtonTapped {
    self.isLoading = YES;
    [self.loadingIndicator startAnimating];
    self.showFormButton.enabled = NO;
    
    // Generate signature for Spreedly configuration
    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            [self.loadingIndicator stopAnimating];
            self.showFormButton.enabled = YES;
            
            if (success) {
                [self showCardFormDropIn];
            } else {
                self.errorMessage = error.localizedDescription;
                [self updateUI];
            }
        });
    }];
}

- (void)showCardFormDropIn {
    // Determine year format based on segmented control
    YearFormat yearFormat = (self.yearFormatSegmentedControl.selectedSegmentIndex == 0) ?
        YearFormatTwoDigit : YearFormatFourDigit;
    
    // Determine name display mode
    DropInNameDisplayMode nameDisplayMode = (self.nameDisplayModeSegmentedControl.selectedSegmentIndex == 1) ?
        DropInNameDisplayModeSingleField : DropInNameDisplayModeSeparateFields;
    
    CardFormDropInViewController *dropInVC = nil;
    if (self.useCustomTheme && self.lightThemeConfig && self.darkThemeConfig) {
        dropInVC = [[CardFormDropInViewController alloc]
                    initWithOtherFields:@[]
                    yearFormat:yearFormat
                    nameDisplayMode:nameDisplayMode
                    lightThemeConfig:self.lightThemeConfig
                    darkThemeConfig:self.darkThemeConfig
                    onProcessingResult:^(PaymentProcessingResult *processingResult) {
            if (processingResult.isProcessing) {
                self.isLoading = YES;
                [self.loadingIndicator startAnimating];
                self.showFormButton.enabled = NO;
            } else if (processingResult.isValidationFailed) {
                // Handle validation failure
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                self.showFormButton.enabled = YES;
                self.errorMessage = [NSString stringWithFormat:@"Validation failed: %@", [processingResult getDescription]];
                [self updateUI];
            }
        }];
    } else {
        dropInVC = [[CardFormDropInViewController alloc]
                    initWithOtherFields:@[]
                    yearFormat:yearFormat
                    nameDisplayMode:nameDisplayMode
                    onProcessingResult:^(PaymentProcessingResult *processingResult) {
            if (processingResult.isProcessing) {
                self.isLoading = YES;
                [self.loadingIndicator startAnimating];
                self.showFormButton.enabled = NO;
            } else if (processingResult.isValidationFailed) {
                // Handle validation failure
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                self.showFormButton.enabled = YES;
                self.errorMessage = [NSString stringWithFormat:@"Validation failed: %@", [processingResult getDescription]];
                [self updateUI];
            }
        }];
    }
    
    // Wrap DropIn in secure protection for screen prevention
    UIViewController *secureDropInVC = [dropInVC wrapInSecureViewControllerWithPlaceholderText:@""];
    
    [self presentViewController:secureDropInVC animated:YES completion:nil];
}

- (void)updateUI {
    static NSString *errorContainerKey = @"errorContainer";
    UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &errorContainerKey);
    
    // Update result container
    if (self.paymentResult && self.paymentResult.isSuccess) {
        [self setupResultContainer];
        self.resultContainer.hidden = NO;
        self.errorLabel.hidden = YES;
        if (errorContainer) {
            errorContainer.hidden = YES;
        }
        
        // Ensure the result container is fully visible
        [self ensureResultContainerVisible];
    } else if (self.errorMessage) {
        // Create error message view with proper styling
        [self setupErrorMessageView];
        self.errorLabel.hidden = YES; // Hide the old simple label
        self.resultContainer.hidden = YES;
    } else {
        self.resultContainer.hidden = YES;
        self.errorLabel.hidden = YES;
        if (errorContainer) {
            errorContainer.hidden = YES;
        }
    }
}

- (void)ensureResultContainerVisible {
    // Force immediate layout update
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self.contentView setNeedsLayout];
    [self.contentView layoutIfNeeded];
    [self.scrollView setNeedsLayout];
    [self.scrollView layoutIfNeeded];
    
    // Wait for layout to complete, then scroll to show the full result container
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Calculate the position of the result container
        CGRect resultContainerFrame = [self.resultContainer convertRect:self.resultContainer.bounds toView:self.scrollView];
        CGFloat resultContainerBottom = resultContainerFrame.origin.y + resultContainerFrame.size.height;
        
        // Calculate the scroll view's visible area
        CGFloat scrollViewHeight = self.scrollView.bounds.size.height;
        CGFloat currentOffset = self.scrollView.contentOffset.y;
        CGFloat visibleBottom = currentOffset + scrollViewHeight;
        
        // If the result container is not fully visible, scroll to show it
        if (resultContainerBottom > visibleBottom) {
            CGFloat newOffset = resultContainerBottom - scrollViewHeight + 20; // Add 20pt buffer
            newOffset = MAX(0, newOffset); // Ensure we don't scroll past the top
            
            [self.scrollView setContentOffset:CGPointMake(0, newOffset) animated:YES];
        }
    });
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
    
    // Success icon
    UIImageView *successIcon = [[UIImageView alloc] init];
    successIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    successIcon.tintColor = [ThemeHelper successColor];
    successIcon.translatesAutoresizingMaskIntoConstraints = NO;
    successIcon.accessibilityIdentifier = @"basicCheckoutSuccessIcon";
    successIcon.accessibilityLabel = @"Success";
    successIcon.accessibilityHint = @"Success indicator icon";
    successIcon.accessibilityTraits = UIAccessibilityTraitImage;
    [hStack addArrangedSubview:successIcon];
    
    // Success title
    UILabel *successLabel = [[UILabel alloc] init];
    successLabel.text = @"Payment Successful!";
    successLabel.font = [ThemeHelper subtitleFont];
    successLabel.textColor = [ThemeHelper successColor];
    successLabel.translatesAutoresizingMaskIntoConstraints = NO;
    successLabel.accessibilityIdentifier = @"basicCheckoutSuccessTitle";
    successLabel.accessibilityLabel = @"Payment Successful!";
    successLabel.accessibilityHint = @"Payment success message";
    successLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [hStack addArrangedSubview:successLabel];
    
    [vStack addArrangedSubview:hStack];
    
    // Message text
    UILabel *messageLabel = [[UILabel alloc] init];
    messageLabel.text = @"Your payment has been processed successfully.";
    messageLabel.font = [ThemeHelper bodyFont];
    messageLabel.textColor = [ThemeHelper textColor];
    messageLabel.numberOfLines = 0;
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [vStack addArrangedSubview:messageLabel];
    
    // Transaction token (if available)
    if (self.paymentResult.token) {
        UILabel *transactionLabel = [[UILabel alloc] init];
        NSString *masked = [Spreedly maskedToken:self.paymentResult.token];
        transactionLabel.text = [NSString stringWithFormat:@"Transaction Token: %@", masked];
        transactionLabel.font = [ThemeHelper captionFont];
        transactionLabel.textColor = [ThemeHelper textSecondaryColor];
        transactionLabel.numberOfLines = 0;
        transactionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        transactionLabel.accessibilityIdentifier = @"basicCheckoutTransactionToken";
        transactionLabel.accessibilityLabel = [NSString stringWithFormat:@"Transaction Token: %@", masked];
        transactionLabel.accessibilityHint = @"Transaction token for the successful payment";
        [vStack addArrangedSubview:transactionLabel];
    }
    
    [NSLayoutConstraint activateConstraints:@[
        [vStack.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:[ThemeHelper spacingMD]],
        [vStack.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
        [vStack.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [vStack.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
}

- (void)setupErrorMessageView {
    // Create error container view if it doesn't exist
    static NSString *errorContainerKey = @"errorContainer";
    UIView *errorContainer = objc_getAssociatedObject(self.errorLabel, &errorContainerKey);
    
    if (!errorContainer) {
        errorContainer = [[UIView alloc] init];
        errorContainer.backgroundColor = [[ThemeHelper errorColor] colorWithAlphaComponent:0.1];
        errorContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
        errorContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [ThemeHelper applySmallShadowToView:errorContainer];
        errorContainer.accessibilityIdentifier = @"basicCheckoutErrorMessage";
        [self.contentView insertSubview:errorContainer belowSubview:self.errorLabel];
        objc_setAssociatedObject(self.errorLabel, &errorContainerKey, errorContainer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Update constraints for error container
        [NSLayoutConstraint activateConstraints:@[
            [errorContainer.topAnchor constraintEqualToAnchor:self.showFormButton.bottomAnchor constant:[ThemeHelper spacingLG]],
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
    errorIcon.accessibilityIdentifier = @"basicCheckoutErrorIcon";
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
    errorTitle.accessibilityIdentifier = @"basicCheckoutErrorTitle";
    errorTitle.accessibilityLabel = @"Error";
    errorTitle.accessibilityHint = @"Error message title";
    errorTitle.accessibilityTraits = UIAccessibilityTraitHeader;
    [hStack addArrangedSubview:errorTitle];
    
    [vStack addArrangedSubview:hStack];
    
    // Create error message
    UILabel *errorMessageLabel = [[UILabel alloc] init];
    errorMessageLabel.text = self.errorMessage;
    errorMessageLabel.font = [ThemeHelper screenBodyFont];
    errorMessageLabel.textColor = [ThemeHelper textColor];
    errorMessageLabel.numberOfLines = 0;
    errorMessageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    errorMessageLabel.accessibilityIdentifier = @"basicCheckoutErrorMessageText";
    errorMessageLabel.accessibilityHint = @"Error message from payment process";
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
    
    // Scroll to bottom after a short delay to ensure layout is complete
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.scrollView setNeedsLayout];
        [self.scrollView layoutIfNeeded];
        
        // Wait a bit more for the layout to complete
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CGFloat contentHeight = self.scrollView.contentSize.height;
            CGFloat scrollViewHeight = self.scrollView.bounds.size.height;
            CGFloat bottomOffset = contentHeight - scrollViewHeight;
            
            // Add a buffer to ensure we're at the very bottom
            bottomOffset = MAX(0, bottomOffset + 20);
            
            [self.scrollView setContentOffset:CGPointMake(0, bottomOffset) animated:YES];
        });
    });
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    // After scrolling animation ends, check if result container is fully visible
    if (!self.resultContainer.hidden) {
        [self checkResultContainerVisibility];
    }
}

- (void)checkResultContainerVisibility {
    // Calculate if the result container is fully visible
    CGRect resultContainerFrame = [self.resultContainer convertRect:self.resultContainer.bounds toView:self.scrollView];
    CGFloat resultContainerBottom = resultContainerFrame.origin.y + resultContainerFrame.size.height;
    
    CGFloat scrollViewHeight = self.scrollView.bounds.size.height;
    CGFloat currentOffset = self.scrollView.contentOffset.y;
    CGFloat visibleBottom = currentOffset + scrollViewHeight;
    
    // If still not fully visible, scroll a bit more
    if (resultContainerBottom > visibleBottom) {
        CGFloat additionalOffset = resultContainerBottom - visibleBottom + 10;
        [self.scrollView setContentOffset:CGPointMake(0, currentOffset + additionalOffset) animated:YES];
    }
}

#pragma mark - SpreedlyPaymentDelegate

- (void)paymentDidComplete:(PaymentResult *)result {
    self.paymentResult = result;
    self.isLoading = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimating];
        self.showFormButton.enabled = YES;
        
        if (result.isSuccess) {
            self.errorMessage = nil;
            
            // Handle card retention preference (save card for future payments)
            if (result.shouldRetain && result.token) {
                [self retainPaymentMethodWithToken:result.token];
            }
            
            // Dismiss the drop-in view controller on success
            if (self.presentedViewController) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
        } else if (result.isFailure) {
            NSString *errorMessage = @"Payment failed";
            if (result.failureDetails) {
                errorMessage = [result.failureDetails getDescription];
            }
            // Dismiss the drop-in view controller on error
            if (self.presentedViewController) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
            self.errorMessage = errorMessage;
            self.paymentResult = nil;
            self.isLoading = NO;
            [self.loadingIndicator stopAnimating];
            self.showFormButton.enabled = YES;
        }
        
        [self updateUI];
    });
}

#pragma mark - Retain Payment Method Helper

- (void)retainPaymentMethodWithToken:(NSString *)token {
    // Get the API client from config manager
    RetainPaymentMethodAPIClient *apiClient = [[SpreedlyConfigManager shared] createRetainPaymentMethodAPIClient];
    
    // Call the retain API
    [apiClient retainPaymentMethodWithToken:token completion:^(RetainPaymentMethodResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            return;
        }
        
        if (!response || !response.transaction) {
            return;
        }
    }];
}


@end 
