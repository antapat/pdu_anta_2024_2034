# ==============================================================================
# ESTILOS CARTOGRÁFICOS Y PALETAS OFICIALES - GEOVISOR PDU ANTA (2024 - 2034)
# Módulo desacoplado de estilos territoriales para zonificación y sistema vial
# GDUR - Municipalidad Provincial de Anta
# ==============================================================================

#' Paleta oficial de colores para macrozonas de zonificación urbana
#' Códigos oficiales del PDU Anta 2024-2034
pdu_colores_zonas <- function() {
  c(
    ZDA     = "#C97876",  # Residencial Densidad Alta
    ZDM     = "#D99384",  # Residencial Densidad Media
    ZDB     = "#D8A36C",  # Residencial Densidad Baja
    ZDMB    = "#D5C66F",  # Residencial Densidad Muy Baja
    ZI      = "#8D94AD",  # Zona Industrial
    `ZSPC-E` = "#8FB5CA", # Servicios Públicos Complementarios - Educación
    `ZSPC-S` = "#7FB7AE", # Servicios Públicos Complementarios - Salud
    ZRP     = "#A8C486",  # Recreación Pública
    ZOU     = "#A6AEB0",  # Otros Usos
    ZA      = "#DDE7C3",  # Zona Agrícola
    ZPA     = "#6FA27A",  # Protección Ambiental
    ZRE     = "#B47B96",  # Reglamentación Especial
    ZM      = "#C7BBB3"   # Zona Monumental
  )
}

#' Paleta oficial de colores para el sistema vial propuesto
pdu_colores_vias <- function() {
  c(
    "SISTEMA VIAL PROVINCIAL-METROPOLITANO" = "#9A6B1F",
    "SISTEMA VIAL PRIMARIO"                 = "#A23E3A",
    "SISTEMA VIAL SECUNDARIO"               = "#2E6B57",
    "SISTEMA VIAL ESPECIAL"                 = "#6B5A88"
  )
}

#' Paleta oficial para la variable CATEG_VIA (Clasificación de la Red Vial)
pdu_colores_categ_vias <- function() {
  c(
    "RED VIAL NACIONAL"       = "#C0392B",  # Rojo MTC / Red Nacional
    "RED VIAL DEPARTAMENTAL"  = "#D97706",  # Ámbar / Red Departamental
    "RED VIAL VECINAL"        = "#2E7D32",  # Verde vial vecinal
    "LOCAL"                   = "#5B7083"   # Azul pizarra / Red local urbana
  )
}

#' Patrones de trazo para CATEG_VIA en Leaflet
pdu_trazos_categ_vias <- function() {
  c(
    "RED VIAL NACIONAL"       = "",
    "RED VIAL DEPARTAMENTAL"  = "",
    "RED VIAL VECINAL"        = "7,5",
    "LOCAL"                   = ""
  )
}

#' Grosor de línea oficial para CATEG_VIA
pdu_pesos_categ_vias <- function() {
  c(
    "RED VIAL NACIONAL"       = 2.8,
    "RED VIAL DEPARTAMENTAL"  = 2.2,
    "RED VIAL VECINAL"        = 1.8,
    "LOCAL"                   = 1.4
  )
}

#' Patrón de trazo (stroke-dasharray) para jerarquías viales en Leaflet
pdu_trazos_vias <- function() {
  c(
    "SISTEMA VIAL PROVINCIAL-METROPOLITANO" = "12,6",
    "SISTEMA VIAL PRIMARIO"                 = "9,5",
    "SISTEMA VIAL SECUNDARIO"               = "5,5",
    "SISTEMA VIAL ESPECIAL"                 = "2,5"
  )
}

#' Grosor de línea oficial para jerarquías viales
pdu_pesos_vias <- function() {
  c(
    "SISTEMA VIAL PROVINCIAL-METROPOLITANO" = 2.2,
    "SISTEMA VIAL PRIMARIO"                 = 2.0,
    "SISTEMA VIAL SECUNDARIO"               = 1.6,
    "SISTEMA VIAL ESPECIAL"                 = 1.7
  )
}

#' Extrae paleta de colores a partir de columnas en un dataframe o capa espacial
pdu_paleta_desde_columnas <- function(datos, codigo, color) {
  if (!all(c(codigo, color) %in% names(datos))) return(character())
  pares <- unique(sf::st_drop_geometry(datos)[, c(codigo, color), drop = FALSE])
  pares <- pares[!is.na(pares[[codigo]]) & !is.na(pares[[color]]) &
                   nzchar(as.character(pares[[codigo]])) & nzchar(as.character(pares[[color]])), , drop = FALSE]
  stats::setNames(as.character(pares[[color]]), as.character(pares[[codigo]]))
}

