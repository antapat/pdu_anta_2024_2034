raiz_reglamento <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
source(file.path(raiz_reglamento, "R/reglamento_utils.R"), local = TRUE)

test_that("la consulta conserva todas las subzonas y exige una equivalencia exacta", {
  m <- pdu_leer_reglamento(file.path(raiz_reglamento, "normativa"))$parametros
  encontrados <- pdu_buscar_parametros(m, c("ZDA-C", "ZDM-CR-I", "ZDA-C"))
  expect_length(encontrados, 2)
  expect_equal(encontrados[[2]]$COD_S_ZONA, "ZDM-CR-I")
  expect_error(pdu_buscar_parametros(m, "ZDA"), "sin")
  expect_length(pdu_buscar_parametros(m, character()), 0)
  expect_equal(nrow(pdu_filtrar_catalogo(m, "(")), 40)
  expect_gt(nrow(pdu_filtrar_catalogo(m, "sotanos")), 0)
  expect_equal(pdu_filtrar_catalogo(m, ""), m)
})

test_that("la matriz final conserva valores y categorías de la fuente", {
  r <- pdu_leer_reglamento(file.path(raiz_reglamento, "normativa"))
  m <- r$parametros
  expect_equal(nrow(m), 40L)
  expect_false(anyDuplicated(m$COD_S_ZONA) > 0)
  expect_equal(m$COEFICIENTE_EDIF[m$COD_S_ZONA == "ZDA-C"], "3.5")
  expect_match(m$LOTE_MINIMO[m$COD_S_ZONA == "H3"], "10,000.00")
  expect_match(m$RETIRO_FRONTAL[m$COD_S_ZONA == "H3"], "5.00")
  expect_match(m$RESTRICCIONES[m$COD_S_ZONA == "ZRE-PMA-S"], "niveles adicionales")
  expect_match(m$ALTURA_MAXIMA[m$COD_S_ZONA == "ZRE-PA-C"], "No establecido")
  expect_true(all(nzchar(m$REFERENCIA_DOCUMENTAL)))
  expect_equal(sum(as.integer(r$vinculo$POLIGONOS)), 3664L)
  expect_setequal(r$vinculo$COD_S_ZONA, m$COD_S_ZONA)
})

test_that("el vínculo no confunde símbolos de riesgo ni silencia la inconsistencia ZOU", {
  r <- pdu_leer_reglamento(file.path(raiz_reglamento, "normativa"))
  original <- r$vinculo[c("SIMB_ZONI", "SCLAS_ZONI", "NOM_ZONI")]
  z <- pdu_vincular_reglamento(original, r)
  expect_equal(z$COD_S_ZONA, r$vinculo$COD_S_ZONA)
  idx <- which(z$SIMB_ZONI == "ZRE" & z$SCLAS_ZONI == "ZONA DE OTROS USOS")
  expect_length(idx, 1L)
  expect_equal(z$COD_S_ZONA[idx], "ZOU")
  expect_true(nzchar(z$OBSERVACION_VINCULO[idx]))
  expect_equal(z$SIMB_ZONI, original$SIMB_ZONI)
  original$SCLAS_ZONI[1] <- "CATEGORIA NUEVA NO CONCILIADA"
  expect_error(pdu_vincular_reglamento(original, r), "CATEGORIA NUEVA NO CONCILIADA")
  r$vinculo <- rbind(r$vinculo, r$vinculo[1, ])
  expect_error(pdu_vincular_reglamento(z, r), "duplicadas")
})

test_that("el reporte contiene los campos adicionales y la trazabilidad", {
  r <- pdu_leer_reglamento(file.path(raiz_reglamento, "normativa"))
  h3 <- r$parametros[r$parametros$COD_S_ZONA == "H3", ]
  campos <- pdu_campos_adicionales_reglamento(h3)
  expect_true(all(c("ESTACIONAMIENTOS", "VOLADIZOS", "RESTRICCIONES",
                    "FUENTE_NORMATIVA", "OBSERVACIONES_FUENTE") %in% names(campos)))
  expect_false("REFERENCIA_DOCUMENTAL" %in% names(campos))
  html <- as.character(htmltools::tagList(pdu_filas_reglamento(h3)))
  expect_match(html, "Ordenanza Municipal Nº 04-2025-A-MPA/C", fixed = TRUE)
  expect_false(grepl("Ubicación en el reglamento", html, fixed = TRUE))
  expect_false(grepl("\\[P[0-9]+\\]", html))
})

test_that("la ficha de Educacion Tecnico Productivo (E1') se filtra y resuelve correctamente", {
  r <- pdu_leer_reglamento(file.path(raiz_reglamento, "normativa"))
  filtro <- pdu_filtrar_catalogo(r$parametros, "educacion tecnica productiva")
  expect_true("E1'" %in% filtro$COD_S_ZONA)
  e1_p <- pdu_buscar_parametros(r$parametros, "E1'")
  expect_equal(length(e1_p), 1)
  expect_equal(e1_p[[1]]$NOMBRE_COMPLETO, "Educación Técnico Productivo")
})

