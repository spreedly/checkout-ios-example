# EBANX Integration - Spreedly iOS SDK

Accept Latin American payment methods including Pix, Boleto, OXXO, and NuPay.

**Estimated integration time:** ~15 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Supported EBANX Payment Types](#supported-ebanx-payment-types)
3. [Prerequisites](#prerequisites)
4. [SDK Methods](#sdk-methods)
5. [Flow](#flow)
6. [Important Notes](#important-notes)
7. [EBANX Purchase API (Backend)](#ebanx-purchase-api-backend)
8. [SwiftUI Integration](#swiftui-integration)
9. [UIKit Integration](#uikit-integration)
10. [Objective-C Integration](#objective-c-integration)
11. [EBANX Config Reference](#ebanx-config-reference)
12. [EBANX Result States](#ebanx-result-states)
13. [Related Documentation](#related-documentation)

---

## Introduction

EBANX payments (Pix, Boleto Bancario, OXXO, NuPay) use the same offsite flow as other providers, with two key differences:

1. **Provider-specific `OffsitePaymentConfig`** — Different EBANX providers require different fields (e.g., OXXO does not require `documentId`; Pix, Boleto, and NuPay require it).
2. **Gateway-specific fields in the purchase API** — The purchase call includes `gateway_specific_fields.ebanx.document` for taxpayer identification. This is a merchant backend concern, not an SDK call.

---

## Supported EBANX Payment Types

| Type | Enum | Country | Required Fields |
|------|------|---------|-----------------|
| Pix | `.pix` | Brazil | email, fullName, documentId, country("BR"), phoneNumber, address1, city, state, zip |
| Boleto | `.boletoBancario` | Brazil | email, fullName, documentId, country("BR"), phoneNumber, address1, city, state, zip |
| OXXO | `.oxxo` | Mexico | email, fullName, country("MX"), phoneNumber, address1, city, state, zip (NO documentId) |
| NuPay | `.nupay` | Brazil | email, fullName, documentId, country("BR"), phoneNumber |

---

## Prerequisites

Before integrating EBANX payments:

- Complete [getting-started.md](getting-started.md) — installation, `Spreedly.setup(config:)`, and credential management
- Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`)
- Register a custom URL scheme in `Info.plist` (see [Custom URL Scheme Setup](offsite-payments.md#custom-url-scheme-setup) in the Offsite Payment Guide)
- Understand the offsite payment flow (see [offsite-payments.md](offsite-payments.md))

> **Important:** Fetch signature parameters from your backend and call `Spreedly.setup(config:)` before calling `submitOffsitePayment()`.

---

## SDK Methods

The SDK methods are the same as standard offsite payments:

| # | Method | Module | Purpose |
|---|--------|--------|---------|
| 1 | `submitOffsitePayment(config:)` | SpreedlyCore | Create EBANX payment method token |
| 2 | `subscribeToPaymentResults` | SpreedlyCore | Listen for results (tokenization + checkout) |
| 3 | `SpreedlyOffsiteCheckout.present(transactionToken:)` | SpreedlyUI | Present Safari for EBANX checkout |
| 4 | `handleOffsiteReturn(url:)` | SpreedlyCore | Handle redirect URL when app re-opens |

---

## Flow

1. **Create payment method:** Call `submitOffsitePayment(config:)` with the appropriate `OffsitePaymentConfig` for the selected EBANX provider. Receive `payment_method_token` via `PaymentResult`.
2. **Purchase on your backend:** Call Spreedly purchase API with `payment_method_token`, `redirect_url`, `callback_url`, and `gateway_specific_fields` (including `ebanx.document` for taxpayer ID). Receive `transaction_token`.
3. **Present checkout:** Call `SpreedlyOffsiteCheckout.present(transactionToken:)`. SDK fetches the checkout URL and presents Safari.
4. **Handle result:** User completes payment in Safari. On return, SDK checks status and emits `PaymentResult`.

---

## Important Notes

- **`pending` is a success for EBANX:** Many EBANX methods (Boleto, OXXO, Pix) result in a `"pending"` state, meaning the customer will complete payment offline/externally. Treat `"pending"` as a successful initiation.
- **Document ID (CPF/CNPJ) required for Brazilian methods:** Required for Pix, Boleto, and NuPay. Pass it both in `OffsitePaymentConfig.documentId` (for tokenization) and in `gateway_specific_fields.ebanx.document` (for the purchase API).
- **Currency:** Use `BRL` for Brazilian methods (Pix, Boleto, NuPay) and `MXN` for Mexican methods (OXXO).
- **Do NOT cancel subscription in onDisappear:** Same subscription rules as offsite — Safari can trigger disappear events.
- **Custom URL scheme required:** The `redirect_url` in your purchase API call must use a custom URL scheme registered in your app's `Info.plist`. See [Custom URL Scheme Setup](offsite-payments.md#custom-url-scheme-setup) in the Offsite Payment Guide.

---

## EBANX Purchase API (Backend)

> The example app uses `PurchaseAPIClient` (see `API/PurchaseAPIClient.swift`). In production, replace this with your own backend endpoint.

Your backend purchase call to Spreedly must include EBANX gateway-specific fields.

> **Important:** Pix, Boleto Bancário, and NuPay require `gateway_specific_fields.ebanx.document` (CPF/CNPJ). OXXO does not.

Example request body:

```json
{
  "transaction": {
    "payment_method_token": "<token from step 1>",
    "amount": 9900,
    "currency_code": "BRL",
    "redirect_url": "spreedlyApp://yourapp/ebanx/checkout",
    "callback_url": "https://yourbackend.com/callback",
    "channel": "app",
    "gateway_specific_fields": {
      "ebanx": {
        "document": "853.513.468-93"
      }
    }
  }
}
```

- `document` — CPF/CNPJ taxpayer ID. Required for Pix, Boleto, NuPay. Not required for OXXO.
- `channel` — Set to `"app"` for mobile transactions.
- `redirect_url` — Must use a custom URL scheme registered in your app's `Info.plist`.

---

## SwiftUI Integration

```swift
import SwiftUI
import Combine
import SpreedlyCore
import SpreedlyUI

struct EbanxPaymentView: View {
    @State private var paymentResultCancellable: AnyCancellable?
    @State private var stage: EbanxStage = .idle
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    enum EbanxStage { case idle, creatingPaymentMethod, purchasing, checkout }

    var body: some View {
        VStack {
            // Your product selection and provider picker UI ...

            Button("Pay with Pix") { startEbanxFlow(provider: .pix) }
                .disabled(isLoading)

            if let success = successMessage {
                Text(success).foregroundColor(.green)
            }
            if let error = errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
        .onAppear {
            // Subscribe once — do NOT cancel in onDisappear
            paymentResultCancellable?.cancel()
            paymentResultCancellable = Spreedly.shared().subscribeToPaymentResults { result in
                handlePaymentResult(result)
            }
        }
        // IMPORTANT: Place .onOpenURL in your root @main App struct, NOT here.
        // It is shown inline for readability only.
        // See getting-started.md for the canonical onOpenURL setup.
        .onOpenURL { url in
            let isSpreedlyURL = Spreedly.shared().handleOffsiteReturn(url: url)
            if !isSpreedlyURL {
                // Handle other custom URL navigations
            }
        }
    }

    // MARK: - Start Flow

    func startEbanxFlow(provider: OffsitePaymentMethodType) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        stage = .creatingPaymentMethod

        Task {
            // Step 0: Generate signature and setup SDK (your implementation)
            await generateSignatureAndSetupSDK()

            // Step 1: Build config based on provider
            let config = buildConfig(for: provider)
            _ = Spreedly.shared().submitOffsitePayment(config: config)
        }
    }

    // MARK: - Build Provider Config

    func buildConfig(for provider: OffsitePaymentMethodType) -> OffsitePaymentConfig {
        switch provider {
        case .oxxo:
            return OffsitePaymentConfig(
                paymentMethodType: .oxxo,
                email: "user@example.com",
                fullName: "Maria Garcia",
                country: "MX",
                phoneNumber: "5551234567",
                address1: "Calle 10, 200",
                city: "Mexico City",
                state: "CDMX",
                zip: "06600"
            )
        case .nupay:
            return OffsitePaymentConfig(
                paymentMethodType: .nupay,
                email: "user@example.com",
                fullName: "Ana Santos",
                documentId: DocumentId(key: .documentId, value: "853.513.468-93"),
                country: "BR",
                phoneNumber: "11987654321"
            )
        default: // pix, boletoBancario
            return OffsitePaymentConfig(
                paymentMethodType: provider,
                email: "user@example.com",
                fullName: "Ana Santos",
                documentId: DocumentId(key: .documentId, value: "853.513.468-93"),
                country: "BR",
                phoneNumber: "11987654321",
                address1: "Rua E, 1040",
                city: "Maracanaú",
                state: "CE",
                zip: "12345"
            )
        }
    }

    // MARK: - Handle Two Responses

    func handlePaymentResult(_ result: PaymentResult) {
        switch stage {
        case .creatingPaymentMethod:
            if result.isSuccess, let token = result.token {
                stage = .purchasing
                Task { await purchaseWithToken(token) }
            } else if result.isFailure {
                isLoading = false
                stage = .idle
                errorMessage = result.failureDetails?.getDescription() ?? "Failed to create payment method"
            }

        case .purchasing:
            break

        case .checkout:
            isLoading = false
            stage = .idle
            if result.isSuccess {
                successMessage = "EBANX payment succeeded"
            } else if result.isFailure {
                switch result.state {
                case "pending":
                    // Pending is expected for Boleto, OXXO, Pix — customer completes offline
                    successMessage = "Payment initiated. The customer will complete payment offline."
                case "processing":
                    errorMessage = "Payment is being processed. Please wait."
                case "gateway_processing_failed":
                    errorMessage = "Payment could not be completed. Please try again."
                default:
                    errorMessage = result.failureDetails?.getDescription() ?? "EBANX checkout failed"
                }
            }

        case .idle:
            break
        }
    }

    // MARK: - Purchase (Merchant Backend Call)

    func purchaseWithToken(_ paymentMethodToken: String) async {
        let document: String? = "853.513.468-93" // CPF — omit for OXXO
        do {
            // Call YOUR backend which calls Spreedly purchase API
            // Include gateway_specific_fields.ebanx.document in the request
            let response = try await yourBackend.ebanxPurchase(
                paymentMethodToken: paymentMethodToken,
                amount: amountInCents,
                currencyCode: "BRL",
                redirectUrl: "spreedlyApp://yourapp/ebanx/checkout",
                callbackUrl: "https://yourbackend.com/callback",
                document: document
            )

            await MainActor.run {
                if let transaction = response.transaction {
                    stage = .checkout
                    SpreedlyOffsiteCheckout.present(transactionToken: transaction.token)
                } else {
                    isLoading = false
                    stage = .idle
                    errorMessage = "Purchase failed"
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                stage = .idle
                errorMessage = "Purchase failed: \(error.localizedDescription)"
            }
        }
    }
}
```

---

## UIKit Integration

```swift
import UIKit
import SpreedlyCore
import SpreedlyUI

class EbanxPaymentViewController: UIViewController, SpreedlyPaymentDelegate {

    enum EbanxStage { case idle, creatingPaymentMethod, purchasing, checkout }
    var stage: EbanxStage = .idle
    var selectedProvider: OffsitePaymentMethodType = .pix
    var amountInCents: Int = 9900  // Set from your product/order

    override func viewDidLoad() {
        super.viewDidLoad()
        Spreedly.shared().paymentDelegate = self
    }

    // MARK: - Start Flow

    func startEbanxFlow() {
        stage = .creatingPaymentMethod
        // Generate signature and setup SDK, then:
        let config = buildConfig(for: selectedProvider)
        Spreedly.shared().submitOffsitePayment(config: config)
    }

    // MARK: - Build Provider Config

    func buildConfig(for provider: OffsitePaymentMethodType) -> OffsitePaymentConfig {
        switch provider {
        case .oxxo:
            return OffsitePaymentConfig(
                paymentMethodType: .oxxo,
                email: "user@example.com",
                fullName: "Maria Garcia",
                country: "MX",
                phoneNumber: "5551234567",
                address1: "Calle 10, 200",
                city: "Mexico City",
                state: "CDMX",
                zip: "06600"
            )
        case .nupay:
            return OffsitePaymentConfig(
                paymentMethodType: .nupay,
                email: "user@example.com",
                fullName: "Ana Santos",
                documentId: DocumentId(key: .documentId, value: "853.513.468-93"),
                country: "BR",
                phoneNumber: "11987654321"
            )
        default:
            return OffsitePaymentConfig(
                paymentMethodType: provider,
                email: "user@example.com",
                fullName: "Ana Santos",
                documentId: DocumentId(key: .documentId, value: "853.513.468-93"),
                country: "BR",
                phoneNumber: "11987654321",
                address1: "Rua E, 1040",
                city: "Maracanaú",
                state: "CE",
                zip: "12345"
            )
        }
    }

    // MARK: - SpreedlyPaymentDelegate — Two responses

    func paymentDidComplete(_ result: PaymentResult) {
        DispatchQueue.main.async {
            switch self.stage {
            case .creatingPaymentMethod:
                if result.isSuccess, let token = result.token {
                    self.stage = .purchasing
                    self.purchaseWithToken(token)
                } else {
                    self.stage = .idle
                    self.showError(result.failureDetails?.getDescription() ?? "Failed to create payment method")
                }

            case .checkout:
                self.stage = .idle
                if result.isSuccess {
                    if result.state == "processing" {
                        self.showSuccess("Payment accepted and is being processed. Final confirmation may take a few days.")
                    } else if result.state == "pending" {
                        self.showSuccess("Payment submitted. Awaiting final confirmation from the payment provider.")
                    } else {
                        self.showSuccess("EBANX payment succeeded")
                    }
                } else if result.isFailure {
                    if result.state == "gateway_processing_failed" {
                        self.showError("Payment could not be completed. Please try again.")
                    } else if result.state == "processing" {
                        self.showSuccess("Payment accepted and is being processed. Final confirmation may take a few days.")
                    } else if result.state == "pending" {
                        self.showError("Your payment is pending. Please try again shortly.")
                    } else {
                        self.showError(result.failureDetails?.getDescription() ?? "EBANX checkout failed")
                    }
                }

            default:
                break
            }
        }
    }

    // MARK: - Purchase (Merchant Backend Call)

    func purchaseWithToken(_ paymentMethodToken: String) {
        // Call YOUR backend which calls Spreedly purchase API with gateway_specific_fields.ebanx.document
        // SpreedlyConfigManager is from the Example app -- replace with your own backend client
        let client = YourBackend.createPurchaseAPIClient()
        Task {
            do {
                let response = try await client.ebanxPurchase(
                    paymentMethodToken: paymentMethodToken,
                    amount: Decimal(amountInCents),
                    currencyCode: "BRL",
                    redirectUrl: "spreedlyApp://yourapp/ebanx/checkout",
                    callbackUrl: "https://yourbackend.com/callback"
                )
                await MainActor.run {
                    if let transaction = response.transaction {
                        self.stage = .checkout
                        SpreedlyOffsiteCheckout.present(transactionToken: transaction.token)
                    } else {
                        self.stage = .idle
                        self.showError("Purchase failed")
                    }
                }
            } catch {
                await MainActor.run {
                    self.stage = .idle
                    self.showError("Purchase failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

```

In your `SceneDelegate` — handle redirect return:

```swift
// Add this to your SceneDelegate
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    let isSpreedlyURL = Spreedly.shared().handleOffsiteReturn(url: url)
    if !isSpreedlyURL {
        // Handle other URLs
    }
}
```

---

## Objective-C Integration

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>
// Replace with your own backend client headers
#import "YourBackend.h"

typedef NS_ENUM(NSInteger, EbanxStage) {
    EbanxStageIdle,
    EbanxStageCreatingPaymentMethod,
    EbanxStagePurchasing,
    EbanxStageCheckout
};

@interface EbanxPaymentViewController () <SpreedlyPaymentDelegate>
@property (nonatomic, assign) EbanxStage stage;
@end

@implementation EbanxPaymentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Spreedly shared].paymentDelegate = self;
}

// MARK: - Start Flow

- (void)startEbanxFlowWithProvider:(OffsitePaymentMethodType)provider {
    self.stage = EbanxStageCreatingPaymentMethod;
    // Generate signature, setup SDK, then:
    OffsitePaymentConfig *config = [self buildConfigForProvider:provider];
    [[Spreedly shared] submitOffsitePaymentWithConfig:config];
}

// MARK: - Build Provider Config

- (OffsitePaymentConfig *)buildConfigForProvider:(OffsitePaymentMethodType)provider {
    switch (provider) {
        case OffsitePaymentMethodTypeOxxo:
            return [[OffsitePaymentConfig alloc]
                initWithPaymentMethodType:OffsitePaymentMethodTypeOxxo
                redirectUrl:nil email:@"user@example.com"
                fullName:@"Maria Garcia"
                firstName:nil lastName:nil documentId:nil
                country:@"MX" countryCode:nil
                phoneNumber:@"5551234567"
                address1:@"Calle 10, 200" address2:nil
                city:@"Mexico City" state:@"CDMX" zip:@"06600"];

        case OffsitePaymentMethodTypeNupay:
            return [[OffsitePaymentConfig alloc]
                initWithPaymentMethodType:OffsitePaymentMethodTypeNupay
                redirectUrl:nil email:@"user@example.com"
                fullName:@"Ana Santos"
                firstName:nil lastName:nil
                documentId:[[DocumentId alloc] initWithKey:DocumentIdKeyDocumentId
                                                    value:@"853.513.468-93"
                                                customKey:nil]
                country:@"BR" countryCode:nil
                phoneNumber:@"11987654321"
                address1:nil address2:nil
                city:nil state:nil zip:nil];

        default: // Pix, Boleto
            return [[OffsitePaymentConfig alloc]
                initWithPaymentMethodType:provider
                redirectUrl:nil email:@"user@example.com"
                fullName:@"Ana Santos"
                firstName:nil lastName:nil
                documentId:[[DocumentId alloc] initWithKey:DocumentIdKeyDocumentId
                                                    value:@"853.513.468-93"
                                                customKey:nil]
                country:@"BR" countryCode:nil
                phoneNumber:@"11987654321"
                address1:@"Rua E, 1040" address2:nil
                city:@"Maracanaú" state:@"CE" zip:@"12345"];
    }
}

// MARK: - SpreedlyPaymentDelegate — Two responses

- (void)paymentDidComplete:(PaymentResult *)result {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.stage == EbanxStageCreatingPaymentMethod) {
            if (result.isSuccess && result.token.length > 0) {
                self.stage = EbanxStagePurchasing;
                [self purchaseWithToken:result.token];
            } else {
                self.stage = EbanxStageIdle;
                NSString *msg = [result.failureDetails getDescription] ?: @"Failed to create payment method";
                [self showError:msg];
            }
        } else if (self.stage == EbanxStageCheckout) {
            self.stage = EbanxStageIdle;
            if (result.isSuccess) {
                if ([result.state isEqualToString:@"processing"]) {
                    [self showSuccess:@"Payment accepted and is being processed. Final confirmation may take a few days."];
                } else if ([result.state isEqualToString:@"pending"]) {
                    [self showSuccess:@"Payment submitted. Awaiting final confirmation from the payment provider."];
                } else {
                    [self showSuccess:@"EBANX payment succeeded"];
                }
            } else if (result.isFailure) {
                if ([result.state isEqualToString:@"gateway_processing_failed"]) {
                    [self showError:@"Payment could not be completed. Please try again."];
                } else if ([result.state isEqualToString:@"processing"]) {
                    [self showSuccess:@"Payment accepted and is being processed. Final confirmation may take a few days."];
                } else if ([result.state isEqualToString:@"pending"]) {
                    [self showError:@"Your payment is pending. Please try again shortly."];
                } else {
                    NSString *msg = [result.failureDetails getDescription] ?: @"EBANX checkout failed";
                    [self showError:msg];
                }
            }
        }
    });
}

// MARK: - Purchase (Merchant Backend Call)

- (void)purchaseWithToken:(NSString *)paymentMethodToken {
    // Replace with your own backend client that calls the Spreedly purchase API
    YourBackendAPIClient *client = [[YourBackend shared] createPurchaseAPIClient];
    NSDecimalNumber *amount = [NSDecimalNumber numberWithInt:9900];
    [client ebanxPurchaseWithPaymentMethodToken:paymentMethodToken
                                         amount:amount
                                   currencyCode:@"BRL"
                                    redirectUrl:@"spreedlyApp://yourapp/ebanx/checkout"
                                    callbackUrl:@"https://yourbackend.com/callback"
                                       document:@"853.513.468-93"
                                     completion:^(PurchaseResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !response || !response.transaction) {
                self.stage = EbanxStageIdle;
                [self showError:error.localizedDescription ?: @"Purchase failed"];
                return;
            }
            self.stage = EbanxStageCheckout;
            [SpreedlyOffsiteCheckout presentWithTransactionToken:response.transaction.token];
        });
    }];
}

@end
```

In `SceneDelegate.m` — handle redirect return:

```objc
// Add this to your SceneDelegate.m
@implementation SceneDelegate

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
    NSURL *url = URLContexts.allObjects.firstObject.URL;
    if (url) {
        BOOL isSpreedlyURL = [[Spreedly shared] handleOffsiteReturnWithUrl:url];
        if (!isSpreedlyURL) {
            // Handle other URLs
        }
    }
}

@end
```

---

## EBANX Config Reference

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `paymentMethodType` | `OffsitePaymentMethodType` | Yes | `.pix`, `.boletoBancario`, `.oxxo`, `.nupay` |
| `email` | `String` | Yes | Customer email |
| `fullName` | `String` | Yes | Customer full name |
| `documentId` | `DocumentId` | Pix, Boleto, NuPay | CPF/CNPJ — use `DocumentId(key: .documentId, value: "...")` |
| `country` | `String` | Yes | `"BR"` for Brazil, `"MX"` for Mexico |
| `phoneNumber` | `String` | Yes | Customer phone number |
| `address1` | `String` | Pix, Boleto, OXXO | Street address |
| `city` | `String` | Pix, Boleto, OXXO | City |
| `state` | `String` | Pix, Boleto, OXXO | State/province |
| `zip` | `String` | Pix, Boleto, OXXO | Postal code |

---

## EBANX Result States

| state | Meaning | UX |
|-------|---------|-----|
| succeeded | Payment completed | Show success |
| pending | Customer will pay offline (Boleto, OXXO, Pix) | Show success message — "Payment initiated, complete offline" |
| processing | Payment is being processed | Show wait message |
| gateway_processing_failed | Gateway could not process | Show retry message |

---

### Blocked Devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK blocks this flow automatically. The `present()` call returns immediately without showing any UI, and a `PaymentResult.failure` is published. See [Security — Runtime Integrity](security.md#runtime-integrity) for details.

## Related Documentation

- [offsite-payments.md](offsite-payments.md) — Custom URL scheme setup, offsite flow details
- [stripe-apm.md](stripe-apm.md) — Alternative payment methods via Stripe
- [EBANX_FLOW.md](../development/EBANX_FLOW.md) — Detailed flow diagrams for EBANX payments
