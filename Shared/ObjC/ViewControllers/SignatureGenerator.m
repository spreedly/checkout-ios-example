//
//  SignatureGenerator.m
//  SpreedlySDKExampleObjectiveC
//
//  Created by Vinay Naikade on 12/08/25.
//

#import "SignatureGenerator.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>

// MARK: - SignatureConfig Implementation

@implementation SignatureConfig

- (instancetype)initWithPrivateKeyPEM:(NSString *)privateKeyPEM
                      certificateToken:(NSString *)certificateToken {
    if (self = [super init]) {
        _privateKeyPEM = [privateKeyPEM copy];
        _certificateToken = [certificateToken copy];
    }
    return self;
}

@end

// MARK: - SignatureParameters Implementation

@implementation SignatureParameters

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

// MARK: - SignatureGenerator Implementation

@implementation SignatureGenerator

+ (nullable SignatureParameters *)generateSignatureParametersWithConfig:(SignatureConfig *)config
                                                                  error:(NSError **)error {
    // Generate nonce (UUID)
    NSString *nonce = [[NSUUID UUID] UUIDString];
    
    // Generate timestamp (Unix timestamp)
    NSInteger timestamp = (NSInteger)[[NSDate date] timeIntervalSince1970];
    
    // Create the data to sign: nonce + timestamp + certificateToken
    NSString *dataToSign = [NSString stringWithFormat:@"%@%ld%@", nonce, (long)timestamp, config.certificateToken];
    
    // Generate signature using private key
    NSString *signature = [self generateSignatureWithData:dataToSign privateKeyPEM:config.privateKeyPEM error:error];
    if (!signature) {
        return nil;
    }
    
    return [[SignatureParameters alloc] initWithNonce:nonce
                                            timestamp:timestamp
                                      certificateToken:config.certificateToken
                                             signature:signature];
}

+ (nullable NSString *)generateSignatureWithData:(NSString *)data
                                   privateKeyPEM:(NSString *)privateKeyPEM
                                           error:(NSError **)error {
    NSData *dataToSign = [data dataUsingEncoding:NSUTF8StringEncoding];
    if (!dataToSign) {
        if (error) {
            *error = [NSError errorWithDomain:@"SignatureGenerator"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid data provided for signature generation"}];
        }
        return nil;
    }
    
    // Parse the private key from PEM format
    SecKeyRef privateKey = [self parsePrivateKeyFromPEM:privateKeyPEM error:error];
    if (!privateKey) {
        return nil;
    }
    
    // Create signature using SHA256
    NSData *signatureData = [self createSignatureWithData:dataToSign privateKey:privateKey error:error];
    if (!signatureData) {
        CFRelease(privateKey);
        return nil;
    }
    
    CFRelease(privateKey);
    
    // Encode signature as Base64
    return [signatureData base64EncodedStringWithOptions:0];
}

+ (nullable SecKeyRef)parsePrivateKeyFromPEM:(NSString *)pemString error:(NSError **)error {
    // Remove PEM headers and footers
    NSString *cleanPEM = [pemString stringByReplacingOccurrencesOfString:@"-----BEGIN PRIVATE KEY-----" withString:@""];
    cleanPEM = [cleanPEM stringByReplacingOccurrencesOfString:@"-----END PRIVATE KEY-----" withString:@""];
    cleanPEM = [cleanPEM stringByReplacingOccurrencesOfString:@"-----BEGIN RSA PRIVATE KEY-----" withString:@""];
    cleanPEM = [cleanPEM stringByReplacingOccurrencesOfString:@"-----END RSA PRIVATE KEY-----" withString:@""];
    cleanPEM = [cleanPEM stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    cleanPEM = [cleanPEM stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    
    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:cleanPEM options:0];
    if (!keyData) {
        if (error) {
            *error = [NSError errorWithDomain:@"SignatureGenerator"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid private key format"}];
        }
        return NULL;
    }
    
    // Create key attributes
    NSDictionary *attributes = @{
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
        (__bridge id)kSecAttrKeyClass: (__bridge id)kSecAttrKeyClassPrivate,
        (__bridge id)kSecAttrKeySizeInBits: @3072
    };
    
    CFErrorRef cfError = NULL;
    SecKeyRef privateKey = SecKeyCreateWithData((__bridge CFDataRef)keyData, (__bridge CFDictionaryRef)attributes, &cfError);
    
    if (!privateKey) {
        if (error) {
            NSError *underlyingError = (__bridge_transfer NSError *)cfError;
            *error = [NSError errorWithDomain:@"SignatureGenerator"
                                         code:3
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Failed to create private key",
                                         NSUnderlyingErrorKey: underlyingError
                                     }];
        }
        return NULL;
    }
    
    return privateKey;
}

+ (nullable NSData *)createSignatureWithData:(NSData *)data
                                  privateKey:(SecKeyRef)privateKey
                                       error:(NSError **)error {
    SecKeyAlgorithm algorithm = kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA256;
    
    CFErrorRef cfError = NULL;
    CFDataRef signature = SecKeyCreateSignature(privateKey, algorithm, (__bridge CFDataRef)data, &cfError);
    
    if (!signature) {
        if (error) {
            NSError *underlyingError = (__bridge_transfer NSError *)cfError;
            *error = [NSError errorWithDomain:@"SignatureGenerator"
                                         code:4
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"Failed to create signature",
                                         NSUnderlyingErrorKey: underlyingError
                                     }];
        }
        return nil;
    }
    
    return (__bridge_transfer NSData *)signature;
}

@end 