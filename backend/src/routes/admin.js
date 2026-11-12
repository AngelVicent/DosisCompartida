const express = require('express');
const bcrypt = require('bcryptjs');
const { query, tx } = require('../db');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { HttpError, asyncHandler, str, entero, isUuid } = require('../util');

const router = express.Router();
router.use(requireAuth, requireAdmin);

const HORA_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

// GET /api/admin/cuidadores
router.get('/cuidadores', asyncHandler(async (req, res) => {
  const { rows } = await query('SELECT id, nombre, correo, rol, activo FROM cuidadores ORDER BY nombre');
  res.json(rows);
}));

// POST /api/admin/cuidadores  { nombre, correo, password, rol? }
router.post('/cuidadores', asyncHandler(async (req, res) => {
  const nombre = str(req.body?.nombre);
  const correo = str(req.body?.correo).toLowerCase();
  const password = typeof req.body?.password === 'string' ? req.body.password : '';
  const rol = req.body?.rol === 'administrador' ? 'administrador' : 'cuidador';

  if (!nombre || nombre.length > 100) throw new HttpError(400, 'Escribe un nombre (máximo 100 caracteres).');
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(correo) || correo.length > 120) throw new HttpError(400, 'Correo inválido.');
  if (password.length < 8) throw new HttpError(400, 'La contraseña debe tener al menos 8 caracteres.');

  const existe = await query('SELECT 1 FROM cuidadores WHERE lower(correo) = $1', [correo]);
  if (existe.rowCount) throw new HttpError(409, 'Ya existe un cuidador con ese correo.');

  const hash = await bcrypt.hash(password, 10);
  const { rows } = await query(
    'INSERT INTO cuidadores (nombre, correo, password_hash, rol) VALUES ($1, $2, $3, $4) RETURNING id, nombre, correo, rol, activo',
    [nombre, correo, hash, rol]
  );
  res.status(201).json(rows[0]);
}));

// POST /api/admin/medicamentos
// { nombre, indicacion, unidadesPorDosis?, cantidad, umbral, horarios: ["07:00", "19:00"] }
router.post('/medicamentos', asyncHandler(async (req, res) => {
  const b = req.body || {};
  const nombre = str(b.nombre);
  const indicacion = str(b.indicacion);
  const unidades = b.unidadesPorDosis === undefined ? 1 : entero(b.unidadesPorDosis, 1, 100);
  const cantidad = entero(b.cantidad, 0, 100000);
  const umbral = entero(b.umbral, 0, 100000);
  const horarios = Array.isArray(b.horarios) ? [...new Set(b.horarios)] : [];

  if (!nombre || nombre.length > 100) throw new HttpError(400, 'Escribe el nombre del medicamento.');
  if (!indicacion || indicacion.length > 100) throw new HttpError(400, 'Escribe la indicación (por ejemplo "1 tableta").');
  if (unidades === null || cantidad === null || umbral === null) {
    throw new HttpError(400, 'unidadesPorDosis, cantidad y umbral deben ser enteros válidos.');
  }
  if (horarios.length === 0 || !horarios.every((h) => typeof h === 'string' && HORA_RE.test(h))) {
    throw new HttpError(400, 'Indica al menos un horario con formato HH:MM.');
  }

  const medicamento = await tx(async (c) => {
    const { rows } = await c.query(
      `INSERT INTO medicamentos (paciente_id, nombre, indicacion, unidades_por_dosis, cantidad, umbral)
       VALUES ((SELECT id FROM pacientes ORDER BY creado_en LIMIT 1), $1, $2, $3, $4, $5)
       RETURNING id, nombre, indicacion, unidades_por_dosis, cantidad, umbral`,
      [nombre, indicacion, unidades, cantidad, umbral]
    );
    for (const hora of horarios) {
      await c.query('INSERT INTO horarios (medicamento_id, hora) VALUES ($1, $2)', [rows[0].id, hora]);
    }
    return rows[0];
  });

  res.status(201).json({ ...medicamento, horarios: horarios.sort() });
}));

// DELETE /api/admin/medicamentos/:id  ->  baja lógica (se conserva el historial)
router.delete('/medicamentos/:id', asyncHandler(async (req, res) => {
  if (!isUuid(req.params.id)) throw new HttpError(400, 'Identificador inválido.');
  const { rowCount } = await query('UPDATE medicamentos SET activo = FALSE WHERE id = $1 AND activo', [req.params.id]);
  if (!rowCount) throw new HttpError(404, 'El medicamento no existe.');
  res.json({ ok: true });
}));

module.exports = router;
