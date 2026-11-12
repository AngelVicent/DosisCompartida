# Dosis Compartida

App para que varios cuidadores coordinen los medicamentos de un adulto mayor: quién dio cada dosis y a qué
hora, inventario con alertas de reposición, recordatorios y notas de voz.

- **App iOS** (SwiftUI): los archivos `.swift` de esta carpeta.
- **API** (Node + Express + PostgreSQL): carpeta [`backend/`](backend/README.md).

## Documentación
- [Documentación de las APIs](docs/API.md): qué API recibe la información de cada pantalla de entrada.
- [Guion del video de avance](docs/GUION_VIDEO.md)

## Funciones
- **Hoy:** dosis del día en orden, con marca de "atrasada" y registro en 3 pasos. El paso 1 **verifica el
  medicamento**: se fotografía la etiqueta de la caja o blíster, la app lee el texto (Vision) y avisa si el
  nombre o la dosis no coinciden, o si parece ser otro medicamento del paciente.
- **Historial compartido:** quién administró cada dosis, agrupado por día y filtrable por cuidador, con la
  verificación de cada una (verificada, con diferencia o sin verificar).
- **Medicinas:** inventario que baja solo al registrar una dosis, alerta de existencias bajas,
  pedido a la farmacia y registro de reposición.
- **Recordatorios:** aviso a la hora de la dosis y otro 15 minutos después si sigue pendiente.
- **Notas de voz:** graba una nota hablada (hasta 3 minutos), guárdala y escucha las de los demás cuidadores.
- **Dos modos:** *demostración* (datos de ejemplo guardados en el teléfono) y *servidor*
  (todo se comparte a través de la API).

## Cómo probar la app

### 1. Crear el proyecto en Xcode (requiere Mac)
El repositorio contiene los archivos fuente, no el archivo `.xcodeproj`.
1. Xcode > File > New > Project > **iOS App**, interfaz **SwiftUI**, nombre `DosisCompartida`.
2. Borra `ContentView.swift` y el archivo `@main` que crea Xcode.
3. Arrastra al proyecto todos los `.swift` de esta carpeta (marca "Copy items if needed").
4. Mínimo iOS 16.

### 2. Modo demostración (sin servidor)
Abre la app e inicia sesión con `ana@correo.com` / `demo1234`.

### 3. Modo servidor
1. Levanta la API siguiendo [`backend/README.md`](backend/README.md).
2. En la app: **Ajustes > desactiva "Modo demostración"** y escribe la URL del servidor.
   - Simulador: `http://localhost:3000`
   - iPhone real: `http://<IP de tu computadora>:3000` (el teléfono y la computadora en la misma red).
3. Inicia sesión con `ana@correo.com` (administrador) o `luis@correo.com` (cuidador), contraseña `demo1234`.
4. Para ver lo "compartido": entra con Ana en un dispositivo y con Luis en otro, registra una dosis en uno y
   desliza hacia abajo en **Hoy** o **Historial** del otro para actualizar.

**Obligatorio para verificar el medicamento:** agrega también
`Privacy - Camera Usage Description` (`NSCameraUsageDescription`) con un texto como
"Fotografiar la etiqueta del medicamento para verificar que sea el correcto". En el simulador no hay cámara:
la app abre la fototeca para elegir una foto de una etiqueta.

**Obligatorio para las notas de voz:** agrega en el Info.plist del target la clave
`Privacy - Microphone Usage Description` (`NSMicrophoneUsageDescription`) con un texto como
"Grabar notas de voz sobre el cuidado del paciente". Sin ella, iOS cierra la app al grabar.

**Importante para iPhone real con `http://`:** iOS bloquea conexiones sin HTTPS. Para desarrollo en red local
agrega en Info.plist del target:
`App Transport Security Settings > Allow Local Networking = YES`. En producción usa HTTPS.

## Estructura
| Archivo | Para qué sirve |
|---|---|
| `DosisCompartidaApp.swift` | Punto de entrada y pantalla de inicio según la sesión |
| `AppState.swift` | Estado de la app, modos demo/servidor, sesión, datos |
| `APIClient.swift` | Peticiones HTTP a la API |
| `KeychainStore.swift` | Guarda el token de sesión en el Keychain |
| `Persistencia.swift` | Guardado local del modo demostración |
| `NotificationManager.swift` | Recordatorios locales |
| `GrabadoraVoz.swift` | Grabación y reproducción de notas de voz |
| `VerificadorPastilla.swift` | Compara el texto de la etiqueta con la dosis programada |
| `LectorEtiqueta.swift` | Cámara y lectura de texto con Vision |
| `Models.swift` | Modelos y datos de ejemplo |
| `LoginView.swift`, `MainTabView.swift`, `HistorialView.swift`, `MedicinasView.swift`, `NotasVozView.swift` | Pantallas |

## Pendiente
- Identificar la pastilla suelta por su aspecto (requiere un modelo entrenado con fotos de medicamentos).
  Hoy se verifica la etiqueta de la caja o blíster, no la pastilla.
- Escaneo de código de barras de la caja como segunda verificación.
- Alta y edición de medicamentos desde la app (la API ya tiene los endpoints de administrador).
- Envío real del correo a la farmacia, HTTPS y varios pacientes.
