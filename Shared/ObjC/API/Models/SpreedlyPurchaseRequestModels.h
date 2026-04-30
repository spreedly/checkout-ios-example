//
//  SpreedlyPurchaseRequestModels.h
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Request body for direct Spreedly Core API purchase.
/// Wraps fields inside a "transaction" key: { "transaction": { ... } }
@interface SpreedlyPurchaseTransactionRequest : NSObject

@property (nonatomic, assign, readonly) double amount;
@property (nonatomic, copy, readonly) NSString *browserInfo;
@property (nonatomic, copy, readonly) NSString *currencyCode;
@property (nonatomic, copy, readonly) NSString *paymentMethodToken;
@property (nonatomic, copy, readonly) NSString *ip;
@property (nonatomic, copy, readonly) NSString *redirectUrl;
@property (nonatomic, copy, readonly) NSString *channel;
@property (nonatomic, copy, readonly) NSString *callbackUrl;
@property (nonatomic, copy, readonly, nullable) NSString *scaProviderKey;

- (instancetype)initWithAmount:(NSDecimalNumber *)amount
                   browserInfo:(NSString *)browserInfo
                  currencyCode:(NSString *)currencyCode
            paymentMethodToken:(NSString *)paymentMethodToken
                            ip:(NSString *)ip
                   redirectUrl:(NSString *)redirectUrl
                       channel:(NSString *)channel
                   callbackUrl:(NSString *)callbackUrl
                scaProviderKey:(nullable NSString *)scaProviderKey;

/// Returns the full request body wrapped in "transaction" key
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
