//
//  ThemeHelper.m
//  MerchantExample
//
//
//

#import "ThemeHelper.h"
#import <SpreedlyUI/SpreedlyUI-Swift.h>

@implementation ThemeHelper

// MARK: - Colors
// Dynamic colors matching SwiftUI examples with dark/light mode support
+ (UIColor *)primaryColor {
    return [UIColor colorWithRed:0.0/255.0 green:119.0/255.0 blue:200.0/255.0 alpha:1.0]; // #0077C8 (same for both modes)
}

+ (UIColor *)secondaryColor {
    return [UIColor colorWithRed:175.0/255.0 green:180.0/255.0 blue:181.0/255.0 alpha:1.0]; // #AFB4B5 (same for both modes)
}

+ (UIColor *)surfaceColor {
    // Card background: Light #FFFFFF, Dark #1C1C1E
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:30.0/255.0 alpha:1.0]; // #1C1C1E
        } else {
            return [UIColor whiteColor]; // #FFFFFF
        }
    }];
}

+ (UIColor *)textColor {
    // Primary text: use system label color (black/white)
    return [UIColor labelColor];
}

+ (UIColor *)textSecondaryColor {
    // Text secondary: Light #545859, Dark #AEAEB2
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:174.0/255.0 green:174.0/255.0 blue:178.0/255.0 alpha:1.0]; // #AEAEB2
        } else {
            return [UIColor colorWithRed:84.0/255.0 green:88.0/255.0 blue:89.0/255.0 alpha:1.0]; // #545859
        }
    }];
}

+ (UIColor *)borderColor {
    // Card border: Light #EFEDEA, Dark #3A3A3C
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:58.0/255.0 green:58.0/255.0 blue:60.0/255.0 alpha:1.0]; // #3A3A3C
        } else {
            return [UIColor colorWithRed:239.0/255.0 green:237.0/255.0 blue:234.0/255.0 alpha:1.0]; // #EFEDEA
        }
    }];
}

+ (UIColor *)errorColor {
    // Error: Light #DC3545, Dark #FF3B30
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:255.0/255.0 green:59.0/255.0 blue:48.0/255.0 alpha:1.0]; // #FF3B30
        } else {
            return [UIColor colorWithRed:220.0/255.0 green:53.0/255.0 blue:69.0/255.0 alpha:1.0]; // #DC3545
        }
    }];
}

+ (UIColor *)successColor {
    // Success: Light #28A745, Dark #34C759
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:52.0/255.0 green:199.0/255.0 blue:89.0/255.0 alpha:1.0]; // #34C759
        } else {
            return [UIColor colorWithRed:40.0/255.0 green:167.0/255.0 blue:69.0/255.0 alpha:1.0]; // #28A745
        }
    }];
}

+ (UIColor *)warningColor {
    // Warning: Light #FFC107, Dark #FF9500
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:255.0/255.0 green:149.0/255.0 blue:0.0/255.0 alpha:1.0]; // #FF9500
        } else {
            return [UIColor colorWithRed:255.0/255.0 green:193.0/255.0 blue:7.0/255.0 alpha:1.0]; // #FFC107
        }
    }];
}

// MARK: - Card-specific colors (matching SwiftUI examples)
+ (UIColor *)cardBackgroundColor {
    // Card background: Light #FFFFFF, Dark #1C1C1E
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:28.0/255.0 green:28.0/255.0 blue:30.0/255.0 alpha:1.0]; // #1C1C1E
        } else {
            return [UIColor whiteColor]; // #FFFFFF
        }
    }];
}

+ (UIColor *)cardBorderColor {
    // Card border: Light #EFEDEA, Dark #3A3A3C
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:58.0/255.0 green:58.0/255.0 blue:60.0/255.0 alpha:1.0]; // #3A3A3C
        } else {
            return [UIColor colorWithRed:239.0/255.0 green:237.0/255.0 blue:234.0/255.0 alpha:1.0]; // #EFEDEA
        }
    }];
}

+ (UIColor *)cardShadowColor {
    // Card shadow: Light #AFB4B5 80%, Dark black 50%
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [[UIColor blackColor] colorWithAlphaComponent:0.5]; // black 50%
        } else {
            return [UIColor colorWithRed:175.0/255.0 green:180.0/255.0 blue:181.0/255.0 alpha:0.8]; // #AFB4B5 80%
        }
    }];
}

