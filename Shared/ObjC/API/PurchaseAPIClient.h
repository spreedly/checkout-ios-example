//
//  PurchaseAPIClient.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ServerConfig;
@class PurchaseResponse;

/// API client for purchase transactions
@interface PurchaseAPIClient : NSObject

- (instancetype)initWithConfig:(ServerConfig *)config;

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

/// Performs an offsite purchase via merchant backend (POST {baseURL}/offsite-purchase). Gateway: "sprel" or "paypal".
- (void)offsitePurchaseWithGateway:(NSString *)gateway
             paymentMethodToken:(NSString *)paymentMethodToken
                         amount:(NSDecimalNumber *)amount
                  currencyCode:(NSString *)currencyCode
                   redirectUrl:(NSString *)redirectUrl
                  callbackUrl:(NSString *)callbackUrl
                    completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Performs an EBANX purchase via merchant backend (POST {baseURL}/create-purchase). Gateway: "ebanx".
- (void)ebanxPurchaseWithPaymentMethodToken:(NSString *)paymentMethodToken
                                     amount:(NSDecimalNumber *)amount
                              currencyCode:(NSString *)currencyCode
                               redirectUrl:(NSString *)redirectUrl
                              callbackUrl:(NSString *)callbackUrl
                                  document:(nullable NSString *)document
                                completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Stripe APM pending purchase (POST {baseURL}/create-purchase). Gateway: "stripe", payment_method stripe_apm + apm_types.
- (void)stripeAPMPendingPurchaseWithAmount:(NSDecimalNumber *)amount
                             currencyCode:(NSString *)currencyCode
                              redirectUrl:(NSString *)redirectUrl
                             callbackUrl:(NSString *)callbackUrl
                                apmTypes:(NSArray<NSString *> *)apmTypes
                              completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Braintree purchase (POST {baseURL}/braintree-purchase).
- (void)braintreePurchaseWithAmount:(NSDecimalNumber *)amount
                      currencyCode:(NSString *)currencyCode
                       redirectUrl:(NSString *)redirectUrl
                      callbackUrl:(NSString *)callbackUrl
                 paymentMethodType:(NSString *)paymentMethodType
                        completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

/// Braintree confirm (POST {baseURL}/transactions/{token}/confirm).
- (void)braintreeConfirmWithTransactionToken:(NSString *)transactionToken
                                       state:(NSString *)state
                                       nonce:(NSString *)nonce
                                  deviceData:(nullable NSString *)deviceData
                           paymentMethodType:(NSString *)paymentMethodType
                                  completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END


