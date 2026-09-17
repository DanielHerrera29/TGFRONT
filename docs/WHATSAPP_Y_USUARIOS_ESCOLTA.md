# Contactos, vehículos y compartir órdenes

Reglas confirmadas por TEG el 13/09/2026:

- Los escoltas son cuentas de `users`, con rol operativo `operator` (también se reconoce `escolta` en backend).
- `users.whatsapp` es contacto, no credencial ni identidad de la cuenta de WhatsApp abierta.
- Los usuarios existentes sin contacto reciben provisionalmente `+573144672648`. Los números son editables y no únicos. Una segunda ejecución no pisa contactos corregidos.
- Destino inicial de órdenes: `+573223509469`, editable por administración.
- WILMER: `ABC123`, `MNB124`, `LLO001`.

## Aplicación

1. Aplicar `sql/20260913_contactos_whatsapp_usuarios.sql` en el SQL Editor del proyecto actual. El resultado final debe mostrar WILMER con las tres placas y el contacto provisional. No ejecuta correos ni WhatsApp.
2. Desplegar backend con `ContactoEscoltaController`, y reiniciar Flutter. Este código no requiere cambiar claves de Render.
3. Cerrar sesión y entrar nuevamente. En Usuarios se puede editar el celular; desde «Vehículos escolta y destinatario WhatsApp» se administran las placas y el destino global.
4. Como WILMER, una orden nueva muestra un selector con sus tres vehículos. El servidor valida la asignación al confirmar. Borradores parciales siguen permitidos y órdenes históricas confirmadas se conservan.
5. Tras el correo, en Android/iOS se intenta abrir el selector de compartir PDF y detalles. El usuario elige WhatsApp, selecciona el destino mostrado y confirma. No se puede imponer una cuenta personal ni verificar la entrega a través del selector del sistema.
6. En navegador el botón «Compartir PDF y detalles» usa las capacidades disponibles del navegador. Si no hay soporte de compartir archivos, se descarga el archivo. «Abrir chat con el mensaje» prepara el texto para el número configurado; se adjunta el PDF manualmente. El navegador requiere un clic para abrir estas acciones.
7. Historial → menú del PDF → «Compartir por WhatsApp» permite compartir nuevamente una orden guardada sin recrearla ni reenviar correo.

## Modelo

`users (id, whatsapp)` → `usuario_vehiculos_escolta (usuario_id, placa, activo)`.
La relación admite varios carros por usuario; no se crean cuentas adicionales por placa. El vínculo de la orden al usuario queda en `ordenes_escolta.escolta_usuario_id`. Los nombres del operador se toman de la cuenta en el servidor. El catálogo legado `escoltas` se conserva como referencia: no se crean contraseñas ni se deducen cuentas por nombres repetidos. Para incorporarlo, administración crea/identifica la cuenta real y asigna allí sus placas.

No se registra «WhatsApp entregado» por abrir el selector. Compartir no invoca endpoints de creación ni correo. Si se cierra o falla WhatsApp, el historial permite repetir exclusivamente esa acción.

## Verificación de base (solo lectura)

```sql
select id,name,whatsapp from public.users;
select usuario_id,placa,activo from public.usuario_vehiculos_escolta;
select destino from public.orden_whatsapp_config;
```

SQL revisado, pendiente de ejecución en el proyecto: no se dispone de PostgreSQL local para validar la migración aquí. Las pruebas de backend usan HTTP simulado. La entrega real de WhatsApp debe comprobarse en el dispositivo del usuario; no se enviaron mensajes de prueba.

## Reversión operativa

Volver al frontend/backend anterior si es necesario y desactivar únicamente `trg_usuario_orden_escolta` con revisión del administrador. Conservar las columnas y tablas aditivas, contactos y vínculos para no perder datos. No ejecutar el borrador `20260913_usuarios_escoltas_entregas.sql`: la numeración por placa es un incremento pendiente de consolidación.
