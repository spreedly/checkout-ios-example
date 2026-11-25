//
//  ApplePayDemoComponents.swift
//  SpreedlySDKExample
//
//  Small pieces shared by the Apple Pay demo screens: the result line under a button, and a
//  button that opens the card drop-in with Apple Pay on top.
//

// SpreedlyApplePay ships through Swift Package Manager only, so CocoaPods builds skip this demo.
#if canImport(SpreedlyApplePay)

import Combine
import SpreedlyApplePay
import SpreedlyCore
import SpreedlyUI
import SwiftUI

/// Last Apple Pay result, read from `subscribeToPaymentResults` while the screen is visible.
struct ApplePayResultStatus: View {
    let identifier: String
    /// Extra text after the token on success, e.g. the order ID sent as metadata.
    /// Read when the result arrives, so it reflects the screen's current settings.
    var successDetail: () -> String? = { nil }
    /// Called on success.
    var onSuccess: (() -> Void)?

    @State private var text: String?
    @State private var isError = false
    @State private var isPending = false
    /// New on every appearance, so the spinner restarts after its List row scrolls back on screen.
    @State private var spinnerID = UUID()
    @State private var token: String?
    @State private var tokenDetail: String?
    @State private var isTokenVisible = false
    @State private var cancellable: AnyCancellable?

    var body: some View {
        ZStack(alignment: .leading) {
            Color.clear.frame(height: 0)
            if let token {
                tokenRow(token)
            } else if let text {
                HStack(spacing: 8) {
                    if isPending {
                        ProgressView()
                            .controlSize(.small)
                            .id(spinnerID)
                    }
                    Text(text)
                        .font(.footnote)
                        .foregroundColor(isError ? .red : (isPending ? .secondary : .green))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(identifier)
                .onAppear { spinnerID = UUID() }
            }
        }
        .onAppear(perform: subscribe)
        .onDisappear { cancellable?.cancel() }
    }

    private func tokenRow(_ token: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Success. Token \(isTokenVisible ? token : Spreedly.maskedToken(token))"
                + (tokenDetail.map { " · \($0)" } ?? ""))
                .font(.footnote)
                .foregroundColor(.green)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityIdentifier(identifier)
            Button {
                isTokenVisible.toggle()
            } label: {
                Label(isTokenVisible ? "Hide token" : "Show token",
                      systemImage: isTokenVisible ? "eye.slash" : "eye")
            }
            .accessibilityHint(isTokenVisible ? "Masks the payment method token" : "Shows the full payment method token")
            .accessibilityIdentifier("\(identifier)ToggleToken")
            .font(.footnote)
            .buttonStyle(.borderless)
        }
    }

    private func subscribe() {
        cancellable = Spreedly.shared().subscribeToPaymentResults { result in
            isPending = result.isPending
            if result.isSuccess, let resultToken = result.token, !resultToken.isEmpty {
                token = resultToken
                tokenDetail = successDetail()
                isTokenVisible = false
                text = nil
                isError = false
                onSuccess?()
                return
            }
            token = nil
            if result.isPending {
                text = "Your payment is still being processed. Please don't pay again."
                isError = false
            } else if result.isSuccess {
                text = "Success" + (successDetail().map { " · \($0)" } ?? "")
                isError = false
                onSuccess?()
            } else if result.isCanceled {
                text = nil
            } else if result.isStatusUnknown {
                text = "Payment not confirmed. Check the order before paying again."
                isError = true
            } else if result.isFailure {
                text = result.failureDetails?.message ?? "Payment failed"
                isError = true
            }
        }
    }
}

/// Opens `CardFormDropIn` with Apple Pay above the card fields, built from `settings`.
struct ApplePayDropInLauncher: View {
    @ObservedObject var settings: ApplePayDemoSettings
    let mode: ApplePayDemoMode
    let identifier: String

    @State private var isPresented = false

    var body: some View {
        Button {
            Task {
                // Signed auth for the card fields; Apple Pay gets its own for every attempt.
                _ = await ApplePayDemoSettings.refreshAuth()
                isPresented = true
            }
        } label: {
            Label("Open Checkout Sheet", systemImage: "creditcard")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityHint("Opens the card checkout sheet with Apple Pay above the card fields")
        .accessibilityIdentifier(identifier)
        .sheet(isPresented: $isPresented) {
            CardFormDropIn(
                walletButtons: [settings.makeWallet(mode: mode)],
                walletButtonDividerText: settings.dividerText.isEmpty ? nil : settings.dividerText
            )
        }
    }
}

/// Title on the left, editable value on the right.
struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    let identifier: String
    var keyboard: UIKeyboardType = .default
    /// Called with `true` when editing starts and `false` when it ends (Done, or leaving the field).
    var onEditingChanged: ((Bool) -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .frame(maxWidth: 160)
                .focused($isFocused)
                .onChange(of: isFocused) { focused in onEditingChanged?(focused) }
                .accessibilityIdentifier(identifier)
        }
    }
}

// MARK: - Keyboard

extension View {
    /// Lets the shopper put the keyboard away on an Apple Pay demo screen: a Done button above the
    /// keyboard (number pads have no return key), a tap outside any text field, or dragging the list.
    /// Apply once, on the screen's root view.
    func applePayDemoKeyboardDismissal() -> some View {
        modifier(ApplePayKeyboardDismissal())
    }
}

private struct ApplePayKeyboardDismissal: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .background(TapOutsideTextFieldDismissesKeyboard())
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                        )
                    }
                    .accessibilityHint("Hides the keyboard")
                    .accessibilityIdentifier("applePayKeyboardDone")
                }
            }
    }
}

/// A window-level tap recognizer that ends editing when the tap lands outside a text field. It
/// doesn't cancel the tap, so buttons, toggles and links still work on the same tap.
private struct TapOutsideTextFieldDismissesKeyboard: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async { [weak view] in context.coordinator.attach(to: view?.window) }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?
        private lazy var recognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func attach(to window: UIWindow?) {
            guard let window, self.window !== window else { return }
            detach()
            window.addGestureRecognizer(recognizer)
            self.window = window
        }

        func detach() {
            window?.removeGestureRecognizer(recognizer)
            window = nil
        }

        @objc private func tapped() {
            window?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

#endif
