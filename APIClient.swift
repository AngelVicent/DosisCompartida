import Foundation

enum APIError: Error {
    case urlInvalida
    case red
    case noAutorizado          // el token expiró o no es válido (HTTP 401 con sesión iniciada)
    case servidor(String)

    var mensaje: String {
        switch self {
        case .urlInvalida:
            return "La dirección del servidor no es válida."
        case .red:
            return "No se pudo conectar con el servidor. Revisa la dirección en Ajustes."
        case .noAutorizado:
            return "Tu sesión expiró. Inicia sesión de nuevo."
        case .servidor(let texto):
            return texto
        }
    }
}

// Cliente de la API (carpeta backend/ de este repositorio).
struct APIClient {

    // Las fechas llegan en ISO 8601 sin milisegundos, ej. 2026-11-11T13:04:00Z
    static var decodificador: JSONDecoder {
        let decodificador = JSONDecoder()
        decodificador.dateDecodingStrategy = .iso8601
        return decodificador
    }

    // MARK: Autenticación

    func login(baseURL: String, correo: String, password: String) async throws -> LoginResponse {
        try await enviar(
            baseURL: baseURL,
            ruta: "/api/auth/login",
            metodo: "POST",
            token: nil,
            cuerpo: ["correo": correo, "password": password]
        )
    }

    // Cambia el refreshToken por tokens nuevos (el anterior deja de servir).
    func refrescar(baseURL: String, refreshToken: String) async throws -> LoginResponse {
        try await enviar(
            baseURL: baseURL,
            ruta: "/api/auth/refresh",
            metodo: "POST",
            token: nil,
            cuerpo: ["refreshToken": refreshToken]
        )
    }

    func logout(baseURL: String, token: String) async {
        guard let request = try? construirRequest(
            baseURL: baseURL,
            ruta: "/api/auth/logout",
            metodo: "POST",
            token: token,
            cuerpo: nil
        ) else { return }
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: Peticiones con sesión

    func get<T: Decodable>(baseURL: String, ruta: String, token: String) async throws -> T {
        try await enviar(baseURL: baseURL, ruta: ruta, metodo: "GET", token: token, cuerpo: nil)
    }

    func post<T: Decodable>(baseURL: String, ruta: String, token: String,
                            cuerpo: [String: Any]? = nil) async throws -> T {
        try await enviar(baseURL: baseURL, ruta: ruta, metodo: "POST", token: token, cuerpo: cuerpo)
    }

    // Descarga un archivo (por ejemplo, el audio de una nota).
    func descargar(baseURL: String, ruta: String, token: String) async throws -> Data {
        var request = try construirRequest(baseURL: baseURL, ruta: ruta, metodo: "GET", token: token, cuerpo: nil)
        request.timeoutInterval = 60
        return try await ejecutar(request, conToken: true)
    }

    // Sube una nota de voz (audio .m4a) con su duración en segundos.
    func subirAudio(baseURL: String, token: String, audio: Data, segundos: Int) async throws -> NotaRemota {
        var request = try construirRequest(baseURL: baseURL, ruta: "/api/notas", metodo: "POST", token: token, cuerpo: nil)
        request.timeoutInterval = 60
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.setValue(String(segundos), forHTTPHeaderField: "X-Duracion-Seg")
        request.httpBody = audio

        let datos = try await ejecutar(request, conToken: true)
        do {
            return try APIClient.decodificador.decode(NotaRemota.self, from: datos)
        } catch {
            throw APIError.servidor("Respuesta inesperada del servidor.")
        }
    }

    // MARK: Internos

    private func enviar<T: Decodable>(
        baseURL: String,
        ruta: String,
        metodo: String,
        token: String?,
        cuerpo: [String: Any]?
    ) async throws -> T {
        let request = try construirRequest(
            baseURL: baseURL,
            ruta: ruta,
            metodo: metodo,
            token: token,
            cuerpo: cuerpo
        )
        let datos = try await ejecutar(request, conToken: token != nil)
        do {
            return try APIClient.decodificador.decode(T.self, from: datos)
        } catch {
            throw APIError.servidor("Respuesta inesperada del servidor.")
        }
    }

    // Ejecuta la petición y devuelve el cuerpo si la respuesta es 2xx.
    private func ejecutar(_ request: URLRequest, conToken: Bool) async throws -> Data {
        let resultado: (Data, URLResponse)
        do {
            resultado = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.red
        }

        let (datos, respuesta) = resultado
        guard let http = respuesta as? HTTPURLResponse else {
            throw APIError.red
        }

        if (200..<300).contains(http.statusCode) {
            return datos
        }

        if http.statusCode == 401 && conToken {
            throw APIError.noAutorizado
        }

        let mensaje = (try? JSONDecoder().decode(ErrorResponse.self, from: datos))?.error
            ?? "Error del servidor (código \(http.statusCode))."
        throw APIError.servidor(mensaje)
    }

    private func construirRequest(
        baseURL: String,
        ruta: String,
        metodo: String,
        token: String?,
        cuerpo: [String: Any]?
    ) throws -> URLRequest {
        let base = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        guard let url = URL(string: base + ruta) else {
            throw APIError.urlInvalida
        }

        var request = URLRequest(url: url)
        request.httpMethod = metodo
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let cuerpo {
            request.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        }
        return request
    }
}
