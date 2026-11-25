//
//  PurchaseAPIClient.h
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// `userInfo` keys on a purchase error: the HTTP status (NSNumber) and the server's message (NSString).
FOUNDATION_EXPORT NSString * const PurchaseAPIStatusCodeKey;
FOUNDATION_EXPORT NSString * const PurchaseAPIServerMessageKey;

@class ServerConfig;
@class PurchaseResponse;

/// API client for purchase transactions
@interface PurchaseAPIClient : NSObject

- (instancetype)initWithConfig:(ServerConfig *)config;

/// Uses `session` for requests instead of one built from `config`, so tests can answer them.
- (instancetype)initWithConfig:(ServerConfig *)config session:(NSURLSession *)session NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Performs a purchase transaction
/// @param paymentMethodToken Token of the payment method to use
/// @param amount Purchase amount in cents (e.g., 49900 for $499.00)
/// @param currencyCode ISO 4217 currency code (e.g. "USD", "BRL")
/// @param useGatewaySpecific3DS When YES, includes attempt_3dsecure in the request
/// @param completion Completion block with response or error
- (void)purchaseWithPaymentMethodToken:(NSString *)paymentMethodToken
                                 amount:(NSDecimalNumber *)amount
                          currencyCode:(NSString *)currencyCode
                  useGatewaySpecific3DS:(BOOL)useGatewaySpecific3DS
                            completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Completes a gateway-specific 3DS transaction via complete.json endpoint
/// @param transactionToken Token of the transaction to complete
/// @param completion Completion block with response data or error
- (void)completeTransactionWithToken:(NSString *)transactionToken
                          completion:(void (^)(NSData * _Nullable responseData, NSError * _Nullable error))completion;

/// Performs a purchase transaction (default: useGatewaySpecific3DS = NO)
- (void)purchaseWithPaymentMethodToken:(NSString *)paymentMethodToken
                                 amount:(NSDecimalNumber *)amount
                          currencyCode:(NSString *)currencyCode
                            completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Performs a purchase without Spreedly 3DS (POST {baseURL}/simple-purchase). Use it for payment methods the
/// wallet already authenticated, such as Apple Pay: Spreedly 3DS accepts credit cards only.
/// @param amount Purchase amount in minor units (e.g. cents)
- (void)simplePurchaseWithPaymentMethodToken:(NSString *)paymentMethodToken
                                       amount:(NSDecimalNumber *)amount
                                 currencyCode:(NSString *)currencyCode
                                   completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Performs an offsite purchase via merchant backend (POST {baseURL}/offsite-purchase). Gateway: "sprel" or "paypal".
- (void)offsitePurchaseWithGateway:(NSString *)gateway
             paymentMethodToken:(NSString *)paymentMethodToken
                         amount:(NSDecimalNumber *)amount
                  currencyCode:(NSString *)currencyCode
                   redirectUrl:(nullable NSString *)redirectUrl
                  callbackUrl:(NSString *)callbackUrl
                    completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Performs an EBANX purchase via merchant backend (POST {baseURL}/create-purchase). Gateway: "ebanx".
- (void)ebanxPurchaseWithPaymentMethodToken:(NSString *)paymentMethodToken
                                     amount:(NSDecimalNumber *)amount
                              currencyCode:(NSString *)currencyCode
                               redirectUrl:(nullable NSString *)redirectUrl
                              callbackUrl:(NSString *)callbackUrl
                                  document:(nullable NSString *)document
                                completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Stripe APM pending purchase (POST {baseURL}/create-purchase). Gateway: "stripe", payment_method stripe_apm + apm_types.
- (void)stripeAPMPendingPurchaseWithAmount:(NSDecimalNumber *)amount
                             currencyCode:(NSString *)currencyCode
                              redirectUrl:(nullable NSString *)redirectUrl
                             callbackUrl:(NSString *)callbackUrl
                                apmTypes:(NSArray<NSString *> *)apmTypes
                           radarSessionId:(nullable NSString *)radarSessionId
                              completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Braintree purchase (POST {baseURL}/create-purchase, gateway "braintree").
- (void)braintreePurchaseWithAmount:(NSDecimalNumber *)amount
                      currencyCode:(NSString *)currencyCode
                       redirectUrl:(nullable NSString *)redirectUrl
                      callbackUrl:(NSString *)callbackUrl
                 paymentMethodType:(NSString *)paymentMethodType
                        completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Braintree confirm (POST {baseURL}/transactions/{token}/confirm).
/// Successful: nonce (+ optional deviceData). Failed/Cancelled: message (no nonce).
- (void)braintreeConfirmWithTransactionToken:(NSString *)transactionToken
                                       state:(NSString *)state
                                       nonce:(nullable NSString *)nonce
                                  deviceData:(nullable NSString *)deviceData
                                     message:(nullable NSString *)message
                           paymentMethodType:(NSString *)paymentMethodType
                                  completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END


