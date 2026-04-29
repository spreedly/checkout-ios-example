# Gateway-Specific 3DS - Spreedly iOS SDK

Integrate gateway-driven 3DS authentication for gateways like Worldpay.

**Estimated time:** ~15 minutes

## Table of Contents

1. [Introduction](#introduction)
2. [How the Challenge Works](#how-the-challenge-works)
3. [Prerequisites](#prerequisites)
4. [Flow](#flow)
5. [Purchase Response Checks](#purchase-response-checks)
6. [Events](#events)
7. [SwiftUI Integration](#swiftui-integration)
8. [UIKit Integration (Swift + Combine)](#uikit-integration-swift--combine)
9. [UIKit (Notification + Delegate)](#uikit-notification--delegate)
10. [Objective-C Integration](#objective-c-integration)
11. [Device Fingerprint Polling](#device-fingerprint-polling)
12. [Result Handling](#result-handling)
13. [Deprecated APIs](#deprecated-apis)
14. [Troubleshooting](#troubleshooting)
15. [Related Documentation](#related-documentation)

---

## Introduction

### When to Use

Use gateway-specific 3DS when your payment gateway explicitly requires its own 3DS implementation. Examples include Worldpay and other gateways that handle 3DS authentication through their own flow rather than the global Forter-based flow.

> **Module note:** Gateway-Specific 3DS logic currently lives inside `SpreedlyCore` (lifecycle, device fingerprint, trigger/finalize) and `SpreedlyUI` (challenge presentation via `ASWebAuthenticationSession`). It is **not a separate SDK module yet**. We plan to extract it into a dedicated `SpreedlyGateway3DS` module in a future release so merchants who don't use gateway-specific 3DS can exclude it entirely. Unlike 3DS Global, this flow does not require the third-party `Forter3DS` framework.

### Global vs Gateway-Specific Comparison

| Flow | Backend responsibility | App responsibility |
|------|------------------------|---------------------|
| **3DS Global (Forter)** | Purchase/authorize; return `transaction_token` when 3DS required | Present challenge UI; SDK calls complete/status; handle result |
| **3DS Gateway-Specific** | Purchase; when SDK signals, call `/complete.json` | Present challenge UI; on trigger, call backend; finalize with response; handle result |

For a full comparison table and detailed flow diagrams, see [3ds-global.md](3ds-global.md).

---

## How the Challenge Works

When you present `DoChallengeIfNeeded`, the SDK manages two internal phases automatically:

| Phase | Mechanism | User-visible? |
|-------|-----------|---------------|
| **Device fingerprint** | Hidden WKWebView (background, non-interactive) | No — runs silently |
| **Challenge** | `ASWebAuthenticationSession` | Yes — system-managed secure browser with visible URL bar |

**Device fingerprint:** The SDK injects a hidden 1×1 WKWebView to collect device fingerprint data. This is non-interactive and follows industry standard practice for 3DS device data collection.

**Challenge (`ASWebAuthenticationSession`):** When the gateway requires user interaction (e.g. OTP entry or biometric verification), the SDK presents `ASWebAuthenticationSession` — Apple's endorsed API for web-based authentication. The browser shows the bank's domain (anti-phishing) and stays in-app; **no `Info.plist` registration, redirect URL, or `onOpenURL` handler is needed**. Challenge completion is detected by status polling (every 2 seconds), which dismisses the session automatically.

**User cancellation:** If the user taps **"Cancel"** in the authentication session during the challenge, the SDK treats it as a failure and emits `ThreeDSChallengeResult` with `isFailure == true`. The error message will contain `"3DS challenge canceled by user"`. Handle this in your `isFailure` branch.

> **Note:** You do not need to manage the auth session presentation or dismissal. The SDK handles this automatically. Your `DoChallengeIfNeeded` view displays a loading spinner while both phases run; the auth session is presented on top when the challenge phase begins. No `Info.plist` URL scheme or `onOpenURL` handler is required for the default flow.

---

## Prerequisites

Same as global 3DS, plus:

1. Complete [getting-started.md](getting-started.md) (installation, basic setup).
2. Ensure `Spreedly.initializeSDK()` is called at app launch (e.g., in your `App.init()` or `AppDelegate`).
3. Call `Spreedly.setup(config:)` with environment key and signature parameters before any 3DS calls.
4. A gateway that requires gateway-specific 3DS (e.g. Worldpay).
5. **No `Info.plist` URL scheme, redirect URL, or `onOpenURL` handler needed for 3DS.** The SDK uses `ASWebAuthenticationSession`, which stays in-app. Polling detects the terminal state and dismisses the session automatically.
6. When creating the purchase/authorize on your backend, include these parameters:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `attempt_3dsecure` | `true` | Tells Spreedly to attempt 3DS authentication |
| `callback_url` | Your backend URL | For server-to-server notifications |

The SDK detects that gateway-specific 3DS is needed from the transaction response.

**Example backend purchase call:**

```json
{
  "transaction": {
    "payment_method_token": "...",
    "amount": 1999,
    "currency_code": "USD",
    "attempt_3dsecure": true,
    "callback_url": "https://yourbackend.com/callback"
  }
}
```

**Note:** The purchase/authorize call is made by your **backend** to the Spreedly REST API — the iOS SDK does not provide a `purchase()` method. Your backend creates the transaction and returns the `transaction.token` and state to your app, which then uses the SDK for 3DS challenge handling.

---

## Flow

1. **Backend purchase/authorize** returns `transaction.token`.
2. **App presents** `DoChallengeIfNeeded` with the transaction token. The SDK shows a loading spinner, runs device fingerprint in a hidden WKWebView, and auto-presents `ASWebAuthenticationSession` if a challenge is required (see [How the Challenge Works](#how-the-challenge-works)).
3. **SDK emits** `GatewaySpecific3DSTriggerCompletion` when your backend must call `/complete.json`.
4. **App calls** `GatewaySpecific3DSIntegration.finalizeTransaction(for:transaction:)` with the `/complete.json` response.
5. **SDK emits** `ThreeDSChallengeResult` with the final outcome.

**Note:** The `/complete.json` call must be made by your backend. The app should call your backend endpoint, which in turn calls Spreedly. The exact Spreedly endpoint is:

- **Method:** `POST`
- **Path:** `https://core.spreedly.com/v1/transactions/{token}/complete.json`

Replace `{token}` with the transaction token from the `GatewaySpecific3DSTriggerCompletion` event.

**Important:** If you present `DoChallengeIfNeeded`, the SDK handles the 3DS lifecycle internally. Follow only the steps in this guide.

---

## Purchase Response Checks

After your backend returns a purchase/authorize response:

- If `response.errors` is non-empty: surface the error and stop the flow.
- If `transaction` is missing: treat it as an error and stop the flow.
- If `transaction.state == "pending"` or `transaction.scaAuthentication?.requiredAction == "device_fingerprint"`: present the challenge UI.
- If `transaction.state == "succeeded"`: show success immediately and skip the challenge UI.

When showing error messages during gateway-specific flows, use your normal error handling to decide what to display to the user.

---

## Events

| Event | Meaning |
|-------|---------|
| `GatewaySpecific3DSTriggerCompletion` | The SDK needs your backend to call `/complete.json`. The event provides the transaction token. |
| `ThreeDSChallengeResult` | Final 3DS outcome (success, failure, or canceled). Handle all three cases in your subscriber. |
| `GatewaySpecific3DSStatusUpdate` (notification) | Fires on each status poll during the challenge phase. Optional — use only if you need to display live status to the user. |

---

## GatewaySpecific3DSIntegration

The main integration point for gateway-specific 3DS flows.

### Starting a Flow

- **`startFlow(transactionToken:statusResponse:presentingViewController:)`** — Starts the gateway-specific 3DS flow programmatically. **Most merchants should use `DoChallengeIfNeeded` (SwiftUI) or `DoChallengeIfNeededViewController` (UIKit) instead** — they handle status detection, flow routing, and presentation automatically. Use `startFlow` only when you need full programmatic control (e.g., custom UI around the challenge).

### Managing Flows

- **`cancelFlow(for:)`** — Cancels an active flow for a given transaction token. Call this to programmatically abort a 3DS flow. The SDK will emit `ThreeDSChallengeResult` with `isCanceled == true`.

- **`getLifecycle(for:)`** → `GatewaySpecific3DSLifecycle?` — Retrieves the lifecycle object for a transaction. Returns `nil` if no active flow exists for the given token.

### Finalizing

- **`finalizeTransaction(for:transaction:)`** — Pass the `/complete.json` response to the SDK so it can emit `ThreeDSChallengeResult`. Call this when `GatewaySpecific3DSTriggerCompletion` fires and your backend has returned a non-succeeded transaction.

**Important:** The `transaction` parameter is `TransactionStatus` — a Codable struct defined by the SDK. When your backend returns the raw `/complete.json` JSON, you must extract the `"transaction"` key and decode it:

```swift
// Your backend returns the raw /complete.json response as Data
let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
guard let transactionDict = json?["transaction"] as? [String: Any] else { return }
let transactionData = try JSONSerialization.data(withJSONObject: transactionDict)
let transaction = try JSONDecoder().decode(TransactionStatus.self, from: transactionData)

GatewaySpecific3DSIntegration.finalizeTransaction(
    for: transactionToken,
    transaction: transaction
)
```

**For Objective-C**, use `GatewaySpecific3DSObjCBridge.finalizeTransactionForTransactionToken:completeResponseData:error:` instead — it accepts raw `NSData` from `/complete.json` and handles decoding internally.

---

## GatewaySpecific3DSLifecycle

The lifecycle manager for gateway-specific 3DS flows. Obtain an instance via `GatewaySpecific3DSIntegration.getLifecycle(for:)`.

### Public Methods

- **`start()`** — Starts the lifecycle (device fingerprint, polling, etc.).
- **`finalize(transaction:)`** — Finalizes the flow with the transaction from `/complete.json`. Use when your backend has returned the complete response.

> **Note:** `stop()` and `state` are internal to the SDK. Use `GatewaySpecific3DSIntegration.cancelFlow(for:)` to programmatically cancel a flow, and subscribe to `ThreeDSChallengeResult` to observe the final outcome.

---

## SwiftUI Integration

Subscribe to both `subscribeToThreeDSChallengeResults` and `subscribeToGatewaySpecific3DSTriggerCompletion` before presenting the challenge. On trigger, call your backend to invoke `/complete.json`. If the response state is `succeeded`, show success immediately; otherwise call `finalizeTransaction`.

**Note:** Store subscription cancellables and cancel them in `onDisappear` (SwiftUI) or `dealloc` (UIKit/Obj-C) to prevent memory leaks.

```swift
@State private var show3DSChallenge = false
@State private var transactionToken: String?
@State private var challengeCancellable: AnyCancellable?
@State private var triggerCancellable: AnyCancellable?
@State private var errorMessage: String?
@State private var successMessage: String?

var body: some View {
    // Your payment UI
    .sheet(isPresented: $show3DSChallenge) {
        if let token = transactionToken {
            // The SDK shows a loading spinner, runs device fingerprint in
            // a hidden WebView, and auto-presents the challenge if needed.
            DoChallengeIfNeeded(transactionToken: token) {
                show3DSChallenge = false
            }
        }
    }
    .onAppear {
        // ── STEP 1: Subscribe to events BEFORE presenting the challenge ──
        // Both subscriptions must be active before DoChallengeIfNeeded is
        // shown. If you subscribe after presenting, you may miss the
        // trigger or the final result.

        // Subscribe to the final 3DS outcome (success / failure / cancel).
        // This fires once per flow, after the SDK determines the terminal state.
        challengeCancellable = Spreedly.shared().subscribeToThreeDSChallengeResults { result in
            if result.isSuccess {
                // Authentication succeeded — payment is authorized.
                successMessage = "Payment successful"
                show3DSChallenge = false
            } else if result.isFailure {
                // Authentication failed, or the user tapped "Cancel" in the
                // auth session. Check result.error for "3DS challenge canceled
                // by user" if you want to distinguish user cancellation.
                errorMessage = result.error?.localizedDescription ?? "Payment failed"
                show3DSChallenge = false
            } else if result.isCanceled {
                // Only emitted when cancelFlow() is called programmatically.
                errorMessage = "Payment canceled"
                show3DSChallenge = false
            }
        }

        // ── STEP 2: Subscribe to the trigger event ──
        // After the SDK finishes device fingerprint collection, it emits this
        // trigger to tell your app: "call /complete.json on your backend now."
        // This is the handoff: SDK → your app → your backend → Spreedly API.
        triggerCancellable = Spreedly.shared().subscribeToGatewaySpecific3DSTriggerCompletion { event in
            Task {
                // ── STEP 3: Call your backend to invoke /complete.json ──
                // Your backend calls POST /v1/transactions/{token}/complete.json
                // and returns the raw JSON response as Data.
                let responseData = try await backend.complete(transactionToken: event.token)

                // Decode the "transaction" key from the /complete.json response.
                // The SDK needs a TransactionStatus to determine next steps.
                let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
                guard let txnDict = json?["transaction"] as? [String: Any] else { return }
                let txnData = try JSONSerialization.data(withJSONObject: txnDict)
                let transaction = try JSONDecoder().decode(TransactionStatus.self, from: txnData)

                // ── STEP 4: Check if the transaction is already terminal ──
                // If /complete.json returned "succeeded", no challenge is needed.
                // Show success and skip finalize entirely.
                if transaction.state?.lowercased() == "succeeded" {
                    await MainActor.run {
                        successMessage = "Payment successful"
                        show3DSChallenge = false
                    }
                    return
                }

                // ── STEP 5: Finalize — hand the response back to the SDK ──
                // For non-succeeded states the SDK checks whether a user-facing
                // challenge is required and presents it automatically.
                await MainActor.run {
                    GatewaySpecific3DSIntegration.finalizeTransaction(
                        for: event.token,
                        transaction: transaction
                    )
                }
            }
        }
    }
    .onDisappear {
        // Cancel subscriptions when leaving the view. Be careful not to
        // cancel while the auth session is still showing — see Troubleshooting.
        challengeCancellable?.cancel()
        triggerCancellable?.cancel()
    }
}

// ── ENTRY POINT: Call this after your backend returns a purchase response ──
// PurchaseResponse is YOUR app's model for the backend response — not an SDK type.
func handlePurchaseResponse(_ response: PurchaseResponse) {
    // Bail early on backend errors.
    guard response.errors?.isEmpty ?? true else {
        errorMessage = "Purchase failed"
        return
    }
    guard let transaction = response.transaction else {
        errorMessage = "Missing transaction"
        return
    }
    transactionToken = transaction.token

    // Route based on the purchase response state:
    // • "succeeded"            → 3DS not required, payment is done.
    // • "pending" or device_fingerprint required → present DoChallengeIfNeeded
    //   to kick off the 3DS flow (device fingerprint → trigger → challenge).
    let state = transaction.state?.lowercased() ?? ""
    let requiredAction = transaction.scaAuthentication?.requiredAction?.lowercased() ?? ""
    if state == "succeeded" {
        successMessage = "Payment successful"
    } else if state == "pending" || requiredAction == "device_fingerprint" {
        show3DSChallenge = true
    }
}
```

---

## UIKit Integration (Swift + Combine)

Same pattern as SwiftUI: subscribe to both events in `viewDidLoad`, present the challenge when needed, and handle the trigger by calling your backend and then `finalizeTransaction`.

```swift
final class GatewaySpecific3DSViewController: UIViewController {
    private var challengeCancellable: AnyCancellable?
    private var triggerCancellable: AnyCancellable?
    private var transactionToken: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        // ── STEP 1: Subscribe to events BEFORE presenting the challenge ──
        // Both subscriptions must be active before the challenge VC is
        // presented, otherwise you may miss the trigger or the final result.

        // Subscribe to the final 3DS outcome (fires once per flow).
        challengeCancellable = Spreedly.shared().subscribeToThreeDSChallengeResults { [weak self] result in
            if result.isSuccess {
                // Authentication succeeded — payment is authorized.
                self?.dismiss(animated: true)
            } else if result.isFailure {
                // Authentication failed or user tapped "Cancel" in the
                // auth session. Check result.error for details.
                self?.dismiss(animated: true)
            } else if result.isCanceled {
                // Only emitted when cancelFlow() is called programmatically.
                self?.dismiss(animated: true)
            }
        }

        // ── STEP 2: Subscribe to the trigger event ──
        // Fires when device fingerprint is done and the SDK needs your
        // backend to call /complete.json.
        triggerCancellable = Spreedly.shared().subscribeToGatewaySpecific3DSTriggerCompletion { [weak self] event in
            Task {
                // ── STEP 3: Call your backend to invoke /complete.json ──
                let responseData = try await backend.complete(transactionToken: event.token)

                // Decode the "transaction" key from the /complete.json response.
                let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
                guard let txnDict = json?["transaction"] as? [String: Any] else { return }
                let txnData = try JSONSerialization.data(withJSONObject: txnDict)
                let transaction = try JSONDecoder().decode(TransactionStatus.self, from: txnData)

                // ── STEP 4: If already succeeded, no challenge needed ──
                if transaction.state?.lowercased() == "succeeded" {
                    await MainActor.run { self?.dismiss(animated: true) }
                    return
                }

                // ── STEP 5: Finalize — SDK determines if challenge is required ──
                await MainActor.run {
                    GatewaySpecific3DSIntegration.finalizeTransaction(
                        for: event.token,
                        transaction: transaction
                    )
                }
            }
        }
    }

    // ── ENTRY POINT: Route based on the purchase response state ──
    // PurchaseResponse is YOUR app's model for the backend response — not an SDK type.
    func handlePurchaseResponse(_ response: PurchaseResponse) {
        guard response.errors?.isEmpty ?? true,
              let transaction = response.transaction else { return }
        transactionToken = transaction.token

        // "succeeded" → 3DS not required; "pending" or device_fingerprint
        // required → present the challenge to kick off the 3DS flow.
        let state = transaction.state?.lowercased() ?? ""
        let requiredAction = transaction.scaAuthentication?.requiredAction?.lowercased() ?? ""
        if state == "succeeded" { return }
        if state == "pending" || requiredAction == "device_fingerprint" {
            presentChallenge()
        }
    }

    private func presentChallenge() {
        guard let token = transactionToken else { return }
        // DoChallengeIfNeededViewController handles device fingerprint,
        // polling, trigger, and challenge presentation internally.
        let vc = DoChallengeIfNeededViewController(
            transactionToken: token,
            onDismiss: { [weak self] in self?.dismiss(animated: true) }
        )
        present(vc, animated: true)
    }
}
```

---

## UIKit (Notification + Delegate)

Use `NotificationCenter` to observe `GatewaySpecific3DSTriggerCompletion` and implement `SpreedlyThreeDSChallengeDelegate` for the final outcome.

```swift
final class GatewaySpecific3DSViewController: UIViewController, SpreedlyThreeDSChallengeDelegate {
    private var transactionToken: String?
    private var triggerObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        // ── STEP 1: Set delegate BEFORE presenting the challenge ──
        // The delegate receives the final 3DS outcome via
        // threeDSChallengeDidComplete(_:).
        Spreedly.shared().threeDSChallengeDelegate = self

        // ── STEP 2: Observe the trigger notification ──
        // Fires when device fingerprint is done and the SDK needs your
        // backend to call /complete.json.
        triggerObserver = NotificationCenter.default.addObserver(
            forName: .gatewaySpecific3DSTriggerCompletion,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // The notification carries the transaction token in userInfo.
            // In multi-flow apps, compare this token against the one you're
            // tracking to avoid handling triggers from unrelated flows.
            guard let token = note.userInfo?["transactionToken"] as? String else { return }
            Task {
                // ── STEP 3: Call your backend to invoke /complete.json ──
                let responseData = try await backend.complete(transactionToken: token)

                // Decode the "transaction" key from the /complete.json response.
                let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
                guard let txnDict = json?["transaction"] as? [String: Any] else { return }
                let txnData = try JSONSerialization.data(withJSONObject: txnDict)
                let transaction = try JSONDecoder().decode(TransactionStatus.self, from: txnData)

                // ── STEP 4: If already succeeded, no challenge needed ──
                if transaction.state?.lowercased() == "succeeded" {
                    await MainActor.run { /* Show success, dismiss challenge */ }
                    return
                }

                // ── STEP 5: Finalize — SDK determines if challenge is required ──
                await MainActor.run {
                    GatewaySpecific3DSIntegration.finalizeTransaction(
                        for: token,
                        transaction: transaction
                    )
                }
            }
        }
    }

    deinit {
        if let observer = triggerObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // ── STEP 6: Final 3DS outcome delivered via delegate ──
    func threeDSChallengeDidComplete(_ result: ThreeDSChallengeResult) {
        if result.isSuccess {
            // Authentication succeeded — payment is authorized.
        } else if result.isFailure {
            // Authentication failed or user tapped "Cancel" in the auth
            // session. Check result.error for "3DS challenge canceled by
            // user" to distinguish user cancellation from other failures.
        } else if result.isCanceled {
            // Only emitted when cancelFlow() is called programmatically.
        }
    }
}
```

---

## Objective-C Integration

Set the delegate before presenting. Use `NSNotificationCenter` to observe `GatewaySpecific3DSTriggerCompletion`. When the trigger fires, call your backend to invoke `/complete.json` (your backend calls `POST https://core.spreedly.com/v1/transactions/{token}/complete.json`), then pass the raw response data to `GatewaySpecific3DSObjCBridge.finalizeTransactionForTransactionToken:completeResponseData:error:`.

### Objective-C API Reference

- **`GatewaySpecific3DSObjCBridge.finalizeTransactionForTransactionToken:completeResponseData:error:`** — Finalizes the transaction with raw response data from `/complete.json`. Pass the transaction token and the `NSData` from your backend's complete response. On success, the error pointer is set to `nil`; on failure, it is populated. The final result is delivered via `SpreedlyThreeDSChallengeDelegate` (`threeDSChallengeDidComplete:`).

- **`GatewaySpecific3DSTriggerCompletion`** — The notification name posted when the SDK needs your backend to call `/complete.json`. The `userInfo` dictionary contains `transactionToken` (the transaction token). In Swift, use `Notification.Name.gatewaySpecific3DSTriggerCompletion`; in Objective-C, observe the string `@"GatewaySpecific3DSTriggerCompletion"`.

```objc
@interface GatewaySpecific3DSViewController () <SpreedlyThreeDSChallengeDelegate>
@property (nonatomic, strong) NSString *transactionToken;
@property (nonatomic, strong) id gatewaySpecificTriggerObserver;
@end

@implementation GatewaySpecific3DSViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // ── STEP 1: Set delegate BEFORE presenting the challenge ──
    // The delegate receives the final 3DS outcome via
    // threeDSChallengeDidComplete:.
    [Spreedly shared].threeDSChallengeDelegate = self;

    // ── STEP 2: Observe the trigger notification ──
    // Fires when device fingerprint is done and the SDK needs your
    // backend to call /complete.json.
    __weak typeof(self) weakSelf = self;
    self.gatewaySpecificTriggerObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:@"GatewaySpecific3DSTriggerCompletion"
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
                    // userInfo carries the transaction token. In multi-flow
                    // apps, compare against the token you're tracking.
                    NSString *transactionToken = note.userInfo[@"transactionToken"];
                    if (!transactionToken.length) return;
                    [weakSelf handleGatewaySpecificTriggerWithToken:transactionToken];
                }];
}

- (void)presentChallenge {
    if (!self.transactionToken) return;
    // DoChallengeIfNeededViewController handles device fingerprint,
    // polling, trigger, and challenge presentation internally.
    DoChallengeIfNeededViewController *challengeVC = [[DoChallengeIfNeededViewController alloc]
        initWithTransactionToken:self.transactionToken
        onDismiss:^{
            // Challenge dismissed
        }];
    [self presentViewController:challengeVC animated:YES completion:nil];
}

// ── STEP 3: Trigger received — device fingerprint is done ──
// Call your backend to invoke /complete.json, then hand the response
// back to the SDK via the ObjC bridge.
- (void)handleGatewaySpecificTriggerWithToken:(NSString *)transactionToken {
    [yourBackend completeTransactionWithToken:transactionToken
                                 completion:^(NSData *responseData, NSError *error) {
        if (error) {
            // Handle backend error, dismiss challenge
            return;
        }
        if (!responseData) {
            // Handle empty response
            return;
        }

        // ── STEP 4: Check if the transaction is already terminal ──
        // PurchaseResponse is YOUR app's model — not an SDK type.
        NSError *parseErr = nil;
        PurchaseResponse *completeResponse = [PurchaseResponse fromJSONData:responseData error:&parseErr];
        if (completeResponse.transaction &&
            [[completeResponse.transaction.state lowercaseString] isEqualToString:@"succeeded"]) {
            // No challenge needed — show success and exit the flow.
            return;
        }

        // ── STEP 5: Finalize — pass raw response data to the ObjC bridge ──
        // The bridge decodes TransactionStatus internally and determines
        // whether a user-facing challenge is required.
        NSError *finalizeError = nil;
        [GatewaySpecific3DSObjCBridge finalizeTransactionForTransactionToken:transactionToken
                                                          completeResponseData:responseData
                                                                         error:&finalizeError];
        if (finalizeError) {
            // Handle finalize error
        }
        // Final result delivered via delegate (threeDSChallengeDidComplete:)
    }];
}

- (void)dealloc {
    if (self.gatewaySpecificTriggerObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.gatewaySpecificTriggerObserver];
        self.gatewaySpecificTriggerObserver = nil;
    }
}

// ── STEP 6: Final 3DS outcome delivered via delegate ──
- (void)threeDSChallengeDidComplete:(ThreeDSChallengeResult *)result {
    if (result.isSuccess) {
        // Authentication succeeded — payment is authorized.
    } else if (result.isFailure) {
        // Authentication failed or user tapped "Cancel" in the auth
        // session. Check result.error for details.
    } else if (result.isCanceled) {
        // Only emitted when cancelFlow: is called programmatically.
    }
}

@end
```

---

## Device Fingerprint Polling

The SDK polls `status.json` every 2 seconds for up to approximately 20 seconds (10 attempts). If it times out or receives a Worldpay postMessage, it emits `GatewaySpecific3DSTriggerCompletion` so you can call `/complete.json` on your backend.

---

## Result Handling

- `/complete.json` returns a `transaction.state`. If it is `succeeded`, you can show success immediately and exit the flow.
- For any other state (`pending`, `failed`, etc.), call `GatewaySpecific3DSIntegration.finalizeTransaction(for:transaction:)` so the SDK can emit `ThreeDSChallengeResult`.
- Always handle all `ThreeDSChallengeResult` outcomes in your subscriber: `isSuccess`, `isFailure`, `isCanceled`.
- In `subscribeToThreeDSChallengeResults`, explicitly branch on `isSuccess`/`isFailure`/`isCanceled` so you know where to show success, show errors, or treat user cancel.
- **Auth session cancellation:** If the user taps "Cancel" in the authentication session during the challenge, the SDK emits `isFailure` (not `isCanceled`) with an error message containing `"3DS challenge canceled by user"`. Check for this string in your `isFailure` handler if you want to distinguish user cancellation from other failures.
- `isCanceled` is emitted only when `GatewaySpecific3DSIntegration.cancelFlow(for:)` is called programmatically.
- If the error message contains `"Forced Failure"` (case-insensitive), use your normal error handling to decide what to display to the user.

---

## Deprecated APIs

### `getChallengeContainerView(for:)` — DEPRECATED

> **Deprecated:** This method always returns `nil` and should not be used.

`GatewaySpecific3DSIntegration.getChallengeContainerView(for:)` previously returned the `WKWebView` used for the challenge. Since the challenge is now presented via `ASWebAuthenticationSession`, this method **always returns `nil`**.

If your code calls `getChallengeContainerView`, you can safely remove those calls. No replacement is needed — the SDK manages the auth session presentation and dismissal automatically.

---

### Blocked Devices

> **Important:** When `blockJailbrokenDevices` is enabled and the device is compromised, the SDK blocks 3DS challenge flows automatically. `DoChallengeIfNeeded` auto-dismisses and emits a failure result. See [Security — Runtime Integrity](security.md#runtime-integrity) for details.

## Troubleshooting

**Trigger never fires**

- Ensure you subscribed to `subscribeToGatewaySpecific3DSTriggerCompletion` (or the notification) before presenting `DoChallengeIfNeeded`.
- Verify your gateway is configured for gateway-specific 3DS (e.g. Worldpay).
- Check that the device fingerprint step completes; the trigger fires after polling timeout or when the gateway posts completion.

**Final result not received**

- Ensure `SpreedlyThreeDSChallengeDelegate` is set (Objective-C) or you are subscribed to `subscribeToThreeDSChallengeResults` (Swift) before presenting the challenge.
- Do not cancel the subscription in `onDisappear` while the challenge is still active. `ASWebAuthenticationSession` is presented on top of your `DoChallengeIfNeeded` view, which can trigger `onDisappear` events on the underlying view. Canceling the subscription at that point will prevent you from receiving the final result.

**User taps "Cancel" in the auth session**

- This is treated as a failure. The SDK emits `ThreeDSChallengeResult` with `isFailure == true` and an error containing `"3DS challenge canceled by user"`.
- Ensure your `isFailure` handler accounts for this scenario (e.g. showing "Payment canceled" instead of a generic error).

**Backend /complete.json errors**

- Verify your backend calls the correct Spreedly `/complete.json` endpoint with the transaction token.
- Ensure the backend returns the full response; `finalizeTransaction` (or `GatewaySpecific3DSObjCBridge`) needs the raw response data.

**Multiple subscriptions**

- Only one active subscription per event type should exist. Cancel previous subscriptions when navigating away or when the flow completes.

**Multi-flow token filtering**

- In apps that may have multiple concurrent 3DS flows, filter `GatewaySpecific3DSTriggerCompletion` notifications by `transactionToken` to avoid handling triggers from unrelated flows. Compare `event.token` (Combine) or `note.userInfo[@"transactionToken"]` (NotificationCenter) against the token you are currently tracking.

---

## Related Documentation

- [3ds-global.md](3ds-global.md) - Global 3DS (Forter) flow and full comparison table
- [error-handling.md](error-handling.md) - Error types and handling patterns
- [3DS_GATEWAY_SPECIFIC_FLOW.md](../development/3DS_GATEWAY_SPECIFIC_FLOW.md) – Detailed flow diagrams for gateway-specific 3DS including device fingerprint, trigger/finalize, challenge lifecycle, and decision flows
