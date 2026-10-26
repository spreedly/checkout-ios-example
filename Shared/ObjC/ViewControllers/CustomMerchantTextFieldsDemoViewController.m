//
//  CustomMerchantTextFieldsDemoViewController.m
//  SpreedlySDKExampleObjectiveC
//

#import "CustomMerchantTextFieldsDemoViewController.h"
#import "MerchantCatalogueFieldValidation.h"
#import "SpreedlyConfigManager.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>

@interface CustomMerchantTextFieldsDemoViewController () <SpreedlyPaymentDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;

@property (nonatomic, strong) SPLTextFieldViewController *cardNumberField;
@property (nonatomic, strong) SPLTextFieldViewController *expMonthField;
@property (nonatomic, strong) SPLTextFieldViewController *expYearField;
@property (nonatomic, strong) SPLTextFieldViewController *cvcField;
@property (nonatomic, strong) UILabel *hostedGateLabel;

@property (nonatomic, strong) UISwitch *fullNameEnabledSwitch;
@property (nonatomic, strong) UISwitch *fullNameRequiredSwitch;
@property (nonatomic, strong) UITextField *fullNameField;
@property (nonatomic, strong) UILabel *fullNameErrorLabel;

@property (nonatomic, strong) UISwitch *addressEnabledSwitch;
@property (nonatomic, strong) UISwitch *addressRequiredSwitch;
@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, strong) UILabel *addressErrorLabel;

@property (nonatomic, strong) UISwitch *cityEnabledSwitch;
@property (nonatomic, strong) UISwitch *cityRequiredSwitch;
@property (nonatomic, strong) UITextField *cityField;
@property (nonatomic, strong) UILabel *cityErrorLabel;

@property (nonatomic, strong) UISwitch *stateEnabledSwitch;
@property (nonatomic, strong) UISwitch *stateRequiredSwitch;
@property (nonatomic, strong) UITextField *stateField;
@property (nonatomic, strong) UILabel *stateErrorLabel;

@property (nonatomic, strong) UISwitch *zipEnabledSwitch;
@property (nonatomic, strong) UISwitch *zipRequiredSwitch;
@property (nonatomic, strong) UITextField *zipField;
@property (nonatomic, strong) UILabel *zipErrorLabel;

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIButton *tokenizeButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@property (nonatomic, assign) BOOL hostedGateReady;
@property (nonatomic, assign) BOOL isLoading;

@end

@implementation CustomMerchantTextFieldsDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Custom Merchant TextFields";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.hostedGateReady = NO;

    [Spreedly.shared setPaymentDelegate:self];

    [self buildUI];
    [self refreshHostedGate];
    [self validateAllMerchantFieldsUpdateUI:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [Spreedly.shared setPaymentDelegate:nil];
}

#pragma mark - UI

