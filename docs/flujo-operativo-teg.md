# Flujo operativo TEG y cobertura del modelo de datos

Estado: propuesta funcional y técnica basada en el código local, el DDL aportado y el Excel. No es una migración aplicada ni una certificación del backend remoto. El backend está en otro proyecto según README.md y no se inspeccionó su implementación. Se conserva el trabajo existente.

## 1. Decisión principal

Crear un expediente de **servicio** con identificador interno estable. Cada servicio representa un trayecto o una prestación facturable concreta, y alimenta una fila del modelo TEG. Una orden de escolta puede autorizar varios servicios; un servicio puede recibir acompañamiento de dos escoltas con órdenes distintas. Los documentos se vinculan mediante identificadores, evitando volver a digitar la misma operación.

Una mensualidad debe registrar período y concepto; no debe fingir un trayecto. Si además hay desplazamientos, se registran como servicios relacionados, sin duplicar el valor de la mensualidad. El Excel contiene transporte, acompañamiento, turnos, horas adicionales y mensualidades: no se puede exigir remesa y manifiesto a toda fila indiscriminadamente. La clasificación documental corresponde al administrativo, con sustento y revisión de los requisitos aplicables.

El COD INT del archivo se repite: se conserva como referencia comercial, **no** como clave única del servicio. Se agregan UUID y folio interno propios. Tampoco se deduplican viajes solamente por fecha, origen, destino o placa: un recorrido puede repetirse legítimamente.

## 2. Qué está funcionando y dónde se rompe la continuidad

| Evidencia | Consecuencia | Cambio propuesto |
| --- | --- | --- |
| `ordenes_escolta` y sus ítems guardan cabecera, máquina y recorrido; el DDL no vincula los ítems con remesas. | Se pierde la trazabilidad del viaje al generar documentos. | Vincular cada ítem con un servicio y cada remesa con su servicio. |
| La orden tiene un solo nombre y placa de escolta; el Excel tiene dos grupos de escoltas y técnico. | Una cabecera no alcanza para representar el servicio completo. | Asignaciones por servicio, con función y posición de exportación. Conservar las órdenes individuales. |
| `app_user.dart` solo reconoce admin, operator y auditor; los roles desconocidos pasan a operator. | Agregar 'escolta' solamente en SQL puede otorgar permisos incorrectos. | Definir capacidades explícitas y denegar roles desconocidos. |
| `app.dart` comprueba sesión en el redirect, sin matriz de roles. | No hay una barrera global por ruta para el escolta. | Verificación por ruta, pantalla, API y base de datos. |
| `user_repository.dart` consulta por email/password y devuelve password; `AuthProvider` además inicia sesión en una API. | Dos mecanismos de acceso y contraseña dentro del modelo Flutter. | Unificar identidad y retirar el acceso directo a contraseñas. |
| `sql/create_tables.sql` deshabilita RLS para varias tablas. | El SQL versionado no ofrece aislamiento por usuario. | Auditar permisos reales y migrar acceso; no asumir que este archivo refleja producción. |
| Existe migración de credenciales SMTP a Vault. | La columna de correo puede contener una referencia a un secreto, no necesariamente una contraseña real. | Comprobar aplicación de la migración y conservar acceso exclusivamente servidor. |
| `saveRemesa()` guarda directamente y usa un consecutivo TEMP si falla el RPC; `generarRemesa()` llama otra API sin enviar ese ID ni consecutivo en el cuerpo inspeccionado. | El contrato visible no asegura que el envío opere sobre el mismo borrador; riesgo de duplicación. | Guardar y enviar por un único ID, con numeración del servidor y sin TEMP oficial. Verificar backend antes de afirmar duplicados efectivos. |
| Varias llamadas de remesas/manifiestos no incluyen Bearer en el código inspeccionado. | Debe comprobarse la autorización del servidor. | Exigir sesión verificada y capacidad específica en todos los endpoints. |
| La creación de orden reserva un registro y luego genera/sube PDF; un nuevo intento vuelve a reservar. | Una falla de PDF o correo puede terminar creando otra orden. | Retomar el ID reservado, con idempotencia persistente y trabajos de PDF/correo independientes. |
| `manifiestos.remesa_id` modela una remesa por manifiesto y `dispatches_view` depende de esa FK. | No representa agrupaciones de remesas sin cambiar consumidores. | Mantener compatibilidad inicial; introducir relación de documentos si se habilita agrupación. |

