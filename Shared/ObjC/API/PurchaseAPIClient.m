//
//  PurchaseAPIClient.m
//  MerchantExample
//
//
//

#import "PurchaseAPIClient.h"
#import "SignatureServerClient.h" // For ServerConfig
#import "PurchaseModels.h"
#import "PurchaseRequestModels.h"
#import "EbanxPurchaseRequestModels.h"
#import "APIResponseErrorParser.h"

@interface PurchaseAPIClient ()

@property (nonatomic, strong) ServerConfig *config;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation PurchaseAPIClient

- (instancetype)initWithConfig:(ServerConfig *)config {
    if (self = [super init]) {
        _config = config;
        
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfig.timeoutIntervalForRequest = config.timeoutInterval;
        sessionConfig.timeoutIntervalForResource = config.timeoutInterval;
        
        _session = [NSURLSession sessionWithConfiguration:sessionConfig];
    }
    return self;
}

- (void)purchaseWithPaymentMethodToken:(NSString *)paymentMethodToken
                                 amount:(NSDecimalNumber *)amount
                          currencyCode:(NSString *)currencyCode
                  useGatewaySpecific3DS:(BOOL)useGatewaySpecific3DS
                            completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion {
    NSString *baseURLString = [self.config.baseURL hasSuffix:@"/"] ? [self.config.baseURL substringToIndex:self.config.baseURL.length - 1] : self.config.baseURL;
    NSString *urlString = [NSString stringWithFormat:@"%@/purchase", baseURLString];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError"
                                                 code:1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid purchase API URL"}];
            completion(nil, error);
        }
        return;
    }
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"POST";
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:@"*/*" forHTTPHeaderField:@"accept"];
    
    // Add API key if provided
    if (self.config.apiKey.length > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"Bearer %@", self.config.apiKey] forHTTPHeaderField:@"Authorization"];
    }
    
    NSDictionary *requestBody = nil;
    if (useGatewaySpecific3DS) {
        GatewaySpecificPurchaseTransactionRequest *request =
            [[GatewaySpecificPurchaseTransactionRequest alloc] initWithAmount:amount
                                                                 currencyCode:currencyCode
                                                           paymentMethodToken:paymentMethodToken
                                                               attempt3DSecure:YES];
        requestBody = [request toDictionary];
    } else {
        PurchaseTransactionRequest *request =
            [[PurchaseTransactionRequest alloc] initWithAmount:amount
                                                  currencyCode:currencyCode
                                            paymentMethodToken:paymentMethodToken];
        requestBody = [request toDictionary];
    }
    
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];
    
    if (jsonError || !jsonData) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError"
                                                 code:2
                                             userInfo:@{
                                                 NSLocalizedDescriptionKey: @"Failed to encode request body",
                                                 NSUnderlyingErrorKey: jsonError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:0 userInfo:nil]
                                             }];
            completion(nil, error);
        }
        return;
    }
    
    urlRequest.HTTPBody = jsonData;
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *networkError = [NSError errorWithDomain:@"PurchaseAPIError"
                                                          code:3
                                                      userInfo:@{
                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Network error: %@", error.localizedDescription],
                                                          NSUnderlyingErrorKey: error
                                                      }];
                completion(nil, networkError);
            }
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        // Check for error status codes
        if (httpResponse.statusCode < 200 || httpResponse.statusCode > 202) {
            NSString *errorMessage = [APIResponseErrorParser extractMessageFromData:data] ?: @"Unknown error";
            if (completion) {
                NSError *serverError = [NSError errorWithDomain:@"PurchaseAPIError"
                                                          code:4
                                                      userInfo:@{
                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Purchase API error (%ld): %@", (long)httpResponse.statusCode, errorMessage]
                                                      }];
                completion(nil, serverError);
            }
            return;
        }
        
        // Success case
        PurchaseResponse *purchaseResponse = nil;
        NSError *decodingError = nil;
        if (data && data.length > 0) {
            purchaseResponse = [PurchaseResponse fromJSONData:data error:&decodingError];
        }
        
        if (!purchaseResponse) {
            if (completion) {
                NSError *error = decodingError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode response"}];
                completion(nil, error);
            }
            return;
        }
        
        if (completion) {
            completion(purchaseResponse, nil);
        }
    }];
    
    [task resume];
}

