//
//  FetchPaymentMethodsModels.m
//  MerchantExample
//
//
//

#import "FetchPaymentMethodsModels.h"

// MARK: - PaymentMethod Implementation

@implementation PaymentMethod

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        _token = dict[@"token"] ?: @"";
        _createdAt = dict[@"created_at"] ?: @"";
        _updatedAt = dict[@"updated_at"] ?: @"";
        _email = dict[@"email"];
        _storageState = dict[@"storage_state"] ?: @"";
        _test = [dict[@"test"] boolValue];
        _callbackUrl = dict[@"callback_url"];
        _lastFourDigits = dict[@"last_four_digits"];
        _firstSixDigits = dict[@"first_six_digits"];
        _cardType = dict[@"card_type"];
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
        _paymentMethodType = dict[@"payment_method_type"] ?: @"";
        _errors = dict[@"errors"] ?: @[];
    }
    return self;
}

@end

// MARK: - FetchPaymentMethodsResponse Implementation

@interface FetchPaymentMethodsResponse ()

@property (nonatomic, strong, readwrite) NSArray<PaymentMethod *> *paymentMethods;

@end

@implementation FetchPaymentMethodsResponse

- (instancetype)initWithPaymentMethods:(NSArray<PaymentMethod *> *)paymentMethods {
    if (self = [super init]) {
        _paymentMethods = [paymentMethods copy];
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
            *error = [NSError errorWithDomain:@"FetchPaymentMethodsResponse" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid JSON format"}];
        }
        return nil;
    }
    
    // Parse payment_methods array
    NSArray *paymentMethodsArray = json[@"payment_methods"];
    if (!paymentMethodsArray || ![paymentMethodsArray isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:@"FetchPaymentMethodsResponse" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Missing or invalid payment_methods array in response"}];
        }
        return nil;
    }
    
    NSMutableArray<PaymentMethod *> *paymentMethods = [NSMutableArray array];
    for (NSDictionary *paymentMethodDict in paymentMethodsArray) {
        if ([paymentMethodDict isKindOfClass:[NSDictionary class]]) {
            PaymentMethod *paymentMethod = [[PaymentMethod alloc] initWithDictionary:paymentMethodDict];
            [paymentMethods addObject:paymentMethod];
        }
    }
    
    FetchPaymentMethodsResponse *response = [[FetchPaymentMethodsResponse alloc] initWithPaymentMethods:[paymentMethods copy]];
    
    return response;
}

@end

