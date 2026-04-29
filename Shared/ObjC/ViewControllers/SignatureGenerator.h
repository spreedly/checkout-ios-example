//
//  SignatureGenerator.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Configuration for certificate-based signature generation
@interface SignatureConfig : NSObject

@property (nonatomic, strong, readonly) NSString *privateKeyPEM;
@property (nonatomic, strong, readonly) NSString *certificateToken;

- (instancetype)initWithPrivateKeyPEM:(NSString *)privateKeyPEM
                      certificateToken:(NSString *)certificateToken;

@end

/// Signature parameters required for the request
@interface SignatureParameters : NSObject

@property (nonatomic, strong, readonly) NSString *nonce;
@property (nonatomic, assign, readonly) NSInteger timestamp;
@property (nonatomic, strong, readonly) NSString *certificateToken;
@property (nonatomic, strong, readonly) NSString *signature;

- (instancetype)initWithNonce:(NSString *)nonce
                    timestamp:(NSInteger)timestamp
              certificateToken:(NSString *)certificateToken
                     signature:(NSString *)signature;

@end

/// Utility for generating certificate-based signatures for enhanced iFrame security
@interface SignatureGenerator : NSObject

/// Generates signature parameters for enhanced iFrame security
/// @param config The signature configuration containing private key and certificate token
/// @param error Pointer to error object if signature generation fails
/// @return Signature parameters including nonce, timestamp, certificate token, and signature
+ (nullable SignatureParameters *)generateSignatureParametersWithConfig:(SignatureConfig *)config
                                                                  error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END 