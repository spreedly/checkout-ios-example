//
//  CustomFormViewController.m
//  MerchantExample
//
//
//

#import "CustomFormViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <objc/runtime.h>
#import "SpreedlyConfigManager.h"
#import "RetainPaymentMethodAPIClient.h"
#import "RetainPaymentMethodModels.h"
#import "ThemeHelper.h"

@interface CustomFormViewController () <UIScrollViewDelegate, SpreedlyPaymentDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIView *componentsContainer;
@property (nonatomic, strong) UIView *configContainer;
@property (nonatomic, strong) UIView *formContainer;
@property (nonatomic, strong) UIView *checkboxContainer;
@property (nonatomic, strong) UIButton *payButton;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *layoutConstraints;

@property (nonatomic, strong) SPLTextFieldViewController *cardHolderNameField;
@property (nonatomic, strong) SPLTextFieldViewController *cardNumberField;
@property (nonatomic, strong) SPLTextFieldViewController *cvcField;
@property (nonatomic, strong) SPLTextFieldViewController *expirationDateField;

@property (nonatomic, strong) UISwitch *allowBlankNameSwitch;
@property (nonatomic, strong) UISwitch *allowExpiredDateSwitch;
@property (nonatomic, strong) UISwitch *allowBlankDateSwitch;
@property (nonatomic, strong) UISegmentedControl *yearFormatSegmentedControl;

@property (nonatomic, strong) PaymentResult *paymentResult;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL cardHolderNameIsValid;
@property (nonatomic, assign) BOOL cardNumberIsValid;
@property (nonatomic, assign) BOOL cvcIsValid;
@property (nonatomic, assign) BOOL expirationDateIsValid;

@property (nonatomic, assign) BOOL allowBlankName;
@property (nonatomic, assign) BOOL allowExpiredDate;
@property (nonatomic, assign) BOOL allowBlankDate;
@property (nonatomic, assign) BOOL shouldRetain;

@property (nonatomic, strong) UIButton *saveCardCheckbox;
@property (nonatomic, strong) UILabel *saveCardLabel;

@end

@implementation CustomFormViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Custom Payment Form";
    self.view.backgroundColor = [ThemeHelper surfaceColor];
    
    // Initialize properties from Spreedly paramsManager
    self.allowBlankName = [[Spreedly shared].paramsManager getParamWithParameter:ValidationParamAllowBlankName];
    self.allowExpiredDate = [[Spreedly shared].paramsManager getParamWithParameter:ValidationParamAllowExpiredDate];
    self.allowBlankDate = [[Spreedly shared].paramsManager getParamWithParameter:ValidationParamAllowBlankDate];
    
    [self setupUI];
    [self setupConstraints];
    
    // Set scroll view delegate
    self.scrollView.delegate = self;
    
    // Set up payment result delegate
    [Spreedly.shared setPaymentDelegate:self];
    
    // Device trust check handled internally by the SDK
}

- (void)resetUI {
    if (self.layoutConstraints.count > 0) {
        [NSLayoutConstraint deactivateConstraints:self.layoutConstraints];
        self.layoutConstraints = nil;
    }
    
    [self removeFormFieldControllers];
    [self.scrollView removeFromSuperview];
    self.scrollView = nil;

    [self setupUI];
    [self setupConstraints];
    self.scrollView.delegate = self;
}

- (void)removeFormFieldControllers {
    if (self.cardHolderNameField) {
        [self.cardHolderNameField willMoveToParentViewController:nil];
        [self.cardHolderNameField.view removeFromSuperview];
        [self.cardHolderNameField removeFromParentViewController];
        self.cardHolderNameField = nil;
    }
    
    if (self.cardNumberField) {
        [self.cardNumberField willMoveToParentViewController:nil];
        [self.cardNumberField.view removeFromSuperview];
        [self.cardNumberField removeFromParentViewController];
        self.cardNumberField = nil;
    }
    
    if (self.cvcField) {
        [self.cvcField willMoveToParentViewController:nil];
        [self.cvcField.view removeFromSuperview];
        [self.cvcField removeFromParentViewController];
        self.cvcField = nil;
    }
    
    if (self.expirationDateField) {
        [self.expirationDateField willMoveToParentViewController:nil];
        [self.expirationDateField.view removeFromSuperview];
        [self.expirationDateField removeFromParentViewController];
        self.expirationDateField = nil;
    }
}

