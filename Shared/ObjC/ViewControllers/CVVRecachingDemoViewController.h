//
//  CVVRecachingDemoViewController.h
//  SpreedlySDKExampleObjectiveC
//
//  Created on 02/07/25.
//

#import <UIKit/UIKit.h>
#import <SpreedlyCore/SpreedlyCore-Swift.h> // For PaymentResult, PaymentProcessingResult
#import <SpreedlyUI/SpreedlyUI-Swift.h>     // For SpreedlyTheme, RecacheConfig, SavedCardInfo, ScreenPresentationMode

// Note: This is the demo/example view controller
// The SDK's CVVRecachingViewController is in SpreedlyUI module
@interface CVVRecachingDemoViewController : UIViewController <SpreedlyPaymentDelegate>

@end

