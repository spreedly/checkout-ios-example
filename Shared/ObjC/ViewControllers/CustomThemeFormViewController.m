//
//  CustomThemeFormViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  Created by Vinay Naikade on 12/08/25.
//

#import "CustomThemeFormViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import "SpreedlyConfigManager.h"
#import "RetainPaymentMethodAPIClient.h"
#import "RetainPaymentMethodModels.h"
#import "ThemeHelper.h"

@interface CustomThemeFormViewController () <UIScrollViewDelegate, SpreedlyPaymentDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *headerContainer;
@property (nonatomic, strong) UIView *configContainer;
@property (nonatomic, strong) UIView *personalInfoContainer;
@property (nonatomic, strong) UIView *paymentInfoContainer;
@property (nonatomic, strong) UIButton *payButton;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UIView *errorContainer;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

// Keyboard handling
@property (nonatomic, assign) CGSize originalContentSize;
@property (nonatomic, strong) NSTimer *keyboardScrollTimer;
@property (nonatomic, assign) CGFloat keyboardHeight;

@property (nonatomic, strong) SPLTextFieldViewController *firstNameField;
@property (nonatomic, strong) SPLTextFieldViewController *lastNameField;
@property (nonatomic, strong) SPLTextFieldViewController *cardNumberField;
@property (nonatomic, strong) SPLTextFieldViewController *expirationMonthField;
@property (nonatomic, strong) SPLTextFieldViewController *expirationYearField;
@property (nonatomic, strong) SPLTextFieldViewController *cvcField;

@property (nonatomic, strong) UISwitch *allowExpiredDateSwitch;

@property (nonatomic, strong) PaymentResult *paymentResult;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, assign) BOOL isLoading;

@property (nonatomic, assign) BOOL allowExpiredDate;
@property (nonatomic, assign) BOOL shouldRetain;

@property (nonatomic, strong) UIView *checkboxContainer;
@property (nonatomic, strong) UIButton *saveCardCheckbox;
@property (nonatomic, strong) UILabel *saveCardLabel;

@end

@implementation CustomThemeFormViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Custom Theme";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.allowExpiredDate = [[Spreedly shared].paramsManager getParamWithParameter:ValidationParamAllowExpiredDate];
    
    // Set global theme with custom purple theme so SDK components (like CVVRecaching) use it
    SPLThemeConfig *lightTheme = [self createLightThemeConfig];
    SPLThemeConfig *darkTheme = [self createDarkThemeConfig];
    [SpreedlyThemeManagerObjC setGlobalThemeWithLightConfig:lightTheme darkConfig:darkTheme];
    
    [self setupUI];
    [self setupConstraints];
    
    // Set scroll view delegate
    self.scrollView.delegate = self;
    
    // Set up payment result delegate
    [Spreedly.shared setPaymentDelegate:self];
    
    if (![Spreedly isDeviceTrusted]) {
        self.errorMessage = Spreedly.initializationError.message ?: @"SDK blocked by security check";
        [self updateUI];
    }
}

- (void)resetUI {
    [self.scrollView removeFromSuperview];
    self.scrollView = nil;
}

- (void)setupUI {
    // Scroll View
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.accessibilityIdentifier = @"custom-theme-scrollview";
    [self.view addSubview:self.scrollView];
    
    // Content View
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    
    // Header Container
    self.headerContainer = [self createHeaderContainer];
    
    // Config Container
    self.configContainer = [self createConfigContainer];
    
    // Personal Info Container
    self.personalInfoContainer = [self createPersonalInfoContainer];
    
    // Payment Info Container
    self.paymentInfoContainer = [self createPaymentInfoContainer];
    
    // Save Card Checkbox Container
    self.checkboxContainer = [[UIView alloc] init];
    self.checkboxContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.checkboxContainer];
    
    // Checkbox Button
    self.saveCardCheckbox = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.saveCardCheckbox setImage:[UIImage systemImageNamed:@"square"] forState:UIControlStateNormal];
    [self.saveCardCheckbox setImage:[UIImage systemImageNamed:@"checkmark.square.fill"] forState:UIControlStateSelected];
    self.saveCardCheckbox.tintColor = [self customThemeTextSecondaryColor];
    self.saveCardCheckbox.selected = self.shouldRetain;
    [self.saveCardCheckbox addTarget:self action:@selector(toggleSaveCard:) forControlEvents:UIControlEventTouchUpInside];
    self.saveCardCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveCardCheckbox.accessibilityIdentifier = @"custom-theme-form-save-card-checkbox";
    [self.checkboxContainer addSubview:self.saveCardCheckbox];
    
    // Save Card Label
    self.saveCardLabel = [[UILabel alloc] init];
    self.saveCardLabel.text = @"Save card for future payments";
    self.saveCardLabel.font = [self customThemeBodyFont];
    self.saveCardLabel.textColor = [self customThemeTextColor];
    self.saveCardLabel.userInteractionEnabled = YES;
    self.saveCardLabel.translatesAutoresizingMaskIntoConstraints = NO;
    UITapGestureRecognizer *labelTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleSaveCard:)];
    [self.saveCardLabel addGestureRecognizer:labelTap];
    [self.checkboxContainer addSubview:self.saveCardLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.saveCardCheckbox.leadingAnchor constraintEqualToAnchor:self.checkboxContainer.leadingAnchor],
        [self.saveCardCheckbox.centerYAnchor constraintEqualToAnchor:self.checkboxContainer.centerYAnchor],
        [self.saveCardCheckbox.widthAnchor constraintEqualToConstant:24],
        [self.saveCardCheckbox.heightAnchor constraintEqualToConstant:24],
        
        [self.saveCardLabel.leadingAnchor constraintEqualToAnchor:self.saveCardCheckbox.trailingAnchor constant:8],
        [self.saveCardLabel.centerYAnchor constraintEqualToAnchor:self.checkboxContainer.centerYAnchor],
        [self.saveCardLabel.trailingAnchor constraintEqualToAnchor:self.checkboxContainer.trailingAnchor],
        
        [self.checkboxContainer.heightAnchor constraintEqualToConstant:32]
    ]];
    
    // Pay Button
    self.payButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
    self.payButton.titleLabel.font = [ThemeHelper buttonFont];
    self.payButton.backgroundColor = [self customThemePrimaryColor];
    [self.payButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.payButton.layer.cornerRadius = 12;
    self.payButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.payButton.layer.shadowOffset = CGSizeMake(0, 2);
    self.payButton.layer.shadowOpacity = 0.1;
    self.payButton.layer.shadowRadius = 4;
    self.payButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.payButton.accessibilityIdentifier = @"customThemePayButton";
    [self.payButton addTarget:self action:@selector(payButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.payButton];
    
    // Result Container
    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.backgroundColor = [[self customThemeSuccessColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = 12;
    self.resultContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    self.resultContainer.layer.shadowOffset = CGSizeMake(0, 2);
    self.resultContainer.layer.shadowOpacity = 0.1;
    self.resultContainer.layer.shadowRadius = 4;
    self.resultContainer.hidden = YES;
    self.resultContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.resultContainer];
    
    // Error Container
    self.errorContainer = [[UIView alloc] init];
    self.errorContainer.backgroundColor = [[self customThemeErrorColor] colorWithAlphaComponent:0.1];
    self.errorContainer.layer.cornerRadius = 12;
    self.errorContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    self.errorContainer.layer.shadowOffset = CGSizeMake(0, 2);
    self.errorContainer.layer.shadowOpacity = 0.1;
    self.errorContainer.layer.shadowRadius = 4;
    self.errorContainer.hidden = YES;
    self.errorContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.errorContainer];
    
    // Loading Indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
}

- (UIView *)createHeaderContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor clearColor];
    container.layer.cornerRadius = 16;
    container.layer.shadowOpacity = 0.0;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Custom Theme Payment";
    titleLabel.font = [self customThemeTitleFont];
    titleLabel.textColor = [self customThemeTextColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityIdentifier = @"customThemeTitle";
    [container addSubview:titleLabel];
    
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = @"Experience our beautiful custom theme";
    subtitleLabel.font = [self customThemeBodyFont];
    subtitleLabel.textColor = [self customThemeTextSecondaryColor];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:subtitleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:24],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-24]
    ]];
    
    return container;
}

