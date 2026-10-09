# ==============================================================================
# GEOVISOR DEL PLAN DE DESARROLLO URBANO (PDU) DE ANTA - CUSCO (2024 - 2034)
# Proyecto: Mejoramiento de los Servicios de Gestión Territorial y Desarrollo
#           Urbano Sostenible, del distrito de Anta, provincia de Anta, Cusco
# ==============================================================================

# En desarrollo local, recargar la configuración ignorada por Git antes de
# inicializar cualquier cliente. En Posit Connect las variables se administran
# como secretos del despliegue y este archivo no se publica.
if (file.exists(".Renviron")) {
  readRenviron(".Renviron")
}

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(leaflet)
  library(sf)
  library(dplyr)
  library(htmltools)
  library(ggplot2)
  library(knitr)
})

# Carga segura del motor PDF Quarto / Typst y fallback Pagedown
if (requireNamespace("quarto", quietly = TRUE)) {
  suppressPackageStartupMessages(library(quarto))
}
if (requireNamespace("pagedown", quietly = TRUE)) {
  suppressPackageStartupMessages(library(pagedown))
}

options(shiny.maxRequestSize = 25 * 1024^2)
source("R/spatial_utils.R", local = TRUE)
source("R/supabase_utils.R", local = TRUE)

# Las rutas de Chrome/Pandoc se resuelven desde el entorno de despliegue.

# ------------------------------------------------------------------------------
# 0. CARGA DE DATOS OFICIALES DESDE SUPABASE/POSTGIS Y CONSTANTES
# ------------------------------------------------------------------------------
datos_supabase <- supabase_cargar_datos_espaciales()
capas <- datos_supabase$capas
df_parametros <- datos_supabase$parametros
message(
  "GeoVisor iniciado con fuente espacial ", datos_supabase$origen, ": ",
  paste(names(datos_supabase$conteos), datos_supabase$conteos, sep = "=", collapse = ", ")
)

# Paleta de colores oficial para zonificación (por subzona y macrozona) y vías
colores_subzonas <- capas$colores_subzonas
colores_zonas <- capas$colores_zonas
colores_vias <- capas$colores_vias

# Textos institucionales oficiales
PROYECTO_NOMBRE_OFICIAL <- "Mejoramiento de los Servicios de Gestión Territorial y Desarrollo Urbano Sostenible, del distrito de Anta, provincia de Anta, departamento del Cusco"
INSTRUMENTO_GESTION_OFICIAL <- "PLAN DE DESARROLLO URBANO DE ANTA 2024 - 2034"
ENTIDAD_OFICIAL <- "MUNICIPALIDAD PROVINCIAL DE ANTA"
FECHA_APROBACION_PDU <- "04 de abril del 2025"
CARACTER_INFORMATIVO <- paste(
  "Documento de carácter exclusivamente informativo. No constituye certificado oficial,",
  "no genera derechos urbanísticos ni reemplaza la verificación técnica municipal.",
  "El certificado oficial debe tramitarse ante la Gerencia de Desarrollo Urbano y Rural",
  "de la Municipalidad Provincial de Anta."
)

