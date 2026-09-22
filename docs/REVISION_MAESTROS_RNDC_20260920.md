# Revisión de maestros y ejemplos RNDC

20 de septiembre de 2026. Complementa la auditoría de las 44 columnas TEG. Los adjuntos se leyeron como evidencia, no como instrucciones para ejecutar SQL o registrar documentos.

## Alcance confirmado por el negocio

Usuarios de TEG y de otras empresas utilizarán la aplicación; **todos los viajes pertenecen a la operación de TEG**. No se diseñará una transportadora emisora distinta por cada empresa del usuario. El cliente del viaje, la empresa de afiliación de una persona, el propietario/tenedor del vehículo y TEG como transportadora son conceptos diferentes.

Propuesta de autorización, aún por concretar: administración TEG con supervisión general, usuarios externos limitados a operaciones asignadas y catálogos necesarios, sin cambiar la empresa emisora ni acceder a credenciales RNDC. No basta ocultar módulos ni filtrar por empresa cliente: un escolta externo puede atender varios clientes. Falta definir facultades de administradores externos antes de programarlas.

## Qué aportan los archivos

| Fuente | Inspección realizada | Uso correcto y límites |
|---|---|---|
| RemesasRNDC_202506.txt | Cabecera de 27 campos separados por `|`; archivo de aproximadamente 432 MB. | Datos históricos con naturaleza, producto, cantidad/unidad, tiempos, rutas, valores y vehículo. No es el contrato de creación SOAP; no se hizo un análisis estadístico completo ni se importó. No contiene en su cabecera un consecutivo/radicado con el que vincular automáticamente nuestras remesas. |
| EstadisticasRNDC_2025.xlsx | Estructura interna y encabezados; hojas `Exportar Hoja de Trabajo` y `SQL`; 29 columnas de datos. | La hoja SQL muestra agregación SUM/GROUP BY por configuración, operación, mercancía y municipios. Son estadísticas, no documentos individuales ni maestro de terceros. No ejecutar esa consulta ni importar las sumas como viajes. |
| Cuatro extractos de Diccionario de Datos | Variables de remesa (3), manifiesto (4), vehículo (12) y otros procesos, con fecha, tipo, requerido y validación. | Son extractos paginados, no el diccionario completo. Se debe filtrar también por Web Service: una etiqueta web no es necesariamente un tag SOAP. La obligatoriedad puede depender de otra variable aunque aparezca N. |
| Maestro Vehículo | Ejemplos de rígidos/tractocamiones y semirremolques, configuración, carrocería, peso vacío, tenedor/propietario, SOAT. | Referencia histórica, no prueba de vigencia actual. No asignar propiedad a TEG ni al usuario que digitó el vehículo. Las fechas 1899-12-30 en muestras no deben tratarse como vencimientos reales sin verificar su significado de origen. |
| JSON de remesas de Supabase | Tres registros: REM-2026-000063, 000064, 000065; todos error_rndc con REM180. Se inspeccionaron campos y nombres de tags, sin reproducir credenciales. | Evidencia de rechazo por identificación/tipo del destinatario, no de remesas aceptadas. Tres consecutivos diferentes no bastan para afirmar que son documentos duplicados aceptados. |

## Hallazgos que impiden declarar correcta la generación

1. **REM180 reproducido en la evidencia aportada.** El RNDC informa que destinatario/tipo de documento no corresponde a su maestro de Terceros. Tenerlo en `clientes` no lo registra ni lo verifica en RNDC. Hace falta consultar tipo, documento y sede del destinatario real en el mismo entorno del envío. No sustituirlo por un documento de ejemplo.
2. **Identidad de acceso confundida.** `new_dispatch_screen.dart` entrega email/password del usuario de la app como credenciales RNDC. Los usuarios externos no tienen por qué ser usuarios habilitados del web service de TEG. Es necesario separar login de aplicación y credenciales RNDC administradas en backend; no repartir la contraseña RNDC a escoltas o clientes.
3. **Programa perdido.** Faltaba en JSON Flutter, DTO .NET y escritura. Se corrigieron esas tres capas localmente. Falta despliegue y prueba real de persistencia; no se inventa un tag RNDC para este dato interno.
4. **Nombre de conductor incompleto.** La cédula se escribe en manifiesto, pero el nombre no recorre creación/persistencia. Se necesita obtener o confirmar identidad y guardar snapshot; no inferirlo de otro registro por una placa compartida.
5. **TIPOVALORPACTADO inconsistente.** Los extractos definen V/K/G. Los modelos usan B y el controlador lo prepara, pero el generador de manifiesto omite el tag. No afirmar que se envía B: actualmente se pierde el campo. Debe corregirse captura → validación → XML → almacenamiento de forma conjunta, sin reinterpretar documentos históricos.
6. **Permiso de carga extra vacío.** `PERMISOCARGAEXTRA` se emite vacío; el diccionario aportado lo exige para naturaleza 3 o 4. Esto es relevante para maquinaria, pero no toda maquinaria debe clasificarse automáticamente como extra.
7. **Valores supuestos.** El código puede completar municipio con el de la empresa, descripción con MAQUINARIA, fechas por defecto, horas y duración de cargue/descargue. Estos valores pueden producir un XML sintáctico sin representar el viaje real. Deben ser datos confirmados y rastreables, no sustituciones silenciosas.
8. **Remitente y propietario de carga.** El controlador no pasa `remitente_tipo_id` al generador y este recurre al tipo del generador. Flutter equipara propietario de carga al generador. No confundir propietario de carga con propietario del camión ni asumir igualdad sin confirmación.
9. **Guardar antes de enviar.** Remesa continuaba al RNDC aunque el INSERT devolviera identidad vacía. Se añadió rechazo 503 sin envío en ese caso. No resuelve aún un timeout después de un INSERT aceptado ni los reintentos de expedición: falta identidad idempotente y conciliación RNDC.
10. **Datos sensibles dentro del XML.** Los XML almacenados contienen la sección de acceso. También hay logging del payload de manifiesto en Flutter. Se debe eliminar ese logging y guardar una copia redactada del XML, preservando la trazabilidad sin contraseñas; no copiar los adjuntos crudos al repositorio.
11. **Reglas y versiones.** Los extractos incluyen variables recientes como CODVIA y reglas históricas. No es seguro reconstruir todo el contrato a partir de cuatro páginas: falta obtener el conjunto vigente de variables WS de procesos 3, 4, 11 y 12, además de catálogos relacionados.