- (void)toggleSwitch:(UISwitch *)ts {
    if([ts isEqual:self.allowExpiredDateSwitch]) {
        self.allowExpiredDate = ts.isOn;
        [[Spreedly shared] setParamWithParameter:ValidationParamAllowExpiredDate value:ts.isOn];
        [[SpreedlyUIManager shared] notifySpreedlyParamsUpdated];
        [[SpreedlyUIManager shared] notifyForceOnValidationChangeFor:FormFieldTypeExpirationMonth];
        [[SpreedlyUIManager shared] notifyForceOnValidationChangeFor:FormFieldTypeExpirationYear];
    }
}

- (UIView *)createConfigContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = 16;
    container.layer.borderWidth = 1.0;
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    container.layer.borderColor = resolvedBorderColor.CGColor;
    [ThemeHelper applySmallShadowToView:container];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Configuration Options";
    titleLabel.font = [self customThemeTitleFont];
    titleLabel.textColor = [self customThemeTextColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:titleLabel];
    
    // Allow Expired Date Switch
    UILabel *expiredDateLabel = [[UILabel alloc] init];
    expiredDateLabel.text = @"Allow Expired Date";
    expiredDateLabel.font = [self customThemeBodyFont];
    expiredDateLabel.textColor = [self customThemeTextColor];
    expiredDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:expiredDateLabel];
    
    self.allowExpiredDateSwitch = [[UISwitch alloc] init];
    self.allowExpiredDateSwitch.onTintColor = [ThemeHelper primaryColor];
    self.allowExpiredDateSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowExpiredDateSwitch.accessibilityIdentifier = @"customThemeAllowExpiredDateToggle";
    [container addSubview:self.allowExpiredDateSwitch];
    [self.allowExpiredDateSwitch setOn:self.allowExpiredDate];
    [self.allowExpiredDateSwitch addTarget:self action:@selector(toggleSwitch:) forControlEvents:UIControlEventValueChanged];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        
        [expiredDateLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16],
        [expiredDateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [expiredDateLabel.centerYAnchor constraintEqualToAnchor:self.allowExpiredDateSwitch.centerYAnchor],
        
        [self.allowExpiredDateSwitch.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16],
        [self.allowExpiredDateSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [self.allowExpiredDateSwitch.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-20]
    ]];
    
    return container;
}

- (SPLThemeConfig *)createLightThemeConfig {
    UIColor *purpleColor = [UIColor colorWithRed:0.4 green:0.2 blue:0.8 alpha:1.0];
    UIColor *darkPurpleColor = [UIColor colorWithRed:0.15 green:0.1 blue:0.25 alpha:1.0];
    UIColor *textSecondary = [UIColor colorWithRed:0.5 green:0.45 blue:0.6 alpha:1.0];
    UIColor *borderColor = [UIColor colorWithRed:0.85 green:0.8 blue:0.9 alpha:1.0];
    UIColor *placeholderColor = [UIColor colorWithRed:0.65 green:0.6 blue:0.75 alpha:1.0];
    
    return [[SPLThemeConfig alloc] initWithPrimaryColor:purpleColor
                                         secondaryColor:nil
                                        backgroundColor:[UIColor clearColor]
                                           surfaceColor:[UIColor whiteColor]
                                             borderColor:borderColor
                                      borderFocusedColor:nil
                                               textColor:darkPurpleColor
                                      textSecondaryColor:textSecondary
                                             errorColor:[UIColor colorWithRed:0.8 green:0.2 blue:0.4 alpha:1.0]
                                        placeholderColor:placeholderColor
                                          borderRadius:12.0];
}

