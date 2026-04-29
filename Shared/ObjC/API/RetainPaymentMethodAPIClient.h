//
//  RetainPaymentMethodAPIClient.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ServerConfig, RetainPaymentMethodResponse;

/// API client for retaining payment methods
@interface RetainPaymentMethodAPIClient : NSObject

- (instancetype)initWithConfig:(ServerConfig *)config;

/// Retains a payment method
/// @param token The payment method token to retain
/// @param completion Completion block with response or error
- (void)retainPaymentMethodWithToken:(NSString *)token
                           completion:(void (^)(RetainPaymentMethodResponse * _Nullable response, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END

