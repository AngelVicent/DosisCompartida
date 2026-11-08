import SwiftUI

@main
struct CuidadoFamiliarApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            if app.cuidador == nil {
                LoginView()
                    .environmentObject(app)
            } else {
                MainTabView()
                    .environmentObject(app)
            }
        }
    }
}
