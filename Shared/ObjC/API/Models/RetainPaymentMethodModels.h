//
//  RetainPaymentMethodModels.h
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class RetainPaymentMethodTransaction, RetainPaymentMethod, RetainPaymentMethodBinMetadata, RetainPaymentMethodMetadata;

@interface RetainPaymentMethodResponse : NSObject
@property (nonatomic, strong, readonly) RetainPaymentMethodTransaction *transaction;
+ (instancetype)fromJSONData:(NSData *)data error:(NSError **)error;
- (instancetype)initWithTransaction:(RetainPaymentMethodTransaction *)transaction;
@end

@interface RetainPaymentMethodTransaction : NSObject
@property (nonatomic, strong, readonly) NSString *token;
@property (nonatomic, strong, readonly) NSString *createdAt;
@property (nonatomic, strong, readonly) NSString *updatedAt;
@property (nonatomic, assign, readonly) BOOL succeeded;
@property (nonatomic, strong, readonly) NSString *transactionType;
@property (nonatomic, strong, readonly) NSString *state;
@property (nonatomic, strong, readonly) NSString *messageKey;
@property (nonatomic, strong, readonly) NSString *message;
@property (nonatomic, strong, readonly) RetainPaymentMethod *paymentMethod;
@end

@interface RetainPaymentMethodMetadata : NSObject
@property (nonatomic, strong, readonly, nullable) NSString *cardType;
@end

@interface RetainPaymentMethod : NSObject
@property (nonatomic, strong, readonly) NSString *token;
@property (nonatomic, strong, readonly) NSString *createdAt;
@property (nonatomic, strong, readonly) NSString *updatedAt;
@property (nonatomic, strong, readonly, nullable) NSString *email;
@property (nonatomic, strong, readonly, nullable) NSString *data;
@property (nonatomic, strong, readonly) NSString *storageState;
@property (nonatomic, assign, readonly) BOOL test;
@property (nonatomic, strong, readonly, nullable) RetainPaymentMethodMetadata *metadata;
@property (nonatomic, strong, readonly, nullable) NSString *callbackUrl;
@property (nonatomic, strong, readonly) NSString *lastFourDigits;
@property (nonatomic, strong, readonly) NSString *firstSixDigits;
@property (nonatomic, strong, readonly) NSString *cardType;
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
@property (nonatomic, assign, readonly) BOOL eligibleForCardUpdater;
@property (nonatomic, strong, readonly, nullable) NSString *shippingAddress1;
@property (nonatomic, strong, readonly, nullable) NSString *shippingAddress2;
@property (nonatomic, strong, readonly, nullable) NSString *shippingCity;
@property (nonatomic, strong, readonly, nullable) NSString *shippingState;
@property (nonatomic, strong, readonly, nullable) NSString *shippingZip;
@property (nonatomic, strong, readonly, nullable) NSString *shippingCountry;
@property (nonatomic, strong, readonly, nullable) NSString *shippingPhoneNumber;
@property (nonatomic, strong, readonly, nullable) NSString *issuerIdentificationNumber;
@property (nonatomic, assign, readonly) BOOL clickToPay;
@property (nonatomic, assign, readonly) BOOL managed;
@property (nonatomic, strong, readonly, nullable) RetainPaymentMethodBinMetadata *binMetadata;
@property (nonatomic, assign, readonly) BOOL subscribedToMastercardAbu;
@property (nonatomic, strong, readonly) NSString *paymentMethodType;
@property (nonatomic, strong, readonly) NSArray<NSString *> *errors;
@property (nonatomic, strong, readonly, nullable) NSString *fingerprint;
@property (nonatomic, strong, readonly) NSString *verificationValue;
@property (nonatomic, strong, readonly) NSString *number;
@end

@interface RetainPaymentMethodBinMetadata : NSObject
@property (nonatomic, strong, readonly, nullable) NSString *cardBrand;
@property (nonatomic, strong, readonly, nullable) NSString *issuingBank;
@property (nonatomic, strong, readonly, nullable) NSString *cardType;
@property (nonatomic, strong, readonly, nullable) NSString *cardCategory;
@property (nonatomic, strong, readonly, nullable) NSString *issuingCountryIsoNumber;
@property (nonatomic, strong, readonly, nullable) NSString *issuingBankWebsite;
@property (nonatomic, strong, readonly, nullable) NSString *issuingBankPhoneNumber;
@property (nonatomic, strong, readonly, nullable) NSNumber *maxPanLength;
@property (nonatomic, strong, readonly, nullable) NSString *binType;
@property (nonatomic, strong, readonly, nullable) NSString *regulated;
@property (nonatomic, strong, readonly, nullable) NSString *issuingCountryIsoA2Code;
@property (nonatomic, strong, readonly, nullable) NSString *issuingCountryIsoA3Code;
@property (nonatomic, strong, readonly, nullable) NSString *issuingCountryIsoName;
@end

NS_ASSUME_NONNULL_END