- (void)completeTransactionWithToken:(NSString *)transactionToken
                          completion:(void (^)(NSData * _Nullable responseData, NSError * _Nullable error))completion {
    NSString *baseURLString = [self.config.baseURL hasSuffix:@"/"] ? [self.config.baseURL substringToIndex:self.config.baseURL.length - 1] : self.config.baseURL;
    NSString *urlString = [NSString stringWithFormat:@"%@/transactions/%@/complete", baseURLString, transactionToken];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError"
                                                 code:6
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid complete API URL"}];
            completion(nil, error);
        }
        return;
    }
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"POST";
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:@"*/*" forHTTPHeaderField:@"accept"];
    
    if (self.config.apiKey.length > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"Bearer %@", self.config.apiKey] forHTTPHeaderField:@"Authorization"];
    }
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *networkError = [NSError errorWithDomain:@"PurchaseAPIError"
                                                          code:7
                                                      userInfo:@{
                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Network error: %@", error.localizedDescription],
                                                          NSUnderlyingErrorKey: error
                                                      }];
                completion(nil, networkError);
            }
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        if (httpResponse.statusCode < 200 || httpResponse.statusCode > 202) {
            NSString *errorMessage = [APIResponseErrorParser extractMessageFromData:data] ?: @"Unknown error";
            if (completion) {
                NSError *serverError = [NSError errorWithDomain:@"PurchaseAPIError"
                                                          code:8
                                                      userInfo:@{
                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Complete API error (%ld): %@", (long)httpResponse.statusCode, errorMessage]
                                                      }];
                completion(nil, serverError);
            }
            return;
        }
        
        if (!data || data.length == 0) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"PurchaseAPIError"
                                                     code:9
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Empty complete API response"}];
                completion(nil, error);
            }
            return;
        }
        
        if (completion) {
            completion(data, nil);
        }
    }];
    
    [task resume];
}

- (void)purchaseWithPaymentMethodToken:(NSString *)paymentMethodToken
                                 amount:(NSDecimalNumber *)amount
                          currencyCode:(NSString *)currencyCode
                            completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion {
    [self purchaseWithPaymentMethodToken:paymentMethodToken
                                  amount:amount
                           currencyCode:currencyCode
                   useGatewaySpecific3DS:NO
                              completion:completion];
}

- (void)offsitePurchaseWithGateway:(NSString *)gateway
             paymentMethodToken:(NSString *)paymentMethodToken
                         amount:(NSDecimalNumber *)amount
                  currencyCode:(NSString *)currencyCode
                   redirectUrl:(NSString *)redirectUrl
                  callbackUrl:(NSString *)callbackUrl
                    completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion {
    NSString *baseURLString = [self.config.baseURL hasSuffix:@"/"] ? [self.config.baseURL substringToIndex:self.config.baseURL.length - 1] : self.config.baseURL;
    NSString *urlString = [NSString stringWithFormat:@"%@/offsite-purchase", baseURLString];
    NSURL *url = [NSURL URLWithString:urlString];

    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError"
                                                 code:1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid offsite-purchase API URL"}];
            completion(nil, error);
        }
        return;
    }

    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"POST";
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:@"*/*" forHTTPHeaderField:@"accept"];

    if (self.config.apiKey.length > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"Bearer %@", self.config.apiKey] forHTTPHeaderField:@"Authorization"];
    }

    OffsitePurchaseRequest *request = [[OffsitePurchaseRequest alloc] initWithGateway:gateway ?: @""
                                                                                              amount:amount
                                                                                       currencyCode:currencyCode
                                                                                 paymentMethodToken:paymentMethodToken
                                                                                        redirectUrl:redirectUrl
                                                                                       callbackUrl:callbackUrl
                                                                                           channel:@"app"];
    NSDictionary *requestBody = [request toDictionary];
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];

    if (jsonError || !jsonData) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError"
                                                 code:2
                                             userInfo:@{
                                                 NSLocalizedDescriptionKey: @"Failed to encode request body",
                                                 NSUnderlyingErrorKey: jsonError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:0 userInfo:nil]
                                             }];
            completion(nil, error);
        }
        return;
    }

    urlRequest.HTTPBody = jsonData;

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *networkError = [NSError errorWithDomain:@"PurchaseAPIError"
                                                          code:3
                                                      userInfo:@{
                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Network error: %@", error.localizedDescription],
                                                          NSUnderlyingErrorKey: error
                                                      }];
                completion(nil, networkError);
            }
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

        if (httpResponse.statusCode < 200 || httpResponse.statusCode > 202) {
            NSString *errorMessage = [APIResponseErrorParser extractMessageFromData:data] ?: @"Offsite purchase failed";
            if (completion) {
                NSError *serverError = [NSError errorWithDomain:@"PurchaseAPIError"
                                                          code:4
                                                      userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Offsite purchase error (%ld): %@", (long)httpResponse.statusCode, errorMessage]}];
                completion(nil, serverError);
            }
            return;
        }

        PurchaseResponse *purchaseResponse = nil;
        NSError *decodingError = nil;
        if (data && data.length > 0) {
            purchaseResponse = [PurchaseResponse fromJSONData:data error:&decodingError];
        }

        if (!purchaseResponse) {
            if (completion) {
                NSError *err = decodingError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode response"}];
                completion(nil, err);
            }
            return;
        }
        if (completion) completion(purchaseResponse, nil);
    }];
    [task resume];
}