- (void)buildUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.stackView = [[UIStackView alloc] init];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 12;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:16],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-16],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    UILabel *introTitle = [self labelWithText:@"Your TextFields + Hosted Card" font:[UIFont preferredFontForTextStyle:UIFontTextStyleTitle2] color:UIColor.labelColor];
    UILabel *introBody = [self labelWithText:@"Build catalogue fields with your own UITextFields (additionalFields). Card / expiry / CVC stay on SPLTextField. Toggle Enable and Required per field. Validation copy matches Android sample messages."
                                        font:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]
                                       color:UIColor.secondaryLabelColor];
    introBody.numberOfLines = 0;
    [self.stackView addArrangedSubview:introTitle];
    [self.stackView addArrangedSubview:introBody];

    [self.stackView addArrangedSubview:[self sectionHeader:@"Required card fields (SPLTextField)"]];
    [self addHostedCardFields];

    [self.stackView addArrangedSubview:[self sectionHeader:@"Your catalogue TextFields"]];
    [self addMerchantFieldNamed:@"Full name"
                 enabledSwitch:&_fullNameEnabledSwitch
                requiredSwitch:&_fullNameRequiredSwitch
                     textField:&_fullNameField
                    errorLabel:&_fullNameErrorLabel
                   placeholder:@"Jane Doe"
                 defaultEnabled:YES
                defaultRequired:YES];
    [self addMerchantFieldNamed:@"Address"
                 enabledSwitch:&_addressEnabledSwitch
                requiredSwitch:&_addressRequiredSwitch
                     textField:&_addressField
                    errorLabel:&_addressErrorLabel
                   placeholder:@"123 Main Street"
                 defaultEnabled:YES
                defaultRequired:NO];
    [self addMerchantFieldNamed:@"City"
                 enabledSwitch:&_cityEnabledSwitch
                requiredSwitch:&_cityRequiredSwitch
                     textField:&_cityField
                    errorLabel:&_cityErrorLabel
                   placeholder:@"San Francisco"
                 defaultEnabled:YES
                defaultRequired:NO];
    [self addMerchantFieldNamed:@"State"
                 enabledSwitch:&_stateEnabledSwitch
                requiredSwitch:&_stateRequiredSwitch
                     textField:&_stateField
                    errorLabel:&_stateErrorLabel
                   placeholder:@"CA"
                 defaultEnabled:NO
                defaultRequired:NO];
    [self addMerchantFieldNamed:@"ZIP / postal"
                 enabledSwitch:&_zipEnabledSwitch
                requiredSwitch:&_zipRequiredSwitch
                     textField:&_zipField
                    errorLabel:&_zipErrorLabel
                   placeholder:@"94107"
                 defaultEnabled:YES
                defaultRequired:NO];

    self.statusLabel = [self labelWithText:@"" font:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote] color:UIColor.systemGreenColor];
    self.statusLabel.numberOfLines = 0;
    self.errorLabel = [self labelWithText:@"" font:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote] color:UIColor.systemRedColor];
    self.errorLabel.numberOfLines = 0;
    [self.stackView addArrangedSubview:self.statusLabel];
    [self.stackView addArrangedSubview:self.errorLabel];

    self.tokenizeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.tokenizeButton setTitle:@"Tokenize" forState:UIControlStateNormal];
    self.tokenizeButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.tokenizeButton.backgroundColor = UIColor.systemBlueColor;
    [self.tokenizeButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.tokenizeButton.layer.cornerRadius = 10;
    self.tokenizeButton.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 16);
    [self.tokenizeButton addTarget:self action:@selector(tokenizeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.stackView addArrangedSubview:self.tokenizeButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [self.stackView addArrangedSubview:self.spinner];
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    return label;
}

- (UILabel *)sectionHeader:(NSString *)text {
    UILabel *label = [self labelWithText:text font:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline] color:UIColor.labelColor];
    return label;
}

- (void)addHostedCardFields {
    __weak typeof(self) weakSelf = self;
    void (^onValid)(BOOL) = ^(BOOL valid) {
        (void)valid;
        [weakSelf refreshHostedGate];
    };

    self.cardNumberField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeCardNumber
                                                                      title:@"Card Number"
                                                                 isRequired:YES];
    self.cardNumberField.placeholder = nil;
    self.cardNumberField.keyboardType = UIKeyboardTypeNumberPad;
    self.cardNumberField.textContentType = UITextContentTypeCreditCardNumber;
    self.cardNumberField.onValidationChange = onValid;

    self.expMonthField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeExpirationMonth
                                                                     title:@"Exp Month"
                                                                isRequired:YES];
    self.expMonthField.keyboardType = UIKeyboardTypeNumberPad;
    self.expMonthField.textContentType = UITextContentTypeDateTime;
    self.expMonthField.onValidationChange = onValid;

    self.expYearField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeExpirationYear
                                                                    title:@"Exp Year"
                                                               isRequired:YES];
    self.expYearField.keyboardType = UIKeyboardTypeNumberPad;
    self.expYearField.textContentType = UITextContentTypeDateTime;
    self.expYearField.onValidationChange = onValid;

    self.cvcField = [[SPLTextFieldViewController alloc] initWithField:FormFieldTypeCvc
                                                                title:@"Security Code"
                                                           isRequired:YES];
    self.cvcField.keyboardType = UIKeyboardTypeNumberPad;
    self.cvcField.textContentType = UITextContentTypeCreditCardSecurityCode;
    self.cvcField.onValidationChange = onValid;

    for (SPLTextFieldViewController *field in @[self.cardNumberField, self.expMonthField, self.expYearField, self.cvcField]) {
        [self addChildViewController:field];
        [self.stackView addArrangedSubview:field.view];
        [field didMoveToParentViewController:self];
        [field.view.heightAnchor constraintGreaterThanOrEqualToConstant:56].active = YES;
    }

    self.hostedGateLabel = [self labelWithText:@"" font:[UIFont preferredFontForTextStyle:UIFontTextStyleCaption2] color:UIColor.systemOrangeColor];
    [self.stackView addArrangedSubview:self.hostedGateLabel];
}

