//
//  SignatureServerClient.m
//  MerchantExample
//
//
//

#import "SignatureServerClient.h"

// MARK: - ServerConfig Implementation

@implementation ServerConfig

- (instancetype)initWithBaseURL:(NSString *)baseURL
                timeoutInterval:(NSTimeInterval)timeoutInterval
                         apiKey:(nullable NSString *)apiKey {
    if (self = [super init]) {
        _baseURL = [baseURL copy];
        _timeoutInterval = timeoutInterval;
        _apiKey = [apiKey copy];
    }
    return self;
}

@end

// MARK: - SignatureRequest Implementation

@implementation SignatureRequest

- (instancetype)initWithCertificateToken:(NSString *)certificateToken
                                   nonce:(nullable NSString *)nonce
                                timestamp:(nullable NSString *)timestamp {
    if (self = [super init]) {
        _certificateToken = [certificateToken copy];
        _nonce = [nonce copy];
        _timestamp = [timestamp copy];
    }
    return self;
}

@end

// MARK: - SignatureResponse Implementation

@implementation SignatureResponse

- (instancetype)initWithNonce:(NSString *)nonce
                    timestamp:(NSInteger)timestamp
              certificateToken:(NSString *)certificateToken
                     signature:(NSString *)signature {
    if (self = [super init]) {
        _nonce = [nonce copy];
        _timestamp = timestamp;
        _certificateToken = [certificateToken copy];
        _signature = [signature copy];
    }
    return self;
}

@end

// MARK: - SignatureServerClient Implementation

@interface SignatureServerClient ()

@property (nonatomic, strong) ServerConfig *config;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation SignatureServerClient

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

- (void)requestSignatureWithCompletion:(void (^)(SignatureParameters * _Nullable signatureParams, NSError * _Nullable error))completion {
    NSURL *url = [NSURL URLWithString:self.config.baseURL];
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"SignatureServerClient"
                                                 code:1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid signature server URL"}];
            completion(nil, error);
        }
        return;
    }
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"GET";
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // Add API key if provided
    if (self.config.apiKey.length > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"Bearer %@", self.config.apiKey] forHTTPHeaderField:@"Authorization"];
    }
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                NSError *networkError = [NSError errorWithDomain:@"SignatureServerClient"
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
                NSError *serverError = [NSError errorWithDomain:@"SignatureServerClient"
                                                           code:3
                                                       userInfo:@{
                                                           NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Signature server error (%ld): %@", (long)httpResponse.statusCode, errorMessage]
                                                       }];
                completion(nil, serverError);
            }
            return;
        }
        
        if (!data) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"SignatureServerClient"
                                                     code:4
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Invalid response from signature server"}];
                completion(nil, error);
            }
            return;
        }
        
        // Parse JSON response
        NSError *jsonError;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"SignatureServerClient"
                                                     code:5
                                                 userInfo:@{
                                                     NSLocalizedDescriptionKey: @"Failed to parse server response",
                                                     NSUnderlyingErrorKey: jsonError
                                                 }];
                completion(nil, error);
            }
            return;
        }
        
        // Extract signature parameters
        NSString *nonce = jsonResponse[@"nonce"];
        NSNumber *timestampNumber = jsonResponse[@"timestamp"];
        NSString *certificateToken = jsonResponse[@"certificateToken"];
        NSString *signature = jsonResponse[@"signature"];
        
        if (!nonce || !timestampNumber || !certificateToken || !signature) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"SignatureServerClient"
                                                     code:6
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Invalid signature response format"}];
                completion(nil, error);
            }
            return;
        }
        
        if (signature.length == 0) {
            if (completion) {
                NSError *error = [NSError errorWithDomain:@"SignatureServerClient"
                                                     code:7
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Signature generation failed: Unknown error"}];
                completion(nil, error);
            }
            return;
        }
        
        SignatureParameters *signatureParams = [[SignatureParameters alloc] initWithNonce:nonce
                                                                                timestamp:[timestampNumber integerValue]
                                                                          certificateToken:certificateToken
                                                                                 signature:signature];
        
        if (completion) {
            completion(signatureParams, nil);
        }
    }];
    
    [task resume];
}

- (void)isServerAvailableWithCompletion:(void (^)(BOOL isAvailable))completion {
    NSString *healthURLString = [NSString stringWithFormat:@"%@/health", self.config.baseURL];
    NSURL *url = [NSURL URLWithString:healthURLString];
    if (!url) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"GET";
    urlRequest.timeoutInterval = 5.0; // Short timeout for health check
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:urlRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(NO);
            }
            return;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        BOOL isAvailable = httpResponse.statusCode == 200;
        
        if (completion) {
            completion(isAvailable);
        }
    }];
    
    [task resume];
}

@end 