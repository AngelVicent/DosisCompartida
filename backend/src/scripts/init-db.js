// Crea las tablas y carga los datos de ejemplo.
//   npm run db:init     crea el esquema si no existe y siembra si está vacío
//   npm run db:reset    BORRA todo y lo vuelve a crear
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { Client } = require('pg');

async function main() {
  if (!process.env.DATABASE_URL) throw new Error('Falta DATABASE_URL en .env');
  const reset = process.argv.includes('--reset');

  const db = new Client({ connectionString: process.env.DATABASE_URL });
  await db.connect();
  await db.query("SELECT set_config('TimeZone', $1, false)", [process.env.TZ_APP || 'America/Mexico_City']);

  try {
    if (reset) {
      await db.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
      console.log('Base de datos reiniciada.');
    }

    const existe = (await db.query("SELECT to_regclass('public.cuidadores') AS t")).rows[0].t;
    if (!existe) {
      await db.query(fs.readFileSync(path.join(__dirname, '../../db/schema.sql'), 'utf8'));
      console.log('Esquema creado.');
    }

    const { rowCount } = await db.query('SELECT 1 FROM cuidadores LIMIT 1');
    if (rowCount) {
      console.log('La base ya tiene datos; no se sembró nada (usa db:reset para empezar de cero).');
      return;
    }

    const hash = await bcrypt.hash('demo1234', 10);
    const ana = (await db.query(
      `INSERT INTO cuidadores (nombre, correo, password_hash, rol)
       VALUES ('Ana Pérez', 'ana@correo.com', $1, 'administrador') RETURNING id`, [hash])).rows[0].id;
    const luis = (await db.query(
      `INSERT INTO cuidadores (nombre, correo, password_hash, rol)
       VALUES ('Luis Morales', 'luis@correo.com', $1, 'cuidador') RETURNING id`, [hash])).rows[0].id;

    const paciente = (await db.query(
      `INSERT INTO pacientes (nombre, edad, padecimientos, alergias)
       VALUES ('José Morales', 78, 'Hipertensión, diabetes tipo 2', ARRAY['Penicilina']) RETURNING id`)).rows[0].id;

    const losartan = (await db.query(
      `INSERT INTO medicamentos (paciente_id, nombre, indicacion, cantidad, umbral)
       VALUES ($1, 'Losartán 50 mg', '1 tableta', 5, 10) RETURNING id`, [paciente])).rows[0].id;
    const metformina = (await db.query(
      `INSERT INTO medicamentos (paciente_id, nombre, indicacion, cantidad, umbral)
       VALUES ($1, 'Metformina 850 mg', '1 tableta', 30, 30) RETURNING id`, [paciente])).rows[0].id;

    for (const [med, horas] of [[losartan, ['07:00', '09:00']], [metformina, ['13:00', '21:00']]]) {
      for (const hora of horas) {
        await db.query('INSERT INTO horarios (medicamento_id, hora) VALUES ($1, $2)', [med, hora]);
      }
    }

    // Historial de ayer: la mañana la dio Ana y la tarde/noche Luis.
    await db.query(
      `INSERT INTO administraciones (horario_id, medicamento_id, fecha, cuidador_id, registrada_en)
       SELECT h.id, h.medicamento_id, CURRENT_DATE - 1,
              CASE WHEN h.hora < '12:00' THEN $1::uuid ELSE $2::uuid END,
              (CURRENT_DATE - 1) + h.hora + interval '3 minutes'
         FROM horarios h`, [ana, luis]);

    console.log('Datos de ejemplo cargados.');
    console.log('  Administrador: ana@correo.com / demo1234');
    console.log('  Cuidador:      luis@correo.com / demo1234');
  } finally {
    await db.end();
  }
}

main().catch((e) => { console.error(e.message); process.exit(1); });
