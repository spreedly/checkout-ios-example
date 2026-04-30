//
//  FetchPaymentMethodsModels.h
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PaymentMethod;

@interface FetchPaymentMethodsResponse : NSObject
@property (nonatomic, strong, readonly) NSArray<PaymentMethod *> *paymentMethods;
+ (instancetype)fromJSONData:(NSData *)data error:(NSError **)error;
- (instancetype)initWithPaymentMethods:(NSArray<PaymentMethod *> *)paymentMethods;
@end

@interface PaymentMethod : NSObject
@property (nonatomic, strong, readonly) NSString *token;
@property (nonatomic, strong, readonly) NSString *createdAt;
@property (nonatomic, strong, readonly) NSString *updatedAt;
@property (nonatomic, strong, readonly, nullable) NSString *email;
@property (nonatomic, strong, readonly) NSString *storageState;
@property (nonatomic, assign, readonly) BOOL test;
@property (nonatomic, strong, readonly, nullable) NSString *callbackUrl;
@property (nonatomic, strong, readonly, nullable) NSString *lastFourDigits;
@property (nonatomic, strong, readonly, nullable) NSString *firstSixDigits;
@property (nonatomic, strong, readonly, nullable) NSString *cardType;
@property (nonatomic, strong, readonly, nullable) NSString *firstName;
@property (nonatomic, strong, readonly, nullable) NSString *lastName;
@property (nonatomic, strong, readonly, nullable) NSNumber *month;
@property (nonatomic, strong, readonly, nullable) NSNumber *year;
@property (nonatomic, strong, readonly, nullable) NSString *address1;
@property (nonatomic, strong, readonly, nullable) NSString *address2;
@property (nonatomic, strong, readonly, nullable) NSString *city;
@property (nonatomic, strong, readonly, nullable) NSString *state;
@property (nonatomic, strong, readonly, nullable) NSString *zip;
@property (nonatomic, strong, readonly, nullable) NSString *country;
@property (nonatomic, strong, readonly, nullable) NSString *phoneNumber;
@property (nonatomic, strong, readonly, nullable) NSString *company;
@property (nonatomic, strong, readonly, nullable) NSString *fullName;
@property (nonatomic, strong, readonly) NSString *paymentMethodType;
@property (nonatomic, strong, readonly) NSArray<NSString *> *errors;
@end

NS_ASSUME_NONNULL_END