+ (UIColor *)cellBackgroundColor {
    // Cell background: Dark #2C2C2E (elevated from surface #1C1C1E so cells stand out), Light systemGray6
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:44.0/255.0 green:44.0/255.0 blue:46.0/255.0 alpha:1.0]; // #2C2C2E
        } else {
            return [UIColor systemGray6Color];
        }
    }];
}

+ (UIColor *)selectedCellBackgroundColor {
    // Selected cell: same as cell in dark mode (border + checkmark show selection); primary 0.1 in light
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:44.0/255.0 green:44.0/255.0 blue:46.0/255.0 alpha:1.0]; // #2C2C2E, same as cellBackgroundColor
        } else {
            return [[self primaryColor] colorWithAlphaComponent:0.1];
        }
    }];
}

// MARK: - Typography
// Using Poppins font if available, otherwise system font
+ (UIFont *)titleFont {
    UIFont *font = [UIFont fontWithName:@"Poppins-Medium" size:16];
    if (!font) {
        font = [UIFont fontWithName:@"Poppins" size:16];
    }
    return font ?: [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
}

+ (UIFont *)subtitleFont {
    UIFont *font = [UIFont fontWithName:@"Poppins-Medium" size:14];
    if (!font) {
        font = [UIFont fontWithName:@"Poppins" size:14];
    }
    return font ?: [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
}

+ (UIFont *)bodyFont {
    UIFont *font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    if (@available(iOS 14.0, *)) {
        UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
        if (descriptor) {
            font = [UIFont fontWithDescriptor:descriptor size:16];
        }
    }
    return font;
}

+ (UIFont *)captionFont {
    UIFont *font = [UIFont fontWithName:@"Poppins" size:12];
    return font ?: [UIFont systemFontOfSize:12];
}

+ (UIFont *)buttonFont {
    UIFont *font = [UIFont fontWithName:@"Poppins" size:16];
    return font ?: [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
}

+ (UIFont *)fieldFont {
    UIFont *font = [UIFont fontWithName:@"Poppins" size:16];
    return font ?: [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
}

// MARK: - Screen Typography (SwiftUI system fonts)
+ (UIFont *)screenTitleFont {
    return [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
}

+ (UIFont *)screenHeadlineFont {
    return [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
}

+ (UIFont *)screenSubheadlineFont {
    return [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
}

+ (UIFont *)screenBodyFont {
    return [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
}

+ (UIFont *)screenCaptionFont {
    return [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
}

// MARK: - Spacing
+ (CGFloat)spacingXS {
    return 4.0;
}

+ (CGFloat)spacingSM {
    return 8.0;
}

+ (CGFloat)spacingMD {
    return 16.0;
}

+ (CGFloat)spacingLG {
    return 24.0;
}

+ (CGFloat)spacingXL {
    return 32.0;
}

// MARK: - Border Radius
+ (CGFloat)borderRadiusXS {
    return 4.0;
}

+ (CGFloat)borderRadiusSM {
    return 8.0;
}

+ (CGFloat)borderRadiusMD {
    return 8.0;
}

+ (CGFloat)borderRadiusLG {
    return 12.0;
}

+ (CGFloat)borderRadiusXL {
    return 16.0;
}

// MARK: - Shadows
+ (void)applySmallShadowToView:(UIView *)view {
    // Apply shadow with dynamic color matching SwiftUI examples
    // Note: We'll update the shadow color when trait collection changes
    [self updateShadowForView:view];
    view.layer.shadowOffset = CGSizeMake(0, 0);
    view.layer.shadowRadius = 4.0;
    view.layer.shadowOpacity = 1.0; // Use full opacity since alpha is in the color
}

// Helper method to update shadow color based on trait collection
+ (void)updateShadowForView:(UIView *)view {
    UIColor *shadowColor = [self cardShadowColor];
    // Resolve the color for the current trait collection
    UIColor *resolvedColor = [shadowColor resolvedColorWithTraitCollection:view.traitCollection];
    view.layer.shadowColor = resolvedColor.CGColor;
}

@end

