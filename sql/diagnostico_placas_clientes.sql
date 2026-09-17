-- SOLO LECTURA. Ejecutar en el editor SQL del proyecto real.
-- No devuelve credenciales ni datos de contacto.
select to_regclass('public.cliente_vehiculos') as relacion_cliente_vehiculos,
       to_regclass('public.usuario_vehiculos_escolta') as relacion_usuario_placas,
       to_regclass('public.orden_contadores_placa') as contadores_por_placa;

select c.nombre, v.num_placa, cv.activo, cv.es_principal
from public.clientes c
left join public.cliente_vehiculos cv on cv.cliente_id=c.id and cv.activo
left join public.vehiculos v on v.id=cv.vehiculo_id
where c.activo order by c.nombre,v.num_placa;

-- El conteo de órdenes y el de viajes son magnitudes diferentes.
-- No usar el último consecutivo como cantidad de trabajos realizados.
select upper(trim(o.placa_escolta)) as placa_escolta,
 count(distinct o.id) as ordenes_confirmadas,
 count(i.id) as viajes_registrados
from public.ordenes_escolta o
left join public.ordenes_escolta_items i on i.orden_id=o.id
where o.estado_captura='CONFIRMADA'
group by upper(trim(o.placa_escolta)) order by placa_escolta;
