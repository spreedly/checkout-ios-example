import SwiftUI
import SpreedlyCore
import SpreedlyUI
#if canImport(SpreedlyBraintree)
import SpreedlyBraintree
#endif

@main
struct MerchantExampleSPMApp: App {

    init() {
        SpreedlyConfigManager.setup()
    }

    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .screenPrevention()
                .onOpenURL { url in
                    #if canImport(SpreedlyBraintree)
                    if BraintreeURLHandler.handleOpen(url: url) { return }
                    #endif
                    let handled = Spreedly.shared().handleOffsiteReturn(url: url)
                    if !handled {
                        // Handle other custom URL navigations
                    }
                }
        }
    }
}
