//
//  ApplePaySettingsViewController.h
//  SpreedlySDKExampleObjectiveC
//
//  Table-driven screens for the Apple Pay demo: button & theme, configuration, recurring options,
//  button-only, and one-time / recurring in the card drop-in. Every screen keeps its own settings,
//  reset on back.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ApplePaySettingsKind) {
    ApplePaySettingsKindButton = 0,
    ApplePaySettingsKindConfiguration,
    ApplePaySettingsKindRecurring,
    ApplePaySettingsKindButtonOnly,
    /// $1.00 with Apple Pay at the top of the card drop-in.
    ApplePaySettingsKindOneTime
};

@interface ApplePaySettingsViewController : UITableViewController

- (instancetype)initWithKind:(ApplePaySettingsKind)kind;

@end

NS_ASSUME_NONNULL_END
