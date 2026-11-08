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

struct Paciente {
    let nombre: String
    let edad: Int
    let padecimientos: String
    let alergias: [String]
}

enum EstadoDosis {
    case pendiente
    case administrada
}

struct Dosis: Identifiable, Equatable {
    let id: UUID
    let hora: String
    let medicamento: String
    let indicacion: String
    var estado: EstadoDosis
    var registradaPor: String?
    var horaRegistro: String?
}

struct ItemInventario: Identifiable, Equatable {
    let id: UUID
    let nombre: String
    let cantidad: Int
    let umbral: Int
    var enviadoAFarmacia: Bool = false

    // Está bajo cuando la cantidad cae por debajo del umbral (RF-08).
    var bajo: Bool { cantidad < umbral }
}

struct NotaVoz: Identifiable {
    let id: UUID
    let fecha: String
    let autor: String
    let duracion: String
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

    static let notas: [NotaVoz] = [
        NotaVoz(id: UUID(), fecha: "Hoy 07:10", autor: "Ana Pérez", duracion: "0:42"),
        NotaVoz(id: UUID(), fecha: "Ayer 20:15", autor: "Luis Morales", duracion: "1:08"),
        NotaVoz(id: UUID(), fecha: "Ayer 08:02", autor: "Ana Pérez", duracion: "0:21")
    ]
}