- (SPLThemeConfig *)createDarkThemeConfig {
    UIColor *brightPurpleColor = [UIColor colorWithRed:0.6 green:0.4 blue:1.0 alpha:1.0];
    UIColor *darkSurfaceColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:1.0];
    UIColor *lightTextColor = [UIColor colorWithRed:0.95 green:0.9 blue:1.0 alpha:1.0];
    UIColor *textSecondary = [UIColor colorWithRed:0.7 green:0.65 blue:0.8 alpha:1.0];
    UIColor *borderColor = [UIColor colorWithRed:0.3 green:0.25 blue:0.4 alpha:1.0];
    UIColor *placeholderColor = [UIColor colorWithRed:0.5 green:0.45 blue:0.6 alpha:1.0];
    
    return [[SPLThemeConfig alloc] initWithPrimaryColor:brightPurpleColor
                                         secondaryColor:nil
                                        backgroundColor:[UIColor clearColor]
                                           surfaceColor:darkSurfaceColor
                                             borderColor:borderColor
                                      borderFocusedColor:nil
                                               textColor:lightTextColor
                                      textSecondaryColor:textSecondary
                                             errorColor:[UIColor colorWithRed:1.0 green:0.3 blue:0.5 alpha:1.0]
                                        placeholderColor:placeholderColor
                                          borderRadius:12.0];
}

// MARK: - Custom Theme Fonts & Colors (match SwiftUI CustomThemeFormView)
- (UIFont *)customThemeTitleFont {
    return [self roundedFontOfSize:28 weight:UIFontWeightBold];
}

- (UIFont *)customThemeSubtitleFont {
    return [self roundedFontOfSize:22 weight:UIFontWeightSemibold];
}

- (UIFont *)customThemeBodyFont {
    return [self roundedFontOfSize:16 weight:UIFontWeightRegular];
}

- (UIFont *)customThemeCaptionFont {
    return [self roundedFontOfSize:14 weight:UIFontWeightMedium];
}

- (UIFont *)roundedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont *font = [UIFont systemFontOfSize:size weight:weight];
    if (@available(iOS 14.0, *)) {
        UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
        if (descriptor) {
            return [UIFont fontWithDescriptor:descriptor size:size];
        }
    }
    return font;
}

- (UIColor *)customThemeTextColor {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.95 green:0.9 blue:1.0 alpha:1.0];
        } else {
            return [UIColor colorWithRed:0.15 green:0.1 blue:0.25 alpha:1.0];
        }
    }];
}

- (UIColor *)customThemeTextSecondaryColor {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.7 green:0.65 blue:0.8 alpha:1.0];
        } else {
            return [UIColor colorWithRed:0.5 green:0.45 blue:0.6 alpha:1.0];
        }
    }];
}

- (UIColor *)customThemePrimaryColor {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.6 green:0.4 blue:1.0 alpha:1.0];
        } else {
            return [UIColor colorWithRed:0.4 green:0.2 blue:0.8 alpha:1.0];
        }
    }];
}

- (UIColor *)customThemeSuccessColor {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:0.3 green:0.8 blue:0.5 alpha:1.0];
        } else {
            return [UIColor colorWithRed:0.2 green:0.6 blue:0.4 alpha:1.0];
        }
    }];
}

- (UIColor *)customThemeErrorColor {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:1.0 green:0.3 blue:0.5 alpha:1.0];
        } else {
            return [UIColor colorWithRed:0.8 green:0.2 blue:0.4 alpha:1.0];
        }
    }];
}

