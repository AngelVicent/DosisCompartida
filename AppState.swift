import Foundation
import SwiftUI

// Estado global de la app: sesión, configuración y datos de la pantalla.
@MainActor
final class AppState: ObservableObject {

    // Configuración guardada en el teléfono
    @Published var demoMode: Bool {
        didSet { UserDefaults.standard.set(demoMode, forKey: "demoMode") }
    }
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    // Sesión
    @Published private(set) var cuidador: Cuidador?
    @Published private(set) var accessToken: String?
    @Published private(set) var errorLogin: String?
    @Published private(set) var cargando = false

    // Datos de las pantallas
    let paciente = DemoData.paciente
    @Published private(set) var dosis: [Dosis] = DemoData.dosisDeHoy()
    @Published private(set) var inventario: [ItemInventario] = DemoData.inventario
    @Published private(set) var notas: [NotaVoz] = DemoData.notas

    init() {
        let defaults = UserDefaults.standard
        self.demoMode = defaults.object(forKey: "demoMode") as? Bool ?? true
        self.serverURL = defaults.string(forKey: "serverURL") ?? "http://localhost:3000"
    }

    // MARK: Sesión

    func iniciarSesion(correo: String, password: String) async {
        errorLogin = nil
        cargando = true
        defer { cargando = false }

        let correoLimpio = correo.trimmingCharacters(in: .whitespaces)

        if demoMode {
            // Pequeña espera para que se vea como una llamada de red real.
            try? await Task.sleep(nanoseconds: 600_000_000)
            if correoLimpio.lowercased() == DemoData.correoDemo && password == DemoData.passwordDemo {
                cuidador = DemoData.cuidadorDemo
            } else {
                errorLogin = "Correo o contraseña incorrectos. En modo demostración usa \(DemoData.correoDemo) / \(DemoData.passwordDemo)."
            }
            return
        }

        do {
            let respuesta = try await APIClient().login(
                baseURL: serverURL,
                correo: correoLimpio,
                password: password
            )
            accessToken = respuesta.accessToken
            cuidador = respuesta.cuidador
        } catch let error as APIError {
            errorLogin = error.mensaje
        } catch {
            errorLogin = "Ocurrió un error inesperado."
        }
    }

    func cerrarSesion() {
        if !demoMode, let token = accessToken {
            let url = serverURL
            Task { await APIClient().logout(baseURL: url, token: token) }
        }
        cuidador = nil
        accessToken = nil
        errorLogin = nil
    }

    // MARK: Dosis

    func registrarDosis(_ id: UUID) {
        guard let i = dosis.firstIndex(where: { $0.id == id }) else { return }
        dosis[i].estado = .administrada
        dosis[i].registradaPor = cuidador?.nombre
        dosis[i].horaRegistro = horaActual()
    }

    // MARK: Inventario

    func enviarAFarmacia(_ id: UUID) {
        guard let i = inventario.firstIndex(where: { $0.id == id }) else { return }
        inventario[i].enviadoAFarmacia = true
    }

    // MARK: Utilidades

    func horaActual() -> String {
        let formato = DateFormatter()
        formato.dateFormat = "HH:mm"
        return formato.string(from: Date())
    }
}
