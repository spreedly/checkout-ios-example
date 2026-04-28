//
//  PurchaseRequestModels.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Purchase Transaction Request (3DS Global)
@interface PurchaseTransactionRequest : NSObject

@property (nonatomic, assign, readonly) double amount;
@property (nonatomic, copy, readonly) NSString *currencyCode;
@property (nonatomic, copy, readonly) NSString *paymentMethodToken;

- (instancetype)initWithAmount:(NSDecimalNumber *)amount
                   currencyCode:(NSString *)currencyCode
             paymentMethodToken:(NSString *)paymentMethodToken;

- (NSDictionary *)toDictionary;

@end

/// Purchase Transaction Request (Gateway-Specific 3DS)
@interface GatewaySpecificPurchaseTransactionRequest : NSObject

@property (nonatomic, assign, readonly) double amount;
@property (nonatomic, copy, readonly) NSString *currencyCode;
@property (nonatomic, copy, readonly) NSString *paymentMethodToken;
@property (nonatomic, assign, readonly) BOOL attempt3DSecure;

- (instancetype)initWithAmount:(NSDecimalNumber *)amount
                   currencyCode:(NSString *)currencyCode
             paymentMethodToken:(NSString *)paymentMethodToken
                 attempt3DSecure:(BOOL)attempt3DSecure;

- (NSDictionary *)toDictionary;

@end

/// Offsite Purchase Request (merchant backend POST /offsite-purchase; gateway, redirect_url, callback_url, channel)
@interface OffsitePurchaseRequest : NSObject

@property (nonatomic, copy, readonly) NSString *gateway;
@property (nonatomic, assign, readonly) double amount;
@property (nonatomic, copy, readonly) NSString *currencyCode;
@property (nonatomic, copy, readonly) NSString *paymentMethodToken;
@property (nonatomic, copy, readonly) NSString *redirectUrl;
@property (nonatomic, copy, readonly) NSString *callbackUrl;
@property (nonatomic, copy, readonly) NSString *channel;

- (instancetype)initWithGateway:(NSString *)gateway
                         amount:(NSDecimalNumber *)amount
                  currencyCode:(NSString *)currencyCode
            paymentMethodToken:(NSString *)paymentMethodToken
                   redirectUrl:(NSString *)redirectUrl
                  callbackUrl:(NSString *)callbackUrl
                      channel:(NSString *)channel;

- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END