- (UIView *)createPersonalInfoContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = 16;
    container.layer.borderWidth = 1.0;
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    container.layer.borderColor = resolvedBorderColor.CGColor;
    [ThemeHelper applySmallShadowToView:container];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Personal Information";
    titleLabel.font = [self customThemeTitleFont];
    titleLabel.textColor = [self customThemeTextColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:titleLabel];
    
    // Create light and dark theme configs
    SPLThemeConfig *lightTheme = [self createLightThemeConfig];
    SPLThemeConfig *darkTheme = [self createDarkThemeConfig];
    
    self.firstNameField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeFirstName
                                                                      title:@"First Name"
                                                                 isRequired:YES
                                                                placeholder:nil
                                                                keyboardType:UIKeyboardTypeDefault
                                                                textContentType:UITextContentTypeName
                                                           lightThemeConfig:lightTheme
                                                           darkThemeConfig:darkTheme
                                                         onValidationChange:nil
                                                                     onFocus:nil];
    [self addChildViewController:self.firstNameField];
    self.firstNameField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.firstNameField.view];
    [self.firstNameField didMoveToParentViewController:self];
    
    self.lastNameField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeLastName
                                                                     title:@"Last Name"
                                                                isRequired:YES
                                                                placeholder:nil
                                                                keyboardType:UIKeyboardTypeDefault
                                                                textContentType:UITextContentTypeName
                                                           lightThemeConfig:lightTheme
                                                           darkThemeConfig:darkTheme
                                                         onValidationChange:nil
                                                                     onFocus:nil];
    [self addChildViewController:self.lastNameField];
    self.lastNameField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.lastNameField.view];
    [self.lastNameField didMoveToParentViewController:self];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        
        [self.firstNameField.view.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16],
        [self.firstNameField.view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [self.firstNameField.view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [self.firstNameField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        
        [self.lastNameField.view.topAnchor constraintEqualToAnchor:self.firstNameField.view.bottomAnchor constant:16],
        [self.lastNameField.view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [self.lastNameField.view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [self.lastNameField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        [self.lastNameField.view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-20]
    ]];
    
    return container;
}

- (UIView *)createPaymentInfoContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = 16;
    container.layer.borderWidth = 1.0;
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    UIColor *resolvedBorderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection];
    container.layer.borderColor = resolvedBorderColor.CGColor;
    [ThemeHelper applySmallShadowToView:container];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:container];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Payment Information";
    titleLabel.font = [self customThemeTitleFont];
    titleLabel.textColor = [self customThemeTextColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:titleLabel];
    
    // Create light and dark theme configs
    SPLThemeConfig *lightTheme = [self createLightThemeConfig];
    SPLThemeConfig *darkTheme = [self createDarkThemeConfig];
    
    self.cardNumberField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeCardNumber
                                                                        title:@"Card Number"
                                                                   isRequired:YES
                                                                   placeholder:nil
                                                                   keyboardType:UIKeyboardTypeNumberPad
                                                                   textContentType:UITextContentTypeCreditCardNumber
                                                              lightThemeConfig:lightTheme
                                                              darkThemeConfig:darkTheme
                                                            onValidationChange:nil
                                                                        onFocus:nil];
    [self addChildViewController:self.cardNumberField];
    self.cardNumberField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cardNumberField.view];
    [self.cardNumberField didMoveToParentViewController:self];
    
    // Expiration and CVC fields in a horizontal stack
    UIView *expirationCvcContainer = [[UIView alloc] init];
    expirationCvcContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:expirationCvcContainer];
    
    self.expirationMonthField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeExpirationMonth
                                                                            title:@"Expiry Month"
                                                                       isRequired:YES
                                                                       placeholder:nil
                                                                       keyboardType:UIKeyboardTypeNumberPad
                                                                       textContentType:nil
                                                                  lightThemeConfig:lightTheme
                                                                  darkThemeConfig:darkTheme
                                                                onValidationChange:nil
                                                                           onFocus:nil];
    [self addChildViewController:self.expirationMonthField];
    self.expirationMonthField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [expirationCvcContainer addSubview:self.expirationMonthField.view];
    [self.expirationMonthField didMoveToParentViewController:self];
    
    self.expirationYearField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeExpirationYear
                                                                           title:@"Expiry Year"
                                                                      isRequired:YES
                                                                      placeholder:nil
                                                                      keyboardType:UIKeyboardTypeNumberPad
                                                                      textContentType:nil
                                                                 lightThemeConfig:lightTheme
                                                                 darkThemeConfig:darkTheme
                                                               onValidationChange:nil
                                                                          onFocus:nil];
    [self addChildViewController:self.expirationYearField];
    self.expirationYearField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [expirationCvcContainer addSubview:self.expirationYearField.view];
    [self.expirationYearField didMoveToParentViewController:self];
    
    self.cvcField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeCvc
                                                              title:@"CVC"
                                                         isRequired:YES
                                                         placeholder:nil
                                                         keyboardType:UIKeyboardTypeNumberPad
                                                         textContentType:nil
                                                    lightThemeConfig:lightTheme
                                                    darkThemeConfig:darkTheme
                                                  onValidationChange:nil
                                                              onFocus:nil];
    [self addChildViewController:self.cvcField];
    self.cvcField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [expirationCvcContainer addSubview:self.cvcField.view];
    [self.cvcField didMoveToParentViewController:self];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        
        [self.cardNumberField.view.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16],
        [self.cardNumberField.view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [self.cardNumberField.view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [self.cardNumberField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        
        [expirationCvcContainer.topAnchor constraintEqualToAnchor:self.cardNumberField.view.bottomAnchor constant:16],
        [expirationCvcContainer.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [expirationCvcContainer.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [expirationCvcContainer.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-20],
        
        [self.expirationMonthField.view.topAnchor constraintEqualToAnchor:expirationCvcContainer.topAnchor],
        [self.expirationMonthField.view.leadingAnchor constraintEqualToAnchor:expirationCvcContainer.leadingAnchor],
        [self.expirationMonthField.view.bottomAnchor constraintEqualToAnchor:expirationCvcContainer.bottomAnchor],
        [self.expirationMonthField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        
        [self.expirationYearField.view.topAnchor constraintEqualToAnchor:expirationCvcContainer.topAnchor],
        [self.expirationYearField.view.leadingAnchor constraintEqualToAnchor:self.expirationMonthField.view.trailingAnchor constant:8],
        [self.expirationYearField.view.bottomAnchor constraintEqualToAnchor:expirationCvcContainer.bottomAnchor],
        [self.expirationYearField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        
        [self.cvcField.view.topAnchor constraintEqualToAnchor:expirationCvcContainer.topAnchor],
        [self.cvcField.view.leadingAnchor constraintEqualToAnchor:self.expirationYearField.view.trailingAnchor constant:8],
        [self.cvcField.view.trailingAnchor constraintEqualToAnchor:expirationCvcContainer.trailingAnchor],
        [self.cvcField.view.bottomAnchor constraintEqualToAnchor:expirationCvcContainer.bottomAnchor],
        [self.cvcField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        
        [self.expirationMonthField.view.widthAnchor constraintEqualToAnchor:expirationCvcContainer.widthAnchor multiplier:0.3],
        [self.expirationYearField.view.widthAnchor constraintEqualToAnchor:expirationCvcContainer.widthAnchor multiplier:0.3],
        [self.cvcField.view.widthAnchor constraintEqualToAnchor:expirationCvcContainer.widthAnchor multiplier:0.3]
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
        
        // Header Container
        [self.headerContainer.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:20],
        [self.headerContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.headerContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Config Container
        [self.configContainer.topAnchor constraintEqualToAnchor:self.headerContainer.bottomAnchor constant:20],
        [self.configContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.configContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Personal Info Container
        [self.personalInfoContainer.topAnchor constraintEqualToAnchor:self.configContainer.bottomAnchor constant:20],
        [self.personalInfoContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.personalInfoContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Payment Info Container
        [self.paymentInfoContainer.topAnchor constraintEqualToAnchor:self.personalInfoContainer.bottomAnchor constant:20],
        [self.paymentInfoContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.paymentInfoContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Checkbox Container
        [self.checkboxContainer.topAnchor constraintEqualToAnchor:self.paymentInfoContainer.bottomAnchor constant:20],
        [self.checkboxContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.checkboxContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        
        // Pay Button
        [self.payButton.topAnchor constraintEqualToAnchor:self.checkboxContainer.bottomAnchor constant:20],
        [self.payButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.payButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.payButton.heightAnchor constraintEqualToConstant:50],
        
        // Result Container
        [self.resultContainer.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:20],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.resultContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-20],
        
        // Error Container
        [self.errorContainer.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:20],
        [self.errorContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.errorContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
        [self.errorContainer.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-20],
        
        // Loading Indicator
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

- (void)toggleSaveCard:(id)sender {
    self.shouldRetain = !self.shouldRetain;
    self.saveCardCheckbox.selected = self.shouldRetain;
    UIColor *tintColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return self.shouldRetain ? [UIColor colorWithRed:0.6 green:0.4 blue:1.0 alpha:1.0] : [UIColor colorWithRed:0.7 green:0.65 blue:0.8 alpha:1.0];
        } else {
            return self.shouldRetain ? [UIColor colorWithRed:0.4 green:0.2 blue:0.8 alpha:1.0] : [UIColor colorWithRed:0.5 green:0.45 blue:0.6 alpha:1.0];
        }
    }];
    self.saveCardCheckbox.tintColor = tintColor;
}

- (void)payButtonTapped {
    self.isLoading = YES;
    [self.loadingIndicator startAnimating];
    [self.payButton setTitle:@"Processing..." forState:UIControlStateNormal];
    self.payButton.enabled = NO;
    self.errorMessage = nil;
    self.paymentResult = nil;
    [self updateUI];
    
    // Generate signature for Spreedly configuration
    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            // Create credit card payment
            [self createCreditCardPayment];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
                self.payButton.enabled = YES;
                self.errorMessage = error.localizedDescription;
                [self updateUI];
            });
        }
    }];
}

- (void)createCreditCardPayment {
    // Capture UI values on the main thread before making the API call
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *additionalFields = @{};
        
        // Create metadata
        NSDictionary *metadata = @{};
        
        // Call Spreedly createCreditCard (synchronous, returns PaymentProcessingResult)
        Spreedly *spreedly = [Spreedly shared];
        PaymentProcessingResult *processingResult = [spreedly createCreditCardObjCWithAdditionalFields:additionalFields metadata: metadata];
        
        // Handle immediate processing result
        if (processingResult.isValidationFailed) {
            self.isLoading = NO;
            [self.loadingIndicator stopAnimating];
            [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
            self.payButton.enabled = YES;
            self.errorMessage = [processingResult getDescription];
            self.paymentResult = nil;
            [self updateUI];
        } else if (processingResult.isProcessing) {
            // Keep loading state - actual result will come through the delegate
            // Payment results will be handled by the paymentDidComplete: delegate method
        }
    });
}

- (void)updateUI {
    // Update result container
    if (self.paymentResult && self.paymentResult.isSuccess) {
        [self setupResultContainer];
        self.resultContainer.hidden = NO;
        self.errorContainer.hidden = YES;
        
        // Ensure the result container is fully visible
        [self ensureResultContainerVisible];
    } else if (self.errorMessage) {
        [self setupErrorContainer];
        self.errorContainer.hidden = NO;
        self.resultContainer.hidden = YES;
    } else {
        self.resultContainer.hidden = YES;
        self.errorContainer.hidden = YES;
    }
}

- (void)ensureResultContainerVisible {
    // Force immediate layout update
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    
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
    
    // Success icon and title
    UIImageView *successIcon = [[UIImageView alloc] init];
    successIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    successIcon.tintColor = [self customThemeSuccessColor];
    successIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultContainer addSubview:successIcon];
    
    UILabel *successLabel = [[UILabel alloc] init];
    successLabel.text = @"Payment Successful!";
    successLabel.font = [self customThemeSubtitleFont];
    successLabel.textColor = [self customThemeSuccessColor];
    successLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultContainer addSubview:successLabel];
    
    // Transaction token
    UILabel *transactionLabel = nil;
    if (self.paymentResult.token) {
        transactionLabel = [[UILabel alloc] init];
        NSString *masked = [Spreedly maskedToken:self.paymentResult.token];
        transactionLabel.text = [NSString stringWithFormat:@"Transaction Token: %@", masked];
        transactionLabel.font = [self customThemeCaptionFont];
        transactionLabel.textColor = [self customThemeTextSecondaryColor];
        transactionLabel.numberOfLines = 0;
        transactionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.resultContainer addSubview:transactionLabel];
    }
    
    // Setup constraints
    NSMutableArray *constraints = [NSMutableArray array];
    
    [constraints addObjectsFromArray:@[
        [successIcon.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:20],
        [successIcon.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:20],
        [successIcon.widthAnchor constraintEqualToConstant:24],
        [successIcon.heightAnchor constraintEqualToConstant:24],
        
        [successLabel.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:20],
        [successLabel.leadingAnchor constraintEqualToAnchor:successIcon.trailingAnchor constant:12],
        [successLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-20]
    ]];
    
    UIView *lastView = successLabel;
    
    if (transactionLabel) {
        [constraints addObjectsFromArray:@[
            [transactionLabel.topAnchor constraintEqualToAnchor:lastView.bottomAnchor constant:12],
            [transactionLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:20],
            [transactionLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-20]
        ]];
        lastView = transactionLabel;
    }
    
    [constraints addObject:[lastView.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-20]];
    
    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)setupErrorContainer {
    // Remove existing subviews
    for (UIView *subview in self.errorContainer.subviews) {
        [subview removeFromSuperview];
    }
    
    // Error icon and message
    UIImageView *errorIcon = [[UIImageView alloc] init];
    errorIcon.image = [UIImage systemImageNamed:@"exclamationmark.triangle.fill"];
    errorIcon.tintColor = [self customThemeErrorColor];
    errorIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.errorContainer addSubview:errorIcon];
    
    UILabel *errorLabel = [[UILabel alloc] init];
    errorLabel.text = [NSString stringWithFormat:@"Error: %@", self.errorMessage];
    errorLabel.font = [self customThemeBodyFont];
    errorLabel.textColor = [self customThemeErrorColor];
    errorLabel.numberOfLines = 0;
    errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.errorContainer addSubview:errorLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [errorIcon.topAnchor constraintEqualToAnchor:self.errorContainer.topAnchor constant:20],
        [errorIcon.leadingAnchor constraintEqualToAnchor:self.errorContainer.leadingAnchor constant:20],
        [errorIcon.widthAnchor constraintEqualToConstant:24],
        [errorIcon.heightAnchor constraintEqualToConstant:24],
        
        [errorLabel.topAnchor constraintEqualToAnchor:self.errorContainer.topAnchor constant:20],
        [errorLabel.leadingAnchor constraintEqualToAnchor:errorIcon.trailingAnchor constant:12],
        [errorLabel.trailingAnchor constraintEqualToAnchor:self.errorContainer.trailingAnchor constant:-20],
        [errorLabel.bottomAnchor constraintEqualToAnchor:self.errorContainer.bottomAnchor constant:-20]
    ]];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[Spreedly shared] reset];
    
    // Stop keyboard scroll timer
    [self stopKeyboardScrollTimer];
    
    // unregister for keyboard notifications while not visible.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                             name:UIKeyboardWillShowNotification
                                           object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                             name:UIKeyboardWillHideNotification
                                           object:nil];
    
    // Remove text field notification observer
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                             name:UITextFieldTextDidBeginEditingNotification
                                           object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // Clean up child view controllers
    if (self.firstNameField) {
        [self.firstNameField willMoveToParentViewController:nil];
        [self.firstNameField.view removeFromSuperview];
        [self.firstNameField removeFromParentViewController];
    }
    
    if (self.lastNameField) {
        [self.lastNameField willMoveToParentViewController:nil];
        [self.lastNameField.view removeFromSuperview];
        [self.lastNameField removeFromParentViewController];
    }
    
    if (self.cardNumberField) {
        [self.cardNumberField willMoveToParentViewController:nil];
        [self.cardNumberField.view removeFromSuperview];
        [self.cardNumberField removeFromParentViewController];
    }
    
    if (self.expirationMonthField) {
        [self.expirationMonthField willMoveToParentViewController:nil];
        [self.expirationMonthField.view removeFromSuperview];
        [self.expirationMonthField removeFromParentViewController];
    }
    
    if (self.expirationYearField) {
        [self.expirationYearField willMoveToParentViewController:nil];
        [self.expirationYearField.view removeFromSuperview];
        [self.expirationYearField removeFromParentViewController];
    }
    
    if (self.cvcField) {
        [self.cvcField willMoveToParentViewController:nil];
        [self.cvcField.view removeFromSuperview];
        [self.cvcField removeFromParentViewController];
    }
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

