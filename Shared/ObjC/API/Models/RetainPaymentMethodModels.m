//
//  RetainPaymentMethodModels.m
//  SpreedlySDKExampleObjectiveC
//
//  Created on [Date]
//

#import "RetainPaymentMethodModels.h"

// MARK: - RetainPaymentMethodMetadata Implementation

@implementation RetainPaymentMethodMetadata

- (instancetype)initWithCardType:(nullable NSString *)cardType {
    if (self = [super init]) {
        _cardType = [cardType copy];
    }
    return self;
}

@end

// MARK: - RetainPaymentMethodBinMetadata Implementation

@implementation RetainPaymentMethodBinMetadata

- (instancetype)initWithCardBrand:(nullable NSString *)cardBrand
                      issuingBank:(nullable NSString *)issuingBank
                         cardType:(nullable NSString *)cardType
                      cardCategory:(nullable NSString *)cardCategory
           issuingCountryIsoNumber:(nullable NSString *)issuingCountryIsoNumber
              issuingBankWebsite:(nullable NSString *)issuingBankWebsite
         issuingBankPhoneNumber:(nullable NSString *)issuingBankPhoneNumber
                    maxPanLength:(nullable NSNumber *)maxPanLength
                        binType:(nullable NSString *)binType
                       regulated:(nullable NSString *)regulated
        issuingCountryIsoA2Code:(nullable NSString *)issuingCountryIsoA2Code
        issuingCountryIsoA3Code:(nullable NSString *)issuingCountryIsoA3Code
         issuingCountryIsoName:(nullable NSString *)issuingCountryIsoName {
    if (self = [super init]) {
        _cardBrand = [cardBrand copy];
        _issuingBank = [issuingBank copy];
        _cardType = [cardType copy];
        _cardCategory = [cardCategory copy];
        _issuingCountryIsoNumber = [issuingCountryIsoNumber copy];
        _issuingBankWebsite = [issuingBankWebsite copy];
        _issuingBankPhoneNumber = [issuingBankPhoneNumber copy];
        _maxPanLength = maxPanLength;
        _binType = [binType copy];
        _regulated = [regulated copy];
        _issuingCountryIsoA2Code = [issuingCountryIsoA2Code copy];
        _issuingCountryIsoA3Code = [issuingCountryIsoA3Code copy];
        _issuingCountryIsoName = [issuingCountryIsoName copy];
    }
    return self;
}

@end

// MARK: - RetainPaymentMethod Implementation

