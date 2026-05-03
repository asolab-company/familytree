import Foundation

enum AppConfiguration {
    enum App {
        static let appStoreURL = URL(string: "https://apps.apple.com/app/id6766037794")!
        static let shareMessage = "I’m exploring my family history with Heritage. Build your family tree and uncover the stories behind your roots."
    }

    enum StoreKit {
        static let premiumProductID = "com.yourcompany.heritage.premium.weekly"
        static let premiumProductIDs: Set<String> = [premiumProductID]
    }

    enum Legal {
        static let privacyPolicyURL = URL(string: "https://sites.google.com/view/origino-ai/privacy-policy")!
        static let termsOfUseURL = URL(string: "https://sites.google.com/view/origino-ai/terms-of-use")!
    }

}
