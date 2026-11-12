const express = require('express');
const { query } = require('../db');
const { requireAuth } = require('../middleware/auth');
const { HttpError, asyncHandler } = require('../util');

const router = express.Router();
router.use(requireAuth);

// GET /api/paciente  ->  { nombre, edad, padecimientos, alergias }
router.get('/', asyncHandler(async (req, res) => {
  const { rows } = await query(
    'SELECT nombre, edad, padecimientos, alergias FROM pacientes ORDER BY creado_en LIMIT 1'
  );
  if (!rows[0]) throw new HttpError(404, 'No hay paciente registrado.');
  res.json(rows[0]);
}));

module.exports = router;
