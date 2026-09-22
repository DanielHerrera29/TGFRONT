# Cobertura actual del modelo TEG

Fecha: 20 de septiembre de 2026. Auditoría del código Flutter, backend .NET en `build/TGBACK-release`, SQL versionado y Excel original `MODELO BASE DE DATOS TEG.xlsx`, hoja Hoja1, A1:AR1.

**Aclaración posterior del negocio (20/09/2026):** habrá usuarios de TEG y de otras empresas, pero todas las operaciones corresponden a viajes de TEG. TEG es la empresa transportadora emisora; no se confirmó una plataforma de transportadoras independientes. Las menciones siguientes a aislamiento empresarial describen una brecha de acceso de usuarios externos, no una decisión de implementar multi-tenant. Falta precisar su alcance autorizado por asignación/cliente y los poderes de los administradores externos. Véase `REVISION_MAESTROS_RNDC_20260920.md`.

**Corrección local posterior:** se añadió Programa al payload Flutter, DTO .NET y escritura de remesa; pendiente de publicación y prueba capturar→guardar→leer en Supabase real. La matriz conserva el diagnóstico anterior como línea base y no cuenta aún ese campo como cubierto en producción.

## Resultado

La aplicación aún no completa el circuito del Excel. Guarda órdenes y crea un servicio por viaje, pero las remesas y los manifiestos siguen un circuito separado, sin relación con ese servicio. No se encontró un exportador integrado de las 44 columnas.

Esta revisión comprueba rutas de escritura en el código, no la cantidad de registros completos en Supabase remoto ni la versión instalada en cada teléfono. Las migraciones reportadas como «Success» son evidencia de aplicación aportada por el usuario; no sustituyen una consulta actual de esquema y datos.

## Lo que efectivamente guarda la orden

- Cabecera: fecha de orden, cliente y snapshots, placa camabaja, placa escolta, nombre escolta y observaciones generales.
- Cada viaje: identificador estable, máquina, origen y destino. No hay observaciones independientes por viaje en el guardado revisado.
- Cada ítem nuevo crea `servicios` y `servicio_trayectos`; conserva `servicio_id` en `ordenes_escolta_items`.
- Borrador/confirmación, versión, creador y clave idempotente permiten recuperar y reintentar sin crear otra operación idéntica.
- La confirmación asigna `codigo_orden` por placa escolta: ABC123 → C123-1. Las órdenes históricas confirmadas conservan su numeración. El contador es por placa completa; una coincidencia de sufijo con otra placa se rechaza y requiere una decisión administrativa.
- PDF, firma y entrega son resultados de la orden; enviar el PDF no significa completar el servicio ni el registro TEG.

## Matriz de las 44 columnas

Estados: **Capturado** = escritura identificada desde órdenes; **Parcial** = dato relacionado, esquema preparado o fuente en otro módulo, pero falta completar o enlazar; **Pendiente** = no se identificó un flujo completo de captura y persistencia. Ningún estado implica exportación ya implementada.

