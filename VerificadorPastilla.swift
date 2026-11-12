import Foundation

// MARK: - Verificación del medicamento (RF-02, RF-03)
//
// Compara el texto leído de la etiqueta de la caja o blíster con la dosis programada.
// No identifica pastillas sueltas por su aspecto (eso requiere un modelo entrenado):
// verifica que el medicamento que se va a dar sea el que corresponde.

struct ResultadoVerificacion: Equatable {
    enum Estado: String {
        case coincide       // nombre y dosis coinciden
        case noCoincide     // hay una diferencia clara (otro medicamento u otra dosis)
        case inconcluso     // no se pudo leer lo suficiente para decidir
    }
    let estado: Estado
    let mensaje: String
}

enum VerificadorPastilla {

    // `lineas`: texto reconocido en la foto. `esperado`: p. ej. "Losartán 50 mg".
    // `otros`: nombres de los demás medicamentos del paciente, para avisar si se tomó uno equivocado.
    static func verificar(lineas: [String], esperado: String, otros: [String] = []) -> ResultadoVerificacion {
        let texto = normalizar(lineas.joined(separator: " "))
        let palabras = texto.split(separator: " ").map(String.init)
        let esperada = descomponer(esperado)

        let nombreOk = esperada.nombre.isEmpty ? false : aparece(esperada.nombre, en: palabras)
        let leidas = dosisLeidas(en: texto)

        if nombreOk {
            guard let dosisEsperada = esperada.dosis else {
                return ResultadoVerificacion(estado: .coincide, mensaje: "La etiqueta coincide con \(esperado).")
            }
            if leidas.contains(where: { $0.unidad == dosisEsperada.unidad && abs($0.valor - dosisEsperada.valor) < 0.001 }) {
                return ResultadoVerificacion(estado: .coincide, mensaje: "La etiqueta coincide con \(esperado).")
            }
            // mg contra mcg es un error de mil veces la dosis: se trata como diferencia clara.
            let parecida: (Dosis) -> Bool = { d in
                d.unidad == dosisEsperada.unidad
                    || (Set([d.unidad, dosisEsperada.unidad]) == Set(["mg", "mcg"]))
            }
            if let distinta = leidas.first(where: parecida) {
                return ResultadoVerificacion(
                    estado: .noCoincide,
                    mensaje: "La etiqueta dice \(formato(distinta)) y se esperaba \(formato(dosisEsperada))."
                )
            }
            return ResultadoVerificacion(
                estado: .inconcluso,
                mensaje: "Se leyó el nombre, pero no la dosis. Acerca la cámara a donde dice los miligramos."
            )
        }

        // Si aparece otro medicamento del paciente, es el error más peligroso: se avisa.
        for otro in otros {
            let d = descomponer(otro)
            if !d.nombre.isEmpty, d.nombre != esperada.nombre, aparece(d.nombre, en: palabras) {
                return ResultadoVerificacion(
                    estado: .noCoincide,
                    mensaje: "La etiqueta parece ser de otro medicamento (\(otro)). Se esperaba \(esperado)."
                )
            }
        }

        let palabrasLegibles = palabras.filter { $0.count >= 3 && $0.contains(where: { $0.isLetter }) }
        if palabrasLegibles.count >= 6 {
            return ResultadoVerificacion(
                estado: .noCoincide,
                mensaje: "No aparece el nombre del medicamento esperado (\(esperado)) en la etiqueta."
            )
        }
        return ResultadoVerificacion(
            estado: .inconcluso,
            mensaje: "No se pudo leer bien la etiqueta. Intenta con más luz y enfocando el nombre."
        )
    }

    // MARK: Texto

    // Minúsculas, sin acentos, comas decimales como punto y solo letras, números y puntos.
    static func normalizar(_ texto: String) -> String {
        var t = texto.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .lowercased()
        t = t.replacingOccurrences(of: #"(\d),(\d)"#, with: "$1.$2", options: .regularExpression)
        t = String(t.map { $0.isLetter || $0.isNumber || $0 == "." ? $0 : " " })
        return t.split(separator: " ").joined(separator: " ")
    }

    private struct Dosis {
        let valor: Double
        let unidad: String
    }

    private static func formato(_ d: Dosis) -> String {
        let v = d.valor == d.valor.rounded() ? String(Int(d.valor)) : String(d.valor)
        return "\(v) \(d.unidad)"
    }

    // "Losartán 50 mg" -> nombre "losartan", dosis 50 mg
    private static func descomponer(_ texto: String) -> (nombre: String, dosis: Dosis?) {
        let t = normalizar(texto)
        let partes = t.split(separator: " ").map(String.init)
        let nombrePartes = partes.prefix { !$0.contains(where: { $0.isNumber }) }.filter { $0.count >= 4 }
        // El nombre más largo es el principal (ej. "metformina").
        let nombre = nombrePartes.max(by: { $0.count < $1.count }) ?? ""
        return (nombre, dosisLeidas(en: t).first)
    }

    private static func dosisLeidas(en texto: String) -> [Dosis] {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(mg|mcg|ml|g)\b"#) else { return [] }
        let rango = NSRange(texto.startIndex..., in: texto)
        return regex.matches(in: texto, range: rango).compactMap { m in
            guard let rv = Range(m.range(at: 1), in: texto),
                  let ru = Range(m.range(at: 2), in: texto),
                  let valor = Double(texto[rv]) else { return nil }
            return Dosis(valor: valor, unidad: String(texto[ru]))
        }
    }

    // MARK: Coincidencia aproximada (el OCR se equivoca en letras sueltas: "L0SARTAN")

    private static func aparece(_ nombre: String, en palabras: [String]) -> Bool {
        palabras.contains { palabra in
            if palabra == nombre { return true }
            guard nombre.count >= 5 else { return false }
            if palabra.contains(nombre) { return true }             // pegadas: "losartanpotasico"
            let tolerancia = nombre.count >= 9 ? 2 : 1
            return abs(palabra.count - nombre.count) <= tolerancia
                && distancia(palabra, nombre) <= tolerancia
        }
    }

    // Distancia de Levenshtein: número mínimo de cambios de letra entre dos palabras.
    private static func distancia(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var previa = Array(0...y.count)
        for i in 1...x.count {
            var actual = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                let costo = x[i - 1] == y[j - 1] ? 0 : 1
                actual[j] = min(previa[j] + 1, actual[j - 1] + 1, previa[j - 1] + costo)
            }
            previa = actual
        }
        return previa[y.count]
    }
}
