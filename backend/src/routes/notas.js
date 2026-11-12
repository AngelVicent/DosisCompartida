const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { query } = require('../db');
const { requireAuth } = require('../middleware/auth');
const { HttpError, asyncHandler, entero, isUuid, isoSinMs } = require('../util');

const router = express.Router();
router.use(requireAuth);

const UPLOADS = path.resolve(process.env.UPLOADS_DIR || 'uploads');
const EXTENSIONES = {
  'audio/mp4': '.m4a',
  'audio/x-m4a': '.m4a',
  'audio/m4a': '.m4a',
  'audio/mpeg': '.mp3',
  'audio/wav': '.wav',
  'audio/x-wav': '.wav',
};

// GET /api/notas
router.get('/', asyncHandler(async (req, res) => {
  const { rows } = await query(
    `SELECT n.id, n.creada_en, n.duracion_seg, c.nombre AS autor
       FROM notas_voz n JOIN cuidadores c ON c.id = n.cuidador_id
      ORDER BY n.creada_en DESC LIMIT 200`
  );
  res.json(rows.map((r) => ({
    id: r.id,
    fecha: isoSinMs(r.creada_en),
    autor: r.autor,
    duracionSegundos: r.duracion_seg,
  })));
}));

// POST /api/notas   Content-Type: audio/mp4 (cuerpo = el audio)   X-Duracion-Seg: 42
router.post('/', express.raw({ type: 'audio/*', limit: '10mb' }), asyncHandler(async (req, res) => {
  const extension = EXTENSIONES[(req.headers['content-type'] || '').split(';')[0].trim().toLowerCase()];
  if (!extension) throw new HttpError(415, 'Formato de audio no permitido (usa m4a, mp3 o wav).');
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) throw new HttpError(400, 'El audio está vacío.');
  const duracion = entero(req.headers['x-duracion-seg'], 1, 3600);
  if (duracion === null) throw new HttpError(400, 'Falta la cabecera X-Duracion-Seg (1 a 3600).');

  await fs.promises.mkdir(UPLOADS, { recursive: true });
  const archivo = `${crypto.randomUUID()}${extension}`;
  await fs.promises.writeFile(path.join(UPLOADS, archivo), req.body);

  const { rows } = await query(
    `INSERT INTO notas_voz (cuidador_id, duracion_seg, archivo) VALUES ($1, $2, $3)
     RETURNING id, creada_en`,
    [req.cuidador.id, duracion, archivo]
  );
  res.status(201).json({
    id: rows[0].id,
    fecha: isoSinMs(rows[0].creada_en),
    autor: req.cuidador.nombre,
    duracionSegundos: duracion,
  });
}));

// GET /api/notas/:id/audio
router.get('/:id/audio', asyncHandler(async (req, res) => {
  if (!isUuid(req.params.id)) throw new HttpError(400, 'Identificador inválido.');
  const { rows } = await query('SELECT archivo FROM notas_voz WHERE id = $1', [req.params.id]);
  if (!rows[0]) throw new HttpError(404, 'La nota no existe.');
  res.sendFile(path.join(UPLOADS, path.basename(rows[0].archivo)));
}));

module.exports = router;
