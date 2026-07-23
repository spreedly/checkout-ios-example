//
//  ThemeHelper.h
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Helper class to access theme values in Objective-C
/// Provides UIKit-compatible access to Spreedly theme properties
@interface ThemeHelper : NSObject

// MARK: - Colors
+ (UIColor *)primaryColor;
+ (UIColor *)secondaryColor;
+ (UIColor *)surfaceColor;
+ (UIColor *)textColor;
+ (UIColor *)textSecondaryColor;
+ (UIColor *)merchantProductPriceColor;
+ (UIColor *)borderColor;
+ (UIColor *)errorColor;
+ (UIColor *)successColor;
+ (UIColor *)warningColor;

// MARK: - Card-specific colors
+ (UIColor *)cardBackgroundColor;
+ (UIColor *)cardBorderColor;
+ (UIColor *)cardShadowColor;

/// Cell background for list items (product cards, payment method rows). Elevated in dark mode (#2C2C2E) so cells stand out from list surface.
+ (UIColor *)cellBackgroundColor;
/// Selected cell background: same as cell in dark mode (border + checkmark show selection); primary 0.1 in light.
+ (UIColor *)selectedCellBackgroundColor;

// MARK: - Typography
+ (UIFont *)titleFont;
+ (UIFont *)subtitleFont;
+ (UIFont *)bodyFont;
+ (UIFont *)captionFont;
+ (UIFont *)buttonFont;
+ (UIFont *)fieldFont;

// MARK: - Screen Typography (SwiftUI system fonts)
+ (UIFont *)screenTitleFont;
+ (UIFont *)screenHeadlineFont;
+ (UIFont *)screenSubheadlineFont;
+ (UIFont *)screenBodyFont;
+ (UIFont *)screenCaptionFont;

// MARK: - Spacing
+ (CGFloat)spacingXS;
+ (CGFloat)spacingSM;
+ (CGFloat)spacingMD;
+ (CGFloat)spacingLG;
+ (CGFloat)spacingXL;

// MARK: - Border Radius
+ (CGFloat)borderRadiusXS;
+ (CGFloat)borderRadiusSM;
+ (CGFloat)borderRadiusMD;
+ (CGFloat)borderRadiusLG;
+ (CGFloat)borderRadiusXL;

// MARK: - Shadows
+ (void)applySmallShadowToView:(UIView *)view;
+ (void)updateShadowForView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END

