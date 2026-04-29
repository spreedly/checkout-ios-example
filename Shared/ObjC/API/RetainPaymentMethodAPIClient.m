//
//  RetainPaymentMethodAPIClient.m
//  MerchantExample
//
//
//

#import "RetainPaymentMethodAPIClient.h"
#import "RetainPaymentMethodModels.h"
#import "SignatureServerClient.h" // For ServerConfig

@interface RetainPaymentMethodAPIClient ()

@property (nonatomic, strong) ServerConfig *config;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation RetainPaymentMethodAPIClient

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

- (void)retainPaymentMethodWithToken:(NSString *)token
                           completion:(void (^)(RetainPaymentMethodResponse * _Nullable response, NSError * _Nullable error))completion {
    NSString *baseURLString = [self.config.baseURL hasSuffix:@"/"] ? [self.config.baseURL substringToIndex:self.config.baseURL.length - 1] : self.config.baseURL;
    NSString *urlString = [NSString stringWithFormat:@"%@/payment_methods/%@/retain", baseURLString, token];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"RetainPaymentMethodAPIClient"
                                                 code:1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid payment method API URL"}];
            completion(nil, error);
        }
        return;
    }
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"PUT";
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:@"*/*" forHTTPHeaderField:@"accept"];
    
    // Add API key if provided
    if (self.config.apiKey.length > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"Bearer %@", self.config.apiKey] forHTTPHeaderField:@"Authorization"];
    }
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *networkError = [NSError errorWithDomain:@"RetainPaymentMethodAPIClient"
                                                            code:2
                                                        userInfo:@{
                                                            NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Network error: %@", error.localizedDescription],
                                                            NSUnderlyingErrorKey: error
                                                        }];
                completion(nil, networkError);
            }
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            if (completion) {
                NSString *errorMessage = @"Unknown error";
                if (data) {
                    errorMessage = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"Unknown error";
                }
                NSError *serverError = [NSError errorWithDomain:@"RetainPaymentMethodAPIClient"
                                                           code:3
                                                       userInfo:@{
                                                           NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Payment method API error (%ld): %@", (long)httpResponse.statusCode, errorMessage]
                                                       }];
                completion(nil, serverError);
            }
            return;
        }
        
        if (!data) {
            if (completion) {
                NSError *dataError = [NSError errorWithDomain:@"RetainPaymentMethodAPIClient"
                                                         code:4
                                                     userInfo:@{NSLocalizedDescriptionKey: @"No data received"}];
                completion(nil, dataError);
            }
            return;
        }
        
        // Parse JSON response
        NSError *jsonError = nil;
        RetainPaymentMethodResponse *responseObj = [RetainPaymentMethodResponse fromJSONData:data error:&jsonError];
        
        if (jsonError || !responseObj) {
            if (completion) {
                completion(nil, jsonError ?: [NSError errorWithDomain:@"RetainPaymentMethodAPIClient" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to decode response"}]);
            }
            return;
        }
        
        if (completion) {
            completion(responseObj, nil);
        }
    }];
    
    [task resume];
}

@end