| Col. | Encabezado exacto | Estado y fuente actual | Responsable / acción necesaria |
|---|---|---|---|
| A | FECHA TRANSPORTE | Parcial: `ordenes_escolta.fecha` es fecha de orden; manifiesto tiene fecha de despacho. | Escolta/conductor registra fecha efectiva por viaje; no sustituirla por fecha de creación. |
| B | COD INT | Pendiente: existe `servicios.folio`, pero no está confirmado que equivalga a COD INT. | Administración define identificación interna y correspondencia. |
| C | FRA No. | Pendiente. | Administración/facturación registra documento. |
| D | FECHA FRA | Pendiente. | Administración/facturación. |
| E | REMESA TRANS No. | Parcial: `remesas.consecutivo` se guarda, sin vínculo al servicio. | Administrativo genera desde servicio y conserva relación. |
| F | AUT REMESA | Parcial: `remesas.radicado_rndc` se guarda tras respuesta. | Validar correspondencia de autorización y enlazar documento al servicio. |
| G | MTO | Parcial: existe `manifiestos.consecutivo`; significado exacto de MTO pendiente de documentar. | Confirmar mapeo antes de exportar. |
| H | (PR)/(PA) | Parcial: `servicios.service_type` existe, pero guardar orden no lo llena. | Capturar PROPIO/TERCERO; exportar PR/PA. Regla ya confirmada. |
| I | REMISION ESC 1 No. | Parcial: hay `codigo_orden`, no documento por asignación. | Confirmar si la orden es esta remisión; evitar equiparación automática. |
| J | NOMBRE ESC 1 | Capturado: `ordenes_escolta.nombre_escolta`. | Usar asignación identificada del usuario y snapshot histórico. |
| K | PLACA ESC 1 | Capturado: `ordenes_escolta.placa_escolta`. | Conservar vehículo/asignación y snapshot. |
| L | REMISION ESC 2 No. | Pendiente. | Documento del segundo escolta, por asignación. |
| M | NOMBRE ESC 2 | Pendiente. | Seleccionar segundo usuario/asignación. |
| N | PLACA ESC 2 | Pendiente. | Vehículo de esa asignación. |
| O | REMISION TECNICO | Pendiente. | Documento del técnico, por asignación. |
| P | NOMBRE TECNICO | Pendiente. | Identificar persona/asignación técnica. |
| Q | CONDUCTOR CAMABAJA | Parcial: manifiesto guarda cédula; tiene propiedad de nombre, pero el INSERT revisado no la llena. | Capturar/persistir identidad y nombre histórico, enlazados al servicio. |
| R | PLACA CAMABAJA | Capturado: cabecera y `servicio_trayectos.placa_camabaja`. | Reutilizar dato validado al preparar manifiesto. |
| S | PLACA REMOLQUE | Parcial: se guarda en manifiesto, separado del servicio. | Conductor/administrativo completa y enlaza. |
| T | CLIENTE | Capturado: cliente_id, empresa y snapshots de orden/servicio. | Mantener identidad; cliente comercial no equivale por sí mismo a empresa propietaria del usuario. |
| U | DIG | Pendiente: no hay flujo de revisión administrativa que lo complete. | Revisor registra estado, autor y fecha; exportar OK al revisar. Significado confirmado; mecanismo propuesto. |
| V | PROGRAMA | Parcial: aparece en modelo/vista previa Flutter y modelo de remesa; DTO y creación de remesa .NET no lo persisten. | Completar recorrido formulario → API → base → servicio. |
| W | OBRA | Parcial: DTO y creación de remesa guardan `obra`, sin relación al servicio. | Capturar temprano cuando se conozca y reutilizar. |
| X | OS | Pendiente. | Registrar número de orden de servicio; no confundir con orden de escolta. |
| Y | FECHA SOLICITUD | Pendiente. | Capturar fecha real; no asumir created_at. |
| Z | ESTADO OS | Pendiente. | Definir estados de OS; no reutilizar BORRADOR/CONFIRMADA automáticamente. |
| AA | PESO | Parcial: trayecto tiene toneladas y kg derivados, pero orden no los escribe; remesa sí guarda kg. | Capturar toneladas conocidas, conservar pendientes; convertir ×1000 al RNDC. Unidad TEG confirmada. |
| AB | TIPO DE CARGA | Parcial: remesa guarda descripción y códigos de producto/naturaleza/operación. | Definir cuál representa este encabezado; tipo_operacion no es automáticamente tipo de carga. |
| AC | TIPO DE CARGA (ESCOLTA) | Parcial: se captura máquina por viaje. | Validar equivalencia máquina → esta columna; conservar clasificación separada si difiere. |
| AD | ORIGEN | Capturado: ítem y trayecto. | Complementar código DANE/dirección para RNDC; texto libre no basta para SOAP. |
| AE | DESTINO | Capturado: ítem y trayecto. | Complementar código DANE/dirección y destinatario. |
| AF | VALOR FLETE | Parcial: existe campo en remesa, no liquidación TEG por servicio. | Administración captura importe real; no interpretar default 0 como liquidado. |
| AG | VALOR TECNICO | Pendiente. | Administración liquida asignación técnica. |
| AH | V/L ESC No. 1 | Pendiente. | Administración liquida escolta 1. |
| AI | V/L ESC No. 2 | Pendiente. | Administración liquida escolta 2. |
| AJ | VALOR TOTAL | Pendiente en app. Excel contiene SUM(AF:AI) en filas revisadas. | Administración valida importes; proponer cálculo, sin convertir pendientes en cero. Confirmar política de ajustes. |
| AK | RNDC | Parcial: existen estados, radicados, XML y errores de documentos separados. | Definir proyección del resultado RNDC por servicio; significado general confirmado. |
| AL | LEG No | Pendiente. | Administración registra legalización y define documento. |
| AM | VALOR ANT PARA VIAJE | Parcial: manifiesto guarda valor_anticipo; no hay aplicación/conciliación por servicio TEG. | Administración registra anticipo real y su distribución; no duplicarlo en varias filas. |
| AN | FECHA ANT | Pendiente. | Registrar fecha efectiva del anticipo; no fecha de pago del manifiesto. |
| AO | No. ANTICIPO | Pendiente. | Registrar documento de anticipo. |
| AP | FECHA LEGALIZACION | Pendiente. | Administración registra cierre/soporte. |
| AQ | VERIFICACION | Pendiente. | Control separado de DIG con responsable/fecha; definir criterios y valores. |
| AR | NOTA | Parcial: hay observación general de orden y de remesa, no nota consolidada por servicio. | Definir alcance y permitir nota por viaje cuando sea distinta. |