- (void)ebanxPurchaseWithPaymentMethodToken:(NSString *)paymentMethodToken
                                     amount:(NSDecimalNumber *)amount
                              currencyCode:(NSString *)currencyCode
                               redirectUrl:(NSString *)redirectUrl
                              callbackUrl:(NSString *)callbackUrl
                                  document:(NSString *)document
                                completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion {
    NSString *baseURLString = [self.config.baseURL hasSuffix:@"/"] ? [self.config.baseURL substringToIndex:self.config.baseURL.length - 1] : self.config.baseURL;
    NSString *urlString = [NSString stringWithFormat:@"%@/create-purchase", baseURLString];
    NSURL *url = [NSURL URLWithString:urlString];

    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError"
                                                 code:1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid create-purchase API URL"}];
            completion(nil, error);
        }
        return;
    }

    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"POST";
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:@"*/*" forHTTPHeaderField:@"accept"];

    if (self.config.apiKey.length > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"Bearer %@", self.config.apiKey] forHTTPHeaderField:@"Authorization"];
    }

    EbanxPurchaseTransaction *transaction = [[EbanxPurchaseTransaction alloc] initWithAmount:amount
                                                                               currencyCode:currencyCode
                                                                         paymentMethodToken:paymentMethodToken
                                                                                redirectUrl:redirectUrl
                                                                               callbackUrl:callbackUrl
                                                                                   channel:@"app"
                                                                                  document:document];
    NSDictionary *transactionDict = [transaction toDictionary];
    NSDictionary *requestBody = @{ @"gateway": @"ebanx", @"transaction": transactionDict };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];

    if (jsonError || !jsonData) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError"
                                                 code:2
                                             userInfo:@{
                                                 NSLocalizedDescriptionKey: @"Failed to encode request body",
                                                 NSUnderlyingErrorKey: jsonError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:0 userInfo:nil]
                                             }];
            completion(nil, error);
        }
        return;
    }

    urlRequest.HTTPBody = jsonData;

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *networkError = [NSError errorWithDomain:@"PurchaseAPIError"
                                                          code:3
                                                      userInfo:@{
                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Network error: %@", error.localizedDescription],
                                                          NSUnderlyingErrorKey: error
                                                      }];
                completion(nil, networkError);
            }
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

        if (httpResponse.statusCode < 200 || httpResponse.statusCode > 202) {
            NSString *errorMessage = [APIResponseErrorParser extractMessageFromData:data] ?: @"EBANX purchase failed";
            if (completion) {
                NSError *serverError = [NSError errorWithDomain:@"PurchaseAPIError"
                                                          code:4
                                                      userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"EBANX purchase error (%ld): %@", (long)httpResponse.statusCode, errorMessage]}];
                completion(nil, serverError);
            }
            return;
        }

        PurchaseResponse *purchaseResponse = nil;
        NSError *decodingError = nil;
        if (data && data.length > 0) {
            purchaseResponse = [PurchaseResponse fromJSONData:data error:&decodingError];
        }

        if (!purchaseResponse) {
            if (completion) {
                NSError *err = decodingError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode response"}];
                completion(nil, err);
            }
            return;
        }
        if (completion) completion(purchaseResponse, nil);
    }];
    [task resume];
}