@implementation RetainPaymentMethod

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        _token = dict[@"token"] ?: @"";
        _createdAt = dict[@"created_at"] ?: @"";
        _updatedAt = dict[@"updated_at"] ?: @"";
        _email = dict[@"email"];
        _data = dict[@"data"];
        _storageState = dict[@"storage_state"] ?: @"";
        _test = [dict[@"test"] boolValue];
        
        // Parse metadata
        NSDictionary *metadataDict = dict[@"metadata"];
        if (metadataDict && [metadataDict isKindOfClass:[NSDictionary class]]) {
            _metadata = [[RetainPaymentMethodMetadata alloc] initWithCardType:metadataDict[@"card_type"]];
        } else {
            _metadata = nil;
        }
        
        _callbackUrl = dict[@"callback_url"];
        _lastFourDigits = dict[@"last_four_digits"] ?: @"";
        _firstSixDigits = dict[@"first_six_digits"] ?: @"";
        _cardType = dict[@"card_type"] ?: @"";
        _firstName = dict[@"first_name"];
        _lastName = dict[@"last_name"];
        _month = dict[@"month"];
        _year = dict[@"year"];
        _address1 = dict[@"address1"];
        _address2 = dict[@"address2"];
        _city = dict[@"city"];
        _state = dict[@"state"];
        _zip = dict[@"zip"];
        _country = dict[@"country"];
        _phoneNumber = dict[@"phone_number"];
        _company = dict[@"company"];
        _fullName = dict[@"full_name"];
        _eligibleForCardUpdater = [dict[@"eligible_for_card_updater"] boolValue];
        _shippingAddress1 = dict[@"shipping_address1"];
        _shippingAddress2 = dict[@"shipping_address2"];
        _shippingCity = dict[@"shipping_city"];
        _shippingState = dict[@"shipping_state"];
        _shippingZip = dict[@"shipping_zip"];
        _shippingCountry = dict[@"shipping_country"];
        _shippingPhoneNumber = dict[@"shipping_phone_number"];
        _issuerIdentificationNumber = dict[@"issuer_identification_number"];
        _clickToPay = [dict[@"click_to_pay"] boolValue];
        _managed = [dict[@"managed"] boolValue];
        
        // Parse binMetadata
        NSDictionary *binMetadataDict = dict[@"bin_metadata"];
        if (binMetadataDict && [binMetadataDict isKindOfClass:[NSDictionary class]]) {
            _binMetadata = [[RetainPaymentMethodBinMetadata alloc] initWithCardBrand:binMetadataDict[@"card_brand"]
                                                                         issuingBank:binMetadataDict[@"issuing_bank"]
                                                                            cardType:binMetadataDict[@"card_type"]
                                                                         cardCategory:binMetadataDict[@"card_category"]
                                                              issuingCountryIsoNumber:binMetadataDict[@"issuing_country_iso_number"]
                                                                 issuingBankWebsite:binMetadataDict[@"issuing_bank_website"]
                                                            issuingBankPhoneNumber:binMetadataDict[@"issuing_bank_phone_number"]
                                                                       maxPanLength:binMetadataDict[@"max_pan_length"]
                                                                           binType:binMetadataDict[@"bin_type"]
                                                                          regulated:binMetadataDict[@"regulated"]
                                                           issuingCountryIsoA2Code:binMetadataDict[@"issuing_country_iso_a2_code"]
                                                           issuingCountryIsoA3Code:binMetadataDict[@"issuing_country_iso_a3_code"]
                                                            issuingCountryIsoName:binMetadataDict[@"issuing_country_iso_name"]];
        } else {
            _binMetadata = nil;
        }
        
        _subscribedToMastercardAbu = [dict[@"subscribed_to_mastercard_abu"] boolValue];
        _paymentMethodType = dict[@"payment_method_type"] ?: @"";
        _errors = dict[@"errors"] ?: @[];
        _fingerprint = dict[@"fingerprint"];
        _verificationValue = dict[@"verification_value"] ?: @"";
        _number = dict[@"number"] ?: @"";
    }
    return self;
}

@end

// MARK: - RetainPaymentMethodTransaction Implementation

@implementation RetainPaymentMethodTransaction

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        _token = dict[@"token"] ?: @"";
        _createdAt = dict[@"created_at"] ?: @"";
        _updatedAt = dict[@"updated_at"] ?: @"";
        _succeeded = [dict[@"succeeded"] boolValue];
        _transactionType = dict[@"transaction_type"] ?: @"";
        _state = dict[@"state"] ?: @"";
        _messageKey = dict[@"message_key"] ?: @"";
        _message = dict[@"message"] ?: @"";
        
        // Parse payment method
        NSDictionary *paymentMethodDict = dict[@"payment_method"];
        if (paymentMethodDict && [paymentMethodDict isKindOfClass:[NSDictionary class]]) {
            _paymentMethod = [[RetainPaymentMethod alloc] initWithDictionary:paymentMethodDict];
        } else {
            _paymentMethod = nil;
        }
    }
    return self;
}

@end

// MARK: - RetainPaymentMethodResponse Implementation

@interface RetainPaymentMethodResponse ()

@property (nonatomic, strong, readwrite) RetainPaymentMethodTransaction *transaction;

@end

@implementation RetainPaymentMethodResponse

- (instancetype)initWithTransaction:(RetainPaymentMethodTransaction *)transaction {
    if (self = [super init]) {
        _transaction = transaction;
    }
    return self;
}

+ (instancetype)fromJSONData:(NSData *)data error:(NSError **)error {
    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (jsonError) {
        if (error) *error = jsonError;
        return nil;
    }
    
    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"RetainPaymentMethodResponse" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid JSON format"}];
        }
        return nil;
    }
    
    // Parse transaction
    NSDictionary *transactionDict = json[@"transaction"];
    if (!transactionDict || ![transactionDict isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"RetainPaymentMethodResponse" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Missing or invalid transaction in response"}];
        }
        return nil;
    }
    
    RetainPaymentMethodTransaction *transaction = [[RetainPaymentMethodTransaction alloc] initWithDictionary:transactionDict];
    RetainPaymentMethodResponse *response = [[RetainPaymentMethodResponse alloc] initWithTransaction:transaction];
    
    return response;
}

@end

