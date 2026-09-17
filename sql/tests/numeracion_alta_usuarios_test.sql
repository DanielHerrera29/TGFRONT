-- SOLO entorno de pruebas, después de la migración de numeración.
-- ROLLBACK conserva filas reales; las secuencias identity pueden avanzar.
begin;
do $$
declare a uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); sin_placa uuid:=gen_random_uuid();
 clave uuid; cliente uuid:=gen_random_uuid(); datos jsonb; r jsonb; repetida jsonb;
begin
 if exists(select 1 from public.orden_contadores_placa where prefijo in ('Z998','Z997','Z996')) then
  raise exception 'Los prefijos de prueba ya existen. Usar una base de pruebas limpia.';
 end if;
 insert into public.users(id,name,email,password,role,active) values(a,'ADMIN TEST',a||'@test.invalid',gen_random_uuid()::text,'admin',true);
 perform public.crear_usuario_con_placas(a,u,'ESCOLTA TEST',u||'@test.invalid','solo_fixture_123','operator','+573144672648',array['QZZ998','QZZ997']);
 perform public.crear_usuario_con_placas(a,u,'ESCOLTA TEST',u||'@test.invalid','solo_fixture_123','operator','+573144672648',array['QZZ998','QZZ997']);
 if (select count(*) from public.usuario_vehiculos_escolta where usuario_id=u)<>2 then raise exception 'Alta duplicó placas'; end if;
 perform public.crear_usuario_con_placas(a,sin_placa,'SIN PLACA',sin_placa||'@test.invalid','solo_fixture_123','operator',null,'{}'::text[]);
 if exists(select 1 from public.usuario_vehiculos_escolta where usuario_id=sin_placa) then raise exception 'Alta sin placas incorrecta'; end if;
 datos:=jsonb_build_object('clientOrderId',cliente,'version',0,'confirmar',false,'empresa','PRUEBA','placaCamabaja','AAA111','placaEscolta','QZZ998',
   'viajes',jsonb_build_array(jsonb_build_object('clientItemId',gen_random_uuid(),'maquina','PRUEBA','origen','ORIGEN','destino','DESTINO')));
 r:=public.guardar_orden_servicios(u,gen_random_uuid(),datos);
 if r->>'codigoOrden' is not null or exists(select 1 from public.orden_contadores_placa where placa='QZZ998') then raise exception 'Borrador consumió número'; end if;
 datos:=datos||jsonb_build_object('version',1,'confirmar',true); clave:=gen_random_uuid();
 r:=public.guardar_orden_servicios(u,clave,datos);
 repetida:=public.guardar_orden_servicios(u,clave,datos);
 if r->>'codigoOrden' is distinct from 'Z998-1' or repetida is distinct from r then raise exception 'Numeración o reintento incorrecto'; end if;
 if (select ultimo from public.orden_contadores_placa where placa='QZZ998')<>1 then raise exception 'Reintento incrementó número'; end if;
 datos:=datos||jsonb_build_object('clientOrderId',gen_random_uuid(),'version',0);
 r:=public.guardar_orden_servicios(u,gen_random_uuid(),datos);
 if r->>'codigoOrden' is distinct from 'Z998-2' then raise exception 'Segunda orden incorrecta'; end if;
 datos:=datos||jsonb_build_object('clientOrderId',gen_random_uuid(),'placaEscolta','QZZ997');
 r:=public.guardar_orden_servicios(u,gen_random_uuid(),datos);
 if r->>'codigoOrden' is distinct from 'Z997-1' then raise exception 'Contador de otra placa incorrecto'; end if;
 begin
  perform public.guardar_orden_servicios(u,gen_random_uuid(),datos||jsonb_build_object('clientOrderId',gen_random_uuid(),'placaEscolta','QZZ996'));
  raise exception 'Permitió placa ajena';
 exception when invalid_parameter_value then null;
 end;
 if exists(select 1 from public.orden_contadores_placa where placa='QZZ996') then raise exception 'Fallo dejó contador consumido'; end if;
 raise notice 'Pruebas de numeración, reintento y alta atómica aprobadas.';
end $$;
rollback;
