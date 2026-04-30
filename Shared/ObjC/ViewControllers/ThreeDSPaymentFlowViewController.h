//
//  ThreeDSPaymentFlowViewController.h
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ThreeDSPaymentFlowViewController : UIViewController

- (instancetype)initWithGatewaySpecificFlow:(BOOL)useGatewaySpecific3DS;

@end

NS_ASSUME_NONNULL_END


