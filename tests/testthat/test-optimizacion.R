source(testthat::test_path("..", "..", "R", "optimizacion.R"), local = TRUE)

test_that("la cache rechaza cambios y archivos nuevos", {
  firma <- c(a = "abc", b = "def")
  cache <- list(version = 1L, firma = firma, datos = list(capas = list()))
  expect_true(pdu_cache_vigente(cache, firma))
  expect_false(pdu_cache_vigente(cache, firma[1])) # no omitir normativa ni codigo
  expect_false(pdu_cache_vigente(cache, c(a = "otro", b = "def")))
  expect_false(pdu_cache_vigente(cache, c(firma, nuevo = "xyz")))
  expect_false(pdu_cache_vigente(NULL, firma))
})

test_that("el dibujo conserva entidades, atributos requeridos y originales intactos", {
  raiz <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  original <- readRDS(file.path(raiz, "data_pdu/pdu_preparado.rds"))$datos$capas
  antes <- serialize(original, NULL)
  ligero <- pdu_capas_visualizacion(original)
  expect_identical(serialize(original, NULL), antes)
  for (nombre in names(ligero)) {
    expect_equal(nrow(ligero[[nombre]]), nrow(original[[nombre]]))
    expect_true(all(sf::st_is_valid(ligero[[nombre]])))
    expect_false(any(sf::st_is_empty(ligero[[nombre]])))
    expect_equal(sf::st_crs(ligero[[nombre]])$epsg, 4326)
  }
  expect_identical(ligero$zonificacion$POPUP_MAPA, original$zonificacion$POPUP_MAPA)
  a <- sf::st_transform(sf::st_geometry(original$zonificacion), 32718)
  b <- sf::st_transform(sf::st_geometry(ligero$zonificacion), 32718)
  error <- sf::st_distance(a, b, by_element = TRUE, which = "Hausdorff", par = 0.25)
  expect_lt(max(as.numeric(error)), 0.51)
  expect_lt(nrow(sf::st_coordinates(b)), nrow(sf::st_coordinates(a)))
})
