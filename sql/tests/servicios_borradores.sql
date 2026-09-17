-- Ejecutar solo en una base de desarrollo con migración aplicada.
-- Todo el fixture revierte; no llama correo ni RNDC.
begin;
do $$
declare
 u uuid := gen_random_uuid(); k uuid := gen_random_uuid(); c uuid := gen_random_uuid();
 i uuid := gen_random_uuid(); p jsonb; a jsonb; b jsonb; sid uuid; denied boolean := false;
begin
 insert into public.users(id,name,email,password,role)
 values(u,'Fixture','fixture-'||u||'@example.invalid','NOT-A-REAL-PASSWORD','operator');
 p := jsonb_build_object('clientOrderId',c,'version',0,'empresa','Prueba','viajes',
   jsonb_build_array(jsonb_build_object('clientItemId',i,'maquina','','origen','','destino','')));
 a := public.guardar_orden_servicios(u,k,p);
 b := public.guardar_orden_servicios(u,k,p);
 assert a=b, 'Reintento debe devolver mismo resultado';
 assert (select count(*) from public.servicios where created_by=u)=1, 'Un solo servicio';
 sid := (a->'items'->0->>'servicioId')::uuid;
 p := jsonb_set(p,'{version}','1');
 p := jsonb_set(p,'{viajes,0,maquina}','"Completada"');
 b := public.guardar_orden_servicios(u,gen_random_uuid(),p);
 assert (b->'items'->0->>'servicioId')::uuid=sid, 'Completar conserva servicio';
 assert (select maquina from public.servicio_trayectos where servicio_id=sid)='Completada';
 begin
   perform public.guardar_orden_servicios(u,gen_random_uuid(),p); -- versión antigua
 exception when raise_exception then denied := true;
 end;
 assert denied, 'Rechazar versión antigua';
 denied := false;
 begin
   perform public.guardar_orden_servicios(u,k,p); -- misma clave, otro payload
 exception when raise_exception then denied := true;
 end;
 assert denied, 'Rechazar clave con datos diferentes';
 -- Fallo después de insertar cabecera/primer viaje: transacción completa revierte.
 p := jsonb_build_object('clientOrderId',gen_random_uuid(),'version',0,'viajes',
   jsonb_build_array(jsonb_build_object('clientItemId',gen_random_uuid()),jsonb_build_object('clientItemId','invalid')));
 begin
   perform public.guardar_orden_servicios(u,gen_random_uuid(),p);
 exception when invalid_text_representation then null;
 end;
 assert (select count(*) from public.servicios where created_by=u)=1, 'No dejar servicios parciales';
 assert (select count(*) from public.ordenes_escolta where created_by=u)=1, 'No dejar cabeceras parciales';
 -- Complementos de recuperación y entrega deben estar aplicados en desarrollo.
 b := public.recuperar_orden_servicios(u,c);
 assert b->>'version'='2', 'Recuperar versión persistida';
 assert b->'fields'->'viajes'->0->>'maquina'='Completada', 'Recuperar campos';
 assert public.recuperar_orden_servicios(u,gen_random_uuid()) is null, 'No inventar otra orden';
 update public.ordenes_escolta set estado_captura='CONFIRMADA' where id=(a->>'id')::uuid;
 assert public.reclamar_entrega_orden(u,(a->>'id')::uuid,'hash-fixture')='RECLAMADA';
 assert public.reclamar_entrega_orden(u,(a->>'id')::uuid,'hash-fixture')='POR_VERIFICAR', 'No iniciar segundo correo';
 perform public.finalizar_entrega_orden(u,(a->>'id')::uuid,'ERROR_PREVIO');
 assert public.reclamar_entrega_orden(u,(a->>'id')::uuid,'hash-fixture')='RECLAMADA', 'Fallo previo permite retry';
 perform public.finalizar_entrega_orden(u,(a->>'id')::uuid,'ENVIADA');
 assert public.reclamar_entrega_orden(u,(a->>'id')::uuid,'hash-fixture')='ENVIADA', 'No reenviar éxito';
 update public.users set active=false where id=u;
 denied := false;
 begin
   perform public.listar_servicios_operativos(u);
 exception when insufficient_privilege then denied := true;
 end;
 assert denied, 'Cuenta inactiva no consulta';
end $$;
rollback;
