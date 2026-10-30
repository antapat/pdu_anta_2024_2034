source(testthat::test_path("..", "..", "R", "mod_acceso_dni.R"), local = TRUE)

test_that("generador de captcha produce codigos de 5 caracteres", {
  c1 <- pdu_acceso_generar_captcha()
  expect_equal(nchar(c1), 5)
  expect_true(grepl("^[A-Z0-9]{5}$", c1))
})

test_that("el control de cuotas limita a exactamente 2 periodos por dia por DNI", {
  dni_prueba <- "99887766"
  tmp_db <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp_db), add = TRUE)
  
  # Estado inicial: 0 sesiones hoy
  c0 <- pdu_acceso_consultar_cuota(dni_prueba, ruta_db = tmp_db)
  expect_true(c0$permitido)
  expect_equal(c0$total_hoy, 0)
  expect_equal(c0$restantes, 2)
  
  # Registro de 1ra sesión
  id1 <- pdu_acceso_registrar_sesion(dni_prueba, "15/05/2021", duracion_min = 10, ruta_db = tmp_db)
  expect_true(nzchar(id1))
  
  c1 <- pdu_acceso_consultar_cuota(dni_prueba, ruta_db = tmp_db)
  expect_true(c1$permitido)
  expect_equal(c1$total_hoy, 1)
  expect_equal(c1$restantes, 1)
  
  # Registro de 2da sesión
  id2 <- pdu_acceso_registrar_sesion(dni_prueba, "15/05/2021", duracion_min = 10, ruta_db = tmp_db)
  expect_true(nzchar(id2))
  
  c2 <- pdu_acceso_consultar_cuota(dni_prueba, ruta_db = tmp_db)
  expect_false(c2$permitido)
  expect_equal(c2$total_hoy, 2)
  expect_equal(c2$restantes, 0)
  expect_true(grepl("límite diario permitido", c2$mensaje, ignore.case = TRUE))
  
  # Rechaza DNIs con formato incorrecto (menos de 8 dígitos o caracteres)
  expect_false(pdu_acceso_consultar_cuota("123", ruta_db = tmp_db)$permitido)
  expect_false(pdu_acceso_consultar_cuota("1234567A", ruta_db = tmp_db)$permitido)
})