- (void)addMerchantFieldNamed:(NSString *)name
               enabledSwitch:(UISwitch * __strong *)enabledOut
              requiredSwitch:(UISwitch * __strong *)requiredOut
                   textField:(UITextField * __strong *)textOut
                  errorLabel:(UILabel * __strong *)errorOut
                 placeholder:(NSString *)placeholder
               defaultEnabled:(BOOL)defaultEnabled
              defaultRequired:(BOOL)defaultRequired {
    UIView *box = [[UIView alloc] init];
    box.backgroundColor = UIColor.tertiarySystemBackgroundColor;
    box.layer.cornerRadius = 12;

    UIStackView *inner = [[UIStackView alloc] init];
    inner.axis = UILayoutConstraintAxisVertical;
    inner.spacing = 8;
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    [box addSubview:inner];
    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor constraintEqualToAnchor:box.topAnchor constant:12],
        [inner.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:12],
        [inner.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-12],
        [inner.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-12]
    ]];

    UISwitch *enabled = [[UISwitch alloc] init];
    enabled.on = defaultEnabled;
    [enabled addTarget:self action:@selector(merchantToggleChanged:) forControlEvents:UIControlEventValueChanged];
    UISwitch *required = [[UISwitch alloc] init];
    required.on = defaultRequired;
    [required addTarget:self action:@selector(merchantToggleChanged:) forControlEvents:UIControlEventValueChanged];

    UIStackView *toggles = [[UIStackView alloc] init];
    toggles.axis = UILayoutConstraintAxisHorizontal;
    toggles.spacing = 8;
    toggles.alignment = UIStackViewAlignmentCenter;
    UILabel *enableLabel = [self labelWithText:[NSString stringWithFormat:@"Enable %@", name]
                                          font:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]
                                         color:UIColor.labelColor];
    UILabel *requiredLabel = [self labelWithText:@"Required"
                                            font:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]
                                           color:UIColor.labelColor];
    [toggles addArrangedSubview:enableLabel];
    [toggles addArrangedSubview:enabled];
    [toggles addArrangedSubview:[[UIView alloc] init]];
    [toggles addArrangedSubview:requiredLabel];
    [toggles addArrangedSubview:required];
    [inner addArrangedSubview:toggles];

    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.delegate = self;
    [field addTarget:self action:@selector(merchantTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [inner addArrangedSubview:field];

    UILabel *error = [self labelWithText:@"" font:[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1] color:UIColor.systemRedColor];
    error.numberOfLines = 0;
    [inner addArrangedSubview:error];

    *enabledOut = enabled;
    *requiredOut = required;
    *textOut = field;
    *errorOut = error;

    field.hidden = !defaultEnabled;
    error.hidden = !defaultEnabled;
    required.hidden = !defaultEnabled;
    requiredLabel.hidden = !defaultEnabled;

    [self.stackView addArrangedSubview:box];
}

#pragma mark - Actions

- (void)merchantToggleChanged:(UISwitch *)sender {
    BOOL nameOn = self.fullNameEnabledSwitch.isOn;
    self.fullNameField.hidden = !nameOn;
    self.fullNameErrorLabel.hidden = !nameOn;
    self.fullNameRequiredSwitch.hidden = !nameOn;
    if (!nameOn) { self.fullNameField.text = @""; }

    BOOL addressOn = self.addressEnabledSwitch.isOn;
    self.addressField.hidden = !addressOn;
    self.addressErrorLabel.hidden = !addressOn;
    self.addressRequiredSwitch.hidden = !addressOn;
    if (!addressOn) { self.addressField.text = @""; }

    BOOL cityOn = self.cityEnabledSwitch.isOn;
    self.cityField.hidden = !cityOn;
    self.cityErrorLabel.hidden = !cityOn;
    self.cityRequiredSwitch.hidden = !cityOn;
    if (!cityOn) { self.cityField.text = @""; }

    BOOL stateOn = self.stateEnabledSwitch.isOn;
    self.stateField.hidden = !stateOn;
    self.stateErrorLabel.hidden = !stateOn;
    self.stateRequiredSwitch.hidden = !stateOn;
    if (!stateOn) { self.stateField.text = @""; }

    BOOL zipOn = self.zipEnabledSwitch.isOn;
    self.zipField.hidden = !zipOn;
    self.zipErrorLabel.hidden = !zipOn;
    self.zipRequiredSwitch.hidden = !zipOn;
    if (!zipOn) { self.zipField.text = @""; }

    [self validateAllMerchantFieldsUpdateUI:YES];
    [self updateTokenizeEnabled];
}

- (void)merchantTextChanged:(UITextField *)sender {
    [self validateAllMerchantFieldsUpdateUI:YES];
    [self updateTokenizeEnabled];
}

- (void)refreshHostedGate {
    NSArray<NSNumber *> *types = @[
        @(FormFieldTypeCardNumber),
        @(FormFieldTypeExpirationMonth),
        @(FormFieldTypeExpirationYear),
        @(FormFieldTypeCvc)
    ];
    self.hostedGateReady = [Spreedly areAllFieldsValidWithFieldTypeRawValues:types];
    self.hostedGateLabel.text = [NSString stringWithFormat:@"areAllFieldsValid(CHD) = %@", self.hostedGateReady ? @"true" : @"false"];
    self.hostedGateLabel.textColor = self.hostedGateReady ? UIColor.systemGreenColor : UIColor.systemOrangeColor;
    [self updateTokenizeEnabled];
}

- (BOOL)validateAllMerchantFieldsUpdateUI:(BOOL)updateUI {
    BOOL ok = YES;

    if (self.fullNameEnabledSwitch.isOn) {
        NSString *msg = [MerchantCatalogueFieldValidation nameErrorMessageForValue:self.fullNameField.text ?: @""
                                                                        isRequired:self.fullNameRequiredSwitch.isOn];
        if (updateUI) { self.fullNameErrorLabel.text = msg ?: @""; }
        if (msg) { ok = NO; }
    } else if (updateUI) {
        self.fullNameErrorLabel.text = @"";
    }

    if (self.addressEnabledSwitch.isOn) {
        NSString *msg = [MerchantCatalogueFieldValidation addressErrorMessageForValue:self.addressField.text ?: @""
                                                                           isRequired:self.addressRequiredSwitch.isOn];
        if (updateUI) { self.addressErrorLabel.text = msg ?: @""; }
        if (msg) { ok = NO; }
    } else if (updateUI) {
        self.addressErrorLabel.text = @"";
    }

    if (self.cityEnabledSwitch.isOn) {
        NSString *msg = [MerchantCatalogueFieldValidation cityErrorMessageForValue:self.cityField.text ?: @""
                                                                        isRequired:self.cityRequiredSwitch.isOn];
        if (updateUI) { self.cityErrorLabel.text = msg ?: @""; }
        if (msg) { ok = NO; }
    } else if (updateUI) {
        self.cityErrorLabel.text = @"";
    }

    if (self.stateEnabledSwitch.isOn) {
        NSString *msg = [MerchantCatalogueFieldValidation stateErrorMessageForValue:self.stateField.text ?: @""
                                                                         isRequired:self.stateRequiredSwitch.isOn];
        if (updateUI) { self.stateErrorLabel.text = msg ?: @""; }
        if (msg) { ok = NO; }
    } else if (updateUI) {
        self.stateErrorLabel.text = @"";
    }

    if (self.zipEnabledSwitch.isOn) {
        NSString *msg = [MerchantCatalogueFieldValidation zipErrorMessageForValue:self.zipField.text ?: @""
                                                                       isRequired:self.zipRequiredSwitch.isOn];
        if (updateUI) { self.zipErrorLabel.text = msg ?: @""; }
        if (msg) { ok = NO; }
    } else if (updateUI) {
        self.zipErrorLabel.text = @"";
    }

    return ok;
}

- (NSDictionary<NSString *, NSString *> *)buildAdditionalFields {
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    if (self.fullNameEnabledSwitch.isOn) {
        map[@"full_name"] = self.fullNameField.text ?: @"";
    }
    if (self.addressEnabledSwitch.isOn) {
        map[@"address1"] = self.addressField.text ?: @"";
    }
    if (self.cityEnabledSwitch.isOn) {
        map[@"city"] = self.cityField.text ?: @"";
    }
    if (self.stateEnabledSwitch.isOn) {
        map[@"state"] = self.stateField.text ?: @"";
    }
    if (self.zipEnabledSwitch.isOn) {
        map[@"zip"] = self.zipField.text ?: @"";
    }
    return map;
}

- (void)clearMerchantFields {
    self.fullNameField.text = @"";
    self.addressField.text = @"";
    self.cityField.text = @"";
    self.stateField.text = @"";
    self.zipField.text = @"";
    self.fullNameErrorLabel.text = @"";
    self.addressErrorLabel.text = @"";
    self.cityErrorLabel.text = @"";
    self.stateErrorLabel.text = @"";
    self.zipErrorLabel.text = @"";
}

- (void)updateTokenizeEnabled {
    BOOL can = self.hostedGateReady && [self validateAllMerchantFieldsUpdateUI:NO] && !self.isLoading;
    self.tokenizeButton.enabled = can;
    self.tokenizeButton.alpha = can ? 1.0 : 0.5;
}

- (void)tokenizeTapped {
    if (![self validateAllMerchantFieldsUpdateUI:YES]) {
        self.errorLabel.text = @"Fix merchant field errors before paying.";
        self.statusLabel.text = @"";
        return;
    }
    if (!self.hostedGateReady) {
        self.errorLabel.text = @"Complete card fields first.";
        self.statusLabel.text = @"";
        return;
    }

    self.isLoading = YES;
    self.errorLabel.text = @"";
    self.statusLabel.text = @"";
    [self.spinner startAnimating];
    [self updateTokenizeEnabled];

    [[SpreedlyConfigManager shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                self.isLoading = NO;
                [self.spinner stopAnimating];
                self.errorLabel.text = @"Failed to generate signature.";
                [self updateTokenizeEnabled];
                return;
            }

            [self refreshHostedGate];
            if (!self.hostedGateReady || ![self validateAllMerchantFieldsUpdateUI:YES]) {
                self.isLoading = NO;
                [self.spinner stopAnimating];
                self.errorLabel.text = @"Fix invalid fields before paying.";
                [self updateTokenizeEnabled];
                return;
            }

            NSDictionary *metadata = @{@"source": @"CustomMerchantTextFieldsDemo"};
            PaymentProcessingResult *processing = [Spreedly.shared createCreditCardObjCWithAdditionalFields:[self buildAdditionalFields]
                                                                                                   metadata:metadata];
            if (processing.isValidationFailed) {
                self.isLoading = NO;
                [self.spinner stopAnimating];
                self.errorLabel.text = processing.getDescription;
                [self updateTokenizeEnabled];
            }
        });
    }];
}

#pragma mark - SpreedlyPaymentDelegate

- (void)paymentDidComplete:(PaymentResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isLoading = NO;
        [self.spinner stopAnimating];
        [self updateTokenizeEnabled];

        if (result.isSuccess) {
            self.errorLabel.text = @"";
            self.statusLabel.text = [NSString stringWithFormat:@"Tokenized: %@", result.token ? [Spreedly maskedToken:result.token] : @"(no token)"];
            [self clearMerchantFields];
        } else if (result.failureDetails) {
            self.statusLabel.text = @"";
            self.errorLabel.text = result.failureDetails.getDescription;
        } else {
            self.statusLabel.text = @"";
            self.errorLabel.text = @"Payment failed";
        }
    });
}

@end
