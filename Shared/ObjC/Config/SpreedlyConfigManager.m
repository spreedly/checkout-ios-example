//
//  SpreedlyConfigManager.m
//  SpreedlySDKExampleObjectiveC
//
//  Created by Vinay Naikade on 12/08/25.
//
//  This manager sets up Spreedly configuration and global theme
//  for all examples in the Objective-C sample app.
//

#import "SpreedlyConfigManager.h"
#import <SpreedlyCore/SpreedlyCore-Swift.h>
// #import <SpreedlyUI/SpreedlyUI-Swift.h>
#import "SignatureSecurityService.h"
#import "RetainPaymentMethodAPIClient.h"
#import "FetchPaymentMethodsAPIClient.h"
#import "PurchaseAPIClient.h"
#import "SignatureServerClient.h"

// Forward declaration for Swift classes
// @class SpreedlyThemeManagerObjC;
// @class SPLThemeConfig;

@interface SpreedlyConfigManager ()

@property (nonatomic, strong) NSString *environmentKey;
@property (nonatomic, strong) NSString *forterSiteId;
@property (nonatomic, strong) NSString *serverURL;
@property (nonatomic, strong) NSString *paymentMethodsBaseURL;
@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, copy, readwrite) NSString *applePayMerchantId;

@end

@implementation SpreedlyConfigManager

static SpreedlyConfigManager *_shared = nil;

+ (SpreedlyConfigManager *)shared {
    return _shared;
}

+ (NSString *)infoPlistValueForKey:(NSString *)key {
    return [[NSBundle mainBundle] infoDictionary][key] ?: @"";
}

- (instancetype)init {
    if (self = [super init]) {
        self.environmentKey       = [SpreedlyConfigManager infoPlistValueForKey:@"SpreedlyEnvironmentKey"];
        self.forterSiteId         = [SpreedlyConfigManager infoPlistValueForKey:@"SpreedlyForterSiteId"];
        self.serverURL            = [SpreedlyConfigManager infoPlistValueForKey:@"SpreedlyServerURL"];
        self.paymentMethodsBaseURL = [SpreedlyConfigManager infoPlistValueForKey:@"SpreedlyBaseURL"];
        self.apiKey               = [SpreedlyConfigManager infoPlistValueForKey:@"SpreedlyApiKey"];
        self.applePayMerchantId   = [SpreedlyConfigManager infoPlistValueForKey:@"SpreedlyApplePayMerchantId"];

        [Spreedly initializeSDK];

        NSString *applePayError = self.applePayMerchantIdConfigurationError;
        if (applePayError.length > 0) {
            NSLog(@"[SpreedlyExample] Apple Pay config: %@", applePayError);
        }
    }
    return self;
}

+ (void)setup {
    _shared = [[SpreedlyConfigManager alloc] init];
    
    // // Set global theme for all SpreedlyUI components across all examples
    // SPLThemeConfig *globalTheme = [[SPLThemeConfig alloc] initWithPrimaryColorHex:@"#0077C8"
    //     secondaryColorHex:@"#AFB4B5"
    //     formBorderColorHex:@"#D9D9D9"
    //     formBackgroundColorHex:@"#FFFFFF"
    //     fieldBackgroundColorHex:@"#F8F9FA"
    //     fieldLabelColorHex:@"#6C757D"
    //     borderRadius:8.0];
    // [SpreedlyThemeManagerObjC setGlobalThemeWithConfig:globalTheme];
}

