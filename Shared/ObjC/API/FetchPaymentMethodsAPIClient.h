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

/// The saved payment methods kept on the device, read on a background queue.
/// @param completion Called on a background queue with the response or an error; dispatch to main for UI work.
- (void)fetchPaymentMethodsWithCompletion:(void (^)(FetchPaymentMethodsResponse * _Nullable response, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END

