# Aplicación del incremento 1

**Actualización tras diagnóstico de la base real:** TEG aportó metadatos que muestran presentes las tablas, columnas, restricciones y funciones del incremento. En esa base **no repetir el paso de creación de la migración**. Consultar `RESULTADO_DIAGNOSTICO_INCREMENTO_1.md`. La secuencia siguiente describe instalación inicial en un entorno que aún no tenga estos objetos; no es una instrucción de reinstalar sobre la base diagnosticada.

Estado: implementación local inicial. No se ha aplicado SQL remoto. El backend ahora identificado está en `C:/Users/dell/transportegutierrezBack` (ASP.NET Core 8); el frontend está en `C:/Users/dell/transportegutierrez`.

## Orden de instalación

1. Inventariar la base de destino y hacer respaldo/restauración de prueba. Confirmar entorno antes de ejecutar SQL. No ejecutar `create_tables.sql` antiguo: contiene desactivación de RLS y no refleja necesariamente el esquema desplegado.
2. Verificar que existen users, clientes, ordenes_escolta y ordenes_escolta_items con los campos del DDL TEG aportado, incluidas las columnas snapshot. Los ítems deben permitir posiciones > 8; aplicar primero la migración existente de viajes ilimitados si falta. La migración inicial del backend, por sí sola, no crea toda esa línea base.
3. Para la base diagnosticada, **omitir la migración inicial**. Preparar en desarrollo los complementos en orden: `20260912010000_recuperacion_catalogos.sql` (funciones de recuperación y catálogo) y `20260912020000_control_entrega_orden.sql` (tabla nueva de control de correo y funciones). Sus copias de revisión en frontend son `20260912_recuperacion_catalogos.sql` y `20260912_control_entrega_orden.sql`. Ejecutar una sola copia de cada archivo. En una instalación vacía, la migración inicial sigue siendo prerrequisito. Verificar primero que `orden_entrega_control` no proviene de una ejecución anterior; no sustituir su creación por IF NOT EXISTS sin contrastar estructura.
4. Ejecutar `sql/tests/servicios_borradores.sql` en desarrollo. Requiere rol de migración con permisos, revierte fixtures y no llama RNDC/correo. Adicionalmente probar concurrencia desde dos conexiones y permisos de anon/authenticated: los fixtures de un solo bloque no prueban concurrencia.
5. Compilar/desplegar backend con `ServiciosController`, luego frontend. Nueva captura usa `/api/servicios/orden-borrador`; listado `/api/servicios`. Mantener API_URL consistente. No desplegar frontend antes de migración/backend.
6. Demostrar reinicio de Flutter, borrador parcial y respuesta perdida contra desarrollo. Solo después autorizar aplicación remota. No compartir claves ni pegarlas en estos scripts.

## Alcance actual y límites

- Nuevas órdenes: guardado transaccional de cabecera, ítems, servicios y trayectos; clave idempotente por operación y versión por borrador. Cuenta activa/rol comprobados en SQL, usuario tomado del token del backend. Nuevas tablas sin acceso directo anon/authenticated; funciones solo service_role.
- Flutter: un borrador local por usuario, claves persistidas antes de enviar, edición incremental y recuperación de operación pendiente. SharedPreferences no es un almacén cifrado ni garantiza recuperación de datos que el sistema operativo nunca llegó a persistir; validar requisitos de dispositivo antes de producción. No se guardan contraseñas o tokens en el borrador.
- Firma PNG persistida junto al borrador local por usuario; una orden confirmada recupera esa firma para regenerar el PDF. Recuperar una versión diferente desde el servidor invalida la firma local. El PDF final sigue almacenándose en el backend, no en SharedPreferences. Proteger dispositivo y respaldos locales porque contienen datos y firma.
- `orden_entrega_control` reclama una entrega por orden con bloqueo PostgreSQL. ENVIADA devuelve éxito sin reenviar; ENVIANDO/POR_VERIFICAR bloquea el reenvío. Solo ERROR_PREVIO, antes de iniciar correo, permite retry automático. Ante resultado incierto, administración debe verificar el proveedor y conciliar con soporte. No hay promesa de entrega exactamente una vez ni trabajador de reintentos automático; un proceso interrumpido queda bloqueado para revisión.
- La bandeja muestra hasta 200 servicios recientes visibles según rol, incluidos borradores. operator mantiene capacidad administrativa de lectura por compatibilidad; la migración completa de roles/Auth aún no está implementada.
- La ruta antigua `/api/ordenes-escolta/reservar` devuelve 426 y no crea registros. Actualizar frontend y backend coordinadamente; los clientes antiguos deben actualizarse.
- No se permite retirar/reordenar viajes guardados ni compartir un servicio entre dos órdenes desde esta primera interfaz. Esas pruebas del incremento completo siguen pendientes. No se migran ni inventan vínculos históricos.
- Una confirmación bloquea edición; aprobación económica, RNDC, afiliaciones y exportación de 44 columnas quedan para incrementos siguientes. Nunca interpretar confirmar captura como aceptación RNDC.
- Ante 409 se ofrece «Recuperar versión del servidor», con confirmación y respaldo del borrador local anterior. No crea otra orden. Ante 400 transaccional se conserva el contenido y se habilita corrección con nueva clave; timeout/5xx conserva la clave pendiente. La recuperación se limita a la orden propia identificada por clientOrderId; búsqueda de todos los borradores entre dispositivos queda pendiente.
- Clientes se consultan mediante `/api/servicios/clientes`, con actor verificado y proyección mínima de datos. No se agrega una política universal sobre clientes. La vulnerabilidad existente de `users` (grants anónimos y RLS desactivada) sigue requiriendo migración coordinada de identidad/login; esta edición no debe presentarse como cierre de la seguridad global.

## Verificación local de esta edición

Backend .NET 8 compilado sin advertencias/errores. Ocho comprobaciones de contrato con HTTP simulado en `tests/backend_contracts`: sesión ausente, clave requerida, JSON, actor del token, conflicto, denegación, respuesta no JSON y bloqueo de la ruta antigua. `flutter analyze --no-pub`: sin incidencias. `flutter test --no-pub`: 11 pruebas aprobadas. Las pruebas SQL fueron ampliadas para recuperación y control de entrega, pero **no se ejecutaron en la base real**. No se enviaron correos ni RNDC. Estos resultados no prueban concurrencia PostgreSQL ni entrega del proveedor.

## Reversión

Si la migración falla durante ejecución, PostgreSQL revierte la transacción. Si ya se aplicó, no borrar tablas/columnas nuevas: desactivar el acceso al formulario nuevo y conservar órdenes y borradores para conciliación. No dirigir reintentos inciertos a la ruta antigua porque duplicaría operaciones. Restauración completa solo en entorno de desarrollo o desde un respaldo con procedimiento explícitamente aprobado; no se entrega un DROP automático de datos operativos.

Esta entrega no cumple aún todos los criterios del incremento 1. Los resultados de compilación y pruebas locales deben distinguirse de los de PostgreSQL, concurrencia real, reinicio de dispositivo y envío de correo.