## 3. Roles y usuarios

| Capacidad | Escolta | Administrativo | Administrador | Auditor existente |
| --- | --- | --- | --- | --- |
| Crear orden y proponer nuevos viajes | Sí, propios | Sí | Sí | No |
| Ver operación | Propia o asignada, datos mínimos | Todas las operativas | Todas | Lectura autorizada |
| Modificar captura | Borrador propio o corrección solicitada | Revisar y completar | Revisar y completar | No |
| Reportar ejecución y adjuntar soportes | Propios/asignados | Sí | Sí | No |
| Crear/enviar remesa y manifiesto | No | Sí, con datos aprobados | Sí | No |
| Cambiar fletes, costos, anticipos y facturación | No | No por defecto | Sí | No |
| Ver valores necesarios para emitir un manifiesto | No | Sí, solo los necesarios | Sí | Según permiso de lectura |
| Gestionar cuentas y roles | No | No | Sí | No |

El administrativo puede generar documentos con valores aprobados por el administrador. Si falta un valor requerido para emitir, la operación queda en «pendiente de aprobación económica». Los valores no requeridos hasta el cierre no bloquean la captura operativa.

Alta de usuario: administrador introduce nombre y correo, selecciona rol y vincula el perfil de escolta existente cuando corresponda; se envía invitación individual y se activa la cuenta. No usar cuentas compartidas ni contraseñas predeterminadas. Mantener desactivación, recuperación de acceso y auditoría de cambios de rol. La identidad del usuario no equivale a una placa: las asignaciones de vehículo deben poder cambiar sin cambiar su cuenta.

Recomendación de identidad: Supabase Auth con `users.auth_user_id` único como transición, manteniendo los UUID actuales y sus FK. El backend valida el token y consulta estado/rol confiables. No utilizar un JWT propio con `auth.uid()` sin integración comprobada. El rol se administra por servidor; ni metadatos editables por usuario ni el cuerpo de la solicitud otorgan privilegios. Retirar `users.password` después de migrar y validar el acceso; no borrar usuarios que tienen documentos.

Proteger los valores económicos en tablas separadas y respuestas filtradas: una política por filas, por sí sola, no oculta columnas. Los listados mínimos de clientes/escoltas/vehículos deben permitir completar la orden sin exponer cuentas, secretos o finanzas.

## 4. Flujo de trabajo diario

### A. Captura y orden de escolta

1. El escolta ingresa a «Mis órdenes» y «Crear orden». Su nombre se toma del perfil; confirma la placa asignada.
2. Selecciona cliente y camabaja cuando aplique. La relación cliente-vehículo sirve para sugerir vehículos, no para atribuir propiedad ni bloquear excepciones sin revisión.
3. Agrega uno o varios viajes: máquina/descripción, origen y destino. Añade fecha prevista por viaje, observaciones por viaje y, si los conoce, conductor, remolque, peso con unidad, programa, obra y referencia de OS. El peso estimado queda marcado para revisión.
4. Cada viaje puede crear un servicio o vincularse a uno asignado. Una segunda orden de otro escolta debe poder vincularse al mismo servicio: así aparecen ESC 1 y ESC 2 en una sola fila y no se duplica el transporte.
5. Guarda borrador aunque falten datos administrativos. Para confirmar la orden se validan los mínimos operativos y la firma ya prevista en la app. La confirmación fija una versión de la orden; las correcciones posteriores conservan el original firmado.
6. El servidor guarda cabecera, ítems y vínculos en una transacción y devuelve un ID persistente. PDF y correo tienen estado propio y reintento sobre ese ID. El correo es un aviso; el administrativo encuentra el trabajo pendiente dentro de la aplicación.

