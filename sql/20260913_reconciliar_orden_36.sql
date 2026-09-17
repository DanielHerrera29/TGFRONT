-- Reparación puntual para revisión y ejecución en el SQL Editor de Supabase.
-- Evidencia observada: Brevo > Transaccional > Logs, sin filtros de destinatario,
-- intervalo 06/09/2026 a 13/09/2026: 0 logs. Orden 36 bloqueada desde
-- 12/09/2026 19:33:25.871637 -05, antes del despliegue 2957697.
-- Ejecutar solo si esta cuenta Brevo corresponde a la clave configurada en Render.
-- NO envía correo ni modifica el PDF, viajes, servicios o consecutivo.
begin;

create table if not exists public.orden_entrega_reparaciones (
 id bigint generated always as identity primary key,
 orden_id uuid not null references public.ordenes_escolta(id) on delete restrict,
 version_anterior timestamptz not null,
 estado_anterior jsonb not null,
 evidencia text not null,
 ejecutado_por text not null default session_user,
 created_at timestamptz not null default now(),
 unique(orden_id,version_anterior)
);
alter table public.orden_entrega_reparaciones enable row level security;
revoke all on public.orden_entrega_reparaciones from public,anon,authenticated;

do $$
declare
 v_id constant uuid := '7372e318-514d-4990-8451-9f24fad1a33b';
 v_version constant timestamptz := '2026-09-12T19:33:25.871637-05:00';
 v_o public.ordenes_escolta;
 v_e public.orden_entrega_control;
begin
 select * into strict v_o from public.ordenes_escolta where id=v_id for update;
 select * into strict v_e from public.orden_entrega_control where orden_id=v_id for update;
 if exists(select 1 from public.orden_entrega_reparaciones where orden_id=v_id and version_anterior=v_version) then
   raise notice 'Esta reparación ya fue aplicada. No se modifica la entrega actual.';
   return;
 end if;
 if v_o.consecutivo <> 36 or v_o.estado_captura <> 'CONFIRMADA'
    or v_o.email_enviado_at is not null or v_e.estado <> 'POR_VERIFICAR'
    or v_e.updated_at is distinct from v_version then
   raise exception 'La orden o la entrega cambió. Se cancela la reparación; revisar el estado actual.';
 end if;
 insert into public.orden_entrega_reparaciones(orden_id,version_anterior,estado_anterior,evidencia)
 values(v_id,v_version,jsonb_build_object('entrega',to_jsonb(v_e),'email_error',v_o.email_error),
   'Brevo Logs revisado el 2026-09-13: 0 logs en 06/09/2026 a 13/09/2026, sin filtro de destinatario. Se habilita reintento manual de la orden 36.');
 update public.orden_entrega_control set estado='ERROR_PREVIO',updated_at=now() where orden_id=v_id;
 update public.ordenes_escolta set email_error='Revisada en Brevo sin registro de envío. Puede reintentar esta misma orden.' where id=v_id;
end $$;

select o.consecutivo,e.estado as estado_entrega,o.email_enviado_at,o.email_error
from public.ordenes_escolta o join public.orden_entrega_control e on e.orden_id=o.id
where o.id='7372e318-514d-4990-8451-9f24fad1a33b';
commit;
