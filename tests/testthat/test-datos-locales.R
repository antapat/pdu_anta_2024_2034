source(testthat::test_path("..", "..", "R", "estilos_territoriales.R"), local = TRUE)
source(testthat::test_path("..", "..", "R", "local_data.R"), local = TRUE)

test_that("la fuente local carga datos y paletas correctamente", {
  Sys.setenv(PDU_DATA_SOURCE = "local")
  
  paleta_zonas <- pdu_colores_zonas()
  expect_true(is.character(paleta_zonas))
  expect_true("ZDA" %in% names(paleta_zonas))
  expect_true(all(grepl("^#[0-9A-F]{6}$", unname(paleta_zonas))))
  
  paleta_vias <- pdu_colores_vias()
  expect_true("SISTEMA VIAL PRIMARIO" %in% names(paleta_vias))
  
  paleta_categ <- pdu_colores_categ_vias()
  expect_true(all(c("RED VIAL NACIONAL", "RED VIAL DEPARTAMENTAL", "RED VIAL VECINAL", "LOCAL") %in% names(paleta_categ)))
  
  datos <- pdu_cargar_datos()
  expect_identical(datos$origen, "Archivos locales (data)")
  expect_true(inherits(datos$capas$zonificacion, "sf"))
  expect_true(nrow(datos$capas$zonificacion) > 0)
  expect_true(nrow(datos$parametros) > 0)
  expect_true("POPUP_MAPA" %in% names(datos$capas$zonificacion))
  expect_equal(length(datos$capas$zonificacion$POPUP_MAPA), nrow(datos$capas$zonificacion))
  # Los popups no deben contener citas crudas de páginas ni referencias internas de tablas XML
  popups_sample <- head(datos$capas$zonificacion$POPUP_MAPA, 50)
  expect_false(any(grepl("P58[1-4]|P63[4-9]|P640", popups_sample)))
  expect_false(any(grepl("tabla XML", popups_sample, ignore.case = TRUE)))
  
  # Validación de capa de ámbito de intervención
  expect_true(inherits(datos$capas$ambito, "sf"))
  expect_gt(nrow(datos$capas$ambito), 0)
  expect_true("NOM_AI" %in% names(datos$capas$ambito))
  
  # Validación de capas de vías y CATEG_VIA
  expect_true("CATEG_VIA" %in% names(datos$capas$vias))
  expect_true(all(unique(datos$capas$vias$CATEG_VIA) %in% c("RED VIAL NACIONAL", "RED VIAL DEPARTAMENTAL", "RED VIAL VECINAL", "LOCAL")))
  expect_true("colores_categ_vias" %in% names(datos$capas))
  
  # Validación de generar_mapa_certificado para reportes
  source(testthat::test_path("..", "..", "R", "reporte_cartografico_utils.R"), local = TRUE)
  pt_test <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(-72.148, -13.462)), crs = 4326))
  mapa_uri <- generar_mapa_certificado(pt_test, es_poligono = FALSE, capas_pdu = datos$capas, pal_subzonas = datos$capas$colores_subzonas)
  expect_true(is.character(mapa_uri))
  expect_gt(nchar(mapa_uri), 1000)
})

test_that("el emulador de métricas local opera en outputs/", {
  source(testthat::test_path("..", "..", "R", "supabase_utils.R"), local = TRUE)
  Sys.setenv(PDU_DATA_SOURCE = "local")
  
  m0 <- supabase_obtener_metricas()
  expect_true(is.numeric(m0$visitas_total))
  expect_true(is.numeric(m0$constancias_total))
  
  m1 <- supabase_registrar_visita("test_local_browser")
  expect_true(m1$visitas_total >= m0$visitas_total)
  
  rep <- supabase_enviar_reporte_ciudadano(
    nombre_ciudadano = "Test Usuario",
    contacto = "test@anta.gob.pe",
    tipo = "OBSERVACION",
    ubicacion = "Plaza de Armas",
    mensaje = "Mensaje de prueba en entorno local"
  )
  expect_true(isTRUE(rep$ok))
  expect_identical(rep$origen, "local")
})
