# Guion del video de avance (6 a 7 minutos)

Un video corto vale más si cada parte muestra algo **funcionando**. Este guion sigue el orden en que la app
se entiende mejor. Los tiempos son aproximados.

## Antes de grabar (lista de verificación)

- [ ] Servidor en marcha: `cd backend && npm run db:reset && npm start` (empezar con datos limpios).
- [ ] App en modo servidor: Ajustes > desactivar "Modo demostración" y escribir la URL del servidor.
- [ ] En Xcode, en el Info.plist: permiso de **micrófono**, de **cámara** y **Allow Local Networking = YES**.
- [ ] Dos dispositivos o simuladores: uno con **Ana** y otro con **Luis** (`demo1234`).
- [ ] Una **caja o blíster real** de medicina (o una foto nítida de su etiqueta) y otra caja distinta.
- [ ] Notificaciones permitidas y un fragmento de audio de prueba pensado ("el paciente comió bien").
- [ ] Ensayar una vez completo. **Plan B:** si falla la red en vivo, usar el modo demostración.

Cómo grabar: en iPhone, el botón de grabación de pantalla del Centro de control (activando el micrófono para
narrar); en el simulador, `xcrun simctl io booted recordVideo avance.mp4` (detener con Ctrl+C).

## Guion

| Tiempo | Qué mostrar | Qué decir |
|---|---|---|
| **0:00 a 0:30** | Pantalla de inicio de la app | Qué es Dosis Compartida y qué problema resuelve: cuando varios familiares cuidan a un adulto mayor, nadie sabe quién ya dio la medicina. Presentar al equipo. |
| **0:30 a 1:15** | Diagrama de arquitectura (abajo) | App iOS en SwiftUI, API en Node con Express y base de datos PostgreSQL. La app y el servidor hablan por las APIs documentadas en `docs/API.md`. |
| **1:15 a 2:00** | Login con Ana y pantalla **Hoy** | Datos del paciente, alergia en rojo, dosis del día. Mencionar que las horas atrasadas se marcan en rojo. |
| **2:00 a 3:15** | **Registrar una dosis**: paso 1, foto de la etiqueta correcta, luego una caja equivocada, y confirmar | La app lee la etiqueta con la cámara y la compara con lo programado. Con la caja correcta dice "Coincide"; con otra, avisa "Posible error". Aclarar que verifica la **etiqueta**, no la pastilla suelta. Mostrar que el inventario baja. |
| **3:15 a 4:00** | **El otro dispositivo (Luis)**: Historial, deslizar para actualizar | Aquí está lo "compartido": Luis ve que Ana dio la dosis, a qué hora y si la etiqueta se verificó. |
| **4:00 a 4:40** | Pestaña **Medicinas** | El inventario ya está bajo, aparece la alerta. Enviar a farmacia y registrar una reposición. |
| **4:40 a 5:10** | Pestaña **Notas**: grabar, guardar y reproducir; luego Luis la escucha | Notas de voz compartidas entre cuidadores. |
| **5:10 a 5:30** | Ajustes: "Enviar recordatorio de prueba" | Recordatorios a la hora de la dosis y aviso si sigue pendiente. |
| **5:30 a 6:15** | `docs/API.md` (la tabla de la sección 1) y un `curl` a `/api/historial` | Cada pantalla de entrada tiene su API. Mostrar la tabla pantalla a API y una respuesta real del servidor. |
| **6:15 a 6:45** | Lista de pendientes | Ser honestos (ver abajo). |
| **6:45 a 7:00** | Cierre | Qué sigue. |

### Diagrama para el minuto 0:30

```
   iPhone (SwiftUI)            Servidor (Node + Express)          PostgreSQL
 ┌─────────────────┐  HTTP   ┌──────────────────────────┐       ┌───────────────┐
 │ Hoy / Historial │ ──────▶ │ /api/auth   /api/dosis   │ ────▶ │ cuidadores    │
 │ Medicinas       │  JSON   │ /api/inventario          │  SQL  │ medicamentos  │
 │ Notas de voz    │ ◀────── │ /api/historial /api/notas│ ◀──── │ administraciones│
 │ Cámara (Vision) │         │ /api/admin               │       │ notas_voz ... │
 └─────────────────┘         └──────────────────────────┘       └───────────────┘
   la foto de la etiqueta se lee en el teléfono y no se sube
```

## Lo que hay que decir con honestidad (minuto 6:15)

Decirlo uno mismo se ve mejor que dejar que lo descubran con una pregunta.

- Verifica la **etiqueta de la caja o blíster**, no reconoce la pastilla suelta por su aspecto (eso requeriría
  un modelo entrenado con fotos de medicamentos).
- "Enviar a farmacia" **registra el pedido**, pero todavía no manda el correo.
- Dar de alta medicamentos y cuidadores funciona en la API, pero **aún no hay pantalla** en la app.
- Un solo paciente por ahora.
- Falta HTTPS y revisión de privacidad antes de usarlo con personas reales.

## Lo que NO hay que decir

- "Reconoce la pastilla" (no es cierto).
- "Envía el correo a la farmacia" (no lo hace).
- "Es seguro para usarse en producción" (no se ha revisado).

## Si preguntan

- **¿Qué pasa si la cámara no lee bien?** Avisa que no pudo verificar y el cuidador decide; queda registrado
  como "Sin verificar".
- **¿Y si dos cuidadores registran la misma dosis a la vez?** Solo uno entra; el servidor lo garantiza con
  una transacción y el inventario baja una sola vez. Está probado.
- **¿Dónde se guardan los datos?** En PostgreSQL. En modo demostración, en el teléfono.
- **¿Cómo se protegen las contraseñas?** Con bcrypt; las sesiones usan tokens de corta duración.
