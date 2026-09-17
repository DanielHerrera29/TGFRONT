-- SOLO LECTURA. Ejecutar en una consulta nueva del editor SQL.
-- Devuelve estructura y permisos; no devuelve órdenes, personas ni contraseñas.
with objetivos(nombre) as (
 values ('servicios'), ('servicio_trayectos'), ('orden_operaciones'),
        ('ordenes_escolta'), ('ordenes_escolta_items'), ('clientes'), ('users')
), relaciones as (
 select c.oid,c.relname,c.relkind,c.relrowsecurity,c.relforcerowsecurity,c.reltuples
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 join objetivos o on o.nombre=c.relname
 where n.nspname='public'
)
select jsonb_pretty(jsonb_build_object(
 'objetos', (select jsonb_agg(jsonb_build_object(
   'nombre',o.nombre,'existe',r.oid is not null,'tipo',r.relkind,
   'rls',r.relrowsecurity,'force_rls',r.relforcerowsecurity,
   'filas_estimadas_no_conteo',r.reltuples
 ) order by o.nombre) from objetivos o left join relaciones r on r.relname=o.nombre),
 'columnas', (select coalesce(jsonb_agg(jsonb_build_object(
   'tabla',r.relname,'columna',a.attname,'tipo',format_type(a.atttypid,a.atttypmod),
   'not_null',a.attnotnull,'identity',a.attidentity,'generated',a.attgenerated,
   'default_o_expresion',case when a.attname in ('password','contrasena_email_app') then '[omitido]'
     else pg_get_expr(d.adbin,d.adrelid) end
 ) order by r.relname,a.attnum),'[]'::jsonb)
 from relaciones r join pg_attribute a on a.attrelid=r.oid and a.attnum>0 and not a.attisdropped
 left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum),
 'restricciones', (select coalesce(jsonb_agg(jsonb_build_object(
   'tabla',r.relname,'nombre',c.conname,'tipo',c.contype,'validada',c.convalidated,
   'definicion',pg_get_constraintdef(c.oid)
 ) order by r.relname,c.conname),'[]'::jsonb)
 from relaciones r join pg_constraint c on c.conrelid=r.oid),
 'referencias_entrantes', (select coalesce(jsonb_agg(jsonb_build_object(
   'tabla_origen',c.conrelid::regclass::text,'tabla_destino',r.relname,
   'nombre',c.conname,'definicion',pg_get_constraintdef(c.oid)
 )),'[]'::jsonb) from relaciones r join pg_constraint c on c.confrelid=r.oid and c.contype='f'),
 'indices', (select coalesce(jsonb_agg(to_jsonb(i) order by i.tablename,i.indexname),'[]'::jsonb)
   from pg_indexes i join objetivos o on o.nombre=i.tablename where i.schemaname='public'),
 'politicas', (select coalesce(jsonb_agg(to_jsonb(p) order by p.tablename,p.policyname),'[]'::jsonb)
   from pg_policies p join objetivos o on o.nombre=p.tablename where p.schemaname='public'),
 'permisos_tablas', (select coalesce(jsonb_agg(jsonb_build_object(
   'tabla',g.table_name,'rol',g.grantee,'permiso',g.privilege_type
 ) order by g.table_name,g.grantee,g.privilege_type),'[]'::jsonb)
 from information_schema.table_privileges g join objetivos o on o.nombre=g.table_name
 where g.table_schema='public'),
 'triggers', (select coalesce(jsonb_agg(jsonb_build_object(
   'tabla',r.relname,'nombre',t.tgname,'habilitado',t.tgenabled,
   'definicion',pg_get_triggerdef(t.oid),'funcion',t.tgfoid::regprocedure::text
 ) order by r.relname,t.tgname),'[]'::jsonb)
 from relaciones r join pg_trigger t on t.tgrelid=r.oid where not t.tgisinternal),
 'funciones_incremento', (select coalesce(jsonb_agg(jsonb_build_object(
   'nombre',p.proname,'argumentos',pg_get_function_identity_arguments(p.oid),
   'retorno',pg_get_function_result(p.oid),'security_definer',p.prosecdef,
   'configuracion',p.proconfig,'permisos',p.proacl::text,
   'huella_definicion',md5(pg_get_functiondef(p.oid))
 )),'[]'::jsonb) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('guardar_orden_servicios','listar_servicios_operativos'))
)) as diagnostico;
