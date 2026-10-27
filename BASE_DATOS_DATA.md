# Base espacial preparada desde data

## Ejecución local del visor

Ejecutar `shiny::runApp()` desde la raíz. La fuente predeterminada es `local`;
no requiere Supabase, RDS ni ejecutar el preprocesador Python. El cargador
`R/local_data.R` lee directamente los seis Shapefiles y adapta los campos.
Ámbito y distritos faltantes se muestran como no disponibles. Se pueden aportar
como `data/ambito.shp` (campo `NOM_AI`) y `data/distritos.shp` (campo `NOMBDIST`).
Los parámetros se vinculan solo por coincidencia exacta de descripción
normalizada; las demás subzonas conservan su descripción con prefijo `LOCAL:`.
Las métricas y escrituras remotas permanecen desactivadas en modo local.
Para volver a Supabase, configurar `PDU_DATA_SOURCE=supabase` en `.Renviron`
y las credenciales correspondientes.


Ejecutar desde la raíz del proyecto:

```powershell
python scripts/preparar_base_data.py
```

Dependencias Python: geopandas, pyogrio, shapely y pandas.

El proceso valida archivos auxiliares y CRS, repara geometrías, transforma a
EPSG:4326 y verifica integridad SQLite y conteos. Genera en `data/base_preparada/`:

- `pdu_fuentes.gpkg`: base espacial local GeoPackage con seis capas, conservando
  nombres y tipos de atributos originales.
- `inventario.json`: conteos, campos, geometrías reparadas y huellas SHA-256.
- `cargar_fuentes_postgis.sql`: carga transaccional al esquema privado
  `pdu_fuentes`, con índices GiST y RLS. Conserva atributos como texto para evitar
  conversiones con pérdida; las geometrías son PostGIS EPSG:4326.

El SQL reemplaza únicamente las seis tablas homónimas en `pdu_fuentes` cuando
se ejecuta de nuevo. No modifica las tablas de `public` usadas por Shiny.
Para cargarlo con una conexión PostgreSQL configurada mediante variables PG*:

```powershell
psql -v ON_ERROR_STOP=1 -f data/base_preparada/cargar_fuentes_postgis.sql
```

No se ejecutó la carga remota: no hay credenciales SUPABASE_* configuradas en
el entorno de esta sesión ni archivo `.Renviron` en la raíz.

## Estado del visor

`app.R` exige ocho capas normalizadas en `public` y una matriz de parámetros.
Los archivos actuales aportan seis capas con 5.344 registros:

| Capa | Registros |
|---|---:|
| zonificacion | 3664 |
| vias | 1673 |
| alta_tension | 3 |
| alta_tension_buffer | 2 |
| ferrocarril | 1 |
| ferrocarril_buffer | 1 |

Faltan los límites oficiales de ámbito y distritos. No se deben deducir de la
zonificación ni de los nombres de distritos. El preprocesador R anterior busca
otra carpeta (`shp_pdu_anta`) y otro esquema de atributos. Por ejemplo, las
fuentes tienen `SIMB_ZONI` y `SCLAS_ZONI`, mientras el visor requiere `COD_ZONA`
y `COD_S_ZONA`; las vías no tienen `SIS_VIAL`. Se necesita conciliar estos campos
con criterios municipales antes de poblar las tablas públicas. Hay al menos un
registro cuyo símbolo es ZRE y descripción es ZONA DE OTROS USOS; no se corrigió
automáticamente. Los polígonos de servidumbre y ferrocarril suministrados se
conservan sin recalcular buffers.

Para terminar la integración, configurar localmente `.Renviron` siguiendo
`.env.example`, aportar las dos capas oficiales faltantes y confirmar la
correspondencia normativa. No enviar contraseñas por el chat ni guardarlas en
archivos versionados. Los resultados de `data/` están excluidos por `.gitignore`.
