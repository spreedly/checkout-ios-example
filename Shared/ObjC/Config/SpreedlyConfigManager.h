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

@interface SpreedlyConfigManager : NSObject

@property (class, nonatomic, strong, readonly) SpreedlyConfigManager *shared;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (void)setup;

- (void)generateSignatureWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;

- (RetainPaymentMethodAPIClient *)createRetainPaymentMethodAPIClient;

- (FetchPaymentMethodsAPIClient *)createFetchPaymentMethodsAPIClient;

- (PurchaseAPIClient *)createPurchaseAPIClient;

/// Stripe publishable key for PaymentSheet (Stripe APM flow).
@property (nonatomic, copy, readonly) NSString *stripePublishableKey;

@end

NS_ASSUME_NONNULL_END 
