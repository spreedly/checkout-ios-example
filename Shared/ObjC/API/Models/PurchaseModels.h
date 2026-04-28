//
//  PurchaseModels.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PurchaseTransaction;
@class PurchaseError;
@class SCAAuthentication;

@interface PurchaseResponse : NSObject
@property (nonatomic, strong, readonly, nullable) PurchaseTransaction *transaction;
@property (nonatomic, strong, readonly, nullable) NSArray<PurchaseError *> *errors;
+ (instancetype)fromJSONData:(NSData *)data error:(NSError **)error;
- (instancetype)initWithTransaction:(PurchaseTransaction * _Nullable)transaction errors:(NSArray<PurchaseError *> * _Nullable)errors;
@end

@interface PurchaseTransaction : NSObject
@property (nonatomic, assign, readonly) BOOL succeeded;
@property (nonatomic, strong, readonly) NSString *token;
@property (nonatomic, strong, readonly, nullable) NSString *state;
@property (nonatomic, strong, readonly, nullable) NSString *message;
@property (nonatomic, strong, readonly, nullable) NSString *requiredAction;
@property (nonatomic, strong, readonly, nullable) NSString *managedOrderToken;
@property (nonatomic, strong, readonly, nullable) SCAAuthentication *scaAuthentication;
/// Stripe PaymentIntent client_secret from gateway_specific_response_fields.stripe_payment_intents (Stripe APM pending purchase)
@property (nonatomic, strong, readonly, nullable) NSString *stripePaymentIntentClientSecret;
/// Braintree client_token from gateway_specific_response_fields.braintree (Braintree purchase)
@property (nonatomic, strong, readonly, nullable) NSString *braintreeClientToken;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
@end

@interface SCAAuthentication : NSObject
@property (nonatomic, strong, readonly, nullable) NSString *managedOrderToken;
@property (nonatomic, strong, readonly, nullable) NSString *requiredAction;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
@end

@interface PurchaseError : NSObject
@property (nonatomic, strong, readonly, nullable) NSString *attribute;
@property (nonatomic, strong, readonly, nullable) NSString *key;
@property (nonatomic, strong, readonly, nullable) NSString *message;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END

