//
//  BankAccountCustomFormViewController.m
//  SpreedlySDKExampleObjectiveC
//
//  ObjC parity for the Swift `BankAccountCustomFormView`; uses
//  `SPLTextFieldViewController` for hosted-field input.
//

#import "BankAccountCustomFormViewController.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <objc/runtime.h>
#import "SpreedlyConfigManager.h"
#import "ThemeHelper.h"

typedef NS_ENUM(NSInteger, BankAccountNameDisplayMode) {
    BankAccountNameDisplayModeFullName = 0,
    BankAccountNameDisplayModeSeparate = 1
};

@interface BankAccountCustomFormViewController () <SpreedlyPaymentDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UIView *componentsContainer;
@property (nonatomic, strong) UIView *configContainer;
@property (nonatomic, strong) UIView *formContainer;
@property (nonatomic, strong) UIButton *payButton;
@property (nonatomic, strong) UIView *resultContainer;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@property (nonatomic, strong, nullable) SPLTextFieldViewController *fullNameField;
@property (nonatomic, strong, nullable) SPLTextFieldViewController *firstNameField;
@property (nonatomic, strong, nullable) SPLTextFieldViewController *lastNameField;
@property (nonatomic, strong) SPLTextFieldViewController *routingNumberField;
@property (nonatomic, strong) SPLTextFieldViewController *accountNumberField;

@property (nonatomic, strong) UISegmentedControl *nameDisplayModeControl;
@property (nonatomic, strong) UISwitch *showBankNameSwitch;
@property (nonatomic, strong) UISwitch *allowBlankNameSwitch;
@property (nonatomic, strong) UISegmentedControl *accountTypeControl;
@property (nonatomic, strong) UISegmentedControl *holderTypeControl;
@property (nonatomic, strong) UITextField *bankNameField;
@property (nonatomic, strong) UIView *bankNameRow;

@property (nonatomic, assign) BankAccountNameDisplayMode nameDisplayMode;
@property (nonatomic, assign) BOOL allowBlankName;
@property (nonatomic, assign) BOOL showBankName;
@property (nonatomic, assign) BOOL isLoading;

@property (nonatomic, assign) BOOL fullNameIsValid;
@property (nonatomic, assign) BOOL firstNameIsValid;
@property (nonatomic, assign) BOOL lastNameIsValid;
@property (nonatomic, assign) BOOL routingNumberIsValid;
@property (nonatomic, assign) BOOL accountNumberIsValid;

@property (nonatomic, strong, nullable) PaymentResult *paymentResult;
@property (nonatomic, copy, nullable) NSString *errorMessage;

@end

@implementation BankAccountCustomFormViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"ACH Bank Account – Custom Form";
    self.view.backgroundColor = [ThemeHelper surfaceColor];

    self.allowBlankName = [[Spreedly shared].paramsManager getParamWithParameter:ValidationParamAllowBlankName];
    self.nameDisplayMode = BankAccountNameDisplayModeFullName;
    self.showBankName = NO;

    [self setupUI];
    [self setupConstraints];

    [Spreedly.shared setPaymentDelegate:self];

    if (![Spreedly isDeviceTrusted]) {
        self.errorMessage = Spreedly.initializationError.message ?: @"SDK blocked by security check";
        [self updateUI];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self detachField:self.fullNameField];
    [self detachField:self.firstNameField];
    [self detachField:self.lastNameField];
    [self detachField:self.routingNumberField];
    [self detachField:self.accountNumberField];
    self.fullNameField = nil;
    self.firstNameField = nil;
    self.lastNameField = nil;
}

- (void)detachField:(SPLTextFieldViewController *)field {
    if (!field) { return; }
    [field willMoveToParentViewController:nil];
    [field.view removeFromSuperview];
    [field removeFromParentViewController];
}

