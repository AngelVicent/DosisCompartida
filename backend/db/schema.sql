-- Esquema de Dosis Compartida (PostgreSQL 13+)

CREATE TABLE cuidadores (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre        VARCHAR(100) NOT NULL,
    correo        VARCHAR(120) NOT NULL,
    password_hash TEXT NOT NULL,
    rol           VARCHAR(20) NOT NULL DEFAULT 'cuidador'
                  CHECK (rol IN ('administrador', 'cuidador')),
    activo        BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX cuidadores_correo_uq ON cuidadores (lower(correo));

CREATE TABLE refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuidador_id UUID NOT NULL REFERENCES cuidadores(id) ON DELETE CASCADE,
    token_hash  CHAR(64) NOT NULL UNIQUE,
    expira_en   TIMESTAMPTZ NOT NULL,
    revocado    BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE pacientes (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre        VARCHAR(100) NOT NULL,
    edad          INTEGER NOT NULL CHECK (edad >= 0),
    padecimientos TEXT NOT NULL DEFAULT '',
    alergias      TEXT[] NOT NULL DEFAULT '{}',
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE medicamentos (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paciente_id        UUID NOT NULL REFERENCES pacientes(id),
    nombre             VARCHAR(100) NOT NULL,
    indicacion         VARCHAR(100) NOT NULL,
    unidades_por_dosis INTEGER NOT NULL DEFAULT 1 CHECK (unidades_por_dosis > 0),
    cantidad           INTEGER NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    umbral             INTEGER NOT NULL DEFAULT 0 CHECK (umbral >= 0),
    enviado_a_farmacia BOOLEAN NOT NULL DEFAULT FALSE,
    activo             BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Horas diarias en que se debe dar cada medicamento
CREATE TABLE horarios (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medicamento_id UUID NOT NULL REFERENCES medicamentos(id) ON DELETE CASCADE,
    hora           TIME NOT NULL,
    activo         BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (medicamento_id, hora)
);

-- Una fila por dosis administrada: es el historial compartido
CREATE TABLE administraciones (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    horario_id     UUID NOT NULL REFERENCES horarios(id),
    medicamento_id UUID NOT NULL REFERENCES medicamentos(id),
    fecha          DATE NOT NULL DEFAULT CURRENT_DATE,
    cuidador_id    UUID NOT NULL REFERENCES cuidadores(id),
    registrada_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Cómo se verificó el medicamento antes de darlo (foto de la etiqueta)
    verificacion   VARCHAR(20) NOT NULL DEFAULT 'omitida'
                   CHECK (verificacion IN ('coincide', 'no_coincide', 'omitida')),
    UNIQUE (horario_id, fecha)            -- una dosis no se registra dos veces el mismo día
);
CREATE INDEX administraciones_fecha_idx ON administraciones (fecha);

CREATE TABLE notas_voz (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuidador_id  UUID NOT NULL REFERENCES cuidadores(id),
    duracion_seg INTEGER NOT NULL CHECK (duracion_seg > 0),
    archivo      TEXT NOT NULL,
    creada_en    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE pedidos_farmacia (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medicamento_id UUID NOT NULL REFERENCES medicamentos(id),
    cuidador_id    UUID NOT NULL REFERENCES cuidadores(id),
    estado         VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    creado_en      TIMESTAMPTZ NOT NULL DEFAULT now()
);
