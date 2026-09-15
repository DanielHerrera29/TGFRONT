# Prueba nativa en iPhone desde Windows

Estado: configuración preparada; compilación remota e instalación todavía no ejecutadas.

El archivo iOS es IPA, no APK. `codemagic.yaml` compila una aplicación release para
dispositivo usando macOS y genera un IPA SIN FIRMA. No se instala directamente y
no se puede enviar a TestFlight en ese estado. El backend configurado es Render.

1. Crear/iniciar sesión en Codemagic y conectar el repositorio frontend con estos
   cambios guardados. Seleccionar el workflow `ios-prueba-sin-firma`.
2. Ejecutar el workflow dentro del cupo gratuito disponible. Revisar el primer
   build: este proyecto aún no se ha validado con Xcode.
3. Descargar el artefacto `TEG-sin-firma.ipa`.
4. Instalar AltServer/AltStore siguiendo la guía oficial para Windows, confiar
   en el ordenador y activar Modo de desarrollador en el iPhone.
5. Importar el IPA en AltStore para firmarlo con la cuenta personal de Apple e
   instalarlo. Introducir las credenciales únicamente en la herramienta elegida.
   La firma gratuita caduca y exige renovación; comprobar las restricciones
   vigentes de AltStore antes de usar esta ruta.

No se necesita contraseña Gmail de aplicación del escolta. El correo se envía
desde el backend. En iOS el PDF se entrega a la hoja de compartir del sistema;
la integración Android de apertura directa de WhatsApp no aplica a iOS.

Fuentes:
- https://codemagic.io/pricing/
- https://docs.codemagic.io/yaml-code-signing/signing-ios/
- https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows

Para TestFlight se requiere otra configuración: identidad de aplicación,
certificado/perfil de distribución y cuenta Apple Developer habilitada.
