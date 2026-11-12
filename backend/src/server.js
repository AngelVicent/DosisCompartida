require('dotenv').config();

if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 16) {
  console.error('Falta JWT_SECRET en .env (mínimo 16 caracteres).');
  process.exit(1);
}
if (!process.env.DATABASE_URL) {
  console.error('Falta DATABASE_URL en .env.');
  process.exit(1);
}

const app = require('./app');
const port = Number(process.env.PORT) || 3000;

app.listen(port, '0.0.0.0', () => {
  console.log(`Dosis Compartida API escuchando en http://0.0.0.0:${port}`);
});
