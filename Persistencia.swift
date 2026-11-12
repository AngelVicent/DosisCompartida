import Foundation

// Lo que se guarda en el teléfono entre sesiones de la app.
struct DatosGuardados: Codable {
    var diaDosis: Date          // día al que pertenece la lista de dosis
    var dosis: [Dosis]
    var inventario: [ItemInventario]
    var notas: [NotaVoz]
    var historial: [RegistroDosis]
}

// Guarda y lee un archivo JSON en la carpeta privada de la app (Application Support).
enum Persistencia {

    private static var archivo: URL {
        let carpeta = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        return carpeta.appendingPathComponent("dosis_compartida.json")
    }

    static func cargar() -> DatosGuardados? {
        guard let datos = try? Data(contentsOf: archivo) else { return nil }
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601
        return try? decodificador.decode(DatosGuardados.self, from: datos)
    }

    static func guardar(_ datos: DatosGuardados) {
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        guard let json = try? codificador.encode(datos) else { return }
        try? json.write(to: archivo, options: .atomic)
    }
}
