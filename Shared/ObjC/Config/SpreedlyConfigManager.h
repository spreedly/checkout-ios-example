//
//  SpreedlyConfigManager.h
//  SpreedlySDKExampleObjectiveC
//
//  Created by Vinay Naikade on 12/08/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class RetainPaymentMethodAPIClient;
@class FetchPaymentMethodsAPIClient;
@class PurchaseAPIClient;
@class SpreedlyConfig;

@interface SpreedlyConfigManager : NSObject

@property (class, nonatomic, strong, readonly) SpreedlyConfigManager *shared;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (void)setup;

- (void)generateSignatureWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/// Fresh signed auth from the demo backend, without applying it. Signed auth works for one request
/// only, so Apple Pay asks for a new one on every payment attempt.
- (void)fetchSignedAuthWithCompletion:(void (^)(SpreedlyConfig * _Nullable config, NSError * _Nullable error))completion;

- (RetainPaymentMethodAPIClient *)createRetainPaymentMethodAPIClient;

- (FetchPaymentMethodsAPIClient *)createFetchPaymentMethodsAPIClient;

- (PurchaseAPIClient *)createPurchaseAPIClient;

/// Stripe publishable key for PaymentSheet (Stripe APM flow).
@property (nonatomic, copy, readonly) NSString *stripePublishableKey;

/// Merchant ID from Info.plist (`SpreedlyApplePayMerchantId` / `SPREEDLY_APPLE_PAY_MERCHANT_ID`).
@property (nonatomic, copy, readonly) NSString *applePayMerchantId;

/// `nil` when configured; otherwise a message describing the fix (empty or placeholder ID).
@property (nonatomic, copy, readonly, nullable) NSString *applePayMerchantIdConfigurationError;

@end

NS_ASSUME_NONNULL_END 
