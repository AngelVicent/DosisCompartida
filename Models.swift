import Foundation

// MARK: - Sesión y API

struct Cuidador: Codable, Identifiable, Equatable {
    let id: String
    let nombre: String
    let correo: String
    let rol: String
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let cuidador: Cuidador
}

struct ErrorResponse: Codable {
    let error: String
}

// MARK: - Datos de la pantalla

struct Paciente: Codable {
    let nombre: String
    let edad: Int
    let padecimientos: String
    let alergias: [String]

    // Marcador mientras se cargan los datos del servidor.
    static let vacio = Paciente(nombre: "", edad: 0, padecimientos: "", alergias: [])
}

enum EstadoDosis: String, Codable {
    case pendiente
    case administrada
}

struct Dosis: Identifiable, Equatable, Codable {
    let id: UUID
    let hora: String
    let medicamento: String
    let indicacion: String
    var estado: EstadoDosis
    var registradaPor: String?
    var horaRegistro: String?

    // Minutos de gracia antes de considerar la dosis atrasada y avisar de nuevo.
    static let toleranciaMinutos = 15

    // Hora programada de hoy como fecha ("07:00" -> hoy a las 07:00).
    var fechaProgramada: Date? {
        let partes = hora.split(separator: ":").compactMap { Int($0) }
        guard partes.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: partes[0], minute: partes[1], second: 0, of: Date())
    }

    // Unidades que se consumen en cada dosis: el primer número de la indicación
    // ("1 tableta" -> 1, "2 tabletas" -> 2). Si no hay número, se asume 1.
    var unidades: Int {
        indicacion.split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
            .first ?? 1
    }

    // Pendiente y ya pasó la hora más la tolerancia.
    func atrasada(ahora: Date = Date()) -> Bool {
        guard estado == .pendiente, let programada = fechaProgramada else { return false }
        return ahora > programada.addingTimeInterval(Double(Dosis.toleranciaMinutos * 60))
    }
}

struct ItemInventario: Identifiable, Equatable, Codable {
    let id: UUID
    let nombre: String
    var cantidad: Int
    let umbral: Int
    var enviadoAFarmacia: Bool = false

    // Está bajo cuando la cantidad cae por debajo del umbral (RF-08).
    var bajo: Bool { cantidad < umbral }
}

// Registro permanente de una dosis administrada (historial compartido entre cuidadores).
struct RegistroDosis: Identifiable, Equatable, Codable {
    let id: UUID
    let fecha: Date
    let medicamento: String
    let indicacion: String
    let horaProgramada: String
    let cuidador: String
    // "coincide", "no_coincide" u "omitida": cómo se verificó la etiqueta antes de dar la dosis.
    var verificacion: String?
}

struct NotaVoz: Identifiable, Codable {
    let id: UUID
    let fecha: String
    let autor: String
    let duracion: String
    // Solo en modo demostración: nombre del archivo de audio guardado en el teléfono.
    // (Las notas del servidor se descargan con su id.)
    var archivo: String?
}

// MARK: - Respuestas del servidor

// Respuesta de POST /api/dosis/:id/administrar
struct ResultadoAdministrar: Decodable {
    let dosis: Dosis
    let inventario: ItemInventario
}

// Las notas llegan con fecha ISO y duración en segundos; la pantalla las muestra como texto.
struct NotaRemota: Decodable {
    let id: UUID
    let fecha: Date
    let autor: String
    let duracionSegundos: Int

    var comoNota: NotaVoz {
        let calendario = Calendar.current
        let hora = DateFormatter()
        hora.dateFormat = "HH:mm"

        let texto: String
        if calendario.isDateInToday(fecha) {
            texto = "Hoy \(hora.string(from: fecha))"
        } else if calendario.isDateInYesterday(fecha) {
            texto = "Ayer \(hora.string(from: fecha))"
        } else {
            let dia = DateFormatter()
            dia.dateFormat = "d/MM HH:mm"
            texto = dia.string(from: fecha)
        }

        let duracion = String(format: "%d:%02d", duracionSegundos / 60, duracionSegundos % 60)
        return NotaVoz(id: id, fecha: texto, autor: autor, duracion: duracion)
    }
}

