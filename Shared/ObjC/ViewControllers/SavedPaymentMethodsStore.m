//
//  SavedPaymentMethodsStore.m
//  SpreedlySDKExampleObjectiveC
//

#import "SavedPaymentMethodsStore.h"
#import "RetainPaymentMethodModels.h"
#import "FetchPaymentMethodsModels.h"
#import "SignatureServerClient.h" // SPLExampleSampleAppOwnerTag
#import <CommonCrypto/CommonCrypto.h>
#import <Security/Security.h>

NSString *const SPLExampleSavedPaymentMethodsLegacyKey = @"spreedlySampleApp.savedPaymentMethods";
const NSUInteger SPLExampleSavedPaymentMethodsMax = 20;
const NSTimeInterval SPLExampleSavedPaymentMethodsMaxAge = 30 * 24 * 60 * 60;

NSString *SPLExampleSavedPaymentMethodsStorageKeyForInfo(NSDictionary * _Nullable info) {
    id baseURL = info[@"SpreedlyBaseURL"];
    id environmentKey = info[@"SpreedlyEnvironmentKey"];
    NSString *configuration = [NSString stringWithFormat:@"%@|%@",
                               [baseURL isKindOfClass:[NSString class]] ? baseURL : @"",
                               [environmentKey isKindOfClass:[NSString class]] ? environmentKey : @""];
    NSString *scope = [SPLExampleSampleAppOwnerTag(configuration) substringToIndex:16];
    return [NSString stringWithFormat:@"%@.%@", SPLExampleSavedPaymentMethodsLegacyKey, scope];
}

NSString *SPLExampleSavedPaymentMethodsStorageKey(void) {
    return SPLExampleSavedPaymentMethodsStorageKeyForInfo([NSBundle mainBundle].infoDictionary);
}

