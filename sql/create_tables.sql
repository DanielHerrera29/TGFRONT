-- ============================================================
-- CargoDespacho - Sprint 1
-- Automatizador RNDC desde WhatsApp
-- ============================================================
-- Ejecutar desde SQL Editor de Supabase Dashboard
-- ============================================================

-- 1. USERS (email = usuario RNDC, password = contraseña RNDC)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'operator',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. SETTINGS (configuración global de la empresa)
CREATE TABLE IF NOT EXISTS settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_nombre TEXT,
    empresa_nit TEXT NOT NULL,
    empresa_dv TEXT,
    empresa_direccion TEXT,
    empresa_telefono TEXT,
    empresa_ciudad TEXT,
    empresa_municipio_dane TEXT DEFAULT '11001000',
    poliza_numero TEXT,
    poliza_vencimiento TIMESTAMPTZ,
    poliza_aseguradora TEXT,
    poliza_aseguradora_nit TEXT,
    generador_tipo_id TEXT DEFAULT 'N',
    generador_nit TEXT,
    generador_dv TEXT,
    generador_nombre TEXT,
    generador_sede TEXT DEFAULT '00',
    simulacion TEXT DEFAULT 'S',
    consecutivo_remesa INTEGER DEFAULT 1,
    consecutivo_manifiesto INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO settings (empresa_nit)
  SELECT '9003447664'
  WHERE NOT EXISTS (SELECT 1 FROM settings);

-- 3. REMESAS
CREATE TABLE IF NOT EXISTS remesas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consecutivo TEXT,
    tipo_operacion TEXT,
    naturaleza_carga TEXT,
    cantidad NUMERIC(12,2),
    unidad_medida TEXT,
    tipo_empaque TEXT,
    peso_kg NUMERIC(12,2),
    codigo_producto TEXT,
    descripcion_producto TEXT,
    generador_tipo_id TEXT,
    generador_nit TEXT,
    generador_sede TEXT,
    remitente_tipo_id TEXT,
    remitente_nit TEXT,
    remitente_sede TEXT,
    remitente_municipio_dane TEXT,
    destinatario_tipo_id TEXT,
    destinatario_nit TEXT,
    destinatario_sede TEXT,
    destinatario_municipio_dane TEXT,
    poliza_numero TEXT,
    poliza_vencimiento TIMESTAMPTZ,
    poliza_aseguradora TEXT,
    poliza_aseguradora_nit TEXT,
    raw_message TEXT,
    cliente_nombre TEXT,
    obra TEXT,
    observaciones TEXT,
    radicado_rndc TEXT,
    consecutivo_rndc TEXT,
    xml_enviado TEXT,
    xml_respuesta TEXT,
    estado TEXT NOT NULL DEFAULT 'draft',
    error_detalle TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. MANIFIESTOS
CREATE TABLE IF NOT EXISTS manifiestos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    consecutivo TEXT,
    remesa_id UUID REFERENCES remesas(id),
    placa_vehiculo TEXT NOT NULL,
    placa_remolque TEXT,
    conductor_tipo_id TEXT DEFAULT 'C',
    conductor_cedula TEXT NOT NULL,
    conductor_nombre TEXT,
    conductor2_cedula TEXT,
    conductor2_nombre TEXT,
    propietario_tipo_id TEXT,
    propietario_cedula TEXT,
    propietario_nombre TEXT,
    fecha_despacho TIMESTAMPTZ,
    fecha_limite_entrega TIMESTAMPTZ,
    tipo_valor_pactado TEXT DEFAULT 'B',
    valor_viaje NUMERIC(14,2),
    valor_anticipo NUMERIC(14,2),
    municipio_pago_dane TEXT,
    fecha_limite_pago TIMESTAMPTZ,
    resp_cargue TEXT DEFAULT 'D',
    resp_descargue TEXT DEFAULT 'D',
    horas_espera_cargue INTEGER DEFAULT 0,
    horas_espera_descargue INTEGER DEFAULT 0,
    observaciones TEXT,
    aceptacion_electronica TEXT,
    radicado_rndc TEXT,
    numero_autorizacion TEXT,
    xml_enviado TEXT,
    xml_respuesta TEXT,
    pdf_url TEXT,
    estado TEXT NOT NULL DEFAULT 'draft',
    error_detalle TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. VEHICULOS
CREATE TABLE IF NOT EXISTS vehiculos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    num_placa TEXT NOT NULL UNIQUE,
    cod_configuracion_unidad_carga TEXT NOT NULL,
    peso_vehiculo_vacio NUMERIC(12,2),
    cod_tipo_carroceria TEXT NOT NULL,
    cod_tipo_id_tenedor TEXT NOT NULL,
    num_id_tenedor TEXT NOT NULL,
    estado TEXT DEFAULT 'registered',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. DISPATCHES (despachos legacy)
CREATE TABLE IF NOT EXISTS dispatches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raw_message TEXT NOT NULL,
    parsed_json JSONB,
    cliente TEXT,
    conductor TEXT,
    placa TEXT,
    origen TEXT,
    destino TEXT,
    peso NUMERIC(12,2),
    tipo_carga TEXT,
    fecha_cargue DATE,
    hora_cargue TEXT,
    remesa_rndc TEXT,
    manifiesto_rndc TEXT,
    estado TEXT NOT NULL DEFAULT 'draft',
    pdf_url TEXT,
    error_rndc TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- RLS: Deshabilitado para la app CargoDespacho que usa anon key
-- (no usa Supabase Auth, usa login propio contra tabla users)
-- ============================================================
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE settings DISABLE ROW LEVEL SECURITY;
ALTER TABLE remesas DISABLE ROW LEVEL SECURITY;
ALTER TABLE manifiestos DISABLE ROW LEVEL SECURITY;
ALTER TABLE vehiculos DISABLE ROW LEVEL SECURITY;
ALTER TABLE dispatches DISABLE ROW LEVEL SECURITY;

-- ============================================================
-- MIGRACIÓN: agregar columnas faltantes a tablas existentes
-- Ejecutar solo si las tablas ya existen con el schema anterior
-- ============================================================

-- remesas: columnas faltantes
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='remesas' AND column_name='remitente_tipo_id') THEN
        ALTER TABLE remesas ADD COLUMN remitente_tipo_id TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='remesas' AND column_name='poliza_numero') THEN
        ALTER TABLE remesas ADD COLUMN poliza_numero TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='remesas' AND column_name='poliza_vencimiento') THEN
        ALTER TABLE remesas ADD COLUMN poliza_vencimiento TIMESTAMPTZ;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='remesas' AND column_name='poliza_aseguradora') THEN
        ALTER TABLE remesas ADD COLUMN poliza_aseguradora TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='remesas' AND column_name='poliza_aseguradora_nit') THEN
        ALTER TABLE remesas ADD COLUMN poliza_aseguradora_nit TEXT;
    END IF;
END $$;
