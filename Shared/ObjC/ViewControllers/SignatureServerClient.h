//
//  SignatureServerClient.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>
#import "SignatureGenerator.h"

NS_ASSUME_NONNULL_BEGIN

/// Configuration for the signature server
@interface ServerConfig : NSObject

@property (nonatomic, strong, readonly) NSString *baseURL;
@property (nonatomic, assign, readonly) NSTimeInterval timeoutInterval;
@property (nonatomic, strong, readonly, nullable) NSString *apiKey;

- (instancetype)initWithBaseURL:(NSString *)baseURL
                timeoutInterval:(NSTimeInterval)timeoutInterval
                         apiKey:(nullable NSString *)apiKey;

@end

/// Request model for signature generation
@interface SignatureRequest : NSObject

@property (nonatomic, strong, readonly) NSString *certificateToken;
@property (nonatomic, strong, readonly, nullable) NSString *nonce;
@property (nonatomic, strong, readonly, nullable) NSString *timestamp;

- (instancetype)initWithCertificateToken:(NSString *)certificateToken
                                   nonce:(nullable NSString *)nonce
                                timestamp:(nullable NSString *)timestamp;

@end

/// Response model from signature server
@interface SignatureResponse : NSObject

@property (nonatomic, strong, readonly) NSString *nonce;
@property (nonatomic, assign, readonly) NSInteger timestamp;
@property (nonatomic, strong, readonly) NSString *certificateToken;
@property (nonatomic, strong, readonly) NSString *signature;

- (instancetype)initWithNonce:(NSString *)nonce
                    timestamp:(NSInteger)timestamp
              certificateToken:(NSString *)certificateToken
                     signature:(NSString *)signature;

@end

/// Client for communicating with a local signature server
@interface SignatureServerClient : NSObject

- (instancetype)initWithConfig:(ServerConfig *)config;

/// Requests a signature from the local signature server
/// @param completion Completion block with signature parameters or error
- (void)requestSignatureWithCompletion:(void (^)(SignatureParameters * _Nullable signatureParams, NSError * _Nullable error))completion;

/// Checks if the signature server is available
/// @param completion Completion block with availability status
- (void)isServerAvailableWithCompletion:(void (^)(BOOL isAvailable))completion;

@end

NS_ASSUME_NONNULL_END 