## Cobertura: cómo medirla sin exagerarla

Hay **6 columnas con correspondencia directa de captura en órdenes**: J, K, R, T, AD y AE. Además se captura máquina, candidata a AC, y existen datos parciales para otras columnas. Esto no significa que solo existan seis datos en toda la aplicación: RNDC tiene más información, pero aún no se puede reconstruir una fila TEG de manera trazable usando un único servicio.

Superar el 80 % de 44 requiere **al menos 36 columnas**. No se ha demostrado ese resultado. Deben medirse por separado:

1. Cobertura funcional: columnas que tienen captura, persistencia y salida correctas.
2. Completitud por servicio: valores presentes frente a los aplicables, distinguiendo pendiente y no aplica.
3. Automatización: valores reutilizados/calculados o recibidos del RNDC frente a digitados por una persona.

Un campo financiero escrito por el administrador puede estar cubierto por la app sin ser automático. Un servicio sin segundo escolta no debe contarse como error ni llenarse con datos ficticios. Falta acordar esa regla de medición antes de prometer un porcentaje.

## Flujo que debe cerrar el circuito

1. Usuario escolta crea orden y viajes, con placas propias autorizadas y cliente. Conserva identidades al guardar/reintentar.
2. Cada viaje mantiene su servicio existente. El escolta completa datos operativos conocidos; lo desconocido queda pendiente explícito.
3. Bandeja administrativa abre esos mismos servicios, muestra faltantes y completa cliente/obra/programa/OS, asignaciones y datos RNDC. Existe un archivo `ServiciosScreen`, pero no está registrado en la navegación revisada y es de consulta, no una bandeja de preparación.
4. Administrativo prepara remesa desde el servicio, evitando volver a digitar. Conserva vínculo explícito; no relacionar por placa, nombre o fecha.
5. Manifiesto toma la remesa aceptada. El código actual usa `remesa.Consecutivo` en `consecutivo_remesa`; el radicado de respuesta es otro dato. El consecutivo lo asigna la aplicación, no debe confundirse con la autorización RNDC.
6. Se registran ejecución, revisión, importes, anticipos y legalización sin sobrescribir los documentos emitidos.
7. Vista/exportador produce las 44 columnas con procedencia y faltantes. Propuesta: una fila por servicio/viaje, pendiente de confirmar reglas cuando existen varios documentos o asignaciones. Evitar multiplicación de filas y doble suma al hacer joins.

No debe asumirse una remesa por orden completa: una orden admite varios viajes. Antes del vínculo RNDC se debe definir si un servicio admite varios documentos y cómo se representa esa cardinalidad en el Excel.

## Usuarios, empresas y decisiones anteriores

- La gestión actual incluye usuarios con varias placas escolta y clientes con varias placas de carga (`usuario_vehiculos_escolta` y `cliente_placas`); `cliente_vehiculos` sigue siendo otra relación con vehículos RNDC. No son el mismo catálogo ni prueban propiedad empresarial del usuario.
- Flutter reconoce admin/operator/auditor; operator se presenta como escolta/operador. Conductor, administrativo y administrador de cliente no están resueltos como roles diferenciados de extremo a extremo.
- No hay pertenencia empresarial de usuario ni aislamiento por empresa en el modelo revisado. Los catálogos consultan clientes globales. Falta que solo TEG asigne empresa y que cada administrador de cliente opere dentro de la suya.
- El centro de costo por escolta y el conteo operativo por carro no quedan completos solo por tener un consecutivo por placa. Se necesitan asignaciones e informes con reglas de conteo, incluyendo borradores/anulaciones y viajes múltiples.
- El envío actual de órdenes usa configuración central de Brevo. Las antiguas columnas de credenciales por usuario no describen ese flujo vigente.
- La última decisión de WhatsApp usa la cuenta activa del teléfono y selección de contacto. Tener el número del usuario en la base no permite forzar otra cuenta emisora. La mención de validar el número registrado en el resumen es una discrepancia con esa decisión, no una función ya implementada.
- El login propio consulta users; no usa Supabase Auth. Sin embargo, las tablas nuevas de servicios tienen RLS activado y acceso por backend. «RLS deshabilitado en todas las tablas» es una descripción histórica, no una regla para futuras migraciones. El esquema remoto completo no se verificó en esta auditoría.
- El manejo actual de contraseña y el aislamiento empresarial requieren revisión antes de entregar acceso a múltiples empresas. La autorización debe aplicarse en backend/base, no solo ocultar módulos.
- RNDC es autoridad para resultados regulatorios; Supabase debe conservar también la operación interna que RNDC no representa: asignaciones, control, costos y legalizaciones.

