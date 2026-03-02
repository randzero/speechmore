import SwiftUI

@main
struct SpeechMoreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window – menu bar only
        SwiftUI.Settings {
            EmptyView()
        }
    }
}
