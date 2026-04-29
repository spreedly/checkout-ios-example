//
//  PurchaseRequestModels.m
//  MerchantExample
//
//
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
                   redirectUrl:(NSString *)redirectUrl
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
    return @{
        @"gateway": self.gateway ?: @"",
        @"amount": @(self.amount),
        @"currency_code": self.currencyCode ?: @"",
        @"payment_method_token": self.paymentMethodToken ?: @"",
        @"redirect_url": self.redirectUrl ?: @"",
        @"callback_url": self.callbackUrl ?: @"",
        @"channel": self.channel ?: @"app"
    };
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