- (void)stripeAPMPendingPurchaseWithAmount:(NSDecimalNumber *)amount
                             currencyCode:(NSString *)currencyCode
                              redirectUrl:(NSString *)redirectUrl
                             callbackUrl:(NSString *)callbackUrl
                                apmTypes:(NSArray<NSString *> *)apmTypes
                              completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion {
    NSString *baseURLString = [self.config.baseURL hasSuffix:@"/"] ? [self.config.baseURL substringToIndex:self.config.baseURL.length - 1] : self.config.baseURL;
    NSString *urlString = [NSString stringWithFormat:@"%@/create-purchase", baseURLString];
    NSURL *url = [NSURL URLWithString:urlString];

    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid create-purchase API URL"}];
            completion(nil, error);
        }
        return;
    }

    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"POST";
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:@"*/*" forHTTPHeaderField:@"accept"];
    if (self.config.apiKey.length > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"Bearer %@", self.config.apiKey] forHTTPHeaderField:@"Authorization"];
    }

    NSDictionary *paymentMethod = @{
        @"payment_method_type": @"stripe_apm",
        @"apm_types": apmTypes ?: @[]
    };
    NSDictionary *transaction = @{
        @"amount": @([amount doubleValue]),
        @"currency_code": currencyCode ?: @"",
        @"redirect_url": redirectUrl ?: @"",
        @"callback_url": callbackUrl ?: @"",
        @"channel": @"app",
        @"payment_method": paymentMethod
    };
    NSDictionary *requestBody = @{ @"gateway": @"stripe", @"transaction": transaction };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];
    if (jsonError || !jsonData) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode request body", NSUnderlyingErrorKey: jsonError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:0 userInfo:nil]}];
            completion(nil, error);
        }
        return;
    }
    urlRequest.HTTPBody = jsonData;

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *networkError = [NSError errorWithDomain:@"PurchaseAPIError" code:3 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Network error: %@", error.localizedDescription], NSUnderlyingErrorKey: error}];
                completion(nil, networkError);
            }
            return;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode < 200 || httpResponse.statusCode > 202) {
            NSString *errorMessage = [APIResponseErrorParser extractMessageFromData:data] ?: @"Stripe APM pending purchase failed";
            if (completion) {
                NSError *serverError = [NSError errorWithDomain:@"PurchaseAPIError" code:4 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Stripe APM error (%ld): %@", (long)httpResponse.statusCode, errorMessage]}];
                completion(nil, serverError);
            }
            return;
        }
        PurchaseResponse *purchaseResponse = nil;
        NSError *decodingError = nil;
        if (data && data.length > 0) {
            purchaseResponse = [PurchaseResponse fromJSONData:data error:&decodingError];
        }
        if (!purchaseResponse && completion) {
            NSError *err = decodingError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode response"}];
            completion(nil, err);
            return;
        }
        if (completion) completion(purchaseResponse, nil);
    }];
    [task resume];
}

