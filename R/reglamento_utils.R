# Matriz del TOMO III final y vínculo explícito por atributos originales.
pdu_leer_reglamento <- function(directorio = "normativa") {
  leer <- function(nombre) {
    datos <- utils::read.csv(
    file.path(directorio, nombre), encoding = "UTF-8",
    stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character",
    na.strings = character()
    )
    names(datos) <- sub("^\ufeff", "", names(datos))
    datos
  }
  matriz <- leer("matriz_reglamento_final.csv")
  vinculo <- leer("vinculo_zonificacion_reglamento.csv")
  requeridas <- c("COD_S_ZONA", "COD_ZONA", "NOMBRE_COMPLETO", "DENSIDAD_NETA_MAX",
    "LOTE_MINIMO", "FRENTE_MINIMO", "ALTURA_MAXIMA", "COEFICIENTE_EDIF", "AREA_LIBRE_MIN",
    "RETIRO_FRONTAL", "USOS_PERMITIDOS", "ESTACIONAMIENTOS", "VOLADIZOS", "RESTRICCIONES",
    "NOTAS_APLICACION", "REFERENCIA_DOCUMENTAL", "FUENTE_NORMATIVA", "ESTADO_VALIDACION")
  if (!all(requeridas %in% names(matriz))) stop("La matriz del reglamento está incompleta.")
  if (anyDuplicated(matriz$COD_S_ZONA)) stop("Códigos duplicados en la matriz del reglamento.")
  if (!all(vinculo$COD_S_ZONA %in% matriz$COD_S_ZONA)) stop("Vínculos sin categoría reglamentaria.")

  # Limpieza de citas y referencias de páginas [P###] para presentación técnica limpia
  limpiar_paginas <- function(x) {
    if (!is.character(x)) return(x)
    x <- gsub("\\[P[0-9]+\\]\\s*", "", x)
    x <- gsub("\\(P[0-9]+[–-][0-9]+;\\s*", "(", x)
    x <- gsub("disposiciones\\s+P[0-9]+[–-][0-9]+\\s+", "disposiciones del reglamento ", x)
    x <- gsub("remisión\\s+de\\s+P[0-9]+\\s+al", "remisión al", x)
    x <- gsub("P[0-9]+[–-][0-9]+;\\s*planes\\s*P[0-9]+[–-][0-9]+", "Reglamento PDU", x)
    x <- gsub("P[0-9]+[–-][0-9]+\\s+y\\s+planes\\s+P[0-9]+[–-][0-9]+", "Reglamento PDU", x)
    x <- gsub("P[0-9]+[–-][0-9]+", "", x)
    x
  }
  for (col in intersect(c("NOTAS_APLICACION", "CONDICIONES_GENERALES", "USOS_PERMITIDOS", "RESTRICCIONES", "OBSERVACIONES_FUENTE"), names(matriz))) {
    matriz[[col]] <- limpiar_paginas(matriz[[col]])
  }
  matriz$FUENTE_NORMATIVA <- "Plan de Desarrollo Urbano de Anta (2024 - 2034) — Ordenanza Municipal Nº 04-2025-A-MPA/C"

  list(parametros = matriz, vinculo = vinculo)
}

pdu_buscar_parametros <- function(matriz, codigos) {
  codigos <- unique(trimws(as.character(codigos)))
  codigos <- codigos[!is.na(codigos) & nzchar(codigos)]
  if (anyDuplicated(matriz$COD_S_ZONA)) stop("La matriz contiene subzonas duplicadas.")
  idx <- match(codigos, matriz$COD_S_ZONA)
  if (anyNA(idx)) stop("Subzona sin parámetros en el reglamento: ", paste(codigos[is.na(idx)], collapse = ", "))
  lapply(idx, function(i) matriz[i, , drop = FALSE])
}

