//
//  SavedPaymentMethodsStore.swift
//  SpreedlySDKExample
//

import CryptoKit
import Foundation
import Security

/// The cards this app retained, kept on the device so the saved-card lists have something to show.
///
/// The sample backend no longer lists payment methods: a shared list would show every visitor's cards.
/// Each install keeps only the cards it retained itself, and only the fields
/// the lists display (never a card number or security code), up to `maxCards`.
/// Each backend and environment key gets its own list, so switching configuration never offers a
/// token from another environment. Cards past their expiry month, or saved more than `maxAge` ago,
/// are deleted the next time any list is read or saved; there is no background sweep, so a device where the
/// app is never opened again keeps its lists until the app is deleted.
///
/// The list is encrypted before it is written to `UserDefaults`, with a key kept in the Keychain that is never migrated
/// to another device (`SavedCardsKey`), so a copied preferences file, or a backup restored to another device,
/// can't be read. Each list is tied to its
/// storage key, so a list copied into another environment's slot can't be read either. A list that can't be
/// decrypted is deleted. When the Keychain can't be read (for example before the first unlock after a
/// restart), nothing is read, written or deleted.
enum SavedPaymentMethodsStore {
    /// Where builds before per-environment lists kept every card; removed on first use.
    static let legacyStorageKey = "spreedlySampleApp.savedPaymentMethods"
    static let maxCards = 20
    /// How long a saved card is kept, whatever its expiry date.
    static let maxAge: TimeInterval = 30 * 24 * 60 * 60

    /// The list for the backend and environment this build is configured for.
    static var storageKey: String { storageKey(infoDictionary: Bundle.main.infoDictionary) }

    /// The list key for a configuration: the legacy key plus a short hash of the backend base URL and
    /// environment key, so the stored name does not reveal either.
    static func storageKey(infoDictionary: [String: Any]?) -> String {
        let baseURL = infoDictionary?["SpreedlyBaseURL"] as? String ?? ""
        let environmentKey = infoDictionary?["SpreedlyEnvironmentKey"] as? String ?? ""
        let digest = SHA256.hash(data: Data("\(baseURL)|\(environmentKey)".utf8))
        let scope = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(legacyStorageKey).\(scope)"
    }

