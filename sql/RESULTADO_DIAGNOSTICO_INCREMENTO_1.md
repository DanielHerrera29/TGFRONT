# Resultado del diagnóstico aportado por TEG

Fuente: resultado JSON de `diagnostico_incremento_1.sql` aportado por el usuario después del error 42P07. Revisión de metadatos, no conexión directa ni prueba funcional remota.

## Decisión

No repetir `20260912_servicios_borradores.sql` ni su copia del backend. Los objetos de su estructura ya están presentes. No se identifica un ALTER TABLE necesario para resolver el error «servicios already exists»: el error procede de intentar crear un objeto existente. No se ha determinado qué ejecución creó esos objetos.

## Evidencia contrastada con la migración local

- `servicios`: UUID, folio bigint identity, cliente, empresa, PROPIO/TERCERO, BORRADOR/EN_REVISION, creador y fechas. Defaults, nulabilidad, PK, UNIQUE y FK esperados presentes.
- `servicio_trayectos`: PK/FK a servicio, máquina, origen, destino, placa, toneladas numeric(12,3) y kg generado mediante multiplicación por 1000.
- `orden_operaciones`: PK usuario/clave, solicitud y resultado jsonb, fecha y FK de usuario.
- Órdenes: client_order_id, version con default 1, estado_captura con LEGADO/BORRADOR/CONFIRMADA, UNIQUE creador/client_order_id y columnas snapshot necesarias.
- Ítems: client_item_id, servicio_id, UNIQUE orden/client_item_id, FK a servicios y posición > 0, sin límite de ocho en el CHECK reportado.
- Índices de creador, pendientes y servicio por ítem presentes.
- `guardar_orden_servicios(uuid, uuid, jsonb)` y `listar_servicios_operativos(uuid)` devuelven jsonb, son SECURITY DEFINER y fijan search_path public, pg_temp. ACL reportada: ejecución para postgres y service_role, sin anon/authenticated.
- Las tres tablas nuevas tienen RLS habilitada; no se reportan políticas y sus grants corresponden a postgres/service_role. Esto coincide con acceso desde backend, no directamente desde Flutter.

Las firmas y huellas de funciones prueban su existencia; el diagnóstico no incluye el cuerpo para demostrar equivalencia exacta con las funciones locales. Tampoco incluye permisos de secuencias/esquema, contenido de datos o validación de transacciones concurrentes. No se afirma que el circuito esté probado por coincidir la estructura.

## Hallazgos fuera del error de creación

- `users` tiene RLS desactivada y grants de SELECT, INSERT, UPDATE, DELETE y otros para anon/authenticated. Es un pendiente concreto de autorización: la validación del rol en una función no protege el perfil si otra vía permite modificarlo. Revisar exposición por API y migrar el login antes de considerar listo el esquema para producción. No aplicar un cambio aislado de RLS que rompa los consumidores actuales.
- Órdenes, ítems y clientes tienen RLS habilitada y no aparecen políticas en la consulta recibida. Los grants de tabla por sí solos no superan RLS para acceso ordinario. Comprobar en particular la lectura directa de clientes que usa Flutter; no resolverla con una política universal que exponga datos innecesarios.
- Existe una FK desde `mensajes_whatsapp` hacia órdenes. Debe incluirse ese consumidor al planear cambios futuros. No eliminar ni recrear órdenes.
- Los valores de filas estimadas (incluido -1) son estadísticas, no conteos exactos ni evidencia de tabla vacía.

## Siguiente validación

Continuar con integración backend/frontend usando esta estructura existente, sin repetir CREATE TABLE. Antes de generar operaciones reales, ejecutar los fixtures SQL en desarrollo o en una copia controlada de la base; los scripts que hacen ROLLBACK pueden consumir secuencias y no son pruebas sin efectos sobre producción. Probar cuenta activa, acceso permitido/denegado, borrador parcial, reintento, respuesta perdida, reinicio y concurrencia. Correo/RNDC fuera de esas pruebas.

El incremento completo continúa pendiente de pruebas PostgreSQL y de los límites documentados en `INCREMENTO_1_APLICACION.md`. No se ejecutaron escrituras remotas en esta revisión.