La fecha de orden, la fecha solicitada y la fecha real del transporte son campos distintos. No copiar una en otra como dato confirmado.

### B. Revisión administrativa

7. «Servicios pendientes» muestra una fila por servicio, origen de la orden, responsables, tipo de servicio y faltantes con dueño: escolta, administrativo o administrador.
8. El administrativo valida datos capturados y completa identificaciones, terceros, sedes, direcciones, municipio/código DANE, carga, empaque, cantidades, peso confirmado, conductor, vehículo y póliza según la operación. Una dirección de obra no sustituye un municipio DANE.
9. Clasifica tratamiento documental: pendiente de definir, RNDC propio, documento externo o no aplica con motivo. Las últimas opciones exigen revisión administrativa; una celda '-' en un Excel histórico no prueba una excepción normativa. Un documento externo conserva emisor, número y soporte, sin emitirlo de nuevo.
10. Si faltan costos necesarios para el documento, solicita al administrador la aprobación del importe. Si falta información de campo, devuelve únicamente esos campos al escolta, con comentario.

### C. Remesa y manifiesto

11. «Preparar remesa» abre un borrador prellenado desde el servicio. Se completa el conjunto de campos del XML vigente; el Excel es una salida comercial y no contiene por sí solo todos los datos exigibles para RNDC.
12. «Enviar remesa» trabaja sobre el ID guardado. El servidor asigna/reserva de forma atómica el consecutivo correspondiente, valida los datos y registra un intento. Se guarda el radicado de la respuesta por separado.
13. Solo una remesa con aceptación confirmada habilita «Preparar manifiesto» en la ruta RNDC propia. Se usa la FK interna y se obtiene el consecutivo de esa remesa desde el servidor; no se digita manualmente otra vez.
14. El administrativo revisa camabaja, remolque, conductor, titular y condiciones/valores aprobados. El manifiesto obtiene su propio consecutivo. Se guardan radicado y autorización cuando estén presentes en la respuesta correspondiente.
15. Un timeout deja «resultado por verificar». Primero se consulta y concilia; no se asigna otro consecutivo ni se reenvía automáticamente. Un rechazo explícito deja el borrador corregible y conserva el historial de intentos.

### D. Ejecución, cumplidos y cierre

16. El escolta reporta ejecución, fechas/horas reales, novedades y soportes de sus servicios. Estos reportes no emiten un cumplido RNDC por sí mismos.
17. El administrativo revisa soportes, aceptación/firma y realiza los procesos de cumplido aplicables. La firma de la orden no sustituye la aceptación electrónica del manifiesto.
18. El administrador completa costos, factura, anticipos, legalización y verificación. El sistema calcula total y muestra faltantes; cierre operativo y cierre financiero son independientes.
19. «Exportar modelo TEG» consulta registros persistidos. Permite exportación parcial con pendientes visibles y exportación de cierre únicamente cuando los campos exigibles estén completos o tengan una razón válida de no aplicación.

## 5. Modelo de datos incremental

Nombres siguientes propuestos, todavía no existentes ni aplicados:

