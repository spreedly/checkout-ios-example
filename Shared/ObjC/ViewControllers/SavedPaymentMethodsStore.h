//
//  SavedPaymentMethodsStore.h
//  SpreedlySDKExampleObjectiveC
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

@class RetainPaymentMethod;
@class FetchPaymentMethodsResponse;

NS_ASSUME_NONNULL_BEGIN

/// The cards this app retained, kept on the device so the saved-card lists have something to show.
///
/// The sample backend no longer lists payment methods: a shared list would show every visitor's cards.
/// Each install keeps only the cards it retained itself, and only the fields
/// the lists display (never a card number or security code), up to `SPLExampleSavedPaymentMethodsMax`.
/// Each backend and environment key gets its own list. Cards past their expiry month, or saved more than
/// `SPLExampleSavedPaymentMethodsMaxAge` ago, are deleted the next time any list is read or saved; there is
/// no background sweep, so a device where the app is never opened again keeps its lists until the app is deleted.
/// The list's key name and JSON fields match the Swift example; each app encrypts its own list in its own format.
FOUNDATION_EXPORT const NSUInteger SPLExampleSavedPaymentMethodsMax;

/// How long a saved card is kept, whatever its expiry date (30 days).
FOUNDATION_EXPORT const NSTimeInterval SPLExampleSavedPaymentMethodsMaxAge;

/// Where builds before per-environment lists kept every card; removed on first use.
FOUNDATION_EXPORT NSString *const SPLExampleSavedPaymentMethodsLegacyKey;

/// The list key for the configuration in `info` (`SpreedlyBaseURL`, `SpreedlyEnvironmentKey`): the legacy
/// key plus a short hash of both, so the stored name does not reveal either.
FOUNDATION_EXPORT NSString *SPLExampleSavedPaymentMethodsStorageKeyForInfo(NSDictionary * _Nullable info);

/// The list key for this build's configuration.
FOUNDATION_EXPORT NSString *SPLExampleSavedPaymentMethodsStorageKey(void);

/// Whether the card's expiry month is before `now`'s month. Cards without an expiry date are kept.
FOUNDATION_EXPORT BOOL SPLExampleSavedCardIsExpired(NSDictionary *card, NSDate *now);

/// Whether the card was saved more than `SPLExampleSavedPaymentMethodsMaxAge` before `now`.
/// Cards without a save time are not stale; reading the list stamps them with the read time.
FOUNDATION_EXPORT BOOL SPLExampleSavedCardIsStale(NSDictionary *card, NSDate *now);

/// Adds the retained card to the front of the list, replacing an entry with the same token. Returns NO, and saves
/// nothing, when the card has no token or the Keychain key or encryption isn't available.
FOUNDATION_EXPORT BOOL SPLExampleRememberPaymentMethod(RetainPaymentMethod *retained);

/// The saved cards, newest first, in the shape the saved-card screens already read.
FOUNDATION_EXPORT FetchPaymentMethodsResponse * _Nullable SPLExampleSavedPaymentMethodsResponse(NSError * _Nullable * _Nullable error);

/// The saved list is encrypted before it is written to UserDefaults, with a key kept in the Keychain that never
/// moves to another device, and tied to its storage key. When the install marker is missing (first install, or
/// deleting and reinstalling the app) a new key is made; a list that can't be decrypted is deleted. When the
/// Keychain can't be read, nothing is read, written or deleted.
FOUNDATION_EXPORT NSString *const SPLExampleSavedCardsKeyAccount;
/// UserDefaults marker for "the key exists for this install"; missing on first install or after delete and reinstall.
FOUNDATION_EXPORT NSString *const SPLExampleSavedCardsKeyInstallMarker;

/// Reads the key stored for `account`; sets `status` to the Keychain result (`errSecItemNotFound` when missing).
typedef NSData * _Nullable (^SPLExampleSavedCardsKeyReader)(NSString *account, OSStatus *status);

/// Loads this install's key from the Keychain `account`, or makes one. Deletes a key left by an earlier
/// install when `defaults` has no install marker, and replaces a missing or malformed key. Returns nil, and
/// changes nothing (not even on first use), when the Keychain returns any other error.
FOUNDATION_EXPORT NSData * _Nullable SPLExampleSavedCardsLoadOrCreateKey(NSUserDefaults *defaults, NSString *account);
/// Same, reading the stored key with `reader` (tests use it to simulate Keychain errors).
FOUNDATION_EXPORT NSData * _Nullable SPLExampleSavedCardsLoadOrCreateKeyWithReader(NSUserDefaults *defaults, NSString *account,
                                                                                   SPLExampleSavedCardsKeyReader reader);
FOUNDATION_EXPORT NSData * _Nullable SPLExampleSavedCardsReadKey(NSString *account, OSStatus * _Nullable status);
FOUNDATION_EXPORT void SPLExampleSavedCardsDeleteKey(NSString *account);

/// Encrypts / decrypts list bytes for `storageKey` with this launch's key. Nil when there is no key, or the
/// data wasn't sealed with this key for this storage key.
FOUNDATION_EXPORT NSData * _Nullable SPLExampleSavedCardsEncrypt(NSData *plaintext, NSString *storageKey);
FOUNDATION_EXPORT NSData * _Nullable SPLExampleSavedCardsDecrypt(NSData *sealed, NSString *storageKey);
FOUNDATION_EXPORT NSData * _Nullable SPLExampleSavedCardsEncryptWithKey(NSData *plaintext, NSString *storageKey, NSData * _Nullable key);
FOUNDATION_EXPORT NSData * _Nullable SPLExampleSavedCardsDecryptWithKey(NSData *sealed, NSString *storageKey, NSData * _Nullable key);

/// The saved tokens read with `key`; empty and storage untouched when `key` is nil. For tests.
FOUNDATION_EXPORT NSArray<NSString *> *SPLExampleSavedCardTokensWithKey(NSData * _Nullable key);

/// Forgets every saved card on the device, for this configuration and any other the app was built for.
/// Used by tests to start clean; the app offers no clear option, so in use the lists go when the app is deleted.
FOUNDATION_EXPORT void SPLExampleClearSavedPaymentMethods(void);

NS_ASSUME_NONNULL_END
