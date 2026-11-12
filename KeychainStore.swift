import Foundation
import Security

// Guarda el refreshToken en el Keychain de iOS (almacén cifrado del sistema),
// para no pedir la contraseña cada vez que se abre la app.
enum KeychainStore {
    private static let servicio = "com.dosiscompartida.app"
    private static let cuenta = "refreshToken"

    private static var base: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta
        ]
    }

    static func guardar(_ valor: String) {
        borrar()
        var consulta = base
        consulta[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        consulta[kSecValueData as String] = Data(valor.utf8)
        SecItemAdd(consulta as CFDictionary, nil)
    }

    static func leer() -> String? {
        var consulta = base
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    static func borrar() {
        SecItemDelete(base as CFDictionary)
    }
}
