# Dosis Compartida: API (Express + PostgreSQL)

Backend de la app iOS. Varios cuidadores comparten el mismo paciente: las dosis de hoy, el historial,
el inventario y las notas de voz viven en PostgreSQL, no en cada teléfono.

## Requisitos
- Node.js 18 o superior
- PostgreSQL 13 o superior

## Puesta en marcha

```bash
# 1. PostgreSQL (si no tienes uno). Con Docker o Podman:
docker run -d --name dosis-pg -p 5432:5432 \
  -e POSTGRES_USER=dosis -e POSTGRES_PASSWORD=dosis -e POSTGRES_DB=dosiscompartida \
  postgres:16-alpine

# 2. Configuración
cd backend
cp .env.example .env        # edita JWT_SECRET con una cadena larga y aleatoria

# 3. Dependencias, tablas y datos de ejemplo
npm install
npm run db:init             # (npm run db:reset borra todo y lo recrea)

# 4. Servidor en http://localhost:3000
npm start
```

Usuarios de ejemplo (contraseña `demo1234`): `ana@correo.com` (administrador) y `luis@correo.com` (cuidador).

En la app: Ajustes > desactivar "Modo demostración" y escribir la URL del servidor
(en un iPhone real usa la IP de tu computadora, por ejemplo `http://192.168.1.20:3000`).

## Endpoints

Todos devuelven JSON. Los errores tienen la forma `{ "error": "mensaje" }`.
Salvo `login` y `refresh`, requieren `Authorization: Bearer <accessToken>`.

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/login` | `{correo, password}` devuelve `{accessToken, refreshToken, cuidador}` |
| POST | `/api/auth/refresh` | `{refreshToken}` devuelve tokens nuevos (el anterior se invalida) |
| POST | `/api/auth/logout` | Cierra todas las sesiones del cuidador |
| GET | `/api/paciente` | Datos del paciente |
| GET | `/api/dosis` | Dosis de hoy, pendientes o administradas |
| POST | `/api/dosis/:id/administrar` | Registra la dosis y **descuenta el inventario** (409 si ya se registró hoy). Cuerpo opcional `{verificacion: "coincide" \| "no_coincide" \| "omitida"}`: cómo se verificó la etiqueta |
| GET | `/api/historial?dias=30&cuidador=<id>` | Dosis administradas por todos los cuidadores, con su `verificacion` |
| GET | `/api/inventario` | Existencias, umbral y si está bajo |
| POST | `/api/inventario/:id/reposicion` | `{cantidad}` suma existencias |
| POST | `/api/inventario/:id/enviar-farmacia` | Crea el pedido (solo si está bajo) |
| GET | `/api/notas` | Notas de voz |
| POST | `/api/notas` | Cuerpo = audio (`Content-Type: audio/mp4`), cabecera `X-Duracion-Seg` |
| GET | `/api/notas/:id/audio` | Descarga el audio |
| GET/POST | `/api/admin/cuidadores` | Solo administrador |
| POST/DELETE | `/api/admin/medicamentos` | Solo administrador (alta con horarios / baja lógica) |
| GET | `/api/health` | Comprobación |

Las fechas salen en ISO 8601 UTC sin milisegundos (`2026-11-11T13:04:00Z`) para que las lea
`JSONDecoder` con `.iso8601`.

## Seguridad
- Contraseñas con bcrypt. Access token JWT de 15 minutos; refresh token aleatorio de 30 días
  guardado como hash y rotado en cada uso.
- Máximo 5 intentos fallidos de login por IP y correo cada 15 minutos.
- Consultas parametrizadas; los permisos de administrador se validan en el servidor.
- Falta para producción: HTTPS (poner un proxy como Caddy o Nginx delante), copias de seguridad
  de la base y revisar la privacidad de los datos de salud.

## Si ya tenías la base creada
El esquema cambió (columna `administraciones.verificacion`). En desarrollo, ejecuta `npm run db:reset` para recrearla.

## Lo que aún no hace
- Un solo paciente (`medicamentos.paciente_id` ya existe para ampliarlo).
- "Enviar a farmacia" registra el pedido en `pedidos_farmacia`, pero no manda el correo.
- La app iOS todavía usa datos locales salvo el login: falta conectar las demás pantallas a esta API.
