import Foundation
import SwiftUI

// Estado global de la app: sesión, configuración y datos de la pantalla.
//
// Dos modos:
//  - Demostración: datos de ejemplo guardados en el teléfono (Persistencia.swift).
//  - Servidor: todo se lee y se escribe en la API (carpeta backend/), así que los
//    cuidadores comparten las dosis, el historial y el inventario.
@MainActor
final class AppState: ObservableObject {

    // Configuración guardada en el teléfono
    @Published var demoMode: Bool {
        didSet {
            UserDefaults.standard.set(demoMode, forKey: "demoMode")
            if oldValue != demoMode { cambioDeModo(eraDemo: oldValue) }
        }
    }
    @Published var recordatorios: Bool {
        didSet {
            UserDefaults.standard.set(recordatorios, forKey: "recordatorios")
            Task { await reprogramarRecordatorios() }
        }
    }
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    // Sesión
    @Published private(set) var cuidador: Cuidador?
    @Published private(set) var accessToken: String?
    @Published private(set) var errorLogin: String?
    @Published private(set) var cargando = false
    @Published private(set) var restaurandoSesion = false
    private var refreshToken: String?
    private var refrescoEnCurso: Task<String, Error>?

    // Error al cargar datos del servidor (se muestra con un botón de reintentar)
    @Published private(set) var errorDatos: String?

    // Datos de las pantallas
    @Published private(set) var paciente: Paciente = DemoData.paciente
    // En modo demostración cada cambio se guarda en el teléfono (ver Persistencia.swift).
    @Published private(set) var dosis: [Dosis] = DemoData.dosisDeHoy() {
        didSet { guardar() }
    }
    @Published private(set) var inventario: [ItemInventario] = DemoData.inventario {
        didSet { guardar() }
    }
    @Published private(set) var notas: [NotaVoz] = DemoData.notas {
        didSet { guardar() }
    }
    @Published private(set) var historial: [RegistroDosis] = DemoData.historialDemo() {
        didSet { guardar() }
    }

    private var diaDosis = Calendar.current.startOfDay(for: Date())
    private var restaurando = false

    init() {
        let defaults = UserDefaults.standard
        self.demoMode = defaults.object(forKey: "demoMode") as? Bool ?? true
        self.serverURL = defaults.string(forKey: "serverURL") ?? "http://localhost:3000"
        self.recordatorios = defaults.object(forKey: "recordatorios") as? Bool ?? true
        NotificationManager.shared.configurar()

        if demoMode {
            restaurarDatosGuardados()
        } else {
            vaciarDatos()
            // Si quedó una sesión guardada, se intenta recuperar sin pedir la contraseña.
            if let guardado = KeychainStore.leer() {
                restaurandoSesion = true
                Task { await restaurarSesion(refreshToken: guardado) }
            }
        }
    }

    // MARK: Persistencia local (modo demostración)

    private func guardar() {
        guard demoMode, !restaurando else { return }
        Persistencia.guardar(DatosGuardados(
            diaDosis: diaDosis,
            dosis: dosis,
            inventario: inventario,
            notas: notas,
            historial: historial
        ))
    }

    // Recupera lo guardado. Las dosis son del día: si ya es otro día, se genera la lista nueva
    // (todas pendientes) pero se conservan el historial, el inventario y las notas.
    private func restaurarDatosGuardados() {
        guard let datos = Persistencia.cargar() else { return }
        restaurando = true
        inventario = datos.inventario
        notas = datos.notas
        historial = datos.historial
        if Calendar.current.isDateInToday(datos.diaDosis) {
            dosis = datos.dosis
        }
        restaurando = false
        guardar()
    }

    // Vuelve a los datos de ejemplo (para repetir la demostración).
    func restablecerDatosDemo() {
        guard demoMode else { return }
        diaDosis = Calendar.current.startOfDay(for: Date())
        restaurando = true
        dosis = DemoData.dosisDeHoy()
        inventario = DemoData.inventario
        notas = DemoData.notas
        historial = DemoData.historialDemo()
        restaurando = false
        try? FileManager.default.removeItem(at: carpetaNotas())   // audios grabados en la demo
        guardar()
        Task { await reprogramarRecordatorios() }
    }

    private func vaciarDatos() {
        restaurando = true
        paciente = .vacio
        dosis = []
        inventario = []
        notas = []
        historial = []
        restaurando = false
    }

