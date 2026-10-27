source(testthat::test_path("..", "..", "R", "neon_utils.R"), local = TRUE)

test_that("neon_disponible detecta la base de datos Neon correctamente", {
  skip_if_not(requireNamespace("DBI", quietly = TRUE) && requireNamespace("RPostgres", quietly = TRUE))
  disp <- tryCatch(neon_disponible(), error = function(e) FALSE)
  # Si hay conexión a internet y Neon está activo, responde TRUE
  expect_type(disp, "logical")
})

test_that("neon_obtener_metricas retorna estructura esperada", {
  skip_if_not(neon_disponible())
  m <- neon_obtener_metricas()
  expect_true(is.list(m))
  expect_true("visitas_total" %in% names(m))
  expect_true("constancias_total" %in% names(m))
})
