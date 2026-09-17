# Verificación de notas operativas — 14 septiembre 2026

No se considera terminado el sistema completo. Los cambios locales no equivalen
a una migración aplicada ni a una versión desplegada.

| Regla | Estado verificable |
|---|---|
| Centro de costo por escolta, no empresa | Pendiente de implementación contable. El usuario escolta y sus placas están modelados; eso no constituye un centro de costo ni una liquidación. |
| Numeración por placa escolta | Migración aplicada según resultado Success comunicado por el usuario. `ABC123` → `C123-1`; `MNB124` → `B124-1`; `LLO001` → `O001-1`. Contador transaccional independiente por placa completa. Pendiente prueba real de una orden nueva. |
| Contar escoltas por carro | Consulta de diagnóstico preparada para órdenes confirmadas y viajes por placa. No existe aún reporte terminado de trabajos realizados/cumplidos. |
| Edición sin contraseña de aplicación Gmail | Retirada del formulario. El envío de correo utiliza la configuración del backend. No se borran columnas históricas. |
| Destinatario WhatsApp legible | Formulario ajustado con separación, borde, icono y etiqueta flotante. |
| Placas de empresa/cliente | `clientes` → `cliente_vehiculos` → `vehiculos`. Nueva acción administrativa para enlazar vehículos de carga existentes. Pendiente migración y despliegue. |
| Placas del escolta | `users` → `usuario_vehiculos_escolta`. No son las placas de carga del cliente. |

## Activación

1. Comprobar que el incremento de contactos ya está aplicado.
2. Aplicar `sql/20260913_numeracion_placas_alta_usuarios.sql` en desarrollo.
3. Aplicar `sql/20260914_vincular_vehiculo_cliente.sql` en desarrollo.
4. Ejecutar las pruebas SQL de numeración en una base de pruebas y revisar
   `sql/diagnostico_placas_clientes.sql` en la base correspondiente.
5. Backend 0caa6c9 desplegado y health verificado en Render. Frontend 5494d13 publicado en codex/ios-pruebas-escoltas; pendiente build e instalación iOS.

Las órdenes históricas confirmadas conservan su número y PDF; no se renumeran
por abrirlas o reenviarlas. La prueba de numeración debe usar una NUEVA orden.
Dos placas completas con el mismo sufijo de cuatro caracteres se bloquean con
un error explícito: queda pendiente acordar cómo resolver esa colisión sin
alterar el formato solicitado.

Prueba de aceptación: crear usuario con placas opcionales, crear/vincular
cliente y vehículo de carga, confirmar dos órdenes con ABC123 (C123-1 y C123-2
si no hay anteriores), confirmar otra con MNB124 (B124-1), repetir una solicitud
y comprobar que conserva ID y código. Revisar el mismo código en historial,
PDF, asunto de correo y mensaje de WhatsApp. No enviar mensajes reales durante
pruebas automatizadas.
