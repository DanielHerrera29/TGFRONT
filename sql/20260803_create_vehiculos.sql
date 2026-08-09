-- Ejecutar en Supabase SQL Editor para corregir PGRST205.
CREATE TABLE IF NOT EXISTS public.vehiculos (
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

ALTER TABLE public.vehiculos DISABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.vehiculos TO anon;

NOTIFY pgrst, 'reload schema';
