-- Confirmación de acceso al teléfono; NO acredita cargo profesional.
-- Aplicar en desarrollo antes de activar FirmaOtp__Required en Render.
begin;
create table public.orden_firma_verificaciones (
 id uuid primary key default gen_random_uuid(),
 orden_id uuid not null references public.ordenes_escolta(id),
 usuario_id uuid not null references public.users(id),
 nombre text not null check(length(nombre) between 3 and 150),
 telefono text not null check(telefono ~ '^\+[1-9][0-9]{7,14}$'),
 proveedor_sid text unique,
 estado text not null default 'SOLICITANDO' check(estado in ('SOLICITANDO','PENDIENTE','COMPROBANDO','VERIFICADA','RECHAZADA')),
 intentos integer not null default 0 check(intentos between 0 and 5),
 created_at timestamptz not null default now(),
 vence_at timestamptz not null default now()+interval '10 minutes',
 verificada_at timestamptz
);
create index on public.orden_firma_verificaciones(orden_id);
create index on public.orden_firma_verificaciones(telefono,created_at);
create index on public.orden_firma_verificaciones(usuario_id,created_at);
alter table public.orden_firma_verificaciones enable row level security;
revoke all on public.orden_firma_verificaciones from public,anon,authenticated;
grant select,insert,update on public.orden_firma_verificaciones to service_role;

create function public.firma_otp_operacion(p_usuario uuid,p_orden uuid,p_accion text,p_id uuid default null,p_nombre text default null,p_telefono text default null,p_sid text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.orden_firma_verificaciones; n integer;
begin
 if not exists(select 1 from public.users where id=p_usuario and active and role in ('admin','operator','administrativo','escolta'))
 or not exists(select 1 from public.ordenes_escolta where id=p_orden and created_by=p_usuario and estado_captura in ('BORRADOR','CONFIRMADA')) then
 return jsonb_build_object('error','Orden no disponible para este usuario'); end if;
 perform pg_advisory_xact_lock(hashtextextended('firma_usuario:'||p_usuario::text,0));
 if p_accion='AUTORIZAR' then
 return jsonb_build_object('autorizada',exists(select 1 from public.orden_firma_verificaciones where orden_id=p_orden and usuario_id=p_usuario and estado='VERIFICADA'));
 end if;
 if p_accion='SOLICITAR' then
 if p_telefono is null or p_telefono !~ '^\+[1-9][0-9]{7,14}$' or length(trim(coalesce(p_nombre,''))) not between 3 and 150 then
 return jsonb_build_object('error','Revise nombre y teléfono con código de país'); end if;
 perform pg_advisory_xact_lock(hashtextextended('firma_telefono:'||p_telefono,0));
 select * into v from public.orden_firma_verificaciones where orden_id=p_orden and usuario_id=p_usuario and telefono=p_telefono and nombre=trim(p_nombre) and (estado='VERIFICADA' or vence_at>now()) order by created_at desc limit 1;
 if found then return to_jsonb(v); end if;
 if exists(select 1 from public.orden_firma_verificaciones where telefono=p_telefono and vence_at>now() and estado<>'VERIFICADA') then
 return jsonb_build_object('error','Este teléfono tiene una solicitud en curso. Espere diez minutos antes de solicitar otra'); end if;
 select count(*) into n from public.orden_firma_verificaciones where usuario_id=p_usuario and created_at>now()-interval '1 hour';
 if n>=10 then return jsonb_build_object('error','Límite de solicitudes por hora alcanzado'); end if;
 select count(*) into n from public.orden_firma_verificaciones where telefono=p_telefono and created_at>now()-interval '1 hour';
 if n>=5 then return jsonb_build_object('error','Límite de solicitudes para este teléfono alcanzado'); end if;
 insert into public.orden_firma_verificaciones(orden_id,usuario_id,nombre,telefono) values(p_orden,p_usuario,trim(p_nombre),p_telefono) returning * into v;
 return to_jsonb(v)||jsonb_build_object('enviar',true);
 end if;
 select * into v from public.orden_firma_verificaciones where id=p_id and orden_id=p_orden and usuario_id=p_usuario for update;
 if not found then return jsonb_build_object('error','Solicitud no encontrada'); end if;
 if v.estado='VERIFICADA' then return to_jsonb(v); end if;
 if v.vence_at<=now() then return jsonb_build_object('error','El código venció. Solicite uno nuevo'); end if;
 if p_accion='ENVIADO' and v.estado='SOLICITANDO' and p_sid ~ '^VE[0-9a-fA-F]{32}$' then
 update public.orden_firma_verificaciones set proveedor_sid=p_sid,estado='PENDIENTE' where id=v.id returning * into v;
 elsif p_accion='COMPROBAR' and v.estado='PENDIENTE' and v.intentos<5 then
 update public.orden_firma_verificaciones set intentos=intentos+1,estado='COMPROBANDO' where id=v.id returning * into v;
 elsif p_accion in ('APROBAR','INCORRECTO') and v.estado='COMPROBANDO' then
 update public.orden_firma_verificaciones set estado=case when p_accion='APROBAR' then 'VERIFICADA' when intentos>=5 then 'RECHAZADA' else 'PENDIENTE' end,verificada_at=case when p_accion='APROBAR' then now() end where id=v.id returning * into v;
 else return jsonb_build_object('error','Solicitud en curso o intentos agotados. No vuelva a enviar a ciegas');
 end if;
 return to_jsonb(v);
end $$;
revoke all on function public.firma_otp_operacion(uuid,uuid,text,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.firma_otp_operacion(uuid,uuid,text,uuid,text,text,text) to service_role;
commit;


