const { Pool } = require('pg');

const TZ = process.env.TZ_APP || 'America/Mexico_City';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// Cada conexión usa la zona horaria de la app (para CURRENT_DATE y las horas).
pool.on('connect', (client) => {
  client.query("SELECT set_config('TimeZone', $1, false)", [TZ]).catch(() => {});
});
pool.on('error', (err) => console.error('Error en el pool de PostgreSQL:', err.message));

const query = (texto, params) => pool.query(texto, params);

// Ejecuta fn dentro de una transacción.
async function tx(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const resultado = await fn(client);
    await client.query('COMMIT');
    return resultado;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

module.exports = { pool, query, tx, TZ };
