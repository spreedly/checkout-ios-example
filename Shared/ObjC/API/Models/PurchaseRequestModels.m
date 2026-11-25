//
//  PurchaseRequestModels.m
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import "PurchaseRequestModels.h"

@implementation PurchaseTransactionRequest

- (instancetype)initWithAmount:(NSDecimalNumber *)amount
                   currencyCode:(NSString *)currencyCode
             paymentMethodToken:(NSString *)paymentMethodToken {
    if (self = [super init]) {
        _amount = amount.doubleValue;
        _currencyCode = [currencyCode copy];
        _paymentMethodToken = [paymentMethodToken copy];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"amount": @(self.amount),
        @"currency_code": self.currencyCode,
        @"payment_method_token": self.paymentMethodToken ?: @""
    };
}

@end

@implementation OffsitePurchaseRequest

- (instancetype)initWithGateway:(NSString *)gateway
                         amount:(NSDecimalNumber *)amount
                  currencyCode:(NSString *)currencyCode
            paymentMethodToken:(NSString *)paymentMethodToken
                   redirectUrl:(nullable NSString *)redirectUrl
                  callbackUrl:(NSString *)callbackUrl
                      channel:(NSString *)channel {
    if (self = [super init]) {
        _gateway = [gateway copy];
        _amount = amount.doubleValue;
        _currencyCode = [currencyCode copy];
        _paymentMethodToken = [paymentMethodToken copy];
        _redirectUrl = [redirectUrl copy];
        _callbackUrl = [callbackUrl copy];
        _channel = [channel copy] ?: @"app";
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *body = [@{
        @"gateway": self.gateway ?: @"",
        @"amount": @(self.amount),
        @"currency_code": self.currencyCode ?: @"",
        @"payment_method_token": self.paymentMethodToken ?: @"",
        @"callback_url": self.callbackUrl ?: @"",
        @"channel": self.channel ?: @"app"
    } mutableCopy];
    // No redirect means the backend picks its own return page, so the key is left out rather than sent empty.
    if (self.redirectUrl) {
        body[@"redirect_url"] = self.redirectUrl;
    }
    return body;
}

@end

@implementation GatewaySpecificPurchaseTransactionRequest

- (instancetype)initWithAmount:(NSDecimalNumber *)amount
                   currencyCode:(NSString *)currencyCode
             paymentMethodToken:(NSString *)paymentMethodToken
                 attempt3DSecure:(BOOL)attempt3DSecure {
    if (self = [super init]) {
        _amount = amount.doubleValue;
        _currencyCode = [currencyCode copy];
        _paymentMethodToken = [paymentMethodToken copy];
        _attempt3DSecure = attempt3DSecure;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"amount": @(self.amount),
        @"currency_code": self.currencyCode,
        @"payment_method_token": self.paymentMethodToken ?: @"",
        @"attempt_3dsecure": @(self.attempt3DSecure)
    };
}

@end
