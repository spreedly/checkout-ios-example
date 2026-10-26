//
//  CustomFormViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  Created by Vinay Naikade on 12/08/25.
//

#import "CustomFormViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <objc/runtime.h>
#import "SpreedlyConfigManager.h"
#import "RetainPaymentMethodAPIClient.h"
#import "RetainPaymentMethodModels.h"
#import "ThemeHelper.h"
#import "DemoCustomValidationRecipes.h"
#import "AdditionalFieldCataloguePanel.h"

@interface CustomFormViewController () <UIScrollViewDelegate, SpreedlyPaymentDelegate, FieldTextChangeListener>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UILabel *activeCustomRulesLabel;
@property (nonatomic, strong) UIView *customValidationContainer;
@property (nonatomic, strong) UIButton *fullNameRuleButton;
@property (nonatomic, assign) DemoCustomValidationKind fullNameCustomRule;
@property (nonatomic, strong) AdditionalFieldCataloguePanel *cataloguePanel;
@property (nonatomic, strong) UIStackView *catalogueHostedStack;
@property (nonatomic, strong) NSMutableArray<SPLTextFieldViewController *> *catalogueHostedFields;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *additionalFieldValidity;
@property (nonatomic, assign) NSInteger previousCustomValidationErrorCount;
@property (nonatomic, strong) UIView *componentsContainer;
@property (nonatomic, strong) UIView *configContainer;
@property (nonatomic, strong) UIView *formContainer;
@property (nonatomic, strong) UIView *checkboxContainer;
@property (nonatomic, strong) UIButton *payButton;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UILabel *fieldStateInspectorTitleLabel;
@property (nonatomic, strong) UILabel *fieldInspectorCaptionLabel;
@property (nonatomic, strong) UILabel *wiringLabel;
@property (nonatomic, strong) UILabel *lastEventLabel;
@property (nonatomic, strong) UILabel *eventLogLabel;
@property (nonatomic, strong) UILabel *fieldStatusLabel;
@property (nonatomic, strong) UILabel *fieldStatusHintLabel;
@property (nonatomic, copy) NSString *lastCardInspectorBody;
@property (nonatomic, copy) NSString *lastCvcInspectorBody;
@property (nonatomic, strong) NSMutableArray<NSString *> *hostedFieldEventLog;
@property (nonatomic, strong) UILabel *aggregateValidationLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *layoutConstraints;

@property (nonatomic, strong) SPLTextFieldViewController *cardHolderNameField;
@property (nonatomic, strong) SPLTextFieldViewController *cardNumberField;
@property (nonatomic, strong) SPLTextFieldViewController *cvcField;
@property (nonatomic, strong) SPLTextFieldViewController *expirationDateField;

@property (nonatomic, strong) UISwitch *allowBlankNameSwitch;
@property (nonatomic, strong) UISwitch *allowExpiredDateSwitch;
@property (nonatomic, strong) UISwitch *allowBlankDateSwitch;
@property (nonatomic, strong) UISwitch *enableAutofillSwitch;
@property (nonatomic, strong) UISwitch *demoHostedWinsConflictSwitch;
@property (nonatomic, strong) UISegmentedControl *panFormatSegmentedControl;
@property (nonatomic, strong) UIButton *resetPaymentStateButton;
@property (nonatomic, strong) UIButton *toggleMaskButton;
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

