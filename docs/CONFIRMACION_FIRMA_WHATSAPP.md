> Sustituido por CONFIRMACION_FIRMA_EMAIL.md. No activar la propuesta Twilio: el canal elegido es correo mediante una segunda cuenta Brevo.

# Código previo para desbloquear la firma

## Flujo corregido

1. Se prepara la orden. **Firmar** está bloqueado.
2. Se pulsa **Pedir código al arquitecto**. Se guarda el borrador para identificar la orden sin confirmar ni generar PDF.
3. Se introduce nombre y número del arquitecto y se pulsa **Pedir código**.
4. Se digitan los seis números recibidos y se pulsa **Validar código**.
5. El servidor confirma el código y habilita **Firmar** únicamente para esa orden.
6. Se pulsa **Firmar**, se dibuja la firma en la app y se continúa con la generación y envío normal.

El código NO confirma un PDF ya firmado ni adjunta una firma. Solo habilita la captura. No requiere un directorio previo de arquitectos. El teléfono y nombre son declarados; el código acredita acceso al teléfono, no título profesional.

## Implementación y límites

Flutter conserva la referencia de solicitud y el desbloqueo local; vuelve a consultar al servidor antes de abrir el lienzo. El backend también exige la verificación para enviar la orden, aunque se omita la pantalla. Una orden nueva no hereda el permiso. No se almacena el código.

Migración pendiente: `sql/20260921_confirmacion_firma_otp.sql`. Se revisó el archivo todavía no aplicado; no ejecutar sobre una instalación previa de la versión de esta misma migración sin adaptación. Primero validar en PostgreSQL de desarrollo.

Proveedor preparado: Twilio Verify WhatsApp, pendiente de elección/configuración por TEG. Variables solo del backend: `FirmaOtp__AccountSid`, `FirmaOtp__AuthToken`, `FirmaOtp__ServiceSid`, `FirmaOtp__Required=true` (predeterminado). Servicio de seis dígitos y diez minutos. No fallback SMS implementado. No se han enviado códigos reales ni desplegado estos cambios.

RLS sin acceso directo anon/authenticated, función solo service_role que comprueba actor activo y propietario. Cinco intentos por código; diez solicitudes por usuario/hora y cinco por teléfono/hora. Una solicitud incierta espera vencimiento; no autoriza ni reenvía automáticamente. Una aprobación registrada desbloquea esa orden incluso tras vencer el código ya utilizado.

## Antes de publicar

- Aplicar y probar migración en desarrollo: usuario ajeno, concurrencia, límites, código vencido y transición a verificada.
- Configurar proveedor y remitente WhatsApp empresarial; probar recepción real.
- Probar: sin código no abre firma; código incorrecto no desbloquea; código correcto sí; reiniciar conserva solicitud; otra orden vuelve a bloquear; envío no vuelve a pedir código.
- Publicar backend y nueva app coordinadamente. El backend nuevo bloquea órdenes antiguas que no tengan desbloqueo registrado; actualizar clientes antes de activar.

No borrar evidencias al revertir. Desactivar el requisito en producción requiere decisión expresa de TEG.

