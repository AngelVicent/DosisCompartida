const express = require('express');
const { HttpError } = require('./util');

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '100kb' }));

app.get('/api/health', (req, res) => res.json({ ok: true }));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/paciente', require('./routes/paciente'));
app.use('/api/dosis', require('./routes/dosis'));
app.use('/api/historial', require('./routes/historial'));
app.use('/api/inventario', require('./routes/inventario'));
app.use('/api/notas', require('./routes/notas'));
app.use('/api/admin', require('./routes/admin'));

app.use((req, res, next) => next(new HttpError(404, 'Ruta no encontrada.')));

// Todos los errores salen como { error: "mensaje" }, el formato que espera la app iOS.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err instanceof HttpError) return res.status(err.status).json({ error: err.message });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'JSON inválido.' });
  if (err.type === 'entity.too.large') return res.status(413).json({ error: 'El contenido es demasiado grande.' });
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor.' });
});

module.exports = app;