    // Al activar o desactivar el modo demostración se cierra la sesión y se cambian los datos.
    private func cambioDeModo(eraDemo: Bool) {
        if !eraDemo { cerrarSesionRemota() }
        limpiarSesionLocal()
        errorDatos = nil

        if demoMode {
            restaurando = true
            paciente = DemoData.paciente
            dosis = DemoData.dosisDeHoy()
            inventario = DemoData.inventario
            notas = DemoData.notas
            historial = DemoData.historialDemo()
            restaurando = false
            restaurarDatosGuardados()
        } else {
            vaciarDatos()
        }
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
                await reprogramarRecordatorios()
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
            establecerSesion(respuesta)
            await recargar()
        } catch let error as APIError {
            errorLogin = error.mensaje
        } catch {
            errorLogin = "Ocurrió un error inesperado."
        }
    }

    func cerrarSesion() {
        if !demoMode { cerrarSesionRemota() }
        limpiarSesionLocal()
        if !demoMode { vaciarDatos() }
    }

    private func establecerSesion(_ respuesta: LoginResponse) {
        accessToken = respuesta.accessToken
        refreshToken = respuesta.refreshToken
        cuidador = respuesta.cuidador
        KeychainStore.guardar(respuesta.refreshToken)
    }

    private func limpiarSesionLocal() {
        NotificationManager.shared.cancelarTodo()
        KeychainStore.borrar()
        cuidador = nil
        accessToken = nil
        refreshToken = nil
        errorLogin = nil
    }

    // Avisa al servidor para que invalide las sesiones. Si el token de acceso ya expiró,
    // primero se renueva para que el cierre de sesión sea efectivo.
    private func cerrarSesionRemota() {
        guard let token = accessToken else { return }
        let refresh = refreshToken
        let url = serverURL
        Task {
            var tokenVigente = token
            if let refresh,
               let nueva = try? await APIClient().refrescar(baseURL: url, refreshToken: refresh) {
                tokenVigente = nueva.accessToken
            }
            await APIClient().logout(baseURL: url, token: tokenVigente)
        }
    }

    // Intenta entrar con la sesión guardada en el Keychain al abrir la app.
    private func restaurarSesion(refreshToken guardado: String) async {
        defer { restaurandoSesion = false }
        do {
            let respuesta = try await APIClient().refrescar(baseURL: serverURL, refreshToken: guardado)
            establecerSesion(respuesta)
            await recargar()
        } catch let error as APIError {
            if case .red = error {
                errorLogin = "No se pudo reconectar con el servidor. Inicia sesión cuando haya conexión."
            } else {
                KeychainStore.borrar()
            }
        } catch {
            KeychainStore.borrar()
        }
    }

    // MARK: Llamadas a la API

    // Ejecuta una petición con el token actual. Si el servidor responde 401, renueva el token
    // una sola vez y reintenta.
    private func conSesion<T: Sendable>(_ operacion: (String) async throws -> T) async throws -> T {
        guard let token = accessToken else { throw APIError.noAutorizado }
        do {
            return try await operacion(token)
        } catch APIError.noAutorizado {
            let nuevo = try await refrescarSesion()
            return try await operacion(nuevo)
        }
    }

    // Si varias peticiones expiran a la vez, comparten una sola renovación
    // (el refreshToken se invalida al usarse).
    private func refrescarSesion() async throws -> String {
        if let tarea = refrescoEnCurso { return try await tarea.value }
        let tarea = Task { try await self.renovarTokens() }
        refrescoEnCurso = tarea
        defer { refrescoEnCurso = nil }
        return try await tarea.value
    }

    private func renovarTokens() async throws -> String {
        let mensaje = "Tu sesión expiró. Inicia sesión de nuevo."
        guard let refresh = refreshToken else {
            limpiarSesionLocal()
            vaciarDatos()
            errorLogin = mensaje
            throw APIError.noAutorizado
        }
        do {
            let respuesta = try await APIClient().refrescar(baseURL: serverURL, refreshToken: refresh)
            establecerSesion(respuesta)
            return respuesta.accessToken
        } catch let error as APIError {
            if case .red = error { throw error }
            limpiarSesionLocal()
            vaciarDatos()
            errorLogin = mensaje
            throw APIError.noAutorizado
        }
    }

    private func obtener<T: Decodable & Sendable>(_ ruta: String) async throws -> T {
        let url = serverURL
        return try await conSesion { token in
            try await APIClient().get(baseURL: url, ruta: ruta, token: token)
        }
    }

    private func publicar<T: Decodable & Sendable>(_ ruta: String, cuerpo: [String: Any]? = nil) async throws -> T {
        let url = serverURL
        return try await conSesion { token in
            try await APIClient().post(baseURL: url, ruta: ruta, token: token, cuerpo: cuerpo)
        }
    }

    private func mensaje(de error: Error) -> String {
        (error as? APIError)?.mensaje ?? "Ocurrió un error inesperado."
    }

    // Vuelve a pedir al servidor todos los datos (así se ve lo que registraron otros cuidadores).
    func recargar() async {
        guard !demoMode, cuidador != nil else { return }
        do {
            let nuevoPaciente: Paciente = try await obtener("/api/paciente")
            let nuevasDosis: [Dosis] = try await obtener("/api/dosis")
            let nuevoInventario: [ItemInventario] = try await obtener("/api/inventario")
            let nuevoHistorial: [RegistroDosis] = try await obtener("/api/historial?dias=60")
            let nuevasNotas: [NotaRemota] = try await obtener("/api/notas")

            paciente = nuevoPaciente
            dosis = nuevasDosis
            inventario = nuevoInventario
            historial = nuevoHistorial
            notas = nuevasNotas.map { $0.comoNota }
            errorDatos = nil
            await reprogramarRecordatorios()
        } catch APIError.noAutorizado {
            // La sesión ya se cerró y la pantalla de inicio muestra el motivo.
        } catch {
            errorDatos = mensaje(de: error)
        }
    }

    private func recargarHistorial() async {
        if let nuevo: [RegistroDosis] = try? await obtener("/api/historial?dias=60") {
            historial = nuevo
        }
    }

    // MARK: Dosis

    // Devuelve nil si todo salió bien, o el mensaje de error.
    func registrarDosis(_ id: UUID, verificacion: String = "omitida") async -> String? {
        if demoMode { return registrarDosisLocal(id, verificacion: verificacion) }

        do {
            let resultado: ResultadoAdministrar = try await publicar(
                "/api/dosis/\(id.uuidString)/administrar",
                cuerpo: ["verificacion": verificacion]
            )
            if let i = dosis.firstIndex(where: { $0.id == resultado.dosis.id }) {
                dosis[i] = resultado.dosis
            }
            reemplazar(resultado.inventario)
            NotificationManager.shared.cancelar(dosis: id)
            await recargarHistorial()
            return nil
        } catch {
            // Por ejemplo, otro cuidador ya la registró: se actualiza la pantalla.
            await recargar()
            return mensaje(de: error)
        }
    }

    private func registrarDosisLocal(_ id: UUID, verificacion: String) -> String? {
        guard let i = dosis.firstIndex(where: { $0.id == id }) else { return "La dosis no existe." }
        guard dosis[i].estado == .pendiente else { return "Esta dosis ya fue registrada." }
        dosis[i].estado = .administrada
        NotificationManager.shared.cancelar(dosis: id)
        dosis[i].registradaPor = cuidador?.nombre
        dosis[i].horaRegistro = horaActual()

        // Cada administración queda en el historial compartido.
        historial.insert(
            RegistroDosis(id: UUID(), fecha: Date(),
                          medicamento: dosis[i].medicamento,
                          indicacion: dosis[i].indicacion,
                          horaProgramada: dosis[i].hora,
                          cuidador: cuidador?.nombre ?? "Desconocido",
                          verificacion: verificacion),
            at: 0
        )

        // La pastilla administrada sale del inventario.
        descontarInventario(medicamento: dosis[i].medicamento, unidades: dosis[i].unidades)
        return nil
    }

    // MARK: Recordatorios

    // Programa los avisos de las dosis pendientes (o los cancela si están apagados).
    func reprogramarRecordatorios() async {
        let manager = NotificationManager.shared
        guard recordatorios, cuidador != nil else {
            manager.cancelarTodo()
            return
        }
        guard await manager.pedirPermiso() else { return }
        await manager.programar(dosis: dosis, paciente: paciente.nombre)
    }

    func enviarRecordatorioDePrueba() async {
        await NotificationManager.shared.enviarPrueba()
    }

    // MARK: Inventario

    func enviarAFarmacia(_ id: UUID) async {
        if demoMode {
            guard let i = inventario.firstIndex(where: { $0.id == id }) else { return }
            inventario[i].enviadoAFarmacia = true
            return
        }
        do {
            let item: ItemInventario = try await publicar("/api/inventario/\(id.uuidString)/enviar-farmacia")
            reemplazar(item)
            errorDatos = nil
        } catch APIError.noAutorizado {
            // La sesión ya se cerró.
        } catch {
            errorDatos = mensaje(de: error)
        }
    }

    // Suma existencias cuando llega el pedido. Devuelve nil si salió bien, o el mensaje de error.
    func reponer(_ id: UUID, cantidad: Int) async -> String? {
        if demoMode {
            guard let i = inventario.firstIndex(where: { $0.id == id }) else { return "El medicamento no existe." }
            inventario[i].cantidad += cantidad
            if inventario[i].cantidad >= inventario[i].umbral {
                inventario[i].enviadoAFarmacia = false
            }
            return nil
        }
        do {
            let item: ItemInventario = try await publicar(
                "/api/inventario/\(id.uuidString)/reposicion",
                cuerpo: ["cantidad": cantidad]
            )
            reemplazar(item)
            return nil
        } catch {
            return mensaje(de: error)
        }
    }

    private func reemplazar(_ item: ItemInventario) {
        if let j = inventario.firstIndex(where: { $0.id == item.id }) {
            inventario[j] = item
        }
    }

    private func descontarInventario(medicamento: String, unidades: Int) {
        guard let j = inventario.firstIndex(where: { $0.nombre == medicamento }) else { return }
        inventario[j].cantidad = max(0, inventario[j].cantidad - unidades)
    }

    func inventarioDe(_ medicamento: String) -> ItemInventario? {
        inventario.first { $0.nombre == medicamento }
    }

    // MARK: Notas de voz

    // Carpeta donde el modo demostración guarda los audios grabados.
    private func carpetaNotas() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let carpeta = base.appendingPathComponent("NotasVoz", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        return carpeta
    }

    func formatoDuracion(_ segundos: Int) -> String {
        String(format: "%d:%02d", segundos / 60, segundos % 60)
    }

    // Guarda la nota grabada (en el teléfono en modo demostración, en el servidor en modo servidor).
    // Devuelve nil si salió bien, o el mensaje de error. Si falla, la grabación se conserva para reintentar.
    func guardarNota(desde archivo: URL, segundos: Int) async -> String? {
        if demoMode {
            let nombre = "\(UUID().uuidString).m4a"
            do {
                try FileManager.default.copyItem(at: archivo, to: carpetaNotas().appendingPathComponent(nombre))
            } catch {
                return "No se pudo guardar la nota."
            }
            try? FileManager.default.removeItem(at: archivo)
            notas.insert(
                NotaVoz(id: UUID(), fecha: "Hoy \(horaActual())",
                        autor: cuidador?.nombre ?? "Desconocido",
                        duracion: formatoDuracion(segundos), archivo: nombre),
                at: 0
            )
            return nil
        }

        guard let audio = try? Data(contentsOf: archivo) else { return "No se pudo leer la grabación." }
        let url = serverURL
        do {
            let nueva: NotaRemota = try await conSesion { token in
                try await APIClient().subirAudio(baseURL: url, token: token, audio: audio, segundos: segundos)
            }
            notas.insert(nueva.comoNota, at: 0)
            try? FileManager.default.removeItem(at: archivo)
            return nil
        } catch {
            return mensaje(de: error)
        }
    }

    // Devuelve el audio de una nota para reproducirlo.
    func audioDeNota(_ nota: NotaVoz) async throws -> Data {
        if demoMode {
            guard let nombre = nota.archivo,
                  let datos = try? Data(contentsOf: carpetaNotas().appendingPathComponent(nombre)) else {
                throw APIError.servidor("Esta nota de ejemplo no tiene audio.")
            }
            return datos
        }
        let url = serverURL
        let ruta = "/api/notas/\(nota.id.uuidString)/audio"
        return try await conSesion { token in
            try await APIClient().descargar(baseURL: url, ruta: ruta, token: token)
        }
    }

    // MARK: Utilidades

    func horaActual() -> String {
        let formato = DateFormatter()
        formato.dateFormat = "HH:mm"
        return formato.string(from: Date())
    }
}
