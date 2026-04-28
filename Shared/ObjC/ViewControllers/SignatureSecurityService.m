//
//  SignatureSecurityService.m
//  MerchantExample
//
//
//

#import "SignatureSecurityService.h"

// MARK: - ServerSecurityConfig Implementation

@implementation ServerSecurityConfig

- (instancetype)initWithServerURL:(NSString *)serverURL
                           apiKey:(nullable NSString *)apiKey
                   environmentKey:(NSString *)environmentKey {
    if (self = [super init]) {
        _serverURL = [serverURL copy];
        _apiKey = [apiKey copy];
        _environmentKey = [environmentKey copy];
    }
    return self;
}

@end

// MARK: - EmbeddedSecurityConfig Implementation

@implementation EmbeddedSecurityConfig

- (instancetype)initWithPrivateKeyPEM:(NSString *)privateKeyPEM
                      certificateToken:(NSString *)certificateToken
                       environmentKey:(NSString *)environmentKey {
    if (self = [super init]) {
        _privateKeyPEM = [privateKeyPEM copy];
        _certificateToken = [certificateToken copy];
        _environmentKey = [environmentKey copy];
    }
    return self;
}

@end

// MARK: - SecuritySetupResult Implementation

@implementation SecuritySetupResult

- (instancetype)initWithSuccess:(BOOL)success
                        message:(nullable NSString *)message
                          error:(nullable NSError *)error
                signatureParams:(nullable SignatureParameters *)signatureParams {
    if (self = [super init]) {
        _success = success;
        _message = [message copy];
        _error = error;
        _signatureParams = signatureParams;
    }
    return self;
}

@end

// MARK: - PaymentTestResult Implementation

@implementation PaymentTestResult

- (instancetype)initWithSuccess:(BOOL)success
              paymentMethodToken:(nullable NSString *)paymentMethodToken
                           error:(nullable NSString *)error {
    if (self = [super init]) {
        _success = success;
        _paymentMethodToken = [paymentMethodToken copy];
        _error = [error copy];
    }
    return self;
}

@end

// MARK: - ServerStatus Implementation

@implementation ServerStatus

- (instancetype)initWithIsAvailable:(BOOL)isAvailable
                            message:(NSString *)message {
    if (self = [super init]) {
        _isAvailable = isAvailable;
        _message = [message copy];
    }
    return self;
}

@end

// MARK: - SignatureSecurityService Implementation

@implementation SignatureSecurityService

+ (void)checkServerStatusWithConfig:(ServerSecurityConfig *)config
                         completion:(void (^)(ServerStatus *status))completion {
    ServerConfig *serverConfig = [[ServerConfig alloc] initWithBaseURL:config.serverURL
                                                        timeoutInterval:5.0
                                                                 apiKey:config.apiKey];
    
    SignatureServerClient *serverClient = [[SignatureServerClient alloc] initWithConfig:serverConfig];
    [serverClient isServerAvailableWithCompletion:^(BOOL isAvailable) {
        ServerStatus *status = [[ServerStatus alloc] initWithIsAvailable:isAvailable
                                                                 message:isAvailable ? @"Available" : @"Unavailable"];
        if (completion) {
            completion(status);
        }
    }];
}

+ (void)setupServerBasedSecurityWithConfig:(ServerSecurityConfig *)config
                                completion:(void (^)(SecuritySetupResult *result))completion {
    // Create server configuration
    ServerConfig *serverConfig = [[ServerConfig alloc] initWithBaseURL:config.serverURL
                                                        timeoutInterval:30.0
                                                                 apiKey:config.apiKey];
    
    // Create server client and request signature
    SignatureServerClient *serverClient = [[SignatureServerClient alloc] initWithConfig:serverConfig];
    
    // Request signature from server
    [serverClient requestSignatureWithCompletion:^(SignatureParameters * _Nullable signatureParams, NSError * _Nullable error) {
        if (error) {
            SecuritySetupResult *result = [[SecuritySetupResult alloc] initWithSuccess:NO
                                                                               message:nil
                                                                                 error:error
                                                                       signatureParams:nil];
            if (completion) {
                completion(result);
            }
            return;
        }
        
        SecuritySetupResult *result = [[SecuritySetupResult alloc] initWithSuccess:YES
                                                                           message:@"Server-based security setup successful"
                                                                             error:nil
                                                                   signatureParams:signatureParams];
        if (completion) {
            completion(result);
        }
    }];
}

+ (void)setupEmbeddedSecurityWithConfig:(EmbeddedSecurityConfig *)config
                             completion:(void (^)(SecuritySetupResult *result))completion {
    // Generate signature parameters at application level
    SignatureConfig *signatureConfig = [[SignatureConfig alloc] initWithPrivateKeyPEM:config.privateKeyPEM
                                                                       certificateToken:config.certificateToken];
    
    NSError *error;
    SignatureParameters *signatureParams = [SignatureGenerator generateSignatureParametersWithConfig:signatureConfig
                                                                                              error:&error];
    
    if (error) {
        SecuritySetupResult *result = [[SecuritySetupResult alloc] initWithSuccess:NO
                                                                           message:nil
                                                                             error:error
                                                                   signatureParams:nil];
        if (completion) {
            completion(result);
        }
        return;
    }
    
    SecuritySetupResult *result = [[SecuritySetupResult alloc] initWithSuccess:YES
                                                                       message:@"Embedded security setup successful"
                                                                         error:nil
                                                               signatureParams:signatureParams];
    if (completion) {
        completion(result);
    }
}

@end 