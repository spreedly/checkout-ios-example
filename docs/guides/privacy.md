# Privacy and Data Handling - Spreedly iOS SDK

Privacy requirements and data handling for the Spreedly iOS SDK. The SDK processes payment card
data in memory only — nothing is stored on disk — and transmits it to Spreedly over TLS for
tokenization.

| | |
|---|---|
| **Audience** | Merchants completing an App Store privacy disclosure or a security review |
| **Use this when** | Filling in App Privacy answers, or answering "what does the SDK collect?" |
| **Use something else when** | Implementing jailbreak gating or screen prevention → [Security](security.md) |
| **Requires** | Any SDK version |

## Data Handling Principles

### Payment Card Data
- **Processing**: Payment card data is processed in memory only
- **Storage**: Card data is never stored on the device or in persistent storage
- **Transmission**: Card data is sent to Spreedly for tokenization via TLS (Transport Layer Security) encrypted connections

### Data Collection
- **Payment data**: The SDK processes payment card data in memory for tokenization only
- **Operational telemetry**: The SDK collects non-personal operational data for reliability monitoring, including: SDK version (and, in React Native apps, the React Native and Spreedly React Native package versions), OS version, device region, ephemeral session ID, environment key (identifies the merchant account), API endpoint paths, HTTP methods, response status codes, error types, flow durations, and payment method types. Field-level interaction events (focus/blur on form fields) are also collected for form usability monitoring. No card numbers, CVVs, expiry dates, or PII are included in telemetry.
- **Telemetry destination**: Operational telemetry is sent to **Datadog**. It is on by default in the published SDK frameworks. You can reduce it or turn it off with `Spreedly.configureLogging(_:)`; see [Telemetry and opting out](getting-started.md#telemetry-and-opting-out).
- **Purpose**: Payment data is used for tokenization. Telemetry data is used to monitor SDK health, detect failures, measure latency, and improve reliability.

### Persistent Storage
- **None**: The SDK does not use persistent storage for card data
- **Memory Only**: All card data operations occur in memory and are cleared immediately after processing

### User Tracking
- **No advertising or profiling**: The SDK does not perform user profiling, advertising analytics, or cross-app tracking
- **Form interaction telemetry**: The SDK records field focus/blur events on payment form fields for usability monitoring. These events contain the field type (e.g. "card_number", "cvv") and the action ("focus"/"blur") but never the field contents.
- **Ephemeral session IDs**: Operational telemetry uses a random UUID generated per SDK initialization. This ID is not tied to user identity and is not persisted across app launches

### Third-Party Sharing
- **Spreedly**: Card data is shared exclusively with Spreedly for tokenization. No card data is sent to any other party
- **Apple Pay**: With `SpreedlyApplePay`, the encrypted Apple Pay payment and any contact fields you request (name, email, phone, address) are sent to Spreedly with the payment. A saved address you pass as `billingContact` or `shippingContact` goes to Apple only, to prefill the sheet; the SDK doesn't log it or send it to Spreedly. See [Apple Pay — App Store Privacy Label](apple-pay.md#app-store-privacy-label) for what to declare
- **Datadog**: Non-sensitive operational telemetry (SDK version, OS version, region, session ID, environment key, flow success/failure events) is sent to Datadog for SDK reliability monitoring, unless you turn it off. No card data, tokens, or PII is included in telemetry payloads

## iOS-Specific Requirements

### Privacy Manifests (PrivacyInfo.xcprivacy)

Every Spreedly framework ships its own `PrivacyInfo.xcprivacy` inside the framework bundle. You do not add it to your app. Each manifest covers the framework's own code and the third-party libraries compiled into it, so a module's declarations appear in your app's privacy report only if you add that module.

All manifests declare `NSPrivacyTracking` as `false` with no tracking domains: the SDK does not perform tracking as defined by Apple's [App Tracking Transparency](https://developer.apple.com/app-store/user-privacy-and-data-use/).

| Module | Required-reason APIs declared | Data types declared |
|---|---|---|
| `SpreedlySecurity` | None | None |
| `SpreedlyCore` | System boot time (`35F9.1`), UserDefaults (`CA92.1`, from the bundled Datadog library), file timestamp (`C617.1`, from the bundled Datadog library) | Payment info, name, email address, phone number, physical address (linked to the user, not used for tracking, purpose: app functionality); performance data, other diagnostic data and product interaction (not linked) |
| `SpreedlyUI` | System boot time (`35F9.1`) | None |
| `SpreedlyStripeAPM` | UserDefaults (`CA92.1`) | Payment info and product interaction, from the bundled Stripe libraries |
| `SpreedlyStripeRadar` | UserDefaults (`CA92.1`) | Product interaction, from the bundled Stripe libraries |
| `SpreedlyBraintree` | UserDefaults (`CA92.1`) | Payment info, name, physical address, device ID, performance data, coarse location and precise location, from the bundled Braintree and PPRiskMagnes libraries. PPRiskMagnes declares location and performance data as linked to the user |
| `SpreedlyClickToPay` | None | None |
| `SpreedlyApplePay` | None | None. The Apple Pay token and any contact fields you request go to Spreedly through `SpreedlyCore`, which declares them |

The data types under `SpreedlyCore` are the fields the SDK sends to Spreedly to tokenize a payment method: card or bank account details, the name, email, phone number and billing or shipping address you pass in.

The operational telemetry described above (SDK version, region, ephemeral session ID, etc.) is **not linked to the user's identity** and is used only for SDK reliability monitoring. It is declared, because the events are retained by Datadog: flow and error events as other diagnostic data, and field focus and blur events as product interaction.

Your app's own App Store privacy disclosure stays your responsibility. Apple combines the SDK manifests with your app's, but you still answer for payment-related data your **app** collects or sends to Spreedly, such as card data for tokenization, in your own privacy disclosures.

### Platform Compliance

The SDK complies with:
- Apple's App Privacy requirements
- iOS App Store privacy guidelines
- Payment Card Industry Data Security Standard (PCI DSS) requirements
- General Data Protection Regulation (GDPR) requirements

## Data Transmission Security

All data transmission to Spreedly:
- Uses TLS 1.2 or higher
- Encrypts card data in transit
- Uses secure, authenticated endpoints
- Validates SSL certificates
- Does not transmit unencrypted card data

## Developer Responsibilities

When integrating the Spreedly iOS SDK:
1. **Do not store card data**: Never store card data in your app's persistent storage
2. **Use secure transmission**: Ensure your app uses secure network connections
3. **Follow PCI DSS guidelines**: Implement appropriate security measures in your application
4. **Respect user privacy**: Do not collect additional user data beyond what is necessary for payment processing

## Privacy Policy Integration

When using the Spreedly iOS SDK, you should include in your app's privacy policy:
- That payment card data is processed by Spreedly for tokenization
- If you use Apple Pay: that the Apple Pay payment and any contact details you request are sent to Spreedly to process the payment
- That card data is not stored on the device
- That data transmission is encrypted
- That the SDK collects non-personal operational telemetry (SDK version, OS version, region, your environment key) for reliability monitoring via Datadog, unless you turn it off
- That no user behavior tracking, profiling, or advertising analytics is performed by the SDK

## Related Documentation

- [Security](security.md) -- Screen prevention and PCI compliance
- [Getting Started](getting-started.md) -- Installation and initialization
- [Apple Pay](apple-pay.md#app-store-privacy-label) -- What Apple Pay adds to your App Store privacy label
- [Spreedly Privacy Policy](https://www.spreedly.com/privacy)
