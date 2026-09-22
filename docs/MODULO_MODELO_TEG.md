# Módulo Modelo de datos TEG

Implementación local del 21/09/2026. Acceso desde Inicio → Modelo de datos TEG (`/modelo-teg`). Disponible para administración y auditoría; los escoltas conservan acceso solo a órdenes. El backend verifica sesión y rol activo; no se confía en el menú para proteger la exportación.

## Uso

1. Abrir el módulo para consultar servicios, incluidos borradores.
2. Elegir Todos o introducir Desde/Hasta en formato AAAA-MM-DD.
3. Generar Excel. Se exportan todas las páginas del filtro, no solo las visibles.
4. En iPhone/Android, guardar o compartir el XLSX mediante el selector del sistema. En web se usa la implementación web de share_plus y su descarga de respaldo cuando no hay Web Share.

El filtro usa **created_at del servicio en hora de Colombia**, con ambos días incluidos. No es fecha efectiva de transporte ni fecha de orden. La consulta fija un corte de altas y pagina por ID para no repetir registros; no es una instantánea transaccional de modificaciones concurrentes. Actualizar comienza una consulta nueva.

## Archivo

- Hoja1 mantiene exactamente A:AR del modelo original, con encabezado fijo y autofiltro.
- Una fila por servicio; un servicio sin orden vinculada también aparece.
- Exporta PR/PA, escolta/placa, placa camabaja, cliente, peso en toneladas, origen, destino y observación general cuando existen.
- Conserva las demás columnas vacías si no hay una fuente comprobada. No relaciona remesas/manifiestos por coincidencias de cliente o placa ni inventa valores económicos. No sustituye fecha transporte por fecha registro.
- Máquina, folio, identificador y código de orden aparecen en Trazabilidad: no se fuerza su equivalencia con TIPO DE CARGA (ESCOLTA), COD INT o REMISION ESC 1.
- Los campos de texto se escriben como texto, incluso si comienzan por =. Los pesos se escriben como números. Los importes pendientes no se convierten en cero.
- Un vínculo ambiguo de varias órdenes al mismo servicio detiene la exportación con explicación en lugar de duplicar filas.
- Límite operativo de 100.000 servicios por archivo. Al superarlo se solicita reducir el rango; nunca se entrega una exportación parcial. Tampoco se recortan silenciosamente textos que excedan el máximo de Excel.

## Backend y publicación

Endpoints GET `/api/modelo-teg` y `/api/modelo-teg/excel`. Consulta tablas existentes mediante PostgREST y relaciones FK. No necesita una migración SQL nueva. Requiere el esquema del incremento de servicios y la columna codigo_orden ya utilizados en la app.

Archivos backend: `Controllers/ModeloTegController.cs`, `Services/ModeloTegWorkbook.cs`. Construcción XLSX con ZIP/XML nativos de .NET, sin nuevas dependencias ni datos históricos embebidos. Exportar no escribe en Supabase, no envía correos y no contacta RNDC.

Para que aparezca en la app instalada deben publicarse el backend y una nueva compilación Flutter. Implementado y probado localmente no equivale a desplegado ni a verificado contra Supabase real.

## Validación

Contratos: rol activo, rango inclusivo Colombia, ausencia de filtro, varias páginas aunque Supabase entregue lotes cortos, 44 columnas, datos pendientes vacíos y texto que no ejecuta fórmulas. XLSX sintético abierto con openpyxl y encabezados comparados contra el Excel original A1:AR1.

Flutter: exportar Todos, bloqueo durante generación, error/vacío/reintento, filtro aplicado también al Excel, restablecer Todos y pantalla compacta con texto ampliado. Los servicios externos están simulados. Falta prueba en dispositivos físicos y servidor desplegado.
