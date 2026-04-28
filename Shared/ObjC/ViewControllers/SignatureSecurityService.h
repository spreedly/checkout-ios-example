//
//  SignatureSecurityService.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>
#import "SignatureGenerator.h"
#import "SignatureServerClient.h"

NS_ASSUME_NONNULL_BEGIN

/// Configuration for server-based security
@interface ServerSecurityConfig : NSObject

@property (nonatomic, strong, readonly) NSString *serverURL;
@property (nonatomic, strong, readonly, nullable) NSString *apiKey;
@property (nonatomic, strong, readonly) NSString *environmentKey;

- (instancetype)initWithServerURL:(NSString *)serverURL
                           apiKey:(nullable NSString *)apiKey
                   environmentKey:(NSString *)environmentKey;

@end

/// Configuration for embedded security (development only)
@interface EmbeddedSecurityConfig : NSObject

@property (nonatomic, strong, readonly) NSString *privateKeyPEM;
@property (nonatomic, strong, readonly) NSString *certificateToken;
@property (nonatomic, strong, readonly) NSString *environmentKey;

- (instancetype)initWithPrivateKeyPEM:(NSString *)privateKeyPEM
                      certificateToken:(NSString *)certificateToken
                       environmentKey:(NSString *)environmentKey;

@end

/// Result of security setup
@interface SecuritySetupResult : NSObject

@property (nonatomic, assign, readonly) BOOL success;
@property (nonatomic, strong, readonly, nullable) NSString *message;
@property (nonatomic, strong, readonly, nullable) NSError *error;
@property (nonatomic, strong, readonly, nullable) SignatureParameters *signatureParams;

- (instancetype)initWithSuccess:(BOOL)success
                        message:(nullable NSString *)message
                          error:(nullable NSError *)error
                signatureParams:(nullable SignatureParameters *)signatureParams;

@end

/// Test result for payment processing
@interface PaymentTestResult : NSObject

@property (nonatomic, assign, readonly) BOOL success;
@property (nonatomic, strong, readonly, nullable) NSString *paymentMethodToken;
@property (nonatomic, strong, readonly, nullable) NSString *error;

- (instancetype)initWithSuccess:(BOOL)success
              paymentMethodToken:(nullable NSString *)paymentMethodToken
                           error:(nullable NSString *)error;

@end

/// Server status information
@interface ServerStatus : NSObject

@property (nonatomic, assign, readonly) BOOL isAvailable;
@property (nonatomic, strong, readonly) NSString *message;

- (instancetype)initWithIsAvailable:(BOOL)isAvailable
                            message:(NSString *)message;

@end

/// Service class for handling signature generation and security setup
@interface SignatureSecurityService : NSObject

/// Checks if the signature server is available
/// @param config Server configuration
/// @param completion Completion block with server status information
+ (void)checkServerStatusWithConfig:(ServerSecurityConfig *)config
                         completion:(void (^)(ServerStatus *status))completion;

/// Sets up server-based security and tests payment processing
/// @param config Server security configuration
/// @param completion Completion block with combined setup and test result
+ (void)setupServerBasedSecurityWithConfig:(ServerSecurityConfig *)config
                                completion:(void (^)(SecuritySetupResult *result))completion;

/// Sets up embedded security and tests payment processing
/// @param config Embedded security configuration
/// @param completion Completion block with combined setup and test result
+ (void)setupEmbeddedSecurityWithConfig:(EmbeddedSecurityConfig *)config
                             completion:(void (^)(SecuritySetupResult *result))completion;

@end

NS_ASSUME_NONNULL_END 