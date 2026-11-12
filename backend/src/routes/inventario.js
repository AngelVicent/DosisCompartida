const express = require('express');
const { query, tx } = require('../db');
const { requireAuth } = require('../middleware/auth');
const { HttpError, asyncHandler, entero, isUuid } = require('../util');

const router = express.Router();
router.use(requireAuth);

const aItem = (r) => ({
  id: r.id,
  nombre: r.nombre,
  cantidad: r.cantidad,
  umbral: r.umbral,
  bajo: r.cantidad < r.umbral,
  enviadoAFarmacia: r.enviado_a_farmacia,
});

const validarId = (id) => {
  if (!isUuid(id)) throw new HttpError(400, 'Identificador inválido.');
};

// GET /api/inventario
router.get('/', asyncHandler(async (req, res) => {
  const { rows } = await query(
    'SELECT id, nombre, cantidad, umbral, enviado_a_farmacia FROM medicamentos WHERE activo ORDER BY nombre'
  );
  res.json(rows.map(aItem));
}));

// POST /api/inventario/:id/reposicion  { cantidad }  ->  suma existencias
router.post('/:id/reposicion', asyncHandler(async (req, res) => {
  validarId(req.params.id);
  const cantidad = entero(req.body?.cantidad, 1, 100000);
  if (cantidad === null) throw new HttpError(400, 'La cantidad debe ser un entero mayor que 0.');

  const { rows } = await query(
    `UPDATE medicamentos
        SET cantidad = cantidad + $2,
            enviado_a_farmacia = CASE WHEN cantidad + $2 >= umbral THEN FALSE ELSE enviado_a_farmacia END
      WHERE id = $1 AND activo
      RETURNING id, nombre, cantidad, umbral, enviado_a_farmacia`,
    [req.params.id, cantidad]
  );
  if (!rows[0]) throw new HttpError(404, 'El medicamento no existe.');
  res.json(aItem(rows[0]));
}));

// POST /api/inventario/:id/enviar-farmacia  ->  crea el pedido de reposición
router.post('/:id/enviar-farmacia', asyncHandler(async (req, res) => {
  validarId(req.params.id);

  const item = await tx(async (c) => {
    const { rows } = await c.query(
      `SELECT id, nombre, cantidad, umbral, enviado_a_farmacia
         FROM medicamentos WHERE id = $1 AND activo FOR UPDATE`,
      [req.params.id]
    );
    const m = rows[0];
    if (!m) throw new HttpError(404, 'El medicamento no existe.');
    if (m.cantidad >= m.umbral) throw new HttpError(409, 'Este medicamento no está bajo en inventario.');
    if (m.enviado_a_farmacia) throw new HttpError(409, 'Ya se envió el pedido a la farmacia.');

    await c.query('INSERT INTO pedidos_farmacia (medicamento_id, cuidador_id) VALUES ($1, $2)', [m.id, req.cuidador.id]);
    await c.query('UPDATE medicamentos SET enviado_a_farmacia = TRUE WHERE id = $1', [m.id]);
    return { ...m, enviado_a_farmacia: true };
  });

  res.status(201).json(aItem(item));
}));

module.exports = router;
