//
//  FetchPaymentMethodsAPIClient.h
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ServerConfig;
@class FetchPaymentMethodsResponse;

/// API client for fetching payment methods
@interface FetchPaymentMethodsAPIClient : NSObject

- (instancetype)initWithConfig:(ServerConfig *)config;

/// Fetches all payment methods
/// @param completion Completion block with response or error
- (void)fetchPaymentMethodsWithCompletion:(void (^)(FetchPaymentMethodsResponse * _Nullable response, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END

