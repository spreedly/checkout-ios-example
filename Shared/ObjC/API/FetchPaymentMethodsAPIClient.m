//
//  FetchPaymentMethodsAPIClient.m
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import "FetchPaymentMethodsAPIClient.h"
#import "SignatureServerClient.h" // For ServerConfig
#import "FetchPaymentMethodsModels.h"
#import "SavedPaymentMethodsStore.h"

@interface FetchPaymentMethodsAPIClient ()

/// Kept for the initializer's signature; the list is read from the device, so no request is made.
@property (nonatomic, strong) ServerConfig *config;

@end

@implementation FetchPaymentMethodsAPIClient

- (instancetype)initWithConfig:(ServerConfig *)config {
    if (self = [super init]) {
        _config = config;
    }
    return self;
}

/// The cards this app retained, newest first. The sample backend no longer lists payment methods
/// (a shared list would show every visitor's cards), so this reads the list kept on the device.
/// Reading it touches the Keychain and decrypts the list, so it runs on a background queue; `completion` is
/// called on that queue, and callers move to the main queue for UI work.
- (void)fetchPaymentMethodsWithCompletion:(void (^)(FetchPaymentMethodsResponse * _Nullable response, NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error = nil;
        FetchPaymentMethodsResponse *response = SPLExampleSavedPaymentMethodsResponse(&error);
        if (completion) {
            completion(response, error);
        }
    });
}

@end
