import Foundation

enum APIError: Error {
    case urlInvalida
    case red
    case servidor(String)

    var mensaje: String {
        switch self {
        case .urlInvalida:
            return "La dirección del servidor no es válida."
        case .red:
            return "No se pudo conectar con el servidor. Revisa la dirección en Ajustes."
        case .servidor(let texto):
            return texto
        }
    }
}

// Cliente de la API de autenticación (src/routes/auth.js del backend).
struct APIClient {

    func login(baseURL: String, correo: String, password: String) async throws -> LoginResponse {
        let respuesta: LoginResponse = try await enviar(
            baseURL: baseURL,
            ruta: "/api/auth/login",
            metodo: "POST",
            token: nil,
            cuerpo: ["correo": correo, "password": password]
        )
        return respuesta
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

    private func enviar<T: Decodable>(
        baseURL: String,
        ruta: String,
        metodo: String,
        token: String?,
        cuerpo: [String: String]?
    ) async throws -> T {
        let request = try construirRequest(
            baseURL: baseURL,
            ruta: ruta,
            metodo: metodo,
            token: token,
            cuerpo: cuerpo
        )

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
            do {
                return try JSONDecoder().decode(T.self, from: datos)
            } catch {
                throw APIError.servidor("Respuesta inesperada del servidor.")
            }
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
        cuerpo: [String: String]?
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