- (void)setupUI {
    // Scroll View
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.accessibilityIdentifier = @"custom-form-scroll-view";
    [self.view addSubview:self.scrollView];
    
    // Content View
    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];
    
    // Title Label
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"Custom Payment Form";
    self.titleLabel.font = [ThemeHelper screenTitleFont];
    self.titleLabel.textColor = [ThemeHelper textColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.accessibilityIdentifier = @"customFormTitle";
    [self.contentView addSubview:self.titleLabel];
    
    // Description Label
    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = @"This demonstrates a custom form built at the application level using headless UI components from the SDK.";
    self.descriptionLabel.font = [ThemeHelper screenBodyFont];
    self.descriptionLabel.textColor = [ThemeHelper textColor];
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.descriptionLabel];
    
    // Components Container
    self.componentsContainer = [self createInfoContainerWithTitle:@"Form Components:" 
                                                          items:@[@"• Card Holder Name: SPLTextField with .fullName type", @"• Card Number: SPLTextField with .cardNumber type", @"• CVC: SPLTextField with .cvc type", @"• Expiry Date: SPLTextField with .expirationDate type"]
                                                          backgroundColor:[ThemeHelper primaryColor]];
    
    // Config Container
    self.configContainer = [self createConfigContainer];
    
    // Form Container
    self.formContainer = [self createFormContainer];
    
    // Save Card Checkbox Container
    self.checkboxContainer = [[UIView alloc] init];
    self.checkboxContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.checkboxContainer];
    
    // Checkbox Button
    self.saveCardCheckbox = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.saveCardCheckbox setImage:[UIImage systemImageNamed:@"square"] forState:UIControlStateNormal];
    [self.saveCardCheckbox setImage:[UIImage systemImageNamed:@"checkmark.square.fill"] forState:UIControlStateSelected];
    self.saveCardCheckbox.tintColor = [UIColor systemGrayColor];
    self.saveCardCheckbox.selected = self.shouldRetain;
    [self.saveCardCheckbox addTarget:self action:@selector(toggleSaveCard:) forControlEvents:UIControlEventTouchUpInside];
    self.saveCardCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    self.saveCardCheckbox.accessibilityIdentifier = @"custom-form-save-card-checkbox";
    [self.checkboxContainer addSubview:self.saveCardCheckbox];
    
    // Save Card Label
    self.saveCardLabel = [[UILabel alloc] init];
    self.saveCardLabel.text = @"Save card for future payments";
    self.saveCardLabel.font = [ThemeHelper bodyFont];
    self.saveCardLabel.textColor = [ThemeHelper textColor];
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
        
        [self.saveCardLabel.leadingAnchor constraintEqualToAnchor:self.saveCardCheckbox.trailingAnchor constant:[ThemeHelper spacingSM]],
        [self.saveCardLabel.centerYAnchor constraintEqualToAnchor:self.checkboxContainer.centerYAnchor],
        [self.saveCardLabel.trailingAnchor constraintEqualToAnchor:self.checkboxContainer.trailingAnchor],
        
        [self.checkboxContainer.heightAnchor constraintEqualToConstant:32]
    ]];
    
    // Pay Button
    self.payButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
    self.payButton.titleLabel.font = [ThemeHelper buttonFont];
    self.payButton.backgroundColor = [ThemeHelper primaryColor];
    [self.payButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.payButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.payButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.payButton.accessibilityIdentifier = @"customFormPayButton";
    [self.payButton addTarget:self action:@selector(payButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.payButton];
    
    // Result Container (will be set up in setupResultContainer)
    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.hidden = YES;
    self.resultContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.resultContainer];
    
    // Error Container (will be set up in setupErrorMessageView)
    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.hidden = YES;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.numberOfLines = 0;
    [self.contentView addSubview:self.errorLabel];
    
    // Loading Indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.color = [ThemeHelper textColor];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];
}