- (NSString *)formFieldTypeDisplayName:(FormFieldType)type;
- (NSString *)hostedFieldEventDescription:(HostedFieldEventType)eventType;
- (NSString *)logYesNo:(BOOL)value;
- (NSString *)cardNumberFormatLabelForRawValue:(NSInteger)rawValue;
- (NSString *)inspectorBodyForCardState:(HostedFieldState *)state;
- (NSString *)inspectorBodyForCvcState:(HostedFieldState *)state;
- (void)refreshCombinedFieldInspectorText;
- (void)refreshAggregateValidationReadout;
- (void)appendHostedFieldEventLog:(HostedFieldState *)state;
- (void)logHostedFieldStateChange:(HostedFieldState *)state;
- (void)attachHostedFieldCallbacksToField:(SPLTextFieldViewController *)field;
- (NSString *)merchantPanAssetNameForSchemeRawValue:(NSString *)schemeRaw;
- (UIView *)merchantPanTrailingBrandViewForSchemeRawValue:(NSString *)schemeRaw;

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
    if (self.panFormatSegmentedControl) {
        self.panFormatSegmentedControl.selectedSegmentIndex = (NSInteger)[Spreedly shared].hostedCardDisplayCardNumberFormatRawValue;
    }
    // Set scroll view delegate
    self.scrollView.delegate = self;
    
    // Set up payment result delegate
    [Spreedly.shared setPaymentDelegate:self];
    self.fullNameCustomRule = DemoCustomValidationKindNone;
    self.additionalFieldValidity = [NSMutableDictionary dictionary];
    self.catalogueHostedFields = [NSMutableArray array];
    [self applyCustomValidationSelections];
    
    if (![Spreedly isDeviceTrusted]) {
        self.errorMessage = Spreedly.initializationError.message ?: @"SDK blocked by security check";
        [self updateUI];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    (void)[self.cardHolderNameField becomeFirstResponder];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self refreshAggregateValidationReadout];
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
    self.descriptionLabel.text = @"Headless SPLTextField form. Use Optional address groups or Show Additional Fields Configuration to mount extra fields. Full name Custom rule (and per-field rules in the catalogue) run on blur + Pay.";
    self.descriptionLabel.font = [ThemeHelper screenBodyFont];
    self.descriptionLabel.textColor = [ThemeHelper textColor];
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.descriptionLabel];

    self.activeCustomRulesLabel = [[UILabel alloc] init];
    self.activeCustomRulesLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.activeCustomRulesLabel.textColor = [UIColor secondaryLabelColor];
    self.activeCustomRulesLabel.numberOfLines = 0;
    self.activeCustomRulesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.activeCustomRulesLabel.accessibilityIdentifier = @"customForm_activeCustomRules";
    [self.contentView addSubview:self.activeCustomRulesLabel];

    self.customValidationContainer = [self createCustomValidationContainer];
    [self.contentView addSubview:self.customValidationContainer];

    self.cataloguePanel = [[AdditionalFieldCataloguePanel alloc] initWithAccessibilityPrefix:@"customForm"
                                                                          leadingDetailViews:nil];
    self.cataloguePanel.hostViewController = self;
    __weak typeof(self) weakSelf = self;
    self.cataloguePanel.onCatalogueChanged = ^{
        [weakSelf reloadCatalogueHostedFields];
        [weakSelf applyCustomValidationSelections];
        [weakSelf updatePayButtonState];
    };
    [self.contentView addSubview:self.cataloguePanel];
    
    // Components Container
    self.componentsContainer = [self createInfoContainerWithTitle:@"Form Components:" 
                                                          items:@[@"• Card Holder Name: SPLTextField with .fullName type", @"• Card Number: SPLTextField with .cardNumber type", @"• CVC: SPLTextField with .cvc type", @"• Expiry Date: SPLTextField with .expirationDate type", @"• Optional catalogue fields mount below when enabled"]
                                                          backgroundColor:[ThemeHelper primaryColor]];
    
    // Config Container
    self.configContainer = [self createConfigContainer];
    
    self.fieldStateInspectorTitleLabel = [[UILabel alloc] init];
    self.fieldStateInspectorTitleLabel.text = @"Field state inspector";
    self.fieldStateInspectorTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.fieldStateInspectorTitleLabel.textColor = [ThemeHelper textColor];
    self.fieldStateInspectorTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fieldStateInspectorTitleLabel.accessibilityIdentifier = @"custom-form-field-state-inspector-title";
    [self.contentView addSubview:self.fieldStateInspectorTitleLabel];

    self.fieldInspectorCaptionLabel = [[UILabel alloc] init];
    self.fieldInspectorCaptionLabel.text = @"Updates from onFieldStateChange. Use snapshot fields — not hostedCardDisplayState in the callback.";
    self.fieldInspectorCaptionLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    self.fieldInspectorCaptionLabel.textColor = [UIColor secondaryLabelColor];
    self.fieldInspectorCaptionLabel.numberOfLines = 0;
    self.fieldInspectorCaptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.fieldInspectorCaptionLabel];

    self.wiringLabel = [[UILabel alloc] init];
    self.wiringLabel.text = @"Hosted fields: enableAutofill toggle; PAN + CVC follow setNumberFormat / toggleMask (iframe parity)";
    self.wiringLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    self.wiringLabel.textColor = [UIColor secondaryLabelColor];
    self.wiringLabel.numberOfLines = 0;
    self.wiringLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.wiringLabel.accessibilityIdentifier = @"custom-form-wiring-readout";
    [self.contentView addSubview:self.wiringLabel];

    self.lastEventLabel = [[UILabel alloc] init];
    self.lastEventLabel.text = @"Last event: —";
    self.lastEventLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.lastEventLabel.textColor = [UIColor secondaryLabelColor];
    self.lastEventLabel.numberOfLines = 0;
    self.lastEventLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.lastEventLabel.accessibilityIdentifier = @"custom-form-last-event-readout";
    [self.contentView addSubview:self.lastEventLabel];

    self.eventLogLabel = [[UILabel alloc] init];
    self.eventLogLabel.text = @"Event log (last 5)\n  (no events yet)";
    self.eventLogLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.eventLogLabel.textColor = [UIColor secondaryLabelColor];
    self.eventLogLabel.numberOfLines = 0;
    self.eventLogLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.eventLogLabel.accessibilityIdentifier = @"custom-form-event-log";
    [self.contentView addSubview:self.eventLogLabel];

    self.hostedFieldEventLog = [NSMutableArray array];

    self.fieldStatusLabel = [[UILabel alloc] init];
    self.fieldStatusLabel.text = @"Card number\n  (waiting for input…)\n\nCVC\n  (waiting for input…)";
    self.fieldStatusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.fieldStatusLabel.textColor = [UIColor secondaryLabelColor];
    self.fieldStatusLabel.numberOfLines = 0;
    self.fieldStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fieldStatusLabel.accessibilityIdentifier = @"custom-form-field-state-inspector";
    [self.contentView addSubview:self.fieldStatusLabel];

    self.fieldStatusHintLabel = [[UILabel alloc] init];
    self.fieldStatusHintLabel.text = @"onChange: edit a field to see values (card/CVC stay opaque).";
    self.fieldStatusHintLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    self.fieldStatusHintLabel.textColor = [UIColor secondaryLabelColor];
    self.fieldStatusHintLabel.numberOfLines = 0;
    self.fieldStatusHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fieldStatusHintLabel.accessibilityIdentifier = @"custom-form-onchange-readout";
    [self.contentView addSubview:self.fieldStatusHintLabel];

    self.aggregateValidationLabel = [[UILabel alloc] init];
    self.aggregateValidationLabel.text = @"";
    self.aggregateValidationLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    self.aggregateValidationLabel.textColor = [UIColor secondaryLabelColor];
    self.aggregateValidationLabel.numberOfLines = 0;
    self.aggregateValidationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.aggregateValidationLabel.accessibilityIdentifier = @"custom-form-aggregate-validation-readout";
    [self.contentView addSubview:self.aggregateValidationLabel];
    
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

    UILabel *enableAutofillLabel = [[UILabel alloc] init];
    enableAutofillLabel.text = @"Enable autofill";
    enableAutofillLabel.font = [ThemeHelper screenBodyFont];
    enableAutofillLabel.textColor = [ThemeHelper textColor];
    enableAutofillLabel.translatesAutoresizingMaskIntoConstraints = NO;
    enableAutofillLabel.accessibilityIdentifier = @"custom-form-enable-autofill-label";
    [container addSubview:enableAutofillLabel];

    self.enableAutofillSwitch = [[UISwitch alloc] init];
    self.enableAutofillSwitch.onTintColor = [ThemeHelper primaryColor];
    self.enableAutofillSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.enableAutofillSwitch.accessibilityIdentifier = @"custom-form-enable-autofill-toggle";
    self.enableAutofillSwitch.accessibilityHint = @"Toggle Wallet and edit-menu autofill on hosted fields";
    [self.enableAutofillSwitch setOn:YES];
    [self.enableAutofillSwitch addTarget:self action:@selector(enableAutofillToggled:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.enableAutofillSwitch];

    UILabel *enableAutofillHelpLabel = [[UILabel alloc] init];
    enableAutofillHelpLabel.text = @"Off clears Wallet hints and suppresses AutoFill on hosted fields.";
    enableAutofillHelpLabel.font = [ThemeHelper screenCaptionFont];
    enableAutofillHelpLabel.textColor = [ThemeHelper textSecondaryColor];
    enableAutofillHelpLabel.numberOfLines = 0;
    enableAutofillHelpLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:enableAutofillHelpLabel];

    UILabel *hostedWinsLabel = [[UILabel alloc] init];
    hostedWinsLabel.text = @"Demo: conflicting ZIP in additionalFields (hosted-wins)";
    hostedWinsLabel.font = [ThemeHelper screenBodyFont];
    hostedWinsLabel.textColor = [ThemeHelper textColor];
    hostedWinsLabel.numberOfLines = 0;
    hostedWinsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:hostedWinsLabel];

    self.demoHostedWinsConflictSwitch = [[UISwitch alloc] init];
    self.demoHostedWinsConflictSwitch.onTintColor = [ThemeHelper primaryColor];
    self.demoHostedWinsConflictSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.demoHostedWinsConflictSwitch.accessibilityIdentifier = @"customFormDemoHostedWinsConflictToggle";
    self.demoHostedWinsConflictSwitch.accessibilityHint = @"When on, Pay passes conflicting zip/city in additionalFields so mounted fields can win";
    [self.demoHostedWinsConflictSwitch setOn:NO];
    [container addSubview:self.demoHostedWinsConflictSwitch];

    UILabel *panFormatHelpLabel = [[UILabel alloc] init];
    panFormatHelpLabel.text = @"Pretty: grouped spaced digits (focus and blur). Plain: all digits visible. Masked: every digit * while typing. toggleMask() toggles plain ↔ masked (first tap from Pretty default → masked).";
    panFormatHelpLabel.font = [ThemeHelper screenBodyFont];
    panFormatHelpLabel.textColor = [ThemeHelper textColor];
    panFormatHelpLabel.numberOfLines = 0;
    panFormatHelpLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:panFormatHelpLabel];

    self.panFormatSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Pretty", @"Plain", @"Masked"]];
    self.panFormatSegmentedControl.selectedSegmentIndex = 0;
    self.panFormatSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.panFormatSegmentedControl.accessibilityIdentifier = @"custom-form-pan-format-segmented";
    [self.panFormatSegmentedControl addTarget:self action:@selector(panFormatChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.panFormatSegmentedControl];

    self.toggleMaskButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.toggleMaskButton setTitle:@"toggleMask()" forState:UIControlStateNormal];
    self.toggleMaskButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [self.toggleMaskButton setTitleColor:[ThemeHelper primaryColor] forState:UIControlStateNormal];
    self.toggleMaskButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.toggleMaskButton.accessibilityIdentifier = @"custom-form-toggle-mask-button";
    self.toggleMaskButton.accessibilityHint = @"Toggles Pretty masked ↔ Plain revealed for PAN and CVC";
    [self.toggleMaskButton addTarget:self action:@selector(toggleMaskTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:self.toggleMaskButton];

    self.resetPaymentStateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resetPaymentStateButton setTitle:@"resetPaymentState()" forState:UIControlStateNormal];
    self.resetPaymentStateButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [self.resetPaymentStateButton setTitleColor:[ThemeHelper primaryColor] forState:UIControlStateNormal];
    self.resetPaymentStateButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetPaymentStateButton.accessibilityIdentifier = @"custom-form-reset-payment-state-button";
    self.resetPaymentStateButton.accessibilityHint = @"Full reset: clears fields, validation, and hosted PAN/CVV display to SDK defaults.";
    [self.resetPaymentStateButton addTarget:self action:@selector(resetPaymentStateTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:self.resetPaymentStateButton];
    
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

        [enableAutofillLabel.topAnchor constraintEqualToAnchor:blankDateLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [enableAutofillLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [enableAutofillLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.enableAutofillSwitch.leadingAnchor constant:-[ThemeHelper spacingSM]],
        [enableAutofillLabel.centerYAnchor constraintEqualToAnchor:self.enableAutofillSwitch.centerYAnchor],

        [self.enableAutofillSwitch.topAnchor constraintEqualToAnchor:blankDateLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.enableAutofillSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [enableAutofillHelpLabel.topAnchor constraintEqualToAnchor:enableAutofillLabel.bottomAnchor constant:[ThemeHelper spacingXS]],
        [enableAutofillHelpLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [enableAutofillHelpLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [hostedWinsLabel.topAnchor constraintEqualToAnchor:enableAutofillHelpLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [hostedWinsLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [hostedWinsLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.demoHostedWinsConflictSwitch.leadingAnchor constant:-[ThemeHelper spacingSM]],
        [hostedWinsLabel.centerYAnchor constraintEqualToAnchor:self.demoHostedWinsConflictSwitch.centerYAnchor],

        [self.demoHostedWinsConflictSwitch.topAnchor constraintEqualToAnchor:enableAutofillHelpLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.demoHostedWinsConflictSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [panFormatHelpLabel.topAnchor constraintEqualToAnchor:hostedWinsLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [panFormatHelpLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [panFormatHelpLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.panFormatSegmentedControl.topAnchor constraintEqualToAnchor:panFormatHelpLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [self.panFormatSegmentedControl.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.panFormatSegmentedControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [self.toggleMaskButton.topAnchor constraintEqualToAnchor:self.panFormatSegmentedControl.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.toggleMaskButton.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],

        [self.resetPaymentStateButton.topAnchor constraintEqualToAnchor:self.toggleMaskButton.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.resetPaymentStateButton.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        
        [yearFormatLabel.topAnchor constraintEqualToAnchor:self.resetPaymentStateButton.bottomAnchor constant:[ThemeHelper spacingMD]],
        [yearFormatLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [yearFormatLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.yearFormatSegmentedControl.leadingAnchor constant:-[ThemeHelper spacingSM]],
        [yearFormatLabel.centerYAnchor constraintEqualToAnchor:self.yearFormatSegmentedControl.centerYAnchor],
        
        [self.yearFormatSegmentedControl.topAnchor constraintEqualToAnchor:self.resetPaymentStateButton.bottomAnchor constant:[ThemeHelper spacingMD]],
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
        if (self.catalogueHostedStack && self.expirationDateField.view) {
            for (NSLayoutConstraint *constraint in self.formContainer.constraints) {
                if (constraint.firstItem == self.catalogueHostedStack && constraint.firstAttribute == NSLayoutAttributeTop) {
                    constraint.active = NO;
                }
            }
            [NSLayoutConstraint activateConstraints:@[
                [self.catalogueHostedStack.topAnchor constraintEqualToAnchor:self.expirationDateField.view.bottomAnchor constant:[ThemeHelper spacingMD]]
            ]];
        }
        [self reloadCatalogueHostedFields];
    }
}

- (void)panFormatChanged:(UISegmentedControl *)sender {
    [[Spreedly shared] setNumberFormatWithCardNumberFormatRawValue:(NSInteger)sender.selectedSegmentIndex];
}

- (void)toggleMaskTapped {
    [[Spreedly shared] toggleMask];
}

- (void)resetPaymentStateTapped {
    [[Spreedly shared] resetPaymentState];
    self.cardHolderNameIsValid = NO;
    self.cardNumberIsValid = NO;
    self.cvcIsValid = NO;
    self.expirationDateIsValid = NO;
    [self.additionalFieldValidity removeAllObjects];
    [self updatePayButtonState];
}

- (BOOL)hostedFieldsEnableAutofill {
    return self.enableAutofillSwitch.isOn;
}

- (void)applyEnableAutofillToHostedFields {
    BOOL enabled = [self hostedFieldsEnableAutofill];
    self.cardHolderNameField.enableAutofill = enabled;
    self.cardNumberField.enableAutofill = enabled;
    self.cvcField.enableAutofill = enabled;
    if (self.expirationDateField) {
        self.expirationDateField.enableAutofill = enabled;
    }
    for (SPLTextFieldViewController *field in self.catalogueHostedFields) {
        field.enableAutofill = enabled;
    }
}

- (void)enableAutofillToggled:(UISwitch *)sender {
    (void)sender;
    [self applyEnableAutofillToHostedFields];
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
    self.cardHolderNameField.enableAutofill = [self hostedFieldsEnableAutofill];
    self.cardHolderNameField.evaluatesCustomValidationOnBlur = YES;
    
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
    self.cardNumberField.enableAutofill = [self hostedFieldsEnableAutofill];
    
    [self addChildViewController:self.cardNumberField];
    self.cardNumberField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cardNumberField.view];
    [self.cardNumberField didMoveToParentViewController:self];
    __weak typeof(self) weakSelf = self;
    self.cardNumberField.trailingIconViewFactory = ^UIView *(NSString *schemeRaw) {
        return [weakSelf merchantPanTrailingBrandViewForSchemeRawValue:schemeRaw];
    };
    [self attachHostedFieldCallbacksToField:self.cardNumberField];
    
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
    self.cvcField.enableAutofill = [self hostedFieldsEnableAutofill];
    [self addChildViewController:self.cvcField];
    self.cvcField.view.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.cvcField.view];
    [self.cvcField didMoveToParentViewController:self];
    [self attachHostedFieldCallbacksToField:self.cvcField];
    
    // Create expiration date field with current year format
    [self createExpirationDateFieldInContainer:container belowView:self.cvcField.view];

    self.catalogueHostedStack = [[UIStackView alloc] init];
    self.catalogueHostedStack.axis = UILayoutConstraintAxisVertical;
    self.catalogueHostedStack.spacing = [ThemeHelper spacingMD];
    self.catalogueHostedStack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.catalogueHostedStack];
    
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

        [self.catalogueHostedStack.topAnchor constraintEqualToAnchor:self.expirationDateField.view.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.catalogueHostedStack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [self.catalogueHostedStack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.catalogueHostedStack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];

    [self reloadCatalogueHostedFields];
    
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
    self.cardHolderNameField.enableAutofill = [self hostedFieldsEnableAutofill];
    self.cardHolderNameField.evaluatesCustomValidationOnBlur = YES;
    
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
    
    self.expirationDateField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeExpirationDate title:@"Expiry Date" isRequired:isRequired placeholder:nil keyboardType:UIKeyboardTypeNumberPad textContentType:UITextContentTypeDateTime onValidationChange:^(BOOL valid) {
        self.expirationDateIsValid = valid;
        [self updatePayButtonState];
    } onSubmit:^{
        [self payButtonTapped];
    } submitLabel:SpreedlySubmitLabelDone onFocus:nil];
    self.expirationDateField.yearFormat = yearFormat;
    self.expirationDateField.enableAutofill = [self hostedFieldsEnableAutofill];
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
            [self.expirationDateField.view.heightAnchor constraintGreaterThanOrEqualToConstant:60]
        ]];
    }
}

- (void)clearCatalogueHostedFields {
    for (SPLTextFieldViewController *field in self.catalogueHostedFields) {
        [field willMoveToParentViewController:nil];
        [field.view removeFromSuperview];
        [field removeFromParentViewController];
    }
    [self.catalogueHostedFields removeAllObjects];
    for (UIView *view in [self.catalogueHostedStack.arrangedSubviews copy]) {
        [self.catalogueHostedStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

- (void)reloadCatalogueHostedFields {
    if (!self.catalogueHostedStack || !self.cataloguePanel) {
        return;
    }
    [self clearCatalogueHostedFields];

    NSMutableSet<NSString *> *enabledIds = [NSMutableSet set];
    NSArray *enabledRows = [self.cataloguePanel.catalogueRows filteredArrayUsingPredicate:
                            [NSPredicate predicateWithBlock:^BOOL(NSDictionary *row, NSDictionary *bindings) {
        return [row[@"enabled"] boolValue];
    }]];

    NSInteger index = 0;
    NSInteger count = enabledRows.count;
    for (NSDictionary *row in enabledRows) {
        NSString *fieldId = row[@"id"];
        [enabledIds addObject:fieldId];
        FormFieldType type = (FormFieldType)[row[@"type"] integerValue];
        BOOL required = [row[@"required"] boolValue];
        BOOL isLast = (index == count - 1);

        __weak typeof(self) weakSelf = self;
        SPLTextFieldViewController *field = [[SPLTextFieldViewController alloc]
            initWithField:type
                    title:row[@"title"]
               isRequired:required
              placeholder:nil
             keyboardType:UIKeyboardTypeDefault
          textContentType:nil
     onValidationChange:^(BOOL valid) {
         weakSelf.additionalFieldValidity[fieldId] = @(valid);
         [weakSelf updatePayButtonState];
     } onSubmit:^{
         if (isLast) {
             [weakSelf payButtonTapped];
         } else if (index + 1 < (NSInteger)weakSelf.catalogueHostedFields.count) {
             (void)[weakSelf.catalogueHostedFields[index + 1] becomeFirstResponder];
         }
     } submitLabel:(isLast ? SpreedlySubmitLabelDone : SpreedlySubmitLabelNext)
             onFocus:nil];
        field.enableAutofill = [self hostedFieldsEnableAutofill];
        field.evaluatesCustomValidationOnBlur = YES;
        field.view.accessibilityIdentifier = [NSString stringWithFormat:@"customForm_hosted_%@", fieldId];

        [self addChildViewController:field];
        field.view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.catalogueHostedStack addArrangedSubview:field.view];
        [NSLayoutConstraint activateConstraints:@[
            [field.view.heightAnchor constraintGreaterThanOrEqualToConstant:60]
        ]];
        [field didMoveToParentViewController:self];
        [self.catalogueHostedFields addObject:field];
        index += 1;
    }

    // Drop validity for fields that are no longer mounted.
    for (NSString *key in [self.additionalFieldValidity.allKeys copy]) {
        if (![enabledIds containsObject:key]) {
            [self.additionalFieldValidity removeObjectForKey:key];
        }
    }

    // Expiry Done vs Next depending on catalogue
    if (self.expirationDateField) {
        __weak typeof(self) weakSelf = self;
        if (self.catalogueHostedFields.count > 0) {
            self.expirationDateField.onSubmit = ^{
                (void)[weakSelf.catalogueHostedFields.firstObject becomeFirstResponder];
            };
            [self.expirationDateField updateSubmitLabel:SpreedlySubmitLabelNext];
        } else {
            self.expirationDateField.onSubmit = ^{
                [weakSelf payButtonTapped];
            };
            [self.expirationDateField updateSubmitLabel:SpreedlySubmitLabelDone];
        }
    }
}

- (void)yearFormatChanged:(UISegmentedControl *)sender {
    // Recreate the expiration date field with the new year format
    if (self.cvcField.view) {
        [self createExpirationDateFieldInContainer:self.formContainer belowView:self.cvcField.view];
        if (self.catalogueHostedStack && self.expirationDateField.view) {
            // Re-pin catalogue stack under the new expiry field.
            for (NSLayoutConstraint *constraint in self.formContainer.constraints) {
                if (constraint.firstItem == self.catalogueHostedStack && constraint.firstAttribute == NSLayoutAttributeTop) {
                    constraint.active = NO;
                }
            }
            [NSLayoutConstraint activateConstraints:@[
                [self.catalogueHostedStack.topAnchor constraintEqualToAnchor:self.expirationDateField.view.bottomAnchor constant:[ThemeHelper spacingMD]]
            ]];
        }
        [self reloadCatalogueHostedFields];
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

        [self.activeCustomRulesLabel.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [self.activeCustomRulesLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.activeCustomRulesLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.customValidationContainer.topAnchor constraintEqualToAnchor:self.activeCustomRulesLabel.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.customValidationContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.customValidationContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.cataloguePanel.topAnchor constraintEqualToAnchor:self.customValidationContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.cataloguePanel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.cataloguePanel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        
        // Components Container
        [self.componentsContainer.topAnchor constraintEqualToAnchor:self.cataloguePanel.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.componentsContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.componentsContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        
        // Config Container
        [self.configContainer.topAnchor constraintEqualToAnchor:self.componentsContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.configContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.configContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        
        [self.fieldStateInspectorTitleLabel.topAnchor constraintEqualToAnchor:self.configContainer.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.fieldStateInspectorTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.fieldStateInspectorTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.fieldInspectorCaptionLabel.topAnchor constraintEqualToAnchor:self.fieldStateInspectorTitleLabel.bottomAnchor constant:4],
        [self.fieldInspectorCaptionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.fieldInspectorCaptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.wiringLabel.topAnchor constraintEqualToAnchor:self.fieldInspectorCaptionLabel.bottomAnchor constant:6],
        [self.wiringLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.wiringLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.lastEventLabel.topAnchor constraintEqualToAnchor:self.wiringLabel.bottomAnchor constant:6],
        [self.lastEventLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.lastEventLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.eventLogLabel.topAnchor constraintEqualToAnchor:self.lastEventLabel.bottomAnchor constant:4],
        [self.eventLogLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.eventLogLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.fieldStatusLabel.topAnchor constraintEqualToAnchor:self.eventLogLabel.bottomAnchor constant:8],
        [self.fieldStatusLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.fieldStatusLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.aggregateValidationLabel.topAnchor constraintEqualToAnchor:self.fieldStatusLabel.bottomAnchor constant:4],
        [self.aggregateValidationLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.aggregateValidationLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.fieldStatusHintLabel.topAnchor constraintEqualToAnchor:self.aggregateValidationLabel.bottomAnchor constant:4],
        [self.fieldStatusHintLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.fieldStatusHintLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.formContainer.topAnchor constraintEqualToAnchor:self.fieldStatusHintLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
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
    [self syncLocalValidityWithCustomValidationErrors];
    BOOL isFormValid = [self isFormValid];
    self.payButton.enabled = isFormValid && !self.isLoading;
    self.payButton.backgroundColor = isFormValid && !self.isLoading ? [ThemeHelper primaryColor] : [[ThemeHelper primaryColor] colorWithAlphaComponent:0.6];
    [self refreshAggregateValidationReadout];
}

/// When custom-validator chrome clears, restore local flags from built-in `isValid`.
/// While any custom error is parked, `isFormValid` already keeps Pay off via `customValidationErrorCount`.
- (void)syncLocalValidityWithCustomValidationErrors {
    NSInteger count = [SpreedlyUIManager shared].customValidationErrorCount;
    if (count == 0 && self.previousCustomValidationErrorCount > 0) {
        for (SPLTextFieldViewController *vc in self.catalogueHostedFields) {
            NSString *fieldId = [self catalogueFieldIdForType:vc.field];
            if (fieldId.length > 0 && vc.isValid) {
                self.additionalFieldValidity[fieldId] = @YES;
            }
        }
        if (self.cardHolderNameField.isValid) {
            self.cardHolderNameIsValid = YES;
        }
    }
    self.previousCustomValidationErrorCount = count;
}

- (nullable NSString *)catalogueFieldIdForType:(FormFieldType)type {
    for (NSDictionary *row in self.cataloguePanel.catalogueRows) {
        if ((FormFieldType)[row[@"type"] integerValue] == type) {
            return row[@"id"];
        }
    }
    return nil;
}

- (BOOL)isFormValid {
    // Name validation: only required if allowBlankName is false
    BOOL nameValid = self.allowBlankNameSwitch.isOn ? YES : self.cardHolderNameIsValid;
    
    // Card number and CVC validation: always required
    BOOL cardValid = self.cardNumberIsValid && self.cvcIsValid;
    
    // Expiration date validation: always required for format, but allowExpiredDate affects validation rules
    BOOL expirationValid = self.expirationDateIsValid;

    BOOL requiredCatalogueValid = YES;
    for (NSDictionary *row in self.cataloguePanel.catalogueRows) {
        if (![row[@"enabled"] boolValue] || ![row[@"required"] boolValue]) { continue; }
        NSString *fieldId = row[@"id"];
        if (![self.additionalFieldValidity[fieldId] boolValue]) {
            requiredCatalogueValid = NO;
            break;
        }
    }

    // Any parked custom-validator message (red chrome) keeps Pay disabled.
    BOOL noCustomErrors = [SpreedlyUIManager shared].customValidationErrorCount == 0;
    
    return nameValid && cardValid && expirationValid && requiredCatalogueValid && noCustomErrors;
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
        NSArray<NSNumber *> *fieldTypes = @[
            @(FormFieldTypeFullName),
            @(FormFieldTypeCardNumber),
            @(FormFieldTypeCvc),
            @(FormFieldTypeExpirationDate)
        ];
        [self refreshAggregateValidationReadout];
        BOOL allValid = [Spreedly areAllFieldsValidWithFieldTypeRawValues:fieldTypes];

        if (!allValid) {
            self.isLoading = NO;
            [self.loadingIndicator stopAnimating];
            [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
            self.errorMessage = @"Fix invalid fields before paying.";
            [self updateUI];
            [self updatePayButtonState];
            return;
        }

        // Demo hosted-wins: only when toggle is on (default off), pass conflicting headless
        // values so mounted ZIP/city fields win when present.
        NSDictionary *additionalFields = @{};
        if (self.demoHostedWinsConflictSwitch.isOn) {
            additionalFields = @{
                @"zip": @"00000",
                @"city": @"SHOULD_NOT_WIN"
            };
        }
        
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

    NSDictionary *pm = self.paymentResult.paymentResponseDictionary[@"transaction"][@"paymentMethod"];
    if ([pm isKindOfClass:[NSDictionary class]]) {
        NSString *lastFour = pm[@"lastFourDigits"];
        if (lastFour.length > 0) {
            UILabel *lastFourLabel = [[UILabel alloc] init];
            lastFourLabel.text = [NSString stringWithFormat:@"Card ending in •••• %@", lastFour];
            lastFourLabel.font = [ThemeHelper captionFont];
            lastFourLabel.textColor = [ThemeHelper textSecondaryColor];
            lastFourLabel.numberOfLines = 0;
            lastFourLabel.translatesAutoresizingMaskIntoConstraints = NO;
            [self.resultContainer addSubview:lastFourLabel];
            [constraints addObjectsFromArray:@[
                [lastFourLabel.topAnchor constraintEqualToAnchor:lastView.bottomAnchor constant:[ThemeHelper spacingSM]],
                [lastFourLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
                [lastFourLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]]
            ]];
            lastView = lastFourLabel;
        }
        NSString *firstSix = pm[@"firstSixDigits"];
        if (firstSix.length > 0) {
            UILabel *firstSixLabel = [[UILabel alloc] init];
            firstSixLabel.text = [NSString stringWithFormat:@"Card starting in •••• %@", firstSix];
            firstSixLabel.font = [ThemeHelper captionFont];
            firstSixLabel.textColor = [ThemeHelper textSecondaryColor];
            firstSixLabel.numberOfLines = 0;
            firstSixLabel.translatesAutoresizingMaskIntoConstraints = NO;
            [self.resultContainer addSubview:firstSixLabel];
            [constraints addObjectsFromArray:@[
                [firstSixLabel.topAnchor constraintEqualToAnchor:lastView.bottomAnchor constant:[ThemeHelper spacingSM]],
                [firstSixLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
                [firstSixLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]]
            ]];
            lastView = firstSixLabel;
        }
    }
    
    [constraints addObject:[lastView.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-[ThemeHelper spacingMD]]];
    
    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [DemoCustomValidationRecipes removeAllManagedValidations];
    if ([Spreedly shared].paymentDelegate == self) {
        [Spreedly shared].paymentDelegate = nil;
    }
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

#pragma mark - Custom field validators

- (UIView *)createCustomValidationContainer {
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [ThemeHelper cardBackgroundColor];
    container.layer.cornerRadius = [ThemeHelper borderRadiusXL];
    container.layer.borderWidth = 1.0;
    UIColor *borderColor = [ThemeHelper cardBorderColor];
    container.layer.borderColor = [borderColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [ThemeHelper applySmallShadowToView:container];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Custom validation (QA):";
    title.font = [ThemeHelper screenHeadlineFont];
    title.textColor = [ThemeHelper textColor];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:title];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];

    self.fullNameRuleButton = [self ruleButtonWithId:@"customForm_fullName_customRule" action:@selector(fullNameRuleTapped:)];
    [self syncCustomFormRuleButton:self.fullNameRuleButton kind:self.fullNameCustomRule];

    [stack addArrangedSubview:[self labeledRuleRow:@"Full name" button:self.fullNameRuleButton]];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [title.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [title.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [stack.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:[ThemeHelper spacingSM]],
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];
    return container;
}

- (UIButton *)ruleButtonWithId:(NSString *)accessibilityId action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentTrailing;
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    button.accessibilityIdentifier = accessibilityId;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIView *)labeledRuleRow:(NSString *)title button:(UIButton *)button {
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    label.textColor = [UIColor secondaryLabelColor];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[label, button]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    row.alignment = UIStackViewAlignmentCenter;
    return row;
}

- (void)syncCustomFormRuleButton:(UIButton *)button kind:(DemoCustomValidationKind)kind {
    [button setTitle:[NSString stringWithFormat:@"%@ ▾", [DemoCustomValidationRecipes pickerLabelForKind:kind]]
            forState:UIControlStateNormal];
}

- (void)presentCustomFormRulePickerFrom:(UIButton *)button
                            currentKind:(DemoCustomValidationKind)current
                             completion:(void (^)(DemoCustomValidationKind kind))completion {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Custom rule"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSNumber *boxed in [DemoCustomValidationRecipes pickerKindsForNameFields]) {
        DemoCustomValidationKind kind = (DemoCustomValidationKind)boxed.integerValue;
        [sheet addAction:[UIAlertAction actionWithTitle:[DemoCustomValidationRecipes pickerLabelForKind:kind]
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *a) {
            if (completion) { completion(kind); }
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = button;
        sheet.popoverPresentationController.sourceRect = button.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)fullNameRuleTapped:(UIButton *)sender {
    [self presentCustomFormRulePickerFrom:sender currentKind:self.fullNameCustomRule completion:^(DemoCustomValidationKind kind) {
        self.fullNameCustomRule = kind;
        [self syncCustomFormRuleButton:self.fullNameRuleButton kind:kind];
        [self applyCustomValidationSelections];
    }];
}

- (void)applyCustomValidationSelections {
    NSMutableDictionary *selections = [[self.cataloguePanel catalogueCustomValidationSelections] mutableCopy];
    if (!selections) {
        selections = [NSMutableDictionary dictionary];
    }
    DemoCustomValidationKind fullKind = self.fullNameCustomRule;
    NSArray<NSNumber *> *nameKinds = [DemoCustomValidationRecipes pickerKindsForNameFields];
    if (![nameKinds containsObject:@(fullKind)]) {
        fullKind = DemoCustomValidationKindNone;
        self.fullNameCustomRule = fullKind;
        [self syncCustomFormRuleButton:self.fullNameRuleButton kind:fullKind];
    }
    selections[@"full_name"] = @(fullKind);
    [DemoCustomValidationRecipes applySelections:selections];
    self.activeCustomRulesLabel.text = [DemoCustomValidationRecipes activeRulesSummaryFromSelections:selections];
}

- (void)registerDemoCustomFieldValidators {
    [self applyCustomValidationSelections];
}

- (void)removeDemoCustomFieldValidators {
    [DemoCustomValidationRecipes removeAllManagedValidations];
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

- (NSString *)formFieldTypeDisplayName:(FormFieldType)type {
    switch (type) {
        case FormFieldTypeCardNumber:
            return @"Card number";
        case FormFieldTypeFullName:
            return @"Cardholder name";
        case FormFieldTypeFirstName:
            return @"First name";
        case FormFieldTypeLastName:
            return @"Last name";
        case FormFieldTypeExpirationMonth:
            return @"Expiry month";
        case FormFieldTypeExpirationYear:
            return @"Expiry year";
        case FormFieldTypeExpirationDate:
            return @"Expiry date";
        case FormFieldTypeCvc:
            return @"Security code (CVC)";
        case FormFieldTypeAddressLine1:
            return @"Address line 1";
        case FormFieldTypeAddressLine2:
            return @"Address line 2";
        case FormFieldTypeCity:
            return @"City";
        case FormFieldTypeState:
            return @"State";
        case FormFieldTypeZipCode:
            return @"ZIP code";
        default:
            return [NSString stringWithFormat:@"Field (%ld)", (long)type];
    }
}

- (NSString *)hostedFieldEventDescription:(HostedFieldEventType)eventType {
    switch (eventType) {
        case HostedFieldEventTypeInput:
            return @"user typed";
        case HostedFieldEventTypeFocus:
            return @"gained focus";
        case HostedFieldEventTypeBlur:
            return @"left the field";
        case HostedFieldEventTypeValidation:
            return @"VALIDATION";
        case HostedFieldEventTypePanMaskChanged:
            return @"PAN_MASK_CHANGED";
        default:
            return @"UNKNOWN";
    }
}

- (NSString *)logYesNo:(BOOL)value {
    return value ? @"yes" : @"no";
}

- (NSString *)cardNumberFormatLabelForRawValue:(NSInteger)rawValue {
    switch (rawValue) {
        case 0: return @"pretty";
        case 1: return @"plain";
        case 2: return @"masked";
        default: return @"unknown";
    }
}

- (void)logHostedFieldStateChange:(HostedFieldState *)state {
    [self updateHostedFieldStatusFromState:state];
    [self appendHostedFieldEventLog:state];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshAggregateValidationReadout];
    });
}

- (void)attachHostedFieldCallbacksToField:(SPLTextFieldViewController *)field {
    __weak typeof(self) weakSelf = self;
    field.onFieldStateChange = ^(HostedFieldState *state) {
        [weakSelf logHostedFieldStateChange:state];
    };
    field.fieldTextChangeListener = self;
}

- (void)onFieldTextChanged:(FormFieldType)fieldType text:(NSString *)text {
    (void)text;
    if (fieldType != FormFieldTypeCardNumber && fieldType != FormFieldTypeCvc) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.fieldStatusHintLabel.text = [NSString stringWithFormat:
            @"onChange: %@ (opaque — not logged)",
            [self formFieldTypeDisplayName:fieldType]];
    });
}

- (NSString *)merchantPanAssetNameForSchemeRawValue:(NSString *)schemeRaw {
    NSString *scheme = schemeRaw.lowercaseString ?: @"";
    if ([scheme isEqualToString:@"visa"]) {
        return @"MerchantDemoPanVisa";
    }
    if ([scheme isEqualToString:@"mastercard"] || [scheme isEqualToString:@"mastercard2series"]) {
        return @"MerchantDemoPanMastercard";
    }
    if ([scheme isEqualToString:@"americanexpress"]) {
        return @"MerchantDemoPanAmex";
    }
    if ([scheme isEqualToString:@"discover"]) {
        return @"MerchantDemoPanDiscover";
    }
    return @"MerchantDemoPanOther";
}

- (NSString *)merchantPanPlaceholderLabelForSchemeRawValue:(NSString *)schemeRaw {
    NSString *scheme = schemeRaw.lowercaseString ?: @"";
    if ([scheme isEqualToString:@"visa"]) {
        return @"VISA";
    }
    if ([scheme isEqualToString:@"mastercard"] || [scheme isEqualToString:@"mastercard2series"]) {
        return @"MC";
    }
    if ([scheme isEqualToString:@"americanexpress"]) {
        return @"AMEX";
    }
    if ([scheme isEqualToString:@"discover"]) {
        return @"DISC";
    }
    if ([scheme isEqualToString:@"unknown"] || scheme.length == 0) {
        return @"?";
    }
    if (scheme.length <= 5) {
        return scheme.uppercaseString;
    }
    return [[scheme.uppercaseString substringToIndex:4] stringByAppendingString:@"…"];
}

- (UIColor *)merchantPanPlaceholderTintForSchemeRawValue:(NSString *)schemeRaw {
    NSString *scheme = schemeRaw.lowercaseString ?: @"";
    if ([scheme isEqualToString:@"visa"]) {
        return [UIColor colorWithRed:0.07 green:0.20 blue:0.72 alpha:1.0];
    }
    if ([scheme isEqualToString:@"mastercard"] || [scheme isEqualToString:@"mastercard2series"]) {
        return [UIColor colorWithRed:0.96 green:0.52 blue:0.10 alpha:1.0];
    }
    if ([scheme isEqualToString:@"americanexpress"]) {
        return [UIColor colorWithRed:0.0 green:0.55 blue:0.65 alpha:1.0];
    }
    if ([scheme isEqualToString:@"discover"]) {
        return [UIColor colorWithRed:1.0 green:0.42 blue:0.18 alpha:1.0];
    }
    if ([scheme isEqualToString:@"unknown"]) {
        return [UIColor.secondaryLabelColor colorWithAlphaComponent:0.35];
    }
    return [UIColor colorWithRed:0.2 green:0.45 blue:0.95 alpha:1.0];
}

- (UIView *)merchantPanTrailingBrandViewForSchemeRawValue:(NSString *)schemeRaw {
    NSString *assetName = [self merchantPanAssetNameForSchemeRawValue:schemeRaw];
    UIImage *image = [UIImage imageNamed:assetName];
    if (image) {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        imageView.accessibilityIdentifier = @"custom-form-merchant-pan-brand-image";
        [NSLayoutConstraint activateConstraints:@[
            [imageView.widthAnchor constraintEqualToConstant:40],
            [imageView.heightAnchor constraintEqualToConstant:24]
        ]];
        return imageView;
    }

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.accessibilityIdentifier = @"custom-form-merchant-pan-brand-placeholder";

    UIView *badge = [[UIView alloc] init];
    badge.backgroundColor = [self merchantPanPlaceholderTintForSchemeRawValue:schemeRaw];
    badge.layer.cornerRadius = 4;
    badge.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *badgeLabel = [[UILabel alloc] init];
    badgeLabel.text = [self merchantPanPlaceholderLabelForSchemeRawValue:schemeRaw];
    badgeLabel.font = [UIFont systemFontOfSize:8 weight:UIFontWeightBold];
    badgeLabel.textColor = UIColor.whiteColor;
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.numberOfLines = 2;
    badgeLabel.adjustsFontSizeToFitWidth = YES;
    badgeLabel.minimumScaleFactor = 0.5;
    badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *demoLabel = [[UILabel alloc] init];
    demoLabel.text = @"demo";
    demoLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
    demoLabel.textColor = UIColor.secondaryLabelColor;
    demoLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [badge addSubview:badgeLabel];
    [container addSubview:badge];
    [container addSubview:demoLabel];

    [NSLayoutConstraint activateConstraints:@[
        [badge.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [badge.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [badge.widthAnchor constraintEqualToConstant:40],
        [badge.heightAnchor constraintEqualToConstant:24],

        [badgeLabel.leadingAnchor constraintEqualToAnchor:badge.leadingAnchor constant:2],
        [badgeLabel.trailingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:-2],
        [badgeLabel.topAnchor constraintEqualToAnchor:badge.topAnchor constant:2],
        [badgeLabel.bottomAnchor constraintEqualToAnchor:badge.bottomAnchor constant:-2],

        [demoLabel.leadingAnchor constraintEqualToAnchor:badge.trailingAnchor constant:4],
        [demoLabel.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [demoLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [container.heightAnchor constraintEqualToConstant:24]
    ]];
    return container;
}

- (NSString *)inspectorEventToken:(HostedFieldEventType)eventType {
    switch (eventType) {
        case HostedFieldEventTypeInput:
            return @"INPUT";
        case HostedFieldEventTypeFocus:
            return @"FOCUS";
        case HostedFieldEventTypeBlur:
            return @"BLUR";
        case HostedFieldEventTypeValidation:
            return @"VALIDATION";
        case HostedFieldEventTypePanMaskChanged:
            return @"PAN_MASK_CHANGED";
        default:
            return @"UNKNOWN";
    }
}

- (NSString *)inspectorBodyForCardState:(HostedFieldState *)state {
    NSMutableString *body = [NSMutableString string];
    [body appendFormat:@"  Event: %@\n", [self hostedFieldEventDescription:state.eventType]];
    [body appendFormat:@"  Valid: %@    Focused: %@    Empty: %@\n",
     [self logYesNo:state.isValid], [self logYesNo:state.isFocused], [self logYesNo:state.isEmpty]];
    [body appendString:@"  — PAN display (snapshot) —\n"];
    NSString *format = state.panDisplayFormatRawValue != nil
        ? [self cardNumberFormatLabelForRawValue:state.panDisplayFormatRawValue.intValue]
        : @"—";
    NSString *policy = state.panDisplayPolicyMasked != nil
        ? [self logYesNo:state.panDisplayPolicyMasked.boolValue]
        : @"—";
    [body appendFormat:@"  Format: %@    Policy masked: %@    Digits hidden: %@\n",
     format, policy, [self logYesNo:state.isPanMasked]];
    NSString *brand = state.cardSchemeRawValue.length > 0 ? state.cardSchemeRawValue : @"—";
    NSString *panDigits = state.numberLength != nil ? state.numberLength.stringValue : @"0";
    NSString *iin = state.iin.length > 0 ? state.iin : @"—";
    [body appendFormat:@"  Brand: %@    PAN digit count: %@\n", brand, panDigits];
    [body appendFormat:@"  IIN: %@", iin];
    return body;
}

- (NSString *)inspectorBodyForCvcState:(HostedFieldState *)state {
    NSMutableString *body = [NSMutableString string];
    [body appendFormat:@"  Event: %@\n", [self hostedFieldEventDescription:state.eventType]];
    [body appendFormat:@"  Valid: %@    Focused: %@    Empty: %@\n",
     [self logYesNo:state.isValid], [self logYesNo:state.isFocused], [self logYesNo:state.isEmpty]];
    NSString *cvvDigits = state.cvvLength != nil ? state.cvvLength.stringValue : @"0";
    [body appendFormat:@"  CVV digit count: %@", cvvDigits];
    return body;
}

- (void)refreshCombinedFieldInspectorText {
    NSString *cardSection = self.lastCardInspectorBody ?: @"  (waiting for input…)";
    NSString *cvcSection = self.lastCvcInspectorBody ?: @"  (waiting for input…)";
    self.fieldStatusLabel.text = [NSString stringWithFormat:@"Card number\n%@\n\nCVC\n%@",
                                  cardSection, cvcSection];
}

- (void)updateHostedFieldStatusFromState:(HostedFieldState *)state {
    if (state.fieldType != FormFieldTypeCardNumber && state.fieldType != FormFieldTypeCvc) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (state.fieldType == FormFieldTypeCardNumber) {
            self.lastCardInspectorBody = [self inspectorBodyForCardState:state];
        } else if (state.fieldType == FormFieldTypeCvc) {
            self.lastCvcInspectorBody = [self inspectorBodyForCvcState:state];
        }
        [self refreshCombinedFieldInspectorText];
    });
}

- (void)refreshAggregateValidationReadout {
    NSArray<NSNumber *> *fieldTypes = @[
        @(FormFieldTypeFullName),
        @(FormFieldTypeCardNumber),
        @(FormFieldTypeCvc),
        @(FormFieldTypeExpirationDate)
    ];
    BOOL allValid = [Spreedly areAllFieldsValidWithFieldTypeRawValues:fieldTypes];
    NSArray<NSNumber *> *invalidRaw = [[SpreedlyUIManager shared] getInvalidFieldTypes];
    NSInteger registered = [[SpreedlyUIManager shared] getRegisteredFieldCount];
    NSMutableArray<NSString *> *invalidNames = [NSMutableArray array];
    for (NSNumber *raw in invalidRaw) {
        [invalidNames addObject:[self formFieldTypeDisplayName:(FormFieldType)raw.integerValue]];
    }
    NSString *invalidText = invalidNames.count > 0
        ? [invalidNames componentsJoinedByString:@", "]
        : @"none";
    self.aggregateValidationLabel.text = [NSString stringWithFormat:
        @"Form valid: %@ · invalid: %@ · registered: %ld",
        [self logYesNo:allValid], invalidText, (long)registered];
}

- (void)appendHostedFieldEventLog:(HostedFieldState *)state {
    if (state.fieldType != FormFieldTypeCardNumber && state.fieldType != FormFieldTypeCvc) {
        return;
    }
    NSString *fieldLabel = state.fieldType == FormFieldTypeCardNumber ? @"card" : @"cvc";
    NSString *event = [self inspectorEventToken:state.eventType];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";
    NSString *time = [formatter stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"%@ · %@ · %@", event, fieldLabel, time];
    self.lastEventLabel.text = [NSString stringWithFormat:@"Last event: %@", line];
    self.lastEventLabel.textColor = [event isEqualToString:@"PAN_MASK_CHANGED"]
        ? [UIColor systemOrangeColor]
        : [UIColor secondaryLabelColor];
    [self.hostedFieldEventLog insertObject:line atIndex:0];
    while (self.hostedFieldEventLog.count > 5) {
        [self.hostedFieldEventLog removeLastObject];
    }
    if (self.hostedFieldEventLog.count == 0) {
        self.eventLogLabel.text = @"Event log (last 5)\n  (no events yet)";
    } else {
        self.eventLogLabel.text = [NSString stringWithFormat:@"Event log (last 5)\n%@",
                                   [self.hostedFieldEventLog componentsJoinedByString:@"\n"]];
    }
}

@end 
