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
        
        [Spreedly initializeSDK];
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

- (void)generateSignatureWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion {
    // Create server security config
    ServerSecurityConfig *config = [[ServerSecurityConfig alloc] initWithServerURL:self.serverURL
                                                                             apiKey:self.apiKey.length > 0 ? self.apiKey : nil
                                                                     environmentKey:self.environmentKey];
    
    // Setup server-based security
    [SignatureSecurityService setupServerBasedSecurityWithConfig:config completion:^(SecuritySetupResult * _Nullable result) {
        if (!result.success) {
            if (completion) {
                completion(NO, result.error);
            }
            return;
        }
        
        if (!result.signatureParams) {
            NSError *signatureError = [NSError errorWithDomain:@"SpreedlyConfigManager"
                                                          code:0
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate signature parameters"}];
            if (completion) {
                completion(NO, signatureError);
            }
            return;
        }
        
        // Signature parameters generated (values not logged for security)
        // Setup Spreedly with config including forterSiteId
        SpreedlyConfig *spreedlyConfig = [[SpreedlyConfig alloc] initWithEnvironmentKey:self.environmentKey];
        spreedlyConfig.forterSiteId = self.forterSiteId;
        spreedlyConfig.certificateToken = result.signatureParams.certificateToken;
        spreedlyConfig.nonce = result.signatureParams.nonce;
        spreedlyConfig.signature = result.signatureParams.signature;
        spreedlyConfig.timestamp = [NSString stringWithFormat:@"%ld", (long)result.signatureParams.timestamp];
        
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

@end 
