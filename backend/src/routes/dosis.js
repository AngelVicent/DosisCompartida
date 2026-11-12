const express = require('express');
const { query, tx } = require('../db');
const { requireAuth } = require('../middleware/auth');
const { HttpError, asyncHandler, isUuid } = require('../util');

const router = express.Router();
router.use(requireAuth);

// Resultado de comparar la etiqueta del medicamento con la dosis programada (lo calcula la app).
const VERIFICACIONES = ['coincide', 'no_coincide', 'omitida'];

const aDosis = (r) => ({
  id: r.id,
  hora: r.hora,
  medicamento: r.medicamento,
  indicacion: r.indicacion,
  estado: r.adm_id ? 'administrada' : 'pendiente',
  registradaPor: r.registrada_por || null,
  horaRegistro: r.hora_registro || null,
});

// GET /api/dosis  ->  dosis de hoy (cada horario activo, pendiente o administrada)
router.get('/', asyncHandler(async (req, res) => {
  const { rows } = await query(
    `SELECT h.id, to_char(h.hora, 'HH24:MI') AS hora, m.nombre AS medicamento, m.indicacion,
            a.id AS adm_id, to_char(a.registrada_en, 'HH24:MI') AS hora_registro,
            c.nombre AS registrada_por
       FROM horarios h
       JOIN medicamentos m ON m.id = h.medicamento_id AND m.activo AND h.activo
       LEFT JOIN administraciones a ON a.horario_id = h.id AND a.fecha = CURRENT_DATE
       LEFT JOIN cuidadores c ON c.id = a.cuidador_id
      ORDER BY h.hora, m.nombre`
  );
  res.json(rows.map(aDosis));
}));

// POST /api/dosis/:id/administrar
// Registra la dosis de hoy y descuenta el inventario, todo en una transacción.
router.post('/:id/administrar', asyncHandler(async (req, res) => {
  const { id } = req.params;
  if (!isUuid(id)) throw new HttpError(400, 'Identificador de dosis inválido.');
  const verificacion = req.body?.verificacion === undefined ? 'omitida' : req.body.verificacion;
  if (!VERIFICACIONES.includes(verificacion)) throw new HttpError(400, 'Verificación inválida.');

  const resultado = await tx(async (c) => {
    // Bloquea la fila del medicamento para que dos cuidadores no descuenten a la vez.
    const { rows: hs } = await c.query(
      `SELECT h.id, h.medicamento_id, to_char(h.hora, 'HH24:MI') AS hora,
              m.nombre, m.indicacion, m.unidades_por_dosis
         FROM horarios h JOIN medicamentos m ON m.id = h.medicamento_id
        WHERE h.id = $1 AND h.activo AND m.activo
          FOR UPDATE OF m`,
      [id]
    );
    const h = hs[0];
    if (!h) throw new HttpError(404, 'La dosis no existe.');

    const { rows: ins } = await c.query(
      `INSERT INTO administraciones (horario_id, medicamento_id, cuidador_id, verificacion)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (horario_id, fecha) DO NOTHING
       RETURNING id, to_char(registrada_en, 'HH24:MI') AS hora_registro`,
      [h.id, h.medicamento_id, req.cuidador.id, verificacion]
    );
    if (!ins[0]) throw new HttpError(409, 'Esta dosis ya fue registrada hoy.');

    const { rows: inv } = await c.query(
      `UPDATE medicamentos SET cantidad = GREATEST(0, cantidad - $2) WHERE id = $1
       RETURNING id, nombre, cantidad, umbral, enviado_a_farmacia`,
      [h.medicamento_id, h.unidades_por_dosis]
    );

    return {
      dosis: aDosis({
        id: h.id, hora: h.hora, medicamento: h.nombre, indicacion: h.indicacion,
        adm_id: ins[0].id, registrada_por: req.cuidador.nombre, hora_registro: ins[0].hora_registro,
      }),
      inventario: {
        id: inv[0].id, nombre: inv[0].nombre, cantidad: inv[0].cantidad, umbral: inv[0].umbral,
        bajo: inv[0].cantidad < inv[0].umbral, enviadoAFarmacia: inv[0].enviado_a_farmacia,
      },
    };
  });

  res.status(201).json(resultado);
}));

module.exports = router;