| Entidad | Propósito y relaciones |
| --- | --- |
| `servicios` | UUID, folio único, referencia COD INT no única, cliente, `service_type` controlado (PROPIO/TERCERO), tipo de prestación separado, fechas/período, programa, obra, OS, estado operativo y tratamiento documental. |
| `servicio_trayectos` | Datos del recorrido, máquina/carga, dirección y municipio de origen/destino, peso capturado en toneladas, peso confirmado y conversión derivada en kg, conductor/camabaja/remolque. Máximo un trayecto por servicio en la primera versión. Prestaciones por período pueden no tenerlo. |
| `ordenes_escolta_items.servicio_id` | FK nullable durante migración; un ítem vincula su viaje con el expediente. Varias órdenes pueden compartir servicio. Conservar campos actuales como versión documental histórica. |
| `servicio_personal` | Servicio, escolta/técnico, función, posición ESC 1/ESC 2, vehículo y snapshots; relación con ítem de orden si existe. Unicidad de posición activa por servicio y control de asignaciones duplicadas. Técnico con remisión propia o compartida según soporte real. |
| `remesas.servicio_id` | FK y snapshots de datos validados al emitir; un servicio puede conservar varias versiones documentales, con una vigente según reglas aprobadas. Primera UI: una remesa vigente por servicio. No actualizar snapshots aceptados al editar un maestro. |
| `manifiesto_remesas` | Tabla de relación para agrupación futura; conservar y rellenar desde `manifiestos.remesa_id`. Mantener una única fuente de escritura y actualizar vistas/API antes de retirar FK antigua. No habilitar múltiples remesas en UI mientras el backend no lo soporte. |
| `servicio_costos` | Flete comercial, técnico, escolta 1, escolta 2, aprobación, moneda y versión. Importes desconocidos son NULL; cero requiere captura/confirmación explícita. Total calculado. |
| `facturas` y `factura_servicios` | Número, emisor, fecha y vínculos a servicios. Una factura puede cubrir varios servicios; en la primera exportación, una factura vigente por servicio. Notas/reemplazos conservan historial. |
| `anticipos` y `legalizaciones` | Movimientos con valor, fecha, referencia y soporte; pertenecen a servicio o se distribuyen explícitamente entre servicios. Una asignación impide contabilizar el mismo anticipo completo en varias filas. |
| `rndc_intentos` | Documento, proceso, clave idempotente, versión/hash de datos, estado, fechas, respuesta y conciliación. Restricción de un intento en curso por documento/proceso. XML persistido sin credenciales. |
| `servicio_eventos` | Autor, fecha, cambio de estado, motivo y versión. Complementa soportes y fechas/horas de ejecución. |
| `modelo_teg_view` | Proyección de las 44 columnas, con joins controlados para no multiplicar filas. No almacenar una segunda copia editable del Excel. |

Mantener `clientes`, `cliente_vehiculos`, `vehiculos` y `escoltas`. Agregar FK donde hoy hay solo texto y conservar snapshots. Incorporar catálogo de conductores y técnicos si no existe en backend; no reutilizar un cliente como conductor por coincidencia de nombre.

`dispatches` debe revisarse como posible legado de captura de mensajes: inventariar consumidores y registros antes de archivarlo. No eliminarlo por coexistir con una vista. `settings` conserva configuración; la numeración oficial debe reservarse con transacción/sequence y unicidad por documento, sin decrementos ni reutilización al fallar. Revisar el default de simulación aportado contra el esquema real antes de cualquier cambio.

## 6. Las 44 columnas del Excel: origen, responsable y regla

Fuente: `MODELO BASE DE DATOS TEG.xlsx`, `Hoja1!A1:AR11`. Diez filas de ejemplo con contenido además de la cabecera; el rango declarado de la hoja llega a la fila 8847, lo cual no equivale a 8846 operaciones.

