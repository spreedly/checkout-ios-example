# 3DS Authentication (Global) - Spreedly iOS SDK

Add 3D Secure authentication to protect against fraudulent card payments.

**Estimated integration time:** ~15 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Flow](#flow)
4. [SwiftUI Integration](#swiftui-integration)
5. [UIKit Integration](#uikit-integration)
6. [Objective-C Integration](#objective-c-integration)
7. [Result Handling](#result-handling)
8. [Backend Requirements](#backend-requirements)
9. [Error Handling](#error-handling)
10. [Troubleshooting](#troubleshooting)
11. [Related Documentation](#related-documentation)

---

## Introduction

### What is 3DS Global?

3DS Global uses the Forter SDK to provide unified 3D Secure authentication across multiple payment gateways. The SDK manages the challenge flow end-to-end: it fetches the managed order token, presents the challenge UI when required, calls completion APIs, and emits the final result based on the status API response.

> **Module note:** 3DS Global logic currently lives inside `SpreedlyCore` (coordination and API calls) and `SpreedlyUI` (challenge presentation). It is **not a separate SDK module yet**. We plan to extract it into a dedicated `SpreedlyForter3DS` module in a future release so merchants who don't use 3DS can exclude it entirely. The third-party `Forter3DS` framework is already an optional runtime dependency that merchants add separately (see [Prerequisites](#prerequisites)).

### When to Use

- You need multi-gateway support with a single 3DS implementation
- You use Forter for fraud prevention and want SDK-managed 3DS
- You prefer automatic challenge UI presentation without manual backend calls during the flow

### Global vs Gateway-Specific Comparison

| Feature | Global (This Guide) | Gateway-Specific |
|--------|---------------------|------------------|
| Provider | Forter SDK | Gateway's own (e.g. Worldpay) |
| Purchase API | No `attempt_3dsecure` | `attempt_3dsecure: true` |
| SDK | `DoChallengeIfNeeded` | `DoChallengeIfNeeded` + trigger + finalize |
| Challenge UI | Automatic | SDK-managed |
| Backend calls | SDK handles | Merchant calls `/complete.json` |

---

## Prerequisites

### Forter3DS Dependency (Required)

The Forter3DS dependency **MUST** be added to your app target. Without it, the app will crash when 3DS is required.

> **Module note:** A dedicated `SpreedlyForter3DS` module is planned for a future release. Today, merchants add the third-party `Forter3DS` framework directly (see options below).

**Option A: SPM (direct Forter3DS)**

Add `Forter3DS` directly from the Forter repository (the Spreedly package does not include a SpreedlyForter3DS product yet):

1. File → Add Package Dependencies
2. Enter repository URL: `https://bitbucket.org/forter-mobile/forter-ios.git`
3. Set dependency rule to "Exact Version" (2.1.0)
4. Add `Forter3DS` product to your app target
5. Ensure "Embed & Sign" is set in "Frameworks, Libraries, and Embedded Content"

**Option B: CocoaPods**

Add `Forter3DS` directly from Forter's Bitbucket repository (it is not on CocoaPods trunk):

```ruby
pod 'Forter3DS', :git => 'https://bitbucket.org/forter-mobile/forter-ios.git', :tag => '2.1.0'
```

**Add via Package.swift (Option A):**

```swift
dependencies: [
    .package(url: "https://bitbucket.org/forter-mobile/forter-ios.git", exact: "2.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "Forter3DS", package: "forter-ios")
        ]
    )
]
```

**Without Forter3DS:** The app will crash with `dyld: Library not loaded: Forter3DS` when 3DS is required.

If Forter3DS is an optional dependency, use `#if canImport(Forter3DS)` to conditionally import it.

### Spreedly Setup

Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`). Then call `Spreedly.setup(config:)` with `forterSiteId` before any 3DS operations:

```swift
Spreedly.setup(config: SpreedlyConfig(
    environmentKey: "your_environment_key",
    forterSiteId: "your_forter_site_id",  // Required for 3DS
    certificateToken: certificateToken,
    nonce: nonce,
    signature: signature,
    timestamp: timestamp
))
```

---

## Flow

1. **Backend purchase/authorize** – Your backend calls purchase or authorize without `attempt_3dsecure`. When 3DS is required, the response includes `transaction.token` and `sca_authentication`.
2. **App presents DoChallengeIfNeeded** – Present the challenge UI with the transaction token.
3. **SDK completes and emits ThreeDSChallengeResult** – The SDK fetches the managed order token, runs the Forter challenge, calls completion APIs, and emits the final result based on the status API response.

### End-to-End Flow

1. Create payment method (tokenize card)
2. Send token to backend → create purchase with 3DS
3. Check `transaction.sca_authentication` — if "pending", present challenge
4. Present `DoChallengeIfNeeded` with `transactionToken`
5. Handle result via `subscribeToThreeDSChallengeResults`

---

## SwiftUI Integration

Present `DoChallengeIfNeeded` in a sheet. Subscribe to `subscribeToThreeDSChallengeResults` **before** presenting the challenge. `subscribeToThreeDSChallengeResults` callbacks are dispatched on the main thread.

```swift
@State private var show3DSChallenge = false
@State private var transactionToken: String?
@State private var challengeCancellable: AnyCancellable?

var body: some View {
    // Your payment UI
    .sheet(isPresented: $show3DSChallenge) {
        if let token = transactionToken {
            DoChallengeIfNeeded(
                transactionToken: token,
                onDismiss: { show3DSChallenge = false }
            )
        }
    }
    .onAppear {
        challengeCancellable = Spreedly.shared().subscribeToThreeDSChallengeResults { result in
            if result.isSuccess {
                // Show success
            } else if result.isFailure {
                // Show error
            } else if result.isCanceled {
                // User canceled
            }
        }
    }
    .onDisappear {
        challengeCancellable?.cancel()
    }
}
```

When showing error messages from `ThreeDSChallengeResult`, use your normal error handling to decide what to display to the user.

---

## UIKit Integration

`subscribeToThreeDSChallengeResults` callbacks are dispatched on the main thread.

### Option 1: UIHostingController

Wrap `DoChallengeIfNeeded` in a `UIHostingController`:

```swift
import SwiftUI

private var challengeCancellable: AnyCancellable?

func setup3DS() {
    challengeCancellable = Spreedly.shared().subscribeToThreeDSChallengeResults { result in
        if result.isSuccess {
            // Show success
        } else if result.isFailure {
            // Show error
        } else if result.isCanceled {
            // User canceled
        }
    }
}

func present3DSChallenge(transactionToken: String) {
    let challengeView = DoChallengeIfNeeded(
        transactionToken: transactionToken,
        onDismiss: { [weak self] in self?.dismiss(animated: true) }
    )
    let hostingVC = UIHostingController(rootView: challengeView)
    present(hostingVC, animated: true)
}
```

### Option 2: DoChallengeIfNeededViewController

Use the pre-built view controller wrapper:

```swift
private var challengeCancellable: AnyCancellable?

func setup3DS() {
    challengeCancellable = Spreedly.shared().subscribeToThreeDSChallengeResults { result in
        // Handle success/failure/canceled
    }
}

func present3DSChallenge(transactionToken: String) {
    let challengeVC = DoChallengeIfNeededViewController(
        transactionToken: transactionToken,
        onDismiss: { [weak self] in self?.dismiss(animated: true) }
    )
    present(challengeVC, animated: true)
}
```

---

## Objective-C Integration

Add the import, conform to `SpreedlyThreeDSChallengeDelegate`, set `threeDSChallengeDelegate`, and implement the delegate method. Present `DoChallengeIfNeededViewController` when the challenge is needed.

```objc
#import <SpreedlyCore/SpreedlyCore-Swift.h>
#import <SpreedlyUI/SpreedlyUI-Swift.h>

@interface YourViewController () <SpreedlyThreeDSChallengeDelegate>
@end

@implementation YourViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Spreedly shared].threeDSChallengeDelegate = self;
}

- (void)present3DSChallengeWithTransactionToken:(NSString *)transactionToken {
    DoChallengeIfNeededViewController *challengeVC =
        [[DoChallengeIfNeededViewController alloc] initWithTransactionToken:transactionToken onDismiss:nil];
    [self presentViewController:challengeVC animated:YES completion:nil];
}

- (void)threeDSChallengeDidComplete:(ThreeDSChallengeResult *)result {
    if (result.isSuccess) {
        // Show success
    } else if (result.isFailure) {
        // Show error: use result.failureDetails.message and result.error
        NSString *errorMsg = @"Payment failed";
        if (result.failureDetails.message) {
            errorMsg = [NSString stringWithFormat:@"Payment failed: %@", result.failureDetails.message];
        } else if (result.error) {
            errorMsg = [NSString stringWithFormat:@"Payment failed: %@", result.error.localizedDescription];
        }
        // Display errorMsg to user
    } else if (result.isCanceled) {
        // User canceled
    }
    
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
```

---

## Result Handling

`ThreeDSChallengeResult` provides three mutually exclusive states:

| Property | Description |
|----------|-------------|
| `isSuccess` | Challenge completed successfully |
| `isFailure` | Challenge failed (check `error` for details) |
| `isCanceled` | User canceled the challenge |

The result reflects the status API response, not only the Forter callback. This keeps the final transaction state accurate even when the gateway returns a different outcome after the challenge.

---

## Backend Requirements

Your backend must call purchase or authorize **without** `attempt_3dsecure`. When 3DS is required, the response includes `transaction.token` and `sca_authentication`.

### Backend Purchase Example

```bash
POST https://core.spreedly.com/v1/gateways/{gateway_token}/purchase.json
Authorization: Basic {base64(environment_key:access_secret)}
Content-Type: application/json

{
  "transaction": {
    "payment_method_token": "<token from card tokenization>",
    "amount": 1000,
    "currency_code": "USD",
    "channel": "app"
  }
}
```

**Response (when 3DS is required):**

```json
{
  "transaction": {
    "token": "AbCd1234...",
    "state": "pending",
    "sca_authentication": {
      "status": "pending",
      "required_action": "challenge"
    }
  }
}
```

Pass `transaction.token` to `DoChallengeIfNeeded` in the app. The SDK handles completion and status APIs internally; no additional backend calls are needed during the challenge flow.

**Note:** Do **not** pass `attempt_3dsecure: true` for the global (Forter) flow. That parameter is only for gateway-specific 3DS (see [3ds-gateway-specific.md](3ds-gateway-specific.md)).

> When calling purchase for global 3DS, pass `useGatewaySpecific3DS: false` (or omit it) in your backend request to ensure the Forter-based global flow is used instead of gateway-specific 3DS.

---

## Error Handling

### 3DS-Specific Errors

| Error | Cause | Action |
|-------|-------|--------|
| Forter3DS framework not available | `Forter3DS` not embedded in app bundle | Add dependency and set "Embed & Sign" |
| Forter SDK not initialized | Missing `forterSiteId` in `Spreedly.setup(config:)` | Call setup with `forterSiteId` |
| Forter SDK challenge error | Challenge failed in Forter | Check `result.error`; use Forter portal for configuration |
| Managed order token missing | Status API did not return `managed_order_token` | Verify backend response and transaction state |
| Network error | API calls failed during flow | Check connectivity; retry if appropriate |

For detailed error handling patterns, see [error-handling.md](error-handling.md).

---

### Blocked Devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK blocks 3DS challenge flows automatically. `DoChallengeIfNeeded` auto-dismisses and emits a failure result. See [Security — Runtime Integrity](security.md#runtime-integrity) for details.

## Troubleshooting

### Forter3DS crash: "dyld: Library not loaded: Forter3DS"

- Add Forter3DS as a **direct** dependency to your app target (not transitive).
- Ensure "Embed & Sign" is set in "Frameworks, Libraries, and Embedded Content".
- Rebuild and test on a device; simulator may not always reproduce the crash.

### Challenge not appearing

- Verify `transactionToken` is present and valid.
- For Global flow, the status API must return `managed_order_token`.
- Ensure `subscribeToThreeDSChallengeResults` is called **before** presenting the challenge.
- If challenge is not required, Forter may complete immediately without showing UI (this is expected).

### Result not received

- Subscribe to `subscribeToThreeDSChallengeResults` before presenting the challenge.
- Do not cancel the subscription until the flow completes or the view is dismissed.
- Check that `Spreedly.setup(config:)` was called with `forterSiteId`.

---

## Related Documentation

- [3ds-gateway-specific.md](3ds-gateway-specific.md) – Gateway-specific 3DS (e.g. Worldpay) with `/complete.json` flow
- [error-handling.md](error-handling.md) – Error types, handling patterns, troubleshooting
- [getting-started.md](getting-started.md) – Installation, setup, and basic configuration
- [3DS_GLOBAL_FLOW.md](../development/3DS_GLOBAL_FLOW.md) – Detailed flow diagrams for 3DS Global (Forter) including sequence diagrams, SDK internals, and decision flows
