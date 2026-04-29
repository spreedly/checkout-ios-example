# Go-Live Index (iOS SDK)

Main entry point for **production readiness** docs. Each link points to the source of truth, so steps are not repeated on this page.

**Scope:** Merchant integration with the Spreedly iOS SDK (XCFrameworks via SPM or CocoaPods). It does **not** cover Spreedly Core / backend operations, Android, Web, or React Native SDKs.

## Where to start

| Audience | Start here |
|----------|------------|
| Integration engineers | [Getting Started](guides/getting-started.md), [Production Integration Checklist](guides/getting-started.md#production-integration-checklist) |
| Customer success / support | [Customer Troubleshooting](guides/error-handling.md#customer-troubleshooting), [Privacy](guides/privacy.md) |

## Section guide

| Section | Topic | Document |
|---------|-------|----------|
| 1 | Customer integration docs | [Getting Started](guides/getting-started.md), [Production Integration Checklist](guides/getting-started.md#production-integration-checklist) |
| 2 | Customer troubleshooting | [Error Handling -- Customer Troubleshooting](guides/error-handling.md#customer-troubleshooting) |

## Go-live readiness checklist

| Item | Verify | Status |
|------|--------|--------|
| SDK installed | SPM or CocoaPods dependency resolved and building | `[ ]` |
| Backend signing | Your server mints fresh signed init params per session | `[ ]` |
| Customer docs reviewed | [Production Integration Checklist](guides/getting-started.md#production-integration-checklist) | `[ ]` |
| Error handling | All `PaymentResult` states handled with user-friendly messages | `[ ]` |
| Support playbook | [Customer Troubleshooting](guides/error-handling.md#customer-troubleshooting) | `[ ]` |
| Legal / privacy | [Privacy](guides/privacy.md) disclosed in your privacy policy | `[ ]` |

## See also

- [Documentation index](README.md)
- [Changelog](CHANGELOG.md)
