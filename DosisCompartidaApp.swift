import SwiftUI

@main
struct DosisCompartidaApp: App {
    @StateObject private var app = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if app.restaurandoSesion {
                    ProgressView("Conectando...")
                } else if app.cuidador == nil {
                    LoginView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(app)
            // Al volver a la app se actualizan los datos, para ver lo que registraron otros cuidadores.
            .onChange(of: scenePhase) { fase in
                if fase == .active {
                    Task { await app.recargar() }
                }
            }
        }
    }
}