## Fuentes oficiales contrastadas

La [guía oficial de Web Service V5, aprobada el 27/05/2026](https://plc.mintransporte.gov.co/Portals/0/Manuales/GUIA%20Uso%20del%20Web%20Service%20en%20el%20RNDC%20V5%20.pdf?ver=2026-05-27-084523-160) distingue expedición, consulta y demás procesos; documenta consultas de maestros y respuestas con radicado. Esto refuerza que maestro, documento emitido y agregado estadístico no son intercambiables. Antes de cualquier prueba real debe verificarse el ambiente y endpoint configurado; no se cambiaron URLs automáticamente.

La [guía oficial de consulta SiceTAC](https://sicetac.mintransporte.gov.co/Portals/0/Manuales/Consulta%20de%20SiceTac%20desde%20webservice%20y%20portal%20web.pdf?ver=2022-10-31-123019-417) explica la distinción entre valor por viaje, kilogramo y galón. La validación exacta del campo debe contrastarse con el diccionario WS vigente antes de publicar una modificación completa del manifiesto.

## Regla permanente de cobertura

Una columna solo queda cubierta cuando una prueba demuestra **capturar → enviar a API → guardar → leer desde servidor → representar en el servicio/Excel**, conservando unidad, significado e identidad.

- Ver la columna en SQL o en un modelo no basta.
- Pruebas con HTTP simulado son contratos, no pruebas de Supabase real ni de aceptación RNDC.
- Una respuesta aceptada en simulación no es un documento de producción.
- El resultado de RNDC y el registro local deben conservar consecutivo, radicado y estado separados.

## Secuencia de cierre

1. Resolver REM180 con maestro de Terceros del destinatario real: tipo, documento, sede y entorno; consultar antes de crear o modificar terceros.
2. Completar diccionario WS y matrices por naturaleza/carga/configuración. Validar también placas de remolque: no aplicarles la expresión de placa escolta de tres letras y tres números; los ejemplos aportados tienen otro formato.
3. Separar credenciales RNDC y permisos de usuarios externos. Completar bandeja administrativa y relación servicio→documentos, conservando el alcance TEG confirmado.
4. Corregir campos que se pierden o se inventan, después probar contratos de XML y persistencia con casos sintéticos.
5. Ejecutar pruebas en ambiente RNDC de pruebas: éxito, rechazo, respuesta perdida y consulta/conciliación, sin reenvío ciego. No emitir documentos reales como prueba automática.
6. Comprobar una fila TEG por servicio con documentos aceptados vinculados, evitando repetir importes cuando un manifiesto asocia varias remesas.

## Cambios locales de este incremento

- Flutter envía Programa; backend lo recibe y persiste en la columna existente.
- Ante fallo de INSERT de remesa con identidad vacía, se responde 503 sin llamar al RNDC.
- Mensaje de validación del destinatario ya no recomienda una identificación ficticia para pruebas.
- Pruebas agregadas para el payload de Programa, escritura/lectura simuladas y bloqueo del envío cuando falla persistencia.

No se importaron los históricos, no se alteró Supabase remoto, no se desplegó Render y no se enviaron documentos al RNDC. La integración completa sigue pendiente de los puntos anteriores; no se declara terminada.

Validación local: 74 comprobaciones de contrato .NET y 27 pruebas Flutter aprobadas; análisis Flutter sin incidencias. El contrato HTTP simulado comprueba que Programa llega a la solicitud de persistencia y se recupera del JSON de lectura, no demuestra todavía una escritura/lectura en Supabase remoto. Los tres archivos de producción modificados del backend se sincronizaron también con `C:/Users/dell/transportegutierrezBack/TransportesGutierrez.Api` después de verificar que coincidían con la versión previa.