#define kOFFSET_FOR_KEYBOARD 150.0

-(void)keyboardWillShow:(NSNotification *)notification {
    // Get keyboard frame and animation duration
    NSDictionary *userInfo = notification.userInfo;
    CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval animationDuration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    // Convert keyboard frame to view coordinates
    keyboardFrame = [self.view convertRect:keyboardFrame fromView:nil];
    
    // Store the keyboard height for visibility calculations
    self.keyboardHeight = keyboardFrame.size.height;
    
    // Calculate the amount we need to move up
    CGFloat keyboardHeight = keyboardFrame.size.height;
    CGFloat availableHeight = self.view.bounds.size.height - keyboardHeight;
    
    // Calculate the content height needed
    CGFloat contentHeight = self.scrollView.contentSize.height;
    CGFloat additionalHeight = MAX(0, contentHeight - availableHeight + kOFFSET_FOR_KEYBOARD);
    
    // Animate the scroll view content size change
    [UIView animateWithDuration:animationDuration animations:^{
        self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width, 
                                               self.scrollView.contentSize.height + additionalHeight);
    } completion:^(BOOL finished) {
        // After the animation, scroll to the active text field
        [self scrollToActiveTextField];
        
        // Start a timer to periodically check for active text fields
        // This helps catch SPLTextField components that might not trigger the delegate
        [self startKeyboardScrollTimer];
        
        // Also try to scroll to the bottom fields specifically with a delay
        // This ensures the keyboard is fully visible before scrolling
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self scrollToBottomFields];
        });
    }];
}