# Función auxiliar para renderizar plano cartográfico de alta resolución sin márgenes vacíos con Rosa de los Vientos y Escala
generar_mapa_certificado <- function(geom_sf, es_poligono = TRUE, ruta_salida_png = NULL) {
  tryCatch({
    geom_utm <- st_transform(geom_sf, 32718)
    
    # Dimensiones del lienzo cartográfico
    ancho_in <- 8.2
    alto_in <- 5.6
    ratio_canvas <- ancho_in / alto_in # Proporción exacta 1.464
    
    bb_geom <- st_bbox(geom_utm)
    cx <- as.numeric((bb_geom["xmin"] + bb_geom["xmax"]) / 2)
    cy <- as.numeric((bb_geom["ymin"] + bb_geom["ymax"]) / 2)
    dx <- as.numeric(bb_geom["xmax"] - bb_geom["xmin"])
    dy <- as.numeric(bb_geom["ymax"] - bb_geom["ymin"])
    
    if (es_poligono) {
      span_min_y <- 75 # Metros mínimos para visualizar contexto vial y manzanas cercanas
      span_y <- max(dy * 2.2, span_min_y)
      span_x <- span_y * ratio_canvas
      if (dx * 1.8 > span_x) {
        span_x <- dx * 1.8
        span_y <- span_x / ratio_canvas
      }
    } else {
      span_y <- 85
      span_x <- span_y * ratio_canvas
    }
    
    bbox_utm <- c(
      xmin = cx - span_x / 2,
      ymin = cy - span_y / 2,
      xmax = cx + span_x / 2,
      ymax = cy + span_y / 2
    )
    class(bbox_utm) <- "bbox"
    attr(bbox_utm, "crs") <- st_crs(32718)
    
    # Capas transformadas a UTM 18S para recorte y renderizado cartográfico exacto
    zonif_utm <- st_transform(capas$zonificacion, 32718)
    vias_utm <- st_transform(capas$vias, 32718)
    at_utm <- st_transform(capas$alta_tension, 32718)
    ferro_utm <- st_transform(capas$ferrocarril, 32718)
    
    zonif_crop <- suppressWarnings(st_crop(zonif_utm, bbox_utm))
    vias_crop <- suppressWarnings(st_crop(vias_utm, bbox_utm))
    at_crop <- suppressWarnings(st_crop(at_utm, bbox_utm))
    ferro_crop <- suppressWarnings(st_crop(ferro_utm, bbox_utm))
    
    p <- ggplot()
    
    # 1. Zonificación con paleta oficial de la Gerencia
    if (nrow(zonif_crop) > 0) {
      subzonas_presentes <- unique(zonif_crop$COD_S_ZONA)
      pal_zonif <- colores_subzonas[subzonas_presentes]
      pal_zonif[is.na(pal_zonif)] <- "#BCBDBE"
      
      p <- p + geom_sf(data = zonif_crop, aes(fill = COD_S_ZONA), color = "#475569", linewidth = 0.35, alpha = 0.8) +
        scale_fill_manual(
          values = pal_zonif,
          name = "Zonificación Normativa",
          guide = guide_legend(ncol = 4, byrow = TRUE, title.position = "top")
        )
    }
    
    # 2. Vías Propuestas
    if (nrow(vias_crop) > 0) {
      pal_vias <- c(
        "SISTEMA VIAL PROVINCIAL-METROPOLITANO" = "#B88808",
        "SISTEMA VIAL PRIMARIO"                 = "#D80808",
        "SISTEMA VIAL SECUNDARIO"               = "#008800",
        "SISTEMA VIAL ESPECIAL"                 = "#8E44AD"
      )
      p <- p + geom_sf(data = vias_crop, aes(color = SIS_VIAL), linewidth = 1.25, alpha = 0.95) +
        scale_color_manual(
          values = pal_vias,
          name = "Sistema Vial Propuesto (PDU)",
          guide = guide_legend(ncol = 2, byrow = TRUE, title.position = "top")
        )
    }
    
    # 3. Alta Tensión y Ferrocarril
    if (nrow(at_crop) > 0) {
      p <- p + geom_sf(data = at_crop, color = "#C0392B", linetype = "dashed", linewidth = 1.0)
    }
    if (nrow(ferro_crop) > 0) {
      p <- p + geom_sf(data = ferro_crop, color = "#202020", linewidth = 1.2)
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
    return(NULL)
  })
}

# ------------------------------------------------------------------------------
# 1. INTERFAZ DE USUARIO (UI)
# ------------------------------------------------------------------------------
ui <- page_navbar(
  id = "main_navbar",
  title = div(
    class = "d-flex align-items-center gap-3",
    div(
      class = "brand-logo-left",
      img(src = "escudo_muni_anta.png", class = "logo-muni-header", alt = "Escudo Anta", title = "Municipalidad Provincial de Anta")
    ),
    div(
      class = "d-flex flex-column",
      div(
        class = "d-flex align-items-center flex-wrap gap-2",
        span(class = "fw-bold fs-5", style = "color: #174A3A; letter-spacing: -0.3px;", "GEOVISOR PDU ANTA"),
        span(class = "pdu-badge-title", "2024 - 2034"),
        span(
          class = "badge d-none d-sm-inline-flex align-items-center gap-1",
          style = "background-color: #FDF9EE; color: #78350F; border: 1px solid #C59B27; font-size: 0.72rem; font-weight: 600; padding: 3px 8px; border-radius: 4px;",
          icon("calendar-check"), " Aprobado: 04 de abril del 2025"
        ),
        uiOutput("ui_status_supabase_pill", inline = TRUE),
        uiOutput("ui_metricas_publicas", inline = TRUE)
      ),
      tags$small(
        class = "text-muted d-flex align-items-center gap-1",
        style = "font-size: 0.72rem; font-weight: 500;",
        "Municipalidad Provincial de Anta • Sistema de Información Territorial y Gestión Urbana"
      )
    )
  ),
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#174A3A",
    secondary = "#4C5E56",
    base_font = font_google("Inter")
  ),
  header = tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
    tags$script(HTML("
      function obtenerUbicacionGPS() {
        if (!navigator.geolocation) {
          alert('La geolocalización no es soportada por este dispositivo.');
          return;
        }
        var btn = document.getElementById('btn_gps_movil');
        if (btn) {
          btn.innerHTML = '<i class=\"fa fa-spinner fa-spin\"></i> Obteniendo coordenadas GPS...';
          btn.disabled = true;
        }
        navigator.geolocation.getCurrentPosition(
          function(position) {
            if (btn) {
              btn.innerHTML = '<i class=\"fa fa-location-crosshairs\"></i> 📍 Mi Ubicación Actual (GPS)';
              btn.disabled = false;
            }
            Shiny.setInputValue('gps_location_device', {
              lat: position.coords.latitude,
              lng: position.coords.longitude,
              accuracy: position.coords.accuracy,
              timestamp: new Date().getTime()
            }, {priority: 'event'});
          },
          function(error) {
            if (btn) {
              btn.innerHTML = '<i class=\"fa fa-location-crosshairs\"></i> 📍 Mi Ubicación Actual (GPS)';
              btn.disabled = false;
            }
            var msg = 'Error GPS: ';
            switch(error.code) {
              case error.PERMISSION_DENIED: msg += 'Permiso denegado por el usuario.'; break;
              case error.POSITION_UNAVAILABLE: msg += 'Ubicación no disponible.'; break;
              case error.TIMEOUT: msg += 'Tiempo de espera agotado.'; break;
              default: msg += error.message; break;
            }
            alert(msg);
          },
          { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
      }
    ")),
    tags$script(HTML("
      document.addEventListener('shiny:connected', function() {
        var storageKey = 'pdu_anta_visitante_id';
        var visitorId = localStorage.getItem(storageKey);
        if (!visitorId) {
          visitorId = (window.crypto && window.crypto.randomUUID)
            ? window.crypto.randomUUID()
            : 'pdu-' + Date.now() + '-' + Math.random().toString(36).slice(2);
          localStorage.setItem(storageKey, visitorId);
        }
        Shiny.setInputValue('visitante_geovisor_id', visitorId, {priority: 'event'});
      });
    ")),
    tags$style(HTML("
      .leaflet-container { height: calc(100vh - 82px) !important; }
      .nav-link { font-weight: 600; }
    "))
  ),
  fillable = TRUE,
  
  # --- PESTAÑA PRINCIPAL: VISOR Y CONSULTAS ---
  nav_panel(
    title = "Visor Territorial y Consultas",
    value = "tab_visor",
    icon = icon("layer-group"),
    
    layout_sidebar(
      fillable = TRUE,
      sidebar = sidebar(
        width = 410,
        title = div(class = "fw-bold", style = "color: #174A3A;", icon("sliders"), " Panel de Consulta"),
        
        # Botón GPS móvil nativo
        tags$button(
          id = "btn_gps_movil",
          type = "button",
          class = "btn btn-gps-mobile w-100 py-2 mb-3",
          onclick = "obtenerUbicacionGPS()",
          icon("location-crosshairs"), " 📍 Mi Ubicación Actual (GPS Móvil)"
        ),
        
        tabsetPanel(
          id = "tab_modo_consulta",
          type = "pills",
          
          # --- MODO 1: CONSULTA PUNTUAL ---
          tabPanel(
            title = "Punto",
            icon = icon("location-dot"),
            div(class = "mt-3"),
            
            radioButtons(
              "tipo_coordenada", "Sistema de Coordenadas:",
              choices = c("UTM Zona 18S" = "utm", "Coordenadas WGS84" = "geo"),
              selected = "utm",
              inline = TRUE
            ),
            
            conditionalPanel(
              condition = "input.tipo_coordenada == 'utm'",
              div(
                class = "row g-2 mb-2",
                div(class = "col-6", numericInput("in_este", "Este (X - m)", value = 806050, step = 1)),
                div(class = "col-6", numericInput("in_norte", "Norte (Y - m)", value = 8510700, step = 1))
              )
            ),
            
            conditionalPanel(
              condition = "input.tipo_coordenada == 'geo'",
              div(
                class = "row g-2 mb-2",
                div(class = "col-6", numericInput("in_lat", "Latitud (°)", value = -13.4567, step = 0.0001)),
                div(class = "col-6", numericInput("in_lng", "Longitud (°)", value = -72.1742, step = 0.0001))
              )
            ),
            
            actionButton(
              "btn_consultar_punto", "Ubicar y Consultar Punto",
              class = "btn btn-success w-100 fw-bold mb-2",
              style = "background-color: #008800; border-color: #006633;",
              icon = icon("magnifying-glass-location")
            )
          ),
          
          # --- MODO 2: CONSULTA POR POLÍGONO (PREDIO / LOTE) ---
          tabPanel(
            title = "Polígono de Predio",
            icon = icon("draw-polygon"),
            div(class = "mt-3"),
            
            p(class = "small text-muted mb-2",
              "Pegue las coordenadas de los vértices del predio o suba un archivo (CSV / GeoJSON) para calcular la zonificación, afectación vial y servidumbres."
            ),
            
            radioButtons(
              "poligono_input_tipo", "Formato de Vértices:",
              choices = c("UTM 18S (Este Norte)" = "utm", "WGS84 (Lat Lng)" = "geo"),
              selected = "utm",
              inline = TRUE
            ),
            
            textAreaInput(
              "txt_vertices_poligono", "Vértices del Polígono (un punto por línea):",
              value = "805900 8510600\n806250 8510600\n806250 8510850\n805900 8510850",
              rows = 4,
              placeholder = "805900 8510600\n806250 8510600\n806250 8510850\n805900 8510850"
            ),
            
            fileInput(
              "file_poligono", "O subir archivo de lote (Shapefile ZIP / SHP, GeoJSON, KML, CSV):",
              multiple = TRUE,
              accept = c(".zip", ".shp", ".dbf", ".shx", ".prj", ".cpg", ".geojson", ".json", ".kml", ".csv", ".txt"),
              buttonLabel = "Examinar...",
              placeholder = "Seleccione .zip, .shp o GeoJSON"
            ),
            
            actionButton(
              "btn_consultar_poligono", "Calcular Intersección del Polígono",
              class = "btn btn-success w-100 fw-bold mb-2",
              style = "background-color: #008800; border-color: #006633;",
              icon = icon("calculator")
            )
          )
        ),
        
        hr(class = "my-3"),
        
        # Panel de Resultados (Ficha Técnica y Descargas)
        div(class = "fw-bold mb-2", style = "color: #006633;", icon("clipboard-check"), " Ficha Técnica Referencial"),
        div(class = "alert alert-warning py-2 px-3 small", CARACTER_INFORMATIVO),
        uiOutput("ui_ficha_resultado"),
        uiOutput("ui_botones_descarga")
      ),
      
      # Contenedor del Mapa Leaflet
      div(
        class = "h-100 position-relative",
        leafletOutput("mapa_pdu", width = "100%", height = "100%")
      )
    )
  ),
  
  # --- PESTAÑA 2: CERTIFICADO INFORMATIVO DIRECTO EN APP ---
  nav_panel(
    title = "Reporte Informativo",
    value = "tab_certificado",
    icon = icon("file-invoice"),
    
    div(
      class = "container-fluid px-lg-5 px-3 py-3",
      div(
        class = "d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom bg-white p-3 rounded shadow-sm",
        actionButton("btn_volver_al_visor", "← Volver al Visor Territorial", class = "btn btn-outline-success fw-bold"),
        uiOutput("ui_boton_descarga_certificado_tab")
      ),
      div(
        class = "alert alert-warning border-0 shadow-sm reporte-disclaimer",
        icon("circle-info"), tags$b(" Alcance del reporte: "), CARACTER_INFORMATIVO
      ),
      uiOutput("ui_certificado_completo_view")
    )
  ),
  
  # --- PESTAÑA 3: CATÁLOGO DE ZONIFICACIÓN Y LEYENDA ---
  nav_panel(
    title = "Catálogo Normativo de Zonas",
    value = "tab_catalogo",
    icon = icon("book-bookmark"),
    
    div(
      class = "container py-4",
      div(
        class = "card shadow-sm border-0 mb-4 p-4 catalogo-card",
        
        div(
          class = "d-flex flex-column flex-md-row justify-content-between align-items-md-center gap-3 mb-3",
          div(
            h3(class = "fw-bold mb-1 catalogo-title", icon("book-open"), " Catálogo de Zonificación y Parámetros Urbanísticos"),
            p(class = "text-muted mb-0", "Parámetros técnicos y edificatorios aprobados para cada tipología dentro del ámbito del PDU Anta 2024 - 2034.")
          ),
          div(
            class = "d-flex align-items-center gap-2",
            div(
              style = "min-width: 260px;",
              textInput(
                "txt_buscar_catalogo", NULL,
                placeholder = "🔍 Buscar zona (ej. R-3, CZ, ZRE)...",
                width = "100%"
              )
            )
          )
        ),
        
        # Resumen de estadísticas normativas
        div(
          class = "row g-3 mb-4",
          div(
            class = "col-md-4 col-sm-6",
            div(
              class = "p-3 rounded-3 border d-flex align-items-center gap-3 catalogo-kpi",
              div(class = "p-2 rounded-2 text-white catalogo-kpi-icon catalogo-kpi-icon--green", icon("layer-group", class = "fs-4")),
              div(
                tags$small(class = "text-muted text-uppercase fw-bold", "Total Subzonas"),
                tags$h4(class = "mb-0 fw-bold", as.character(nrow(df_parametros)))
              )
            )
          ),
          div(
            class = "col-md-4 col-sm-6",
            div(
              class = "p-3 rounded-3 border d-flex align-items-center gap-3 catalogo-kpi",
              div(class = "p-2 rounded-2 text-white catalogo-kpi-icon catalogo-kpi-icon--gold", icon("gavel", class = "fs-4")),
              div(
                tags$small(class = "text-muted text-uppercase fw-bold", "Marco Normativo"),
                tags$h4(class = "mb-0 fw-bold", "RATDUS / RNE")
              )
            )
          ),
          div(
            class = "col-md-4 col-sm-12",
            div(
              class = "p-3 rounded-3 border d-flex align-items-center gap-3 catalogo-kpi",
              div(class = "p-2 rounded-2 text-white catalogo-kpi-icon catalogo-kpi-icon--dark", icon("circle-check", class = "fs-4")),
              div(
                tags$small(class = "text-muted text-uppercase fw-bold", "Aprobación Oficial"),
                tags$h5(class = "mb-0 fw-bold", "04 de abril del 2025")
              )
            )
          )
        ),
        
        hr(class = "my-2"),
        
        div(
          class = "table-responsive mt-3 catalogo-table-wrap",
          uiOutput("ui_tabla_catalogo_dinamica")
        )
      )
    )
  ),
  
  # El antiguo buzón ciudadano queda deshabilitado: el GeoVisor es un servicio
  # de consulta informativa y no un canal para recepción de aportes.
  if (FALSE) nav_panel(
    title = "Buzón y Observaciones",
    value = "tab_buzon",
    icon = icon("envelope-open-text"),
    
    div(
      class = "container py-4",
      div(
        class = "row g-4",
        
        # Columna Formulario de Reporte
        div(
          class = "col-lg-7",
          div(
            class = "card-buzon h-100",
            div(
              class = "card-buzon-header",
              div(
                class = "d-flex justify-content-between align-items-start mb-2",
                tags$h4(class = "fw-bold mb-0 text-white", icon("comments"), " Buzón de Participación Ciudadana PDU"),
                span(class = "badge-cloud-tag", icon("database"), " Supabase Cloud DB")
              ),
              p(class = "mb-0 small text-light opacity-90",
                "Registre sus observaciones, dudas sobre zonificación o requerimientos referidos a su predio. La información ingresará de forma segura y directa a la base de datos oficial del proyecto."
              )
            ),
            div(
              class = "p-4",
              div(
                class = "row g-3",
                div(
                  class = "col-md-6",
                  textInput("in_buzon_nombre", "Nombres y Apellidos:", placeholder = "Ej: Juan Pérez Morales")
                ),
                div(
                  class = "col-md-6",
                  textInput("in_buzon_contacto", "Correo o Teléfono de contacto:", placeholder = "ejemplo@correo.com / 984000000")
                ),
                div(
                  class = "col-md-6",
                  selectInput(
                    "in_buzon_tipo", "Materia de la Observación:",
                    choices = c(
                      "Consulta sobre Zonificación" = "Zonificación",
                      "Observación a Vía Propuesta" = "Vía proyectada",
                      "Afectación por Servidumbre (AT / Tren)" = "Servidumbre",
                      "Verificación de Límite de Ámbito" = "Ámbito PDU",
                      "Sugerencia / Otra Consulta" = "Otro"
                    )
                  )
                ),
                div(
                  class = "col-md-6",
                  div(
                    class = "d-flex justify-content-between align-items-center mb-1",
                    tags$label(class = "form-label mb-0 small fw-bold", "Ubicación del Predio:"),
                    actionLink("btn_autollenar_ubicacion_buzon", "📍 Usar punto consultado", class = "small fw-bold text-success")
                  ),
                  textInput("in_buzon_ubicacion", NULL, placeholder = "Coordenadas UTM o referencia del predio")
                ),
                div(
                  class = "col-12",
                  textAreaInput(
                    "in_buzon_mensaje", "Detalle de su Observación o Consulta:",
                    rows = 4,
                    placeholder = "Describa detalladamente su solicitud o requerimiento técnico sobre el predio..."
                  )
                ),
                div(
                  class = "col-12 mt-3",
                  actionButton(
                    "btn_enviar_buzon", "📤 Enviar Observación al Sistema Oficial",
                    class = "btn btn-success fw-bold w-100 py-2",
                    icon = icon("paper-plane")
                  )
                ),
                div(
                  class = "col-12 mt-2",
                  uiOutput("ui_feedback_buzon")
                )
              )
            )
          )
        ),
        
        # Columna Información y Avisos de Supabase
        div(
          class = "col-lg-5",
          div(
            class = "d-flex flex-column gap-3",
            
            # Tarjeta de Estado de la Plataforma
            div(
              class = "card p-4 border-0 shadow-sm",
              style = "background: #FFFFFF; border-radius: var(--radius-md); border-left: 4px solid #1B4D3E !important;",
              h5(class = "fw-bold", style = "color: #1B4D3E;", icon("server"), " Estado del Sistema"),
              p(class = "small text-muted mb-2",
                "El GeoVisor se encuentra sincronizado con la infraestructura en la nube de Supabase y Posit Connect Cloud."
              ),
              uiOutput("ui_card_estado_supabase")
            ),
            
            # Tarjeta de Avisos Municipales Dinámicos
            div(
              class = "card p-4 border-0 shadow-sm",
              style = "background: #FFFFFF; border-radius: var(--radius-md); border-left: 4px solid #C59B27 !important;",
              div(
                class = "d-flex justify-content-between align-items-center mb-2",
                h5(class = "fw-bold mb-0", style = "color: #78350F;", icon("bullhorn"), " Avisos Oficiales"),
                span(class = "badge bg-warning text-dark", "PDU Anta")
              ),
              p(class = "small text-muted mb-3", "Comunicados emitidos en tiempo real por la Gerencia de Desarrollo Urbano:"),
              uiOutput("ui_lista_avisos_municipales")
            )
          )
        )
      )
    )
  ),
  
  # --- PESTAÑA 5: INFORMACIÓN INSTITUCIONAL DEL PDU ---
  nav_panel(
    title = "Información del PDU",
    value = "tab_informacion",
    icon = icon("circle-info"),
    div(
      class = "container py-4",
      div(
        class = "hero-pdu mb-4",
        div(
          class = "d-flex flex-column flex-md-row align-items-md-center justify-content-between gap-4",
          div(
            class = "d-flex align-items-center gap-3",
            img(src = "escudo_muni_anta.png", style = "height: 75px; width: auto; background: white; padding: 4px; border-radius: 8px;", alt = "Escudo Anta"),
            div(
              tags$h3(class = "fw-bold mb-1 text-white", "PLAN DE DESARROLLO URBANO DE ANTA (2024 - 2034)"),
              tags$h6(class = "mb-0", style = "color: #E2E8F0;", "Municipalidad Provincial de Anta — Gestión Territorial y Desarrollo Urbano Sostenible")
            )
          ),
          img(src = "pdu_actualizado_sf.png", style = "height: 70px; width: auto; background: white; padding: 4px; border-radius: 8px;", alt = "Logo PDU")
        )
      ),
      
      div(
        class = "card shadow-sm border-0 p-4 mb-4",
        style = "background-color: #FFFFFF; border-radius: var(--radius-md);",
        
        div(
          class = "card p-3 mb-4",
          style = "background-color: #FDF9EE; border-left: 5px solid #C59B27;",
          tags$b(style = "color: #1B4D3E;", "Denominación Oficial del Proyecto:"),
          tags$p(class = "mb-0", style = "color: #1E293B; font-size: 1.05rem;", paste0("«", PROYECTO_NOMBRE_OFICIAL, "»"))
        ),
        
        div(
          class = "row g-4",
          div(
            class = "col-md-6",
            div(
              class = "p-4 bg-light rounded-3 border h-100",
              h5(class = "fw-bold", style = "color: #1B4D3E;", icon("mountain-sun"), " Ámbito de Intervención"),
              p("El ámbito del PDU abarca una superficie reglamentada de aproximadamente ", tags$b("9,469.35 hectáreas"), ", integrando sectores de la provincia de Anta incluyendo los distritos de Anta, Pucyura, Cachimayo, Huarocondo y Zurite."),
              
              h5(class = "fw-bold mt-4", style = "color: #1B4D3E;", icon("road"), " Sistema Vial Propuesto y Secciones Normativas"),
              p("El Sistema Vial Propuesto establece la jerarquización de la red vial en ", tags$b("Sistema Vial Provincial-Metropolitano, Primario, Secundario y Especial"), ", determinando para cada eje el código de vía y su Sección Vial Normativa (SV en metros lineales) para asegurar el derecho de vía y la transitabilidad futura.")
            )
          ),
          div(
            class = "col-md-6",
            div(
              class = "p-4 bg-light rounded-3 border h-100",
              h5(class = "fw-bold", style = "color: #1B4D3E;", icon("bolt"), " Servidumbres Eléctricas y Ferroviarias"),
              p("Comprende las fajas de servidumbre de líneas de alta tensión (138 kV - L-1007 y 220 kV - L-1002 de 20 m y 25 m de ancho) y la zona de influencia del Ferrocarril Trasandino (D.S. 032-2005-MTC)."),
              
              h5(class = "fw-bold mt-4", style = "color: #1B4D3E;", icon("file-lines"), " Base Legal y Reglamentaria"),
              p("D.S. N° 012-2022-VIVIENDA (Reglamento de Acondicionamiento Territorial y Desarrollo Urbano Sostenible - RATDUS), Reglamento Nacional de Edificaciones (RNE) y Ordenanzas Provinciales de la Municipalidad Provincial de Anta.")
            )
          ),
          div(
            class = "col-12",
            div(
              class = "p-4 bg-white rounded-3 border",
              h5(class = "fw-bold", style = "color: #1B4D3E;", icon("gavel"), " Normativa asociada a la planificación urbana"),
              p(class = "text-muted", "Marco normativo de referencia del PDU de Anta, resumido a partir de los documentos de la carpeta normativa:"),
              tags$ul(
                class = "mb-3",
                tags$li(
                  tags$b("Ley N.º 31313 — Ley de Desarrollo Urbano Sostenible: "),
                  "establece el marco nacional para el acondicionamiento territorial, la planificación urbana y la gestión del suelo, con principios de sostenibilidad, equidad, participación y gestión del riesgo.",
                  " ", tags$a("Ver texto oficial", href = "https://busquedas.elperuano.pe/dispositivo/NL/1976352-2", target = "_blank", rel = "noopener")
                ),
                tags$li(
                  tags$b("D.S. N.º 012-2022-VIVIENDA — RATDUS: "),
                  "reglamenta los procesos e instrumentos de planificación, incluido el PDU y sus etapas de formulación, participación, aprobación, implementación y actualización.",
                  " ", tags$a("Ver norma en el MVCS", href = "https://www.gob.pe/institucion/vivienda/normas-legales/3588833-012-2022-vivienda", target = "_blank", rel = "noopener")
                ),
                tags$li(
                  tags$b("D.Leg. N.º 1674: "),
                  "modifica la Ley N.º 31313 y refuerza la planificación urbana y rural, la gestión del suelo, la participación ciudadana y la gestión del riesgo.",
                  " ", tags$a("Ver texto oficial", href = "https://busquedas.elperuano.pe/dispositivo/NL/2329855-10", target = "_blank", rel = "noopener")
                )
              ),
              p(class = "small text-muted mb-0", "El PDU aplica este marco mediante su zonificación, clasificación del suelo, parámetros urbanísticos y sistema vial. Para un trámite o predio concreto, revise también la ordenanza provincial de aprobación y las normas sectoriales pertinentes.")
            )
          )
        )
      )
    )
  ),
  
  # Espaciador y Logo Derecho (Proyecto PDU) al extremo del encabezado
  nav_spacer(),
  nav_item(
    div(
      class = "brand-logo-right me-2 d-none d-md-flex",
      img(src = "pdu_actualizado_sf.png", class = "logo-pdu-header", alt = "Logo PDU", title = "Plan de Desarrollo Urbano de Anta 2024 - 2034")
    )
  )
)

# ------------------------------------------------------------------------------
# 2. LÓGICA DEL SERVIDOR (SERVER)
# ------------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # Estado reactivo: Modo activo ("punto" o "poligono")
  modo_activo <- reactiveVal("punto")
  punto_actual <- reactiveVal(NULL)
  poligono_actual <- reactiveVal(NULL)
  
  # ----------------------------------------------------------------------------
  # 2.1 RENDERIZADO BASE DEL MAPA LEAFLET
  # ----------------------------------------------------------------------------
  output$mapa_pdu <- renderLeaflet({
    ambito_bbox <- st_bbox(st_transform(capas$ambito, CRS_GEOGRAFICO))

    leaflet() %>%
      addProviderTiles(providers$OpenStreetMap, group = "OpenStreetMap") %>%
      addProviderTiles(providers$Esri.WorldImagery, group = "Satélite (Esri)") %>%
      addProviderTiles(providers$Esri.WorldTopoMap, group = "Topográfico (Esri)") %>%
      addProviderTiles(providers$Esri.WorldStreetMap, group = "Calles (Esri)") %>%
      
      # 1. Distritos
      addPolygons(
        data = capas$distritos,
        group = "Límites Distritales",
        fill = FALSE,
        color = "#7F8C8D",
        weight = 1.5,
        dashArray = "4, 4",
        label = ~paste("Distrito:", NOMBDIST)
      ) %>%
      
      # 2. Ámbito PDU
      addPolygons(
        data = capas$ambito,
        group = "Ámbito PDU Anta",
        fillColor = "#8FAE9B",
        fillOpacity = 0.10,
        color = "#1F5137",
        weight = 3,
        dashArray = "6, 6",
        label = ~paste("Ámbito PDU Anta -", NOM_AI)
      ) %>%
      
      # 3. Servidumbre Alta Tensión
      addPolygons(
        data = capas$alta_tension_buffer,
        group = "Servidumbre Alta Tensión",
        fillColor = "#F89808",
        fillOpacity = 0.45,
        color = "#D80808",
        weight = 1,
        label = ~paste("Faja de Servidumbre Eléctrica:", TENS_NOMIN, "kV")
      ) %>%
      
      # 4. Líneas Alta Tensión
      addPolylines(
        data = capas$alta_tension,
        group = "Líneas de Alta Tensión",
        color = "#D80808",
        weight = 3,
        opacity = 0.9,
        label = ~paste("Línea AT:", NOM_EMPRES, "-", TENS_NOMIN)
      ) %>%
      
      # 5. Servidumbre Ferrocarril
      addPolygons(
        data = capas$ferrocarril_buffer,
        group = "Área Referencial Ferroviaria",
        fillColor = "#8E44AD",
        fillOpacity = 0.35,
        color = "#6C3483",
        weight = 1,
        label = ~"Área referencial de análisis ferroviario (15 m por lado; requiere verificación sectorial)"
      ) %>%
      
      # 6. Vía Férrea
      addPolylines(
        data = capas$ferrocarril,
        group = "Vía Férrea (Tren)",
        color = "#202020",
        weight = 3.5,
        dashArray = "6, 4",
        label = ~paste("Ferrocarril:", NOM_FERR, "-", TRAMO_FERR)
      ) %>%
      
      # 7. Zonificación PDU
      addPolygons(
        data = capas$zonificacion,
        group = "Zonificación PDU",
        fillColor = ~COLOR_HEX,
        fillOpacity = 0.65,
        color = "#202020",
        weight = 1,
        label = ~paste0(COD_S_ZONA, " (", COD_ZONA, "): ", SUB_ZONA),
        highlightOptions = highlightOptions(
          weight = 3,
          color = "#FFFFFF",
          fillOpacity = 0.9,
          bringToFront = FALSE
        )
      ) %>%
      
      # 8. Sistema Vial Propuesto
      addPolylines(
        data = capas$vias,
        group = "Sistema Vial Propuesto",
        color = ~COLOR_VIA,
        weight = 3.5,
        opacity = 0.9,
        label = ~paste0(COD_VIA_PR, " (", SECCION_VI, ") — ", SIS_VIAL),
        popup = ~paste0(
          "<div style='font-size:13px; font-family:Inter, sans-serif;'>",
          "<div style='background:#006633; color:white; padding:4px 8px; font-weight:bold; border-radius:4px;'>SISTEMA VIAL PROPUESTO</div>",
          "<div style='padding:6px 2px;'>",
          "<b>Jerarquía:</b> ", SIS_VIAL, "<br>",
          "<b>Código de Vía:</b> <span style='color:#006633; font-weight:bold;'>", COD_VIA_PR, "</span><br>",
          "<b>Sección Vial Normativa (SV):</b> <span style='background:#FFF7D6; color:#B88808; padding:2px 6px; font-weight:bold; border:1px solid #B88808; border-radius:3px;'>", SECCION_VI, "</span>",
          "</div></div>"
        ),
        highlightOptions = highlightOptions(
          weight = 5,
          color = "#F8F888",
          bringToFront = TRUE
        )
      ) %>%
      
      addEasyButton(easyButton(
        icon = "fa-crosshairs", title = "Mi Ubicación Actual (GPS)",
        position = "topleft",
        onClick = JS("function(btn, map){ map.locate({setView: true, maxZoom: 17, enableHighAccuracy: true}); }")
      )) %>%
      
      addLayersControl(
        baseGroups = c("OpenStreetMap", "Satélite (Esri)", "Topográfico (Esri)", "Calles (Esri)"),
        overlayGroups = c(
          "Zonificación PDU", "Sistema Vial Propuesto", "Ámbito PDU Anta", "Límites Distritales",
          "Servidumbre Alta Tensión", "Líneas de Alta Tensión",
          "Área Referencial Ferroviaria", "Vía Férrea (Tren)"
        ),
        options = layersControlOptions(collapsed = TRUE)
      ) %>%
      
      fitBounds(
        lng1 = unname(ambito_bbox["xmin"]),
        lat1 = unname(ambito_bbox["ymin"]),
        lng2 = unname(ambito_bbox["xmax"]),
        lat2 = unname(ambito_bbox["ymax"])
      )
  })
  
  # ----------------------------------------------------------------------------
  # 2.2 CONSULTAS PUNTUALES Y EVENTO GPS
  # ----------------------------------------------------------------------------
  fijar_punto_consulta <- function(lng, lat, precision = NULL) {
    validar_coordenada_punto(lng, lat)
    modo_activo("punto")
    poligono_actual(NULL)
    
    pt_4326 <- st_sfc(st_point(c(lng, lat)), crs = 4326)
    pt_utm <- st_transform(pt_4326, 32718)
    coords_utm <- st_coordinates(pt_utm)
    
    punto_actual(list(
      geom_4326 = pt_4326,
      geom_utm = pt_utm,
      lng = lng,
      lat = lat,
      este = round(coords_utm[1], 2),
      norte = round(coords_utm[2], 2),
      precision = precision
    ))
    
    updateNumericInput(session, "in_lat", value = round(lat, 6))
    updateNumericInput(session, "in_lng", value = round(lng, 6))
    updateNumericInput(session, "in_este", value = round(coords_utm[1], 1))
    updateNumericInput(session, "in_norte", value = round(coords_utm[2], 1))

    leafletProxy("mapa_pdu") %>%
      clearGroup("consulta_activa") %>%
      addCircleMarkers(
        lng = lng, lat = lat, group = "consulta_activa",
        radius = 7, color = "#202020", weight = 2,
        fillColor = "#D80808", fillOpacity = 0.9,
        label = "Punto consultado"
      ) %>%
      setView(lng = lng, lat = lat, zoom = 17)
      
    # Registro de auditoría territorial en Supabase
    tryCatch({
      pt_sf <- st_sf(geometry = pt_4326)
      en_amb <- any(st_intersects(pt_sf, capas$ambito, sparse = FALSE)[1, ])
      dist_m <- st_join(pt_sf, capas$distritos, join = st_intersects)$NOMBDIST[1]
      idx_z <- st_intersects(pt_sf, capas$zonificacion)[[1]]
      z_cod <- if (length(idx_z) > 0) capas$zonificacion$COD_S_ZONA[idx_z[1]] else "SIN_ZONA"
      supabase_registrar_consulta(
        tipo_consulta = "punto",
        coordenadas_texto = paste0("E: ", round(coords_utm[1], 1), " N: ", round(coords_utm[2], 1), " (UTM 18S)"),
        distrito = ifelse(is.na(dist_m), "Fuera de provincia", dist_m),
        en_ambito = en_amb,
        zona_principal = z_cod,
        detalle_json = list(lat = round(lat, 6), lng = round(lng, 6), precision = precision)
      )
    }, error = function(e) NULL)
  }
  
  # Clic en el mapa
  observeEvent(input$mapa_pdu_click, {
    click <- input$mapa_pdu_click
    req(click$lng, click$lat)
    tryCatch(fijar_punto_consulta(click$lng, click$lat), error = function(e) {
      showNotification(conditionMessage(e), type = "error")
    })
  })
  
  # GPS Móvil desde botón HTML / JS
  observeEvent(input$gps_location_device, {
    loc <- input$gps_location_device
    req(loc$lat, loc$lng)
    tryCatch(fijar_punto_consulta(loc$lng, loc$lat, precision = round(loc$accuracy, 1)), error = function(e) {
      showNotification(conditionMessage(e), type = "error")
    })
    showNotification(
      paste0("Ubicación GPS fijada (Precisión: ±", round(loc$accuracy, 1), " m)"),
      type = "message", duration = 4
    )
  })
  
  # GPS Leaflet nativo
  observeEvent(input$mapa_pdu_location, {
    loc <- input$mapa_pdu_location
    req(loc$longitude, loc$latitude)
    tryCatch(fijar_punto_consulta(loc$longitude, loc$latitude), error = function(e) {
      showNotification(conditionMessage(e), type = "error")
    })
  })
  
  # Botón consultar punto manual
  observeEvent(input$btn_consultar_punto, {
    tryCatch({
      if (input$tipo_coordenada == "utm") {
        req(input$in_este, input$in_norte)
        pt_utm <- st_sfc(st_point(c(input$in_este, input$in_norte)), crs = 32718)
        pt_4326 <- st_transform(pt_utm, 4326)
        coords_geo <- st_coordinates(pt_4326)
        fijar_punto_consulta(coords_geo[1], coords_geo[2])
      } else {
        req(input$in_lat, input$in_lng)
        fijar_punto_consulta(input$in_lng, input$in_lat)
      }
    }, error = function(e) showNotification(conditionMessage(e), type = "error"))
  })
  
  # ----------------------------------------------------------------------------
  # 2.3 CONSULTA POR POLÍGONO DE PREDIO (INTERSECCIÓN Y ZONIFICACIÓN MÚLTIPLE)
  # ----------------------------------------------------------------------------
  observeEvent(input$btn_consultar_poligono, {
    tryCatch({
      modo_activo("poligono")
      punto_actual(NULL)
    
    coords_mat <- NULL
    
    # 1. Intentar leer archivo espacial subido (.zip, .shp múltiple, .geojson, .kml, .csv)
    if (!is.null(input$file_poligono) && nrow(input$file_poligono) > 0) {
      f_df <- input$file_poligono
      poly_subido <- NULL
      
      # A. Caso archivo ZIP con Shapefile
      idx_zip <- which(tolower(tools::file_ext(f_df$name)) == "zip")
      if (length(idx_zip) > 0) {
        temp_dir <- tempfile("shp_zip_")
        extraer_zip_seguro(f_df$datapath[idx_zip[1]], temp_dir)
        shp_list <- list.files(temp_dir, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
        if (length(shp_list) > 0) {
          poly_subido <- tryCatch(st_read(shp_list[1], quiet = TRUE), error = function(e) NULL)
        }
      }
      
      # B. Caso selección múltiple de Shapefile (.shp, .dbf, .shx, .prj, .cpg)
      idx_shp <- which(tolower(tools::file_ext(f_df$name)) == "shp")
      if (is.null(poly_subido) && length(idx_shp) > 0) {
        temp_dir <- tempfile("shp_upload_")
        dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)
        for (k in 1:nrow(f_df)) {
          dest_k <- file.path(temp_dir, basename(f_df$name[k]))
          file.copy(f_df$datapath[k], dest_k, overwrite = TRUE)
        }
        shp_target <- file.path(temp_dir, basename(f_df$name[idx_shp[1]]))
        poly_subido <- tryCatch(st_read(shp_target, quiet = TRUE), error = function(e) NULL)
      }
      
      # C. Caso GeoJSON, JSON, KML, GML
      idx_vec <- which(tolower(tools::file_ext(f_df$name)) %in% c("geojson", "json", "kml", "gml"))
      if (is.null(poly_subido) && length(idx_vec) > 0) {
        poly_subido <- tryCatch(st_read(f_df$datapath[idx_vec[1]], quiet = TRUE), error = function(e) NULL)
      }
      
      # D. Caso CSV / TXT tabular con coordenadas
      idx_txt <- which(tolower(tools::file_ext(f_df$name)) %in% c("csv", "txt", "dat"))
      if (is.null(poly_subido) && length(idx_txt) > 0) {
        df_coords <- tryCatch(read.table(f_df$datapath[idx_txt[1]], header = FALSE, fill = TRUE), error = function(e) NULL)
        if (is.null(df_coords) || ncol(df_coords) < 2) {
          df_coords <- tryCatch(read.csv(f_df$datapath[idx_txt[1]], header = FALSE), error = function(e) NULL)
        }
        if (!is.null(df_coords) && ncol(df_coords) >= 2) {
          nums_x <- suppressWarnings(as.numeric(as.character(df_coords[[1]])))
          nums_y <- suppressWarnings(as.numeric(as.character(df_coords[[2]])))
          valid_pts <- !is.na(nums_x) & !is.na(nums_y)
          if (sum(valid_pts) >= 3) {
            coords_mat <- cbind(nums_x[valid_pts], nums_y[valid_pts])
          }
        }
      }
      
      # Si se extrajo un objeto sf válido desde el archivo subido:
      if (!is.null(poly_subido) && nrow(poly_subido) > 0) {
        poly_4326 <- normalizar_poligono_predio(poly_subido)
        showNotification(paste0("✓ Archivo '", f_df$name[1], "' cargado e interpretado exitosamente."), type = "message")
        procesar_poligono_sf(poly_4326)
        return()
      }
    }
    
    # 2. Si no hay archivo o es texto manual de vértices:
    if (is.null(coords_mat)) {
      lineas <- unlist(strsplit(input$txt_vertices_poligono, "[\r\n]+"))
      lineas <- trimws(lineas)
      lineas <- lineas[lineas != ""]
      
      if (length(lineas) < 3) {
        showNotification("Debe ingresar al menos 3 vértices o subir un archivo Shapefile / GeoJSON válido.", type = "error")
        return()
      }
      
      parsed <- lapply(lineas, function(l) {
        nums <- as.numeric(unlist(regmatches(l, gregexpr("[-+]?[0-9]*\\.?[0-9]+(?:[eE][-+]?[0-9]+)?", l))))
        if (length(nums) >= 2) return(nums[1:2]) else return(NULL)
      })
      parsed <- do.call(rbind, parsed[!sapply(parsed, is.null)])
      coords_mat <- parsed
    }
    
    if (is.null(coords_mat) || nrow(coords_mat) < 3) {
      showNotification("No se pudieron extraer vértices válidos para el polígono.", type = "error")
      return()
    }
    
    if (!all(coords_mat[1, ] == coords_mat[nrow(coords_mat), ])) {
      coords_mat <- rbind(coords_mat, coords_mat[1, ])
    }
    
    if (input$poligono_input_tipo == "geo") {
      # La interfaz recibe Latitud Longitud; sf requiere X=Longitud, Y=Latitud.
      coords_mat <- coords_mat[, c(2, 1), drop = FALSE]
    }
    crs_origen <- if (input$poligono_input_tipo == "utm") 32718 else 4326
    poly_sfc <- st_sfc(st_polygon(list(coords_mat)), crs = crs_origen)
    poly_sf <- st_sf(id = 1, geometry = poly_sfc)
    poly_4326 <- normalizar_poligono_predio(poly_sf)
    procesar_poligono_sf(poly_4326)
    }, error = function(e) {
      poligono_actual(NULL)
      showNotification(conditionMessage(e), type = "error", duration = 8)
    })
  })
  
  procesar_poligono_sf <- function(poly_4326) {
    poly_4326 <- normalizar_poligono_predio(poly_4326)
    poly_utm <- st_transform(poly_4326, 32718)
    area_total_m2 <- sum(as.numeric(st_area(poly_utm)), na.rm = TRUE)
    perimetro_m <- sum(as.numeric(st_length(st_boundary(poly_utm))), na.rm = TRUE)
    
    # 1. Ámbito PDU
    area_en_ambito <- area_interseccion_unica_m2(poly_4326, capas$ambito)
    pct_en_ambito <- min(100, (area_en_ambito / area_total_m2) * 100)
    
    # 2. Distritos
    inter_dist <- st_intersection(poly_4326, capas$distritos)
    distritos_list <- if (nrow(inter_dist) > 0) unique(inter_dist$NOMBDIST) else "Desconocido"
    
    # 3. Alta Tensión
    area_at_m2 <- area_interseccion_unica_m2(poly_4326, capas$alta_tension_buffer)
    pct_at <- min(100, (area_at_m2 / area_total_m2) * 100)
    
    # 4. Ferrocarril
    area_ffcc_m2 <- area_interseccion_unica_m2(poly_4326, capas$ferrocarril_buffer)
    pct_ffcc <- min(100, (area_ffcc_m2 / area_total_m2) * 100)
    
    # 5. Sistema Vial Propuesto Intersectado o Colindante (Buffer estricto de 25 metros)
    vias_utm <- st_transform(capas$vias, 32718)
    dists_vias <- as.numeric(st_distance(poly_utm, vias_utm))
    idx_vias_cercanas <- which(dists_vias <= 25)
    
    tabla_vias_predio <- data.frame(
      SIS_VIAL = character(), COD_VIA_PR = character(), SECCION_VI = character(), DISTANCIA_M = numeric(), stringsAsFactors = FALSE
    )
    
    if (length(idx_vias_cercanas) > 0) {
      vias_sub <- capas$vias[idx_vias_cercanas, ]
      d_sub <- dists_vias[idx_vias_cercanas]
      
      tabla_vias_predio <- data.frame(
        SIS_VIAL = vias_sub$SIS_VIAL,
        COD_VIA_PR = vias_sub$COD_VIA_PR,
        SECCION_VI = vias_sub$SECCION_VI,
        DISTANCIA_M = round(d_sub, 3),
        stringsAsFactors = FALSE
      ) %>%
        distinct(SIS_VIAL, COD_VIA_PR, SECCION_VI, .keep_all = TRUE) %>%
        arrange(DISTANCIA_M)
    }
    
    # 6. Intersección con Zonificación (Múltiples zonas)
    inter_zonif <- suppressWarnings(st_intersection(poly_4326, capas$zonificacion))
    
    tabla_zonif <- data.frame(
      COD_ZONA = character(), COD_S_ZONA = character(), SUB_ZONA = character(),
      AREA_M2 = numeric(), PCT_LOTE = numeric(), stringsAsFactors = FALSE
    )
    
    lista_parametros_zonas <- list()
    
    if (nrow(inter_zonif) > 0) {
      inter_zonif_utm <- st_transform(inter_zonif, 32718)
      inter_zonif$AREA_INTER_M2 <- as.numeric(st_area(inter_zonif_utm))
      
      tabla_zonif <- inter_zonif %>%
        st_drop_geometry() %>%
        group_by(COD_ZONA, COD_S_ZONA, SUB_ZONA) %>%
        summarise(AREA_M2 = sum(AREA_INTER_M2), .groups = "drop") %>%
        mutate(
          AREA_M2 = round(AREA_M2, 3),
          PCT_LOTE = round((AREA_M2 / area_total_m2) * 100, 3)
        ) %>%
        arrange(desc(AREA_M2))
      
      # Extraer ficha de parámetros para cada zona intersectada
      for (i in 1:nrow(tabla_zonif)) {
        cod_sz <- trimws(tabla_zonif$COD_S_ZONA[i])
        cod_z <- trimws(tabla_zonif$COD_ZONA[i])
        
        m_idx <- which(trimws(df_parametros$COD_S_ZONA) == cod_sz)
        if (length(m_idx) == 0) m_idx <- which(trimws(df_parametros$COD_ZONA) == cod_z)
        
        if (length(m_idx) > 0) {
          p_row <- df_parametros[m_idx[1], ]
          p_row$AREA_AFECTADA_M2 <- tabla_zonif$AREA_M2[i]
          p_row$PCT_AFECTADO <- tabla_zonif$PCT_LOTE[i]
          lista_parametros_zonas[[length(lista_parametros_zonas) + 1]] <- p_row
        }
      }
    }
    
    poligono_actual(list(
      poly_4326 = poly_4326,
      poly_utm = poly_utm,
      area_m2 = round(area_total_m2, 3),
      area_has = round(area_total_m2 / 10000, 3),
      perimetro_m = round(perimetro_m, 3),
      pct_en_ambito = round(pct_en_ambito, 3),
      distritos = distritos_list,
      area_at_m2 = round(area_at_m2, 3),
      pct_at = round(pct_at, 3),
      area_ffcc_m2 = round(area_ffcc_m2, 3),
      pct_ffcc = round(pct_ffcc, 3),
      tabla_vias_predio = tabla_vias_predio,
      tabla_zonif = tabla_zonif,
      lista_parametros_zonas = lista_parametros_zonas
    ))
    
    bb <- st_bbox(poly_4326)
    leafletProxy("mapa_pdu") %>%
      clearGroup("consulta_activa") %>%
      addPolygons(
        data = poly_4326,
        group = "consulta_activa",
        fillColor = "#D80808",
        fillOpacity = 0.35,
        color = "#202020",
        weight = 3,
        dashArray = "3, 3"
      ) %>%
      fitBounds(
        lng1 = as.numeric(bb["xmin"]), lat1 = as.numeric(bb["ymin"]),
        lng2 = as.numeric(bb["xmax"]), lat2 = as.numeric(bb["ymax"])
      )
      
    # Registro de auditoría territorial de polígono en Supabase
    tryCatch({
      z_prin <- if (nrow(tabla_zonif) > 0) tabla_zonif$COD_S_ZONA[1] else "SIN_ZONA"
      supabase_registrar_consulta(
        tipo_consulta = "poligono",
        coordenadas_texto = paste0("Área: ", round(area_total_m2, 1), " m² | Perímetro: ", round(perimetro_m, 1), " ml"),
        distrito = paste(distritos_list, collapse = ", "),
        en_ambito = (pct_en_ambito > 0),
        zona_principal = z_prin,
        detalle_json = list(
          area_m2 = round(area_total_m2, 1),
          perimetro_m = round(perimetro_m, 1),
          pct_en_ambito = pct_en_ambito,
          zonas_count = nrow(tabla_zonif)
        )
      )
    }, error = function(e) NULL)
  }
  
  # ----------------------------------------------------------------------------
  # 2.4 RENDERIZADO DINÁMICO DE LA FICHA TÉCNICA
  # ----------------------------------------------------------------------------
  output$ui_ficha_resultado <- renderUI({
    modo <- modo_activo()
    
    if (modo == "punto") {
      pt_data <- punto_actual()
      if (is.null(pt_data)) {
        return(
          div(
            class = "text-center py-4 text-muted",
            icon("hand-pointer", class = "fs-2 mb-2 d-block text-secondary"),
            tags$b("Haga clic en el mapa"), " o use el botón GPS para consultar un predio."
          )
        )
      }
      
      pt_sf <- st_sf(geometry = pt_data$geom_4326)
      en_ambito <- any(st_intersects(pt_sf, capas$ambito, sparse = FALSE)[1, ])
      dist_match <- st_join(pt_sf, capas$distritos, join = st_intersects)$NOMBDIST[1]
      distrito_nombre <- if (!is.na(dist_match)) dist_match else "Fuera de la provincia"
      en_serv_at <- any(st_intersects(pt_sf, capas$alta_tension_buffer, sparse = FALSE)[1, ])
      en_serv_ffcc <- any(st_intersects(pt_sf, capas$ferrocarril_buffer, sparse = FALSE)[1, ])
      
      # Vía propuesta más cercana (buffer 25m)
      vias_utm <- st_transform(capas$vias, 32718)
      dists_v <- as.numeric(st_distance(pt_data$geom_utm, vias_utm))
      idx_min_v <- which.min(dists_v)
      min_dist_v <- dists_v[idx_min_v]
      
      info_via <- NULL
      if (length(min_dist_v) > 0 && min_dist_v <= 25) {
        info_via <- list(
          SIS_VIAL = capas$vias$SIS_VIAL[idx_min_v],
          COD_VIA_PR = capas$vias$COD_VIA_PR[idx_min_v],
          SECCION_VI = capas$vias$SECCION_VI[idx_min_v],
          distancia = round(min_dist_v, 3)
        )
      }
      
      idx_zonif_punto <- st_intersects(pt_sf, capas$zonificacion)[[1]]
      zonificacion_ambigua <- length(idx_zonif_punto) > 1
      if (length(idx_zonif_punto) > 0) {
        zonif_match <- capas$zonificacion[idx_zonif_punto[1], ]
        cod_zona <- zonif_match$COD_ZONA[1]
        cod_s_zona <- zonif_match$COD_S_ZONA[1]
        sub_zona <- zonif_match$SUB_ZONA[1]
      } else {
        cod_zona <- cod_s_zona <- sub_zona <- NA_character_
      }
      
      params_row <- NULL
      if (!is.na(cod_s_zona) && cod_s_zona != "") {
        m_idx <- which(trimws(df_parametros$COD_S_ZONA) == trimws(cod_s_zona))
        if (length(m_idx) > 0) params_row <- df_parametros[m_idx[1], ]
      }
      
      tagList(
        if (en_ambito) div(class = "alert-ambito-ok mb-2", icon("circle-check"), " DENTRO del Ámbito PDU Anta")
        else div(class = "alert-ambito-fuera mb-2", icon("triangle-exclamation"), " FUERA del Ámbito PDU Anta"),
        
        # Bloque de Información Vial (buffer 25m)
        if (!is.null(info_via)) {
          div(
            class = "card-vial-info mb-2",
            div(class = "d-flex justify-content-between align-items-center mb-1",
                tags$b(icon("road"), " Vía Propuesta Colindante:"),
                tags$span(class = "badge-seccion-vial", info_via$SECCION_VI)
            ),
            div(
              tags$span(class = "fw-bold", info_via$SIS_VIAL),
              tags$br(),
              tags$small(paste0("Código: ", info_via$COD_VIA_PR, " (a ", info_via$distancia, " m)"))
            )
          )
        } else {
          div(class = "card p-2 mb-2 bg-light text-muted small",
              icon("road"), " Sin vía propuesta del PDU en buffer de 25m.")
        },
        
        if (en_serv_at) div(class = "alert-servidumbre", icon("triangle-exclamation"), tags$b(" Servidumbre de Alta Tensión (Prohibida edificación).")),
        if (en_serv_ffcc) div(class = "alert-servidumbre-ferro", icon("train"), tags$b(" Proximidad ferroviaria referencial. Verificar el derecho de vía con el MTC y el concesionario.")),
        if (!is.null(pt_data$precision) && is.finite(pt_data$precision) && pt_data$precision > 10) {
          div(class = "alert alert-warning py-2 small", icon("location-crosshairs"),
              paste0("Precisión GPS aproximada: ±", pt_data$precision, " m. Verifique el punto antes de usar el resultado."))
        },
        if (zonificacion_ambigua) {
          div(class = "alert alert-warning py-2 small", icon("triangle-exclamation"),
              "El punto coincide con un límite de zonificación. Se requiere verificación cartográfica municipal.")
        },
        
        if (!is.na(cod_zona) && !is.null(params_row)) {
          color_h <- colores_zonas[cod_zona]
          if (is.na(color_h)) color_h <- "#008800"
          div(
            class = "ficha-container mb-2",
            div(
              class = "ficha-header", style = paste0("background: linear-gradient(135deg, ", color_h, ", #202020);"),
              div(tags$h6(class = "mb-0 fw-bold", paste(cod_s_zona, "-", cod_zona)), tags$small(sub_zona)),
              tags$span(class = "badge bg-light text-dark", cod_zona)
            ),
            div(
              class = "ficha-body",
              tags$table(
                class = "param-table",
                tags$tbody(
                  tags$tr(tags$th("Distrito:"), tags$td(tags$b(distrito_nombre))),
                  tags$tr(tags$th("Densidad Neta:"), tags$td(params_row$DENSIDAD_NETA_MAX)),
                  tags$tr(tags$th("Lote Mínimo:"), tags$td(params_row$LOTE_MINIMO)),
                  tags$tr(tags$th("Frente Mínimo:"), tags$td(params_row$FRENTE_MINIMO)),
                  tags$tr(tags$th("Altura Máxima:"), tags$td(tags$b(style = "color: #006633;", params_row$ALTURA_MAXIMA))),
                  tags$tr(tags$th("Área Libre:"), tags$td(params_row$AREA_LIBRE_MIN)),
                  tags$tr(tags$th("Coef. Edificación:"), tags$td(params_row$COEFICIENTE_EDIF)),
                  tags$tr(tags$th("Retiro Frontal:"), tags$td(params_row$RETIRO_FRONTAL)),
                  tags$tr(tags$th("Estado normativo:"), tags$td(tags$b(class = "text-warning", params_row$ESTADO_VALIDACION))),
                  tags$tr(tags$th("Usos Permitidos:"), tags$td(tags$small(params_row$USOS_PERMITIDOS)))
                )
              )
            )
          )
        } else {
          div(class = "alert alert-warning mb-2", "Sin zonificación reglamentada en este punto.")
        },
        
        div(class = "text-muted small text-end", paste0("UTM 18S: E ", pt_data$este, " | N ", pt_data$norte))
      )
      
    } else {
      # Ficha técnica para polígono
      poly_data <- poligono_actual()
      if (is.null(poly_data)) {
        return(
          div(
            class = "text-center py-4 text-muted",
            icon("draw-polygon", class = "fs-2 mb-2 d-block text-secondary"),
            tags$b("Ingrese un polígono"), " para ver el cálculo de zonificación y afectaciones."
          )
        )
      }
      
      tagList(
        div(
          class = "card p-2 mb-2 bg-light border-0",
          div(class = "d-flex justify-content-between", tags$b("Área del Predio:"), tags$span(paste0(poly_data$area_m2, " m² (", poly_data$area_has, " ha)"))),
          div(class = "d-flex justify-content-between", tags$b("Perímetro:"), tags$span(paste0(poly_data$perimetro_m, " ml"))),
          div(class = "d-flex justify-content-between", tags$b("Distrito(s):"), tags$span(paste(poly_data$distritos, collapse = ", "))),
          div(class = "d-flex justify-content-between", tags$b("Ámbito PDU:"), tags$span(paste0(poly_data$pct_en_ambito, "% en ámbito")))
        ),
        
        # Bloque de Vías Propuestas detectadas (buffer 25m)
        if (nrow(poly_data$tabla_vias_predio) > 0) {
          div(
            class = "card-vial-info mb-2",
            div(class = "fw-bold mb-1", style = "color: #B88808;", icon("road"), " Vías Propuestas en Buffer de 25m:"),
            lapply(1:nrow(poly_data$tabla_vias_predio), function(iv) {
              rv <- poly_data$tabla_vias_predio[iv, ]
              div(
                class = "d-flex justify-content-between align-items-center py-1 border-bottom border-light",
                div(
                  tags$b(rv$SIS_VIAL), tags$br(),
                  tags$small(paste0("Cód: ", rv$COD_VIA_PR, " (a ", rv$DISTANCIA_M, " m)"))
                ),
                tags$span(class = "badge-seccion-vial", rv$SECCION_VI)
              )
            })
          )
        } else {
          div(class = "card p-2 mb-2 bg-light text-muted small",
              icon("road"), " Sin vías propuestas del PDU dentro del buffer de 25m.")
        },
        
        if (poly_data$pct_at > 0) {
          div(class = "alert-servidumbre mb-2", icon("triangle-exclamation"),
              tags$b(paste0(" Servidumbre de Alta Tensión afecta ", poly_data$pct_at, "% del predio (", poly_data$area_at_m2, " m²). Prohibida edificación.")))
        },
        if (poly_data$pct_ffcc > 0) {
          div(class = "alert-servidumbre-ferro mb-2", icon("train"),
              tags$b(paste0(" Área ferroviaria referencial alcanza ", poly_data$pct_ffcc, "% del predio (", poly_data$area_ffcc_m2, " m²). Requiere verificación sectorial.")))
        },
        
        if (nrow(poly_data$tabla_zonif) > 0) {
          div(
            class = "card mb-2 border-0 shadow-sm",
            div(class = "card-header bg-success text-white py-1 px-2 fw-bold small", "Desglose de Zonificación:"),
            div(
              class = "card-body p-0",
              tags$table(
                class = "table table-sm table-striped mb-0 small",
                tags$thead(tags$tr(tags$th("Zona"), tags$th("Subzona"), tags$th("Área (m²)"), tags$th("%"))),
                tags$tbody(
                  lapply(1:nrow(poly_data$tabla_zonif), function(i) {
                    r <- poly_data$tabla_zonif[i, ]
                    tags$tr(
                      tags$td(tags$b(r$COD_ZONA)),
                      tags$td(r$COD_S_ZONA),
                      tags$td(r$AREA_M2),
                      tags$td(tags$b(paste0(r$PCT_LOTE, "%")))
                    )
                  })
                )
              )
            )
          )
        },
        
        if (length(poly_data$lista_parametros_zonas) > 0) {
          tagList(
            h6(class = "fw-bold mt-2 mb-2", style = "color: #006633;", icon("book"), " Parámetros por Zona Intersectada:"),
            lapply(poly_data$lista_parametros_zonas, function(p_row) {
              col_z <- colores_zonas[p_row$COD_ZONA]
              if (is.na(col_z)) col_z <- "#008800"
              div(
                class = "ficha-container mb-2",
                div(
                  class = "ficha-header",
                  style = paste0("background: linear-gradient(135deg, ", col_z, ", #202020); font-size: 0.85rem;"),
                  div(
                    tags$b(paste(p_row$COD_S_ZONA, "-", p_row$NOMBRE_COMPLETO)),
                    tags$br(),
                    tags$small(paste0("Afecta: ", p_row$AREA_AFECTADA_M2, " m² (", p_row$PCT_AFECTADO, "% del lote)"))
                  ),
                  tags$span(class = "badge bg-light text-dark", p_row$COD_ZONA)
                ),
                div(
                  class = "ficha-body p-2",
                  tags$table(
                    class = "param-table",
                    tags$tbody(
                      tags$tr(tags$th("Densidad Neta:"), tags$td(p_row$DENSIDAD_NETA_MAX)),
                      tags$tr(tags$th("Lote Mínimo:"), tags$td(p_row$LOTE_MINIMO)),
                      tags$tr(tags$th("Frente Mínimo:"), tags$td(p_row$FRENTE_MINIMO)),
                      tags$tr(tags$th("Altura Máx.:"), tags$td(tags$b(style = "color: #006633;", p_row$ALTURA_MAXIMA))),
                      tags$tr(tags$th("Área Libre:"), tags$td(p_row$AREA_LIBRE_MIN)),
                      tags$tr(tags$th("Retiro Frontal:"), tags$td(p_row$RETIRO_FRONTAL)),
                      tags$tr(tags$th("Estado normativo:"), tags$td(tags$b(class = "text-warning", p_row$ESTADO_VALIDACION))),
                      tags$tr(tags$th("Usos:"), tags$td(tags$small(p_row$USOS_PERMITIDOS)))
                    )
                  )
                )
              )
            })
          )
        }
      )
    }
  })
  
  # ----------------------------------------------------------------------------
  # 2.6 BOTONES DE CONSULTA Y ACCIONES DEL CERTIFICADO
  # ----------------------------------------------------------------------------
  output$ui_botones_descarga <- renderUI({
    modo <- modo_activo()
    if (modo == "punto" && is.null(punto_actual())) return(NULL)
    if (modo == "poligono" && is.null(poligono_actual())) return(NULL)
    
    div(
      class = "d-flex flex-column gap-2 mt-3",
      actionButton(
        "btn_abrir_certificado_tab", "📋 Ver Reporte Informativo",
        class = "btn btn-success fw-bold w-100",
        style = "padding: 10px;",
        icon = icon("file-invoice")
      ),
      if (pdf_motor_disponible()) {
        downloadButton("btn_descargar_pdf", "📥 Descargar Constancia PDF", class = "btn btn-download-pdf w-100")
      } else {
        div(class = "alert alert-secondary py-2 px-3 small mb-0",
            "La constancia informativa se consulta directamente en la pestaña Reporte Informativo.")
      }
    )
  })
  
  # Navegación entre pestañas
  observeEvent(input$btn_abrir_certificado_tab, {
    nav_select("main_navbar", "tab_certificado")
  })
  
  observeEvent(input$btn_volver_al_visor, {
    nav_select("main_navbar", "tab_visor")
  })
  
  observeEvent(input$btn_ir_a_consultar, {
    nav_select("main_navbar", "tab_visor")
  })
  
  observeEvent(input$btn_ir_a_buzon_con_predio, {
    nav_select("main_navbar", "tab_buzon")
    # Pre-cargar ubicación del predio en el buzón
    modo <- modo_activo()
    if (modo == "punto" && !is.null(punto_actual())) {
      pt <- punto_actual()
      updateTextInput(session, "in_buzon_ubicacion",
                      value = paste0("Consulta Puntual en UTM: E ", pt$este, " | N ", pt$norte, " (Lat: ", round(pt$lat, 5), ", Lng: ", round(pt$lng, 5), ")"))
    } else if (modo == "poligono" && !is.null(poligono_actual())) {
      poly <- poligono_actual()
      updateTextInput(session, "in_buzon_ubicacion",
                      value = paste0("Polígono de Lote: ", poly$area_m2, " m² (Distrito: ", paste(poly$distritos, collapse = ", "), ")"))
    }
  })
  
  # Botón de descarga en la cabecera de la pestaña del certificado
  output$ui_boton_descarga_certificado_tab <- renderUI({
    modo <- modo_activo()
    if (modo == "punto" && is.null(punto_actual())) return(NULL)
    if (modo == "poligono" && is.null(poligono_actual())) return(NULL)
    
    tagList(
      if (pdf_motor_disponible()) downloadButton(
        "btn_descargar_pdf_tab", "📥 Descargar Constancia PDF",
        class = "btn btn-success fw-bold"
      ) else div(
        class = "text-muted small",
        "Consulta disponible directamente en esta pestaña."
      )
    )
  })
  
  # Renderizado dinámico del Certificado Informativo completo dentro de la App
  output$ui_certificado_completo_view <- renderUI({
    modo <- modo_activo()
    if ((modo == "punto" && is.null(punto_actual())) || (modo == "poligono" && is.null(poligono_actual()))) {
      return(
        div(
          class = "card p-5 text-center shadow-sm border-0 my-3",
          style = "background-color: #FFFFFF; border-radius: 12px;",
          icon("file-circle-question", class = "fs-1 text-muted mb-3"),
          tags$h4(class = "fw-bold", style = "color: #006633;", "No se ha realizado ninguna consulta todavía"),
          tags$p(class = "text-muted mb-4",
            "Seleccione un punto en el mapa interactivo o ingrese los vértices de un predio para generar un reporte informativo con plano cartográfico y parámetros referenciales."
          ),
          div(
            actionButton(
              "btn_ir_a_consultar", "🗺️ Ir al Visor Territorial",
              class = "btn btn-success fw-bold px-4 py-2",
              style = "background-color: #008800; border-color: #006633;"
            )
          )
        )
      )
    }
    
    # Si hay consulta activa, generar y presentar el certificado en ancho completo
    doc_html <- generar_html_certificado()
    div(
      class = "card shadow-sm p-lg-4 p-3 border-0 my-2 w-100",
      style = "background-color: #FFFFFF; border-radius: 10px;",
      doc_html
    )
  })
  
  # Función auxiliar para generar el HTML completo del certificado con mapa a página completa, logos, escala, rosa de vientos y datos
  generar_html_certificado <- function() {
    modo <- modo_activo()
    
    escudo_b64 <- tryCatch(knitr::image_uri("www/escudo_muni_anta.png"), error = function(e) "")
    logo_pdu_b64 <- tryCatch(knitr::image_uri("www/pdu_actualizado_sf.png"), error = function(e) "")
    
    # Estilo CSS optimizado para uso del 100% del ancho en pantalla y formato A4 en 2 páginas completas
    css_certificado <- "
      @page { size: A4 portrait; margin: 8mm 10mm 8mm 10mm; }
      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #ffffff; color: #202020; margin: 0; padding: 2px; font-size: 13px; line-height: 1.35; width: 100%; }
      .cert-card { width: 100%; max-width: 1200px; margin: 0 auto; }
      .header-banner { background: linear-gradient(135deg, #006633, #008800); color: white; padding: 8px 16px; border-radius: 4px; margin-bottom: 6px; border-bottom: 3px solid #B88808; width: 100%; box-sizing: border-box; }
      .header-title { font-size: 1.15rem; font-weight: 700; color: #FFFFFF; margin: 0; line-height: 1.2; }
      .header-subtitle { font-size: 0.86rem; color: #F8F888; margin: 0; }
      .header-meta { font-size: 0.72rem; color: rgba(255,255,255,0.85); margin: 0; }
      .project-box { background: #FFF7D6; border: 1px solid #B88808; border-radius: 4px; padding: 5px 12px; font-size: 0.80rem; margin-bottom: 6px; line-height: 1.3; width: 100%; box-sizing: border-box; }
      .section-heading { color: #006633; border-bottom: 2px solid #98C838; padding-bottom: 2px; margin-top: 8px; margin-bottom: 4px; font-size: 0.88rem; font-weight: 700; text-transform: uppercase; }
      .table-cert { width: 100%; border-collapse: collapse; margin-bottom: 6px; font-size: 0.82rem; }
      .table-cert th { background-color: #F2F3EF; color: #202020; font-weight: 600; padding: 4px 8px; border: 1px solid #CBD5E1; }
      .table-cert td { padding: 4px 8px; border: 1px solid #CBD5E1; }
      .table-compact th { width: 28%; }
      .mapa-img-fullpage { width: 100%; height: auto; max-height: 640px; object-fit: contain; border-radius: 4px; border: 1.5px solid #008800; margin-top: 4px; margin-bottom: 6px; display: block; box-sizing: border-box; }
      .badge-vial { background: #B88808; color: white; padding: 2px 8px; border-radius: 3px; font-weight: bold; font-size: 0.80rem; display: inline-block; }
      .sub-card-param { background: #F8FAFC; border: 1px solid #CBD5E1; border-radius: 4px; margin-bottom: 6px; padding: 6px 10px; }
      .sub-card-header { font-weight: 700; color: #006633; margin-bottom: 4px; border-bottom: 1px solid #E2E8F0; padding-bottom: 3px; font-size: 0.84rem; }
      .page-break { page-break-before: always; }
      .avoid-break { page-break-inside: avoid; }
      .methodology-note { background: #F8FAFC; border-left: 4px solid #008800; padding: 4px 8px; font-size: 0.75rem; color: #475569; margin-top: 3px; margin-bottom: 6px; font-style: italic; }
      ul.cert-list { margin: 0 0 6px 0; padding-left: 18px; font-size: 0.82rem; }
      ul.cert-list li { margin-bottom: 3px; }
      .legal-note { font-size: 0.72rem; color: #64748B; text-align: center; margin-top: 10px; border-top: 1px solid #CBD5E1; padding-top: 6px; }
      .text-danger { color: #B91C1C; } .text-warning { color: #9A6700; } .text-muted { color: #64748B; }
      .small { font-size: 0.78rem; } .badge { display:inline-block; padding:2px 6px; border-radius:3px; color:#fff; }
      .bg-success { background:#008800; } .me-2 { margin-right:6px; } .ms-2 { margin-left:6px; }
      .mb-0 { margin-bottom:0; } .mb-1 { margin-bottom:3px; } .mb-2 { margin-bottom:6px; }
    "
    
    if (modo == "punto") {
      pt_data <- punto_actual()
      pt_sf <- st_sf(geometry = pt_data$geom_4326)
      en_ambito <- any(st_intersects(pt_sf, capas$ambito, sparse = FALSE)[1, ])
      dist_match <- st_join(pt_sf, capas$distritos, join = st_intersects)$NOMBDIST[1]
      distrito_nombre <- if (!is.na(dist_match)) dist_match else "Fuera de la provincia"
      en_serv_at <- any(st_intersects(pt_sf, capas$alta_tension_buffer, sparse = FALSE)[1, ])
      en_serv_ffcc <- any(st_intersects(pt_sf, capas$ferrocarril_buffer, sparse = FALSE)[1, ])
      
      # Vía propuesta colindante (Buffer estricto 25m)
      vias_utm <- st_transform(capas$vias, 32718)
      dists_v <- as.numeric(st_distance(pt_data$geom_utm, vias_utm))
      idx_min_v <- which.min(dists_v)
      min_dist_v <- dists_v[idx_min_v]
      
      sis_vial_txt <- "No colindante / No identificado"
      cod_via_txt <- "N/A"
      seccion_vial_txt <- "No especificada"
      dist_v_txt <- "N/A"
      
      if (length(min_dist_v) > 0 && min_dist_v <= 25) {
        sis_vial_txt <- capas$vias$SIS_VIAL[idx_min_v]
        cod_via_txt <- capas$vias$COD_VIA_PR[idx_min_v]
        seccion_vial_txt <- capas$vias$SECCION_VI[idx_min_v]
        dist_v_txt <- paste0(round(min_dist_v, 3), " m")
      }
      
      idx_zonif_punto <- st_intersects(pt_sf, capas$zonificacion)[[1]]
      zonificacion_ambigua <- length(idx_zonif_punto) > 1
      if (length(idx_zonif_punto) > 0) {
        zonif_match <- capas$zonificacion[idx_zonif_punto[1], ]
        cod_zona <- zonif_match$COD_ZONA[1]
        cod_s_zona <- zonif_match$COD_S_ZONA[1]
        sub_zona <- zonif_match$SUB_ZONA[1]
      } else {
        cod_zona <- cod_s_zona <- sub_zona <- NA_character_
      }
      
      p_norm <- NULL
      if (!is.na(cod_s_zona) && cod_s_zona != "") {
        m_idx <- which(trimws(df_parametros$COD_S_ZONA) == trimws(cod_s_zona))
        if (length(m_idx) > 0) p_norm <- df_parametros[m_idx[1], ]
      }
      
      mapa_img_uri <- generar_mapa_certificado(pt_sf, es_poligono = FALSE)
      
      doc_html <- tags$html(
        tags$head(
          tags$meta(charset = "utf-8"),
          tags$title("Reporte Informativo de Parámetros Urbanísticos - PDU Anta"),
          tags$style(HTML(css_certificado))
        ),
        tags$body(
          div(
            class = "cert-card",
            
            # --- PÁGINA 1: HOJA DEL PLANO CARTOGRÁFICO OFICIAL ---
            div(
              class = "header-banner",
              tags$table(
                style = "width:100%; color:white; border:none; margin-bottom:0;",
                tags$tr(
                  tags$td(
                    style = "width:70px; vertical-align:middle; border:none; padding:0;",
                    if (escudo_b64 != "") tags$img(src = escudo_b64, style = "height:58px; background:white; padding:2px; border-radius:4px;", alt = "Escudo Anta")
                  ),
                  tags$td(
                    style = "vertical-align:middle; padding-left:14px; border:none;",
                    tags$div(class = "header-title", "MUNICIPALIDAD PROVINCIAL DE ANTA"),
                    tags$div(class = "header-subtitle", "REPORTE INFORMATIVO — PDU ANTA 2024 - 2034"),
                    tags$div(class = "header-meta", paste("Consulta generada el:", format(Sys.time(), "%d/%m/%Y a las %H:%M horas")))
                  ),
                  tags$td(
                    style = "width:80px; text-align:right; vertical-align:middle; border:none; padding:0;",
                    if (logo_pdu_b64 != "") tags$img(src = logo_pdu_b64, style = "height:54px; background:white; padding:2px; border-radius:4px;", alt = "Logo PDU")
                  )
                )
              )
            ),
            
            div(
              class = "project-box",
              tags$b("Proyecto: "), tags$span(paste0("«", PROYECTO_NOMBRE_OFICIAL, "»")), tags$br(),
              tags$b("Instrumento de Gestión: "), tags$span(INSTRUMENTO_GESTION_OFICIAL)
            ),
            
            if (!is.null(mapa_img_uri)) {
              div(
                tags$div(class = "section-heading", "PLANO DE UBICACIÓN Y ZONIFICACIÓN TERRITORIAL (PÁGINA COMPLETA)"),
                tags$img(src = mapa_img_uri, class = "mapa-img-fullpage")
              )
            },
            
            # --- SALTO A PÁGINA 2: DATOS Y PARÁMETROS NORMATIVOS ---
            div(class = "page-break"),
            
            tags$div(class = "section-heading", "1. DATOS DE LOCALIZACIÓN Y COORDENADAS"),
            tags$table(
              class = "table-cert table-compact mb-2",
              tags$tbody(
                tags$tr(tags$th("Distrito:"), tags$td(tags$b(distrito_nombre), " (Provincia de Anta, Cusco)")),
                tags$tr(tags$th("Ámbito Reglamentado PDU:"), tags$td(if (en_ambito) tags$b(style = "color:#008800;", "SÍ (Dentro del Ámbito PDU Anta)") else tags$b(style = "color:#D80808;", "NO (Fuera de Ámbito)"))),
                tags$tr(tags$th("Coordenadas UTM 18S:"), tags$td(paste0("Este (X): ", round(pt_data$este, 3), " m | Norte (Y): ", round(pt_data$norte, 3), " m"))),
                tags$tr(tags$th("Coordenadas WGS84:"), tags$td(paste0("Lat: ", round(pt_data$lat, 4), "° | Lng: ", round(pt_data$lng, 4), "°")))
              )
            ),
            
            tags$div(class = "section-heading", "2. SISTEMA VIAL PROPUESTO Y SECCIÓN VIAL (SV)"),
            tags$table(
              class = "table-cert mb-1",
              tags$thead(
                tags$tr(tags$th("Jerarquía Vial"), tags$th("Código de Vía"), tags$th("Sección Normativa (SV)"), tags$th("Distancia al Punto"))
              ),
              tags$tbody(
                tags$tr(
                  tags$td(tags$b(sis_vial_txt)),
                  tags$td(cod_via_txt),
                  tags$td(tags$span(class = "badge-vial", seccion_vial_txt)),
                  tags$td(dist_v_txt)
                )
              )
            ),
            tags$div(
              class = "methodology-note",
              "Nota Metodológica: Las vías del Sistema Vial Propuesto mostradas corresponden a los ejes normativos identificados dentro de un área de influencia directa (buffer de 25 metros) respecto al punto o predio consultado."
            ),
            
            tags$div(class = "section-heading", "3. ZONIFICACIÓN Y PARÁMETROS URBANÍSTICOS"),
            tags$table(
              class = "table-cert mb-2",
              tags$tbody(
                tags$tr(tags$th("Zonificación:"), tags$td(tags$b(paste(cod_s_zona, "-", cod_zona)), " (", sub_zona, ")")),
                tags$tr(tags$th("Densidad Neta Máxima:"), tags$td(if (!is.null(p_norm)) p_norm$DENSIDAD_NETA_MAX else "N/A")),
                tags$tr(tags$th("Lote Mínimo:"), tags$td(if (!is.null(p_norm)) p_norm$LOTE_MINIMO else "N/A")),
                tags$tr(tags$th("Frente Mínimo:"), tags$td(if (!is.null(p_norm)) p_norm$FRENTE_MINIMO else "N/A")),
                tags$tr(tags$th("Altura Máxima:"), tags$td(tags$b(style = "color:#006633;", if (!is.null(p_norm)) p_norm$ALTURA_MAXIMA else "N/A"))),
                tags$tr(tags$th("Área Libre:"), tags$td(if (!is.null(p_norm)) p_norm$AREA_LIBRE_MIN else "N/A")),
                tags$tr(tags$th("Retiro Frontal:"), tags$td(if (!is.null(p_norm)) p_norm$RETIRO_FRONTAL else "N/A")),
                tags$tr(tags$th("Estado de Validación:"), tags$td(if (!is.null(p_norm)) p_norm$ESTADO_VALIDACION else "N/A")),
                tags$tr(tags$th("Usos Permitidos:"), tags$td(tags$small(if (!is.null(p_norm)) p_norm$USOS_PERMITIDOS else "N/A")))
              )
            ),
            
            tags$div(class = "section-heading", "4. AFECTACIONES DE INFRAESTRUCTURA"),
            tags$ul(
              class = "cert-list",
              tags$li(if (en_serv_at) tags$b(class = "text-danger", "⚠️ AFECTACIÓN POR FAJA DE SERVIDUMBRE DE ALTA TENSIÓN (CNE). Prohibida edificación.") else "✓ Sin afectación por fajas de alta tensión."),
              tags$li(if (en_serv_ffcc) tags$b(class = "text-warning", "⚠️ PROXIMIDAD FERROVIARIA REFERENCIAL. Verificar el derecho de vía con el MTC y el concesionario.") else "✓ Sin proximidad al área ferroviaria referencial.")
            ),
            
            tags$div(class = "legal-note", CARACTER_INFORMATIVO)
          )
        )
      )
      
    } else {
      # CERTIFICADO COMPLETO DE PREDIO CON ZONIFICACIÓN MÚLTIPLE, VÍAS Y MAPA
      poly_data <- poligono_actual()
      mapa_img_uri <- generar_mapa_certificado(poly_data$poly_4326, es_poligono = TRUE)
      
      doc_html <- tags$html(
        tags$head(
          tags$meta(charset = "utf-8"),
          tags$title("Reporte Informativo de Zonificación de Predio - PDU Anta"),
          tags$style(HTML(css_certificado))
        ),
        tags$body(
          div(
            class = "cert-card",
            
            # --- PÁGINA 1: HOJA DEL PLANO CARTOGRÁFICO OFICIAL A PÁGINA COMPLETA ---
            div(
              class = "header-banner",
              tags$table(
                style = "width:100%; color:white; border:none; margin-bottom:0;",
                tags$tr(
                  tags$td(
                    style = "width:70px; vertical-align:middle; border:none; padding:0;",
                    if (escudo_b64 != "") tags$img(src = escudo_b64, style = "height:58px; background:white; padding:2px; border-radius:4px;", alt = "Escudo Anta")
                  ),
                  tags$td(
                    style = "vertical-align:middle; padding-left:14px; border:none;",
                    tags$div(class = "header-title", "MUNICIPALIDAD PROVINCIAL DE ANTA"),
                    tags$div(class = "header-subtitle", "REPORTE INFORMATIVO DE PARÁMETROS URBANÍSTICOS Y ZONIFICACIÓN"),
                    tags$div(class = "header-meta", paste("Consulta generada el:", format(Sys.time(), "%d/%m/%Y a las %H:%M horas")))
                  ),
                  tags$td(
                    style = "width:80px; text-align:right; vertical-align:middle; border:none; padding:0;",
                    if (logo_pdu_b64 != "") tags$img(src = logo_pdu_b64, style = "height:54px; background:white; padding:2px; border-radius:4px;", alt = "Logo PDU")
                  )
                )
              )
            ),
            
            div(
              class = "project-box",
              tags$b("Proyecto: "), tags$span(paste0("«", PROYECTO_NOMBRE_OFICIAL, "»")), tags$br(),
              tags$b("Instrumento de Gestión: "), tags$span(INSTRUMENTO_GESTION_OFICIAL)
            ),
            
            # Resumen compacto de identificación del predio en cabecera de plano
            tags$table(
              class = "table-cert table-compact mb-2",
              tags$tbody(
                tags$tr(
                  tags$th(style = "width:20%;", "Área del Predio:"),
                  tags$td(tags$b(paste0(poly_data$area_m2, " m² (", poly_data$area_has, " ha)"))),
                  tags$th(style = "width:20%;", "Perímetro Total:"),
                  tags$td(paste0(poly_data$perimetro_m, " ml"))
                ),
                tags$tr(
                  tags$th("Distrito(s):"),
                  tags$td(paste(poly_data$distritos, collapse = ", ")),
                  tags$th("Ámbito PDU Anta:"),
                  tags$td(paste0(poly_data$pct_en_ambito, "% en ámbito"))
                )
              )
            ),
            
            if (!is.null(mapa_img_uri)) {
              div(
                tags$div(class = "section-heading", "PLANO DE UBICACIÓN Y ZONIFICACIÓN DEL PREDIO (PÁGINA COMPLETA)"),
                tags$img(src = mapa_img_uri, class = "mapa-img-fullpage")
              )
            },
            
            # --- SALTO DE PÁGINA LIMPIO PARA PÁGINA 2 ---
            div(class = "page-break"),
            
            # --- PÁGINA 2: CERTIFICADO INFORMATIVO NORMATIVO ---
            tags$div(class = "section-heading", "1. DATOS MÉTRICOS DEL PREDIO Y ÁMBITO PDU"),
            tags$table(
              class = "table-cert table-compact mb-2",
              tags$tbody(
                tags$tr(tags$th("Área Total del Predio:"), tags$td(tags$b(paste0(poly_data$area_m2, " m² (", poly_data$area_has, " ha)")))),
                tags$tr(tags$th("Perímetro Total:"), tags$td(paste0(poly_data$perimetro_m, " ml"))),
                tags$tr(tags$th("Distrito(s) Administrativo(s):"), tags$td(paste(poly_data$distritos, collapse = ", "))),
                tags$tr(tags$th("Ámbito Reglamentado PDU:"), tags$td(paste0(poly_data$pct_en_ambito, "% dentro del área PDU Anta")))
              )
            ),
            
            tags$div(class = "section-heading", "2. SISTEMA VIAL PROPUESTO Y SECCIÓN VIAL (SV)"),
            if (nrow(poly_data$tabla_vias_predio) > 0) {
              tags$table(
                class = "table-cert mb-1",
                tags$thead(
                  tags$tr(tags$th("Jerarquía Vial"), tags$th("Código de Vía"), tags$th("Sección Normativa (SV)"), tags$th("Distancia al Predio"))
                ),
                tags$tbody(
                  lapply(1:nrow(poly_data$tabla_vias_predio), function(i) {
                    r_v <- poly_data$tabla_vias_predio[i, ]
                    tags$tr(
                      tags$td(tags$b(r_v$SIS_VIAL)),
                      tags$td(r_v$COD_VIA_PR),
                      tags$td(tags$span(class = "badge-vial", r_v$SECCION_VI)),
                      tags$td(paste0(r_v$DISTANCIA_M, " m"))
                    )
                  })
                )
              )
            } else {
              tags$p(class = "text-muted small mb-1", "No se registran vías propuestas del PDU dentro del área de influencia directa (buffer de 25 metros) del predio.")
            },
            tags$div(
              class = "methodology-note",
              "Nota Metodológica: Las vías del Sistema Vial Propuesto mostradas corresponden a los ejes normativos identificados dentro de un área de influencia directa (buffer de 25 metros) respecto al perímetro del predio o punto consultado."
            ),
            
            tags$div(class = "section-heading", "3. DESGLOSE DE ZONIFICACIÓN EN EL LOTE"),
            tags$table(
              class = "table-cert mb-2",
              tags$thead(
                tags$tr(tags$th("Zona"), tags$th("Subzona / Descripción"), tags$th("Área Ocupada (m²)"), tags$th("% del Lote"))
              ),
              tags$tbody(
                if (nrow(poly_data$tabla_zonif) > 0) {
                  lapply(1:nrow(poly_data$tabla_zonif), function(i) {
                    r <- poly_data$tabla_zonif[i, ]
                    tags$tr(
                      tags$td(tags$b(r$COD_ZONA)),
                      tags$td(paste(r$COD_S_ZONA, "-", r$SUB_ZONA)),
                      tags$td(paste0(r$AREA_M2, " m²")),
                      tags$td(tags$b(paste0(r$PCT_LOTE, "%")))
                    )
                  })
                } else {
                  tags$tr(tags$td(colspan = 4, "Predio sin zonificación reglamentada asignada."))
                }
              )
            ),
            
            tags$div(class = "section-heading", "4. AFECTACIONES POR INFRAESTRUCTURA"),
            tags$ul(
              class = "cert-list",
              tags$li(if (poly_data$pct_at > 0) tags$b(class = "text-danger", paste0("⚠️ Servidumbre Alta Tensión: ", poly_data$area_at_m2, " m² (", poly_data$pct_at, "% del predio).")) else "✓ Sin afectación por fajas de alta tensión."),
              tags$li(if (poly_data$pct_ffcc > 0) tags$b(class = "text-warning", paste0("⚠️ Área ferroviaria referencial: ", poly_data$area_ffcc_m2, " m² (", poly_data$pct_ffcc, "% del predio). Requiere verificación sectorial.")) else "✓ Sin proximidad al área ferroviaria referencial.")
            ),
            
            tags$div(class = "section-heading", "5. PARÁMETROS URBANÍSTICOS POR ZONA"),
            if (length(poly_data$lista_parametros_zonas) > 0) {
              lapply(poly_data$lista_parametros_zonas, function(p_row) {
                div(
                  class = "sub-card-param avoid-break",
                  div(
                    class = "sub-card-header",
                    tags$span(class = "badge bg-success me-2", style = "background-color: #008800 !important; font-size:0.75rem;", p_row$COD_S_ZONA),
                    p_row$NOMBRE_COMPLETO,
                    tags$span(class = "text-muted small ms-2", paste0("— Ocupa: ", p_row$AREA_AFECTADA_M2, " m² (", p_row$PCT_AFECTADO, "% del lote)"))
                  ),
                  tags$table(
                    class = "table-cert mb-0",
                    tags$tbody(
                      tags$tr(tags$th("Densidad Neta Máxima:"), tags$td(p_row$DENSIDAD_NETA_MAX)),
                      tags$tr(tags$th("Lote Normativo Mínimo:"), tags$td(p_row$LOTE_MINIMO)),
                      tags$tr(tags$th("Frente Mínimo:"), tags$td(p_row$FRENTE_MINIMO)),
                      tags$tr(tags$th("Altura Máxima de Edificación:"), tags$td(tags$b(style = "color:#006633;", p_row$ALTURA_MAXIMA))),
                      tags$tr(tags$th("Área Libre Mínima (%):"), tags$td(p_row$AREA_LIBRE_MIN)),
                      tags$tr(tags$th("Coeficiente de Edificación:"), tags$td(p_row$COEFICIENTE_EDIF)),
                      tags$tr(tags$th("Retiro Frontal Obligatorio:"), tags$td(p_row$RETIRO_FRONTAL)),
                      tags$tr(tags$th("Estado de Validación:"), tags$td(tags$b(style = "color:#B88808;", p_row$ESTADO_VALIDACION))),
                      tags$tr(tags$th("Usos Permitidos y Compatibles:"), tags$td(tags$small(p_row$USOS_PERMITIDOS)))
                    )
                  )
                )
              })
            } else {
              div(class = "alert alert-warning small", "No se registran parámetros normativos aplicables.")
            },
            
            tags$div(class = "legal-note", CARACTER_INFORMATIVO)
          )
        )
      )
    }
    
    return(doc_html)
  }
  
  # Función centralizada para generar la Constancia Informativa en PDF (Typst / Chrome)
  generar_constancia_pdf <- function(destino_file) {
    modo <- modo_activo()
    if (modo == "punto" && is.null(punto_actual())) stop("No hay datos de consulta puntual activa.")
    if (modo == "poligono" && is.null(poligono_actual())) stop("No hay datos de consulta por predio activa.")
    
    dir.create("outputs", showWarnings = FALSE)
    temp_id <- paste0("constancia_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))
    mapa_png_rel <- file.path("outputs", paste0("mapa_", temp_id, ".png"))
    on.exit({
      if (file.exists(mapa_png_rel)) unlink(mapa_png_rel)
    }, add = TRUE)
    
    if (modo == "punto") {
      pt_data <- punto_actual()
      pt_sf <- st_sf(geometry = pt_data$geom_4326)
      en_ambito <- any(st_intersects(pt_sf, capas$ambito, sparse = FALSE)[1, ])
      dist_match <- st_join(pt_sf, capas$distritos, join = st_intersects)$NOMBDIST[1]
      distrito_nombre <- if (!is.na(dist_match)) dist_match else "Fuera de la provincia"
      en_serv_at <- any(st_intersects(pt_sf, capas$alta_tension_buffer, sparse = FALSE)[1, ])
      en_serv_ffcc <- any(st_intersects(pt_sf, capas$ferrocarril_buffer, sparse = FALSE)[1, ])
      
      vias_utm <- st_transform(capas$vias, 32718)
      dists_v <- as.numeric(st_distance(pt_data$geom_utm, vias_utm))
      idx_min_v <- which.min(dists_v)
      min_dist_v <- dists_v[idx_min_v]
      
      tabla_vias <- data.frame(
        SIS_VIAL = character(), COD_VIA_PR = character(),
        SECCION_VI = character(), DISTANCIA_M = numeric(), stringsAsFactors = FALSE
      )
      if (length(min_dist_v) > 0 && min_dist_v <= 25) {
        tabla_vias <- data.frame(
          SIS_VIAL = capas$vias$SIS_VIAL[idx_min_v],
          COD_VIA_PR = capas$vias$COD_VIA_PR[idx_min_v],
          SECCION_VI = capas$vias$SECCION_VI[idx_min_v],
          DISTANCIA_M = round(min_dist_v, 3),
          stringsAsFactors = FALSE
        )
      }
      
      idx_zonif_punto <- st_intersects(pt_sf, capas$zonificacion)[[1]]
      if (length(idx_zonif_punto) > 0) {
        zonif_match <- capas$zonificacion[idx_zonif_punto[1], ]
        cod_zona <- zonif_match$COD_ZONA[1]
        cod_s_zona <- zonif_match$COD_S_ZONA[1]
        sub_zona <- zonif_match$SUB_ZONA[1]
      } else {
        cod_zona <- cod_s_zona <- sub_zona <- NA_character_
      }
      
      lista_parametros <- list()
      if (!is.na(cod_s_zona) && cod_s_zona != "") {
        m_idx <- which(trimws(df_parametros$COD_S_ZONA) == trimws(cod_s_zona))
        if (length(m_idx) > 0) {
          lista_parametros[[1]] <- df_parametros[m_idx[1], ]
        }
      }
      
      tabla_zonif <- data.frame()
      if (!is.na(cod_zona)) {
        tabla_zonif <- data.frame(
          COD_ZONA = cod_zona,
          COD_S_ZONA = cod_s_zona,
          SUB_ZONA = sub_zona,
          AREA_M2 = 0,
          PCT_LOTE = 100,
          stringsAsFactors = FALSE
        )
      }
      
      generar_mapa_certificado(pt_sf, es_poligono = FALSE, ruta_salida_png = mapa_png_rel)
      
      payload <- list(
        codigo_consulta = paste0("PDU-ANTA-", format(Sys.time(), "%Y%m%d%H%M")),
        fecha_hora = format(Sys.time(), "%d/%m/%Y %H:%M"),
        distrito = distrito_nombre,
        ambito_pdu = if (en_ambito) "SÍ (Dentro del Ámbito PDU Anta)" else "NO (Fuera de Ámbito)",
        es_poligono = FALSE,
        coords_utm = paste0("E: ", round(pt_data$este, 2), " m | N: ", round(pt_data$norte, 2), " m (Zona 18S)"),
        coords_geo = paste0("Lat: ", round(pt_data$lat, 5), "° | Lng: ", round(pt_data$lng, 5), "° (WGS84)"),
        area_m2 = "N/A (Consulta Puntual)",
        area_has = "N/A",
        perimetro_m = "N/A",
        pct_en_ambito = if (en_ambito) "100" else "0",
        servidumbre_at = if (en_serv_at) "⚠️ Afectación por faja de alta tensión (CNE)" else "No",
        servidumbre_ffcc = if (en_serv_ffcc) "⚠️ Proximidad al eje ferroviario referencial (MTC)" else "No",
        tabla_zonif = tabla_zonif,
        tabla_vias = tabla_vias,
        lista_parametros = lista_parametros,
        mapa_path = mapa_png_rel,
        escudo_path = "www/escudo_muni_anta.png",
        logo_pdu_path = "www/pdu_actualizado_sf.png"
      )
      
    } else {
      poly_data <- poligono_actual()
      generar_mapa_certificado(poly_data$poly_4326, es_poligono = TRUE, ruta_salida_png = mapa_png_rel)
      
      payload <- list(
        codigo_consulta = paste0("PDU-ANTA-", format(Sys.time(), "%Y%m%d%H%M")),
        fecha_hora = format(Sys.time(), "%d/%m/%Y %H:%M"),
        distrito = paste(poly_data$distritos, collapse = ", "),
        ambito_pdu = paste0(poly_data$pct_en_ambito, "% dentro del ámbito PDU"),
        es_poligono = TRUE,
        coords_utm = "Polígono catastral delimitado en coordenadas UTM 18S",
        coords_geo = "Polígono catastral delimitado en coordenadas WGS84",
        area_m2 = format(poly_data$area_m2, big.mark = ","),
        area_has = format(poly_data$area_has, big.mark = ","),
        perimetro_m = format(poly_data$perimetro_m, big.mark = ","),
        pct_en_ambito = as.character(poly_data$pct_en_ambito),
        servidumbre_at = if (poly_data$pct_at > 0) paste0(poly_data$area_at_m2, " m² (", poly_data$pct_at, "% del predio)") else "No",
        servidumbre_ffcc = if (poly_data$pct_ffcc > 0) paste0(poly_data$area_ffcc_m2, " m² (", poly_data$pct_ffcc, "% del predio)") else "No",
        tabla_zonif = poly_data$tabla_zonif,
        tabla_vias = poly_data$tabla_vias_predio,
        lista_parametros = poly_data$lista_parametros_zonas,
        mapa_path = mapa_png_rel,
        escudo_path = "www/escudo_muni_anta.png",
        logo_pdu_path = "www/pdu_actualizado_sf.png"
      )
    }
    
    # 1. Renderizado principal con Quarto + Typst
    if (quarto_disponible()) {
      temp_rds <- tempfile(fileext = ".rds")
      temp_pdf_out <- tempfile(fileext = ".pdf")
      on.exit({
        if (file.exists(temp_rds)) unlink(temp_rds)
        if (file.exists(temp_pdf_out)) unlink(temp_pdf_out)
      }, add = TRUE)
      
      saveRDS(payload, temp_rds)
      
      render_ok <- FALSE
      
      # Opción A: A través del paquete R quarto
      if (requireNamespace("quarto", quietly = TRUE)) {
        tryCatch({
          quarto::quarto_render(
            input = "constancia_pdu_template.qmd",
            output_file = basename(temp_pdf_out),
            execute_params = list(data_rds = temp_rds),
            output_format = "typst",
            quiet = TRUE
          )
          render_ok <- TRUE
        }, error = function(e) {
          render_ok <- FALSE
        })
      }
      
      # Opción B: A través del CLI directo de Quarto del sistema
      if (!render_ok && nzchar(Sys.which("quarto"))) {
        tryCatch({
          system2(
            "quarto",
            args = c(
              "render", "constancia_pdu_template.qmd",
              "--to", "typst",
              "--output", basename(temp_pdf_out),
              "-P", paste0("data_rds:", temp_rds)
            ),
            stdout = FALSE, stderr = FALSE
          )
        }, error = function(e) NULL)
      }
      
      generado <- file.path(dirname("constancia_pdu_template.qmd"), basename(temp_pdf_out))
      if (!file.exists(generado) && file.exists(temp_pdf_out)) generado <- temp_pdf_out
      
      if (file.exists(generado) && file.info(generado)$size > 100) {
        file.copy(generado, destino_file, overwrite = TRUE)
        unlink(generado)
        return(invisible(destino_file))
      }
    }
    
    # 2. Fallback con Chrome / pagedown si Quarto no estuviera instalado
    if (chrome_disponible()) {
      temp_html <- tempfile(fileext = ".html")
      on.exit(unlink(temp_html), add = TRUE)
      doc_html <- generar_html_certificado()
      save_html(doc_html, file = temp_html)
      pagedown::chrome_print(
        input = temp_html,
        output = destino_file,
        extra_args = c("--no-sandbox", "--disable-gpu", "--allow-file-access-from-files")
      )
      if (file.exists(destino_file) && file.info(destino_file)$size >= 5) {
        return(invisible(destino_file))
      }
    }
    
    stop("No fue posible generar la constancia en PDF.")
  }
  
  # Descarga PDF Oficial (Botón en el panel lateral)
  output$btn_descargar_pdf <- downloadHandler(
    filename = function() {
      paste0("Constancia_Informativa_PDU_Anta_", format(Sys.time(), "%Y%m%d_%H%M"), ".pdf")
    },
    content = function(file) {
      generar_constancia_pdf(file)
      metricas_supa(supabase_registrar_constancia())
    }
  )

  output$btn_descargar_pdf_tab <- downloadHandler(
    filename = function() {
      paste0("Constancia_Informativa_PDU_Anta_", format(Sys.time(), "%Y%m%d_%H%M"), ".pdf")
    },
    content = function(file) {
      generar_constancia_pdf(file)
      metricas_supa(supabase_registrar_constancia())
    }
  )
  
  # ----------------------------------------------------------------------------
  # 2.7 MÓDULO REACTIVO SUPABASE, BUZÓN CIUDADANO Y CATÁLOGO DINÁMICO
  # ----------------------------------------------------------------------------
  
  # Contadores públicos persistentes. La visita se deduplica en Supabase por
  # navegador y día; no se almacena IP ni información personal.
  metricas_supa <- reactiveVal(supabase_obtener_metricas())

  observeEvent(input$visitante_geovisor_id, {
    visitante_id <- trimws(as.character(input$visitante_geovisor_id))
    if (nzchar(visitante_id)) {
      metricas_supa(supabase_registrar_visita(visitante_id))
    }
  }, once = TRUE, ignoreInit = FALSE)

  output$ui_metricas_publicas <- renderUI({
    metricas <- metricas_supa()
    if (is.null(metricas) || is.na(metricas$visitas_total)) return(NULL)

    tagList(
      span(
        class = "badge bg-light text-dark border d-none d-lg-inline-flex align-items-center gap-1",
        title = "Visitas únicas aproximadas por navegador y día",
        icon("eye"), format(metricas$visitas_total, big.mark = ",", scientific = FALSE), " visitas"
      ),
      span(
        class = "badge bg-light text-dark border d-none d-lg-inline-flex align-items-center gap-1",
        title = "Constancias informativas generadas",
        icon("file-pdf"), format(metricas$constancias_total, big.mark = ",", scientific = FALSE), " constancias"
      )
    )
  })

  # Estado de Supabase en memoria reactiva
  estado_supa <- reactive({
    supabase_ping()
  })
  
  # Indicador de estado en el Navbar superior
  output$ui_status_supabase_pill <- renderUI({
    info <- estado_supa()
    if (isTRUE(info$conectado)) {
      span(
        class = "status-pill-cloud status-pill-online d-none d-md-inline-flex",
        title = paste("Infraestructura Cloud activa vía", toupper(info$modo), paste0("(", info$latencia_ms, " ms)")),
        icon("database"), paste0("Cloud DB Activa (", toupper(info$modo), ")")
      )
    } else {
      span(
        class = "status-pill-cloud status-pill-offline d-none d-md-inline-flex",
        title = "Las capas PostGIS fueron cargadas al iniciar; el servicio auxiliar de métricas no responde.",
        icon("triangle-exclamation"), "PostGIS cargado / métricas sin conexión"
      )
    }
  })
  
  # Tarjeta de diagnóstico de Supabase en la pestaña de Buzón
  output$ui_card_estado_supabase <- renderUI({
    info <- estado_supa()
    modo_txt <- if (info$modo == "postgres") "PostgreSQL Directo (PostGIS)" else if (info$modo == "rest") "REST API (PostgREST)" else "Modo Autónomo Local"
    
    tagList(
      div(
        class = "d-flex justify-content-between align-items-center py-1 border-bottom",
        span(class = "text-muted small", "Conectividad Cloud:"),
        if (isTRUE(info$conectado)) span(class = "badge bg-success", "🟢 En línea") else span(class = "badge bg-secondary", "⚪ Local")
      ),
      div(
        class = "d-flex justify-content-between align-items-center py-1 border-bottom",
        span(class = "text-muted small", "Protocolo de datos:"),
        span(class = "fw-bold small", modo_txt)
      ),
      if (!is.na(info$latencia_ms)) div(
        class = "d-flex justify-content-between align-items-center py-1 border-bottom",
        span(class = "text-muted small", "Latencia de red:"),
        span(class = "badge bg-light text-dark", paste0(info$latencia_ms, " ms"))
      ),
      div(
        class = "d-flex justify-content-between align-items-center py-1",
        span(class = "text-muted small", "Entorno Posit Connect:"),
        tags$a(
          href = "https://connect.posit.cloud/patantampa",
          target = "_blank",
          class = "small fw-bold text-success text-decoration-none",
          "connect.posit.cloud/patantampa ↗"
        )
      )
    )
  })
  
  # Avisos Municipales traídos en tiempo real de Supabase
  output$ui_lista_avisos_municipales <- renderUI({
    df_av <- tryCatch(supabase_obtener_avisos(limite = 4), error = function(e) data.frame())
    
    if (nrow(df_av) == 0) {
      return(
        div(
          class = "p-3 bg-light rounded-3 text-muted small",
          icon("info-circle"), " El PDU Anta 2024-2034 fue aprobado formalmente el 04 de abril del 2025 y se encuentra vigente para trámites de habilitación urbana y licencias de edificación."
        )
      )
    }
    
    tagList(
      lapply(1:nrow(df_av), function(i) {
        av <- df_av[i, ]
        col_border <- if (av$nivel == "warning") "#D97706" else if (av$nivel == "success") "#059669" else "#1B4D3E"
        bg_card <- if (av$nivel == "warning") "#FFFBEB" else if (av$nivel == "success") "#ECFDF5" else "#F8FAFC"
        
        div(
          class = "p-3 mb-2 rounded-2 border",
          style = paste0("background-color:", bg_card, "; border-left: 4px solid ", col_border, " !important;"),
          div(class = "fw-bold small", style = paste0("color:", col_border, ";"), av$titulo),
          p(class = "mb-1 small text-dark", av$contenido),
          if ("creado_en" %in% names(av)) tags$small(class = "text-muted", paste("Publicado:", substr(as.character(av$creado_en), 1, 10)))
        )
      })
    )
  })
  
  # Auto-llenar coordenadas en el formulario de Buzón
  observeEvent(input$btn_autollenar_ubicacion_buzon, {
    modo <- modo_activo()
    if (modo == "punto" && !is.null(punto_actual())) {
      pt <- punto_actual()
      updateTextInput(session, "in_buzon_ubicacion",
                      value = paste0("Punto UTM: Este ", pt$este, ", Norte ", pt$norte, " (Zona 18S)"))
      showNotification("Ubicación cargada desde la consulta puntual.", type = "message", duration = 3)
    } else if (modo == "poligono" && !is.null(poligono_actual())) {
      poly <- poligono_actual()
      updateTextInput(session, "in_buzon_ubicacion",
                      value = paste0("Polígono de ", poly$area_m2, " m² en ", paste(poly$distritos, collapse = ", ")))
      showNotification("Ubicación cargada desde el polígono consultado.", type = "message", duration = 3)
    } else {
      showNotification("Primero realice una consulta en el mapa para auto-llenar las coordenadas.", type = "warning", duration = 4)
    }
  })
  
  # Envío de reporte u observación ciudadana a Supabase
  feedback_msg <- reactiveVal(NULL)
  
  observeEvent(input$btn_enviar_buzon, {
    nombre <- trimws(input$in_buzon_nombre)
    contacto <- trimws(input$in_buzon_contacto)
    tipo <- input$in_buzon_tipo
    ubicacion <- trimws(input$in_buzon_ubicacion)
    mensaje <- trimws(input$in_buzon_mensaje)
    
    if (!nzchar(nombre)) {
      feedback_msg(list(tipo = "error", texto = "Por favor ingrese sus nombres y apellidos."))
      return()
    }
    if (!nzchar(contacto)) {
      feedback_msg(list(tipo = "error", texto = "Por favor ingrese un correo o teléfono de contacto."))
      return()
    }
    if (!nzchar(mensaje) || nchar(mensaje) < 10) {
      feedback_msg(list(tipo = "error", texto = "El mensaje debe contener una descripción de al menos 10 caracteres."))
      return()
    }
    
    withProgress(message = "Enviando a la base de datos Supabase...", value = 0.5, {
      res <- supabase_enviar_reporte_ciudadano(
        nombre_ciudadano = nombre,
        contacto = contacto,
        tipo_observacion = tipo,
        ubicacion_predio = if (nzchar(ubicacion)) ubicacion else "No especificada",
        mensaje = mensaje
      )
      
      if (isTRUE(res$ok)) {
        cod_ticket <- paste0("PDU-OBS-", format(Sys.time(), "%y%m%d%H%M"))
        feedback_msg(list(
          tipo = "success",
          texto = paste0("¡Observación registrada con éxito! Código de seguimiento asignado: ", cod_ticket, ". La Gerencia de Desarrollo Urbano revisará su reporte.")
        ))
        updateTextInput(session, "in_buzon_nombre", value = "")
        updateTextInput(session, "in_buzon_contacto", value = "")
        updateTextInput(session, "in_buzon_ubicacion", value = "")
        updateTextAreaInput(session, "in_buzon_mensaje", value = "")
        showNotification("Observación enviada exitosamente a Supabase.", type = "message", duration = 5)
      } else {
        feedback_msg(list(
          tipo = "error",
          texto = paste("Error al registrar en la nube:", res$error)
        ))
      }
    })
  })
  
  output$ui_feedback_buzon <- renderUI({
    fb <- feedback_msg()
    if (is.null(fb)) return(NULL)
    
    clase <- if (fb$tipo == "success") "alert alert-success" else "alert alert-danger"
    icono <- if (fb$tipo == "success") "circle-check" else "triangle-exclamation"
    div(
      class = paste(clase, "py-2 px-3 small mt-2"),
      icon(icono), " ", fb$texto
    )
  })
  
  # Catálogo normativo dinámico con filtro de búsqueda
  output$ui_tabla_catalogo_dinamica <- renderUI({
    busqueda <- trimws(tolower(input$txt_buscar_catalogo %||% ""))
    df_mostrar <- df_parametros
    
    if (nzchar(busqueda)) {
      match_cod <- grepl(busqueda, tolower(df_mostrar$COD_S_ZONA))
      match_nom <- grepl(busqueda, tolower(df_mostrar$NOMBRE_COMPLETO))
      match_uso <- grepl(busqueda, tolower(df_mostrar$USOS_PERMITIDOS))
      df_mostrar <- df_mostrar[match_cod | match_nom | match_uso, ]
    }
    
    if (nrow(df_mostrar) == 0) {
      return(
        div(
          class = "p-4 text-center text-muted",
          icon("magnifying-glass", class = "fs-2 mb-2 d-block"),
          "No se encontraron tipologías de zonificación que coincidan con la búsqueda."
        )
      )
    }
    
    tags$table(
      class = "table table-hover align-middle catalogo-table",
      tags$thead(
        tags$tr(
          tags$th("Código"),
          tags$th("Subzona"),
          tags$th("Densidad Máx."),
          tags$th("Lote Mín."),
          tags$th("Frente Mín."),
          tags$th("Altura Máx."),
          tags$th("Área Libre"),
          tags$th("Validación"),
          tags$th("Usos Permitidos Principales")
        )
      ),
      tags$tbody(
        lapply(1:nrow(df_mostrar), function(i) {
          row <- df_mostrar[i, ]
          color <- colores_subzonas[row$COD_S_ZONA]
          if (is.na(color)) color <- colores_zonas[row$COD_ZONA]
          if (is.na(color)) color <- "#BCBDBE"
          tags$tr(
            tags$td(tags$span(class = "badge text-dark fw-bold", style = paste0("background-color:", color, "; font-size: 0.9em; border: 1px solid rgba(0,0,0,0.15);"), row$COD_S_ZONA)),
            tags$td(tags$b(row$NOMBRE_COMPLETO)),
            tags$td(row$DENSIDAD_NETA_MAX),
            tags$td(row$LOTE_MINIMO),
            tags$td(row$FRENTE_MINIMO),
            tags$td(tags$span(class = "badge bg-secondary", row$ALTURA_MAXIMA)),
            tags$td(row$AREA_LIBRE_MIN),
            tags$td(tags$span(class = "badge text-bg-warning", row$ESTADO_VALIDACION)),
            tags$td(tags$small(row$USOS_PERMITIDOS))
          )
        })
      )
    )
  })
}

# ------------------------------------------------------------------------------
# 3. LANZADOR DE LA APLICACIÓN
# ------------------------------------------------------------------------------
shinyApp(ui, server)
