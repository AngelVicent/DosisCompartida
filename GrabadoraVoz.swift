import Foundation
import AVFoundation

// MARK: - Grabadora: graba una nota de voz en un archivo .m4a (AAC, mono, ligero)

@MainActor
final class GrabadoraVoz: ObservableObject {

    enum Estado: Equatable {
        case reposo
        case grabando
        case grabado(URL, Int)      // archivo temporal y duración en segundos
    }

    @Published private(set) var estado: Estado = .reposo
    @Published private(set) var segundos = 0
    @Published var error: String?

    // Límite de una nota (el servidor acepta hasta 10 MB; a esta calidad son unos 4 MB).
    static let maxSegundos = 180

    private var grabador: AVAudioRecorder?
    private var temporizador: Timer?

    func empezar() async {
        error = nil
        guard await permisoMicrofono() else {
            error = "Activa el micrófono para Dosis Compartida en Ajustes del iPhone."
            return
        }

        do {
            let sesion = AVAudioSession.sharedInstance()
            try sesion.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try sesion.setActive(true)

            let archivo = FileManager.default.temporaryDirectory
                .appendingPathComponent("nota-\(UUID().uuidString).m4a")
            let ajustes: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 22050,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]

            let nuevo = try AVAudioRecorder(url: archivo, settings: ajustes)
            guard nuevo.record() else {
                self.error = "No se pudo iniciar la grabación."
                return
            }
            grabador = nuevo
            segundos = 0
            estado = .grabando
            temporizador = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.actualizarTiempo() }
            }
        } catch {
            self.error = "No se pudo iniciar la grabación."
        }
    }

    func detener() {
        guard let actual = grabador else { return }
        let duracion = max(1, Int(actual.currentTime.rounded(.up)))   // se lee antes de detener
        actual.stop()
        temporizador?.invalidate()
        temporizador = nil
        grabador = nil
        segundos = duracion
        estado = .grabado(actual.url, duracion)
    }

    // Tira la grabación y vuelve al inicio.
    func descartar() {
        if case .grabado(let archivo, _) = estado {
            try? FileManager.default.removeItem(at: archivo)
        }
        estado = .reposo
        segundos = 0
        error = nil
    }

    private func actualizarTiempo() {
        guard let actual = grabador else { return }
        segundos = Int(actual.currentTime)
        if segundos >= GrabadoraVoz.maxSegundos {
            detener()
        }
    }

    private func permisoMicrofono() async -> Bool {
        await withCheckedContinuation { continuacion in
            AVAudioSession.sharedInstance().requestRecordPermission { concedido in
                continuacion.resume(returning: concedido)
            }
        }
    }
}

// MARK: - Reproductor: baja (o lee) el audio de una nota y lo reproduce

@MainActor
final class ReproductorNotas: NSObject, ObservableObject, AVAudioPlayerDelegate {

    @Published private(set) var sonando: UUID?
    @Published private(set) var cargando: UUID?
    @Published var error: String?

    private var reproductor: AVAudioPlayer?

    // Si la nota ya está sonando, la detiene; si no, la reproduce.
    func alternar(_ nota: NotaVoz, app: AppState) async {
        if sonando == nota.id {
            detener()
            return
        }
        detener()
        error = nil
        cargando = nota.id
        defer { cargando = nil }

        do {
            let datos = try await app.audioDeNota(nota)

            let sesion = AVAudioSession.sharedInstance()
            try sesion.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try sesion.setActive(true)

            let nuevo = try AVAudioPlayer(data: datos)
            nuevo.delegate = self
            guard nuevo.play() else {
                self.error = "No se pudo reproducir esta nota."
                return
            }
            reproductor = nuevo
            sonando = nota.id
        } catch {
            self.error = (error as? APIError)?.mensaje ?? "No se pudo reproducir esta nota."
        }
    }

    func detener() {
        reproductor?.stop()
        reproductor = nil
        sonando = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.reproductor = nil
            self.sonando = nil
        }
    }
}