| Col. | Encabezado exacto | Origen propuesto / responsable / regla |
| --- | --- | --- |
| A | FECHA TRANSPORTE | Servicio: fecha real reportada por escolta y validada por administrativo. Distinta de fecha de orden. |
| B | COD INT | Servicio: referencia comercial del administrativo; se repite en ejemplos, no usar como PK. |
| C | FRA No. | Factura: administrador. Texto para conservar prefijos. |
| D | FECHA FRA | Factura: administrador. |
| E | REMESA TRANS No. | `remesas.consecutivo` automático o referencia de documento externo validado. No reemplazar por radicado. |
| F | AUT REMESA | `remesas.radicado_rndc` como correspondencia propuesta, a verificar contra respuesta real y significado comercial de autorización. Guardar origen externo si aplica. |
| G | MTO | Consecutivo del manifiesto como correspondencia propuesta; administrativo confirma significado de abreviatura. |
| H | (PR)/(PA) | Regla confirmada TEG: PR = servicio propio; PA = particular/tercero (otra empresa). Administrativo selecciona `service_type`: PROPIO o TERCERO; exportar PR o PA respectivamente. |
| I | REMISION ESC 1 No. | Orden vinculada a asignación ESC 1, consecutivo automático; documento externo si el servicio lo requiere. |
| J | NOMBRE ESC 1 | Snapshot de escolta asignado en posición 1. |
| K | PLACA ESC 1 | Snapshot de vehículo de la asignación 1. |
| L | REMISION ESC 2 No. | Orden vinculada a asignación ESC 2; puede diferir de ESC 1. |
| M | NOMBRE ESC 2 | Snapshot de escolta asignado en posición 2. |
| N | PLACA ESC 2 | Snapshot de vehículo de la asignación 2. |
| O | REMISION TECNICO | Referencia documental de asignación técnica; administrativo valida, no copiar ESC 1 por defecto. |
| P | NOMBRE TECNICO | Técnico asignado, propuesto en captura y validado por administrativo. |
| Q | CONDUCTOR CAMABAJA | Captura opcional del escolta; administrativo valida identificación/nombre y snapshot del manifiesto cuando exista. |
| R | PLACA CAMABAJA | Captura existente; FK/placa confirmada por servicio y snapshot documental. |
| S | PLACA REMOLQUE | Nueva captura opcional del escolta; administrativo valida y reutiliza en manifiesto. |
| T | CLIENTE | Cliente seleccionado y nombre histórico del servicio. |
| U | DIG | Indicador de digitación/control confirmado por TEG. OK significa correctamente digitado/revisado. Administrativo registra la revisión con autor y fecha; independiente del dígito de verificación del NIT. |
| V | PROGRAMA | Captura opcional escolta; administrativo valida; reutilizar dato en remesa cuando corresponda. |
| W | OBRA | Captura opcional escolta; administrativo valida. |
| X | OS | Número/referencia de orden de servicio; escolta puede informar, administrativo valida. Guardar texto, incluye referencias alfanuméricas. |
| Y | FECHA SOLICITUD | Fecha de solicitud del servicio, administrativo; no usar fecha de creación automáticamente. |
| Z | ESTADO OS | Administrativo, catálogo de estado y referencia de cotización separada. Los ejemplos mezclan ambos conceptos: conservar texto original al migrar. |
| AA | PESO | Regla confirmada TEG: toneladas. Escolta captura y administrativo confirma; 18 = 18 t. Exportar toneladas y derivar kg mediante multiplicación por 1000 para campos que requieren kg. |
| AB | TIPO DE CARGA | Descripción comercial/carga o concepto de servicio. Administrativo valida. No equivale al código `tipo_operacion` RNDC. |
| AC | TIPO DE CARGA (ESCOLTA) | Máquina/código observado por escolta, desde ítem/servicio; conservar separado de descripción RNDC. |
| AD | ORIGEN | Lugar/dirección del servicio, captura escolta; municipio DANE separado y validado. |
| AE | DESTINO | Lugar/dirección del servicio; opcional para prestación por período, obligatorio según clasificación del traslado. |
| AF | VALOR FLETE | Administrador en costos. Aclarar si es cobro al cliente; no igualar automáticamente al pago al transportador del manifiesto. |
| AG | VALOR TECNICO | Administrador en costos. |
| AH | V/L ESC No. 1 | Administrador, costo de asignación 1. |
| AI | V/L ESC No. 2 | Administrador, costo de asignación 2. |
| AJ | VALOR TOTAL | Calculado: AF + AG + AH + AI, como `SUM(AF2:AI2)` del archivo. En la app, pendiente si falta un componente aplicable; no mostrar total definitivo incompleto. |
| AK | RNDC | Información/resultado asociado al proceso RNDC, según definición confirmada TEG. Proyección del seguimiento RNDC del servicio; definir la presentación cuando haya varios procesos. No sustituye consecutivos ni radicados. |
| AL | LEG No | Referencia de legalización propuesta; administrador confirma significado. |
| AM | VALOR ANT PARA VIAJE | Administrador; monto de anticipo asignado al servicio. No asumir equivalencia con anticipo RNDC sin conciliación. |
| AN | FECHA ANT | Fecha del anticipo; administrador. |
| AO | No. ANTICIPO | Referencia del anticipo; administrador, texto. |
| AP | FECHA LEGALIZACION | Fecha de legalización; administrador. |
| AQ | VERIFICACION | Campo de verificación/control del proceso, confirmado por TEG. Administrador registra resultado, autor y fecha; catálogo de resultados y criterios de cierre por precisar. |
| AR | NOTA | Nota administrativa del servicio; conservar por separado observaciones operativas originales. |

