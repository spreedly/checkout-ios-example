//
//  DemoCustomValidationRecipes.h
//  SpreedlySDKExampleObjectiveC
//
//  QA-facing demo recipes for merchant custom field validators (Example only).
//

#import <Foundation/Foundation.h>
@import SpreedlyCore;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DemoCustomValidationKind) {
    DemoCustomValidationKindNone = 0,
    DemoCustomValidationKindMinLength3,
    DemoCustomValidationKindNoDigits,
    DemoCustomValidationKindDigitsOnly,
    DemoCustomValidationKindNoSpecialChars,
    DemoCustomValidationKindOnlyWhenCountryUS,
    DemoCustomValidationKindAlwaysInvalid
};

@interface DemoCustomValidationRecipes : NSObject

+ (NSString *)pickerLabelForKind:(DemoCustomValidationKind)kind;
+ (NSArray<NSNumber *> *)pickerKindsForFormFieldType:(FormFieldType)type;
+ (NSArray<NSNumber *> *)pickerKindsForNameFields;
+ (NSString *)displayTitleForWireKey:(NSString *)wireKey;
+ (NSString *)activeRulesSummaryFromSelections:(NSDictionary<NSString *, NSNumber *> *)selections;
+ (nullable NSString *)wireKeyForFormFieldType:(FormFieldType)type;
+ (void)removeAllManagedValidations;
/// selections: wire key → boxed DemoCustomValidationKind
+ (void)applySelections:(NSDictionary<NSString *, NSNumber *> *)selections;

@end

NS_ASSUME_NONNULL_END