## Orden recomendado del desarrollo

**Primero: trazabilidad y captura faltante.** Activar bandeja administrativa sobre servicios existentes; completar campos operativos, incluida persistencia de programa. Definir fecha real, tipo de carga, OS, COD INT y equivalencia de remisión escolta. No recrear servicios ni aplicar nuevamente scripts iniciales CREATE TABLE.

**Segundo: acceso y participantes.** Pertenencia empresarial, permisos por rol/empresa, asignaciones de personas/usuarios, vehículos y remisiones por asignación. No representar escolta 2 y técnico únicamente como nombres libres en una cabecera.

**Tercero: RNDC desde servicio.** Vínculos, precarga, validaciones y recuperación de respuestas inciertas. La idempotencia de guardar orden no demuestra idempotencia de generar remesa/manifiesto: estos tienen sus propios flujos y necesitan pruebas específicas.

**Cuarto: administración y salida TEG.** Importes, controles, anticipos, legalización y exportador. Una vista preliminar de faltantes puede hacerse antes para medir avance sin inventar datos.

## Pruebas de aceptación necesarias

- Orden con dos viajes: dos servicios estables y editables; reinicio, doble clic y timeout no agregan otro servicio.
- Completar borrador conserva clientOrderId, clientItemId y servicio_id; una orden nueva obtiene identidades nuevas.
- Cada dato capturado reaparece tras recargar desde servidor, no solo desde estado local.
- Servicio seleccionado genera documentos vinculados a él; reintento incierto no crea otro documento sin conciliación.
- Administrador de otra empresa no puede consultar/modificar servicios, usuarios ni clientes ajenos mediante API directa.
- Dos escoltas y un técnico exportan sus nombres, placas, remisiones e importes en posiciones correctas.
- 18 toneladas se conservan como 18 en TEG y 18000 kg en el intercambio que lo requiera.
- Fecha de orden, solicitud, transporte, factura y legalización permanecen distintas.
- Exportación conserva orden exacto A:AR, no duplica filas/importes y distingue vacío pendiente, no aplica y cero real.

## Evidencias y alcance

- Excel original: encabezados Hoja1!A1:AR1 y fórmulas de total en las primeras filas revisadas. No se modificó.
- `lib/modules/ordenes_escolta/screens/nueva_orden_escolta_screen.dart`: captura del formulario.
- `sql/20260912_servicios_borradores.sql`: esquema inicial de servicios/trayectos; referencia, no script para repetir sobre tablas existentes.
- `sql/20260913_numeracion_placas_alta_usuarios.sql`: numeración y guardar/recuperar orden.
- `sql/20260919_gestion_clientes_placas.sql`: gestión de clientes/placas.
- `lib/modules/ordenes_escolta/screens/servicios_screen.dart` y `lib/app.dart`: pantalla disponible frente a rutas.
- `build/TGBACK-release/Dtos/GenerarRemesaDto.cs`, `Services/SupabaseService.cs`, `Controllers/RemesaController.cs` y `Controllers/ManifiestoController.cs`: escritura de documentos y vínculo remesa→manifiesto.
- `lib/data/models/app_user.dart`: roles y ausencia de pertenencia empresarial.
- `sql/DEFINICION_BASE_DATOS_TEG.md`: diseño propuesto, no prueba de implementación.

El texto adjunto se trató como propuesta. Su instrucción «NO crear servicios todavía» quedó desactualizada respecto del código existente. Tampoco se ejecutaron sus propuestas SQL ni se asumieron joins por servicio_id que hoy no existen en los modelos RNDC. Esta auditoría no cambió producción, no envió correos y no generó documentos RNDC.
