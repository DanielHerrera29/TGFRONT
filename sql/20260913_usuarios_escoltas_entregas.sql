-- BORRADOR DE DISEÑO, NO APLICAR. Para contactos y vehículos usar
-- 20260913_contactos_whatsapp_usuarios.sql. Numeración y perfiles de este
-- borrador requieren consolidación con ese incremento antes de ejecutarse.
-- Incremento aditivo. No elimina usuarios, escoltas ni órdenes existentes.
-- Aplicar antes del frontend/backend de este incremento. No ejecuta envíos.
begin;
alter table public.users add column if not exists whatsapp text;
alter table public.users add constraint users_whatsapp_formato check
  (whatsapp is null or whatsapp ~ '^\+[1-9][0-9]{7,14}$') not valid;

create table public.escolta_perfiles (
 usuario_id uuid primary key references public.users(id) on delete restrict,
 activo boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.escolta_vehiculos (
 id uuid primary key default gen_random_uuid(),
 placa text not null unique check (placa ~ '^[A-Z]{3}[0-9]{3}$'),
 activo boolean not null default true
);
create table public.escolta_usuario_vehiculos (
 usuario_id uuid not null references public.escolta_perfiles(usuario_id) on delete restrict,
 vehiculo_id uuid not null references public.escolta_vehiculos(id) on delete restrict,
 activo boolean not null default true,
 primary key(usuario_id,vehiculo_id)
);
-- Solo se importa el catálogo de placas válidas. No se infiere identidad por nombre o teléfono.
insert into public.escolta_vehiculos(placa)
select distinct upper(trim(placa)) from public.escoltas
where upper(trim(placa)) ~ '^[A-Z]{3}[0-9]{3}$' on conflict(placa) do nothing;

create table public.configuracion_escoltas (
 id boolean primary key default true check(id),
 whatsapp_destino text not null default '+573144672648' check(whatsapp_destino ~ '^\+[1-9][0-9]{7,14}$'),
 placa_base text not null default 'ESCOLTA' check(placa_base = 'ESCOLTA'),
 updated_at timestamptz not null default now()
);
-- Confirmado por TEG el 2026-09-13: numeración por placa del escolta.
insert into public.configuracion_escoltas(id) values(true);
create table public.orden_contadores_placa (
 placa text primary key check(placa ~ '^[A-Z]{3}[0-9]{3}$'),
 prefijo text not null unique,
 ultimo bigint not null check(ultimo>0)
);
alter table public.ordenes_escolta
 add column if not exists codigo_orden text,
 add column if not exists numero_placa bigint,
 add column if not exists placa_numeracion text,
 add column if not exists escolta_usuario_id uuid references public.escolta_perfiles(usuario_id),
 add column if not exists escolta_whatsapp_snapshot text;
create unique index ordenes_codigo_orden_unique on public.ordenes_escolta(codigo_orden) where codigo_orden is not null;
create unique index ordenes_numero_por_placa_unique on public.ordenes_escolta(placa_numeracion,numero_placa) where numero_placa is not null;

create table public.orden_entrega_conciliaciones (
 id uuid primary key default gen_random_uuid(),
 orden_id uuid not null references public.ordenes_escolta(id),
 usuario_id uuid not null references public.users(id),
 resultado text not null check(resultado in ('ENVIADA','NO_ENVIADA')),
 evidencia text not null check(length(trim(evidencia))>=15),
 created_at timestamptz not null default now()
);

alter table public.escolta_perfiles enable row level security;
alter table public.escolta_vehiculos enable row level security;
alter table public.escolta_usuario_vehiculos enable row level security;
alter table public.configuracion_escoltas enable row level security;
alter table public.orden_contadores_placa enable row level security;
alter table public.orden_entrega_conciliaciones enable row level security;
revoke all on public.escolta_perfiles,public.escolta_vehiculos,public.escolta_usuario_vehiculos,
 public.configuracion_escoltas,public.orden_contadores_placa,public.orden_entrega_conciliaciones from public,anon,authenticated;
grant all on public.escolta_perfiles,public.escolta_vehiculos,public.escolta_usuario_vehiculos,
 public.configuracion_escoltas,public.orden_contadores_placa,public.orden_entrega_conciliaciones to service_role;

create or replace function public.asignar_codigo_orden(p_orden uuid) returns text
language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.ordenes_escolta; b text; v_placa text; v_prefijo text; n bigint;
begin
 select * into strict o from public.ordenes_escolta where id=p_orden for update;
 if o.codigo_orden is not null then return o.codigo_orden; end if;
 if o.estado_captura <> 'CONFIRMADA' then return null; end if;
 select placa_base into b from public.configuracion_escoltas where id;
 if b is null then raise exception using errcode='22023',message='Administración debe definir la placa base de numeración.'; end if;
 v_placa := case b when 'ESCOLTA' then o.placa_escolta else o.placa_camabaja end;
 if v_placa is null or v_placa !~ '^[A-Z]{3}[0-9]{3}$' then raise exception using errcode='22023',message='La placa base debe tener tres letras y tres números.'; end if;
 v_prefijo := right(v_placa,4);
 -- El UPSERT serializa órdenes concurrentes de la misma placa.
 begin
 insert into public.orden_contadores_placa as c(placa,prefijo,ultimo) values(v_placa,v_prefijo,1)
 on conflict(placa) do update set ultimo=c.ultimo+1 returning ultimo into n;
 exception when unique_violation then
 raise exception using errcode='22023',message='Otra placa utiliza el mismo prefijo. Administración debe resolver la colisión antes de numerar.';
 end;
 update public.ordenes_escolta set placa_numeracion=v_placa,numero_placa=n,codigo_orden=v_prefijo||'-'||n where id=p_orden;
 return v_prefijo||'-'||n;
end $$;
revoke all on function public.asignar_codigo_orden(uuid) from public,anon,authenticated,service_role;

create or replace function public.conciliar_entrega_orden(p_usuario uuid,p_orden uuid,p_resultado text,p_evidencia text,p_version timestamptz)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.orden_entrega_control;
begin
 if not exists(select 1 from public.users where id=p_usuario and active and role='admin') then raise exception using errcode='42501',message='Solo administración puede conciliar.'; end if;
 if p_resultado is null or p_resultado not in ('ENVIADA','NO_ENVIADA') or length(trim(coalesce(p_evidencia,'')))<15 then raise exception using errcode='22023',message='Indique resultado y evidencia del proveedor.'; end if;
 perform 1 from public.ordenes_escolta where id=p_orden for update;
 select * into e from public.orden_entrega_control where orden_id=p_orden for update;
 if not found or e.estado <> 'POR_VERIFICAR' or e.updated_at is distinct from p_version then raise exception using errcode='P0001',message='La entrega cambió o sigue en curso. Actualice antes de conciliar.'; end if;
 insert into public.orden_entrega_conciliaciones(orden_id,usuario_id,resultado,evidencia) values(p_orden,p_usuario,p_resultado,trim(p_evidencia));
 update public.orden_entrega_control set estado=case p_resultado when 'ENVIADA' then 'ENVIADA' else 'ERROR_PREVIO' end,updated_at=now() where orden_id=p_orden;
 update public.ordenes_escolta set email_enviado_at=case when p_resultado='ENVIADA' then now() else null end,
 email_error=case when p_resultado='NO_ENVIADA' then 'Administración verificó que no fue enviada. Puede reintentar.' else null end where id=p_orden;
end $$;
revoke all on function public.conciliar_entrega_orden(uuid,uuid,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.conciliar_entrega_orden(uuid,uuid,text,text,timestamptz) to service_role;
commit;