#pragma mark - UI Setup

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.accessibilityIdentifier = @"bank-account-custom-form-scroll-view";
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"ACH Bank Account – Custom Form";
    self.titleLabel.font = [ThemeHelper screenTitleFont];
    self.titleLabel.textColor = [ThemeHelper textColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.accessibilityIdentifier = @"bank-account-custom-form-title";
    self.titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [self.contentView addSubview:self.titleLabel];

    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = @"Preview only — ACH bank-account flows are in the SDK for internal testing and will not ship in 1.4.0. Do not integrate ACH in production. Headless ACH built field-by-field with SPLTextFieldViewController. The app owns the layout and submits via createBankAccountObjC when the user taps PAY NOW.";
    self.descriptionLabel.font = [ThemeHelper screenBodyFont];
    self.descriptionLabel.textColor = [ThemeHelper textColor];
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.descriptionLabel.accessibilityIdentifier = @"bank-account-custom-form-description";
    [self.contentView addSubview:self.descriptionLabel];

    self.componentsContainer = [self createInfoContainerWithTitle:@"Form Components:"
                                                            items:@[
        @"• Account Holder Name: SPLTextFieldViewController with FormFieldTypeFullName / FirstName / LastName",
        @"• Bank Name (optional): UITextField (free-form)",
        @"• Routing Number: SPLTextFieldViewController with FormFieldTypeRoutingNumber",
        @"• Account Number: SPLTextFieldViewController with FormFieldTypeAccountNumber"
    ]];

    self.configContainer = [self createConfigContainer];
    self.formContainer = [self createFormContainer];

    self.payButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
    self.payButton.titleLabel.font = [ThemeHelper buttonFont];
    self.payButton.backgroundColor = [ThemeHelper primaryColor];
    [self.payButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.payButton.layer.cornerRadius = [ThemeHelper borderRadiusSM];
    self.payButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.payButton.accessibilityIdentifier = @"bank-account-custom-form-pay-button";
    [self.payButton addTarget:self action:@selector(payButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.payButton];

    self.resultContainer = [[UIView alloc] init];
    self.resultContainer.hidden = YES;
    self.resultContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultContainer.accessibilityIdentifier = @"bank-account-custom-form-result-container";
    [self.contentView addSubview:self.resultContainer];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.font = [ThemeHelper bodyFont];
    self.errorLabel.textColor = [ThemeHelper errorColor];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.accessibilityIdentifier = @"bank-account-custom-form-error-message";
    [self.contentView addSubview:self.errorLabel];

    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.loadingIndicator.hidesWhenStopped = YES;
    self.loadingIndicator.color = [ThemeHelper textColor];
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.loadingIndicator];

    [self updatePayButtonState];
}

- (UIView *)createInfoContainerWithTitle:(NSString *)title items:(NSArray<NSString *> *)items {
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
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = [ThemeHelper spacingXS];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];

    for (NSString *item in items) {
        UILabel *label = [[UILabel alloc] init];
        label.text = item;
        label.font = [ThemeHelper screenBodyFont];
        label.textColor = [ThemeHelper textColor];
        label.numberOfLines = 0;
        [stack addArrangedSubview:label];
    }

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [stack.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingSM]],
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
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
    titleLabel.text = @"Configuration:";
    titleLabel.font = [ThemeHelper screenHeadlineFont];
    titleLabel.textColor = [ThemeHelper textColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [container addSubview:titleLabel];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.text = @"Name display:";
    nameLabel.font = [ThemeHelper screenBodyFont];
    nameLabel.textColor = [ThemeHelper textColor];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:nameLabel];

    self.nameDisplayModeControl = [[UISegmentedControl alloc] initWithItems:@[@"Full Name", @"Separate"]];
    self.nameDisplayModeControl.selectedSegmentIndex = (NSInteger)self.nameDisplayMode;
    self.nameDisplayModeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameDisplayModeControl.accessibilityIdentifier = @"bank-account-custom-form-name-display-mode-picker";
    self.nameDisplayModeControl.accessibilityLabel = @"Name Display Mode";
    self.nameDisplayModeControl.accessibilityHint = @"Pick single full-name or separate first and last name fields";
    [self.nameDisplayModeControl addTarget:self action:@selector(nameDisplayModeChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.nameDisplayModeControl];

    UILabel *bankNameLabel = [[UILabel alloc] init];
    bankNameLabel.text = @"Show bank name field";
    bankNameLabel.font = [ThemeHelper screenBodyFont];
    bankNameLabel.textColor = [ThemeHelper textColor];
    bankNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:bankNameLabel];

    self.showBankNameSwitch = [[UISwitch alloc] init];
    self.showBankNameSwitch.onTintColor = [ThemeHelper primaryColor];
    self.showBankNameSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.showBankNameSwitch.accessibilityIdentifier = @"bank-account-custom-form-show-bank-name-toggle";
    self.showBankNameSwitch.accessibilityLabel = @"Show Bank Name Field";
    self.showBankNameSwitch.accessibilityHint = @"Toggle the optional bank name field";
    [self.showBankNameSwitch addTarget:self action:@selector(toggleShowBankName:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.showBankNameSwitch];

    UILabel *blankNameLabel = [[UILabel alloc] init];
    blankNameLabel.text = @"Allow Blank Name";
    blankNameLabel.font = [ThemeHelper screenBodyFont];
    blankNameLabel.textColor = [ThemeHelper textColor];
    blankNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:blankNameLabel];

    self.allowBlankNameSwitch = [[UISwitch alloc] init];
    self.allowBlankNameSwitch.onTintColor = [ThemeHelper primaryColor];
    self.allowBlankNameSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.allowBlankNameSwitch.accessibilityIdentifier = @"bank-account-custom-form-allow-blank-name-toggle";
    self.allowBlankNameSwitch.accessibilityLabel = @"Allow Blank Name";
    self.allowBlankNameSwitch.accessibilityHint = @"Toggle whether the account holder name is required";
    [self.allowBlankNameSwitch setOn:self.allowBlankName];
    [self.allowBlankNameSwitch addTarget:self action:@selector(toggleAllowBlankName:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:self.allowBlankNameSwitch];

    UILabel *typeLabel = [[UILabel alloc] init];
    typeLabel.text = @"Account Type:";
    typeLabel.font = [ThemeHelper screenBodyFont];
    typeLabel.textColor = [ThemeHelper textColor];
    typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:typeLabel];

    self.accountTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"Checking", @"Savings"]];
    self.accountTypeControl.selectedSegmentIndex = 0;
    self.accountTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.accountTypeControl.accessibilityIdentifier = @"bank-account-custom-form-account-type-picker";
    self.accountTypeControl.accessibilityLabel = @"Account Type";
    self.accountTypeControl.accessibilityHint = @"Choose checking or savings account";
    [container addSubview:self.accountTypeControl];

    UILabel *holderLabel = [[UILabel alloc] init];
    holderLabel.text = @"Holder Type:";
    holderLabel.font = [ThemeHelper screenBodyFont];
    holderLabel.textColor = [ThemeHelper textColor];
    holderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:holderLabel];

    self.holderTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"Personal", @"Business"]];
    self.holderTypeControl.selectedSegmentIndex = 0;
    self.holderTypeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.holderTypeControl.accessibilityIdentifier = @"bank-account-custom-form-holder-type-picker";
    self.holderTypeControl.accessibilityLabel = @"Account Holder Type";
    self.holderTypeControl.accessibilityHint = @"Choose personal or business account holder";
    [container addSubview:self.holderTypeControl];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [nameLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [nameLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [nameLabel.centerYAnchor constraintEqualToAnchor:self.nameDisplayModeControl.centerYAnchor],

        [self.nameDisplayModeControl.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.nameDisplayModeControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.nameDisplayModeControl.widthAnchor constraintEqualToConstant:200],

        [bankNameLabel.topAnchor constraintEqualToAnchor:self.nameDisplayModeControl.bottomAnchor constant:[ThemeHelper spacingMD]],
        [bankNameLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [bankNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.showBankNameSwitch.leadingAnchor constant:-[ThemeHelper spacingSM]],
        [bankNameLabel.centerYAnchor constraintEqualToAnchor:self.showBankNameSwitch.centerYAnchor],

        [self.showBankNameSwitch.topAnchor constraintEqualToAnchor:self.nameDisplayModeControl.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.showBankNameSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [blankNameLabel.topAnchor constraintEqualToAnchor:bankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [blankNameLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [blankNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.allowBlankNameSwitch.leadingAnchor constant:-[ThemeHelper spacingSM]],
        [blankNameLabel.centerYAnchor constraintEqualToAnchor:self.allowBlankNameSwitch.centerYAnchor],

        [self.allowBlankNameSwitch.topAnchor constraintEqualToAnchor:bankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.allowBlankNameSwitch.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],

        [typeLabel.topAnchor constraintEqualToAnchor:blankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [typeLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [typeLabel.centerYAnchor constraintEqualToAnchor:self.accountTypeControl.centerYAnchor],

        [self.accountTypeControl.topAnchor constraintEqualToAnchor:blankNameLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.accountTypeControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.accountTypeControl.widthAnchor constraintEqualToConstant:200],

        [holderLabel.topAnchor constraintEqualToAnchor:self.accountTypeControl.bottomAnchor constant:[ThemeHelper spacingMD]],
        [holderLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:[ThemeHelper spacingMD]],
        [holderLabel.centerYAnchor constraintEqualToAnchor:self.holderTypeControl.centerYAnchor],

        [self.holderTypeControl.topAnchor constraintEqualToAnchor:self.accountTypeControl.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.holderTypeControl.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-[ThemeHelper spacingMD]],
        [self.holderTypeControl.widthAnchor constraintEqualToConstant:200],
        [self.holderTypeControl.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-[ThemeHelper spacingMD]]
    ]];

    return container;
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
    self.formContainer = container;

    [self attachNameFieldsForCurrentMode];
    [self attachBankNameRowVisible:self.showBankName];
    [self attachRoutingAndAccountFields];
    [self relayoutFormFields];

    return container;
}

#pragma mark - Form Fields

- (void)attachNameFieldsForCurrentMode {
    [self detachField:self.fullNameField];
    [self detachField:self.firstNameField];
    [self detachField:self.lastNameField];
    self.fullNameField = nil;
    self.firstNameField = nil;
    self.lastNameField = nil;

    if (self.nameDisplayMode == BankAccountNameDisplayModeFullName) {
        self.fullNameField = [self makeFieldWithType:FormFieldTypeFullName
                                               title:@"Account Holder Name"
                                          isRequired:!self.allowBlankName
                                        keyboardType:UIKeyboardTypeDefault
                                     textContentType:UITextContentTypeName
                                          identifier:@"bank-account-custom-form-full-name-field"
                                  onValidationChange:^(BOOL valid) {
            self.fullNameIsValid = valid;
            [self updatePayButtonState];
        }
                                            onSubmit:^{
            (void)[self.routingNumberField becomeFirstResponder];
        }
                                         submitLabel:SpreedlySubmitLabelNext];
    } else {
        self.firstNameField = [self makeFieldWithType:FormFieldTypeFirstName
                                                title:@"First Name"
                                           isRequired:!self.allowBlankName
                                         keyboardType:UIKeyboardTypeDefault
                                      textContentType:UITextContentTypeGivenName
                                           identifier:@"bank-account-custom-form-first-name-field"
                                   onValidationChange:^(BOOL valid) {
            self.firstNameIsValid = valid;
            [self updatePayButtonState];
        }
                                             onSubmit:^{
            (void)[self.lastNameField becomeFirstResponder];
        }
                                          submitLabel:SpreedlySubmitLabelNext];

        self.lastNameField = [self makeFieldWithType:FormFieldTypeLastName
                                               title:@"Last Name"
                                          isRequired:!self.allowBlankName
                                        keyboardType:UIKeyboardTypeDefault
                                     textContentType:UITextContentTypeFamilyName
                                          identifier:@"bank-account-custom-form-last-name-field"
                                  onValidationChange:^(BOOL valid) {
            self.lastNameIsValid = valid;
            [self updatePayButtonState];
        }
                                            onSubmit:^{
            (void)[self.routingNumberField becomeFirstResponder];
        }
                                         submitLabel:SpreedlySubmitLabelNext];
    }
}

- (void)attachRoutingAndAccountFields {
    if (self.routingNumberField) { return; }

    self.routingNumberField = [self makeFieldWithType:FormFieldTypeRoutingNumber
                                                 title:@"Routing Number"
                                            isRequired:YES
                                          keyboardType:UIKeyboardTypeNumberPad
                                       textContentType:nil
                                            identifier:@"bank-account-custom-form-routing-number-field"
                                    onValidationChange:^(BOOL valid) {
        self.routingNumberIsValid = valid;
        [self updatePayButtonState];
    }
                                              onSubmit:^{
        (void)[self.accountNumberField becomeFirstResponder];
    }
                                           submitLabel:SpreedlySubmitLabelNext];

    self.accountNumberField = [self makeFieldWithType:FormFieldTypeAccountNumber
                                                 title:@"Account Number"
                                            isRequired:YES
                                          keyboardType:UIKeyboardTypeNumberPad
                                       textContentType:nil
                                            identifier:@"bank-account-custom-form-account-number-field"
                                    onValidationChange:^(BOOL valid) {
        self.accountNumberIsValid = valid;
        [self updatePayButtonState];
    }
                                              onSubmit:^{
        [self payButtonTapped];
    }
                                           submitLabel:SpreedlySubmitLabelDone];
}

- (SPLTextFieldViewController *)makeFieldWithType:(FormFieldType)type
                                            title:(NSString *)title
                                       isRequired:(BOOL)required
                                     keyboardType:(UIKeyboardType)keyboardType
                                  textContentType:(nullable UITextContentType)contentType
                                       identifier:(NSString *)identifier
                               onValidationChange:(void (^)(BOOL))onValidation
                                         onSubmit:(void (^)(void))onSubmit
                                      submitLabel:(SpreedlySubmitLabel)submitLabel {
    SPLTextFieldViewController *field = [[SPLTextFieldViewController alloc]
                                         initWithField:type
                                                 title:title
                                            isRequired:required
                                           placeholder:nil
                                          keyboardType:keyboardType
                                       textContentType:contentType
                                    onValidationChange:onValidation
                                              onSubmit:onSubmit
                                           submitLabel:submitLabel
                                               onFocus:nil];

    [self addChildViewController:field];
    field.view.translatesAutoresizingMaskIntoConstraints = NO;
    field.view.accessibilityIdentifier = identifier;
    [self.formContainer addSubview:field.view];
    [field didMoveToParentViewController:self];
    return field;
}

- (void)attachBankNameRowVisible:(BOOL)visible {
    if (self.bankNameRow) {
        [self.bankNameRow removeFromSuperview];
        self.bankNameRow = nil;
        self.bankNameField = nil;
    }
    if (!visible) { return; }

    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self.formContainer addSubview:row];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Bank Name";
    label.font = [ThemeHelper screenBodyFont];
    label.textColor = [ThemeHelper textSecondaryColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    UITextField *textField = [[UITextField alloc] init];
    textField.placeholder = @"Bank name (optional)";
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.font = [ThemeHelper bodyFont];
    textField.textColor = [ThemeHelper textColor];
    textField.delegate = self;
    textField.returnKeyType = UIReturnKeyNext;
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.accessibilityIdentifier = @"bank-account-custom-form-bank-name-field";
    [row addSubview:textField];
    self.bankNameField = textField;
    self.bankNameRow = row;

    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:row.topAnchor],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [label.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],

        [textField.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:4],
        [textField.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [textField.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [textField.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [textField.heightAnchor constraintGreaterThanOrEqualToConstant:36]
    ]];
}

- (void)relayoutFormFields {
    NSMutableArray<NSLayoutConstraint *> *toRemove = [NSMutableArray array];
    for (NSLayoutConstraint *c in self.formContainer.constraints) {
        if ([self constraintReferencesFormChild:c]) {
            [toRemove addObject:c];
        }
    }
    [NSLayoutConstraint deactivateConstraints:toRemove];

    NSMutableArray<UIView *> *order = [NSMutableArray array];
    if (self.fullNameField.view) { [order addObject:self.fullNameField.view]; }
    if (self.firstNameField.view) { [order addObject:self.firstNameField.view]; }
    if (self.lastNameField.view) { [order addObject:self.lastNameField.view]; }
    if (self.bankNameRow) { [order addObject:self.bankNameRow]; }
    if (self.routingNumberField.view) { [order addObject:self.routingNumberField.view]; }
    if (self.accountNumberField.view) { [order addObject:self.accountNumberField.view]; }

    NSLayoutAnchor<NSLayoutYAxisAnchor *> *previousBottom = nil;
    for (UIView *view in order) {
        if (!previousBottom) {
            [view.topAnchor constraintEqualToAnchor:self.formContainer.topAnchor constant:[ThemeHelper spacingMD]].active = YES;
        } else {
            [view.topAnchor constraintEqualToAnchor:previousBottom constant:[ThemeHelper spacingMD]].active = YES;
        }
        [view.leadingAnchor constraintEqualToAnchor:self.formContainer.leadingAnchor constant:[ThemeHelper spacingMD]].active = YES;
        [view.trailingAnchor constraintEqualToAnchor:self.formContainer.trailingAnchor constant:-[ThemeHelper spacingMD]].active = YES;
        if ([view isKindOfClass:[UIView class]] && view.subviews.count > 0 && ![view isEqual:self.bankNameRow]) {
            [view.heightAnchor constraintGreaterThanOrEqualToConstant:60].active = YES;
        }
        previousBottom = view.bottomAnchor;
    }
    if (previousBottom) {
        [self.formContainer.bottomAnchor constraintEqualToAnchor:previousBottom constant:[ThemeHelper spacingMD]].active = YES;
    }
}

- (BOOL)constraintReferencesFormChild:(NSLayoutConstraint *)constraint {
    NSArray *children = @[
        self.fullNameField.view ?: [NSNull null],
        self.firstNameField.view ?: [NSNull null],
        self.lastNameField.view ?: [NSNull null],
        self.routingNumberField.view ?: [NSNull null],
        self.accountNumberField.view ?: [NSNull null],
        self.bankNameRow ?: [NSNull null]
    ];
    for (id child in children) {
        if (child == [NSNull null]) { continue; }
        if (constraint.firstItem == child || constraint.secondItem == child) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Constraints

- (void)setupConstraints {
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],

        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:[ThemeHelper spacingLG]],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.descriptionLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.descriptionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.descriptionLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.componentsContainer.topAnchor constraintEqualToAnchor:self.descriptionLabel.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.componentsContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.componentsContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.configContainer.topAnchor constraintEqualToAnchor:self.componentsContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.configContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.configContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.formContainer.topAnchor constraintEqualToAnchor:self.configContainer.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.formContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.formContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.payButton.topAnchor constraintEqualToAnchor:self.formContainer.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.payButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.payButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        [self.payButton.heightAnchor constraintEqualToConstant:44],

        [self.resultContainer.topAnchor constraintEqualToAnchor:self.payButton.bottomAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.resultContainer.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],

        [self.errorLabel.topAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:[ThemeHelper spacingMD]],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:[ThemeHelper spacingLG]],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-[ThemeHelper spacingLG]],
        [self.errorLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-[ThemeHelper spacingLG]],

        [self.loadingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

#pragma mark - Toggles

- (void)nameDisplayModeChanged:(UISegmentedControl *)sender {
    self.nameDisplayMode = sender.selectedSegmentIndex == 0 ? BankAccountNameDisplayModeFullName : BankAccountNameDisplayModeSeparate;
    self.fullNameIsValid = NO;
    self.firstNameIsValid = NO;
    self.lastNameIsValid = NO;
    [self attachNameFieldsForCurrentMode];
    [self relayoutFormFields];
    [self updatePayButtonState];
}

- (void)toggleShowBankName:(UISwitch *)sender {
    self.showBankName = sender.isOn;
    [self attachBankNameRowVisible:self.showBankName];
    [self relayoutFormFields];
}

- (void)toggleAllowBlankName:(UISwitch *)sender {
    self.allowBlankName = sender.isOn;
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankName value:sender.isOn];
    [self attachNameFieldsForCurrentMode];
    [self relayoutFormFields];
    [self updatePayButtonState];
}

#pragma mark - Validation

- (BOOL)isFormValid {
    BOOL nameValid;
    if (self.allowBlankName) {
        nameValid = YES;
    } else if (self.nameDisplayMode == BankAccountNameDisplayModeFullName) {
        nameValid = self.fullNameIsValid;
    } else {
        nameValid = self.firstNameIsValid && self.lastNameIsValid;
    }

    return nameValid && self.routingNumberIsValid && self.accountNumberIsValid;
}

- (void)updatePayButtonState {
    BOOL formValid = [self isFormValid];
    self.payButton.enabled = formValid && !self.isLoading;
    self.payButton.backgroundColor = (formValid && !self.isLoading)
        ? [ThemeHelper primaryColor]
        : [[ThemeHelper primaryColor] colorWithAlphaComponent:0.6];
}

#pragma mark - Submit

- (void)payButtonTapped {
    if (![self isFormValid]) { return; }

    self.isLoading = YES;
    [self.loadingIndicator startAnimating];
    [self.payButton setTitle:@"Processing..." forState:UIControlStateNormal];
    self.errorMessage = nil;
    self.paymentResult = nil;
    [self updatePayButtonState];

    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self submitBankAccount];
            } else {
                self.isLoading = NO;
                [self.loadingIndicator stopAnimating];
                [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
                self.errorMessage = error.localizedDescription ?: @"Signature generation failed";
                [self updateUI];
                [self updatePayButtonState];
            }
        });
    }];
}

