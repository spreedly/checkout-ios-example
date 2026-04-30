//
//  SavedCard.m
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import "SavedCard.h"

@implementation SavedCard

- (NSString *)displayName {
    return [NSString stringWithFormat:@"%@ •••• %@", self.cardType, self.lastFourDigits];
}

@end


