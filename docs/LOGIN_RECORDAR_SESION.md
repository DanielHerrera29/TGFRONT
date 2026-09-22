# Login y acceso recordado

Versión 1.0.3+4. Login validado exclusivamente por API, sin consultar contraseñas de usuarios desde Flutter.

- Correo: trim y comparación sin distinguir mayúsculas. Contraseña exacta, sin convertir ni quitar espacios.
- Si existen dos usuarios cuyo correo difiere solo por mayúsculas, rechaza la ambigüedad; administración debe corregir duplicados.
- Recordarme en Android/iOS: correo y contraseña en almacenamiento seguro del sistema para validar de nuevo al abrir, incluso si caducó el token o Render reinició. El modelo en memoria no incluye la contraseña.
- En navegador se conserva solo el token, nunca la contraseña. Se valida contra el servidor; si caducó o Render invalidó sus claves se pide login nuevamente.
- Cerrar sesión elimina el registro seguro de la app, token en memoria y configuración de la sesión. No elimina órdenes/borradores operativos. Los datos que el usuario guardó por su cuenta en el gestor de contraseñas de Google/Apple no los puede borrar la app.
- Credenciales rechazadas al restaurar: elimina el acceso recordado. Un error de red conserva el recuerdo pero no permite entrar sin validar.
- Una respuesta tardía de login después de cerrar sesión no puede volver a abrirla.

Pruebas automatizadas: normalización, contraseña exacta, reabrir sesión, cerrar sesión, error de red, ambigüedad de usuarios, comodines y respuesta tardía. Pendiente comprobar persistencia real de Keychain/Keystore en dispositivos físicos, especialmente tras instalar el IPA mediante firma local.
