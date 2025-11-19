import SwiftUI
import AppnomixCommerce

@main
struct Demo_SwiftUIApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var onboardingEvent: OnboardingEvent? = .unknown
    
    var body: some Scene {
        WindowGroup {
            if !AppnomixCSDK.isOnboardingAvailable() || onboardingEvent == .onboardingDropout || onboardingEvent == .onboardingCompleted {
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
        AppnomixCSDK.initialize(
            clientId: "YOUR_CLIENT_ID", // ask Appnomix
            authToken: "YOUR_AUTH_TOKEN", // ask Appnomix
            appGroupName: "group.app.appnomix.demo-swiftui", // e.g., group.com.mycompany.myapp
            options: .init(
                appURLScheme: "appnomix-demo-swiftui://", // e.g., my-app-url://
                language: "en"
            )
        )
        AppnomixCSDK.trackOfferDisplay(context: "app_start")
        
        return true
    }
}

