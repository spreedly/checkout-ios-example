# Privacy and Data Handling - Spreedly iOS SDK

Privacy requirements and data handling for the Spreedly iOS SDK. The SDK processes payment card data in memory only -- nothing is stored on disk -- and transmits it to Spreedly over TLS for tokenization.

## Data Handling Principles

### Payment Card Data
- **Processing**: Payment card data is processed in memory only
- **Storage**: Card data is never stored on the device or in persistent storage
- **Transmission**: Card data is sent to Spreedly for tokenization via TLS (Transport Layer Security) encrypted connections

### Data Collection
- **Payment data**: The SDK processes payment card data in memory for tokenization only
- **Operational telemetry**: The SDK collects non-personal operational data for reliability monitoring, including: SDK version, OS version, device region, carrier name, ephemeral session ID, environment key (identifies the merchant account), API endpoint paths, HTTP methods, response status codes, error types, flow durations, and payment method types. Field-level interaction events (focus/blur on form fields) are also collected for form usability monitoring. No card numbers, CVVs, expiry dates, or PII are included in telemetry.
- **Telemetry destination**: Operational telemetry is sent to **Datadog** when configured. Telemetry is disabled if no Datadog client token is provided.
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
- **Datadog**: Non-sensitive operational telemetry (SDK version, OS version, region, carrier, session ID, flow success/failure events) is sent to Datadog for SDK reliability monitoring. No card data, tokens, or PII is included in telemetry payloads

## iOS-Specific Requirements

### Privacy Manifest (PrivacyInfo.xcprivacy)

The SDK includes a `PrivacyInfo.xcprivacy` file that declares:
- **NSPrivacyCollectedDataTypes**: Empty array (no data collection)
- **NSPrivacyTracking**: Not used
- **NSPrivacyTrackingDomains**: Not used
- **NSPrivacyAccessedAPITypes**: Declares only required APIs for core functionality

This manifest is automatically included in the SDK distribution and ensures compliance with Apple's App Privacy requirements.

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
- That card data is not stored on the device
- That data transmission is encrypted
- That the SDK collects non-personal operational telemetry (device type, OS version, region) for reliability monitoring via Datadog
- That no user behavior tracking, profiling, or advertising analytics is performed by the SDK

## Related Documentation

- [Security](security.md) -- Screen prevention and PCI compliance
- [Getting Started](getting-started.md) -- Installation and initialization
- [Telemetry Spec](../development/TELEMETRY_SPEC.md) -- Full telemetry event catalog and data attributes
- [Platform Privacy Requirements](../development/PLATFORM_PRIVACY_REQUIREMENTS.md) -- iOS-specific privacy manifest details
- [Spreedly Privacy Policy](https://www.spreedly.com/privacy)
