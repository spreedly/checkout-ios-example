//
//  SignatureServerClient.m
//  SpreedlySDKExampleObjectiveC
//
//  Created by Vinay Naikade on 12/08/25.
//

#import "SignatureServerClient.h"
#import <CommonCrypto/CommonDigest.h>

// MARK: - Backend login

static BOOL SPLExampleIsBlankString(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return YES;
    }
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0;
}

NSString * _Nullable SPLExampleBackendBasicAuthHeader(id _Nullable user, id _Nullable password) {
    // Values are not trimmed here: spaces in a password are part of it (xcconfig strips surrounding whitespace).
    // Basic auth can't carry a colon in the user, so such a login counts as not configured.
    if (SPLExampleIsBlankString(user) || SPLExampleIsBlankString(password) || [user containsString:@":"]) {
        return nil;
    }
    NSString *login = [NSString stringWithFormat:@"%@:%@", user, password];
    NSString *encoded = [[login dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    return [NSString stringWithFormat:@"Basic %@", encoded];
}

/// `https://host:port` (443 when no port is given), or nil when the URL isn't HTTPS or has no host.
static NSString * _Nullable SPLExampleOrigin(NSURL * _Nullable url) {
    NSString *host = url.host.lowercaseString;
    if (![url.scheme.lowercaseString isEqualToString:@"https"] || host.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"https://%@:%@", host, url.port ?: @443];
}

BOOL SPLExampleIsBackendRequest(NSURLRequest *request, id _Nullable backendURL) {
    if (![backendURL isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *backendOrigin = SPLExampleOrigin([NSURL URLWithString:backendURL]);
    NSString *requestOrigin = SPLExampleOrigin(request.URL);
    return backendOrigin != nil && [requestOrigin isEqualToString:backendOrigin];
}

void SPLExampleApplyBackendBasicAuthFromInfo(NSMutableURLRequest *request, NSDictionary * _Nullable info) {
    // Only HTTPS requests for the backend's own origin get the login; SPLExampleBackendSession refuses redirects
    // that leave the original origin.
    if (!SPLExampleIsBackendRequest(request, info[@"SpreedlyBaseURL"])) {
        return;
    }
    NSString *header = SPLExampleBackendBasicAuthHeader(info[@"SpreedlyBackendBasicAuthUser"],
                                                        info[@"SpreedlyBackendBasicAuthPassword"]);
    if (header) {
        [request setValue:header forHTTPHeaderField:@"Authorization"];
    }
}

void SPLExampleApplyBackendBasicAuth(NSMutableURLRequest *request) {
    SPLExampleApplyBackendBasicAuthFromInfo(request, [NSBundle mainBundle].infoDictionary);
}

/// `scheme://host:port`, with the scheme's default port when none is given, or nil without a scheme and host.
static NSString * _Nullable SPLExampleAnyOrigin(NSURL * _Nullable url) {
    NSString *scheme = url.scheme.lowercaseString;
    NSString *host = url.host.lowercaseString;
    if (scheme.length == 0 || host.length == 0) {
        return nil;
    }
    NSNumber *port = url.port ?: ([scheme isEqualToString:@"https"] ? @443 : [scheme isEqualToString:@"http"] ? @80 : @-1);
    return [NSString stringWithFormat:@"%@://%@:%@", scheme, host, port];
}

NSURLRequest * _Nullable SPLExampleRedirectRequest(NSURLRequest *redirect, NSURLRequest * _Nullable original) {
    // A 307 or 308 redirect re-sends the body (retain owner secret, purchase tokens) as well as the headers, so a
    // redirect that leaves the original origin, or moves from HTTPS to HTTP, is refused rather than stripped.
    NSString *redirectOrigin = SPLExampleAnyOrigin(redirect.URL);
    if (redirectOrigin != nil && [redirectOrigin isEqualToString:SPLExampleAnyOrigin(original.URL)]) {
        return redirect;
    }
    return nil;
}

@interface SPLExampleBackendRedirectGuard : NSObject <NSURLSessionTaskDelegate>
@end

@implementation SPLExampleBackendRedirectGuard

- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    completionHandler(SPLExampleRedirectRequest(request, task.originalRequest));
}

@end

NSURLSession *SPLExampleBackendSession(NSURLSessionConfiguration *configuration) {
    static SPLExampleBackendRedirectGuard *guard;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        guard = [[SPLExampleBackendRedirectGuard alloc] init];
    });
    return [NSURLSession sessionWithConfiguration:configuration delegate:guard delegateQueue:nil];
}

NSURLSession *SPLExampleSharedBackendSession(NSTimeInterval timeoutInterval) {
    static NSMutableDictionary<NSNumber *, NSURLSession *> *sessions;
    static NSLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sessions = [NSMutableDictionary dictionary];
        lock = [[NSLock alloc] init];
    });
    [lock lock];
    NSURLSession *session = sessions[@(timeoutInterval)];
    if (!session) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.timeoutIntervalForRequest = timeoutInterval;
        configuration.timeoutIntervalForResource = timeoutInterval;
        session = SPLExampleBackendSession(configuration);
        sessions[@(timeoutInterval)] = session;
    }
    [lock unlock];
    return session;
}

// MARK: - Offsite redirect

NSString * _Nullable SPLExampleBackendRedirectURL(NSString * _Nullable appRedirectURL) {
    id raw = [NSBundle mainBundle].infoDictionary[@"SpreedlyOmitRedirectURL"];
    NSString *value = [raw isKindOfClass:[NSString class]]
        ? [[raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] lowercaseString] : @"";
    if ([@[@"yes", @"true", @"1"] containsObject:value]) {
        return nil;
    }
    return appRedirectURL;
}

// MARK: - Sample app owner (retain)

NSString *SPLExampleSampleAppOwnerSecret(void) {
    static NSString *secret;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        secret = [NSUUID UUID].UUIDString;
    });
    return secret;
}

NSString *SPLExampleSampleAppOwnerTag(NSString *secret) {
    NSData *data = [secret dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

NSDictionary<NSString *, NSString *> *SPLExampleSampleAppOwnerMetadata(void) {
    return @{@"sample_app_owner": SPLExampleSampleAppOwnerTag(SPLExampleSampleAppOwnerSecret())};
}

NSData *SPLExampleSampleAppOwnerRetainBody(void) {
    // A UUID string needs no JSON escaping.
    NSString *json = [NSString stringWithFormat:@"{\"owner_secret\":\"%@\"}", SPLExampleSampleAppOwnerSecret()];
    return [json dataUsingEncoding:NSUTF8StringEncoding];
}

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
        
        _session = SPLExampleSharedBackendSession(config.timeoutInterval);
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
    SPLExampleApplyBackendBasicAuth(urlRequest);
    
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
    SPLExampleApplyBackendBasicAuth(urlRequest);
    
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