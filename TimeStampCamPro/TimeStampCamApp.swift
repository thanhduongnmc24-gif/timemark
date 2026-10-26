import SwiftUI

@main
struct TimeStampCamApp: App {
    @StateObject private var store = WatermarkStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