// MARK: - Datos de demostración

enum DemoData {
    static let correoDemo = "ana@correo.com"
    static let passwordDemo = "demo1234"

    static let cuidadorDemo = Cuidador(
        id: "demo-ana",
        nombre: "Ana Pérez",
        correo: correoDemo,
        rol: "administrador"
    )

    static let paciente = Paciente(
        nombre: "José Morales",
        edad: 78,
        padecimientos: "Hipertensión, diabetes tipo 2",
        alergias: ["Penicilina"]
    )

    static func dosisDeHoy() -> [Dosis] {
        [
            Dosis(id: UUID(), hora: "07:00", medicamento: "Losartán 50 mg",
                  indicacion: "1 tableta", estado: .administrada,
                  registradaPor: "Ana Pérez", horaRegistro: "07:04"),
            Dosis(id: UUID(), hora: "09:00", medicamento: "Losartán 50 mg",
                  indicacion: "1 tableta", estado: .pendiente),
            Dosis(id: UUID(), hora: "13:00", medicamento: "Metformina 850 mg",
                  indicacion: "1 tableta", estado: .pendiente),
            Dosis(id: UUID(), hora: "21:00", medicamento: "Metformina 850 mg",
                  indicacion: "1 tableta", estado: .pendiente)
        ]
    }

    static let inventario: [ItemInventario] = [
        ItemInventario(id: UUID(), nombre: "Losartán 50 mg", cantidad: 5, umbral: 10),
        ItemInventario(id: UUID(), nombre: "Metformina 850 mg", cantidad: 30, umbral: 30)
    ]

    // Fecha de hoy (o de hace N días) a una hora concreta.
    private static func fecha(diasAtras: Int, hora: Int, minuto: Int) -> Date {
        let calendario = Calendar.current
        let dia = calendario.date(byAdding: .day, value: -diasAtras, to: Date()) ?? Date()
        return calendario.date(bySettingHour: hora, minute: minuto, second: 0, of: dia) ?? dia
    }

    static func historialDemo() -> [RegistroDosis] {
        [
            RegistroDosis(id: UUID(), fecha: fecha(diasAtras: 0, hora: 7, minuto: 4),
                          medicamento: "Losartán 50 mg", indicacion: "1 tableta",
                          horaProgramada: "07:00", cuidador: "Ana Pérez"),
            RegistroDosis(id: UUID(), fecha: fecha(diasAtras: 1, hora: 21, minuto: 10),
                          medicamento: "Metformina 850 mg", indicacion: "1 tableta",
                          horaProgramada: "21:00", cuidador: "Luis Morales"),
            RegistroDosis(id: UUID(), fecha: fecha(diasAtras: 1, hora: 13, minuto: 2),
                          medicamento: "Metformina 850 mg", indicacion: "1 tableta",
                          horaProgramada: "13:00", cuidador: "Ana Pérez"),
            RegistroDosis(id: UUID(), fecha: fecha(diasAtras: 1, hora: 9, minuto: 15),
                          medicamento: "Losartán 50 mg", indicacion: "1 tableta",
                          horaProgramada: "09:00", cuidador: "Luis Morales"),
            RegistroDosis(id: UUID(), fecha: fecha(diasAtras: 1, hora: 7, minuto: 1),
                          medicamento: "Losartán 50 mg", indicacion: "1 tableta",
                          horaProgramada: "07:00", cuidador: "Ana Pérez")
        ]
    }

    static let notas: [NotaVoz] = [
        NotaVoz(id: UUID(), fecha: "Hoy 07:10", autor: "Ana Pérez", duracion: "0:42"),
        NotaVoz(id: UUID(), fecha: "Ayer 20:15", autor: "Luis Morales", duracion: "1:08"),
        NotaVoz(id: UUID(), fecha: "Ayer 08:02", autor: "Ana Pérez", duracion: "0:21")
    ]
}
