-- Ejecutar en desarrollo después de 20260919_gestion_clientes_placas.sql.
-- Todas las fixtures se revierten al terminar.
begin;
do $$
declare a uuid:=gen_random_uuid(); o uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); r jsonb;
begin
 insert into public.users(id,name,email,password,role) values
 (a,'Prueba admin',a::text||'@example.invalid','fixture-no-login','admin'),
 (o,'Prueba operador',o::text||'@example.invalid','fixture-no-login','operator');
 begin
  perform public.registrar_cliente_placas(o,c,'empresa','Fixture','99887766554433221100',array['ABC123']);
  raise exception 'FALLO: operador pudo crear cliente';
 exception when insufficient_privilege then null; end;
 r:=public.registrar_cliente_placas(a,c,'empresa','Fixture','99887766554433221100',array['ABC123','MNB124']);
 perform public.registrar_cliente_placas(a,c,'empresa','Fixture','99887766554433221100',array['ABC123','MNB124']);
 if (select count(*) from public.cliente_placas where cliente_id=c)<>2 then raise exception 'FALLO: duplicado'; end if;
 perform public.registrar_cliente_placas(a,c,'empresa','Fixture','99887766554433221100',array['LLO001']);
 if (select count(*) from public.cliente_placas where cliente_id=c)<>3 then raise exception 'FALLO: perdió placas previas'; end if;
 begin
  perform public.registrar_cliente_placas(a,c,'empresa','Fixture','99887766554433221100',array['MAL']);
  raise exception 'FALLO: aceptó placa inválida';
 exception when invalid_parameter_value then null; end;
 if not exists(select 1 from jsonb_array_elements(public.clientes_para_orden(o)) x where x->>'id'=c::text and jsonb_array_length(x->'placas_carga')=3)
 then raise exception 'FALLO: catálogo no contiene placas'; end if;
 begin
  perform public.usuarios_para_gestion(o);
  raise exception 'FALLO: operador consultó usuarios';
 exception when insufficient_privilege then null; end;
 if exists(select 1 from jsonb_array_elements(public.usuarios_para_gestion(a)) x where x ? 'password') then raise exception 'FALLO: expone clave'; end if;
end $$;
rollback;