- (void)braintreePurchaseWithAmount:(NSDecimalNumber *)amount
                      currencyCode:(NSString *)currencyCode
                       redirectUrl:(NSString *)redirectUrl
                      callbackUrl:(NSString *)callbackUrl
                 paymentMethodType:(NSString *)paymentMethodType
                        completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion {
    NSString *baseURLString = [self.config.baseURL hasSuffix:@"/"] ? [self.config.baseURL substringToIndex:self.config.baseURL.length - 1] : self.config.baseURL;
    NSString *urlString = [NSString stringWithFormat:@"%@/braintree-purchase", baseURLString];
    NSURL *url = [NSURL URLWithString:urlString];

    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid braintree-purchase API URL"}];
            completion(nil, error);
        }
        return;
    }

    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"POST";
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:@"*/*" forHTTPHeaderField:@"accept"];
    if (self.config.apiKey.length > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"Bearer %@", self.config.apiKey] forHTTPHeaderField:@"Authorization"];
    }

    NSDictionary *requestBody = @{
        @"amount": @([amount doubleValue]),
        @"currency_code": currencyCode ?: @"",
        @"redirect_url": redirectUrl ?: @"",
        @"callback_url": callbackUrl ?: @"",
        @"channel": @"app",
        @"payment_method_type": paymentMethodType ?: @""
    };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];
    if (jsonError || !jsonData) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode request body", NSUnderlyingErrorKey: jsonError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:0 userInfo:nil]}];
            completion(nil, error);
        }
        return;
    }
    urlRequest.HTTPBody = jsonData;

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *networkError = [NSError errorWithDomain:@"PurchaseAPIError" code:3 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Network error: %@", error.localizedDescription], NSUnderlyingErrorKey: error}];
                completion(nil, networkError);
            }
            return;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode < 200 || httpResponse.statusCode > 202) {
            NSString *errorMessage = [APIResponseErrorParser extractMessageFromData:data] ?: @"Braintree purchase failed";
            if (completion) {
                NSError *serverError = [NSError errorWithDomain:@"PurchaseAPIError" code:4 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Braintree purchase error (%ld): %@", (long)httpResponse.statusCode, errorMessage]}];
                completion(nil, serverError);
            }
            return;
        }
        PurchaseResponse *purchaseResponse = nil;
        NSError *decodingError = nil;
        if (data && data.length > 0) {
            purchaseResponse = [PurchaseResponse fromJSONData:data error:&decodingError];
        }
        if (!purchaseResponse && completion) {
            NSError *err = decodingError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode response"}];
            completion(nil, err);
            return;
        }
        if (completion) completion(purchaseResponse, nil);
    }];
    [task resume];
}

- (void)braintreeConfirmWithTransactionToken:(NSString *)transactionToken
                                       state:(NSString *)state
                                       nonce:(NSString *)nonce
                                  deviceData:(NSString *)deviceData
                           paymentMethodType:(NSString *)paymentMethodType
                                  completion:(void (^)(PurchaseResponse * _Nullable response, NSError * _Nullable error))completion {
    NSString *baseURLString = [self.config.baseURL hasSuffix:@"/"] ? [self.config.baseURL substringToIndex:self.config.baseURL.length - 1] : self.config.baseURL;
    NSString *urlString = [NSString stringWithFormat:@"%@/transactions/%@/confirm", baseURLString, transactionToken ?: @""];
    NSURL *url = [NSURL URLWithString:urlString];

    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid confirm API URL"}];
            completion(nil, error);
        }
        return;
    }

    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"POST";
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:@"*/*" forHTTPHeaderField:@"accept"];
    if (self.config.apiKey.length > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"Bearer %@", self.config.apiKey] forHTTPHeaderField:@"Authorization"];
    }

    NSMutableDictionary *requestBody = [NSMutableDictionary dictionaryWithDictionary:@{
        @"state": state ?: @"Successful",
        @"nonce": nonce ?: @"",
        @"payment_method_type": paymentMethodType ?: @""
    }];
    if (deviceData.length > 0) {
        requestBody[@"device_data"] = deviceData;
    }

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&jsonError];
    if (jsonError || !jsonData) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"PurchaseAPIError" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode request body", NSUnderlyingErrorKey: jsonError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:0 userInfo:nil]}];
            completion(nil, error);
        }
        return;
    }
    urlRequest.HTTPBody = jsonData;

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *networkError = [NSError errorWithDomain:@"PurchaseAPIError" code:3 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Network error: %@", error.localizedDescription], NSUnderlyingErrorKey: error}];
                completion(nil, networkError);
            }
            return;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode < 200 || httpResponse.statusCode > 202) {
            NSString *errorMessage = [APIResponseErrorParser extractMessageFromData:data] ?: @"Braintree confirm failed";
            if (completion) {
                NSError *serverError = [NSError errorWithDomain:@"PurchaseAPIError" code:4 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Braintree confirm error (%ld): %@", (long)httpResponse.statusCode, errorMessage]}];
                completion(nil, serverError);
            }
            return;
        }
        PurchaseResponse *purchaseResponse = nil;
        NSError *decodingError = nil;
        if (data && data.length > 0) {
            purchaseResponse = [PurchaseResponse fromJSONData:data error:&decodingError];
        }
        if (!purchaseResponse && completion) {
            NSError *err = decodingError ?: [NSError errorWithDomain:@"PurchaseAPIError" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode response"}];
            completion(nil, err);
            return;
        }
        if (completion) completion(purchaseResponse, nil);
    }];
    [task resume];
}

@end