-(void)keyboardWillHide:(NSNotification *)notification {
    // Stop the keyboard scroll timer
    [self stopKeyboardScrollTimer];
    
    // Reset keyboard height
    self.keyboardHeight = 0;
    
    // Get animation duration
    NSDictionary *userInfo = notification.userInfo;
    NSTimeInterval animationDuration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    // Reset the scroll view content size to original
    [UIView animateWithDuration:animationDuration animations:^{
        self.scrollView.contentSize = self.originalContentSize;
    }];
}

-(void)textFieldDidBeginEditing:(id)sender {
    UITextField *textField = nil;
    
    // Handle both direct UITextField calls and NSNotification calls
    if ([sender isKindOfClass:[UITextField class]]) {
        textField = (UITextField *)sender;
    } else if ([sender isKindOfClass:[NSNotification class]]) {
        NSNotification *notification = (NSNotification *)sender;
        textField = (UITextField *)notification.object;
    }
    
    if (!textField) {
        return;
    }
    
    // Scroll to make the text field visible
    [self scrollToTextField:textField];
    
    // Also force scroll to bottom if this is one of the bottom fields
    if (textField.superview == self.expirationMonthField.view || 
        textField.superview == self.expirationYearField.view || 
        textField.superview == self.cvcField.view) {
        
        // Check if the bottom row is already visible
        if (![self isBottomRowVisible]) {
            [self forceScrollToBottom];
        }
    }
}

// Force scroll to bottom method
-(void)forceScrollToBottom {
    // Check if we're already scrolled down enough
    CGFloat currentOffset = self.scrollView.contentOffset.y;
    CGFloat maxOffset = self.scrollView.contentSize.height - self.scrollView.bounds.size.height;
    maxOffset = MAX(0, maxOffset);
    
    // Only scroll if we're not already scrolled down enough
    if (currentOffset >= maxOffset * 0.5) {
        return;
    }
    
    // Reduce the offset to avoid scrolling too far
    CGFloat adjustedOffset = maxOffset * 0.7; // Only scroll 70% of the way down
    
    // Scroll to the adjusted position
    [self.scrollView setContentOffset:CGPointMake(0, adjustedOffset) animated:YES];
}

// Helper method to scroll to a specific text field
-(void)scrollToTextField:(UITextField *)textField {
    // Find the text field's frame in the scroll view
    CGRect textFieldFrame = [textField convertRect:textField.bounds toView:self.scrollView];
    
    // Check if the text field is already visible in the scroll view
    if ([self isViewVisible:textFieldFrame inScrollView:self.scrollView]) {
        return;
    }
    
    // Add some padding
    textFieldFrame.origin.y -= 20;
    textFieldFrame.size.height += 40;
    
    // Scroll to make the text field visible
    [self.scrollView scrollRectToVisible:textFieldFrame animated:YES];
}

