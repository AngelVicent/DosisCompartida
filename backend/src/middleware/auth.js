const jwt = require('jsonwebtoken');
const { HttpError } = require('../util');

function requireAuth(req, res, next) {
  const cabecera = req.headers.authorization || '';
  const [tipo, token] = cabecera.split(' ');
  if (tipo !== 'Bearer' || !token) {
    return next(new HttpError(401, 'Falta iniciar sesión.'));
  }
  try {
    const datos = jwt.verify(token, process.env.JWT_SECRET);
    req.cuidador = { id: datos.sub, nombre: datos.nombre, correo: datos.correo, rol: datos.rol };
    next();
  } catch {
    next(new HttpError(401, 'La sesión expiró. Vuelve a iniciar sesión.'));
  }
}

function requireAdmin(req, res, next) {
  if (req.cuidador?.rol !== 'administrador') {
    return next(new HttpError(403, 'Solo el administrador puede hacer esto.'));
  }
  next();
}

module.exports = { requireAuth, requireAdmin };
