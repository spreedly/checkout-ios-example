//
//  APIResponseErrorParser.m
//  MerchantExample
//
//
//

#import "APIResponseErrorParser.h"

@implementation APIResponseErrorParser

+ (nullable NSString *)extractMessageFromData:(NSData *)data {
    if (!data || data.length == 0) {
        return nil;
    }

    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![jsonObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *json = (NSDictionary *)jsonObject;

    // 1. transaction.message (most specific)
    if ([json[@"transaction"] isKindOfClass:[NSDictionary class]]) {
        NSString *message = json[@"transaction"][@"message"];
        if ([message isKindOfClass:[NSString class]] && message.length > 0) {
            return message;
        }
    }

    // 2. errors[].message (all joined)
    if ([json[@"errors"] isKindOfClass:[NSArray class]]) {
        NSArray *errors = json[@"errors"];
        NSMutableArray<NSString *> *messages = [NSMutableArray array];
        for (id errorObj in errors) {
            if ([errorObj isKindOfClass:[NSDictionary class]]) {
                NSString *message = errorObj[@"message"];
                if ([message isKindOfClass:[NSString class]] && message.length > 0) {
                    [messages addObject:message];
                }
            }
        }
        if (messages.count > 0) {
            return [messages componentsJoinedByString:@", "];
        }
    }

    // 3. Top-level message (generic)
    if ([json[@"message"] isKindOfClass:[NSString class]]) {
        NSString *message = json[@"message"];
        if (message.length > 0) {
            return message;
        }
    }

    return nil;
}

@end
