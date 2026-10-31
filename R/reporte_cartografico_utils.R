# ==============================================================================
# GEOVISOR PDU ANTA (2024 - 2034) - UTILIDADES CARTOGRÁFICAS PARA REPORTES
# Renderizado de plano cartográfico en alta resolución con Rosa de los Vientos y Escala
# ==============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
  library(knitr)
})

#' Renderiza plano cartográfico de alta resolución sin márgenes vacíos
#' con Rosa de los Vientos y Escala Gráfica.
#'
#' @param geom_sf Objeto sf con la geometría (punto o polígono) consultada.
#' @param es_poligono Lógico indicando si geom_sf es polígono (TRUE) o punto (FALSE).
#' @param ruta_salida_png Ruta de archivo para guardar el PNG si se requiere.
#' @param capas_pdu Lista con las capas espaciales del PDU (por defecto usa capas globales).
#' @param pal_subzonas Vector con la paleta de colores por subzona (por defecto usa global).
#' @param ancho_in Ancho en pulgadas del lienzo cartográfico (por defecto 7.6 in para A4).
#' @param alto_in Alto en pulgadas del lienzo cartográfico (por defecto 8.85 in para A4 completo).
#' @return URI de imagen base64 o NULL en caso de error.
generar_mapa_certificado <- function(geom_sf, es_poligono = TRUE, ruta_salida_png = NULL,
                                     capas_pdu = NULL, pal_subzonas = NULL,
                                     ancho_in = 7.6, alto_in = 8.85) {
  tryCatch({
    if (is.null(capas_pdu)) {
      for (env in list(parent.frame(), parent.frame(2), parent.frame(3), .GlobalEnv)) {
        if (exists("capas", envir = env, inherits = FALSE)) {
          capas_pdu <- get("capas", envir = env, inherits = FALSE)
          break
        }
      }
    }
    if (is.null(pal_subzonas)) {
      for (env in list(parent.frame(), parent.frame(2), parent.frame(3), .GlobalEnv)) {
        if (exists("colores_subzonas", envir = env, inherits = FALSE)) {
          pal_subzonas <- get("colores_subzonas", envir = env, inherits = FALSE)
          break
        }
      }
    }
    if (is.null(capas_pdu) || is.null(capas_pdu$zonificacion)) {
      warning("generar_mapa_certificado: capas_pdu no proporcionado o incompleto.", call. = FALSE)
      return(NULL)
    }
    
    geom_utm <- st_transform(geom_sf, 32718)
    
    # Dimensiones efectivas del panel interior de dibujo cartográfico en ggplot
    # Descontando márgenes de títulos de ejes (izq/der ~0.90 in) y banda inferior de leyenda (~1.65 in)
    w_axes_in <- 0.90
    h_axes_and_legend_in <- 1.65
    w_panel_in <- max(ancho_in - w_axes_in, 2.5)
    h_panel_in <- max(alto_in - h_axes_and_legend_in, 2.5)
    ratio_panel_yx <- h_panel_in / w_panel_in
    
    bb_geom <- st_bbox(geom_utm)
    cx <- as.numeric((bb_geom["xmin"] + bb_geom["xmax"]) / 2)
    cy <- as.numeric((bb_geom["ymin"] + bb_geom["ymax"]) / 2)
    dx <- as.numeric(bb_geom["xmax"] - bb_geom["xmin"])
    dy <- as.numeric(bb_geom["ymax"] - bb_geom["ymin"])
    
    if (es_poligono) {
      min_span_x <- max(dx * 1.60, 85)
      min_span_y <- max(dy * 1.60, 85)
      if (min_span_y / min_span_x > ratio_panel_yx) {
        span_y <- min_span_y
        span_x <- span_y / ratio_panel_yx
      } else {
        span_x <- min_span_x
        span_y <- span_x * ratio_panel_yx
      }
    } else {
      span_x <- 115
      span_y <- span_x * ratio_panel_yx
    }
    
    bbox_utm <- c(
      xmin = cx - span_x / 2,
      ymin = cy - span_y / 2,
      xmax = cx + span_x / 2,
      ymax = cy + span_y / 2
    )
    class(bbox_utm) <- "bbox"
    attr(bbox_utm, "crs") <- st_crs(32718)
    
    # Capas en UTM 18S optimizadas: si ya existen precalculadas en memoria, se reutilizan.
    # De lo contrario, se filtran candidatos con índice espacial R-tree antes de proyectar,
    # evitando transformar miles de geometrías completas en cada consulta o reporte.
    bbox_sfc_utm <- sf::st_as_sfc(bbox_utm)
    bbox_sfc_4326 <- sf::st_transform(bbox_sfc_utm, 4326)
    
    recortar_capa_optimizada <- function(capa_4326, capa_utm_precalculada = NULL) {
      if (!is.null(capa_utm_precalculada) && nrow(capa_utm_precalculada) > 0) {
        cand <- suppressMessages(sf::st_intersects(bbox_sfc_utm, capa_utm_precalculada)[[1]])
        if (length(cand) == 0) return(sf::st_sf(geometry = sf::st_sfc(crs = 32718)))
        return(suppressWarnings(sf::st_crop(capa_utm_precalculada[cand, , drop = FALSE], bbox_utm)))
      }
      if (is.null(capa_4326) || nrow(capa_4326) == 0) {
        return(sf::st_sf(geometry = sf::st_sfc(crs = 32718)))
      }
      cand <- suppressMessages(sf::st_intersects(bbox_sfc_4326, capa_4326)[[1]])
      if (length(cand) == 0) return(sf::st_sf(geometry = sf::st_sfc(crs = 32718)))
      sub_utm <- sf::st_transform(capa_4326[cand, , drop = FALSE], 32718)
      suppressWarnings(sf::st_crop(sub_utm, bbox_utm))
    }
    
    zonif_utm_global <- get0("zonificacion_utm_compartida", envir = .GlobalEnv, ifnotfound = NULL)
    vias_utm_global <- get0("vias_utm_compartidas", envir = .GlobalEnv, ifnotfound = NULL)
    at_utm_global <- get0("alta_tension_utm_compartida", envir = .GlobalEnv, ifnotfound = NULL)
    ferro_utm_global <- get0("ferrocarril_utm_compartida", envir = .GlobalEnv, ifnotfound = NULL)
    ambito_utm_global <- get0("ambito_utm_compartida", envir = .GlobalEnv, ifnotfound = NULL)
    
    zonif_crop  <- recortar_capa_optimizada(capas_pdu$zonificacion, zonif_utm_global)
    vias_crop   <- recortar_capa_optimizada(capas_pdu$vias, vias_utm_global)
    at_crop     <- recortar_capa_optimizada(capas_pdu$alta_tension, at_utm_global)
    ferro_crop  <- recortar_capa_optimizada(capas_pdu$ferrocarril, ferro_utm_global)
    ambito_crop <- recortar_capa_optimizada(capas_pdu$ambito, ambito_utm_global)
    
    p <- ggplot()
    
    # 1. Zonificación con paleta oficial de la Gerencia
    if (nrow(zonif_crop) > 0) {
      subzonas_presentes <- unique(zonif_crop$COD_S_ZONA)
      pal_zonif <- pal_subzonas[subzonas_presentes]
      pal_zonif[is.na(pal_zonif)] <- "#BCBDBE"
      
      p <- p + geom_sf(data = zonif_crop, aes(fill = COD_S_ZONA), color = "#555555", linewidth = 0.35, alpha = 0.8) +
        scale_fill_manual(
          values = pal_zonif,
          name = "Zonificación Normativa",
          guide = guide_legend(ncol = 4, byrow = TRUE, title.position = "top")
        )
    }
    
    # 2. Vías Propuestas
    if (nrow(vias_crop) > 0) {
      pal_vias <- capas_pdu$colores_vias
      if (is.null(pal_vias)) {
        pal_vias <- get0("colores_vias", envir = .GlobalEnv, ifnotfound = NULL)
      }
      tipos_trazo <- c(
        "SISTEMA VIAL PROVINCIAL-METROPOLITANO" = "longdash",
        "SISTEMA VIAL PRIMARIO" = "dashed",
        "SISTEMA VIAL SECUNDARIO" = "dotdash",
        "SISTEMA VIAL ESPECIAL" = "dotted"
      )
      tipos_locales <- setdiff(unique(vias_crop$SIS_VIAL), names(tipos_trazo))
      tipos_trazo <- c(tipos_trazo, stats::setNames(rep("solid", length(tipos_locales)), tipos_locales))
      p <- p + geom_sf(data = vias_crop, aes(color = SIS_VIAL, linetype = SIS_VIAL), linewidth = 0.75, alpha = 0.9) +
        scale_color_manual(
          values = pal_vias,
          name = "Sistema Vial Propuesto (PDU)",
          guide = guide_legend(ncol = 2, byrow = TRUE, title.position = "top")
        ) +
        scale_linetype_manual(values = tipos_trazo, guide = "none")
    }
    
    # 3. Alta Tensión y Ferrocarril
    if (nrow(at_crop) > 0) {
      p <- p + geom_sf(data = at_crop, color = "#C0392B", linetype = "dashed", linewidth = 1.0)
    }
    if (nrow(ferro_crop) > 0) {
      p <- p + geom_sf(data = ferro_crop, color = "#202020", linewidth = 1.2)
    }
    
    # 3b. Ámbito PDU
    if (nrow(ambito_crop) > 0) {
      p <- p + geom_sf(data = ambito_crop, fill = NA, color = "#D32F2F", linetype = "dashed", linewidth = 1.0)
    }
    
    # 4. Predio / Punto consultado (Destacado en rojo institucional)
    if (es_poligono) {
      p <- p + geom_sf(data = geom_utm, color = "#D80808", fill = "#D80808", alpha = 0.25, linewidth = 2.0)
    } else {
      p <- p + geom_sf(data = geom_utm, color = "#202020", fill = "#D80808", shape = 21, size = 6.0, stroke = 1.8)
    }
    
    # 5. Anotación Cartográfica: Rosa de los Vientos (Norte) con tarjeta de fondo
    x_norte <- as.numeric(bbox_utm["xmax"]) - 0.065 * span_x
    y_norte <- as.numeric(bbox_utm["ymax"]) - 0.085 * span_y
    l_norte <- 0.045 * span_y
    w_norte <- 0.020 * span_x
    
    df_norte_bg <- data.frame(
      xmin = x_norte - w_norte * 1.8,
      xmax = x_norte + w_norte * 1.8,
      ymin = y_norte - l_norte * 0.7,
      ymax = y_norte + l_norte * 1.9
    )
    
    df_norte_izq <- data.frame(
      x = c(x_norte, x_norte - w_norte, x_norte),
      y = c(y_norte + l_norte, y_norte - l_norte * 0.4, y_norte)
    )
    df_norte_der <- data.frame(
      x = c(x_norte, x_norte + w_norte, x_norte),
      y = c(y_norte + l_norte, y_norte - l_norte * 0.4, y_norte)
    )
    
    p <- p +
      geom_rect(data = df_norte_bg, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
                fill = alpha("#FFFFFF", 0.90), color = "#CBD5E1", linewidth = 0.35, inherit.aes = FALSE) +
      geom_polygon(data = df_norte_izq, aes(x = x, y = y), fill = "#006633", color = "#202020", linewidth = 0.3) +
      geom_polygon(data = df_norte_der, aes(x = x, y = y), fill = "#FFFFFF", color = "#202020", linewidth = 0.3) +
      annotate("text", x = x_norte, y = y_norte + l_norte * 1.45, label = "N", fontface = "bold", size = 4.2, color = "#006633")
    
    # 6. Anotación Cartográfica: Escala Gráfica y Numérica con tarjeta de fondo
    scale_dist <- if (span_x < 120) 10 else if (span_x < 220) 25 else if (span_x < 450) 50 else if (span_x < 800) 100 else 200
    x_esc_ini <- as.numeric(bbox_utm["xmin"]) + 0.04 * span_x
    x_esc_fin <- x_esc_ini + scale_dist
    y_esc <- as.numeric(bbox_utm["ymin"]) + 0.07 * span_y
    h_esc <- 0.016 * span_y
    
    df_esc_bg <- data.frame(
      xmin = x_esc_ini - 0.015 * span_x,
      xmax = x_esc_fin + 0.025 * span_x,
      ymin = y_esc - h_esc * 2.2,
      ymax = y_esc + h_esc * 2.6
    )
    
    df_esc1 <- data.frame(
      x = c(x_esc_ini, x_esc_ini + scale_dist / 2, x_esc_ini + scale_dist / 2, x_esc_ini),
      y = c(y_esc - h_esc / 2, y_esc - h_esc / 2, y_esc + h_esc / 2, y_esc + h_esc / 2)
    )
    df_esc2 <- data.frame(
      x = c(x_esc_ini + scale_dist / 2, x_esc_fin, x_esc_fin, x_esc_ini + scale_dist / 2),
      y = c(y_esc - h_esc / 2, y_esc - h_esc / 2, y_esc + h_esc / 2, y_esc + h_esc / 2)
    )
    
    p <- p +
      geom_rect(data = df_esc_bg, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
                fill = alpha("#FFFFFF", 0.90), color = "#CBD5E1", linewidth = 0.35, inherit.aes = FALSE) +
      geom_polygon(data = df_esc1, aes(x = x, y = y), fill = "#006633", color = "#202020", linewidth = 0.3) +
      geom_polygon(data = df_esc2, aes(x = x, y = y), fill = "#FFFFFF", color = "#202020", linewidth = 0.3) +
      annotate("text", x = x_esc_ini, y = y_esc + h_esc * 1.5, label = "0", size = 2.9, fontface = "bold", color = "#202020") +
      annotate("text", x = x_esc_fin, y = y_esc + h_esc * 1.5, label = paste0(scale_dist, " m"), size = 2.9, fontface = "bold", color = "#202020") +
      annotate("text", x = (x_esc_ini + x_esc_fin) / 2, y = y_esc - h_esc * 1.4, label = "ESCALA GRÁFICA", size = 2.3, fontface = "bold", color = "#006633")
    
    p <- p +
      coord_sf(
        xlim = c(bbox_utm["xmin"], bbox_utm["xmax"]),
        ylim = c(bbox_utm["ymin"], bbox_utm["ymax"]),
        expand = FALSE,
        datum = st_crs(32718)
      ) +
      scale_x_continuous(labels = function(x) format(round(x), big.mark = ",")) +
      scale_y_continuous(labels = function(y) format(round(y), big.mark = ",")) +
      theme_minimal() +
      labs(
        x = "Coordenada Este (m) — Proyección UTM Zona 18S",
        y = "Coordenada Norte (m) — Proyección UTM Zona 18S"
      ) +
      theme(
        axis.title = element_text(size = 9.0, face = "bold", color = "#202020"),
        axis.text = element_text(size = 8.0, color = "#334155"),
        legend.position = "bottom",
        legend.box = "vertical",
        legend.spacing.y = unit(0.15, "cm"),
        legend.text = element_text(size = 7.8),
        legend.title = element_text(size = 8.5, face = "bold", color = "#006633"),
        legend.margin = margin(t = 2, b = 2),
        panel.border = element_rect(color = "#008800", fill = NA, linewidth = 0.9),
        panel.grid.major = element_line(color = "#CBD5E1", linewidth = 0.35, linetype = "dashed"),
        plot.margin = margin(4, 4, 4, 4)
      )
    
    if (!is.null(ruta_salida_png)) {
      dir.create(dirname(ruta_salida_png), showWarnings = FALSE, recursive = TRUE)
      ggsave(ruta_salida_png, plot = p, width = ancho_in, height = alto_in, dpi = 240)
    }
    
    temp_png <- tempfile(fileext = ".png")
    ggsave(temp_png, plot = p, width = ancho_in, height = alto_in, dpi = 240)
    img_uri <- knitr::image_uri(temp_png)
    unlink(temp_png)
    return(img_uri)
  }, error = function(e) {
    warning("Error al generar plano cartográfico: ", conditionMessage(e), call. = FALSE)
    return(NULL)
  })
}
