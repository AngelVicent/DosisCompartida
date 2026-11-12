import Foundation
import UserNotifications

// Recordatorios locales de dosis (no necesitan servidor).
// - Un aviso a la hora programada.
// - Otro aviso si, pasada la tolerancia, la dosis sigue pendiente.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationManager()
    private let centro = UNUserNotificationCenter.current()

    // Llamar una vez al iniciar: permite mostrar el aviso aunque la app esté abierta.
    func configurar() {
        centro.delegate = self
    }

    func pedirPermiso() async -> Bool {
        (try? await centro.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // Borra lo programado y vuelve a programar solo las dosis pendientes que aún no pasan.
    func programar(dosis: [Dosis], paciente: String) async {
        centro.removeAllPendingNotificationRequests()

        for dosis in dosis where dosis.estado == .pendiente {
            guard let fecha = dosis.fechaProgramada else { continue }

            await agregar(
                id: idHora(dosis.id),
                titulo: "Hora de la dosis",
                cuerpo: "\(paciente): \(dosis.medicamento) · \(dosis.indicacion) (\(dosis.hora))",
                fecha: fecha
            )
            await agregar(
                id: idAtraso(dosis.id),
                titulo: "Dosis atrasada",
                cuerpo: "\(dosis.medicamento) de las \(dosis.hora) sigue sin registrarse.",
                fecha: fecha.addingTimeInterval(Double(Dosis.toleranciaMinutos * 60))
            )
        }
    }

    // Al registrar una dosis ya no hay que recordarla.
    func cancelar(dosis id: UUID) {
        centro.removePendingNotificationRequests(withIdentifiers: [idHora(id), idAtraso(id)])
    }

    func cancelarTodo() {
        centro.removeAllPendingNotificationRequests()
    }

    // Aviso de prueba a los 5 segundos, útil para la demostración.
    func enviarPrueba() async {
        guard await pedirPermiso() else { return }
        await agregar(
            id: "prueba-recordatorio",
            titulo: "Hora de la dosis",
            cuerpo: "Prueba: Losartán 50 mg · 1 tableta",
            fecha: Date().addingTimeInterval(5)
        )
    }

    // MARK: Internos

    private func idHora(_ id: UUID) -> String { "dosis-\(id.uuidString)-hora" }
    private func idAtraso(_ id: UUID) -> String { "dosis-\(id.uuidString)-atraso" }

    private func agregar(id: String, titulo: String, cuerpo: String, fecha: Date) async {
        let segundos = fecha.timeIntervalSinceNow
        guard segundos > 1 else { return }   // no se programa lo que ya pasó

        let contenido = UNMutableNotificationContent()
        contenido.title = titulo
        contenido.body = cuerpo
        contenido.sound = .default

        let disparador = UNTimeIntervalNotificationTrigger(timeInterval: segundos, repeats: false)
        let peticion = UNNotificationRequest(identifier: id, content: contenido, trigger: disparador)
        try? await centro.add(peticion)
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
