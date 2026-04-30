# Spreedly iOS SDK Docs

**Go-Live Index:** For a launch checklist and team-specific starting points, see [GO_LIVE_INDEX.md](GO_LIVE_INDEX.md).

## Integration Guides

| Guide | Description |
|-------|-------------|
| [Getting Started](guides/getting-started.md) | Install the SDK, set it up, and run a first payment |
| [Express Checkout](guides/express-checkout.md) | Use the ready-made CardFormDropIn payment form |
| [Custom Payment Forms](guides/custom-payment-forms.md) | Build your own payment form UI with SPLTextField |
| [Theme and Styling](guides/theme-and-styling.md) | Colors, typography, dark mode |
| [Error Handling](guides/error-handling.md) | Error types, retry guidance, and user-friendly messages |
| [Security](guides/security.md) | Screen prevention, PCI compliance |
| [Recaching](guides/recaching.md) | CVV recaching for saved payment methods |
| [Offsite Payments](guides/offsite-payments.md) | PayPal, Sprel via Safari |
| [EBANX APM](guides/ebanx-apm.md) | Pix, Boleto, OXXO, NuPay via EBANX |
| [Stripe APM](guides/stripe-apm.md) | iDEAL, Bancontact, EPS, P24, SEPA via Stripe |
| [Braintree APM](guides/braintree-apm.md) | PayPal and Venmo via Braintree |
| [3DS Global](guides/3ds-global.md) | Forter-based 3D Secure authentication |
| [3DS Gateway-Specific](guides/3ds-gateway-specific.md) | Gateway-managed 3DS authentication (e.g. Worldpay) |
| [Objective-C](guides/objective-c.md) | Integrate from Objective-C using delegates and wrappers |
| [Privacy](guides/privacy.md) | Privacy requirements and data handling practices |
| [Troubleshooting](guides/troubleshooting.md) | Common issues and solutions |
| [Testing Guide](guides/testing-guide.md) | Test cards, environment setup, and flow-by-flow testing |

## Development

| Document | Description |
|----------|-------------|
| [Contributing](development/CONTRIBUTING.md) | Setup, development workflow, coding standards, and PR process |
| [Release Process](development/RELEASE_PROCESS.md) | Full release steps from start to finish |
| [Distribution](development/DISTRIBUTION.md) | How SPM and CocoaPods releases are published |
| [Versioning](development/VERSIONING.md) | How semantic versioning is used in this SDK |
| [Package Verification](development/PACKAGE_VERIFICATION.md) | Artifact checksums and verification |
| [Workflow Improvements](development/WORKFLOW_IMPROVEMENTS.md) | GitHub Actions workflows, run order, and CI/CD reference |
| [TestFlight Distribution](development/TESTFLIGHT_DISTRIBUTION.md) | Xcode Cloud setup and TestFlight distribution |
| [Git Hooks](development/GIT_HOOKS.md) | Commit message hooks and setup |
| [Lint Setup](development/LINT_SETUP.md) | SwiftLint configuration and local/CI usage |
| [Pull Request Guidelines](development/PULL_REQUEST_GUIDELINES.md) | PR process, review, and branch protection |
| [Secret Scanning](development/SECRET_SCANNING.md) | Credential safety and secret management |
| [Vulnerability Scanning](development/VULNERABILITY_SCANNING.md) | CodeQL, DAST, and dependency security scanning |
| [Developer Quick Reference](development/DEVELOPER_QUICK_REFERENCE.md) | PR checklist and required CI checks |
| [SDK Technical Specification](development/SDK_TECHNICAL_SPECIFICATION.md) | Architecture, modules, and public API details |
| [Architecture](development/ARCHITECTURE.md) | System diagram, data flow, and module boundaries |
| [Telemetry Spec](development/TELEMETRY_SPEC.md) | Event list, Datadog integration, and production monitoring guidance |
| [Datadog Integration](development/DATADOG_INTEGRATION.md) | Datadog setup, configuration, what gets logged, and troubleshooting |
| [Testing Guide (Dev)](development/TESTING_GUIDE.md) | How to run tests, coverage thresholds, conventions, and CI integration |
| [Platform Privacy](development/PLATFORM_PRIVACY_REQUIREMENTS.md) | Privacy requirements and data handling |
| [Forter3DS Distribution Proposal](development/FORTER3DS_DISTRIBUTION_PROPOSAL.md) | Forter3DS framework distribution approach |
| [CocoaPods Forter3DS Solution](development/COCOAPODS_FORTER3DS_SOLUTION.md) | CocoaPods integration for Forter3DS |

### Flow Diagrams

| Document | Description |
|----------|-------------|
| [3DS Global Flow](development/3DS_GLOBAL_FLOW.md) | Forter-based 3DS flow from status to challenge to final result |
| [3DS Gateway-Specific Flow](development/3DS_GATEWAY_SPECIFIC_FLOW.md) | Gateway-managed 3DS flow with fingerprinting, challenge, and completion |
| [Card Tokenization Flow](development/CARD_TOKENIZATION_FLOW.md) | How card tokenization works, including security and result handling |
| [Recaching Flow](development/RECACHING_FLOW.md) | How CVV recaching works from validation to final result |
| [Stripe Flow](development/STRIPE_FLOW.md) | Stripe APM flow diagrams |
| [Braintree Flow](development/BRAINTREE_FLOW.md) | Braintree PayPal/Venmo flow diagrams |
| [EBANX Flow](development/EBANX_FLOW.md) | EBANX offsite payment flow diagrams |
| [Offsite Flow](development/OFFSITE_FLOW.md) | PayPal/Sprel offsite flow diagrams |
| [Braintree Universal Link Flow](development/BRAINTREE_UNIVERSAL_LINK_FLOW.md) | Return URL handling: universal links vs custom URL schemes |
| [Gateway-Specific Flowcharts](GATEWAY_SPECIFIC_FLOWCHARTS.md) | Combined Mermaid flowchart reference for gateway-specific flows |

## Other

- [Go-Live Index](GO_LIVE_INDEX.md)
- [Changelog](CHANGELOG.md)
- [Root README](../README.md)