pdu_filtrar_catalogo <- function(matriz, busqueda = "") {
  normalizar <- function(x) tolower(iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT"))
  busqueda <- trimws(normalizar(busqueda))
  if (!nzchar(busqueda)) return(matriz)
  
  campos <- names(matriz)[vapply(matriz, is.character, logical(1))]
  texto_filas <- apply(matriz[, campos, drop = FALSE], 1, function(col) paste(normalizar(col), collapse = " "))
  
  palabras <- unlist(strsplit(busqueda, "\\s+"))
  palabras <- palabras[nzchar(palabras)]
  if (length(palabras) == 0) return(matriz)
  
  coincide_por_palabra <- lapply(palabras, function(pal) {
    raiz <- sub("[ao]$", "", pal)
    if (nchar(raiz) >= 4) {
      grepl(raiz, texto_filas, fixed = TRUE)
    } else {
      grepl(pal, texto_filas, fixed = TRUE)
    }
  })
  
  encontrado <- Reduce(`&`, coincide_por_palabra)
  matriz[encontrado & !is.na(encontrado), , drop = FALSE]
}

pdu_tabla_parametros <- function(parametro) {
  basicos <- c(DENSIDAD_NETA_MAX = "Densidad neta máxima", LOTE_MINIMO = "Lote mínimo",
    FRENTE_MINIMO = "Frente mínimo", ALTURA_MAXIMA = "Altura máxima", AREA_LIBRE_MIN = "Área libre",
    COEFICIENTE_EDIF = "Coeficiente de edificabilidad", RETIRO_FRONTAL = "Retiros",
    USOS_PERMITIDOS = "Usos permitidos")
  htmltools::tagList(
    htmltools::tags$h5(paste(parametro$COD_S_ZONA, parametro$NOMBRE_COMPLETO)),
    htmltools::tags$table(class = "table table-bordered table-cert",
      htmltools::tags$tbody(lapply(names(basicos), function(campo) htmltools::tags$tr(
        htmltools::tags$th(basicos[[campo]]), htmltools::tags$td(style = "white-space: pre-line;", parametro[[campo]])
      )), pdu_filas_reglamento(parametro)))
  )
}

pdu_vincular_reglamento <- function(zonificacion, reglamento) {
  campos <- c("SIMB_ZONI", "SCLAS_ZONI", "NOM_ZONI")
  if (!all(campos %in% names(zonificacion))) stop("Faltan atributos originales de zonificación.")
  clave <- function(x) do.call(paste, c(lapply(campos, function(campo) trimws(x[[campo]])), sep = "\x1f"))
  claves <- clave(reglamento$vinculo)
  if (anyDuplicated(claves)) stop("Equivalencias cartográficas duplicadas.")
  idx <- match(clave(zonificacion), claves)
  if (anyNA(idx)) stop("Hay categorías cartográficas sin vínculo explícito con el reglamento: ",
                       paste(unique(zonificacion$SCLAS_ZONI[is.na(idx)]), collapse = "; "))
  for (campo in c("COD_S_ZONA", "COD_ZONA", "METODO_VINCULO", "OBSERVACION_VINCULO")) {
    zonificacion[[campo]] <- reglamento$vinculo[[campo]][idx]
  }
  zonificacion$REFERENCIA_REGLAMENTO <- reglamento$parametros$REFERENCIA_DOCUMENTAL[
    match(zonificacion$COD_S_ZONA, reglamento$parametros$COD_S_ZONA)]
  zonificacion
}

pdu_campos_adicionales_reglamento <- function(parametro) {
  campos <- c(
    ESTACIONAMIENTOS = "Estacionamientos mínimos", VOLADIZOS = "Voladizos sobre retiro",
    RESTRICCIONES = "Restricciones", NOTAS_APLICACION = "Notas de aplicación",
    CONDICIONES_GENERALES = "Condiciones complementarias de aplicación",
    FUENTE_NORMATIVA = "Fuente normativa",
    OBSERVACIONES_FUENTE = "Observaciones del documento",
    OBSERVACIONES_CARTOGRAFIA = "Observaciones cartográficas"
  )
  campos <- campos[names(campos) %in% names(parametro)]
  campos[vapply(names(campos), function(campo) {
    valor <- parametro[[campo]]
    length(valor) > 0 && !is.na(valor[[1]]) && nzchar(valor[[1]])
  }, logical(1))]
}

pdu_filas_reglamento <- function(parametro) {
  campos <- pdu_campos_adicionales_reglamento(parametro)
  lapply(names(campos), function(campo) htmltools::tags$tr(
    htmltools::tags$th(campos[[campo]]),
    htmltools::tags$td(style = "white-space: pre-line;", parametro[[campo]])
  ))
}
