import SwiftUI

@main
struct DictatorMDiOSApp: App {
    @StateObject private var store = MobileSharedStore()

    var body: some Scene {
        WindowGroup {
            MobileHomeView(store: store)
        }
    }
}

