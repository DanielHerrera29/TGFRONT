-- SOLO LECTURA: estado de la orden bloqueada. No libera ni reenvía correos.
select o.consecutivo, o.estado_captura, o.email_enviado_at, o.email_error,
       e.estado as estado_entrega, e.updated_at
from public.ordenes_escolta o
left join public.orden_entrega_control e on e.orden_id = o.id
where o.consecutivo = 36;

-- POR_VERIFICAR requiere evidencia del proveedor o del registro del intento.
-- La ausencia actual de configuración no demuestra por sí sola el resultado
-- de un intento anterior. No actualizar automáticamente a ERROR_PREVIO.
