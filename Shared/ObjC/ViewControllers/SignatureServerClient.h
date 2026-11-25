//
//  SignatureServerClient.h
//  SpreedlySDKExampleObjectiveC
//
//  Created by Vinay Naikade on 12/08/25.
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

/// Adds the merchant backend's Basic login to `request` when one is configured.
/// Reads `SpreedlyBackendBasicAuthUser` and `SpreedlyBackendBasicAuthPassword` from Info.plist
/// (set in `SpreedlyKeys.xcconfig`); leaves the request unchanged when either is empty, or when the request
/// is not an HTTPS request to the origin (host, port) of `SpreedlyBaseURL`.
/// The login replaces any `Authorization` header already set, since a request carries only one.
FOUNDATION_EXPORT void SPLExampleApplyBackendBasicAuth(NSMutableURLRequest *request);

/// Same as `SPLExampleApplyBackendBasicAuth`, reading the login and `SpreedlyBaseURL` from `info` instead of the main bundle.
FOUNDATION_EXPORT void SPLExampleApplyBackendBasicAuthFromInfo(NSMutableURLRequest *request, NSDictionary * _Nullable info);

/// Whether `request` goes over HTTPS to the origin of `backendURL`, also HTTPS: host (case-insensitive) and port, a
/// missing port meaning 443. A missing or non-string URL, or plain HTTP on either side, never matches.
FOUNDATION_EXPORT BOOL SPLExampleIsBackendRequest(NSURLRequest *request, id _Nullable backendURL);

/// The `Authorization` value for a Basic login, or nil when the user or password is missing or blank, or the
/// user contains a colon. Values are not trimmed here.
FOUNDATION_EXPORT NSString * _Nullable SPLExampleBackendBasicAuthHeader(id _Nullable user, id _Nullable password);

/// The request to follow for a redirect, or nil to refuse it. Only a redirect to the same origin (scheme, host and
/// port) as the request that started it is followed; anything else, including HTTPS to HTTP, is refused, because a
/// 307 or 308 redirect re-sends the body as well as the headers. The task then ends with the redirect response.
FOUNDATION_EXPORT NSURLRequest * _Nullable SPLExampleRedirectRequest(NSURLRequest *redirect, NSURLRequest * _Nullable original);

/// A session whose redirects go through `SPLExampleRedirectRequest`. Use it for every backend request.
FOUNDATION_EXPORT NSURLSession *SPLExampleBackendSession(NSURLSessionConfiguration *configuration);

/// The session the backend clients share for a timeout: one per timeout for the life of the app, rather than a new
/// delegated session per client that is never invalidated.
FOUNDATION_EXPORT NSURLSession *SPLExampleSharedBackendSession(NSTimeInterval timeoutInterval);

/// The `redirect_url` an offsite purchase request should send.
/// Returns `nil` when `SpreedlyOmitRedirectURL` in Info.plist (`SPREEDLY_OMIT_REDIRECT_URL` in
/// `SpreedlyKeys.xcconfig`) is `YES`, `true` or `1`, so the backend uses its own return page: the
/// sample app backend refuses `redirect_url` values outside its own origin, such as app deep links.
/// Otherwise returns `appRedirectURL` unchanged.
FOUNDATION_EXPORT NSString * _Nullable SPLExampleBackendRedirectURL(NSString * _Nullable appRedirectURL);
/// One secret per app launch that proves to the sample app backend this app created a payment
/// method. The sample backend is designed to retain a payment method only when the retain request carries a
/// secret whose hash matches the `sample_app_owner` metadata stored on it.
FOUNDATION_EXPORT NSString *SPLExampleSampleAppOwnerSecret(void);

/// Metadata for cards tokenized on the screens that retain them: `sample_app_owner` = the secret's tag.
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *SPLExampleSampleAppOwnerMetadata(void);

/// The tag for `secret`, the value the backend compares against.
FOUNDATION_EXPORT NSString *SPLExampleSampleAppOwnerTag(NSString *secret);

/// Retain request body: `{"owner_secret": "<secret>"}` as JSON.
FOUNDATION_EXPORT NSData *SPLExampleSampleAppOwnerRetainBody(void);

NS_ASSUME_NONNULL_END 