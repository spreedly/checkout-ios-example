# Objective-C Integration - Spreedly iOS SDK

Integrate the Spreedly iOS SDK into Objective-C projects using delegates and UIViewController wrappers.

**Estimated time:** ~15 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Component Mapping Table](#component-mapping-table)
3. [Setup](#setup)
4. [Payment Delegate](#payment-delegate)
5. [CardFormDropInViewController](#cardformdropinviewcontroller)
6. [SPLTextFieldViewController](#spltextfieldviewcontroller)
7. [CVVRecachingViewController](#cvvrecachingviewcontroller)
8. [3DS Challenge](#3ds-challenge)
9. [Gateway-Specific 3DS](#gateway-specific-3ds)
10. [Additional Fields](#additional-fields)
11. [Offsite Payments](#offsite-payments)
12. [Stripe APM](#stripe-apm)
13. [EBANX](#ebanx)
14. [Braintree](#braintree)
15. [Theming](#theming)
16. [URL Handling](#url-handling)
17. [Cleanup and Teardown](#cleanup-and-teardown)
18. [Submit Label Values](#submit-label-values)
19. [Telemetry Events](#telemetry-events)
20. [Related Documentation](#related-documentation)

---

## Introduction

The Spreedly iOS SDK provides full Objective-C support through UIKit wrappers. All UIKit/Objective-C classes are wrappers around SwiftUI components, using `UIHostingController` internally. Delegates replace Combine publishers for receiving payment and 3DS results. The functionality is identical to Swift/SwiftUI; only the API style differs.

---

## Component Mapping Table

| SwiftUI | UIKit/Objective-C | Purpose |
|---------|-------------------|---------|
| CardFormDropIn | CardFormDropInViewController | Full payment form |
| SPLTextField | SPLTextFieldViewController | Individual field |
| SpreedlyCVVRecachingView | CVVRecachingViewController | CVV recaching |
| DoChallengeIfNeeded | DoChallengeIfNeededViewController | 3DS challenge |

---

## Setup

### Imports

```objc
#import <SpreedlyUI/SpreedlyUI-Swift.h>
#import <SpreedlyCore/SpreedlyCore-Swift.h>
```

### Initialization

Call `[Spreedly initializeSDK]` at app launch -- either in `AppDelegate application:didFinishLaunchingWithOptions:` or when setting up your root scene in `SceneDelegate scene:willConnectToSession:options:`. Scene-based apps (the default since iOS 14) should use `SceneDelegate`. Then call `[Spreedly setupWithConfig:]` with your credentials before presenting any payment UI:

```objc
// In AppDelegate or SceneDelegate at launch:
// Spreedly.blockJailbrokenDevices = YES;  // opt-in: block all SDK ops on compromised devices
[Spreedly initializeSDK];

// Before presenting payment form (e.g., after fetching signature from backend):
SpreedlyConfig *config = [[SpreedlyConfig alloc] initWithEnvironmentKey:@"YOUR_ENV_KEY"];
config.forterSiteId = @"YOUR_FORTER_SITE_ID";
config.nonce = nonce;
config.signature = signature;
config.certificateToken = certificateToken;
config.timestamp = timestamp;
// config.sdkPlatform = SdkPlatformIos;          // default — native iOS
// config.sdkPlatform = SdkPlatformReactNative;   // use for React Native bridges
// config.blockJailbrokenDevices = YES;           // or set here instead of the static property
[Spreedly setupWithConfig:config];

if (Spreedly.initializationError != nil) {
    NSLog(@"SDK blocked: %@", Spreedly.initializationError.message);
}

// Check device trust at any time:
if (!Spreedly.isDeviceTrusted) {
    NSLog(@"SDK is blocked — show fallback UI");
}
```

---

## Payment Delegate

Adopt the `SpreedlyPaymentDelegate` protocol to receive payment results:

```objc
@interface PaymentViewController () <SpreedlyPaymentDelegate>
@end

@implementation PaymentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Spreedly shared].paymentDelegate = self;
}

- (void)paymentDidComplete:(PaymentResult *)result {
    if (result.isSuccess) {
        NSString *token = result.token;
        if (result.shouldRetain) {
            // Merchant can save payment method token for future use
        } else {
            // Use token for this transaction only
        }
    } else if (result.isFailure) {
        if (result.failureDetails) {
            NSLog(@"Payment failed: %@", [result.failureDetails getDescription]);
        }
    }
}

@end
```

---

## CardFormDropInViewController

### Basic Usage

Set `paymentDelegate` to receive the final payment result. The `onProcessingResult` callback fires only for validation status (`isProcessing` and `isValidationFailed`); success and failure come via the delegate.

```objc
// Set delegate before presenting
[Spreedly shared].paymentDelegate = self;

CardFormDropInViewController *dropInVC = [[CardFormDropInViewController alloc]
    initWithOtherFields:@[]
    yearFormat:YearFormatFourDigit
    nameDisplayMode:DropInNameDisplayModeSeparateFields
    onProcessingResult:^(PaymentProcessingResult *result) {
        if (result.isProcessing) {
            // Validation passed, request started; show loading
        } else if (result.isValidationFailed) {
            NSLog(@"Validation failed: %@", [result getDescription]);
        }
    }];

UIViewController *secureVC = [dropInVC wrapInSecureViewControllerWithPlaceholderText:@""];
[self presentViewController:secureVC animated:YES completion:nil];

// Implement SpreedlyPaymentDelegate to receive success/failure:
- (void)paymentDidComplete:(PaymentResult *)result {
    if (result.isSuccess) {
        // Use result.token for your payment processing
    } else if (result.isFailure) {
        NSLog(@"Payment failed: %@", [result.failureDetails getDescription]);
    }
}
```

### Advanced Configuration

Use `initWithOtherFields:yearFormat:nameDisplayMode:onProcessingResult:` for additional fields, year format, and name display mode. For themed forms, use `initWithOtherFields:yearFormat:nameDisplayMode:lightThemeConfig:darkThemeConfig:onProcessingResult:`:

```objc
NSArray *additionalFields = @[
    [[FormField alloc] initWithId:@"addressLine1" title:@"Address" type:FormFieldTypeAddressLine1 placeholder:nil isRequired:YES],
    [[FormField alloc] initWithId:@"city" title:@"City" type:FormFieldTypeCity placeholder:nil isRequired:YES],
    [[FormField alloc] initWithId:@"state" title:@"State" type:FormFieldTypeState placeholder:nil isRequired:YES],
    [[FormField alloc] initWithId:@"zipCode" title:@"ZIP Code" type:FormFieldTypeZipCode placeholder:nil isRequired:YES]
];

[[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankName value:NO];
[[Spreedly shared] setParamWithParameter:ValidationParamAllowExpiredDate value:NO];
[[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankDate value:NO];

CardFormDropInViewController *dropInVC = [[CardFormDropInViewController alloc]
    initWithOtherFields:additionalFields
    yearFormat:YearFormatFourDigit
    nameDisplayMode:DropInNameDisplayModeSeparateFields
    onProcessingResult:^(PaymentProcessingResult *result) {
        if (result.isProcessing) {
            // Validation passed, request started; show loading
        } else if (result.isValidationFailed) {
            NSLog(@"Validation failed: %@", [result getDescription]);
        }
    }];

UIViewController *secureVC = [dropInVC wrapInSecureViewControllerWithPlaceholderText:@""];
[self presentViewController:secureVC animated:YES completion:nil];
```

Success and failure are delivered via `SpreedlyPaymentDelegate.paymentDidComplete:`, not via `onProcessingResult`.

### Themed CardFormDropInViewController

Use `initWithOtherFields:yearFormat:nameDisplayMode:lightThemeConfig:darkThemeConfig:onProcessingResult:` for custom light and dark themes:

```objc
SPLThemeConfig *lightThemeConfig = [[SPLThemeConfig alloc]
    initWithPrimaryColor:[UIColor systemBlueColor]
    secondaryColor:[UIColor systemGrayColor]
    backgroundColor:[UIColor whiteColor]
    surfaceColor:[UIColor whiteColor]
    borderColor:[UIColor systemGray4Color]
    borderFocusedColor:[UIColor systemBlueColor]
    textColor:[UIColor blackColor]
    textSecondaryColor:[UIColor systemGrayColor]
    errorColor:[UIColor systemRedColor]
    placeholderColor:nil
    borderRadius:8.0];

SPLThemeConfig *darkThemeConfig = [[SPLThemeConfig alloc]
    initWithPrimaryColor:[UIColor systemBlueColor]
    secondaryColor:[UIColor systemGrayColor]
    backgroundColor:[UIColor blackColor]
    surfaceColor:[UIColor colorWithWhite:0.11 alpha:1.0]
    borderColor:[UIColor systemGrayColor]
    borderFocusedColor:[UIColor systemBlueColor]
    textColor:[UIColor whiteColor]
    textSecondaryColor:[UIColor systemGrayColor]
    errorColor:[UIColor systemRedColor]
    placeholderColor:nil
    borderRadius:8.0];

CardFormDropInViewController *dropInVC = [[CardFormDropInViewController alloc]
    initWithOtherFields:@[]
    yearFormat:YearFormatFourDigit
    nameDisplayMode:DropInNameDisplayModeSeparateFields
    lightThemeConfig:lightThemeConfig
    darkThemeConfig:darkThemeConfig
    onProcessingResult:^(PaymentProcessingResult *result) {
        if (result.isProcessing) {
            // Validation passed, request started; show loading
        } else if (result.isValidationFailed) {
            NSLog(@"Validation failed: %@", [result getDescription]);
        }
    }];

UIViewController *secureVC = [dropInVC wrapInSecureViewControllerWithPlaceholderText:@""];
[self presentViewController:secureVC animated:YES completion:nil];
```

### Validation Parameters

Set validation parameters before creating the view controller. Reads use `[[Spreedly shared].paramsManager getParamWithParameter:]` and writes use `[[Spreedly shared] setParamWithParameter:value:]`.

- `ValidationParamAllowBlankName`
- `ValidationParamAllowExpiredDate`
- `ValidationParamAllowBlankDate`

### Screen Prevention

Wrap the view controller in secure protection for screenshot and screen recording prevention:

```objc
CardFormDropInViewController *dropInVC = [[CardFormDropInViewController alloc] init];
dropInVC.onProcessingResult = ^(PaymentProcessingResult *result) { /* ... */ };

UIViewController *secureDropInVC = [dropInVC wrapInSecureViewControllerWithPlaceholderText:@"Payment information is protected"];
[self presentViewController:secureDropInVC animated:YES completion:nil];
```

---

## SPLTextFieldViewController

### Initialization

Create individual fields with field type, title, keyboard type, and text content type:

```objc
SPLTextFieldViewController *cardNumberField = [[SPLTextFieldViewController alloc]
    initWithField:FormFieldTypeCardNumber
    title:@"Card Number"
    isRequired:YES
    placeholder:nil
    keyboardType:UIKeyboardTypeNumberPad
    textContentType:UITextContentTypeCreditCardNumber
    onValidationChange:^(BOOL isValid) {
        NSLog(@"Card number valid: %@", isValid ? @"YES" : @"NO");
    }
    onSubmit:^{
        [self.cvcField becomeFirstResponder];
    }
    submitLabel:SpreedlySubmitLabelNext
    onFocus:^{
        NSLog(@"Card number field focused");
    }];

SPLTextFieldViewController *cvcField = [[SPLTextFieldViewController alloc]
    initWithField:FormFieldTypeCvc
    title:@"Security Code"
    isRequired:YES
    placeholder:nil
    keyboardType:UIKeyboardTypeNumberPad
    textContentType:UITextContentTypeCreditCardSecurityCode
    onValidationChange:^(BOOL isValid) {
        NSLog(@"CVC valid: %@", isValid ? @"YES" : @"NO");
    }
    onSubmit:^{
        [self submitForm];
    }
    submitLabel:SpreedlySubmitLabelDone
    onFocus:^{
        NSLog(@"CVC field focused");
    }];
```

### Parameters

- **onValidationChange:** Block called when validation state changes.
- **onSubmit:** Called when user taps the keyboard submit button; use for keyboard navigation.
- **submitLabel:** `SpreedlySubmitLabelNext` for "Next" (form navigation) or `SpreedlySubmitLabelDone` for final field.
- **onFocus:** Called when the field gains focus.

### Themed SPLTextFieldViewController

Use `initWithField:title:isRequired:placeholder:keyboardType:textContentType:lightThemeConfig:darkThemeConfig:onValidationChange:onFocus:` to apply custom themes:

```objc
SPLThemeConfig *lightTheme = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemBlueColor]
                                                           secondaryColor:nil
                                                          backgroundColor:[UIColor clearColor]
                                                             surfaceColor:[UIColor whiteColor]
                                                              borderColor:[UIColor systemGray4Color]
                                                       borderFocusedColor:nil
                                                                textColor:[UIColor blackColor]
                                                       textSecondaryColor:[UIColor systemGrayColor]
                                                               errorColor:[UIColor systemRedColor]
                                                         placeholderColor:nil
                                                             borderRadius:8.0];

SPLThemeConfig *darkTheme = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemBlueColor]
                                                          secondaryColor:nil
                                                         backgroundColor:[UIColor clearColor]
                                                            surfaceColor:[UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0]
                                                             borderColor:[UIColor systemGray3Color]
                                                      borderFocusedColor:nil
                                                               textColor:[UIColor whiteColor]
                                                      textSecondaryColor:[UIColor systemGrayColor]
                                                              errorColor:[UIColor systemRedColor]
                                                        placeholderColor:nil
                                                            borderRadius:8.0];

SPLTextFieldViewController *cardNumberField = [[SPLTextFieldViewController alloc]
    initWithField:FormFieldTypeCardNumber
    title:@"Card Number"
    isRequired:YES
    placeholder:nil
    keyboardType:UIKeyboardTypeNumberPad
    textContentType:UITextContentTypeCreditCardNumber
    lightThemeConfig:lightTheme
    darkThemeConfig:darkTheme
    onValidationChange:^(BOOL valid) { /* update UI */ }
    onFocus:nil];
```

You can also set a global theme so all SDK components use it:

```objc
[SpreedlyThemeManagerObjC setGlobalThemeWithLightConfig:lightTheme darkConfig:darkTheme];
```

### Focus Management

Use `becomeFirstResponder` and `resignFirstResponder` for focus management:

```objc
// Add to view hierarchy
[self addChildViewController:cardNumberField];
[self.view addSubview:cardNumberField.view];
[cardNumberField didMoveToParentViewController:self];

[self addChildViewController:cvcField];
[self.view addSubview:cvcField.view];
[cvcField didMoveToParentViewController:self];

// Set initial focus
[cardNumberField becomeFirstResponder];
```

### Complete Form Example

```objc
- (void)setupFormFields {
    self.firstNameField = [[SPLTextFieldViewController alloc]
        initWithField:FormFieldTypeFirstName
        title:@"First Name"
        isRequired:YES
        placeholder:nil
        keyboardType:UIKeyboardTypeDefault
        textContentType:UITextContentTypeGivenName
        onValidationChange:nil
        onSubmit:^{ [self.lastNameField becomeFirstResponder]; }
        submitLabel:SpreedlySubmitLabelNext
        onFocus:nil];

    self.lastNameField = [[SPLTextFieldViewController alloc]
        initWithField:FormFieldTypeLastName
        title:@"Last Name"
        isRequired:YES
        placeholder:nil
        keyboardType:UIKeyboardTypeDefault
        textContentType:UITextContentTypeFamilyName
        onValidationChange:nil
        onSubmit:^{ [self.cardNumberField becomeFirstResponder]; }
        submitLabel:SpreedlySubmitLabelNext
        onFocus:nil];

    self.cardNumberField = [[SPLTextFieldViewController alloc]
        initWithField:FormFieldTypeCardNumber
        title:@"Card Number"
        isRequired:YES
        placeholder:nil
        keyboardType:UIKeyboardTypeNumberPad
        textContentType:UITextContentTypeCreditCardNumber
        onValidationChange:nil
        onSubmit:^{ [self.cvcField becomeFirstResponder]; }
        submitLabel:SpreedlySubmitLabelNext
        onFocus:nil];

    self.cvcField = [[SPLTextFieldViewController alloc]
        initWithField:FormFieldTypeCvc
        title:@"Security Code"
        isRequired:YES
        placeholder:nil
        keyboardType:UIKeyboardTypeNumberPad
        textContentType:UITextContentTypeCreditCardSecurityCode
        onValidationChange:nil
        onSubmit:^{ [self submitForm]; }
        submitLabel:SpreedlySubmitLabelDone
        onFocus:nil];

    [self addFormField:self.firstNameField];
    [self addFormField:self.lastNameField];
    [self addFormField:self.cardNumberField];
    [self addFormField:self.cvcField];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.firstNameField becomeFirstResponder];
}
```

---

## CVVRecachingViewController

### Initialization

Create the recaching view controller with card details and payment method token:

```objc
// Replace with your own backend call that generates a Spreedly signature
[[YourBackend shared] generateSignatureWithCompletion:^(BOOL success, NSError * _Nullable error) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (success) {
            CVVRecachingViewController *recachingVC = [[CVVRecachingViewController alloc]
                initWithLastFourDigits:self.selectedCard.lastFourDigits
                cardType:self.selectedCard.cardType
                cardBrand:self.selectedCard.cardBrand
                paymentMethodToken:self.selectedCard.paymentMethodToken
                presentationMode:0  // 0 = sheet, 1 = alert
                labelText:@"CVV"
                placeholderText:@"123"
                buttonText:@"Confirm"
                cancelButtonText:@"Cancel"
                onProcessingResult:^(PaymentProcessingResult *result) {
                    if (result.isValidationFailed) {
                        NSLog(@"CVV validation failed");
                    } else if (result.isProcessing) {
                        NSLog(@"Recaching in progress...");
                    }
                }];

            recachingVC.modalPresentationStyle = UIModalPresentationFormSheet;
            [self presentViewController:recachingVC animated:YES completion:nil];
        }
    });
}];
```

### Presentation Mode

- `0` = sheet
- `1` = alert

### Custom Themes

Pass `SPLThemeConfig` instances for light and dark themes:

```objc
SPLThemeConfig *lightThemeConfig = [[SPLThemeConfig alloc]
    initWithPrimaryColor:[UIColor systemBlueColor]
    secondaryColor:[UIColor systemGrayColor]
    backgroundColor:[UIColor whiteColor]
    surfaceColor:[UIColor whiteColor]
    borderColor:[UIColor systemGray4Color]
    borderFocusedColor:[UIColor systemBlueColor]
    textColor:[UIColor blackColor]
    textSecondaryColor:[UIColor systemGrayColor]
    errorColor:[UIColor systemRedColor]
    placeholderColor:nil
    borderRadius:8.0];

CVVRecachingViewController *recachingVC = [[CVVRecachingViewController alloc]
    initWithLastFourDigits:lastFourDigits
    cardType:cardType
    cardBrand:cardBrand
    paymentMethodToken:token
    presentationMode:0
    labelText:@"CVV"
    placeholderText:@"123"
    buttonText:@"Confirm"
    cancelButtonText:@"Cancel"
    lightThemeConfig:lightThemeConfig
    darkThemeConfig:darkThemeConfig
    onProcessingResult:^(PaymentProcessingResult *result) { /* ... */ }];
```

### Delegate for Results

Set `[Spreedly shared].paymentDelegate = self` and implement `paymentDidComplete:` to receive the final recaching result. The `onProcessingResult` block receives validation and processing states; the delegate receives success or failure.

---

## 3DS Challenge

### Delegate Setup

Set `threeDSChallengeDelegate` before presenting the challenge:

```objc
[Spreedly shared].threeDSChallengeDelegate = self;
```

### Presenting the Challenge

```objc
- (void)present3DSChallengeWithTransactionToken:(NSString *)transactionToken {
    DoChallengeIfNeededViewController *challengeVC =
        [[DoChallengeIfNeededViewController alloc] initWithTransactionToken:transactionToken onDismiss:nil];
    [self presentViewController:challengeVC animated:YES completion:nil];
}
```

### Delegate Method

```objc
- (void)threeDSChallengeDidComplete:(ThreeDSChallengeResult *)result {
    if (result.isSuccess) {
        // Show success
    } else if (result.isFailure) {
        // Show error
    } else if (result.isCanceled) {
        // User canceled
    }
}
```

---

## Gateway-Specific 3DS

For gateway-specific 3DS (e.g., Worldpay), use `GatewaySpecific3DSObjCBridge` to finalize the transaction after the challenge completes:

- **`finalizeTransactionForTransactionToken:completeResponseData:error:`** — Finalizes a gateway-specific 3DS transaction with the transaction token and the complete response data from the challenge.

No `redirect_url`, Info.plist scheme, or `onOpenURL` handler is needed for gateway-specific 3DS. The SDK uses `ASWebAuthenticationSession` which stays in-app, and polling detects the terminal state and dismisses the session automatically.

See [3ds-gateway-specific.md](3ds-gateway-specific.md) for the full flow and setup.

---

## Additional Fields

Use `createCreditCardObjCWithAdditionalFields:metadata:` to create a credit card token with additional fields:

> **Note:** `createCreditCardObjC(additionalFields:metadata:)` does **not** have a `shouldRetain` parameter, unlike the Swift `createCreditCard` method.

```objc
NSDictionary *additionalFields = @{
    @"firstName": @"John",
    @"lastName": @"Doe",
    @"address1": @"123 Main St",
    @"city": @"Anytown",
    @"state": @"CA",
    @"zip": @"12345",
    @"country": @"US",
    @"phone_number": @"+1234567890",
    @"email": @"john.doe@example.com"
};

NSDictionary *metadata = @{@"orderId": @"12345"};

PaymentProcessingResult *processingResult = [[Spreedly shared]
    createCreditCardObjCWithAdditionalFields:additionalFields
    metadata:metadata];

if (processingResult.isValidationFailed) {
    if (processingResult.invalidFields.count > 0) {
        NSLog(@"Invalid SDK fields: %@", [processingResult.invalidFields description]);
    }
    if (processingResult.invalidAdditionalFields.count > 0) {
        NSLog(@"Invalid additional fields: %@", [processingResult.invalidAdditionalFields description]);
    }
}
```

---

## Offsite Payments

### Flow

1. Call `submitOffsitePaymentWithConfig:` to create the payment method.
2. Receive token via `paymentDidComplete:`.
3. Call your backend to purchase with the token; receive `transaction_token`.
4. Call `[SpreedlyOffsiteCheckout presentWithTransactionToken:]` to present Safari.
5. Handle redirect return in `scene:openURLContexts:` with `handleOffsiteReturnWithUrl:`.

### Example

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    [Spreedly shared].paymentDelegate = self;
}

- (void)startOffsiteFlow {
    OffsitePaymentConfig *config = [[OffsitePaymentConfig alloc]
        initWithPaymentMethodType:OffsitePaymentMethodTypeSprel
        redirectUrl:nil email:@"user@example.com" fullName:@"Test User"
        firstName:nil lastName:nil documentId:nil
        country:@"BR" countryCode:nil phoneNumber:@"123456789"
        address1:@"123 Main St" address2:nil city:@"City" state:@"ST" zip:@"12345"];
    [[Spreedly shared] submitOffsitePaymentWithConfig:config];
}

- (void)paymentDidComplete:(PaymentResult *)result {
    if (self.stage == OffsiteStageCreatingPaymentMethod && result.isSuccess && result.token.length > 0) {
        self.stage = OffsiteStagePurchasing;
        [self purchaseWithToken:result.token];
    } else if (self.stage == OffsiteStageCheckout) {
        if (result.isSuccess) {
            // Show success
        } else {
            // Show error
        }
    }
}

// After backend purchase succeeds, present checkout with the transaction token:
- (void)presentCheckoutWithTransactionToken:(NSString *)transactionToken {
    self.stage = OffsiteStageCheckout;
    [SpreedlyOffsiteCheckout presentWithTransactionToken:transactionToken];
}
```

---

## Stripe APM

Present Stripe APM checkout (iDEAL, Bancontact, EPS, P24, SEPA) with `SpreedlyStripeAPMCheckout presentWithConfig:`:

```objc
[Spreedly shared].paymentDelegate = self;

// After backend creates pending purchase:
StripeAPMConfig *config = [[StripeAPMConfig alloc]
    initWithPublishableKey:publishableKey
    clientSecret:tx.stripePaymentIntentClientSecret
    transactionToken:tx.token
    merchantDisplayName:@"Your Store"
    returnURL:@"myapp://stripe-redirect"];
[SpreedlyStripeAPMCheckout presentWithConfig:config];
```

Handle `paymentDidComplete:` for success or failure. Forward URLs in `scene:openURLContexts:` to `handleOffsiteReturnWithUrl:` so the SDK can process Stripe redirect returns.

### StripeAPMTypeHelper

Use `apmTypeValueForType:` (Swift: `apmTypeValue(for:)`) to get the string value for a Stripe APM type:

```objc
NSString *apmValue = [StripeAPMTypeHelper apmTypeValueForType:StripeAPMTypeIdeal];
```

---

## EBANX

EBANX supports Pix, Boleto Bancario, OXXO, and NuPay. See `EbanxPaymentFlowViewController` for a full example. Build `OffsitePaymentConfig` with EBANX payment types (`OffsitePaymentMethodTypePix`, `OffsitePaymentMethodTypeBoletoBancario`, `OffsitePaymentMethodTypeOxxo`, `OffsitePaymentMethodTypeNupay`). For Brazil (Pix, Boleto, NuPay), provide a `DocumentId`; for Mexico (OXXO), omit it.

```objc
[Spreedly shared].paymentDelegate = self;

// For Pix, Boleto, or NuPay (Brazil) - DocumentId required:
DocumentId *documentId = [[DocumentId alloc] initWithKey:DocumentIdKeyDocumentId
                                                   value:@"853.513.468-93"
                                               customKey:nil];
OffsitePaymentConfig *config = [[OffsitePaymentConfig alloc]
    initWithPaymentMethodType:OffsitePaymentMethodTypePix  // or OffsitePaymentMethodTypeBoletoBancario, OffsitePaymentMethodTypeNupay
    redirectUrl:nil
    email:@"test@test.com"
    fullName:@"Ana Santos Araujo"
    firstName:nil lastName:nil
    documentId:documentId
    country:@"BR" countryCode:nil
    phoneNumber:@"8522847035"
    address1:@"Rua E, 1040" address2:nil
    city:@"Maracanaú" state:@"CE" zip:@"12345"];

[[Spreedly shared] submitOffsitePaymentWithConfig:config];
```

Handle `paymentDidComplete:` for the token. After your backend purchase succeeds, call `[SpreedlyOffsiteCheckout presentWithTransactionToken:transactionToken]` to present the checkout. Result handling is via `paymentDidComplete:`.

---

## Braintree

### Configuration

`[BraintreeURLHandlerObjC configure]` is not needed. The SDK handles Braintree URL routing automatically.

### Presenting Checkout

```objc
[Spreedly shared].paymentDelegate = self;

BraintreeCheckoutConfig *config = [[BraintreeCheckoutConfig alloc]
    initWithTransactionToken:tx.token
    paymentType:BraintreePaymentTypePaypal  // or BraintreePaymentTypeVenmo
    merchantDisplayName:@""
    clientToken:tx.braintreeClientToken
    amount:amountString
    currencyCode:@"USD"];
[SpreedlyBraintreeCheckout presentWithConfig:config];
```

### URL Handling

In `scene:openURLContexts:`, call `BraintreeURLHandlerObjC handleOpenWithUrl:` first; if it returns `YES`, return. Otherwise call `handleOffsiteReturnWithUrl:` for other offsite returns.

---

## Theming

Use `SPLThemeConfig` with `UIColor` parameters for custom themes:

```objc
SPLThemeConfig *themeConfig = [[SPLThemeConfig alloc]
    initWithPrimaryColor:[UIColor systemBlueColor]
    secondaryColor:[UIColor systemGrayColor]
    backgroundColor:[UIColor whiteColor]
    surfaceColor:[UIColor whiteColor]
    borderColor:[UIColor systemGray4Color]
    borderFocusedColor:[UIColor systemBlueColor]
    textColor:[UIColor blackColor]
    textSecondaryColor:[UIColor systemGrayColor]
    errorColor:[UIColor systemRedColor]
    placeholderColor:nil
    borderRadius:8.0];
```

Set globally or pass to individual components that support theme configuration. See [theme-and-styling.md](theme-and-styling.md) for full theming documentation.

### SpreedlyThemeManagerObjC

Use `SpreedlyThemeManagerObjC` to set a global theme applied to all SDK components:

| Method (abbreviated) | Purpose |
|--------|---------|
| `setGlobalThemeWithLightConfig:darkConfig:` | Sets light and dark `SPLThemeConfig` instances |
| `setGlobalThemeWithConfig:` | Sets a single `SPLThemeConfig` |
| `setGlobalThemeWithHexColorsWithPrimaryColorHex:...borderRadius:` | Sets a single theme using hex color strings (full selector includes all color params) |
| `setGlobalThemeWithLightHexColorsWithLightPrimaryColorHex:...borderRadius:` | Sets light + dark themes using hex color strings |
| `setGlobalThemeWithColorsWithPrimaryColor:...borderRadius:` | Sets a single theme using `UIColor` objects |
| `setGlobalThemeWithLightColorsWithLightPrimaryColor:...borderRadius:` | Sets light + dark themes using `UIColor` objects |

> **Note:** The hex/UIColor selectors have long generated names from Swift. Use Xcode autocomplete to fill in the full parameter list. See the example below.

Example:

```objc
// Light and dark configs
SPLThemeConfig *lightTheme = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemBlueColor] ...];
SPLThemeConfig *darkTheme = [[SPLThemeConfig alloc] initWithPrimaryColor:[UIColor systemBlueColor] ...];
[SpreedlyThemeManagerObjC setGlobalThemeWithLightConfig:lightTheme darkConfig:darkTheme];

// Or with hex colors
[SpreedlyThemeManagerObjC setGlobalThemeWithHexColorsWithPrimaryColorHex:@"#007AFF"
    secondaryColorHex:nil
    formBorderColorHex:nil
    formBackgroundColorHex:@"#FFFFFF"
    fieldBackgroundColorHex:nil
    fieldLabelColorHex:nil
    borderRadius:8.0];
```

---

## URL Handling

Handle incoming URLs in `SceneDelegate`:

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>
// If using Braintree, also import:
// #import <SpreedlyBraintree/SpreedlyBraintree-Swift.h>

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    NSURL *url = URLContexts.allObjects.firstObject.URL;
    if (!url) return;

    // If using Braintree: try Braintree first
    if ([BraintreeURLHandlerObjC handleOpenWithUrl:url]) return;

    // Offsite and Stripe APM redirects
    BOOL isSpreedlyURL = [[Spreedly shared] handleOffsiteReturnWithUrl:url];
    if (!isSpreedlyURL) {
        // Handle other deep links
    }
}
```

Call `BraintreeURLHandlerObjC handleOpenWithUrl:` first when using Braintree; otherwise Braintree return URLs may be incorrectly handled as offsite returns.

---

## Cleanup and Teardown

Proper cleanup prevents memory leaks, dangling delegates, and stale validation state.

### Reset Validation State

Call `reset` in `viewWillDisappear:` for custom form views that use `SPLTextFieldViewController`. This stops secure value collection, clears error state, and removes Combine subscriptions. It does **not** reset validation parameters (`allowBlankName`, etc.) -- reset those individually if needed:

```objc
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[Spreedly shared] reset];
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankName value:NO];
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowExpiredDate value:NO];
    [[Spreedly shared] setParamWithParameter:ValidationParamAllowBlankDate value:NO];
}
```

### Nil Delegates in Dealloc

If your view controller sets itself as a delegate (e.g., `paymentDelegate` or `threeDSChallengeDelegate`), nil it in `dealloc` to avoid crashes from dangling references:

```objc
- (void)dealloc {
    if ([Spreedly shared].paymentDelegate == self) {
        [Spreedly shared].paymentDelegate = nil;
    }
}
```

### Remove Child View Controllers

When using `SPLTextFieldViewController` as child VCs, remove them in `viewDidDisappear:`:

```objc
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
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
}
```

### Remove Notification Observers

For gateway-specific 3DS, remove the trigger observer in `dealloc`:

```objc
- (void)dealloc {
    if (self.gatewaySpecificTriggerObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.gatewaySpecificTriggerObserver];
        self.gatewaySpecificTriggerObserver = nil;
    }
}
```

### Cleanup Checklist (Objective-C)

| Pattern | When | How |
|---------|------|-----|
| Reset state + validation | Custom form dismissed | `[[Spreedly shared] reset]` + `setParamWithParameter:value:` in `viewWillDisappear:` |
| Nil delegates | VC deallocated | Check `== self` before nil-ing in `dealloc` |
| Remove child VCs | Custom form dismissed | `willMoveToParent:nil`, `removeFromSuperview`, `removeFromParent` in `viewDidDisappear:` |
| Remove notification observers | VC deallocated | `removeObserver:` in `dealloc` |
| Remove keyboard observers | VC not visible | `removeObserver:` in `viewWillDisappear:` |

---

## Submit Label Values

When using Objective-C, use the integer raw values for `SpreedlySubmitLabel`:

| Value | Constant | Purpose |
|-------|----------|---------|
| 0 | SpreedlySubmitLabelReturn | Return |
| 1 | SpreedlySubmitLabelDone | Done (final field) |
| 2 | SpreedlySubmitLabelGo | Go |
| 3 | SpreedlySubmitLabelSearch | Search |
| 4 | SpreedlySubmitLabelSend | Send |
| 5 | SpreedlySubmitLabelNext | Next (form navigation) |
| 6 | SpreedlySubmitLabelJoin | Join |
| 7 | SpreedlySubmitLabelRoute | Route |
| 8 | SpreedlySubmitLabelContinue | Continue |

---

## Telemetry Events

Use `SpreedlyTelemetryObjCBridge` to emit structured telemetry events from Objective-C. Each method mirrors a `TelemetryEvents` Swift builder with ObjC-compatible signatures.

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>

// Track a method invocation from your module
[SpreedlyTelemetryObjCBridge sdkMethodInvokedWithMethodName:@"checkout" module:@"my-app"];

// Report a successful payment with duration
[SpreedlyTelemetryObjCBridge paymentMethodCreatedWithDurationMs:1200
                                              paymentMethodType:@"credit_card"];

// Report a payment failure
[SpreedlyTelemetryObjCBridge paymentMethodFailedWithErrorCode:@"validation_error"
                                                 errorMessage:@"Card number invalid"
                                                    errorType:@"client_validation"
                                                   durationMs:1200];

// API request with optional status code (pass nil when unavailable)
[SpreedlyTelemetryObjCBridge apiRequestCompletedWithHttpMethod:@"POST"
                                                           url:@"payment_methods"
                                                    durationMs:350
                                                       success:YES
                                                    statusCode:@(200)];
```

**Default parameters:** Swift default parameters are not available in Objective-C. The bridge provides separate overloads instead. For example, `paymentMethodCreated` has two variants:

```objc
// Without paymentMethodType (defaults to "credit_card")
[SpreedlyTelemetryObjCBridge paymentMethodCreatedWithDurationMs:800];

// With explicit paymentMethodType
[SpreedlyTelemetryObjCBridge paymentMethodCreatedWithDurationMs:800
                                              paymentMethodType:@"bank_account"];
```

**Optional integers:** Parameters that are `Int?` in Swift become `NSNumber *` in the bridge. Pass `nil` when the value is not available (e.g., `statusCode` when a request fails without an HTTP response).

**Duration tracking:**

> **Note:** `FlowDurationTracker` is not `@objc`-exposed. Use it from Swift or track duration manually in Objective-C:

```objc
// Track duration manually in Objective-C
NSDate *startTime = [NSDate date];

// ... your flow logic ...

NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime] * 1000;
int64_t durationMs = (int64_t)elapsed;
```

See [Structured Telemetry Events](getting-started.md#structured-telemetry-events) for the full event reference table and detailed usage guidance.

---

## Related Documentation

- [getting-started.md](getting-started.md) - Prerequisites, installation, and basic SDK setup
- [express-checkout.md](express-checkout.md) - Pre-built CardFormDropIn payment form
- [custom-payment-forms.md](custom-payment-forms.md) - Building custom payment forms with SPLTextField
- [recaching.md](recaching.md) - CVV recaching for saved payment methods
- [3ds-global.md](3ds-global.md) - 3DS Global (Forter) authentication
- [3ds-gateway-specific.md](3ds-gateway-specific.md) - Gateway-specific 3DS (e.g. Worldpay)
- [offsite-payments.md](offsite-payments.md) - Offsite payments (PayPal, Sprel)
- [stripe-apm.md](stripe-apm.md) - Stripe APM (iDEAL, Bancontact, EPS, P24, SEPA)
- [braintree-apm.md](braintree-apm.md) - Braintree (PayPal/Venmo)
- [ebanx-apm.md](ebanx-apm.md) - EBANX (Pix, Boleto, OXXO, NuPay)
- [theme-and-styling.md](theme-and-styling.md) - Theming and customization
- [error-handling.md](error-handling.md) - Error types and handling
- [security.md](security.md) - Screen prevention, PCI compliance, security
