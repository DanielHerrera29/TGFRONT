-- Ejecutar una sola vez en el SQL Editor de Supabase.
-- El bucket privado `ordenes-escolta` ya fue creado desde el panel.

alter table public.ordenes_escolta
  add column if not exists pdf_path text,
  add column if not exists pdf_tamano_bytes bigint,
  add column if not exists pdf_generado_at timestamptz,
  add column if not exists pdf_eliminado_at timestamptz;

alter table public.ordenes_escolta
  add constraint ordenes_escolta_pdf_tamano_positivo
  check (pdf_tamano_bytes is null or pdf_tamano_bytes > 0);

create index if not exists ordenes_escolta_created_by_idx
  on public.ordenes_escolta (created_by, created_at desc);

create index if not exists ordenes_escolta_pdf_retencion_idx
  on public.ordenes_escolta (pdf_generado_at)
  where pdf_path is not null;
