//
//  APIResponseErrorParser.h
//  MerchantExample
//
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Extracts human-readable error messages from raw Spreedly API response data.
@interface APIResponseErrorParser : NSObject

/// Priority:
/// 1. transaction.message — most specific (transaction-level failure)
/// 2. errors[].message — validation errors (all joined)
/// 3. Top-level message — generic (auth failures, 404s, etc.)
+ (nullable NSString *)extractMessageFromData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