BOOL SPLExampleSavedCardIsExpired(NSDictionary *card, NSDate *now) {
    id month = card[@"month"];
    id year = card[@"year"];
    if (![month isKindOfClass:[NSNumber class]] || ![year isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *today = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:now];
    NSInteger cardYear = [year integerValue];
    NSInteger cardMonth = [month integerValue];
    return cardYear < today.year || (cardYear == today.year && cardMonth < today.month);
}

BOOL SPLExampleSavedCardIsStale(NSDictionary *card, NSDate *now) {
    id savedAt = card[@"saved_at"];
    if (![savedAt isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    return now.timeIntervalSince1970 - [savedAt doubleValue] > SPLExampleSavedPaymentMethodsMaxAge;
}

#pragma mark - Encryption key (Keychain, never migrated to another device)

// The saved list is encrypted before it goes into UserDefaults, with a key kept in the Keychain that can be
// restored only to the device that created it, so a copied preferences file, or a backup restored to another
// device, can't be read.
//
// Deleting the app removes its UserDefaults but not its Keychain items. A marker in UserDefaults records that
// the key exists for this install; without it (first install, or delete and reinstall) any key left behind is
// deleted and a new one made. A backup restored to the same device is expected to bring back both, so its list
// stays readable (Apple's ThisDeviceOnly behaviour; not tested on a device).
//
// Apart from that first-use reset, only a missing key or one of the wrong length is replaced. Any other Keychain
// error (for example the device hasn't been unlocked since a restart) changes nothing, even on first use, and
// yields nil, so no saved card is lost; the next use tries again.

static NSString *const SPLExampleSavedCardsKeyService = @"com.spreedly.sampleapp.savedPaymentMethods";
NSString *const SPLExampleSavedCardsKeyAccount = @"listEncryptionKey";
// Not under SPLExampleSavedPaymentMethodsLegacyKey, so clearing saved cards keeps it.
NSString *const SPLExampleSavedCardsKeyInstallMarker = @"spreedlySampleAppSavedCardsKeyReady";
static const size_t SPLExampleSavedCardsKeyLength = 64;
static const uint8_t SPLExampleSavedCardsFormatVersion = 2;

static NSDictionary *SPLExampleSavedCardsKeyQuery(NSString *account) {
    return @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrService: SPLExampleSavedCardsKeyService,
              (__bridge id)kSecAttrAccount: account };
}

NSData * _Nullable SPLExampleSavedCardsReadKey(NSString *account, OSStatus * _Nullable status) {
    NSMutableDictionary *query = [SPLExampleSavedCardsKeyQuery(account) mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus copyStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (copyStatus == errSecSuccess && !result) {
        copyStatus = errSecDecode;
    }
    if (status) {
        *status = copyStatus;
    }
    return copyStatus == errSecSuccess ? (__bridge_transfer NSData *)result : nil;
}

void SPLExampleSavedCardsDeleteKey(NSString *account) {
    SecItemDelete((__bridge CFDictionaryRef)SPLExampleSavedCardsKeyQuery(account));
}

static NSData * _Nullable SPLExampleSavedCardsCreateKey(NSUserDefaults *defaults, NSString *account) {
    NSMutableData *key = [NSMutableData dataWithLength:SPLExampleSavedCardsKeyLength];
    if (SecRandomCopyBytes(kSecRandomDefault, key.length, key.mutableBytes) != errSecSuccess) {
        return nil;
    }
    NSMutableDictionary *query = [SPLExampleSavedCardsKeyQuery(account) mutableCopy];
    query[(__bridge id)kSecValueData] = key;
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    if (SecItemAdd((__bridge CFDictionaryRef)query, NULL) != errSecSuccess) {
        return nil;
    }
    [defaults setBool:YES forKey:SPLExampleSavedCardsKeyInstallMarker];
    return [key copy];
}

NSData * _Nullable SPLExampleSavedCardsLoadOrCreateKeyWithReader(NSUserDefaults *defaults, NSString *account,
                                                                 SPLExampleSavedCardsKeyReader reader) {
    OSStatus status = errSecSuccess;
    NSData *stored = reader(account, &status);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        // Temporary (device locked since restart) or unexpected: change nothing, keep the key and the saved
        // cards, and try again on the next use.
        return nil;
    }
    if (![defaults boolForKey:SPLExampleSavedCardsKeyInstallMarker]) {
        // First use on this install: a key left by an earlier install must not decrypt anything.
        SPLExampleSavedCardsDeleteKey(account);
        return SPLExampleSavedCardsCreateKey(defaults, account);
    }
    if (status == errSecSuccess && stored.length == SPLExampleSavedCardsKeyLength) {
        return stored;
    }
    // Missing, or not a key this app wrote: replace it. Anything stored with the old key is unreadable
    // anyway and is deleted when the list is next read.
    SPLExampleSavedCardsDeleteKey(account);
    return SPLExampleSavedCardsCreateKey(defaults, account);
}

NSData * _Nullable SPLExampleSavedCardsLoadOrCreateKey(NSUserDefaults *defaults, NSString *account) {
    return SPLExampleSavedCardsLoadOrCreateKeyWithReader(defaults, account, ^NSData *(NSString *name, OSStatus *status) {
        return SPLExampleSavedCardsReadKey(name, status);
    });
}

/// This launch's key, or nil while the Keychain can't be read. Only a loaded key is kept, so a temporary
/// error is retried on the next use.
static NSData * _Nullable SPLExampleSavedCardsSharedKey(void) {
    static NSData *key;
    static NSLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        lock = [[NSLock alloc] init];
    });
    [lock lock];
    if (!key) {
        key = SPLExampleSavedCardsLoadOrCreateKey([NSUserDefaults standardUserDefaults], SPLExampleSavedCardsKeyAccount);
    }
    NSData *loaded = key;
    [lock unlock];
    return loaded;
}

/// The integrity value for `message` in this slot, so data only reads back in the slot it was written for.
static NSData *SPLExampleSavedCardsMAC(NSData *macKey, NSString *storageKey, NSData *message) {
    NSData *context = [storageKey dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    uint32_t contextLength = CFSwapInt32HostToBig((uint32_t)context.length);
    CCHmacContext hmac;
    CCHmacInit(&hmac, kCCHmacAlgSHA256, macKey.bytes, macKey.length);
    CCHmacUpdate(&hmac, &contextLength, sizeof(contextLength));
    CCHmacUpdate(&hmac, context.bytes, context.length);
    CCHmacUpdate(&hmac, message.bytes, message.length);
    NSMutableData *mac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmacFinal(&hmac, mac.mutableBytes);
    return mac;
}

NSData * _Nullable SPLExampleSavedCardsEncryptWithKey(NSData *plaintext, NSString *storageKey, NSData * _Nullable key) {
    if (key.length != SPLExampleSavedCardsKeyLength) {
        return nil;
    }
    NSData *encKey = [key subdataWithRange:NSMakeRange(0, kCCKeySizeAES256)];
    NSData *macKey = [key subdataWithRange:NSMakeRange(kCCKeySizeAES256, CC_SHA256_DIGEST_LENGTH)];
    NSMutableData *iv = [NSMutableData dataWithLength:kCCBlockSizeAES128];
    if (SecRandomCopyBytes(kSecRandomDefault, iv.length, iv.mutableBytes) != errSecSuccess) {
        return nil;
    }
    NSMutableData *ciphertext = [NSMutableData dataWithLength:plaintext.length + kCCBlockSizeAES128];
    size_t written = 0;
    CCCryptorStatus status = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                     encKey.bytes, encKey.length, iv.bytes,
                                     plaintext.bytes, plaintext.length,
                                     ciphertext.mutableBytes, ciphertext.length, &written);
    if (status != kCCSuccess) {
        return nil;
    }
    ciphertext.length = written;
    NSMutableData *sealed = [NSMutableData dataWithBytes:&SPLExampleSavedCardsFormatVersion length:1];
    [sealed appendData:iv];
    [sealed appendData:ciphertext];
    [sealed appendData:SPLExampleSavedCardsMAC(macKey, storageKey, sealed)];
    return sealed;
}