// Helper method to check if a view frame is visible in the scroll view
-(BOOL)isViewVisible:(CGRect)viewFrame inScrollView:(UIScrollView *)scrollView {
    CGRect visibleRect = CGRectMake(scrollView.contentOffset.x, 
                                   scrollView.contentOffset.y, 
                                   scrollView.bounds.size.width, 
                                   scrollView.bounds.size.height);
    
    // Check if the view frame intersects with the visible rect
    BOOL isVisible = CGRectIntersectsRect(viewFrame, visibleRect);
    
    // Additional check: if the view is within the visible area with some tolerance
    if (isVisible) {
        // Check if the view is actually well within the visible area (not just barely touching)
        CGFloat viewTop = viewFrame.origin.y;
        CGFloat viewBottom = viewFrame.origin.y + viewFrame.size.height;
        CGFloat visibleTop = visibleRect.origin.y;
        CGFloat visibleBottom = visibleRect.origin.y + visibleRect.size.height;
        
        // Consider it visible if at least 30% of the view is within the visible area (reduced from 50%)
        CGFloat visibleHeight = MIN(viewBottom, visibleBottom) - MAX(viewTop, visibleTop);
        CGFloat viewHeight = viewFrame.size.height;
        
        if (visibleHeight < viewHeight * 0.3) { // Reduced from 0.5 to 0.3
            isVisible = NO;
        }
    }
    
    return isVisible;
}

// Helper method to check if a view frame is visible above the keyboard
-(BOOL)isViewVisibleAboveKeyboard:(CGRect)viewFrame inScrollView:(UIScrollView *)scrollView {
    // Use the actual keyboard height if available, otherwise use approximate
    CGFloat keyboardHeight = self.keyboardHeight > 0 ? self.keyboardHeight : 300;
    
    // Calculate visible area above keyboard
    CGRect visibleRect = CGRectMake(scrollView.contentOffset.x, 
                                   scrollView.contentOffset.y, 
                                   scrollView.bounds.size.width, 
                                   scrollView.bounds.size.height - keyboardHeight);
    
    // Check if the view frame intersects with the visible area above keyboard
    return CGRectIntersectsRect(viewFrame, visibleRect);
}

// Helper method to check if the bottom row (MM, YYYY, CVC) is visible
-(BOOL)isBottomRowVisible {
    // Check if any of the bottom fields are visible above the keyboard
    if (self.expirationMonthField && self.expirationMonthField.view) {
        CGRect monthFrame = [self.expirationMonthField.view convertRect:self.expirationMonthField.view.bounds toView:self.scrollView];
        if ([self isViewVisibleAboveKeyboard:monthFrame inScrollView:self.scrollView]) {
            return YES;
        }
    }
    
    if (self.expirationYearField && self.expirationYearField.view) {
        CGRect yearFrame = [self.expirationYearField.view convertRect:self.expirationYearField.view.bounds toView:self.scrollView];
        if ([self isViewVisibleAboveKeyboard:yearFrame inScrollView:self.scrollView]) {
            return YES;
        }
    }
    
    if (self.cvcField && self.cvcField.view) {
        CGRect cvcFrame = [self.cvcField.view convertRect:self.cvcField.view.bounds toView:self.scrollView];
        if ([self isViewVisibleAboveKeyboard:cvcFrame inScrollView:self.scrollView]) {
            return YES;
        }
    }
    
    return NO;
}

// Method to scroll to any view (including SPLTextField views)
-(void)scrollToView:(UIView *)view {
    // Find the view's frame in the scroll view
    CGRect viewFrame = [view convertRect:view.bounds toView:self.scrollView];
    
    // Check if the view is already visible
    if ([self isViewVisible:viewFrame inScrollView:self.scrollView]) {
        return;
    }
    
    // Add moderate padding for better visibility
    viewFrame.origin.y -= 20; // Reduced from 50 to 20
    viewFrame.size.height += 40; // Reduced from 100 to 40
    
    // Ensure the frame is within the scroll view bounds
    viewFrame.origin.y = MAX(0, viewFrame.origin.y);
    viewFrame.size.height = MIN(viewFrame.size.height, self.scrollView.contentSize.height - viewFrame.origin.y);
    
    // Scroll to make the view visible
    [self.scrollView scrollRectToVisible:viewFrame animated:YES];
}

// Method to find and scroll to the active text field
-(void)scrollToActiveTextField {
    // Check all text fields in the scroll view
    NSArray *textFields = [self findAllTextFieldsInView:self.scrollView];
    
    for (UITextField *textField in textFields) {
        if (textField.isFirstResponder) {
            [self scrollToTextField:textField];
            break;
        }
    }
}

// Helper method to find all text fields in a view hierarchy
-(NSArray<UITextField *> *)findAllTextFieldsInView:(UIView *)view {
    NSMutableArray<UITextField *> *textFields = [NSMutableArray array];
    
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UITextField class]]) {
            [textFields addObject:(UITextField *)subview];
        } else {
            [textFields addObjectsFromArray:[self findAllTextFieldsInView:subview]];
        }
    }
    
    return [textFields copy];
}

// Timer-based methods to handle SPLTextField components
-(void)startKeyboardScrollTimer {
    [self stopKeyboardScrollTimer]; // Stop any existing timer
    
    self.keyboardScrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                target:self
                                                              selector:@selector(checkForActiveTextField)
                                                              userInfo:nil
                                                               repeats:YES];
}

-(void)stopKeyboardScrollTimer {
    if (self.keyboardScrollTimer) {
        [self.keyboardScrollTimer invalidate];
        self.keyboardScrollTimer = nil;
    }
}

-(void)checkForActiveTextField {
    // Check if any text field is first responder
    NSArray *textFields = [self findAllTextFieldsInView:self.scrollView];
    
    for (UITextField *textField in textFields) {
        if (textField.isFirstResponder) {
            [self scrollToTextField:textField];
            break;
        }
    }
}

