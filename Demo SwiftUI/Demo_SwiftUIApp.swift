import SwiftUI
import AppnomixCommerce

@main
struct Demo_SwiftUIApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var onboardingEvent: OnboardingEvent? = .unknown
    
    var body: some Scene {
        WindowGroup {
            if onboardingEvent == .onboardingDropout || onboardingEvent == .onboardingCompleted {
                ContentView()
            } else {
                AppnomixOnboardingView(onboardingEvent: $onboardingEvent)
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppnomixCommerceSDK.start(
            clientID: "YOUR_CLIENT_ID", // ask Appnomix
            authToken: "YOUR_AUTH_TOKEN", // ask Appnomix
            appGroupName: "group.app.appnomix.demo-swiftui", // e.g., group.com.mycompany.myapp
            appURLScheme: "appnomix-demo-swiftui://", // e.g., my-app-url://
            requestLocation: true,
            requestTracking: true,
            locale: "en"
        )
        AnalyticsFacade().trackOfferDisplay(context: "app_start")
        
        return true
    }
}

