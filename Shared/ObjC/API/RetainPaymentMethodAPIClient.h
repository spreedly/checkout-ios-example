//
//  RetainPaymentMethodAPIClient.h
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ServerConfig, RetainPaymentMethodResponse;

/// API client for retaining payment methods
@interface RetainPaymentMethodAPIClient : NSObject

- (instancetype)initWithConfig:(ServerConfig *)config;

/// Uses `session` for requests instead of one built from `config`, so tests can answer them.
- (instancetype)initWithConfig:(ServerConfig *)config session:(NSURLSession *)session NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Retains a payment method
/// @param token The payment method token to retain
/// @param completion Completion block with response or error
- (void)retainPaymentMethodWithToken:(NSString *)token
                           completion:(void (^)(RetainPaymentMethodResponse * _Nullable response, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END

