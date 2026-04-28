//
//  EbanxPurchaseRequestModels.m
//  MerchantExample
//

#import "EbanxPurchaseRequestModels.h"

@implementation EbanxPurchaseTransaction

- (instancetype)initWithAmount:(NSDecimalNumber *)amount
                  currencyCode:(NSString *)currencyCode
            paymentMethodToken:(NSString *)paymentMethodToken
                   redirectUrl:(NSString *)redirectUrl
                   callbackUrl:(NSString *)callbackUrl
                       channel:(NSString *)channel
                      document:(nullable NSString *)document {
    if (self = [super init]) {
        _amount = amount.doubleValue;
        _currencyCode = [currencyCode copy];
        _paymentMethodToken = [paymentMethodToken copy];
        _redirectUrl = [redirectUrl copy];
        _callbackUrl = [callbackUrl copy];
        _channel = [channel copy];
        _document = [document copy];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *body = [NSMutableDictionary dictionaryWithDictionary:@{
        @"amount": @(self.amount),
        @"currency_code": self.currencyCode ?: @"",
        @"payment_method_token": self.paymentMethodToken ?: @"",
        @"redirect_url": self.redirectUrl ?: @"",
        @"callback_url": self.callbackUrl ?: @"",
        @"channel": self.channel ?: @"app"
    }];

    if (self.document.length > 0) {
        body[@"gateway_specific_fields"] = @{
            @"ebanx": @{
                @"document": self.document
            }
        };
    }

    return [body copy];
}

@end

@implementation EbanxPurchaseRequest

- (instancetype)initWithTransaction:(EbanxPurchaseTransaction *)transaction {
    if (self = [super init]) {
        _transaction = transaction;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{ @"transaction": [self.transaction toDictionary] };
}

@end
