//
//  SavedCard.m
//  MerchantExample
//
//
//

#import "SavedCard.h"

@implementation SavedCard

- (NSString *)displayName {
    return [NSString stringWithFormat:@"%@ •••• %@", self.cardType, self.lastFourDigits];
}

@end


