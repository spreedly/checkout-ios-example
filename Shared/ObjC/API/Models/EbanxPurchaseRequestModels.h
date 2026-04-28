//
//  EbanxPurchaseRequestModels.h
//  MerchantExample
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Transaction body for EBANX purchase. Encodes to the inner "transaction" object.
@interface EbanxPurchaseTransaction : NSObject

@property (nonatomic, assign, readonly) double amount;
@property (nonatomic, copy, readonly) NSString *currencyCode;
@property (nonatomic, copy, readonly) NSString *paymentMethodToken;
@property (nonatomic, copy, readonly) NSString *redirectUrl;
@property (nonatomic, copy, readonly) NSString *callbackUrl;
@property (nonatomic, copy, readonly) NSString *channel;
@property (nonatomic, copy, readonly, nullable) NSString *document;

- (instancetype)initWithAmount:(NSDecimalNumber *)amount
                 currencyCode:(NSString *)currencyCode
           paymentMethodToken:(NSString *)paymentMethodToken
                  redirectUrl:(NSString *)redirectUrl
                 callbackUrl:(NSString *)callbackUrl
                     channel:(NSString *)channel
                    document:(nullable NSString *)document;

/// Returns the transaction as a dictionary (snake_case keys for API).
- (NSDictionary *)toDictionary;

@end

/// Request wrapper for EBANX purchase. Wraps transaction in "transaction" key: { "transaction": { ... } }
@interface EbanxPurchaseRequest : NSObject

@property (nonatomic, strong, readonly) EbanxPurchaseTransaction *transaction;

- (instancetype)initWithTransaction:(EbanxPurchaseTransaction *)transaction;

/// Returns the full request body: @{ @"transaction": [transaction toDictionary] }
- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