// Method to scroll to SPLTextField components specifically
-(void)scrollToSPLTextField:(SPLTextFieldViewController *)splTextField {
    if (splTextField && splTextField.view) {
        [self scrollToView:splTextField.view];
    }
}

// Method to scroll to the bottom fields (MM, YYYY, CVC) specifically
-(void)scrollToBottomFields {
    // Check if bottom row is already visible
    if ([self isBottomRowVisible]) {
        return;
    }
    
    // Calculate a more conservative scroll offset
    CGFloat bottomOffset = self.scrollView.contentSize.height - self.scrollView.bounds.size.height;
    bottomOffset = MAX(0, bottomOffset);
    
    // Add a smaller padding instead of 100
    bottomOffset += 50; // Reduced from 100 to 50
    
    // Check if we're already scrolled to this position or beyond
    CGFloat currentOffset = self.scrollView.contentOffset.y;
    if (currentOffset >= bottomOffset - 20) { // Allow 20px tolerance
        return;
    }
    
    [self.scrollView setContentOffset:CGPointMake(0, bottomOffset) animated:YES];
}

// Override to handle SPLTextField components
-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Add tap gesture to detect when SPLTextField components are tapped
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tapGesture.cancelsTouchesInView = NO;
    [self.scrollView addGestureRecognizer:tapGesture];
}

-(void)handleTapGesture:(UITapGestureRecognizer *)gesture {
    // Find the tapped view and check if it's a text field or contains a text field
    CGPoint tapLocation = [gesture locationInView:self.scrollView];
    UIView *tappedView = [self.scrollView hitTest:tapLocation withEvent:nil];
    
    // Check if the tapped view is a text field or contains one
    UITextField *textField = [self findTextFieldInView:tappedView];
    if (textField) {
        [self scrollToTextField:textField];
        return;
    }
    
    // Check if the tapped view is within any of the SPLTextField components
    if ([self isView:tappedView withinSPLTextField:self.expirationMonthField]) {
        [self scrollToSPLTextField:self.expirationMonthField];
    } else if ([self isView:tappedView withinSPLTextField:self.expirationYearField]) {
        [self scrollToSPLTextField:self.expirationYearField];
    } else if ([self isView:tappedView withinSPLTextField:self.cvcField]) {
        [self scrollToSPLTextField:self.cvcField];
    } else if ([self isView:tappedView withinSPLTextField:self.cardNumberField]) {
        [self scrollToSPLTextField:self.cardNumberField];
    } else if ([self isView:tappedView withinSPLTextField:self.firstNameField]) {
        [self scrollToSPLTextField:self.firstNameField];
    } else if ([self isView:tappedView withinSPLTextField:self.lastNameField]) {
        [self scrollToSPLTextField:self.lastNameField];
    }
}

// Helper method to check if a view is within an SPLTextField component
-(BOOL)isView:(UIView *)view withinSPLTextField:(SPLTextFieldViewController *)splTextField {
    if (!splTextField || !splTextField.view) {
        return NO;
    }
    
    UIView *currentView = view;
    while (currentView != nil) {
        if (currentView == splTextField.view) {
            return YES;
        }
        currentView = currentView.superview;
    }
    
    return NO;
}

-(UITextField *)findTextFieldInView:(UIView *)view {
    if ([view isKindOfClass:[UITextField class]]) {
        return (UITextField *)view;
    }
    
    for (UIView *subview in view.subviews) {
        UITextField *textField = [self findTextFieldInView:subview];
        if (textField) {
            return textField;
        }
    }
    
    return nil;
}

// Debug method to test scrolling - you can call this from anywhere to test
-(void)testScrollToBottom {
    // Force scroll to bottom
    [self forceScrollToBottom];
    
    // Also try scrolling to specific fields
    [self scrollToBottomFields];
}

//method to move the view up/down whenever the keyboard is shown/dismissed
-(void)setViewMovedUp:(BOOL)movedUp
{
    [UIView animateWithDuration:0.3 animations:^{
        if (movedUp)
        {
            self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width, self.scrollView.contentSize.height + kOFFSET_FOR_KEYBOARD);
        }
        else
        {
            self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width, self.scrollView.contentSize.height - kOFFSET_FOR_KEYBOARD);
        }
    }];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(keyboardWillShow:)
                                             name:UIKeyboardWillShowNotification
                                           object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(keyboardWillHide:)
                                             name:UIKeyboardWillHideNotification
                                           object:nil];
    
    // Register for text field notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(textFieldDidBeginEditing:)
                                             name:UITextFieldTextDidBeginEditingNotification
                                           object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // Store the original content size for keyboard handling
    if (CGSizeEqualToSize(self.originalContentSize, CGSizeZero)) {
        self.originalContentSize = self.scrollView.contentSize;
    }
    
    // Ensure scroll view can scroll
    self.scrollView.scrollEnabled = YES;
    self.scrollView.showsVerticalScrollIndicator = YES;
}

#pragma mark - SpreedlyPaymentDelegate

- (void)paymentDidComplete:(PaymentResult *)result {
    self.paymentResult = result;
    self.isLoading = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.loadingIndicator stopAnimating];
        [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
        self.payButton.enabled = YES;
        
        if (result.isSuccess) {
            self.errorMessage = nil;
            
            // Handle card retention preference (save card for future payments)
            if (self.shouldRetain && result.token) {
                // Call retain API asynchronously
                [self retainPaymentMethodWithToken:result.token];
            }
            
            // Reset checkbox state after successful payment
            self.shouldRetain = NO;
            self.saveCardCheckbox.selected = NO;
            UIColor *defaultTintColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithRed:0.7 green:0.65 blue:0.8 alpha:1.0];
                } else {
                    return [UIColor colorWithRed:0.5 green:0.45 blue:0.6 alpha:1.0];
                }
            }];
            self.saveCardCheckbox.tintColor = defaultTintColor;
        } else if (result.isFailure) {
            if (result.failureDetails) {
                self.errorMessage = [result.failureDetails getDescription];
            } else {
                self.errorMessage = @"Payment failed";
            }
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
        
        if (response.transaction.succeeded) {
            // Retain succeeded
        } else {
            // Retain failed
        }
    }];
}

@end 