- (UIView *)createInfoContainerWithTitle:(NSString *)title items:(NSArray<NSString *> *)items backgroundColor:(UIColor *)backgroundColor {
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
    titleLabel.text = @"Configuration Options:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:titleLabel];
    
    // Allow Blank Name Switch
    UILabel *blankNameLabel = [[UILabel alloc] init];
    blankNameLabel.text = @"Allow Blank Name";
    blankNameLabel.font = [ThemeHelper screenBodyFont];
    blankNameLabel.textColor = [ThemeHelper textColor];
    blankNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:blankNameLabel];
    
    self.allowBlankNameSwitch = [[UISwitch alloc] init];
    self.allowBlankNameSwitch.onTintColor = [ThemeHelper primaryColor];
    self.allowBlankNameSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowBlankNameSwitch.accessibilityIdentifier = @"customFormAllowBlankNameToggle";
    [container addSubview:self.allowBlankNameSwitch];
    [self.allowBlankNameSwitch setOn:self.allowBlankName];
    [self.allowBlankNameSwitch addTarget:self action:@selector(toggleAllowBlankName) forControlEvents:UIControlEventValueChanged];
    
    // Allow Expired Date Switch
    UILabel *expiredDateLabel = [[UILabel alloc] init];
    expiredDateLabel.text = @"Allow Expired Date";
    expiredDateLabel.font = [ThemeHelper screenBodyFont];
    expiredDateLabel.textColor = [ThemeHelper textColor];
    expiredDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:expiredDateLabel];
    
    self.allowExpiredDateSwitch = [[UISwitch alloc] init];
    self.allowExpiredDateSwitch.onTintColor = [ThemeHelper primaryColor];
    self.allowExpiredDateSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowExpiredDateSwitch.accessibilityIdentifier = @"customFormAllowExpiredDateToggle";
    [container addSubview:self.allowExpiredDateSwitch];
    [self.allowExpiredDateSwitch setOn:self.allowExpiredDate];
    [self.allowExpiredDateSwitch addTarget:self action:@selector(toggleExpiryDate) forControlEvents:UIControlEventValueChanged];
    
    // Allow Blank Date Switch
    UILabel *blankDateLabel = [[UILabel alloc] init];
    blankDateLabel.text = @"Allow Blank Date";
    blankDateLabel.font = [ThemeHelper screenBodyFont];
    blankDateLabel.textColor = [ThemeHelper textColor];
    blankDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:blankDateLabel];
    
    self.allowBlankDateSwitch = [[UISwitch alloc] init];
    self.allowBlankDateSwitch.onTintColor = [ThemeHelper primaryColor];
    self.allowBlankDateSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowBlankDateSwitch.accessibilityIdentifier = @"customFormAllowBlankDateToggle";
    [container addSubview:self.allowBlankDateSwitch];
    [self.allowBlankDateSwitch setOn:self.allowBlankDate];
    [self.allowBlankDateSwitch addTarget:self action:@selector(toggleAllowBlankDate) forControlEvents:UIControlEventValueChanged];
    
    // Year Format Segmented Control
    UILabel *yearFormatLabel = [[UILabel alloc] init];
    yearFormatLabel.text = @"Year Format:";
    yearFormatLabel.font = [ThemeHelper screenBodyFont];
    yearFormatLabel.textColor = [ThemeHelper textColor];
    yearFormatLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:yearFormatLabel];
    
    self.yearFormatSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"YY", @"YYYY"]];
    self.yearFormatSegmentedControl.selectedSegmentIndex = 1; // Default to 4-digit
    self.yearFormatSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.yearFormatSegmentedControl.accessibilityIdentifier = @"customFormYearFormatSegmentedControl";
    [self.yearFormatSegmentedControl addTarget:self action:@selector(yearFormatChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.yearFormatSegmentedControl];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [blankNameLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [blankNameLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [blankNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.allowBlankNameSwitch.leadingAnchor constant:-[ThemeHelper spacingSM]],
        [blankNameLabel.centerYAnchor constraintEqualToAnchor:self.allowBlankNameSwitch.centerYAnchor],
        
        [self.allowBlankNameSwitch.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowBlankNameSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [expiredDateLabel.topAnchor constraintEqualToAnchor:blankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [expiredDateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [expiredDateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.allowExpiredDateSwitch.leadingAnchor constant:-[ThemeHelper spacingSM]],
        [expiredDateLabel.centerYAnchor constraintEqualToAnchor:self.allowExpiredDateSwitch.centerYAnchor],
        
        [self.allowExpiredDateSwitch.topAnchor constraintEqualToAnchor:blankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowExpiredDateSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [blankDateLabel.topAnchor constraintEqualToAnchor:expiredDateLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [blankDateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [blankDateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.allowBlankDateSwitch.leadingAnchor constant:-[ThemeHelper spacingSM]],
        [blankDateLabel.centerYAnchor constraintEqualToAnchor:self.allowBlankDateSwitch.centerYAnchor],
        
        [self.allowBlankDateSwitch.topAnchor constraintEqualToAnchor:expiredDateLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowBlankDateSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        
        [yearFormatLabel.topAnchor constraintEqualToAnchor:self.allowBlankDateSwitch.bottomAnchor constant:[ThemeHelper spacingMD]],
        [yearFormatLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [yearFormatLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.yearFormatSegmentedControl.leadingAnchor constant:-[ThemeHelper spacingSM]],
        [yearFormatLabel.centerYAnchor constraintEqualToAnchor:self.yearFormatSegmentedControl.centerYAnchor],
        
        [self.yearFormatSegmentedControl.topAnchor constraintEqualToAnchor:self.allowBlankDateSwitch.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.yearFormatSegmentedControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.yearFormatSegmentedControl.widthAnchor constraintEqualToConstant:200],
        [self.yearFormatSegmentedControl.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    return container;
}

- (void)toggleAllowBlankName {
    self.allowBlankName = self.allowBlankNameSwitch.isOn;
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankName value:self.allowBlankNameSwitch.isOn];
    [self recreateCardHolderNameFieldInContainer];
    [self updatePayButtonState];
}

- (void)toggleExpiryDate {
    self.allowExpiredDate = self.allowExpiredDateSwitch.isOn;
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowExpiredDate value:self.allowExpiredDateSwitch.isOn];
}

- (void)toggleAllowBlankDate {
    self.allowBlankDate = self.allowBlankDateSwitch.isOn;
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankDate value:self.allowBlankDateSwitch.isOn];
    
    // Recreate the expiration date field with the new isRequired value
    if (self.cvcField.view) {
        [self createExpirationDateFieldInContainer:self.formContainer belowView:self.cvcField.view];
    }
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
    
    // Card Holder Name Field
    self.cardHolderNameField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeFullName title:@"Card Holder Name" isRequired:!self.allowBlankName placeholder:nil keyboardType:UIKeyboardTypeDefault textContentType:UITextContentTypeName onValidationChange:^(BOOL valid) {
        self.cardHolderNameIsValid = valid;
        [self updatePayButtonState];
    } onSubmit:^{
        (void)[self.cardNumberField becomeFirstResponder];
    } submitLabel:SpreedlySubmitLabelNext onFocus: nil];
    
    [self addChildViewController:self.cardHolderNameField];
    self.cardHolderNameField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cardHolderNameField.view];
    [self.cardHolderNameField didMoveToParentViewController:self];
    
    // Card Number Field
    self.cardNumberField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeCardNumber title:@"Card Number" isRequired:YES placeholder:nil keyboardType:UIKeyboardTypeNumberPad textContentType:UITextContentTypeCreditCardNumber onValidationChange:^(BOOL valid) {
        self.cardNumberIsValid = valid;
        [self updatePayButtonState];
    } onSubmit:^{
        (void)[self.cvcField becomeFirstResponder];
    } submitLabel:SpreedlySubmitLabelNext onFocus: nil];
    
    [self addChildViewController:self.cardNumberField];
    self.cardNumberField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cardNumberField.view];
    [self.cardNumberField didMoveToParentViewController:self];
    
    if (@available(iOS 17.0, *)) {
        self.cvcField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeCvc title:@"Security Code (CVC)" isRequired:YES placeholder:nil keyboardType:UIKeyboardTypeNumberPad textContentType:UITextContentTypeCreditCardSecurityCode onValidationChange:^(BOOL valid) {
            self.cvcIsValid = valid;
            [self updatePayButtonState];
        } onSubmit:^{
            (void)[self.expirationDateField becomeFirstResponder];
        } submitLabel:SpreedlySubmitLabelNext onFocus:nil];
    } else {
        // Fallback on earlier versions
        self.cvcField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeCvc title:@"Security Code (CVC)" isRequired:YES placeholder:nil keyboardType:UIKeyboardTypeNumberPad textContentType:UITextContentTypeCreditCardNumber onValidationChange:^(BOOL valid) {
            self.cvcIsValid = valid;
            [self updatePayButtonState];
        } onSubmit:^{
            (void)[self.expirationDateField becomeFirstResponder];
        } submitLabel:SpreedlySubmitLabelNext onFocus:nil];
    }
    [self addChildViewController:self.cvcField];
    self.cvcField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cvcField.view];
    [self.cvcField didMoveToParentViewController:self];
    
    // Create expiration date field with current year format
    [self createExpirationDateFieldInContainer:container belowView:self.cvcField.view];
    
    // Setup constraints for form fields
    [NSLayoutConstraint activateConstraints:@[
        [self.cardHolderNameField.view.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [self.cardHolderNameField.view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.cardHolderNameField.view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.cardHolderNameField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        
        [self.cardNumberField.view.topAnchor constraintEqualToAnchor:self.cardHolderNameField.view.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.cardNumberField.view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.cardNumberField.view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.cardNumberField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        
        [self.cvcField.view.topAnchor constraintEqualToAnchor:self.cardNumberField.view.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.cvcField.view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.cvcField.view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.cvcField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
    ]];
    
    return container;
}

- (void)recreateCardHolderNameFieldInContainer {
    if (!self.formContainer || !self.cardNumberField.view) {
        return;
    }
    
    NSMutableArray<NSLayoutConstraint *> *constraintsToRemove = [NSMutableArray array];
    for (NSLayoutConstraint *constraint in self.formContainer.constraints) {
        if (constraint.firstItem == self.cardHolderNameField.view || constraint.secondItem == self.cardHolderNameField.view) {
            [constraintsToRemove addObject:constraint];
            continue;
        }
        if (constraint.firstItem == self.cardNumberField.view && constraint.firstAttribute == NSLayoutAttributeTop) {
            [constraintsToRemove addObject:constraint];
        }
    }
    if (constraintsToRemove.count > 0) {
        [NSLayoutConstraint deactivateConstraints:constraintsToRemove];
    }
    
    if (self.cardHolderNameField) {
        [self.cardHolderNameField willMoveToParentViewController:nil];
        [self.cardHolderNameField.view removeFromSuperview];
        [self.cardHolderNameField removeFromParentViewController];
        self.cardHolderNameField = nil;
    }
    
    self.cardHolderNameField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeFullName title:@"Card Holder Name" isRequired:!self.allowBlankName placeholder:nil keyboardType:UIKeyboardTypeDefault textContentType:UITextContentTypeName onValidationChange:^(BOOL valid) {
        self.cardHolderNameIsValid = valid;
        [self updatePayButtonState];
    } onSubmit:^{
        (void)[self.cardNumberField becomeFirstResponder];
    } submitLabel:SpreedlySubmitLabelNext onFocus:nil];
    
    [self addChildViewController:self.cardHolderNameField];
    self.cardHolderNameField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.formContainer addSubview:self.cardHolderNameField.view];
    [self.cardHolderNameField didMoveToParentViewController:self];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.cardHolderNameField.view.topAnchor constraintEqualToAnchor:self.formContainer.topAnchor constant:[ThemeHelper spacingMD]],
        [self.cardHolderNameField.view.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.cardHolderNameField.view.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.cardHolderNameField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        
        [self.cardNumberField.view.topAnchor constraintEqualToAnchor:self.cardHolderNameField.view.bottomAnchor constant:[ThemeHelper spacingMD]]
    ]];
}

- (void)createExpirationDateFieldInContainer:(UIView *)container belowView:(UIView *)aboveView {
    // Remove existing expiration date field if it exists
    if (self.expirationDateField) {
        NSMutableArray<NSLayoutConstraint *> *constraintsToRemove = [NSMutableArray array];
        for (NSLayoutConstraint *constraint in container.constraints) {
            if (constraint.firstItem == self.expirationDateField.view || constraint.secondItem == self.expirationDateField.view) {
                [constraintsToRemove addObject:constraint];
            }
        }
        if (constraintsToRemove.count > 0) {
            [NSLayoutConstraint deactivateConstraints:constraintsToRemove];
        }
        
        [self.expirationDateField willMoveToParentViewController:nil];
        [self.expirationDateField.view removeFromSuperview];
        [self.expirationDateField removeFromParentViewController];
    }
    
//    // Determine year format based on segmented control
//    YearFormat yearFormat = (self.yearFormatSegmentedControl.selectedSegmentIndex == 0) ?
//        YearFormatTwoDigit : YearFormatFourDigit;
    
    // Make isRequired dynamic based on allowBlankDate
    // allowBlankDate=true means the date is optional, so required should be false.
    BOOL isRequired = !self.allowBlankDate;
    
    YearFormat yearFormat = (self.yearFormatSegmentedControl.selectedSegmentIndex == 0) ?
        YearFormatTwoDigit : YearFormatFourDigit;
    
    if (@available(iOS 15.0, *)) {
        self.expirationDateField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeExpirationDate title:@"Expiry Date" isRequired:isRequired placeholder:nil keyboardType:UIKeyboardTypeNumberPad textContentType:UITextContentTypeDateTime onValidationChange:^(BOOL valid) {
            self.expirationDateIsValid = valid;
            [self updatePayButtonState];
        } onSubmit:^{
            [self payButtonTapped];
        } submitLabel:SpreedlySubmitLabelDone onFocus:nil];
    } else {
        // Fallback on earlier versions
        self.expirationDateField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeExpirationDate title:@"Expiry Date" isRequired:isRequired placeholder:nil keyboardType:UIKeyboardTypeNumberPad textContentType:UITextContentTypePostalCode onValidationChange:^(BOOL valid) {
            self.expirationDateIsValid = valid;
            [self updatePayButtonState];
        } onSubmit:^{
            [self payButtonTapped];
        } submitLabel:SpreedlySubmitLabelDone onFocus:nil];
    }
    self.expirationDateField.yearFormat = yearFormat;
    [self addChildViewController:self.expirationDateField];
    self.expirationDateField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.expirationDateField.view];
    [self.expirationDateField didMoveToParentViewController:self];
    
    // If this is the initial creation (label is provided), set up the constraints
    if (aboveView) {
        [NSLayoutConstraint activateConstraints:@[
            [self.expirationDateField.view.topAnchor constraintEqualToAnchor:aboveView.bottomAnchor constant:[ThemeHelper spacingMD]],
            [self.expirationDateField.view.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
            [self.expirationDateField.view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
            [self.expirationDateField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60],
            [self.expirationDateField.view.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-16]
        ]];
    }
}

- (void)yearFormatChanged:(UISegmentedControl *)sender {
    // Recreate the expiration date field with the new year format
    if (self.cvcField.view) {
        [self createExpirationDateFieldInContainer:self.formContainer belowView:self.cvcField.view];
    }
}

- (void)setupConstraints {
    self.layoutConstraints = @[
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
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        
        // Description Label
        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        
        // Components Container
        [self.componentsContainer.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.componentsContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.componentsContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        
        // Config Container
        [self.configContainer.topAnchor constraintEqualToAnchor:self.componentsContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.configContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.configContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        
        // Form Container
        [self.formContainer.topAnchor constraintEqualToAnchor:self.configContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.formContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.formContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        
        // Checkbox Container
        [self.checkboxContainer.topAnchor constraintEqualToAnchor:self.formContainer.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.checkboxContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.checkboxContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        
        // Pay Button
        [self.payButton.topAnchor constraintEqualToAnchor:self.checkboxContainer.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.payButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.payButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        [self.payButton.heightAnchor constraintEqualToConstant:44],
        
        // Result Container
        [self.resultContainer.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        [self.resultContainer.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],
        
        // Error Label
        [self.errorLabel.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        [self.errorLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],
        
        // Loading Indicator
        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ];
    
    [NSLayoutConstraint activateConstraints:self.layoutConstraints];
}

- (void)updatePayButtonState {
    BOOL isFormValid = [self isFormValid];
    self.payButton.enabled = isFormValid && !self.isLoading;
    self.payButton.backgroundColor = isFormValid && !self.isLoading ? [ThemeHelper primaryColor] : [[ThemeHelper primaryColor] colorWithAlphaComponent:0.6];
}

- (BOOL)isFormValid {
    // Name validation: only required if allowBlankName is false
    BOOL nameValid = self.allowBlankNameSwitch.isOn ? YES : self.cardHolderNameIsValid;
    
    // Card number and CVC validation: always required
    BOOL cardValid = self.cardNumberIsValid && self.cvcIsValid;
    
    // Expiration date validation: always required for format, but allowExpiredDate affects validation rules
    BOOL expirationValid = self.expirationDateIsValid;
    
    return nameValid && cardValid && expirationValid;
}

- (void)toggleSaveCard:(id)sender {
    self.shouldRetain = !self.shouldRetain;
    self.saveCardCheckbox.selected = self.shouldRetain;
    self.saveCardCheckbox.tintColor = self.shouldRetain ? [ThemeHelper primaryColor] : [ThemeHelper textSecondaryColor];
}

- (void)payButtonTapped {
    self.isLoading = YES;
    [self.loadingIndicator startAnimating];
    [self.payButton setTitle:@"Processing..." forState:UIControlStateNormal];
    self.errorMessage = nil;
    self.paymentResult = nil;
    [self updatePayButtonState];
    
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
                self.errorMessage = error.localizedDescription;
                [self updateUI];
                [self updatePayButtonState];
            });
        }
    }];
}

- (void)createCreditCardPayment {
    // Capture UI values on the main thread before making the API call
    dispatch_async(dispatch_get_main_queue(), ^{
        // Create additional fields - SPLTextFieldViewController with FormFieldTypeFullName
        // automatically stores the value in the secure container, so we don't need to
        // manually extract it. Pass empty dictionary and let the SDK handle it.
        NSDictionary *additionalFields = @{};
        
        // Create metadata
        NSDictionary *metadata = @{};
        
        // Call Spreedly createCreditCard (synchronous, returns PaymentProcessingResult)
        Spreedly *spreedly = [Spreedly shared];
        PaymentProcessingResult *processingResult = [spreedly createCreditCardObjCWithAdditionalFields: additionalFields metadata: metadata];
        
        // Handle immediate processing result
        if (processingResult.isValidationFailed) {
            self.isLoading = NO;
            [self.loadingIndicator stopAnimating];
            [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
            self.errorMessage = [processingResult getDescription];
            self.paymentResult = nil;
            [self updateUI];
            [self updatePayButtonState];
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
        self.errorLabel.hidden = YES;
        
        // Ensure the result container is fully visible
        [self ensureResultContainerVisible];
    } else if (self.errorMessage) {
        [self setupErrorMessageView];
        self.errorLabel.hidden = NO;
        self.resultContainer.hidden = YES;
    } else {
        self.resultContainer.hidden = YES;
        self.errorLabel.hidden = YES;
    }
}

- (void)setupErrorMessageView {
    // Remove existing subviews if errorLabel was converted to a container
    if ([self.errorLabel isKindOfClass:[UIView class]] && self.errorLabel.subviews.count > 0) {
        for (UIView *subview in self.errorLabel.subviews) {
            [subview removeFromSuperview];
        }
    }
    
    // Create container view for error message
    UIView *errorContainer = [[UIView alloc] init];
    errorContainer.backgroundColor = [[ThemeHelper errorColor] colorWithAlphaComponent:0.1];
    errorContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    [ThemeHelper applySmallShadowToView:errorContainer];
    errorContainer.translatesAutoresizingMaskIntoConstraints = NO;
    errorContainer.hidden = self.errorLabel.hidden;
    
    // Create vertical stack for content
    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = [ThemeHelper spacingSM];
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [errorContainer addSubview:contentStack];
    
    // Create horizontal stack for icon and title
    UIStackView *headerStack = [[UIStackView alloc] init];
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.spacing = [ThemeHelper spacingSM];
    headerStack.alignment = UIStackViewAlignmentCenter;
    [contentStack addArrangedSubview:headerStack];
    
    // Error icon
    UIImageView *errorIcon = [[UIImageView alloc] init];
    errorIcon.image = [UIImage systemImageNamed:@"exclamationmark.triangle.fill"];
    errorIcon.tintColor = [ThemeHelper errorColor];
    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithFont:[UIFont preferredFontForTextStyle:UIFontTextStyleTitle2]];
    errorIcon.preferredSymbolConfiguration = iconConfig;
    [headerStack addArrangedSubview:errorIcon];
    
    // Error title
    UILabel *errorTitle = [[UILabel alloc] init];
    errorTitle.text = @"Error";
    errorTitle.font = [ThemeHelper subtitleFont];
    errorTitle.textColor = [ThemeHelper errorColor];
    [headerStack addArrangedSubview:errorTitle];
    
    // Error message
    UILabel *errorMessageLabel = [[UILabel alloc] init];
    errorMessageLabel.text = self.errorMessage;
    errorMessageLabel.font = [ThemeHelper screenBodyFont];
    errorMessageLabel.textColor = [ThemeHelper textColor];
    errorMessageLabel.numberOfLines = 0;
    [contentStack addArrangedSubview:errorMessageLabel];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        [contentStack.topAnchor constraintEqualToAnchor:errorContainer.topAnchor constant:[ThemeHelper spacingMD]],
        [contentStack.leadingAnchor constraintEqualToAnchor:errorContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
        [contentStack.trailingAnchor constraintEqualToAnchor:errorContainer.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [contentStack.bottomAnchor constraintEqualToAnchor:errorContainer.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    // Replace errorLabel with container
    if (self.errorLabel.superview) {
        // Store the constraints
        NSArray *constraints = [self.contentView.constraints filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSLayoutConstraint *constraint, NSDictionary *bindings) {
            return (constraint.firstItem == self.errorLabel || constraint.secondItem == self.errorLabel);
        }]];
        
        [self.errorLabel removeFromSuperview];
        
        // Add container in same position
        [self.contentView addSubview:errorContainer];
        
        // Reapply constraints with container
        for (NSLayoutConstraint *constraint in constraints) {
            id firstItem = (constraint.firstItem == self.errorLabel) ? errorContainer : constraint.firstItem;
            id secondItem = (constraint.secondItem == self.errorLabel) ? errorContainer : constraint.secondItem;
            
            NSLayoutConstraint *newConstraint = [NSLayoutConstraint constraintWithItem:firstItem
                                                                               attribute:constraint.firstAttribute
                                                                               relatedBy:constraint.relation
                                                                                  toItem:secondItem
                                                                               attribute:constraint.secondAttribute
                                                                              multiplier:constraint.multiplier
                                                                                constant:constraint.constant];
            [self.contentView addConstraint:newConstraint];
        }
    } else {
        [self.contentView addSubview:errorContainer];
    }
    
    // Update errorLabel reference
    self.errorLabel = (UILabel *)errorContainer;
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
    
    // Style the container
    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    [ThemeHelper applySmallShadowToView:self.resultContainer];
    
    // Create horizontal stack for icon and title
    UIStackView *headerStack = [[UIStackView alloc] init];
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.spacing = [ThemeHelper spacingSM];
    headerStack.alignment = UIStackViewAlignmentCenter;
    headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultContainer addSubview:headerStack];
    
    // Success icon
    UIImageView *successIcon = [[UIImageView alloc] init];
    successIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    successIcon.tintColor = [ThemeHelper successColor];
    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithFont:[UIFont preferredFontForTextStyle:UIFontTextStyleTitle2]];
    successIcon.preferredSymbolConfiguration = iconConfig;
    [headerStack addArrangedSubview:successIcon];
    
    // Success title
    UILabel *successTitle = [[UILabel alloc] init];
    successTitle.text = @"Payment Successful!";
    successTitle.font = [ThemeHelper subtitleFont];
    successTitle.textColor = [ThemeHelper successColor];
    [headerStack addArrangedSubview:successTitle];
    
    // Transaction token
    UILabel *transactionLabel = nil;
    if (self.paymentResult.token) {
        transactionLabel = [[UILabel alloc] init];
        NSString *masked = [Spreedly maskedToken:self.paymentResult.token];
        transactionLabel.text = [NSString stringWithFormat:@"Transaction Token: %@", masked];
        transactionLabel.font = [ThemeHelper captionFont];
        transactionLabel.textColor = [ThemeHelper textSecondaryColor];
        transactionLabel.numberOfLines = 0;
        transactionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.resultContainer addSubview:transactionLabel];
    }
    
    // Setup constraints
    NSMutableArray *constraints = [NSMutableArray array];
    
    [constraints addObjectsFromArray:@[
        [headerStack.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:[ThemeHelper spacingMD]],
        [headerStack.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
        [headerStack.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    
    UIView *lastView = headerStack;
    
    if (transactionLabel) {
        [constraints addObjectsFromArray:@[
            [transactionLabel.topAnchor constraintEqualToAnchor:lastView.bottomAnchor constant:[ThemeHelper spacingSM]],
            [transactionLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
            [transactionLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]]
        ]];
        lastView = transactionLabel;
    }
    
    [constraints addObject:[lastView.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-[ThemeHelper spacingMD]]];
    
    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[Spreedly shared] reset];
    // unregister for keyboard notifications while not visible.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                             name:UIKeyboardWillShowNotification
                                           object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                             name:UIKeyboardWillHideNotification
                                           object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // Clean up child view controllers
    if (self.cardHolderNameField) {
        [self.cardHolderNameField willMoveToParentViewController:nil];
        [self.cardHolderNameField.view removeFromSuperview];
        [self.cardHolderNameField removeFromParentViewController];
    }
    
    if (self.cardNumberField) {
        [self.cardNumberField willMoveToParentViewController:nil];
        [self.cardNumberField.view removeFromSuperview];
        [self.cardNumberField removeFromParentViewController];
    }
    
    if (self.cvcField) {
        [self.cvcField willMoveToParentViewController:nil];
        [self.cvcField.view removeFromSuperview];
        [self.cvcField removeFromParentViewController];
    }
    
    if (self.expirationDateField) {
        [self.expirationDateField willMoveToParentViewController:nil];
        [self.expirationDateField.view removeFromSuperview];
        [self.expirationDateField removeFromParentViewController];
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

-(void)keyboardWillShow {
    // Animate the current view out of the way
    if (self.view.frame.origin.y >= 0)
    {
        [self setViewMovedUp:YES];
    }
    else if (self.view.frame.origin.y < 0)
    {
        [self setViewMovedUp:NO];
    }
}

-(void)keyboardWillHide {
    if (self.view.frame.origin.y >= 0)
    {
        [self setViewMovedUp:YES];
    }
    else if (self.view.frame.origin.y < 0)
    {
        [self setViewMovedUp:NO];
    }
}

-(void)textFieldDidBeginEditing:(UITextField *)sender
{
    //move the main view, so that the keyboard does not hide it.
    if  (self.view.frame.origin.y >= 0)
    {
        [self setViewMovedUp:YES];
    }
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
                                         selector:@selector(keyboardWillShow)
                                             name:UIKeyboardWillShowNotification
                                           object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(keyboardWillHide)
                                             name:UIKeyboardWillHideNotification
                                           object:nil];
    
    // Focus the first field (card holder name) when view appears
    (void)[self.cardHolderNameField becomeFirstResponder];
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
            
            // Handle card retention preference (save card for future payments)
            if (self.shouldRetain && result.token) {
                [self retainPaymentMethodWithToken:result.token];
            }
            
            // Reset checkbox state after successful payment
            self.shouldRetain = NO;
            self.saveCardCheckbox.selected = NO;
            self.saveCardCheckbox.tintColor = [UIColor systemGrayColor];
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

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // Card holder name field is now SPLTextFieldViewController, so this delegate method
    // is no longer needed for that field. It handles its own return key behavior.
    return NO;
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
