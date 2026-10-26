//
//  MerchantCatalogueFieldValidation.h
//  SpreedlySDKExampleObjectiveC
//
//  Example-app only — Android sample-app error copy for merchant-owned UITextFields
//  (not Spreedly SDK validators). Used by CustomMerchantTextFieldsDemoViewController.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MerchantCatalogueFieldValidation : NSObject

+ (nullable NSString *)nameErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired;
+ (nullable NSString *)addressErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired;
+ (nullable NSString *)cityErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired;
+ (nullable NSString *)stateErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired;
+ (nullable NSString *)zipErrorMessageForValue:(NSString *)value isRequired:(BOOL)isRequired;

@end

NS_ASSUME_NONNULL_END