    /// Whether the card's expiry month has passed. Cards without an expiry date are kept.
    static func isExpired(
        _ card: SavedCard, now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Bool {
        guard let month = card.month, let year = card.year else { return false }
        let today = calendar.dateComponents([.year, .month], from: now)
        guard let currentYear = today.year, let currentMonth = today.month else { return false }
        return year < currentYear || (year == currentYear && month < currentMonth)
    }

    /// Whether the card was saved more than `maxAge` before `now`. Cards without a save time are not stale;
    /// reading the list stamps them with the read time.
    static func isStale(_ card: SavedCard, now: Date = Date()) -> Bool {
        guard let savedAt = card.savedAt else { return false }
        return now.timeIntervalSince1970 - savedAt > maxAge
    }

    /// Retain completions and screen code can save at the same time; without this, two saves that
    /// read the same list would each write their own copy and one card would be lost.
    private static let lock = NSLock()

    /// The fields the saved-card screens read, and nothing else: token, type, brand, last four and expiry.
    /// Kept in the backend's JSON naming so the stored list decodes straight into the screens' models.
    struct SavedCard: Codable, Equatable {
        let token: String
        let paymentMethodType: String?
        let cardType: String?
        let lastFourDigits: String?
        let month: Int?
        let year: Int?
        /// When this device saved the card, in seconds since 1970. Not shown; drives `maxAge`.
        var savedAt: Double?

        private enum CodingKeys: String, CodingKey {
            case token
            case paymentMethodType = "payment_method_type"
            case cardType = "card_type"
            case lastFourDigits = "last_four_digits"
            case month
            case year
            case savedAt = "saved_at"
        }

        init(
            token: String,
            paymentMethodType: String? = nil,
            cardType: String? = nil,
            lastFourDigits: String? = nil,
            month: Int? = nil,
            year: Int? = nil,
            savedAt: Double? = nil
        ) {
            self.token = token
            self.paymentMethodType = paymentMethodType
            self.cardType = cardType
            self.lastFourDigits = lastFourDigits
            self.month = month
            self.year = year
            self.savedAt = savedAt
        }

        /// Keeps only the fields the saved-card screens read from a retained payment method.
        init(_ retained: RetainPaymentMethod) {
            self.init(
                token: retained.token,
                paymentMethodType: retained.paymentMethodType,
                cardType: retained.cardType,
                lastFourDigits: retained.lastFourDigits,
                month: retained.month,
                year: retained.year
            )
        }
    }

    /// Adds the card to the front of the list, replacing an entry with the same token. Returns whether the card
    /// was saved: `false` when it has no token, or when the Keychain key or encryption isn't available (nothing is
    /// then written, rather than plain text).
    @discardableResult
    static func remember(
        _ card: SavedCard, defaults: UserDefaults = .standard, key: String = storageKey, now: Date = Date(),
        cipherKey: SymmetricKey? = SavedCardsKey.shared
    ) -> Bool {
        guard let cipherKey, var stamped = validated(card) else { return false }
        return lock.withLock {
            stamped.savedAt = now.timeIntervalSince1970
            let others = storedCards(defaults: defaults, key: key, now: now, cipherKey: cipherKey)
                .filter { $0.token != card.token }
            let list = Array(([stamped] + others).prefix(maxCards))
            return save(list, defaults: defaults, key: key, cipherKey: cipherKey)
        }
    }

    /// The card as it may be stored: `nil` without a token, and `lastFourDigits` kept only when it is exactly four
    /// ASCII digits, so nothing longer than the last four can be written or shown.
    static func validated(_ card: SavedCard) -> SavedCard? {
        guard !card.token.isEmpty else { return nil }
        guard let lastFour = card.lastFourDigits, !isLastFour(lastFour) else { return card }
        return SavedCard(
            token: card.token, paymentMethodType: card.paymentMethodType, cardType: card.cardType,
            lastFourDigits: nil, month: card.month, year: card.year, savedAt: card.savedAt
        )
    }

    static func isLastFour(_ value: String) -> Bool {
        value.utf8.count == 4 && value.utf8.allSatisfy { (48...57).contains($0) }
    }

    /// The saved cards, newest first. Expired, stale and unreadable entries are deleted from storage.
    /// Empty, without touching storage, when the Keychain key isn't available.
    static func cards(
        defaults: UserDefaults = .standard, key: String = storageKey, now: Date = Date(),
        cipherKey: SymmetricKey? = SavedCardsKey.shared
    ) -> [SavedCard] {
        guard let cipherKey else { return [] }
        return lock.withLock { storedCards(defaults: defaults, key: key, now: now, cipherKey: cipherKey) }
    }

    /// The list for `key`, after tidying every list on the device: lists for other backends or environments
    /// get the same expiry, age and readability rules, so a configuration the app no longer uses doesn't keep
    /// old or unreadable lists around. Callers hold `lock`.
    private static func storedCards(
        defaults: UserDefaults, key: String, now: Date, cipherKey: SymmetricKey
    ) -> [SavedCard] {
        defaults.removeObject(forKey: legacyStorageKey)
        for otherKey in defaults.dictionaryRepresentation().keys
        where otherKey != key && otherKey.hasPrefix(legacyStorageKey + ".") {
            _ = tidiedCards(defaults: defaults, key: otherKey, now: now, cipherKey: cipherKey)
        }
        return tidiedCards(defaults: defaults, key: key, now: now, cipherKey: cipherKey)
    }

    /// The readable, current cards stored under `key`; anything else stored there is deleted. Callers hold `lock`.
    private static func tidiedCards(
        defaults: UserDefaults, key: String, now: Date, cipherKey: SymmetricKey
    ) -> [SavedCard] {
        guard let stored = defaults.object(forKey: key) else { return [] }
        guard let sealed = stored as? Data, let data = decrypt(sealed, storageKey: key, cipherKey: cipherKey) else {
            // Not data, written with another key (an earlier install), for another environment's slot, as plain
            // text by an earlier build, or damaged: it can never be read, so delete it.
            defaults.removeObject(forKey: key)
            return []
        }
        // Unreadable entries are skipped: these are only display copies of cards the backend still
        // holds, so there is nothing to recover, and one bad entry shouldn't hide the others.
        guard let entries = try? JSONDecoder().decode([LossyCard].self, from: data) else {
            // Not a list at all: nothing in it can be shown, so delete it now.
            defaults.removeObject(forKey: key)
            return []
        }
        let readable = entries.compactMap { $0.card.flatMap(validated) }
        let kept = readable
            .map { card -> SavedCard in
                var card = card
                card.savedAt = card.savedAt ?? now.timeIntervalSince1970
                return card
            }
            .filter { !isExpired($0, now: now) && !isStale($0, now: now) }
        // Write back whenever the stored bytes differ from what is kept: that deletes expired, stale and
        // unreadable entries now, stamps missing save times, and drops fields earlier builds stored.
        if kept.isEmpty {
            defaults.removeObject(forKey: key)
        } else if encode(kept) != data {
            save(kept, defaults: defaults, key: key, cipherKey: cipherKey)
        }
        return kept
    }

    /// The saved cards in the shape the saved-card screens already read.
    static func response(
        defaults: UserDefaults = .standard, key: String = storageKey
    ) throws -> FetchPaymentMethodsResponse {
        let data = try JSONEncoder().encode(["payment_methods": cards(defaults: defaults, key: key)])
        return try JSONDecoder().decode(FetchPaymentMethodsResponse.self, from: data)
    }

    /// Forgets every saved card on the device: this configuration's list and those of any other
    /// backend or environment the app was built for before. Used by tests to start clean; the app offers
    /// no clear option, so in use the lists go when the app is deleted.
    static func clear(defaults: UserDefaults = .standard, key: String = storageKey) {
        lock.withLock {
            defaults.removeObject(forKey: key)
            for storedKey in defaults.dictionaryRepresentation().keys
            where storedKey == legacyStorageKey || storedKey.hasPrefix(legacyStorageKey + ".") {
                defaults.removeObject(forKey: storedKey)
            }
        }
    }

    @discardableResult
    private static func save(
        _ cards: [SavedCard], defaults: UserDefaults, key: String, cipherKey: SymmetricKey
    ) -> Bool {
        // If encryption fails, write nothing rather than plain text.
        guard let data = encode(cards),
              let sealed = encrypt(data, storageKey: key, cipherKey: cipherKey) else { return false }
        defaults.set(sealed, forKey: key)
        return true
    }

    /// The list bytes as stored for `storageKey`, or `nil` when there is no key. The result only reads back in the
    /// slot it was written for.
    static func encrypt(
        _ plaintext: Data, storageKey: String, cipherKey: SymmetricKey? = SavedCardsKey.shared
    ) -> Data? {
        guard let cipherKey else { return nil }
        return try? AES.GCM.seal(plaintext, using: cipherKey, authenticating: Data(storageKey.utf8)).combined
    }

    /// The list bytes from data stored for `storageKey`, or `nil` when there is no key, or the data wasn't
    /// sealed with this key for this storage key.
    static func decrypt(_ sealed: Data, storageKey: String, cipherKey: SymmetricKey? = SavedCardsKey.shared) -> Data? {
        guard let cipherKey, let box = try? AES.GCM.SealedBox(combined: sealed) else { return nil }
        return try? AES.GCM.open(box, using: cipherKey, authenticating: Data(storageKey.utf8))
    }

    /// Sorted keys so the same list always encodes to the same bytes.
    private static func encode(_ cards: [SavedCard]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(cards)
    }

    /// Decodes one list entry, or `nil` when it doesn't have the card shape.
    private struct LossyCard: Decodable {
        let card: SavedCard?

        init(from decoder: Decoder) throws {
            card = try? SavedCard(from: decoder)
        }
    }
}

/// The key that encrypts the saved-card list, kept in the Keychain. It can be restored only to the device that
/// created it, never migrated to another device.
///
/// Deleting the app removes its `UserDefaults` but not its Keychain items. A marker in `UserDefaults`
/// records that the key exists for this install; when the marker is missing (first install, or deleting and
/// reinstalling the app), any key left behind is deleted and a new one made, so the earlier install's lists
/// can't be read. A backup restored to the same device is expected to bring back both the marker and the key, so
/// its list stays readable (Apple's `ThisDeviceOnly` behaviour; not tested on a device).
///
/// Apart from that first-use reset, only a missing key or one of the wrong length is replaced. Any other
/// Keychain error (for example the device hasn't been unlocked since a restart) changes nothing, even on first
/// use, and yields `nil`, so no saved card is lost; the next use tries again.
enum SavedCardsKey {
    static let service = "com.spreedly.sampleapp.savedPaymentMethods"
    static let account = "listEncryptionKey"
    /// Not under `SavedPaymentMethodsStore.legacyStorageKey`, so clearing saved cards keeps it.
    static let installMarkerKey = "spreedlySampleAppSavedCardsKeyReady"
    static let keyLength = 32