#' Genera el contenido HTML estructurado para los popups de zonificación en el mapa
#' Evita citas documentales crudas como números de página (P###) y tablas XML internas.
#' @param z Objeto sf o data.frame con la capa de zonificación
#' @return Vector de cadenas HTML del mismo tamaño que nrow(z)
pdu_construir_popups_zonificacion <- function(z) {
  u_idx <- !duplicated(z$COD_S_ZONA)
  u_z <- sf::st_drop_geometry(z[u_idx, , drop = FALSE])
  
  generar_un_popup <- function(cs, zn, nm, alt, lt, al, dn, us) {
    if (is.na(zn) || !nzchar(trimws(zn))) zn <- "Zonificación PDU"
    if (is.na(nm) || !nzchar(trimws(nm))) nm <- cs
    
    es_especial <- grepl("^ZRE", cs) || grepl("^OU|^ZOU", cs) || 
                   grepl("^ZPA", cs) || grepl("^ZHR", cs) || 
                   is.na(alt) || grepl("No establecido", alt)
    
    h <- paste0(
      "<div style='font-family:Inter, system-ui, -apple-system, sans-serif; font-size:12px; min-width:230px; max-width:310px; color:#1C2421; line-height:1.4;'>",
      "<div style='background:#174A3A; color:#FFFFFF; padding:6px 10px; border-radius:5px 5px 0 0; margin:-1px -1px 8px -1px;'>",
        "<div style='font-size:10px; text-transform:uppercase; letter-spacing:0.5px; opacity:0.85; font-weight:600;'>Zonificación PDU Anta</div>",
        "<div style='font-size:15px; font-weight:700; margin-top:2px;'>", htmltools::htmlEscape(cs), "</div>",
      "</div>",
      "<div style='padding:0 4px;'>",
        "<div style='font-size:10.5px; font-weight:700; color:#52635B; text-transform:uppercase;'>", htmltools::htmlEscape(zn), "</div>",
        "<div style='font-size:13px; font-weight:600; color:#174A3A; margin:3px 0 8px 0;'>", htmltools::htmlEscape(nm), "</div>"
    )
    
    if (!es_especial) {
      items <- character(0)
      if (!is.na(alt) && nzchar(trimws(alt)) && !grepl("No establecido", alt)) {
        items <- c(items, paste0("<b>Altura máx.:</b> ", htmltools::htmlEscape(alt)))
      }
      if (!is.na(lt) && nzchar(trimws(lt)) && !grepl("No establecido", lt)) {
        items <- c(items, paste0("<b>Lote mín.:</b> ", htmltools::htmlEscape(lt)))
      }
      if (!is.na(al) && nzchar(trimws(al)) && !grepl("No establecido", al)) {
        items <- c(items, paste0("<b>Área libre mín.:</b> ", htmltools::htmlEscape(al)))
      }
      if (!is.na(dn) && nzchar(trimws(dn)) && !grepl("No establecido", dn)) {
        items <- c(items, paste0("<b>Densidad máx.:</b> ", htmltools::htmlEscape(dn)))
      }
      if (length(items) > 0) {
        h <- paste0(
          h,
          "<div style='background:#F4F7F5; border-radius:4px; padding:6px 8px; margin-bottom:7px; font-size:11px; line-height:1.4;'>",
          paste(items, collapse = "<br>"),
          "</div>"
        )
      }
      if (!is.na(us) && nzchar(trimws(us)) && !grepl("No establecido", us) && !grepl("---------", us)) {
        h <- paste0(
          h,
          "<div style='font-size:11px; color:#404B46; margin-bottom:6px;'><b>Usos:</b> ",
          htmltools::htmlEscape(us), "</div>"
        )
      }
    } else {
      nota <- if (grepl("^ZRE-CBIP", cs)) {
        "Sujeta a normativa de protección de bien inmueble prehispánico (Ministerio de Cultura / PDU)."
      } else if (grepl("riesgo|sismicidad|CR|peligro", cs, ignore.case = TRUE) || grepl("riesgo|peligro", nm, ignore.case = TRUE)) {
        "Zona con condicionantes de riesgo o seguridad física. Sujeta a evaluación técnica y restricciones específicas."
      } else if (grepl("^ZRE", cs)) {
        "Zona de Reglamentación Especial sujeta a instrumentos específicos de protección y desarrollo normativo."
      } else if (grepl("^OU|^ZOU", cs)) {
        "Otros Usos: Usos institucionales, comunales o especiales según proyecto sectorial específico."
      } else if (grepl("^ZPA", cs)) {
        "Zona de Protección Ambiental: Preservación ecológica y restricción de ocupación urbana."
      } else {
        "Parámetros normativos según evaluación técnica y proyecto sectorial (Reglamento PDU)."
      }
      h <- paste0(
        h,
        "<div style='background:#FBF7EB; border-left:3px solid #B68A2C; border-radius:0 4px 4px 0; padding:6px 8px; margin-bottom:6px; font-size:11px; color:#6B5218;'>",
        htmltools::htmlEscape(nota),
        "</div>"
      )
    }
    
    h <- paste0(
      h,
      "<div style='font-size:10px; color:#8C9B94; border-top:1px solid #E5EBE8; padding-top:4px; margin-top:6px;'>PDU Anta 2024–2034 — GDUR</div>",
      "</div></div>"
    )
    h
  }
  
  popups_dict <- vapply(seq_len(nrow(u_z)), function(i) {
    generar_un_popup(
      u_z$COD_S_ZONA[i], u_z$ZONA[i], u_z$NOMBRE_COMPLETO[i],
      u_z$ALTURA_MAXIMA[i], u_z$LOTE_MINIMO[i], u_z$AREA_LIBRE_MIN[i],
      u_z$DENSIDAD_NETA_MAX[i], u_z$USOS_PERMITIDOS[i]
    )
  }, character(1))
  names(popups_dict) <- u_z$COD_S_ZONA
  
  unname(popups_dict[z$COD_S_ZONA])
}

