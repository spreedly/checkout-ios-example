//
//  SavedCard.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Example model for Objective-C/UIKit demo. Similar SavedCard struct exists in SwiftUI example.
/// In production, fetch saved payment methods from your backend or local storage.
/// Used by both CVVRecachingDemoViewController and ThreeDSPaymentFlowViewController
@interface SavedCard : NSObject

@property (nonatomic, strong) NSString *cardId;
@property (nonatomic, strong) NSString *paymentMethodToken;
@property (nonatomic, strong) NSString *lastFourDigits;
@property (nonatomic, strong) NSString *cardType;
@property (nonatomic, strong) NSString *cardBrand;
@property (nonatomic, strong, nullable) NSString *expiryMonth;
@property (nonatomic, strong, nullable) NSString *expiryYear;

- (NSString *)displayName;

@end

NS_ASSUME_NONNULL_END


