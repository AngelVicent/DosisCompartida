const express = require('express');
const { query } = require('../db');
const { requireAuth } = require('../middleware/auth');
const { HttpError, asyncHandler, entero, isUuid, isoSinMs } = require('../util');

const router = express.Router();
router.use(requireAuth);

// GET /api/historial?dias=30&cuidador=<uuid>
// Dosis administradas por todos los cuidadores, de la más reciente a la más antigua.
router.get('/', asyncHandler(async (req, res) => {
  const dias = req.query.dias === undefined ? 30 : entero(req.query.dias, 1, 365);
  if (dias === null) throw new HttpError(400, 'El parámetro dias debe estar entre 1 y 365.');

  const params = [dias];
  let filtro = '';
  if (req.query.cuidador !== undefined) {
    if (!isUuid(req.query.cuidador)) throw new HttpError(400, 'Cuidador inválido.');
    params.push(req.query.cuidador);
    filtro = 'AND a.cuidador_id = $2';
  }

  const { rows } = await query(
    `SELECT a.id, a.registrada_en AS fecha, m.nombre AS medicamento, m.indicacion,
            to_char(h.hora, 'HH24:MI') AS hora_programada, c.nombre AS cuidador, a.verificacion
       FROM administraciones a
       JOIN medicamentos m ON m.id = a.medicamento_id
       JOIN horarios h ON h.id = a.horario_id
       JOIN cuidadores c ON c.id = a.cuidador_id
      WHERE a.fecha > CURRENT_DATE - $1::int ${filtro}
      ORDER BY a.registrada_en DESC
      LIMIT 500`,
    params
  );

  res.json(rows.map((r) => ({
    id: r.id,
    fecha: isoSinMs(r.fecha),
    medicamento: r.medicamento,
    indicacion: r.indicacion,
    horaProgramada: r.hora_programada,
    cuidador: r.cuidador,
    verificacion: r.verificacion,
  })));
}));

module.exports = router;
