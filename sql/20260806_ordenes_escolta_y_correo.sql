-- Ordenes internas de escolta. No corresponden a Remesas RNDC.
CREATE TABLE IF NOT EXISTS public.ordenes_escolta (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consecutivo bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  fecha date NOT NULL DEFAULT current_date,
  empresa text,
  placa_camabaja text,
  placa_escolta text,
  nombre_escolta text,
  observaciones text,
  destinatario_email text NOT NULL DEFAULT 'transportegutierrezremesas@gmail.com',
  created_by uuid REFERENCES public.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ordenes_escolta_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  orden_id uuid NOT NULL REFERENCES public.ordenes_escolta(id) ON DELETE CASCADE,
  posicion smallint NOT NULL CHECK (posicion BETWEEN 1 AND 8),
  maquina text,
  origen text,
  destino text,
  CONSTRAINT ordenes_escolta_items_unica_posicion UNIQUE (orden_id, posicion)
);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS correo_email text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS contrasena_email_app text;

-- La columna contrasena_email_app debe guardar solo un valor cifrado por el backend.
-- No insertar ni actualizar la clave real desde SQL, Flutter o la consola del navegador.
CREATE INDEX IF NOT EXISTS ordenes_escolta_created_at_idx
  ON public.ordenes_escolta (created_at DESC);