    enum ReadResult: Equatable {
        case found(Data)
        case notFound
        case failed(OSStatus)
    }

    /// This launch's key, or `nil` while the Keychain can't be read. Only a loaded key is kept, so a
    /// temporary error is retried on the next use.
    static var shared: SymmetricKey? { cache.key { loadOrCreate(defaults: .standard, account: account) } }

    private static let cache = KeyCache()

    static func loadOrCreate(
        defaults: UserDefaults, account: String, read: (String) -> ReadResult = SavedCardsKey.read(account:)
    ) -> SymmetricKey? {
        let stored = read(account)
        if case .failed = stored {
            // Temporary (device locked since restart) or unexpected: change nothing, keep the key and the saved
            // cards, and try again on the next use.
            return nil
        }
        if !defaults.bool(forKey: installMarkerKey) {
            // First use on this install: a key left by an earlier install must not decrypt anything.
            delete(account: account)
            return create(defaults: defaults, account: account)
        }
        if case .found(let data) = stored, data.count == keyLength {
            return SymmetricKey(data: data)
        }
        // Missing, or not a key this app wrote: replace it. Anything stored with the old key is unreadable
        // anyway and is deleted when the list is next read.
        delete(account: account)
        return create(defaults: defaults, account: account)
    }

    private static func create(defaults: UserDefaults, account: String) -> SymmetricKey? {
        let key = SymmetricKey(size: .bits256)
        let bytes = key.withUnsafeBytes { Data($0) }
        guard add(bytes, account: account) else { return nil }
        defaults.set(true, forKey: installMarkerKey)
        return key
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read(account: String) -> ReadResult {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return .failed(errSecDecode) }
            return .found(data)
        case errSecItemNotFound:
            return .notFound
        default:
            return .failed(status)
        }
    }

    private static func add(_ bytes: Data, account: String) -> Bool {
        var query = baseQuery(account: account)
        query[kSecValueData as String] = bytes
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    /// Holds the loaded key; `load` runs under the lock until it succeeds.
    private final class KeyCache: @unchecked Sendable {
        private let lock = NSLock()
        private var loaded: SymmetricKey?

        func key(_ load: () -> SymmetricKey?) -> SymmetricKey? {
            lock.withLock {
                if let loaded { return loaded }
                loaded = load()
                return loaded
            }
        }
    }
}