NSData * _Nullable SPLExampleSavedCardsDecryptWithKey(NSData *sealed, NSString *storageKey, NSData * _Nullable key) {
    const NSUInteger headerLength = 1 + kCCBlockSizeAES128;
    if (key.length != SPLExampleSavedCardsKeyLength
        || sealed.length < headerLength + kCCBlockSizeAES128 + CC_SHA256_DIGEST_LENGTH
        || ((const uint8_t *)sealed.bytes)[0] != SPLExampleSavedCardsFormatVersion) {
        return nil;
    }
    NSData *encKey = [key subdataWithRange:NSMakeRange(0, kCCKeySizeAES256)];
    NSData *macKey = [key subdataWithRange:NSMakeRange(kCCKeySizeAES256, CC_SHA256_DIGEST_LENGTH)];
    NSUInteger macOffset = sealed.length - CC_SHA256_DIGEST_LENGTH;
    NSData *signedPart = [sealed subdataWithRange:NSMakeRange(0, macOffset)];
    NSData *expected = SPLExampleSavedCardsMAC(macKey, storageKey, signedPart);
    // Verify integrity before decrypting.
    if (timingsafe_bcmp(expected.bytes, (const uint8_t *)sealed.bytes + macOffset, CC_SHA256_DIGEST_LENGTH) != 0) {
        return nil;
    }
    NSData *iv = [sealed subdataWithRange:NSMakeRange(1, kCCBlockSizeAES128)];
    NSData *ciphertext = [sealed subdataWithRange:NSMakeRange(headerLength, macOffset - headerLength)];
    NSMutableData *plaintext = [NSMutableData dataWithLength:ciphertext.length];
    size_t written = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                     encKey.bytes, encKey.length, iv.bytes,
                                     ciphertext.bytes, ciphertext.length,
                                     plaintext.mutableBytes, plaintext.length, &written);
    if (status != kCCSuccess) {
        return nil;
    }
    plaintext.length = written;
    return plaintext;
}

NSData * _Nullable SPLExampleSavedCardsEncrypt(NSData *plaintext, NSString *storageKey) {
    return SPLExampleSavedCardsEncryptWithKey(plaintext, storageKey, SPLExampleSavedCardsSharedKey());
}

NSData * _Nullable SPLExampleSavedCardsDecrypt(NSData *sealed, NSString *storageKey) {
    return SPLExampleSavedCardsDecryptWithKey(sealed, storageKey, SPLExampleSavedCardsSharedKey());
}

#pragma mark - Saved list

/// Retain completions and screen code can save at the same time; without this, two saves that
/// read the same list would each write their own copy and one card would be lost.
static NSLock *SPLExampleSavedCardsLock(void) {
    static NSLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        lock = [[NSLock alloc] init];
    });
    return lock;
}

/// The only fields kept for a saved card: what the saved-card screens read, plus the save time.
static NSArray<NSString *> *SPLExampleSavedCardFields(void) {
    return @[@"token", @"payment_method_type", @"card_type", @"last_four_digits", @"month", @"year", @"saved_at"];
}

/// Whether `entry` has the shape the saved-card screens read: a dictionary with a token, text fields
/// holding strings and `month` / `year` holding numbers. Anything else could crash the screens.
/// Exactly four ASCII digits, so nothing longer than the last four can be stored or shown.
static BOOL SPLExampleIsLastFour(id value) {
    if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] != 4) {
        return NO;
    }
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    return [[(NSString *)value stringByTrimmingCharactersInSet:digits] length] == 0;
}

