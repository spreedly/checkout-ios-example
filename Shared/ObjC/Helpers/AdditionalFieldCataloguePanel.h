//
//  AdditionalFieldCataloguePanel.h
//  SpreedlySDKExampleObjectiveC
//
//  Shared Optional address groups + Additional Fields Configuration panel
//  for drop-in and headless ObjC demos.
//

#import <UIKit/UIKit.h>
#import "DemoCustomValidationRecipes.h"
@import SpreedlyUI;

NS_ASSUME_NONNULL_BEGIN

/// Owns catalogue row dictionaries (@{ id, title, type, enabled, required, customRule, enableSwitch, requiredSwitch, ruleButton }).
@interface AdditionalFieldCataloguePanel : UIView

@property (nonatomic, copy, readonly) NSString *accessibilityPrefix;
@property (nonatomic, strong, readonly) NSMutableArray<NSMutableDictionary *> *catalogueRows;
@property (nonatomic, weak, nullable) UIViewController *hostViewController;
@property (nonatomic, copy, nullable) void (^onCatalogueChanged)(void);

/// Builds groups card + collapsible config. `leadingDetailViews` are inserted at the top of the expanded config (e.g. first/last name rules).
- (instancetype)initWithAccessibilityPrefix:(NSString *)accessibilityPrefix
                         leadingDetailViews:(nullable NSArray<UIView *> *)leadingDetailViews;

- (NSDictionary<NSString *, NSNumber *> *)catalogueCustomValidationSelections;
- (NSArray<FormField *> *)enabledFormFields;

+ (NSArray<NSString *> *)billingGroupIds;
+ (NSArray<NSString *> *)shippingGroupIds;
+ (NSArray<NSString *> *)emailGroupIds;

@end

NS_ASSUME_NONNULL_END
