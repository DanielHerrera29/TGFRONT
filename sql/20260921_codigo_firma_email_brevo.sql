-- Código por CORREO para habilitar Firmar antes de dibujar la firma.
-- Independiente de la propuesta anterior de WhatsApp. No borra tablas existentes.
begin;
create table public.orden_firma_codigos_email (
 id uuid primary key,
 orden_id uuid not null references public.ordenes_escolta(id),
 usuario_id uuid not null references public.users(id),
 nombre text not null check(length(nombre) between 3 and 150),
 email text not null check(length(email)<=254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
 codigo_hash text not null check(codigo_hash ~ '^[A-F0-9]{64}$'),
 mensaje_id text,
 estado text not null default 'SOLICITANDO' check(estado in ('SOLICITANDO','PENDIENTE','VERIFICADA','RECHAZADA')),
 intentos integer not null default 0 check(intentos between 0 and 5),
 created_at timestamptz not null default now(),
 vence_at timestamptz not null default now()+interval '10 minutes',
 verificada_at timestamptz
);
create index on public.orden_firma_codigos_email(orden_id,usuario_id);
create index on public.orden_firma_codigos_email(email,created_at);
create index on public.orden_firma_codigos_email(usuario_id,created_at);
create index on public.orden_firma_codigos_email(created_at);
alter table public.orden_firma_codigos_email enable row level security;
revoke all on public.orden_firma_codigos_email from public,anon,authenticated;
grant select,insert,update on public.orden_firma_codigos_email to service_role;

create function public.firma_codigo_email_operacion(p_usuario uuid,p_orden uuid,p_accion text,p_id uuid default null,p_nombre text default null,p_email text default null,p_hash text default null,p_message text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.orden_firma_codigos_email; n integer; acierto boolean;
begin
 if not exists(select 1 from public.users where id=p_usuario and active and role in ('admin','operator','administrativo','escolta'))
 or not exists(select 1 from public.ordenes_escolta where id=p_orden and created_by=p_usuario and estado_captura in ('BORRADOR','CONFIRMADA')) then
 return jsonb_build_object('error','Orden no disponible para este usuario'); end if;
 perform pg_advisory_xact_lock(hashtextextended('firma_email_usuario:'||p_usuario::text,0));
 if p_accion='AUTORIZAR' then
 return jsonb_build_object('autorizada',exists(select 1 from public.orden_firma_codigos_email where orden_id=p_orden and usuario_id=p_usuario and estado='VERIFICADA'));
 end if;
 if p_accion='SOLICITAR' then
 if p_id is null or p_email is null or length(p_email)>254 or p_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
 or p_hash is null or p_hash !~ '^[A-F0-9]{64}$' or length(trim(coalesce(p_nombre,''))) not between 3 and 150 then
 return jsonb_build_object('error','Revise nombre y correo del arquitecto'); end if;
 p_email:=lower(trim(p_email));
 -- Serializa la reserva del cupo diario, también entre usuarios diferentes.
 perform pg_advisory_xact_lock(hashtextextended('firma_email_cupo',0));
 select * into v from public.orden_firma_codigos_email where orden_id=p_orden and usuario_id=p_usuario and email=p_email and nombre=trim(p_nombre) and (estado='VERIFICADA' or vence_at>now()) order by created_at desc limit 1;
 if found then return to_jsonb(v)-'codigo_hash'; end if;
 if exists(select 1 from public.orden_firma_codigos_email where orden_id=p_orden and usuario_id=p_usuario and vence_at>now() and estado<>'VERIFICADA') then
 return jsonb_build_object('error','La orden tiene un código en curso. Espere diez minutos antes de cambiar el correo'); end if;
 select count(*) into n from public.orden_firma_codigos_email where usuario_id=p_usuario and created_at>now()-interval '1 hour';
 if n>=10 then return jsonb_build_object('error','Límite de solicitudes por hora alcanzado'); end if;
 select count(*) into n from public.orden_firma_codigos_email where email=p_email and created_at>now()-interval '1 hour';
 if n>=5 then return jsonb_build_object('error','Límite de solicitudes para este correo alcanzado'); end if;
 -- Margen sobre el cupo de 300/día. Ventana móvil conservadora, sin colas de códigos vencidos.
 select count(*) into n from public.orden_firma_codigos_email where created_at>now()-interval '24 hours';
 if n>=280 then return jsonb_build_object('error','Cupo de códigos temporalmente agotado. Intente más tarde'); end if;
 insert into public.orden_firma_codigos_email(id,orden_id,usuario_id,nombre,email,codigo_hash) values(p_id,p_orden,p_usuario,trim(p_nombre),p_email,p_hash) returning * into v;
 return (to_jsonb(v)-'codigo_hash')||jsonb_build_object('enviar',true);
 end if;
 select * into v from public.orden_firma_codigos_email where id=p_id and orden_id=p_orden and usuario_id=p_usuario for update;
 if not found then return jsonb_build_object('error','Solicitud no encontrada'); end if;
 if v.estado='VERIFICADA' then return to_jsonb(v)-'codigo_hash'; end if;
 if v.vence_at<=now() then return jsonb_build_object('error','El código venció. Solicite uno nuevo'); end if;
 if p_accion='ENVIADO' and v.estado='SOLICITANDO' and nullif(p_message,'') is not null then
 update public.orden_firma_codigos_email set mensaje_id=p_message,estado='PENDIENTE' where id=v.id returning * into v;
 elsif p_accion='COMPROBAR' and v.estado in ('SOLICITANDO','PENDIENTE') and v.intentos<5 then
 -- Permite comprobar un código recibido aunque se perdiera la respuesta de Brevo.
 acierto := p_hash is not null and p_hash=v.codigo_hash;
 update public.orden_firma_codigos_email set intentos=intentos+1,
 estado=case when acierto then 'VERIFICADA' when intentos+1>=5 then 'RECHAZADA' else estado end,
 verificada_at=case when acierto then now() end where id=v.id returning * into v;
 else return jsonb_build_object('error','Solicitud en curso o intentos agotados'); end if;
 return to_jsonb(v)-'codigo_hash';
end $$;
revoke all on function public.firma_codigo_email_operacion(uuid,uuid,text,uuid,text,text,text,text) from public,anon,authenticated;
grant execute on function public.firma_codigo_email_operacion(uuid,uuid,text,uuid,text,text,text,text) to service_role;
commit;