static BOOL SPLExampleIsSavedCard(id entry) {
    if (![entry isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSDictionary *card = entry;
    id token = card[@"token"];
    if (![token isKindOfClass:[NSString class]] || [token length] == 0) {
        return NO;
    }
    for (NSString *key in @[@"payment_method_type", @"card_type", @"last_four_digits"]) {
        id value = card[key];
        if (value && value != [NSNull null] && ![value isKindOfClass:[NSString class]]) {
            return NO;
        }
    }
    for (NSString *key in @[@"month", @"year", @"saved_at"]) {
        id value = card[key];
        if (value && value != [NSNull null] && ![value isKindOfClass:[NSNumber class]]) {
            return NO;
        }
    }
    return YES;
}

/// The readable, current cards stored under `storageKey`; anything else stored there is deleted. Expired, stale
/// and unreadable entries are deleted here rather than waiting for the next save; entries without a save time
/// get `now`. Callers hold `SPLExampleSavedCardsLock()`.
static NSArray<NSDictionary *> *SPLExampleTidiedCards(NSUserDefaults *defaults, NSString *storageKey, NSDate *now, NSData *key) {
    id stored = [defaults objectForKey:storageKey];
    if (!stored) {
        return @[];
    }
    NSData *data = [stored isKindOfClass:[NSData class]] ? SPLExampleSavedCardsDecryptWithKey(stored, storageKey, key) : nil;
    if (!data) {
        // Not data, written with another key (an earlier install), for another environment's slot, as plain
        // text by an earlier build, or damaged: it can never be read, so delete it.
        [defaults removeObjectForKey:storageKey];
        return @[];
    }
    // Unreadable data is treated as an empty list: these are only display copies of cards
    // the backend still holds, so there is nothing to recover. Entries that are not cards are
    // dropped so a damaged list can't crash the app later.
    id list = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![list isKindOfClass:[NSArray class]]) {
        [defaults removeObjectForKey:storageKey];
        return @[];
    }
    NSMutableArray<NSDictionary *> *cards = [NSMutableArray array];
    for (id entry in (NSArray *)list) {
        if (!SPLExampleIsSavedCard(entry)) {
            continue;
        }
        // Keep only the fields the screens read. This also drops JSON null (lists saved before nulls
        // were filtered) and fields that earlier builds stored but nothing shows.
        NSMutableDictionary *card = [NSMutableDictionary dictionary];
        for (NSString *key in SPLExampleSavedCardFields()) {
            id value = entry[key];
            if (value && value != [NSNull null]) {
                card[key] = value;
            }
        }
        if (card[@"last_four_digits"] && !SPLExampleIsLastFour(card[@"last_four_digits"])) {
            [card removeObjectForKey:@"last_four_digits"];
        }
        if (!card[@"saved_at"]) {
            card[@"saved_at"] = @(now.timeIntervalSince1970);
        }
        if (!SPLExampleSavedCardIsExpired(card, now) && !SPLExampleSavedCardIsStale(card, now)) {
            [cards addObject:card];
        }
    }
    if (![cards isEqualToArray:list]) {
        if (cards.count == 0) {
            [defaults removeObjectForKey:storageKey];
        } else {
            NSData *pruned = [NSJSONSerialization dataWithJSONObject:cards options:0 error:nil];
            NSData *prunedSealed = pruned ? SPLExampleSavedCardsEncryptWithKey(pruned, storageKey, key) : nil;
            if (prunedSealed) {
                [defaults setObject:prunedSealed forKey:storageKey];
            }
        }
    }
    return cards;
}

/// This configuration's list, after tidying every list on the device: lists for other backends or environments
/// get the same expiry, age and readability rules, so a configuration the app no longer uses doesn't keep old or
/// unreadable lists around. Callers hold `SPLExampleSavedCardsLock()`.
static NSArray<NSDictionary *> *SPLExampleStoredCards(NSDate *now, NSData *key) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:SPLExampleSavedPaymentMethodsLegacyKey];
    NSString *storageKey = SPLExampleSavedPaymentMethodsStorageKey();
    NSString *prefix = [SPLExampleSavedPaymentMethodsLegacyKey stringByAppendingString:@"."];
    for (NSString *otherKey in defaults.dictionaryRepresentation.allKeys) {
        if (![otherKey isEqualToString:storageKey] && [otherKey hasPrefix:prefix]) {
            SPLExampleTidiedCards(defaults, otherKey, now, key);
        }
    }
    return SPLExampleTidiedCards(defaults, storageKey, now, key);
}