El archivo tiene una sola columna VALOR FLETE y una fórmula de total de cuatro componentes; el flete repetido en la solicitud no obliga a crear dos columnas iguales.

No almacenar '-' ni 'N/A' en fechas o importes. Guardar NULL y motivo de no aplicación por separado; representar el marcador al exportar. Diferenciar datos pendientes de datos no aplicables. Para más de dos escoltas, múltiples anticipos o legalizaciones, el exportador debe señalar conflicto de representación y ofrecer detalle o una regla de consolidación aprobada; nunca escoger silenciosamente el primer registro. La base no debe perder esos movimientos por las limitaciones del formato.

## 7. Estados y recuperación

Mantener estados separados:

- Servicio: borrador → pendiente de revisión → revisado → programado → en ejecución → ejecutado → cerrado operativo. Devolución y cancelación con motivo.
- Documento RNDC: borrador → listo → enviando → aceptado / rechazado / resultado por verificar. La conciliación resuelve el estado incierto. Cumplidos y anulaciones son procesos registrados, no ediciones arbitrarias del estado.
- Finanzas: pendiente → valores aprobados → facturado → legalizado → cerrado financiero, según campos aplicables.
- PDF/correo: pendiente → procesando → disponible/enviado o error recuperable.

Son estados propuestos. Los checks SQL existentes no aceptan todos estos valores: preparar migración y compatibilidad antes de escribirlos desde Flutter. `generated` debe tener una definición comprobada; producir un PDF nunca basta para marcar un documento como aceptado por RNDC.

Para cada transición el servidor valida rol, propiedad, versión y prerrequisitos. Usar control de concurrencia para evitar que una revisión sobrescriba otra. Corregir una orden firmada mediante versión relacionada, no reemplazar su PDF. Evitar borrado físico de documentos o costos cerrados.

## 8. Consecutivo, radicado y vínculo RNDC

El XML local de prueba contiene `CONSECUTIVOREMESA`. Se conserva la distinción entre UUID interno, consecutivo de remesa enviado y radicado de respuesta. La guía oficial V5 describe la respuesta con `ingresoid` como radicación; ese valor no sustituye el consecutivo de remesa.

El manual oficial del Web Service muestra asociación de remesas mediante `CONSECUTIVOREMESA` y admite varios elementos dentro de `REMESASMAN`. El esquema local actual es más limitado. Antes de habilitar agrupaciones se debe contrastar el XML del backend con el diccionario vigente y actualizar la API, la vista y la exportación.

Fuentes oficiales consultadas:

