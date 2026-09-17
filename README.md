# TGFRONT

Aplicacion Flutter de CargoDespacho para la operacion de remesas, manifiestos,
vehiculos y ordenes de escolta.

## Ejecutar en desarrollo

```powershell
flutter pub get
.\run-backend-local.ps1
```

En otra terminal, desde esta carpeta:

```powershell
.\run-frontend-local.ps1
```

Frontend local: `http://localhost:5173`. API local: `http://localhost:5116`;
Swagger: `http://localhost:5116/swagger`. También puede iniciarse el frontend
con la configuración de VS Code «TEG local (API localhost:5116)».

El script del frontend fuerza `API_URL` a localhost al recompilar; abra la
dirección local, no la web publicada en GitHub Pages. Reinicie `flutter run`
si cambia `API_URL`, porque es un valor de compilación. Supabase sigue siendo
la base configurada; ejecutar la API localmente no copia la base a su equipo.
El inicio local desactiva la tarea automática de retención de PDF.

La API se ejecuta desde el proyecto backend por separado. No incluya en Git
credenciales RNDC, claves SMTP, archivos `.env` ni XML de pruebas con datos reales.
# Probar con el backend de Render

El frontend usa `https://tgback-api.onrender.com` por defecto. Para ejecutarlo
explícitamente contra Render:

```powershell
.\run-frontend-render.ps1
```

Detén primero la ejecución anterior de Flutter con `q`. Vuelve a iniciar sesión
después de cambiar de backend. `run-frontend-local.ps1` sigue disponible para
probar contra localhost cuando sea necesario.
