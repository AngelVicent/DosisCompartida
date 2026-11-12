class HttpError extends Error {
  constructor(status, mensaje) {
    super(mensaje);
    this.status = status;
  }
}

// Permite usar async/await en las rutas de Express 4.
const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

const str = (v) => (typeof v === 'string' ? v.trim() : '');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);

// Entero dentro de un rango, o null si no es válido.
function entero(v, min, max) {
  const n = typeof v === 'string' && v.trim() !== '' ? Number(v) : v;
  if (!Number.isInteger(n) || n < min || n > max) return null;
  return n;
}

// El cliente iOS decodifica fechas con .iso8601, que NO acepta milisegundos.
const isoSinMs = (d) => (d ? new Date(d).toISOString().replace(/\.\d{3}Z$/, 'Z') : null);

module.exports = { HttpError, asyncHandler, str, isUuid, entero, isoSinMs };
