-- Credenciales SMTP por usuario, protegidas con Supabase Vault.
-- La columna users.contrasena_email_app conserva solo el UUID del secreto.
-- Nunca almacene la contraseña de aplicación en texto plano en public.users.

create extension if not exists supabase_vault with schema vault;

create or replace function public.guardar_credencial_email_usuario(
  p_usuario_id uuid,
  p_correo_email text,
  p_contrasena_app text
)
returns void
language plpgsql
security definer
set search_path = public, vault
as $$
declare
  v_secret_id uuid;
  v_nombre_secret text := 'smtp_app_' || p_usuario_id::text;
begin
  if coalesce(trim(p_correo_email), '') = '' then
    raise exception 'El correo de envío es obligatorio';
  end if;

  if coalesce(trim(p_contrasena_app), '') = '' then
    raise exception 'La contraseña de aplicación es obligatoria';
  end if;

  select id into v_secret_id
  from vault.secrets
  where name = v_nombre_secret
  limit 1;

  if v_secret_id is null then
    v_secret_id := vault.create_secret(
      p_contrasena_app,
      v_nombre_secret,
      'Contraseña SMTP de la cuenta configurada para el usuario'
    );
  else
    perform vault.update_secret(v_secret_id, p_contrasena_app, v_nombre_secret);
  end if;

  update public.users
  set correo_email = lower(trim(p_correo_email)),
      contrasena_email_app = v_secret_id::text
  where id = p_usuario_id;

  if not found then
    raise exception 'Usuario no encontrado';
  end if;
end;
$$;

-- Esta función solo se invoca desde el backend con la clave service_role.
-- Nunca debe ser llamada desde Flutter ni exponerse a usuarios finales.
create or replace function public.obtener_credencial_email_usuario(p_usuario_id uuid)
returns table(correo_email text, contrasena_app text)
language sql
security definer
set search_path = public, vault
as $$
  select u.correo_email, v.decrypted_secret
  from public.users u
  join vault.decrypted_secrets v on v.id::text = u.contrasena_email_app
  where u.id = p_usuario_id
    and u.active = true
    and u.correo_email is not null;
$$;

revoke all on function public.guardar_credencial_email_usuario(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.obtener_credencial_email_usuario(uuid)
  from public, anon, authenticated;
grant execute on function public.guardar_credencial_email_usuario(uuid, text, text)
  to service_role;
grant execute on function public.obtener_credencial_email_usuario(uuid)
  to service_role;

-- Ejecútelo solo desde el backend (service_role), no pegando una clave real en SQL:
-- select public.guardar_credencial_email_usuario(
--   '<UUID_DEL_USUARIO>',
--   'correo@dominio.com',
--   '<CONTRASENA_DE_APLICACION>'
-- );