- (void)submitBankAccount {
    NSString *bankAccountTypeRaw = self.accountTypeControl.selectedSegmentIndex == 0 ? @"checking" : @"savings";
    NSString *bankAccountHolderTypeRaw = self.holderTypeControl.selectedSegmentIndex == 0 ? @"personal" : @"business";

    NSString *bankNameInput = [self.bankNameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *bankName = (self.showBankName && bankNameInput.length > 0) ? bankNameInput : nil;

    NSNumber *allowBlankNameValue = self.allowBlankName ? @YES : nil;

    PaymentProcessingResult *processingResult =
        [[Spreedly shared] createBankAccountObjCWithAdditionalFields:@{}
                                                     bankAccountType:bankAccountTypeRaw
                                               bankAccountHolderType:bankAccountHolderTypeRaw
                                                            bankName:bankName
                                                            metadata:nil
                                                      allowBlankName:allowBlankNameValue
                                                       shouldRetain:nil];

    if (processingResult.isValidationFailed) {
        self.isLoading = NO;
        [self.loadingIndicator stopAnimating];
        [self.payButton setTitle:@"PAY NOW" forState:UIControlStateNormal];
        self.errorMessage = [processingResult getDescription];
        self.paymentResult = nil;
        [self updateUI];
        [self updatePayButtonState];
    }
}

#pragma mark - Result UI

- (void)updateUI {
    if (self.paymentResult && self.paymentResult.isSuccess) {
        [self renderSuccessContainer];
        self.resultContainer.hidden = NO;
        self.errorLabel.hidden = YES;
    } else if (self.errorMessage.length > 0) {
        self.errorLabel.text = [NSString stringWithFormat:@"Error: %@", self.errorMessage];
        self.errorLabel.hidden = NO;
        self.resultContainer.hidden = YES;
    } else {
        self.resultContainer.hidden = YES;
        self.errorLabel.hidden = YES;
    }
}

- (void)renderSuccessContainer {
    for (UIView *subview in self.resultContainer.subviews) {
        [subview removeFromSuperview];
    }

    self.resultContainer.backgroundColor = [[ThemeHelper successColor] colorWithAlphaComponent:0.1];
    self.resultContainer.layer.cornerRadius = [ThemeHelper borderRadiusMD];
    [ThemeHelper applySmallShadowToView:self.resultContainer];

    UIStackView *headerStack = [[UIStackView alloc] init];
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.spacing = [ThemeHelper spacingSM];
    headerStack.alignment = UIStackViewAlignmentCenter;
    headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultContainer addSubview:headerStack];

    UIImageView *successIcon = [[UIImageView alloc] init];
    successIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    successIcon.tintColor = [ThemeHelper successColor];
    successIcon.accessibilityIdentifier = @"bank-account-custom-form-success-icon";
    [headerStack addArrangedSubview:successIcon];

    UILabel *successTitle = [[UILabel alloc] init];
    successTitle.text = @"Bank Account Tokenized!";
    successTitle.font = [ThemeHelper subtitleFont];
    successTitle.textColor = [ThemeHelper successColor];
    successTitle.accessibilityIdentifier = @"bank-account-custom-form-success-title";
    successTitle.accessibilityTraits = UIAccessibilityTraitHeader;
    [headerStack addArrangedSubview:successTitle];

    UILabel *tokenLabel = nil;
    if (self.paymentResult.token) {
        tokenLabel = [[UILabel alloc] init];
        NSString *masked = [Spreedly maskedToken:self.paymentResult.token];
        tokenLabel.text = [NSString stringWithFormat:@"Payment Token: %@", masked];
        tokenLabel.font = [ThemeHelper captionFont];
        tokenLabel.textColor = [ThemeHelper textSecondaryColor];
        tokenLabel.numberOfLines = 0;
        tokenLabel.translatesAutoresizingMaskIntoConstraints = NO;
        tokenLabel.accessibilityIdentifier = @"bank-account-custom-form-token-text";
        [self.resultContainer addSubview:tokenLabel];
    }

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [headerStack.topAnchor constraintEqualToAnchor:self.resultContainer.topAnchor constant:[ThemeHelper spacingMD]],
        [headerStack.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
        [headerStack.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]]
    ]];

    UIView *lastView = headerStack;
    if (tokenLabel) {
        [constraints addObjectsFromArray:@[
            [tokenLabel.topAnchor constraintEqualToAnchor:lastView.bottomAnchor constant:[ThemeHelper spacingSM]],
            [tokenLabel.leadingAnchor constraintEqualToAnchor:self.resultContainer.leadingAnchor constant:[ThemeHelper spacingMD]],
            [tokenLabel.trailingAnchor constraintEqualToAnchor:self.resultContainer.trailingAnchor constant:-[ThemeHelper spacingMD]]
        ]];
        lastView = tokenLabel;
    }
    [constraints addObject:[lastView.bottomAnchor constraintEqualToAnchor:self.resultContainer.bottomAnchor constant:-[ThemeHelper spacingMD]]];
    [NSLayoutConstraint activateConstraints:constraints];
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
    if (textField == self.bankNameField) {
        [textField resignFirstResponder];
        (void)[self.routingNumberField becomeFirstResponder];
        return NO;
    }
    return YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [Spreedly.shared setPaymentDelegate:nil];
    [[Spreedly shared] reset];
}

@end