- (void)fetchSignedAuthWithCompletion:(void (^)(SpreedlyConfig * _Nullable config, NSError * _Nullable error))completion {
    ServerSecurityConfig *config = [[ServerSecurityConfig alloc] initWithServerURL:self.serverURL
                                                                             apiKey:self.apiKey.length > 0 ? self.apiKey : nil
                                                                     environmentKey:self.environmentKey];

    [SignatureSecurityService setupServerBasedSecurityWithConfig:config completion:^(SecuritySetupResult * _Nullable result) {
        if (!result.success || !result.signatureParams) {
            NSError *error = result.error ?: [NSError errorWithDomain:@"SpreedlyConfigManager"
                                                                 code:0
                                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate signature parameters"}];
            completion(nil, error);
            return;
        }
        // Signature parameters generated (values not logged for security)
        SpreedlyConfig *spreedlyConfig = [[SpreedlyConfig alloc] initWithEnvironmentKey:self.environmentKey];
        spreedlyConfig.forterSiteId = self.forterSiteId;
        spreedlyConfig.certificateToken = result.signatureParams.certificateToken;
        spreedlyConfig.nonce = result.signatureParams.nonce;
        spreedlyConfig.signature = result.signatureParams.signature;
        spreedlyConfig.timestamp = [NSString stringWithFormat:@"%ld", (long)result.signatureParams.timestamp];
        completion(spreedlyConfig, nil);
    }];
}

- (void)generateSignatureWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    [self fetchSignedAuthWithCompletion:^(SpreedlyConfig * _Nullable spreedlyConfig, NSError * _Nullable error) {
        if (!spreedlyConfig) {
            if (completion) {
                completion(NO, error);
            }
            return;
        }

        [Spreedly setupWithConfig:spreedlyConfig];

        if (Spreedly.initializationError != nil) {
            NSError *blockError = [NSError errorWithDomain:@"SpreedlyConfigManager"
                                                      code:1
                                                  userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"SDK blocked: %@", Spreedly.initializationError.message]}];
            if (completion) {
                completion(NO, blockError);
            }
            return;
        }

        if (completion) {
            completion(YES, nil);
        }
    }];
}

- (RetainPaymentMethodAPIClient *)createRetainPaymentMethodAPIClient {
    ServerConfig *config = [[ServerConfig alloc] initWithBaseURL:self.paymentMethodsBaseURL
                                                  timeoutInterval:30.0
                                                           apiKey:self.apiKey.length > 0 ? self.apiKey : nil];
    return [[RetainPaymentMethodAPIClient alloc] initWithConfig:config];
}

- (FetchPaymentMethodsAPIClient *)createFetchPaymentMethodsAPIClient {
    ServerConfig *config = [[ServerConfig alloc] initWithBaseURL:self.paymentMethodsBaseURL
                                                timeoutInterval:30.0
                                                         apiKey:self.apiKey.length > 0 ? self.apiKey : nil];
    return [[FetchPaymentMethodsAPIClient alloc] initWithConfig:config];
}

- (PurchaseAPIClient *)createPurchaseAPIClient {
    ServerConfig *config = [[ServerConfig alloc] initWithBaseURL:self.paymentMethodsBaseURL
                                                  timeoutInterval:30.0
                                                           apiKey:nil];
    return [[PurchaseAPIClient alloc] initWithConfig:config];
}

- (NSString *)stripePublishableKey {
    return [SpreedlyConfigManager infoPlistValueForKey:@"StripePublishableKey"];
}

- (nullable NSString *)applePayMerchantIdConfigurationError {
    NSString *trimmed = [self.applePayMerchantId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return @"Apple Pay Merchant ID is empty. Set SPREEDLY_APPLE_PAY_MERCHANT_ID in SpreedlyKeys.xcconfig to your real Merchant ID from Apple Developer, enable Apple Pay on the app target with the same ID, then rebuild.";
    }
    // Template-only values from SpreedlyKeys.xcconfig.example. Real IDs may contain "example".
    NSSet<NSString *> *templates = [NSSet setWithArray:@[
        @"merchant.com.your.example",
        @"merchant.com.example"
    ]];
    if ([templates containsObject:trimmed.lowercaseString]) {
        return [NSString stringWithFormat:
                @"Apple Pay Merchant ID is still the template value (%@). Set SPREEDLY_APPLE_PAY_MERCHANT_ID in SpreedlyKeys.xcconfig to the Merchant ID you created in Apple Developer (must match the Apple Pay entitlement), then rebuild.",
                trimmed];
    }
    return nil;
}

@end
