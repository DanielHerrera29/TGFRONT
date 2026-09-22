# Código por correo para desbloquear Firmar

Estado: integración local implementada y pruebas HTTP simuladas. Pendientes migración PostgreSQL, verificación del remitente Brevo, publicación backend/app y prueba real.

Flujo: guardar borrador → pedir código al correo del arquitecto → validar seis dígitos → habilitar Firmar → dibujar firma → confirmar y enviar PDF. El código no adjunta firma ni confirma un PDF ya firmado. Gmail es compatible; también se aceptan correos válidos de otros dominios.

## Render: nombres y valores exactos

| Variable (nombre) | Valor |
|---|---|
| `Brevo_Codigo_verificacionAPIKEY` | Clave API de la segunda cuenta (secreta) |
| `Brevo_Codigo_verificacionSenderEmail` | `transportegutierrezremesas@gmail.com` |
| `Brevo_Codigo_verificacionSenderName` | `TRANSPORTE GUTIERREZ` |

El guion usado para separar nombre y valor en una explicación NO forma parte de la variable. Estos nombres se leen literalmente, con guiones bajos simples. No sobrescribir `Brevo__ApiKey`, `Brevo__SenderEmail` o `Brevo__SenderName`: siguen enviando PDF.

`FirmaOtp__Required` es true por defecto. No se necesitan claves Twilio. La clave API secreta de la segunda cuenta también protege el HMAC con un prefijo exclusivo para códigos de firma; rotarla invalida códigos pendientes, pero no borra desbloqueos ya aprobados. Nunca se transmite esa clave a Flutter.

## Activación coordinada

1. Segunda cuenta Brevo: añadir remitente y completar el enlace/código de verificación recibido en Gmail. Si se utiliza la protección de IP, autorizar las salidas actuales de Render en esa segunda cuenta, conservando la protección.
2. Validar y aplicar `sql/20260921_codigo_firma_email_brevo.sql`. Es independiente de la propuesta antigua de WhatsApp: no ejecutar la migración WhatsApp para este flujo. La migración nueva no borra ni transforma las tablas anteriores.
3. Publicar backend con estas variables y distribuir nueva app. Clientes antiguos no pueden enviar sin desbloqueo registrado cuando está activo el requisito.
4. Prueba con correo autorizado: recepción, error de código, código correcto, firma, PDF por cuenta original, recuperación tras reinicio y solicitud en otra orden.

## Protección y cuotas

Códigos criptográficamente aleatorios de seis dígitos; diez minutos de vigencia y cinco intentos. Base almacena HMAC ligado al usuario, orden e ID de solicitud, no el código. Comprobación y contador se actualizan bajo bloqueo en una transacción. No existe acción pública para aprobar sin código.

RLS sin acceso anon/authenticated y RPC solo service_role; RPC comprueba usuario activo y propiedad. El control al enviar y al abrir el lienzo consulta estado del servidor. Una nueva orden requiere su propio código. El código acredita acceso al correo declarado, no profesión ni representación autorizada por TEG.

Límite preventivo local: 280 solicitudes en ventana móvil de 24 horas para toda la cuenta de códigos, diez por usuario/hora y cinco por destinatario/hora. Es conservador frente al cupo de 300 correos de Brevo, reserva margen y evita agotar el cupo con reintentos. Otros envíos desde esa cuenta también consumen el cupo del proveedor. Esta implementación por tanto admite como máximo 280 nuevas solicitudes por 24 horas, no promete 300 órdenes.

Doble clic o reintento recupera solicitud sin otro correo. Si Brevo acepta pero se pierde la respuesta, el código recibido puede comprobarse con la misma solicitud. Si no llega, esperar diez minutos antes de generar uno nuevo; no reenvío automático. La API de Brevo puede aceptar un correo sin entregarlo de inmediato, por lo que hace falta verificar recepción real.

## Reversión

No borrar evidencias. Retirar la versión no publicada y dejar las tablas inactivas es reversible. Si ya está activa, quitar el requisito permitiría enviar sin confirmación: requiere decisión de TEG. No modificar la cuenta original para resolver fallos de la cuenta de códigos.