/// Empty, without touching storage, when there is no key (Keychain unavailable).
static NSArray<NSDictionary *> *SPLExampleSavedCardsWithKey(NSData * _Nullable key) {
    if (!key) {
        return @[];
    }
    [SPLExampleSavedCardsLock() lock];
    NSArray<NSDictionary *> *cards = SPLExampleStoredCards([NSDate date], key);
    [SPLExampleSavedCardsLock() unlock];
    return cards;
}

static NSArray<NSDictionary *> *SPLExampleSavedCards(void) {
    return SPLExampleSavedCardsWithKey(SPLExampleSavedCardsSharedKey());
}

NSArray<NSString *> *SPLExampleSavedCardTokensWithKey(NSData * _Nullable key) {
    return [SPLExampleSavedCardsWithKey(key) valueForKey:@"token"];
}

static void SPLExampleSetIfPresent(NSMutableDictionary *card, NSString *key, id value, Class expected) {
    // Retain responses carry JSON null for blank fields such as names, and a malformed response can carry the
    // wrong type; keep only values of the expected type.
    if ([value isKindOfClass:expected]) {
        card[key] = value;
    }
}

/// Adds `card` to the front of the saved list, replacing an entry with the same token.
static BOOL SPLExampleRememberCard(NSDictionary *card) {
    NSData *key = SPLExampleSavedCardsSharedKey();
    if (!key) {
        // Keychain unavailable: save nothing rather than plain text, and leave the stored list alone.
        return NO;
    }
    NSString *token = card[@"token"];
    NSDate *now = [NSDate date];
    NSMutableDictionary *stamped = [card mutableCopy];
    stamped[@"saved_at"] = @(now.timeIntervalSince1970);
    [SPLExampleSavedCardsLock() lock];
    NSMutableArray<NSDictionary *> *cards = [NSMutableArray arrayWithObject:stamped];
    for (NSDictionary *existing in SPLExampleStoredCards(now, key)) {
        if (cards.count >= SPLExampleSavedPaymentMethodsMax) {
            break;
        }
        if (![existing[@"token"] isEqual:token]) {
            [cards addObject:existing];
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:cards options:0 error:nil];
    NSString *storageKey = SPLExampleSavedPaymentMethodsStorageKey();
    // If encryption fails, write nothing rather than plain text.
    NSData *sealed = data ? SPLExampleSavedCardsEncryptWithKey(data, storageKey, key) : nil;
    if (sealed) {
        [[NSUserDefaults standardUserDefaults] setObject:sealed forKey:storageKey];
    }
    [SPLExampleSavedCardsLock() unlock];
    return sealed != nil;
}

BOOL SPLExampleRememberPaymentMethod(RetainPaymentMethod *retained) {
    // The model holds whatever the response decoded to; a token that isn't a non-empty string saves nothing.
    id token = retained.token;
    if (![token isKindOfClass:[NSString class]] || [(NSString *)token length] == 0) {
        return NO;
    }
    NSMutableDictionary *card = [NSMutableDictionary dictionaryWithObject:token forKey:@"token"];
    SPLExampleSetIfPresent(card, @"payment_method_type", retained.paymentMethodType, [NSString class]);
    SPLExampleSetIfPresent(card, @"card_type", retained.cardType, [NSString class]);
    if (SPLExampleIsLastFour(retained.lastFourDigits)) {
        card[@"last_four_digits"] = retained.lastFourDigits;
    }
    SPLExampleSetIfPresent(card, @"month", retained.month, [NSNumber class]);
    SPLExampleSetIfPresent(card, @"year", retained.year, [NSNumber class]);
    return SPLExampleRememberCard(card);
}

FetchPaymentMethodsResponse * _Nullable SPLExampleSavedPaymentMethodsResponse(NSError * _Nullable * _Nullable error) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"payment_methods": SPLExampleSavedCards()}
                                                   options:0
                                                     error:error];
    if (!json) {
        return nil;
    }
    return [FetchPaymentMethodsResponse fromJSONData:json error:error];
}

void SPLExampleClearSavedPaymentMethods(void) {
    [SPLExampleSavedCardsLock() lock];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:SPLExampleSavedPaymentMethodsStorageKey()];
    // Also forget the lists of any other backend or environment the app was built for before.
    NSString *scopePrefix = [SPLExampleSavedPaymentMethodsLegacyKey stringByAppendingString:@"."];
    for (NSString *key in defaults.dictionaryRepresentation.allKeys) {
        if ([key isEqualToString:SPLExampleSavedPaymentMethodsLegacyKey] || [key hasPrefix:scopePrefix]) {
            [defaults removeObjectForKey:key];
        }
    }
    [SPLExampleSavedCardsLock() unlock];
}
