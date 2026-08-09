-- Ejecutar una vez en Supabase antes de publicar esta version.
-- Elimina el limite anterior de ocho viajes por orden.
alter table public.ordenes_escolta_items
  drop constraint if exists ordenes_escolta_items_posicion_check;

alter table public.ordenes_escolta_items
  alter column posicion type integer;

alter table public.ordenes_escolta_items
  add constraint ordenes_escolta_items_posicion_positiva check (posicion > 0);

alter table public.ordenes_escolta
  add column if not exists email_enviado_at timestamptz,
  add column if not exists email_error text;