- [Guía de uso Web Service RNDC V5, aprobada 27/05/2026](https://plc.mintransporte.gov.co/Portals/0/Manuales/GUIA%20Uso%20del%20Web%20Service%20en%20el%20RNDC%20V5%20.pdf?ver=2026-05-27-084523-160), respuesta/radicación y procesos.
- [Manual Web Service RNDC v3.0, referencia de asociación de remesas](https://rndc.mintransporte.gov.co/LinkClick.aspx?fileticket=024lc_Rpl0k%3D&language=es-MX&tabid=204). Referencia histórica a contrastar con el diccionario vigente para implementación.
- [Manuales y guías oficiales vigentes](https://plc.mintransporte.gov.co/RNDC/Manuales-y-gu%C3%ADas/Manuales-Empresas-de-transporte).

## 9. Orden de implementación y migración

1. Inventariar backend real, esquema desplegado, políticas, funciones, consumidores y documentos existentes. Aplicar las reglas confirmadas de PR/PA, controles y toneladas; resolver únicamente las definiciones todavía abiertas. Respaldar y probar restauración antes de intervenir producción.
2. Unificar autenticación; incorporar escolta y administrativo, conservar auditor, mapear operator explícitamente después de revisar sus funciones. Migrar identidades conservando FK. Probar permitidos/denegados antes de revocar el acceso anterior.
3. Crear entidades de servicios, asignaciones y costos de forma aditiva. Agregar vínculos nullable. Por cada ítem histórico generar un candidato de servicio con procedencia; coincidencias entre órdenes se revisan para unir ambos escoltas sin fusionar viajes repetidos por error.
4. Vincular remesas/manifiestos históricos solo con evidencia suficiente. Mantener una bandeja de «sin vincular». No fabricar destinos, unidades, radicados ni valores cero para pasar restricciones.
5. Implementar captura/bandeja/prellenado y aprobación de valores. Mantener PDF/firma actuales con recuperación por ID. Actualizar API para guardar y enviar un mismo borrador, numeración atómica, permisos y conciliación RNDC.
6. Agregar ejecución/cumplidos, facturación, anticipos, legalización y exportación de 44 columnas. Validar una operación completa antes de ampliar alcance.
7. Comparar conteos, vínculos, importes y documentos con el origen; recién entonces exigir FK/NOT NULL para registros nuevos y retirar accesos/columnas legadas. Conservar archivos históricos y un procedimiento de reversión.

Reversión: desactivar nuevas rutas mediante configuración y conservar tablas añadidas y datos capturados; no borrar nuevas operaciones para volver al frontend anterior. La vuelta a un mecanismo de autenticación inseguro no es una estrategia de reversión. Migraciones de identidad requieren un plan de acceso administrativo de recuperación probado.

No se propone limpiar mediante DROP/TRUNCATE ni reiniciar consecutivos. La limpieza necesaria consiste en corregir relaciones, asegurar acceso, normalizar campos y reconciliar registros. Las migraciones remotas y creación de cuentas reales se ejecutan en una fase posterior con entorno identificado y autorización concreta.

## 10. Criterios de aceptación

- Una orden con tres viajes produce tres servicios vinculados; se puede emitir documentación y cerrar cada uno independientemente.
- Dos órdenes de escoltas distintas vinculadas al mismo servicio generan una sola fila TEG con ambos grupos de escolta.
- Un escolta no puede leer costos ni crear remesas/manifiestos/cuentas, incluso enviando solicitudes manuales a la API o base.
- Un rol desconocido y una cuenta inactiva no tienen acceso; desactivación y cambios de rol invalidan acceso según política de sesión definida.
- Un error de PDF/correo retoma la orden existente, sin consumir otra orden para la misma solicitud.
- Doble clic o dos solicitudes simultáneas no emiten dos documentos; un timeout aceptado por RNDC se concilia sin segundo envío.
- El manifiesto utiliza el consecutivo de la remesa aceptada vinculada y conserva su radicado por separado.
- El administrativo puede emitir con importes aprobados sin modificarlos; el escolta puede capturar antes de que esos importes estén disponibles.
- Un cambio posterior de cliente/escolta/vehículo no modifica los snapshots de documentos emitidos.
- No aparecen totales definitivos si falta un costo aplicable; se diferencia cero confirmado de dato pendiente.
- Turnos/mensualidades/acompañamientos mantienen su concepto y tratamiento documental revisado; no se les inventa un destino para cumplir un formulario de transporte.
- La exportación conserva orden y nombres de las 44 columnas, tipos de fechas/números, referencias alfanuméricas y total de cuatro componentes; no multiplica filas por joins de anticipos o documentos.
- La migración preserva todos los IDs y documentos previos o registra explícitamente su correspondencia; los casos ambiguos quedan pendientes de revisión.

## 11. Reglas de negocio confirmadas por TEG

Estas definiciones proceden de la aclaración expresa de TEG y reemplazan las dudas iniciales del análisis:

- **PR = Propio**: servicio propio de TEG.
- **PA = Particular / tercero**: servicio de otra empresa.
- **PESO = toneladas**: 18 representa 18 toneladas.
- **DIG**: indicador de digitación/control; OK indica correctamente digitado/revisado.
- **RNDC**: información/resultado asociado al proceso RNDC.
- **VERIFICACION**: campo de verificación/control del proceso.

### Aplicación al diseño

`servicios.service_type` admite exclusivamente `PROPIO` o `TERCERO`, mediante enum o CHECK en la base y validación del servidor. La exportación traduce PROPIO → PR y TERCERO → PA. No confundir esta clasificación con `tipo_prestacion` (transporte, acompañamiento, turno, mensualidad, etc.) ni con el código `remesas.tipo_operacion` del RNDC. No asignar PROPIO por defecto a históricos sin evidencia; permitir clasificación pendiente durante migración/borrador y exigirla para aprobar el servicio.

Para TERCERO se propone una FK a la empresa responsable, validada por el administrativo. PR/PA identifica quién presta el servicio, no quién es el cliente: un servicio propio también puede prestarse a un cliente externo. La clasificación no determina por sí sola si corresponde emisión RNDC propia, documento externo o no aplicación; el tratamiento documental se revisa por separado.

La interfaz y el Excel usan toneladas. Propuesta de almacenamiento: `peso_toneladas numeric(12,3)` como valor canónico del servicio y `peso_kg` derivado multiplicando por 1000 cuando se requiera, sin dos entradas editables independientes. Así, 18 t = 18000 kg y 0.5 t = 500 kg. Los `remesas.peso_kg` existentes conservan su unidad; no multiplicarlos de nuevo durante migración. El documento emitido mantiene el peso validado como snapshot.

Los reportes de peso suman servicios de transporte distintos con peso confirmado. Una segunda escolta, otra orden o un join con documentos no debe sumar nuevamente la misma carga. Servicios sin transporte no reciben peso cero inventado para completar el indicador.

Para DIG se propone un control estructurado de revisión, con estados pendientes/observado/revisado; solo revisado exporta OK. Ese catálogo es una propuesta técnica, no una ampliación de las reglas confirmadas. VERIFICACION se conserva separada del control de digitación, con resultado, responsable, fecha y observación. Ninguno se marca automáticamente OK por guardar o emitir un documento.

El seguimiento RNDC conserva proceso, estado, documento, radicado y detalle de resultado. La columna RNDC será una presentación de ese seguimiento; su formato exacto y la prioridad entre varios procesos todavía deben acordarse. No interpretar la definición general como una instrucción de copiar un único radicado.

### Verificaciones adicionales para implementación

- Guardar/exportar PROPIO como PR y TERCERO como PA; rechazar códigos diferentes en un servicio aprobado.
- Convertir 18 t a 18000 kg y 0.5 t a 500 kg; exportar nuevamente 18 y 0.5 toneladas.
- Migrar remesas con 18000 kg sin convertirlas a 18000000 kg.
- Dos escoltas sobre un servicio de 18 t mantienen un total movilizado de 18 t.
- Guardar un borrador no activa DIG = OK ni completa VERIFICACION.

## 12. Definiciones de negocio todavía necesarias

Precisar MTO, LEG No, significado del flete comercial frente al pago al transportador, criterio para documentos externos y representación de múltiples anticipos en una fila. Para RNDC y VERIFICACION su finalidad ya está confirmada; resta detallar formato de salida, resultados permitidos y criterios de cierre. DIG, PR/PA y la unidad de PESO ya no son significados pendientes.
