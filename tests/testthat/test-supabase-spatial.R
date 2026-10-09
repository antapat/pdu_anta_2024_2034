source(testthat::test_path("..", "..", "R", "supabase_utils.R"), local = TRUE)

test_that("se exige la fuente espacial PostgreSQL", {
  vars <- c("SUPABASE_HOST", "SUPABASE_PASSWORD", "SUPABASE_USER")
  anteriores <- Sys.getenv(vars, unset = NA_character_)
  on.exit({
    for (i in seq_along(vars)) {
      if (is.na(anteriores[[i]])) {
        Sys.unsetenv(vars[[i]])
      } else {
        do.call(Sys.setenv, stats::setNames(list(anteriores[[i]]), vars[[i]]))
      }
    }
  }, add = TRUE)
  Sys.unsetenv(vars)

  expect_error(
    supabase_cargar_datos_espaciales(),
    "PostgreSQL directa"
  )
})

test_that("el catálogo espacial contiene todas las tablas oficiales", {
  expect_setequal(
    supabase_tablas_espaciales(),
    c(
      "ambito", "distritos", "zonificacion", "vias", "alta_tension",
      "alta_tension_buffer", "ferrocarril", "ferrocarril_buffer"
    )
  )
})

test_that("la paleta de macrozonas conserva códigos oficiales", {
  paleta <- supabase_colores_zonas()
  expect_true(all(c("ZDA", "ZDM", "ZDB", "ZRE") %in% names(paleta)))
  expect_true(all(grepl("^#[0-9A-F]{6}$", unname(paleta))))
})
