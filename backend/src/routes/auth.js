const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { query } = require('../db');
const { requireAuth } = require('../middleware/auth');
const { HttpError, asyncHandler, str } = require('../util');

const router = express.Router();

const ACCESS_TTL = '15m';
const REFRESH_DIAS = 30;
const DUMMY_HASH = bcrypt.hashSync('no-existe', 10); // iguala el tiempo de respuesta si el correo no existe

const sha256 = (t) => crypto.createHash('sha256').update(t).digest('hex');

// Límite simple de intentos fallidos por IP + correo.
const MAX_INTENTOS = 5;
const VENTANA_MS = 15 * 60 * 1000;
const intentos = new Map();
const bloqueado = (clave) => {
  const r = intentos.get(clave);
  if (!r) return false;
  if (Date.now() > r.hasta) { intentos.delete(clave); return false; }
  return r.n >= MAX_INTENTOS;
};
const registrarFallo = (clave) => {
  const r = intentos.get(clave);
  if (!r || Date.now() > r.hasta) intentos.set(clave, { n: 1, hasta: Date.now() + VENTANA_MS });
  else r.n += 1;
};

async function emitirTokens(c) {
  const accessToken = jwt.sign(
    { rol: c.rol, nombre: c.nombre, correo: c.correo },
    process.env.JWT_SECRET,
    { subject: c.id, expiresIn: ACCESS_TTL }
  );
  const refreshToken = crypto.randomBytes(48).toString('hex');
  await query(
    `INSERT INTO refresh_tokens (cuidador_id, token_hash, expira_en)
     VALUES ($1, $2, now() + ($3 || ' days')::interval)`,
    [c.id, sha256(refreshToken), String(REFRESH_DIAS)]
  );
  return { accessToken, refreshToken };
}

const publico = (c) => ({ id: c.id, nombre: c.nombre, correo: c.correo, rol: c.rol });

// POST /api/auth/login  ->  { accessToken, refreshToken, cuidador }
router.post('/login', asyncHandler(async (req, res) => {
  const correo = str(req.body?.correo).toLowerCase();
  const password = typeof req.body?.password === 'string' ? req.body.password : '';
  if (!correo || !password) throw new HttpError(400, 'Escribe tu correo y contraseña.');

  const clave = `${req.ip}|${correo}`;
  if (bloqueado(clave)) throw new HttpError(429, 'Demasiados intentos. Espera unos minutos.');

  const { rows } = await query(
    'SELECT id, nombre, correo, rol, password_hash FROM cuidadores WHERE lower(correo) = $1 AND activo',
    [correo]
  );
  const cuidador = rows[0];
  const ok = await bcrypt.compare(password, cuidador ? cuidador.password_hash : DUMMY_HASH);
  if (!cuidador || !ok) {
    registrarFallo(clave);
    throw new HttpError(401, 'Correo o contraseña incorrectos.');
  }
  intentos.delete(clave);

  const tokens = await emitirTokens(cuidador);
  res.json({ ...tokens, cuidador: publico(cuidador) });
}));

// POST /api/auth/refresh  { refreshToken }  ->  tokens nuevos (el anterior se invalida)
router.post('/refresh', asyncHandler(async (req, res) => {
  const refreshToken = str(req.body?.refreshToken);
  if (!refreshToken) throw new HttpError(400, 'Falta el refreshToken.');

  const { rows } = await query(
    `UPDATE refresh_tokens SET revocado = TRUE
      WHERE token_hash = $1 AND NOT revocado AND expira_en > now()
      RETURNING cuidador_id`,
    [sha256(refreshToken)]
  );
  if (!rows[0]) throw new HttpError(401, 'La sesión expiró. Vuelve a iniciar sesión.');

  const { rows: cs } = await query(
    'SELECT id, nombre, correo, rol FROM cuidadores WHERE id = $1 AND activo',
    [rows[0].cuidador_id]
  );
  if (!cs[0]) throw new HttpError(401, 'La cuenta ya no está activa.');

  const tokens = await emitirTokens(cs[0]);
  res.json({ ...tokens, cuidador: publico(cs[0]) });
}));

// POST /api/auth/logout  (Bearer)  ->  cierra todas las sesiones del cuidador
router.post('/logout', requireAuth, asyncHandler(async (req, res) => {
  await query('UPDATE refresh_tokens SET revocado = TRUE WHERE cuidador_id = $1 AND NOT revocado', [req.cuidador.id]);
  res.json({ ok: true });
}));

module.exports = router;
