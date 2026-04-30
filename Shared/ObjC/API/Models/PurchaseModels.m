//
//  PurchaseModels.m
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import "PurchaseModels.h"

// MARK: - PurchaseError Implementation

@implementation PurchaseError

- (instancetype)initWithAttribute:(NSString * _Nullable)attribute key:(NSString * _Nullable)key message:(NSString * _Nullable)message {
    if (self = [super init]) {
        _attribute = attribute;
        _key = key;
        _message = message;
    }
    return self;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    return [[PurchaseError alloc] initWithAttribute:dict[@"attribute"]
                                                key:dict[@"key"]
                                            message:dict[@"message"]];
}

@end

// MARK: - SCAAuthentication Implementation

@interface SCAAuthentication ()
@property (nonatomic, strong, readwrite, nullable) NSString *managedOrderToken;
@property (nonatomic, strong, readwrite, nullable) NSString *requiredAction;
@end

@implementation SCAAuthentication

- (instancetype)initWithManagedOrderToken:(NSString * _Nullable)managedOrderToken
                           requiredAction:(NSString * _Nullable)requiredAction {
    if (self = [super init]) {
        _managedOrderToken = managedOrderToken;
        _requiredAction = requiredAction;
    }
    return self;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSString *managedOrderToken = dict[@"managed_order_token"];
    NSString *requiredAction = dict[@"required_action"];
    return [[SCAAuthentication alloc] initWithManagedOrderToken:managedOrderToken
                                                requiredAction:requiredAction];
}

@end

// MARK: - PurchaseTransaction Implementation

@interface PurchaseTransaction ()
@property (nonatomic, assign, readwrite) BOOL succeeded;
@property (nonatomic, strong, readwrite) NSString *token;
@property (nonatomic, strong, readwrite, nullable) NSString *state;
@property (nonatomic, strong, readwrite, nullable) NSString *message;
@property (nonatomic, strong, readwrite, nullable) NSString *requiredAction;
@property (nonatomic, strong, readwrite, nullable) NSString *managedOrderToken;
@property (nonatomic, strong, readwrite, nullable) SCAAuthentication *scaAuthentication;
@property (nonatomic, strong, readwrite, nullable) NSString *stripePaymentIntentClientSecret;
@property (nonatomic, strong, readwrite, nullable) NSString *braintreeClientToken;
@end

@implementation PurchaseTransaction

- (instancetype)initWithSucceeded:(BOOL)succeeded
                             token:(NSString *)token
                             state:(NSString * _Nullable)state
                           message:(NSString * _Nullable)message
                    requiredAction:(NSString * _Nullable)requiredAction
                 managedOrderToken:(NSString * _Nullable)managedOrderToken
                 scaAuthentication:(SCAAuthentication * _Nullable)scaAuthentication
    stripePaymentIntentClientSecret:(NSString * _Nullable)stripePaymentIntentClientSecret
              braintreeClientToken:(NSString * _Nullable)braintreeClientToken {
    if (self = [super init]) {
        _succeeded = succeeded;
        _token = token ?: @"";
        _state = state;
        _message = message;
        _requiredAction = requiredAction;
        _managedOrderToken = managedOrderToken;
        _scaAuthentication = scaAuthentication;
        _stripePaymentIntentClientSecret = stripePaymentIntentClientSecret;
        _braintreeClientToken = braintreeClientToken;
    }
    return self;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    BOOL succeeded = [dict[@"succeeded"] boolValue];
    NSString *token = dict[@"token"] ?: @"";
    NSString *state = dict[@"state"];
    NSString *message = dict[@"message"];
    NSString *requiredAction = dict[@"required_action"];
    NSString *managedOrderToken = dict[@"managed_order_token"];
    
    SCAAuthentication *scaAuth = nil;
    NSDictionary *scaDict = dict[@"sca_authentication"];
    if (scaDict && [scaDict isKindOfClass:[NSDictionary class]]) {
        scaAuth = [SCAAuthentication fromDictionary:scaDict];
    }
    
    NSString *stripeClientSecret = nil;
    NSString *braintreeClientToken = nil;
    NSDictionary *gsf = dict[@"gateway_specific_response_fields"];
    if ([gsf isKindOfClass:[NSDictionary class]]) {
        NSDictionary *spi = gsf[@"stripe_payment_intents"];
        if ([spi isKindOfClass:[NSDictionary class]] && [spi[@"client_secret"] isKindOfClass:[NSString class]]) {
            stripeClientSecret = spi[@"client_secret"];
        }
        NSDictionary *bt = gsf[@"braintree"];
        if ([bt isKindOfClass:[NSDictionary class]] && [bt[@"client_token"] isKindOfClass:[NSString class]]) {
            braintreeClientToken = bt[@"client_token"];
        }
    }
    
    return [[PurchaseTransaction alloc] initWithSucceeded:succeeded
                                                   token:token
                                                   state:state
                                                 message:message
                                         requiredAction:requiredAction
                                      managedOrderToken:managedOrderToken
                                       scaAuthentication:scaAuth
                        stripePaymentIntentClientSecret:stripeClientSecret
                                  braintreeClientToken:braintreeClientToken];
}

@end

// MARK: - PurchaseResponse Implementation

@interface PurchaseResponse ()
@property (nonatomic, strong, readwrite, nullable) PurchaseTransaction *transaction;
@property (nonatomic, strong, readwrite, nullable) NSArray<PurchaseError *> *errors;
@end

@implementation PurchaseResponse

- (instancetype)initWithTransaction:(PurchaseTransaction * _Nullable)transaction errors:(NSArray<PurchaseError *> * _Nullable)errors {
    if (self = [super init]) {
        _transaction = transaction;
        _errors = errors ? [errors copy] : nil;
    }
    return self;
}

+ (instancetype)fromJSONData:(NSData *)data error:(NSError **)error {
    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (jsonError) {
        if (error) *error = jsonError;
        return nil;
    }
    
    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"PurchaseResponse" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid JSON format"}];
        }
        return nil;
    }
    
    // Parse transaction
    PurchaseTransaction *transaction = nil;
    NSDictionary *transactionDict = json[@"transaction"];
    if (transactionDict && [transactionDict isKindOfClass:[NSDictionary class]]) {
        transaction = [PurchaseTransaction fromDictionary:transactionDict];
    }
    
    // Parse errors
    NSArray<PurchaseError *> *errors = nil;
    NSArray *errorsArray = json[@"errors"];
    if (errorsArray && [errorsArray isKindOfClass:[NSArray class]]) {
        NSMutableArray<PurchaseError *> *parsedErrors = [NSMutableArray array];
        for (NSDictionary *errorDict in errorsArray) {
            if ([errorDict isKindOfClass:[NSDictionary class]]) {
                PurchaseError *error = [PurchaseError fromDictionary:errorDict];
                if (error) {
                    [parsedErrors addObject:error];
                }
            }
        }
        if (parsedErrors.count > 0) {
            errors = [parsedErrors copy];
        }
    }
    
    return [[PurchaseResponse alloc] initWithTransaction:transaction errors:errors];
}

@end


