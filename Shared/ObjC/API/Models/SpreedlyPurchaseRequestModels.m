//
//  SpreedlyPurchaseRequestModels.m
//  MerchantExample
//
//
//

#import "SpreedlyPurchaseRequestModels.h"

@implementation SpreedlyPurchaseTransactionRequest

- (instancetype)initWithAmount:(NSDecimalNumber *)amount
                   browserInfo:(NSString *)browserInfo
                  currencyCode:(NSString *)currencyCode
            paymentMethodToken:(NSString *)paymentMethodToken
                            ip:(NSString *)ip
                   redirectUrl:(NSString *)redirectUrl
                       channel:(NSString *)channel
                   callbackUrl:(NSString *)callbackUrl
                scaProviderKey:(nullable NSString *)scaProviderKey {
    if (self = [super init]) {
        _amount = amount.doubleValue;
        _browserInfo = [browserInfo copy];
        _currencyCode = [currencyCode copy];
        _paymentMethodToken = [paymentMethodToken copy];
        _ip = [ip copy];
        _redirectUrl = [redirectUrl copy];
        _channel = [channel copy];
        _callbackUrl = [callbackUrl copy];
        _scaProviderKey = [scaProviderKey copy];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *transaction = [NSMutableDictionary dictionaryWithDictionary:@{
        @"amount": @(self.amount),
        @"browser_info": self.browserInfo ?: @"",
        @"currency_code": self.currencyCode,
        @"payment_method_token": self.paymentMethodToken ?: @"",
        @"ip": self.ip ?: @"",
        @"redirect_url": self.redirectUrl ?: @"",
        @"channel": self.channel ?: @"app",
        @"callback_url": self.callbackUrl ?: @""
    }];
    if (self.scaProviderKey.length > 0) {
        transaction[@"sca_provider_key"] = self.scaProviderKey;
    }
    return @{ @"transaction": [transaction copy] };
}

@end
