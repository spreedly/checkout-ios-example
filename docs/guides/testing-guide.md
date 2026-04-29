# Testing Guide

How to test your Spreedly iOS SDK integration before going to production.

## Table of Contents

- [Test Environment Setup](#test-environment-setup)
- [Test Card Numbers](#test-card-numbers)
- [Testing Each Payment Flow](#testing-each-payment-flow)
- [Testing Error Scenarios](#testing-error-scenarios)
- [Debugging Tips](#debugging-tips)
- [Production Readiness Checklist](#production-readiness-checklist)
- [Related Documentation](#related-documentation)

---

## Test Environment Setup

### Prerequisites

- A Spreedly test environment with a valid `environmentKey`
- Backend-signed authentication parameters (nonce, signature, timestamp, certificateToken)
- For 3DS Global: a Forter `siteId` configured in your Spreedly environment
- For Stripe APM: a Stripe test publishable key (`pk_test_...`) and a Stripe Payment Intents gateway
- For Braintree APM: a Braintree sandbox gateway configured in Spreedly
- For offsite payments: an offsite gateway (use SPREL for testing)

### Test vs Production

| Setting | Test | Production |
|---------|------|------------|
| Environment key | Spreedly test environment key | Spreedly live environment key |
| Card numbers | Use test cards below | Real cards |
| Stripe key | `pk_test_...` | `pk_live_...` |
| Braintree gateway | Sandbox gateway token | Production gateway token |
| Offsite gateway | SPREL (test) | PayPal, EBANX, etc. |
| Forter portal | Sandbox > Mobile Events Viewer | Production dashboard |
| Charges | Free — no real payments processed | Real charges |

Switch between environments by changing the `environmentKey` in `SpreedlyConfig`. No code changes are required beyond the key.

---

## Test Card Numbers

### Credit Card Tokenization

| Card Brand | Number | CVV | Expiry |
|------------|--------|-----|--------|
| Visa | `4111111111111111` | Any 3 digits | Any future date |
| Mastercard | `5555555555554444` | Any 3 digits | Any future date |
| American Express | `378282246310005` | Any 4 digits | Any future date |
| Discover | `6011111111111117` | Any 3 digits | Any future date |

### 3DS (Forter Global)

| Card Number | 3DS Behavior | Expected Result |
|-------------|--------------|-----------------|
| `4000000000000002` | Requires 3DS challenge | Challenge appears, complete to succeed |
| `4000000000000101` | 3DS authentication fails | Challenge fails with error |
| `4242424242424242` | Frictionless 3DS | No challenge, instant success |

Contact your Spreedly account manager or Forter support for complete test card lists specific to your configuration.

### 3DS (Gateway-Specific)

Use test **amounts** (not card numbers) to trigger different 3DS scenarios:

| Amount | Cents | Scenario |
|--------|-------|----------|
| $30.03 | 3003 | Device fingerprint only (no challenge) |
| $30.04 | 3004 | Device fingerprint + challenge (retained card) |
| $30.05 | 3005 | Direct challenge (no fingerprint) |

Your purchase request must include `attempt_3dsecure: true` for 3DS to trigger.

### EBANX Test Data

| Field | Brazil (Pix/Boleto/NuPay) | Mexico (OXXO) |
|-------|--------------------------|---------------|
| **CPF/Document** | `853.513.468-93` | Not required |
| **Name** | `Ana Santos Araujo` | `Manuela E. Beyer Rocabado` |
| **Email** | `test@test.com` | `test@test.com` |
| **Phone** | `8522847035` | `(040) 577-7687` |
| **Address** | `Rua E, 1040` | `Oyono, 882` |
| **City** | `Maracanaú` | `Hermosillo` |
| **State** | `CE` | `Sonora` |
| **Zip** | `12345` | `48822` |
| **Country** | `BR` | `MX` |
| **Currency** | `BRL` | `MXN` |

---

## Testing Each Payment Flow

### Card Tokenization (Express Checkout)

1. Initialize the SDK with `Spreedly.setup(config:)` using your test environment key
2. Present the `CardFormDropIn` payment form
3. Enter a test card number, future expiry, and any CVV
4. Tap "Pay"
5. Observe the result via Combine:
   - `.completed` with a `token` means success
   - `.failed` with an error indicates a problem — check the error type
   - `.canceled` means the user dismissed the form

```swift
let config = SpreedlyConfig(
    environmentKey: "your-test-environment-key",
    nonce: nonce,
    signature: signature,
    timestamp: timestamp,
    certificateToken: certificateToken
)
Spreedly.setup(config: config)

// Present CardFormDropIn in your SwiftUI view
CardFormDropIn()
```

See [Express Checkout](express-checkout.md) for the full integration.

### Card Tokenization (Custom Payment Forms)

1. Initialize the SDK
2. Add `SPLTextField` fields to your layout for card number, expiry, and CVV
3. Fill in test card data
4. Call `Spreedly.shared().createCreditCard(...)` with the form fields
5. Verify `.completed` via Combine publishers

See [Custom Payment Forms](custom-payment-forms.md) for the full integration.

### Recaching (CVV Update)

1. Initialize the SDK
2. Present `SpreedlyCVVRecachingView` with a saved payment method token
3. Enter any 3-digit CVV
4. Submit and verify `.completed` result

See [Recaching](recaching.md) for configuration details.

### 3DS Global (Forter)

1. Initialize the SDK with `forterSiteId` in your `SpreedlyConfig`
2. Tokenize a card, send the token to your backend to create a purchase
3. If the purchase response includes `sca_authentication`, present `DoChallengeIfNeeded(transactionToken:)`
4. Complete the challenge in the Forter UI
5. Collect results from the 3DS Combine publisher
6. Verify events in the Forter Portal under **Sandbox > Mobile Events Viewer**

See [3DS Global](3ds-global.md) for the full integration.

### 3DS Gateway-Specific

1. Initialize the SDK
2. Tokenize a card, send the token to your backend
3. Create a purchase with `attempt_3dsecure: true` and a test amount (e.g., 3005 cents for a direct challenge)
4. If the response includes `required_action`, use `GatewaySpecific3DSIntegration` to start the lifecycle
5. The challenge opens in an `ASWebAuthenticationSession` (system-managed secure browser)
6. Complete the challenge and verify the result via `GatewaySpecific3DSEvent`

See [3DS Gateway-Specific](3ds-gateway-specific.md) for the full integration.

### Offsite Payments (SPREL Test Gateway)

1. Initialize the SDK
2. Configure with `OffsitePaymentMethodType.sprel`:

```swift
let config = OffsitePaymentConfig(
    paymentMethodType: .sprel,
    email: "test@example.com",
    fullName: "Test User"
)
```

3. Tokenize, purchase via your backend, then present `SpreedlyOffsiteCheckout` with the transaction token
4. Complete checkout on the SPREL test page in `SFSafariViewController`
5. Verify the deep link returns to your app and `PaymentResult` is received

See [Offsite Payments](offsite-payments.md) for EBANX (Pix, Boleto, NuPay, OXXO) and PayPal flows.

### Stripe APM

1. Initialize the SDK
2. Have your backend create a purchase with the Stripe Payment Intents gateway, returning `clientSecret` and `transactionToken`
3. Configure Stripe APM:

```swift
let config = StripeAPMConfig(
    publishableKey: "pk_test_...",
    clientSecret: clientSecret,
    transactionToken: transactionToken,
    merchantDisplayName: "Test Store"
)
```

4. Present the Stripe PaymentSheet via `SpreedlyStripeAPMCheckout.present()`
5. Select an APM (e.g., iDEAL) and complete the test payment
6. Verify `PaymentResult` received via Combine publisher

See [Stripe APM](stripe-apm.md) for the full integration.

### Braintree APM (PayPal / Venmo)

1. Configure a Braintree sandbox gateway in your Spreedly environment
2. Use sandbox credentials for PayPal and Venmo testing
3. Set up `BraintreeCheckoutConfig` with the sandbox gateway token
4. PayPal: use PayPal sandbox buyer accounts for the PayPal checkout flow
5. Venmo: requires the Venmo app installed on the test device, or use Braintree SDK's test mode

See [Braintree APM](braintree-apm.md) for the full integration.

---

## Testing Error Scenarios

### Trigger Common Errors

| Scenario | How to Trigger | Expected Result |
|----------|---------------|-----------------|
| Validation error | Submit with empty card number | `.validationError` with field-level details |
| Invalid card number | Enter `1234567890123456` (fails Luhn) | `.validationError` — Luhn check fails |
| Expired card | Use a past expiry date (e.g., `01/20`) | `.validationError` — expiry in the past |
| Account inactive | Use a real card in test environment | `.accountInactive` error |
| Network error | Disconnect from network before submitting | `.networkError` — no connectivity |
| Invalid credentials | Use wrong `environmentKey` | `.unauthorized` error on API call |

### Verifying Error Handling

1. **Field-level errors**: Clear the card number field and tap Pay. Verify the SDK highlights the invalid field and shows a user-friendly message.
2. **General errors**: Use invalid credentials. Verify `PaymentResult.failed` includes an actionable error type.
3. **Network recovery**: Disconnect, trigger an error, reconnect, and retry. The SDK should recover on the next attempt.

See [Error Handling](error-handling.md) for the full error type catalog and retry guidance.

---

## Debugging Tips

### Enable SDK Logging

Enable debug logging to see SDK activity in the Xcode console:

```swift
Spreedly.setLogLevel(.debug)
```

Use `.debug` during development. Set to `.none` for production. Call this after `Spreedly.initializeSDK()`.

### Verify in the Spreedly Dashboard

After a successful tokenization, the payment method token appears in your Spreedly test dashboard. Verify:

- Token was created
- Card brand and last four digits match
- Additional fields (name, address) were attached

### Xcode Console Filtering

Filter Xcode console output by subsystem `com.spreedly.sdk` to see only SDK logs.

---

## Production Readiness Checklist

Before switching to production:

- [ ] All payment flows tested with test cards and test credentials
- [ ] Error handling verified for validation, network, and auth errors
- [ ] `environmentKey` switched from test to production
- [ ] `logLevel` set to `.none` (or `.error` at most)
- [ ] Stripe APM uses `pk_live_...` (not `pk_test_...`)
- [ ] Braintree gateway switched from sandbox to production
- [ ] Forter portal verified in production (not sandbox)
- [ ] `NSCameraUsageDescription` in Info.plist if using Stripe APM
- [ ] URL schemes and universal links configured for Braintree/offsite returns
- [ ] Screen prevention (`ScreenPreventionSecureView`) wraps payment UI
- [ ] No test card numbers or credentials in source code

See [Go-Live Index](../GO_LIVE_INDEX.md) for the full production readiness checklist.

---

## Testing Blocked-Device Scenarios

When `blockJailbrokenDevices` is enabled, verify the SDK behaves correctly on compromised devices.

### Using the DEBUG Override

The SDK provides `SecurityManager.shared.setOverrideAssessment(_:)` in DEBUG builds. This forces a specific assessment result on the Simulator (where real checks always return `.clean`):

```swift
#if DEBUG
// Force a "compromised" state for testing
let compromised = SecurityAssessment(level: .compromised, signals: ["sandbox_broken", "dylib_injection"])
SecurityManager.shared.setOverrideAssessment(compromised)

// Now initialize with blocking enabled
Spreedly.blockJailbrokenDevices = true
Spreedly.initializeSDK()

// Verify: isDeviceTrusted should be false
assert(!Spreedly.isDeviceTrusted)
assert(Spreedly.initializationError != nil)

// Restore normal behavior
SecurityManager.shared.setOverrideAssessment(nil)
#endif
```

### What to Verify

| Scenario | Expected Behavior |
|----------|-------------------|
| `CardFormDropIn` presented on blocked device | Sheet auto-dismisses, `PaymentResult.failure` published |
| `CVVRecachingView` presented on blocked device | View auto-dismisses, `PaymentResult.failure` published |
| APM `present()` called on blocked device | Returns immediately, `PaymentResult.failure` published |
| 3DS `DoChallengeIfNeeded` on blocked device | Auto-dismisses, `ThreeDSChallengeResult.failure` published |
| `SPLTextField` rendered on blocked device | Renders invisible (zero-size frame) |
| `Spreedly.shared()` on blocked device | Returns non-functional instance; all network calls fail |
| Recovery: call `initializeSDK()` after clearing override | `isDeviceTrusted` returns `true`, SDK operational |

### Telemetry Verification

When a device is blocked, verify these events fire:

- `security_check_completed` — with `is_compromised: true` and the signal names
- `sdk_init_blocked` — with `reason: "device_compromised"`

See [Security — Runtime Integrity](security.md#runtime-integrity) for full details on per-component behavior.

---

## Related Documentation

- [Getting Started](getting-started.md) — Installation and first payment
- [Error Handling](error-handling.md) — Error types and retry guidance
- [Security](security.md) — PCI compliance and screen prevention
- [Troubleshooting](troubleshooting.md) — Common integration issues
