"# pdu_anta_2024_2034" 


## Optimizacion del visor

El mapa Leaflet se prepara una vez por proceso y usa Canvas. Sus capas son copias
de visualizacion simplificadas a 0,5 m en UTM 18S, con los atributos necesarios para
estilos, etiquetas y ventanas. No usar esas copias para mediciones: las consultas,
intersecciones y reportes siguen usando las geometrías originales. Las vias UTM y
el encuadre se calculan una sola vez y se comparten entre sesiones.

`Rscript scripts/preparar_cache_pdu.R` crea `data_pdu/pdu_preparado.rds` con las
geometrias originales, la normativa vinculada y firmas MD5. El cargador comprueba
las fuentes presentes y descarta una cache desactualizada. No se escribe cache al
iniciar la aplicacion. Los shapefiles se mantienen locales; el despliegue puede
usar la cache sin incluirlos. `scripts/generate_manifest.R` regenera la cache antes
del manifiesto e incluye normativa y documentos de aprobacion.

Despues de cambiar fuentes o cargadores, ejecutar desde la raiz:

```r
source("scripts/preparar_cache_pdu.R")
testthat::test_file("tests/testthat/test-optimizacion.R")
source("scripts/generate_manifest.R")
```

La construccion compartida evita repetir procesamiento por visitante; cada visita
todavia recibe el mapa. La reduccion del widget no representa una medicion de
transferencia HTTP: comprobar esta ultima en el navegador y las metricas de Posit.
