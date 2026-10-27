# Matriz del reglamento final del PDU Anta

La fuente de parámetros para el visor local es **TOMO III_REGLAMENTO_2024-2034.docx**.
La matriz anterior de `R/parametros_locales.R` ya no se utiliza en esta carga.

- `matriz_reglamento_final.csv`: 40 categorías con parámetros textuales,
  estacionamientos, voladizos, usos, restricciones, notas, referencias y huella
  SHA-256 del documento.
- `vinculo_zonificacion_reglamento.csv`: 41 combinaciones de los atributos
  originales `SIMB_ZONI`, `SCLAS_ZONI` y `NOM_ZONI`, vinculadas a una categoría
  reglamentaria. Abarcan los 3.664 polígonos del Shapefile entregado.

El visor consulta estas dos tablas al iniciar. Conserva los atributos originales
y agrega `COD_S_ZONA`, `COD_ZONA`, `METODO_VINCULO`, `OBSERVACION_VINCULO` y
`REFERENCIA_REGLAMENTO`. Una combinación nueva o duplicada detiene la carga
para evitar asignarle parámetros por una semejanza de nombres o por macrozona.

Los reportes HTML y la plantilla Quarto incluyen los parámetros y condiciones
de cada subzona consultada, junto con su referencia documental. Las condiciones
de unifamiliar y multifamiliar se conservan dentro del valor textual; no se
reducen a un único máximo que oculte esa diferencia.

## Criterio de extracción y trazabilidad

Se transcriben las tablas individuales 15–32 y 34–42. E1 y E1' comparten la
Tabla 34: se conserva el contenido conjunto, sin deducir una tipología educativa
concreta para un predio. Las categorías sin tabla numérica individual usan sus
disposiciones específicas; los valores ausentes dicen **No establecido en este
apartado del reglamento**, en vez de asignar un cero o inventar un parámetro.

`Pn` significa el párrafo n del cuerpo del archivo Word, incluidos párrafos
vacíos en la numeración; no es un número de página ni de artículo. El índice de
tabla XML identifica su posición dentro del DOCX. El archivo de evidencia en
`outputs/reglamento/evidencia_parametros.csv` registra tabla, fila, etiqueta y
valor literal de cada parámetro tabulado. La revisión también conserva los
apartados de planes específicos y las remisiones al IUUAU, SLO y ferrocarril.

Esta matriz transcribe la fuente final proporcionada. El estado de transcripción
no acredita una nueva validación o aprobación administrativa, ni comprueba
actualizaciones posteriores de normas citadas o planes específicos aprobados.

## Observaciones conservadas

1. Tabla 38: la leyenda y el apartado identifican H3, pero el encabezado interno
   dice H1. Se conservan los valores de Tabla 38 y se advierte la diferencia.
2. Tabla 42: el encabezado interno dice Industria Elemental y Complementaria I2,
   mientras la leyenda identifica Industria Liviana I2.
3. ZDMB-CR: Tabla 32 incluye Taller en los usos y Tabla 33 no lo incluye. El reporte
   muestra la tabla individual junto con la discrepancia.
4. ZRE-CBIP aparece en el apartado específico y la cartografía, pero falta en
   Tabla 14. Se incorpora con su remisión al Ministerio de Cultura y al Plan
   Específico desarrollado en P634–640.
5. Un polígono tiene descripción ZONA DE OTROS USOS y símbolo ZRE. Se vincula a
   ZOU por descripción, conservando el símbolo y una observación explícita.
6. Para ZRE-VHC-CH se conserva la remisión a OM 017–2010-MPA-A/SG; el documento
   no reproduce sus parámetros y la matriz no inventa sus valores.

El IUUAU se menciona como Anexo 2, pero el cuadro de actividades no está entre las
33 tablas extraídas del documento. Los usos generales de esta matriz no
determinan por sí solos la compatibilidad de una actividad económica. La
afectación por SLO requiere su información espacial específica.

## Reconstrucción

Desde la raíz, con Python y python-docx:

```powershell
python scripts/construir_matriz_reglamento.py
```

El script verifica que cada descripción cartográfica tenga una equivalencia
exacta normalizada o un alias explícito. Genera la matriz, el vínculo y los
archivos de evidencia. No modifica el Word ni los componentes del Shapefile.
Si cambia la fuente o la cartografía, reconstruir y revisar los hallazgos antes
de reemplazar los archivos usados por el visor.
