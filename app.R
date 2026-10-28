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
  library(htmlwidgets)
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
source("R/estilos_territoriales.R", local = TRUE)
source("R/supabase_utils.R", local = TRUE)
source("R/reglamento_utils.R", local = TRUE, encoding = "UTF-8")
source("R/local_data.R", local = TRUE)
source("R/reporte_cartografico_utils.R", local = TRUE)
source("R/mod_privacidad.R", local = TRUE)
source("R/mod_informacion_pdu.R", local = TRUE)
source("R/mod_catalogo_zonas.R", local = TRUE)

# Las rutas de Chrome/Pandoc se resuelven desde el entorno de despliegue.

# ------------------------------------------------------------------------------
# 0. CARGA DE DATOS LOCALES O SUPABASE/POSTGIS Y CONSTANTES
# ------------------------------------------------------------------------------
if (dir.exists("aprobacion")) {
  shiny::addResourcePath("aprobacion", normalizePath("aprobacion"))
}

datos_pdu <- datos_supabase <- pdu_cargar_datos()
ambito_disponible <- nrow(datos_supabase$capas$ambito) > 0
if (!is.null(datos_supabase$aviso)) message(datos_supabase$aviso)
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
FECHA_APROBACION_PDU <- "11 de abril de 2025"
FECHA_ACTUALIZACION_PDU <- "04 de septiembre del 2026"
ORDENANZA_APROBACION_PDU <- "ORDENANZA MUNICIPAL Nº 04-2025-A-MPA/C"
ORDENANZA_ACTUALIZACION_PDU <- "ORDENANZA MUNICIPAL N°008-2026-A-MPA-C"
URL_EL_PERUANO_PDU <- "https://busquedas.elperuano.pe/dispositivo/NL/2407024-1"
GERENCIA_OFICIAL <- "GERENCIA DE DESARROLLO URBANO Y RURAL"
SUBGERENCIA_OFICIAL <- "SUB GERENCIA DE PLANEAMIENTO URBANO Y ACONDICIONAMIENTO TERRITORIAL"
SUBGERENCIA_ROL <- "Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial"
CARACTER_INFORMATIVO <- paste(
  "Documento de carácter informativo, generado mediante consulta al visor geográfico municipal de la",
  "Municipalidad Provincial de Anta. No constituye certificado, constancia ni autorización administrativa,",
  "no genera derechos urbanísticos y no sustituye los procedimientos técnicos ni administrativos",
  "previstos en la normativa vigente. Todo trámite oficial o expedición de certificados debe gestionarse",
  "formalmente ante la Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial."
)

# ------------------------------------------------------------------------------
# 1. INTERFAZ DE USUARIO (UI)
# ------------------------------------------------------------------------------
ui <- page_navbar(
  id = "main_navbar",
  navbar_options = navbar_options(theme = "light", bg = "#FFFFFF"),
  title = div(
    class = "d-flex align-items-center gap-3",
    div(
      class = "brand-logo-left",
      img(src = "escudo_muni_anta.png", class = "logo-muni-header", alt = "Escudo Anta", title = "Municipalidad Provincial de Anta")
    ),
    div(
      class = "d-flex flex-column justify-content-center",
      # Fila 1: Marca institucional + Vigencia normativa + Fecha oficial
      div(
        class = "d-flex align-items-center gap-2",
        span(class = "header-brand-title", "GEOVISOR PDU ANTA"),
        span(class = "pdu-badge-title", "2024 - 2034"),
        span(
          class = "header-badge-aprobado d-none d-sm-inline-flex",
          icon("calendar-check"), " Aprobado: 11 de abril del 2025 (Act. 04/09/2026)"
        )
      ),
      # Fila 2: Subtítulo territorial institucional
      tags$small(
        class = "header-subtitle d-none d-md-inline-block",
        "Municipalidad Provincial de Anta • Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial"
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
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1, shrink-to-fit=no"),
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css"),
    tags$script(HTML("
      function obtenerUbicacionGPS() {
        if (!navigator.geolocation) {
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('gps_error_event', { code: 0, message: 'La geolocalización no es soportada por este navegador.' }, {priority: 'event'});
          }
          return;
        }
        var btn = document.getElementById('btn_gps_movil');
        if (btn) {
          btn.innerHTML = '<i class=\"fa fa-spinner fa-spin\"></i> Obteniendo coordenadas GPS...';
          btn.disabled = true;
        }

        function exitoGPS(position) {
          if (btn) {
            btn.innerHTML = '<i class=\"fa fa-location-crosshairs\"></i> 📍 Mi Ubicación Actual (GPS Móvil)';
            btn.disabled = false;
          }
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('gps_location_device', {
              lat: position.coords.latitude,
              lng: position.coords.longitude,
              accuracy: position.coords.accuracy,
              timestamp: new Date().getTime()
            }, {priority: 'event'});
          }
        }

        function falloGPS(error) {
          if (btn) {
            btn.innerHTML = '<i class=\"fa fa-location-crosshairs\"></i> 📍 Mi Ubicación Actual (GPS Móvil)';
            btn.disabled = false;
          }
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('gps_error_event', {
              code: error.code,
              message: error.message || ''
            }, {priority: 'event'});
          }
        }

        // Intento 1: Alta precisión (para móviles con GPS dedicado)
        navigator.geolocation.getCurrentPosition(
          exitoGPS,
          function(error) {
            // Si el error fue timeout o posición no disponible, reintentar con red/Wi-Fi estándar
            if (error.code === error.TIMEOUT || error.code === error.POSITION_UNAVAILABLE) {
              navigator.geolocation.getCurrentPosition(
                exitoGPS,
                falloGPS,
                { enableHighAccuracy: false, timeout: 10000, maximumAge: 30000 }
              );
            } else {
              falloGPS(error);
            }
          },
          { enableHighAccuracy: true, timeout: 8000, maximumAge: 0 }
        );
      }
    ")),
    tags$script(HTML("
      // ======================================================================
      // GESTIÓN DE CONSENTIMIENTO OPT-IN (Ley N° 29733 y Estándares Int.)
      // Ningún identificador de analítica se almacena ni se transmite antes de Aceptar.
      // ======================================================================
      function inicializarConsentimientoPDU() {
        var decision = localStorage.getItem('pdu_consent_decision');
        if (decision === 'accepted') {
          var storageKey = 'pdu_anta_visitante_id';
          var visitorId = localStorage.getItem(storageKey);
          if (!visitorId) {
            visitorId = (window.crypto && window.crypto.randomUUID)
              ? window.crypto.randomUUID()
              : 'pdu-' + Date.now() + '-' + Math.random().toString(36).slice(2);
            localStorage.setItem(storageKey, visitorId);
          }
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('visitante_geovisor_id', visitorId, {priority: 'event'});
          }
        }
      }

      function aceptarConsentimientoPDU() {
        localStorage.setItem('pdu_consent_decision', 'accepted');
        var storageKey = 'pdu_anta_visitante_id';
        var visitorId = localStorage.getItem(storageKey);
        if (!visitorId) {
          visitorId = (window.crypto && window.crypto.randomUUID)
            ? window.crypto.randomUUID()
            : 'pdu-' + Date.now() + '-' + Math.random().toString(36).slice(2);
          localStorage.setItem(storageKey, visitorId);
        }
        if (window.Shiny && Shiny.setInputValue) {
          Shiny.setInputValue('visitante_geovisor_id', visitorId, {priority: 'event'});
          Shiny.setInputValue('cerrar_modal_privacidad', new Date().getTime(), {priority: 'event'});
        }
        if (window.$ && $('#shiny-modal').length) {
          $('#shiny-modal').modal('hide');
        }
        var banner = document.getElementById('banner_consentimiento_pdu');
        if (banner) banner.style.display = 'none';
      }

      function rechazarConsentimientoPDU() {
        localStorage.setItem('pdu_consent_decision', 'rejected');
        localStorage.removeItem('pdu_anta_visitante_id');
        if (window.Shiny && Shiny.setInputValue) {
          Shiny.setInputValue('cerrar_modal_privacidad', new Date().getTime(), {priority: 'event'});
        }
        if (window.$ && $('#shiny-modal').length) {
          $('#shiny-modal').modal('hide');
        }
        var banner = document.getElementById('banner_consentimiento_pdu');
        if (banner) banner.style.display = 'none';
      }

      function reabrirModalPrivacidad() {
        if (window.Shiny && Shiny.setInputValue) {
          Shiny.setInputValue('abrir_modal_privacidad', new Date().getTime(), {priority: 'event'});
        }
      }

      document.addEventListener('shiny:connected', function() {
        inicializarConsentimientoPDU();
      });
    ")),
    tags$script(HTML("
      // ======================================================================
      // CONTROL DE TIEMPO Y MODAL AMIGABLE DE DESCONEXIÓN (ETAPA 1)
      // ======================================================================
      function mostrarModalDesconexionPDU(mensajeCustom) {
        var defaultOverlay = document.getElementById('shiny-disconnected-overlay');
        if (defaultOverlay) {
          defaultOverlay.style.display = 'none';
        }

        var existingBackdrop = document.getElementById('pdu-timeout-backdrop');
        if (existingBackdrop) {
          if (mensajeCustom) {
            var msgElem = existingBackdrop.querySelector('.pdu-timeout-custom-msg');
            if (msgElem) msgElem.textContent = mensajeCustom;
          }
          existingBackdrop.classList.add('active');
          return;
        }

        var backdrop = document.createElement('div');
        backdrop.id = 'pdu-timeout-backdrop';
        backdrop.className = 'pdu-timeout-backdrop active';
        backdrop.innerHTML = `
          <div class=\"pdu-timeout-modal-card\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"pdu-timeout-title\">
            <div class=\"pdu-timeout-header\">
              <div class=\"pdu-timeout-icon-circle\">
                <i class=\"fa fa-clock\"></i>
              </div>
              <h3 id=\"pdu-timeout-title\" class=\"pdu-timeout-title\">Sesión de Consulta Finalizada</h3>
              <p class=\"pdu-timeout-subtitle\">Municipalidad Provincial de Anta • PDU 2024 - 2034</p>
            </div>
            <div class=\"pdu-timeout-body\">
              <p class=\"pdu-timeout-custom-msg mb-2\">
                Su sesión de consulta de <strong>10 minutos</strong> ha culminado con el fin de optimizar los recursos del servidor y garantizar un acceso fluido para toda la ciudadanía.
              </p>
              <div class=\"pdu-timeout-callout\">
                <i class=\"fa fa-circle-info text-success me-1\"></i>
                Si requiere continuar consultando información territorial, zonificación o generar fichas informativas, puede iniciar una nueva sesión inmediatamente.
              </div>
            </div>
            <div class=\"pdu-timeout-footer\">
              <button type=\"button\" class=\"btn-pdu-reconnect\" onclick=\"window.location.reload();\">
                <i class=\"fa fa-rotate-right\"></i> Iniciar Nueva Consulta
              </button>
            </div>
          </div>
        `;
        document.body.appendChild(backdrop);
      }

      // Escuchar eventos de desconexión o expiración de Shiny
      $(document).on('shiny:connected', function() {
        if (window.Shiny && Shiny.addCustomMessageHandler) {
          Shiny.addCustomMessageHandler('pdu_session_expired', function(data) {
            mostrarModalDesconexionPDU(data && data.mensaje ? data.mensaje : null);
          });
        }
      });

      $(document).on('shiny:disconnected', function(event) {
        mostrarModalDesconexionPDU();
      });
    ")),
    tags$style(HTML("
      .leaflet-container { height: calc(100vh - 78px) !important; width: 100% !important; }
      @media (max-width: 767.98px) {
        .leaflet-container {
          height: calc(100dvh - 66px) !important;
          height: calc(100vh - 66px) !important;
          width: 100% !important;
        }
      }
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
              "Ingrese los vértices del predio o cargue un archivo para consultar la zonificación urbana y las fajas de servidumbre normativas."
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
              placeholder = "Seleccione un archivo del predio"
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
        
        # Acceso al Reporte Informativo y Descarga
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
    title = "Ficha Informativa",
    value = "tab_certificado",
    icon = icon("file-invoice"),
    
    div(
      class = "container-fluid px-lg-5 px-2 px-sm-3 py-3",
      div(
        class = "alert alert-warning border-0 shadow-sm reporte-disclaimer mb-3",
        icon("circle-info"), tags$b(" Alcance de la ficha: "), CARACTER_INFORMATIVO
      ),
      div(
        class = "d-flex flex-column flex-sm-row justify-content-between align-items-stretch align-items-sm-center gap-2 mb-3 pb-2 border-bottom bg-white p-2 p-sm-3 rounded shadow-sm",
        actionButton("btn_volver_al_visor", "← Volver al Visor Territorial", class = "btn btn-outline-success fw-bold"),
        uiOutput("ui_boton_descarga_certificado_tab")
      ),
      uiOutput("ui_certificado_completo_view")
    )
  ),
  
  # --- PESTAÑA DESPLEGABLE: NORMATIVA E INFORMACIÓN ---
  nav_menu(
    title = "Normativa e Información",
    icon = icon("book-open"),
    
    # 3.1: CATÁLOGO DE ZONIFICACIÓN Y LEYENDA
    mod_catalogo_zonas_ui(total_subzonas = nrow(df_parametros)),
    
    # 3.2: INFORMACIÓN INSTITUCIONAL DEL PDU
    mod_informacion_pdu_ui()
  ),
  # Espaciador, métricas de telemetría y Logo Oficial PDU al extremo derecho
  nav_spacer(),
  nav_item(
    div(
      class = "d-flex align-items-center gap-2 me-1",
      uiOutput("ui_temporizador_sesion", inline = TRUE),
      uiOutput("ui_metricas_publicas", inline = TRUE),
      div(
        class = "brand-logo-right d-none d-xl-flex",
        img(src = "pdu_actualizado_sf.png", class = "logo-pdu-header", alt = "Logo PDU", title = "Plan de Desarrollo Urbano de Anta 2024 - 2034")
      )
    )
  )
)

# ------------------------------------------------------------------------------
# 2. LÓGICA DEL SERVIDOR (SERVER)
# ------------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # ============================================================================
  # CONTROL DE TIEMPO DE CONSULTA (ETAPA 1 - GUÍA PDU ANTA)
  # Duración fija de 600 segundos (10 minutos) por sesión con desconexión activa
  # ============================================================================
  session$allowReconnect(FALSE)
  
  DURACION_SESION_SEG <- 600L
  tiempo_inicio_sesion <- Sys.time()
  tiempo_limite_sesion <- tiempo_inicio_sesion + DURACION_SESION_SEG
  
  sesion_cerrada <- FALSE
  aviso_1min_mostrado <- FALSE
  restante_seg <- reactiveVal(DURACION_SESION_SEG)
  
  cerrar_sesion_pdu <- function(motivo = "tiempo_agotado") {
    if (sesion_cerrada) return(invisible(NULL))
    sesion_cerrada <<- TRUE
    tryCatch({
      session$sendCustomMessage("pdu_session_expired", list(
        motivo = motivo,
        mensaje = "Su tiempo de consulta de 10 minutos ha finalizado."
      ))
    }, error = function(e) NULL)
    session$close()
  }
  
  sesion_vigente <- function() {
    !sesion_cerrada && as.numeric(difftime(tiempo_limite_sesion, Sys.time(), units = "secs")) > 0
  }
  
  observe({
    invalidateLater(1000, session)
    if (sesion_cerrada) return()
    
    n_seg <- max(0L, ceiling(as.numeric(difftime(tiempo_limite_sesion, Sys.time(), units = "secs"))))
    restante_seg(n_seg)
    
    if (n_seg <= 0L) {
      cerrar_sesion_pdu("tiempo_agotado")
    } else if (n_seg <= 60L && !aviso_1min_mostrado) {
      aviso_1min_mostrado <<- TRUE
      showNotification(
        tagList(
          tags$div(
            class = "d-flex align-items-center gap-2",
            icon("clock", class = "text-warning fs-5"),
            tags$strong("Queda 1 minuto de consulta")
          ),
          tags$p(
            class = "mb-0 mt-1",
            "Le recomendamos descargar su ficha informativa técnica o plano cartográfico antes del vencimiento."
          )
        ),
        duration = 12,
        type = "warning",
        id = "notif_aviso_tiempo_pdu"
      )
    }
  }, priority = 100)
  
  output$ui_temporizador_sesion <- renderUI({
    seg <- restante_seg()
    if (is.null(seg)) return(NULL)
    
    minutos <- seg %/% 60L
    segundos <- seg %% 60L
    tiempo_formateado <- sprintf("%02d:%02d", minutos, segundos)
    
    es_critico <- seg <= 30L
    es_aviso <- seg <= 60L
    
    clase_estado <- if (es_critico) {
      "timer-chip-danger"
    } else if (es_aviso) {
      "timer-chip-warning"
    } else {
      "timer-chip-normal"
    }
    
    span(
      id = "pdu_timer_chip",
      class = paste("timer-chip-pdu", clase_estado),
      title = paste0("Tiempo restante de consulta: ", tiempo_formateado, " min (Límite: 10 minutos)"),
      icon(if (es_aviso) "triangle-exclamation" else "clock"),
      span(class = "timer-label d-none d-sm-inline", "Consulta:"),
      span(class = "timer-digits", tiempo_formateado)
    )
  })
  
  # Estado reactivo: Modo activo ("punto" o "poligono")
  modo_activo <- reactiveVal("punto")
  punto_actual <- reactiveVal(NULL)
  poligono_actual <- reactiveVal(NULL)
  
  # ----------------------------------------------------------------------------
  # 2.1 RENDERIZADO BASE DEL MAPA LEAFLET
  # ----------------------------------------------------------------------------
  output$mapa_pdu <- renderLeaflet({
    zonif_bbox <- st_bbox(st_transform(capas$zonificacion, CRS_GEOGRAFICO))

    leaflet() %>%
      addProviderTiles(providers$OpenStreetMap, group = "OpenStreetMap") %>%
      addProviderTiles(providers$Esri.WorldImagery, group = "Satélite") %>%
      addProviderTiles(providers$Esri.WorldTopoMap, group = "Topográfico") %>%
      

      
      # 2. Ámbito PDU (color rojo resaltante para máxima visibilidad)
      addPolygons(
        data = capas$ambito,
        group = "Ámbito PDU Anta",
        fillColor = "#FFCDD2",
        fillOpacity = 0.08,
        color = "#D32F2F",
        weight = 3.5,
        opacity = 1.0,
        dashArray = "8, 5",
        label = ~paste("Ámbito PDU Anta -", NOM_AI)
      ) %>%
      
      # 3. Servidumbre Alta Tensión
      addPolygons(
        data = capas$alta_tension_buffer,
        group = "Servidumbre Alta Tensión",
        fillColor = "#D6A43A",
        fillOpacity = 0.24,
        color = "#A23E3A",
        weight = 0.9,
        label = ~paste("Faja de Servidumbre Eléctrica:", TENS_NOMIN, "kV"),
        popup = ~paste0(
          "<div style='font-size:12px; font-family:Inter, sans-serif; min-width:210px;'>",
          "<div style='background:#A23E3A; color:white; padding:5px 8px; font-weight:bold; border-radius:4px 4px 0 0;'>FAJA DE SERVIDUMBRE ELÉCTRICA</div>",
          "<div style='padding:6px;'>",
          "<b>Nivel de Tensión:</b> ", htmltools::htmlEscape(TENS_NOMIN), " kV<br>",
          "<b>Empresa:</b> ", htmltools::htmlEscape(NOM_EMPRES), "<br>",
          "<div style='margin-top:4px; font-size:11px; color:#A23E3A; font-weight:600;'>Área con restricción de edificación (CNE)</div>",
          "</div></div>"
        )
      ) %>%
      
      # 4. Líneas Alta Tensión
      addPolylines(
        data = capas$alta_tension,
        group = "Líneas de Alta Tensión",
        color = "#A23E3A",
        weight = 1.8,
        opacity = 0.85,
        dashArray = "8, 5",
        label = ~paste("Línea AT:", NOM_EMPRES, "-", TENS_NOMIN),
        popup = ~paste0(
          "<div style='font-size:12px; font-family:Inter, sans-serif; min-width:210px;'>",
          "<div style='background:#A23E3A; color:white; padding:5px 8px; font-weight:bold; border-radius:4px 4px 0 0;'>LÍNEA DE ALTA TENSIÓN</div>",
          "<div style='padding:6px;'>",
          "<b>Línea:</b> ", htmltools::htmlEscape(NOM_LINEA), "<br>",
          "<b>Empresa:</b> ", htmltools::htmlEscape(NOM_EMPRES), "<br>",
          "<b>Tensión:</b> ", htmltools::htmlEscape(TENS_NOMIN), " kV",
          "</div></div>"
        )
      ) %>%
      
      # 5. Servidumbre Ferrocarril
      addPolygons(
        data = capas$ferrocarril_buffer,
        group = "Zona de influencia del ferrocarril",
        fillColor = "#8B7AA8",
        fillOpacity = 0.20,
        color = "#6B5A88",
        weight = 0.9,
        label = ~"Zona de influencia del ferrocarril (15 m por lado; requiere verificación sectorial)",
        popup = ~paste0(
          "<div style='font-size:12px; font-family:Inter, sans-serif; min-width:220px;'>",
          "<div style='background:#6B5A88; color:white; padding:5px 8px; font-weight:bold; border-radius:4px 4px 0 0;'>ZONA DE INFLUENCIA DEL FERROCARRIL</div>",
          "<div style='padding:6px;'>",
          "<b>Faja de Seguridad:</b> 15 m por lado respecto al eje.<br>",
          "<b>Normativa:</b> D.S. 032-2005-MTC.<br>",
          "<div style='margin-top:4px; font-size:11px; color:#6B5A88;'>Verificar derecho de vía con el MTC y concesionario.</div>",
          "</div></div>"
        )
      ) %>%
      
      # 6. Vía Férrea
      addPolylines(
        data = capas$ferrocarril,
        group = "Vía Férrea (Tren)",
        color = "#3F4844",
        weight = 2.1,
        opacity = 0.88,
        dashArray = "7, 5",
        label = ~paste("Ferrocarril:", NOM_FERR, "-", TRAMO_FERR),
        popup = ~paste0(
          "<div style='font-size:12px; font-family:Inter, sans-serif; min-width:200px;'>",
          "<div style='background:#3F4844; color:white; padding:5px 8px; font-weight:bold; border-radius:4px 4px 0 0;'>RED FERROVIARIA</div>",
          "<div style='padding:6px;'>",
          "<b>Ferrocarril:</b> ", htmltools::htmlEscape(NOM_FERR), "<br>",
          "<b>Tramo:</b> ", htmltools::htmlEscape(TRAMO_FERR), "<br>",
          "<b>Administrador:</b> ", htmltools::htmlEscape(ADM_FERR),
          "</div></div>"
        )
      ) %>%
      
      # 7. Zonificación PDU
      addPolygons(
        data = capas$zonificacion,
        group = "Zonificación PDU",
        fillColor = ~COLOR_MAPA,
        fillOpacity = 0.60,
        color = ~COLOR_MAPA,
        opacity = 0.88,
        weight = 0.8,
        label = ~paste0(COD_S_ZONA, ": ", NOMBRE_COMPLETO),
        popup = ~POPUP_MAPA,
        highlightOptions = highlightOptions(
          weight = 2.2,
          color = "#F1C75B",
          fillOpacity = 0.82,
          bringToFront = FALSE
        )
      ) %>%
      

      
      addEasyButton(easyButton(
        icon = "fa-crosshairs", title = "Mi Ubicación Actual (GPS)",
        position = "topleft",
        onClick = JS("function(btn, map){ obtenerUbicacionGPS(); }")
      )) %>%
      addEasyButton(easyButton(
        icon = "fa-expand", title = "Ajustar vista a Zonificación PDU",
        position = "topleft",
        onClick = JS(sprintf(
          "function(btn, map){ map.invalidateSize(); map.fitBounds([[%f, %f], [%f, %f]], {padding: [12, 12], maxZoom: 16}); }",
          unname(zonif_bbox["ymin"]), unname(zonif_bbox["xmin"]),
          unname(zonif_bbox["ymax"]), unname(zonif_bbox["xmax"])
        ))
      )) %>%
      
      addLayersControl(
        baseGroups = c("OpenStreetMap", "Satélite", "Topográfico"),
        overlayGroups = c(
          "Zonificación PDU", "Ámbito PDU Anta",
          "Servidumbre Alta Tensión", "Líneas de Alta Tensión",
          "Zona de influencia del ferrocarril", "Vía Férrea (Tren)"
        ),
        options = layersControlOptions(collapsed = TRUE)
      ) %>%
      
      fitBounds(
        lng1 = unname(zonif_bbox["xmin"]),
        lat1 = unname(zonif_bbox["ymin"]),
        lng2 = unname(zonif_bbox["xmax"]),
        lat2 = unname(zonif_bbox["ymax"])
      ) %>%
      
      htmlwidgets::onRender(sprintf("
        function(el, x) {
          var map = this;
          var zonifBounds = [[%f, %f], [%f, %f]];
          
          function enfocarZonificacionMobile() {
            if (!map) return;
            map.invalidateSize();
            map.fitBounds(zonifBounds, {
              padding: [15, 15],
              maxZoom: 16,
              animate: false
            });
          }
          
          // Re-intentos escalonados conforme el viewport móvil calcula el 100dvh y el layout se estabiliza
          setTimeout(enfocarZonificacionMobile, 150);
          setTimeout(enfocarZonificacionMobile, 600);
          setTimeout(enfocarZonificacionMobile, 1400);
          
          // Soporte ante giros de pantalla (portrait/landscape) y redimensionamiento
          window.addEventListener('resize', function() {
            map.invalidateSize();
          });
          window.addEventListener('orientationchange', function() {
            setTimeout(enfocarZonificacionMobile, 350);
          });
          
          // Re-ajustar al cambiar de pestaña en Bootstrap
          document.addEventListener('shown.bs.tab', function() {
            setTimeout(enfocarZonificacionMobile, 200);
          });
          
          // Re-ajustar si el usuario colapsa o despliega el sidebar de bslib
          document.addEventListener('bslib.sidebar.toggle', function() {
            setTimeout(enfocarZonificacionMobile, 350);
          });
        }
      ",
      unname(zonif_bbox["ymin"]), unname(zonif_bbox["xmin"]),
      unname(zonif_bbox["ymax"]), unname(zonif_bbox["xmax"])
      ))
  })
  
  # Refuerzo reactivo: Asegurar encuadre a zonificación en cuanto el cliente móvil completa la conexión
  session$onFlushed(function() {
    zonif_bb <- st_bbox(st_transform(capas$zonificacion, CRS_GEOGRAFICO))
    leafletProxy("mapa_pdu") %>%
      fitBounds(
        lng1 = unname(zonif_bb["xmin"]),
        lat1 = unname(zonif_bb["ymin"]),
        lng2 = unname(zonif_bb["xmax"]),
        lat2 = unname(zonif_bb["ymax"])
      )
  }, once = TRUE)
  
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

    proxy_map <- leafletProxy("mapa_pdu") %>%
      clearGroup("consulta_activa")
      
    # Círculo de radio de precisión estimada (GPS / Wi-Fi)
    if (!is.null(precision) && is.numeric(precision) && precision > 5) {
      proxy_map <- proxy_map %>%
        addCircles(
          lng = lng, lat = lat, group = "consulta_activa",
          radius = precision,
          color = "#2563EB", weight = 1.5, dashArray = "4,4",
          fillColor = "#3B82F6", fillOpacity = 0.12,
          popup = paste0("<b>Incertidumbre de posición:</b> ±", precision, " metros")
        )
    }

    proxy_map %>%
      addCircleMarkers(
        lng = lng, lat = lat, group = "consulta_activa",
        radius = 7, color = "#202020", weight = 2,
        fillColor = "#D80808", fillOpacity = 0.9,
        label = paste0("Punto consultado", if (!is.null(precision)) paste0(" (Precisión: ±", precision, " m)") else "")
      ) %>%
      setView(lng = lng, lat = lat, zoom = if (!is.null(precision) && precision > 150) 15 else 17)
      
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
        distrito = ifelse(is.na(dist_m), "Distrito no disponible", dist_m),
        en_ambito = en_amb,
        zona_principal = z_cod,
        detalle_json = list(lat = round(lat, 6), lng = round(lng, 6), precision = precision)
      )
    }, error = function(e) NULL)
  }
  
  # Clic en el mapa
  observeEvent(input$mapa_pdu_click, {
    if (!sesion_vigente()) {
      cerrar_sesion_pdu("tiempo_agotado")
      return()
    }
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
    acc <- round(loc$accuracy, 1)
    tryCatch(fijar_punto_consulta(loc$lng, loc$lat, precision = acc), error = function(e) {
      showNotification(conditionMessage(e), type = "error")
    })
    
    if (acc > 30) {
      showNotification(
        HTML(paste0(
          "<b><i class='fa fa-wifi'></i> Posición estimada por Red/Wi-Fi (±", acc, " m):</b><br>",
          "En computadoras o laptops la posición es aproximada mediante antenas Wi-Fi.<br>",
          "<small style='color: #4A5568;'>Para máxima precisión catastral (±3 a 5 m), abra el geovisor en un teléfono móvil con GPS activo en campo o ingrese coordenadas UTM del plano.</small>"
        )),
        type = "warning", duration = 8
      )
    } else {
      showNotification(
        paste0("✓ Ubicación GPS de alta precisión fijada (±", acc, " m)."),
        type = "message", duration = 4
      )
    }
  })
  
  # Manejo institucional de avisos y errores de GPS (RStudio Viewer / Navegador)
  observeEvent(input$gps_error_event, {
    err <- input$gps_error_event
    req(err)
    
    codigo <- suppressWarnings(as.integer(err$code))
    mensaje_html <- if (isTRUE(codigo == 1)) { # PERMISSION_DENIED
      HTML(paste0(
        "<div style='font-size: 13.5px;'>",
        "<b><i class='fa fa-location-dot'></i> Permiso de ubicación GPS no concedido</b><br>",
        "El navegador o entorno de ejecución no permitió acceder a las coordenadas del dispositivo.<br>",
        "<ul style='margin: 6px 0 0 16px; padding: 0;'>",
        "<li><b>Si está en el visor interno de RStudio:</b> Haga clic en el botón <b>«Open in Browser»</b> (arriba a la izquierda) para abrir la aplicación en Chrome, Edge o Firefox.</li>",
        "<li><b>Si está en un navegador web o teléfono móvil:</b> Verifique que los permisos de ubicación estén habilitados para este sitio en la barra de direcciones.</li>",
        "<li>También puede ingresar coordenadas UTM o seleccionar su predio directamente en el mapa.</li>",
        "</ul>",
        "</div>"
      ))
    } else if (isTRUE(codigo == 2)) { # POSITION_UNAVAILABLE
      HTML("<b>Ubicación no disponible:</b> No se pudo determinar la posición geográfica del dispositivo. Puede ingresar coordenadas UTM manualmente en el panel.")
    } else if (isTRUE(codigo == 3)) { # TIMEOUT
      HTML("<b>Tiempo de espera agotado:</b> La señal GPS tardó demasiado en responder. Intente nuevamente o ingrese coordenadas UTM manualmente.")
    } else {
      HTML("<b>Aviso de ubicación:</b> Su dispositivo o navegador no tiene soporte de geolocalización activo en este momento.")
    }
    
    showNotification(
      mensaje_html,
      type = "warning",
      duration = 10,
      closeButton = TRUE
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
    pct_en_ambito <- if (ambito_disponible) min(100, (area_en_ambito / area_total_m2) * 100) else NA_real_
    
    # 2. Distritos
    inter_dist <- if (nrow(capas$distritos)) st_intersection(poly_4326, capas$distritos) else capas$distritos
    distritos_list <- if (nrow(inter_dist) > 0) unique(inter_dist$NOMBDIST) else if (nrow(capas$ambito) > 0 && "NOMBDIST" %in% names(capas$ambito)) capas$ambito$NOMBDIST[1] else "Anta"
    
    # 3. Alta Tensión (Servidumbre Eléctrica)
    area_at_m2 <- area_interseccion_unica_m2(poly_4326, capas$alta_tension_buffer)
    pct_at <- min(100, (area_at_m2 / area_total_m2) * 100)
    inter_at <- suppressWarnings(st_intersection(poly_4326, capas$alta_tension_buffer))
    lineas_at_txt <- if (nrow(inter_at) > 0) {
      nom_l <- unique(na.omit(inter_at$NOM_LINEA))
      volt_l <- unique(na.omit(inter_at$TENS_NOMIN))
      paste0(paste(nom_l, collapse = " / "), " (", paste(volt_l, collapse = ", "), ")")
    } else ""
    
    # 4. Ferrocarril (Zona de Influencia / Derecho de Vía)
    area_ffcc_m2 <- area_interseccion_unica_m2(poly_4326, capas$ferrocarril_buffer)
    pct_ffcc <- min(100, (area_ffcc_m2 / area_total_m2) * 100)
    inter_ffcc <- suppressWarnings(st_intersection(poly_4326, capas$ferrocarril_buffer))
    lineas_ffcc_txt <- if (nrow(inter_ffcc) > 0) {
      nom_f <- unique(na.omit(inter_ffcc$NOM_FERR))
      tramo_f <- unique(na.omit(inter_ffcc$TRAMO_FERR))
      paste0(paste(nom_f, collapse = " / "), " (Tramo: ", paste(tramo_f, collapse = ", "), ")")
    } else "" 
    
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
        
        if (length(m_idx) > 0) {
          p_row <- pdu_buscar_parametros(df_parametros, cod_sz)[[1]]
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
      lineas_at_txt = lineas_at_txt,
      lineas_ffcc_txt = lineas_ffcc_txt,
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
  # 2.4 RETIRO DE LA FICHA TÉCNICA DEL PANEL LATERAL
  # (La información técnica se despliega exclusivamente en el Módulo Reporte Informativo)
  # ----------------------------------------------------------------------------
  output$ui_ficha_resultado <- renderUI(NULL)
  
  # ----------------------------------------------------------------------------
  # 2.6 ACCIONES DE CONSULTA Y ACCESO AL REPORTE INFORMATIVO
  # ----------------------------------------------------------------------------
  output$ui_botones_descarga <- renderUI({
    modo <- modo_activo()
    hay_consulta <- (modo == "punto" && !is.null(punto_actual())) ||
                    (modo == "poligono" && !is.null(poligono_actual()))
    
    if (!hay_consulta) {
      return(
        div(
          class = "text-center py-4 text-muted small",
          icon("hand-pointer", class = "fs-2 mb-2 d-block text-secondary"),
          tags$b("Haga clic en el mapa"), " o use coordenadas / polígono para iniciar una consulta territorial."
        )
      )
    }
    
    pt_data <- punto_actual()
    poly_data <- poligono_actual()
    
    div(
      class = "card border-0 shadow-sm p-3 mb-2",
      style = "background-color: #F8FAFC; border-left: 4px solid #008800 !important; border-radius: 8px;",
      div(
        class = "d-flex align-items-center gap-2 mb-2",
        icon("circle-check", style = "color: #008800; font-size: 1.15rem;"),
        tags$b(style = "color: #006633; font-size: 0.95rem;",
               if (modo == "punto") "Punto Consultado" else "Polígono Consultado")
      ),
      div(
        class = "small text-muted mb-0",
        if (modo == "punto") {
          tagList(
            tags$div(tags$b("Coordenadas UTM 18S: "), paste0("E: ", round(pt_data$este, 2), " m | N: ", round(pt_data$norte, 2), " m")),
            if (!is.null(pt_data$precision) && is.finite(pt_data$precision) && pt_data$precision > 10) {
              tags$div(class = "text-warning small mt-1", icon("location-crosshairs"), paste0(" Precisión GPS: ±", round(pt_data$precision, 1), " m"))
            }
          )
        } else {
          tagList(
            tags$div(tags$b("Área del Predio: "), paste0(poly_data$area_m2, " m² (", poly_data$area_has, " ha)")),
            tags$div(tags$b("Perímetro: "), paste0(poly_data$perimetro_m, " ml")),
            tags$div(tags$b("Distrito(s): "), paste(poly_data$distritos, collapse = ", "))
          )
        }
      ),
      p(
        class = "small text-muted mt-2 mb-0",
        style = "font-size: 0.80rem; line-height: 1.35;",
        "La zonificación, afectaciones viales, parámetros urbanísticos y el plano oficial se encuentran en la pestaña ",
        tags$b(style = "color: #006633;", "Reporte Informativo"), "."
      )
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
        "btn_descargar_pdf_tab", "📥 Descargar Ficha Informativa (PDF)",
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
  
  # Función auxiliar para generar el HTML completo del certificado con mapa oficial, logos, escala, rosa de vientos y datos
  generar_html_certificado <- function() {
    modo <- modo_activo()
    
    escudo_b64 <- tryCatch(knitr::image_uri("www/escudo_muni_anta.png"), error = function(e) "")
    logo_pdu_b64 <- tryCatch(knitr::image_uri("www/pdu_actualizado_sf.png"), error = function(e) "")
    
    # Estilo CSS optimizado para formato A4 en 2 páginas completas con encabezados y pies de página numerados
    css_certificado <- "
      @page { size: A4 portrait; margin: 6mm 8mm 6mm 8mm; }
      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #ffffff; color: #202020; margin: 0; padding: 0; font-size: 12px; line-height: 1.30; width: 100%; box-sizing: border-box; }
      .cert-card { width: 100%; max-width: 1200px; margin: 0 auto; box-sizing: border-box; }
      .cert-page { width: 100%; box-sizing: border-box; min-height: 280mm; display: flex; flex-direction: column; justify-content: space-between; page-break-after: always; position: relative; }
      .cert-watermark {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%) rotate(-35deg);
        font-size: 36pt;
        font-weight: 800;
        color: rgba(180, 180, 180, 0.14);
        white-space: nowrap;
        pointer-events: none;
        z-index: 50;
        user-select: none;
        letter-spacing: 4px;
      }
      .cert-page:last-child { page-break-after: auto; }
      .cert-page-body { flex-grow: 1; display: flex; flex-direction: column; }
      
      .header-banner { background: linear-gradient(135deg, #006633, #008800); color: white; padding: 5px 12px; border-radius: 4px; margin-bottom: 4px; border-bottom: 3px solid #B88808; width: 100%; box-sizing: border-box; }
      .header-banner-p2 { margin-bottom: 5px; padding: 4px 10px; }
      .header-title { font-size: 1.05rem; font-weight: 700; color: #FFFFFF; margin: 0; line-height: 1.15; letter-spacing: 0.2px; }
      .header-subtitle { font-size: 0.80rem; color: #F8F888; margin: 0; font-weight: 600; }
      .header-meta { font-size: 0.66rem; color: rgba(255,255,255,0.90); margin: 0; }
      
      .project-box { background: #FFF7D6; border: 1px solid #B88808; border-radius: 4px; padding: 3px 8px; font-size: 0.74rem; margin-bottom: 3px; line-height: 1.2; width: 100%; box-sizing: border-box; }
      .legal-notice-box { background: #FFFBEB; border: 1px solid #F59E0B; border-left: 4px solid #D97706; border-radius: 4px; padding: 3px 8px; font-size: 0.71rem; color: #78350F; margin-bottom: 3px; line-height: 1.2; width: 100%; box-sizing: border-box; }
      
      .section-heading { color: #006633; border-bottom: 1.5px solid #98C838; padding-bottom: 1px; margin-top: 4px; margin-bottom: 3px; font-size: 0.82rem; font-weight: 700; text-transform: uppercase; }
      .table-cert { width: 100%; border-collapse: collapse; margin-bottom: 4px; font-size: 0.78rem; }
      .table-cert th { background-color: #F2F3EF; color: #202020; font-weight: 600; padding: 2.5px 6px; border: 1px solid #CBD5E1; }
      .table-cert td { padding: 2.5px 6px; border: 1px solid #CBD5E1; }
      .table-compact th { width: 24%; }
      
      .mapa-container { width: 100%; flex: 1 1 auto; display: flex; flex-direction: column; justify-content: flex-start; align-items: center; min-height: 0; margin-top: 3px; margin-bottom: 2px; }
      .mapa-img-fullpage { width: 100%; height: auto; max-height: 228mm; object-fit: contain; display: block; box-sizing: border-box; }
      
      .cert-footer { width: 100%; border-top: 1px solid #CBD5E1; padding-top: 3px; margin-top: 4px; display: flex; justify-content: space-between; align-items: center; font-size: 0.66rem; color: #64748B; box-sizing: border-box; }
      .cert-footer-left { text-align: left; }
      .cert-footer-right { text-align: right; white-space: nowrap; font-weight: 700; color: #006633; }
      
      .badge-vial { background: #B88808; color: white; padding: 1.5px 6px; border-radius: 3px; font-weight: bold; font-size: 0.74rem; display: inline-block; }
      .sub-card-param { background: #F8FAFC; border: 1px solid #CBD5E1; border-radius: 4px; margin-bottom: 4px; padding: 4px 6px; }
      .sub-card-header { font-weight: 700; color: #006633; margin-bottom: 2px; border-bottom: 1px solid #E2E8F0; padding-bottom: 2px; font-size: 0.78rem; }
      .page-break { page-break-before: always; }
      .avoid-break { page-break-inside: avoid; }
      .methodology-note { background: #F8FAFC; border-left: 3px solid #008800; padding: 2px 6px; font-size: 0.70rem; color: #475569; margin-top: 2px; margin-bottom: 3px; font-style: italic; }
      ul.cert-list { margin: 0 0 3px 0; padding-left: 16px; font-size: 0.78rem; }
      ul.cert-list li { margin-bottom: 1.5px; }
      .text-danger { color: #B91C1C; } .text-warning { color: #9A6700; } .text-muted { color: #64748B; }
      .small { font-size: 0.76rem; } .badge { display:inline-block; padding:2px 6px; border-radius:3px; color:#fff; }
      .bg-success { background:#008800; } .me-2 { margin-right:6px; } .ms-2 { margin-left:6px; }
      .mb-0 { margin-bottom:0; } .mb-1 { margin-bottom:3px; } .mb-2 { margin-bottom:4px; }
      
      @media screen {
        .cert-page { min-height: auto; margin-bottom: 24px; padding-bottom: 16px; border-bottom: 2px dashed #CBD5E1; }
        .cert-page:last-child { border-bottom: none; margin-bottom: 0; padding-bottom: 0; }
        .mapa-img-fullpage { max-height: 850px; }
      }
      
      @media print {
        @page { size: A4 portrait; margin: 6mm 8mm 6mm 8mm; }
        body { margin: 0; padding: 0; }
        .cert-card { width: 100% !important; max-width: 100% !important; margin: 0; padding: 0; }
        .cert-watermark { color: rgba(180, 180, 180, 0.16) !important; font-size: 34pt !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        .cert-page { height: 284mm !important; max-height: 284mm !important; min-height: 284mm !important; display: flex !important; flex-direction: column !important; justify-content: space-between !important; page-break-after: always !important; page-break-inside: avoid !important; overflow: hidden !important; }
        .cert-page:last-child { page-break-after: auto !important; }
        .cert-page-body { flex-grow: 1; display: flex; flex-direction: column; }
        .cert-page-technical { height: auto !important; max-height: none !important; min-height: 284mm !important; page-break-inside: auto !important; overflow: visible !important; }
        .cert-page-technical .cert-page-body { flex: 1 0 auto !important; }
        .cert-page-technical .cert-footer { margin-top: auto; padding-bottom: 3px; }
        .page-break { display: none !important; }
        .mapa-img-fullpage { width: 100% !important; max-height: 228mm !important; }
      }
      
      @media (max-width: 768px) {
        body { font-size: 11.5px; padding: 0; }
        .cert-card { width: 100% !important; max-width: 100% !important; margin: 0; padding: 0; }
        .header-banner { padding: 4px 6px; }
        .header-title { font-size: 0.85rem; }
        .header-subtitle { font-size: 0.72rem; }
        .header-meta { font-size: 0.62rem; }
        .table-cert { font-size: 0.74rem; }
        .table-cert th, .table-cert td { padding: 2px 4px; }
        .table-compact th { width: 32%; }
        .project-box { font-size: 0.70rem; padding: 3px 6px; }
        .legal-notice-box { font-size: 0.70rem; padding: 3px 6px; }
        .mapa-img-fullpage { max-height: 380px; }
        .section-heading { font-size: 0.78rem; }
      }
    "
    
    fecha_consulta_str <- format(Sys.time(), "%d/%m/%Y a las %H:%M horas")
    codigo_consulta <- paste0("PDU-ANTA-", format(Sys.time(), "%Y%m%d%H%M"))
    
    # Encabezado institucional oficial para Página 1
    header_banner_p1 <- div(
      class = "header-banner",
      tags$table(
        style = "width:100%; color:white; border:none; margin-bottom:0;",
        tags$tr(
          tags$td(
            style = "width:65px; vertical-align:middle; border:none; padding:0;",
            if (escudo_b64 != "") tags$img(src = escudo_b64, style = "height:52px; background:white; padding:2px; border-radius:4px;", alt = "Escudo Anta")
          ),
          tags$td(
            style = "vertical-align:middle; padding-left:12px; border:none;",
            tags$div(class = "header-title", "MUNICIPALIDAD PROVINCIAL DE ANTA"),
            tags$div(class = "header-subtitle", if (modo == "punto") "REPORTE INFORMATIVO — PDU ANTA 2024 - 2034" else "REPORTE INFORMATIVO DE PARÁMETROS URBANÍSTICOS Y ZONIFICACIÓN"),
            tags$div(class = "header-meta", paste("Consulta:", codigo_consulta, "|", fecha_consulta_str, "| Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial"))
          ),
          tags$td(
            style = "width:75px; text-align:right; vertical-align:middle; border:none; padding:0;",
            if (logo_pdu_b64 != "") tags$img(src = logo_pdu_b64, style = "height:48px; background:white; padding:2px; border-radius:4px;", alt = "Logo PDU")
          )
        )
      )
    )
    
    # Encabezado institucional oficial para Página 2
    header_banner_p2 <- div(
      class = "header-banner header-banner-p2",
      tags$table(
        style = "width:100%; color:white; border:none; margin-bottom:0;",
        tags$tr(
          tags$td(
            style = "width:50px; vertical-align:middle; border:none; padding:0;",
            if (escudo_b64 != "") tags$img(src = escudo_b64, style = "height:40px; background:white; padding:2px; border-radius:4px;", alt = "Escudo Anta")
          ),
          tags$td(
            style = "vertical-align:middle; padding-left:12px; border:none;",
            tags$div(class = "header-title", style = "font-size: 1.02rem;", "MUNICIPALIDAD PROVINCIAL DE ANTA"),
            tags$div(class = "header-subtitle", style = "font-size: 0.80rem;", if (modo == "punto") "REPORTE INFORMATIVO — FICHA TÉCNICA Y PARÁMETROS URBANÍSTICOS" else "REPORTE INFORMATIVO — FICHA TÉCNICA NORMATIVA DE PREDIO"),
            tags$div(class = "header-meta", style = "font-size: 0.68rem;", paste("PDU Anta 2024 - 2034 • Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial • Consulta:", codigo_consulta))
          ),
          tags$td(
            style = "width:65px; text-align:right; vertical-align:middle; border:none; padding:0;",
            if (logo_pdu_b64 != "") tags$img(src = logo_pdu_b64, style = "height:38px; background:white; padding:2px; border-radius:4px;", alt = "Logo PDU")
          )
        )
      )
    )
    
    # Pie de página institucional numerado para Página 1
    footer_p1 <- div(
      class = "cert-footer",
      div(class = "cert-footer-left", tags$b("Municipalidad Provincial de Anta"), " — Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial | PDU Anta 2024 - 2034"),
      div(class = "cert-footer-right", tags$b("Página 1 de 2"))
    )
    
    # Pie de página institucional numerado para Página 2
    footer_p2 <- div(
      class = "cert-footer",
      div(class = "cert-footer-left", tags$b("Municipalidad Provincial de Anta"), " — Gerencia de Desarrollo Urbano y Rural — Sub Gerencia de Planeamiento Urbano y Acondicionamiento Territorial | PDU Anta 2024 - 2034"),
      div(class = "cert-footer-right", tags$b("Página 2 de 2"))
    )
    
    if (modo == "punto") {
      pt_data <- punto_actual()
      pt_sf <- st_sf(geometry = pt_data$geom_4326)
      en_ambito <- any(st_intersects(pt_sf, capas$ambito, sparse = FALSE)[1, ])
      dist_match <- if (nrow(capas$distritos) > 0) st_join(pt_sf, capas$distritos, join = st_intersects)$NOMBDIST[1] else NA_character_
      distrito_nombre <- if (!is.na(dist_match)) dist_match else if (nrow(capas$ambito) > 0 && "NOMBDIST" %in% names(capas$ambito)) capas$ambito$NOMBDIST[1] else "Anta"
      idx_at <- which(st_intersects(pt_sf, capas$alta_tension_buffer, sparse = FALSE)[1, ])
      en_serv_at <- length(idx_at) > 0
      lineas_at_pt_txt <- if (en_serv_at) {
        nom_l <- unique(na.omit(capas$alta_tension_buffer$NOM_LINEA[idx_at]))
        volt_l <- unique(na.omit(capas$alta_tension_buffer$TENS_NOMIN[idx_at]))
        paste0(paste(nom_l, collapse = " / "), " (", paste(volt_l, collapse = ", "), ")")
      } else ""
      
      idx_ffcc <- which(st_intersects(pt_sf, capas$ferrocarril_buffer, sparse = FALSE)[1, ])
      en_serv_ffcc <- length(idx_ffcc) > 0
      lineas_ffcc_pt_txt <- if (en_serv_ffcc) {
        nom_f <- unique(na.omit(capas$ferrocarril_buffer$NOM_FERR[idx_ffcc]))
        tramo_f <- unique(na.omit(capas$ferrocarril_buffer$TRAMO_FERR[idx_ffcc]))
        paste0(paste(nom_f, collapse = " / "), " (Tramo: ", paste(tramo_f, collapse = ", "), ")")
      } else "" 
      
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
        if (length(m_idx) > 0) p_norm <- pdu_buscar_parametros(df_parametros, cod_s_zona)[[1]]
      }
      
      mapa_img_uri <- generar_mapa_certificado(pt_sf, es_poligono = FALSE, capas_pdu = capas, pal_subzonas = colores_subzonas, ancho_in = 7.6, alto_in = 8.85)
      
      doc_html <- tags$html(
        tags$head(
          tags$meta(charset = "utf-8"),
          tags$meta(name = "viewport", content = "width=device-width, initial-scale=1, shrink-to-fit=no"),
          tags$title("Reporte Informativo de Parámetros Urbanísticos - PDU Anta"),
          tags$style(HTML(css_certificado))
        ),
        tags$body(
          div(
            class = "cert-card",
            
            # --- PÁGINA 1: HOJA DEL PLANO CARTOGRÁFICO OFICIAL OFICIAL ---
            div(
              class = "cert-page",
              div(class = "cert-watermark", "DOCUMENTO INFORMATIVO"),
              div(
                class = "cert-page-body",
                header_banner_p1,
                div(
                  class = "legal-notice-box",
                  icon("circle-info"), " ", tags$b("Carácter del Documento: "), CARACTER_INFORMATIVO
                ),
                if (!is.null(mapa_img_uri)) {
                  tagList(
                    tags$div(class = "section-heading", "PLANO DE UBICACIÓN Y ZONIFICACIÓN TERRITORIAL"),
                    div(class = "mapa-container", tags$img(src = mapa_img_uri, class = "mapa-img-fullpage"))
                  )
                }
              ),
              footer_p1
            ),
            
            # --- PÁGINA 2: DATOS Y PARÁMETROS NORMATIVOS ---
            div(
              class = "cert-page cert-page-technical",
              div(class = "cert-watermark", "DOCUMENTO INFORMATIVO"),
              div(
                class = "cert-page-body",
                header_banner_p2,
                tags$div(class = "section-heading", "1. DATOS DE LOCALIZACIÓN Y COORDENADAS"),
                tags$table(
                  class = "table-cert table-compact mb-2",
                  tags$tbody(
                    tags$tr(tags$th("Distrito:"), tags$td(tags$b(distrito_nombre), " (Provincia de Anta, Cusco)")),
                    tags$tr(tags$th("Ámbito Reglamentado PDU:"), tags$td(if (!ambito_disponible) "Ámbito no disponible en datos locales" else if (en_ambito) tags$b(style = "color:#008800;", "SÍ (Dentro del Ámbito PDU Anta)") else tags$b(style = "color:#D80808;", "NO (Fuera de Ámbito)"))),
                    tags$tr(tags$th("Coordenadas UTM 18S:"), tags$td(paste0("Este (X): ", round(pt_data$este, 3), " m | Norte (Y): ", round(pt_data$norte, 3), " m"))),
                    tags$tr(tags$th("Coordenadas WGS84:"), tags$td(paste0("Lat: ", round(pt_data$lat, 4), "° | Lng: ", round(pt_data$lng, 4), "°")))
                  )
                ),
                tags$div(class = "section-heading", "2. RESUMEN DE IDENTIFICACIÓN CARTOGRÁFICA"),
                tags$table(
                  class = "table-cert table-compact mb-2",
                  tags$tbody(
                    tags$tr(tags$th("Tipo de consulta:"), tags$td("Punto geográfico")),
                    tags$tr(tags$th("Zona PDU:"), tags$td(if (!is.na(cod_zona)) cod_zona else "Sin zonificación asignada")),
                    tags$tr(tags$th("Subzona / descripción:"), tags$td(if (!is.na(cod_s_zona)) paste(cod_s_zona, "—", sub_zona) else "No identificada")),
                    tags$tr(tags$th("Ámbito PDU Anta:"), tags$td(if (!ambito_disponible) "No disponible" else if (en_ambito) "Dentro del ámbito reglamentado" else "Fuera del ámbito reglamentado"))
                  )
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
                    tags$tr(tags$th("Coeficiente de Edificabilidad:"), tags$td(if (!is.null(p_norm)) p_norm$COEFICIENTE_EDIF else "N/A")),
                    tags$tr(tags$th("Retiros:"), tags$td(if (!is.null(p_norm)) p_norm$RETIRO_FRONTAL else "N/A")),
                    tags$tr(tags$th("Usos Permitidos:"), tags$td(tags$small(if (!is.null(p_norm)) p_norm$USOS_PERMITIDOS else "N/A"))),
                    pdu_filas_reglamento(p_norm)
                  )
                ),
                
                if (length(unique(capas$zonificacion$COD_S_ZONA[idx_zonif_punto])) > 1) tagList(
                  tags$div(class = "section-heading", "OTRAS SUBZONAS INTERSECTADAS"),
                  div(class = "alert alert-warning", "El punto intersecta varias subzonas. Verifique el límite cartográfico; se incluyen todas las fichas aplicables."),
                  lapply(pdu_buscar_parametros(df_parametros, setdiff(capas$zonificacion$COD_S_ZONA[idx_zonif_punto], cod_s_zona)), pdu_tabla_parametros)
                ),
                tags$div(class = "section-heading", "4. AFECTACIONES DE INFRAESTRUCTURA"),
                tags$ul(
                  class = "cert-list",
                  tags$li(if (en_serv_at) tags$b(class = "text-danger", "⚠️ AFECTACIÓN POR FAJA DE SERVIDUMBRE DE ALTA TENSIÓN (CNE). Prohibida edificación.") else "✓ Sin afectación por fajas de alta tensión."),
                  tags$li(if (en_serv_ffcc) tags$b(class = "text-warning", "⚠️ PROXIMIDAD A ZONA DE INFLUENCIA DEL FERROCARRIL. Verificar el derecho de vía con el MTC y el concesionario.") else "✓ Sin proximidad a la zona de influencia del ferrocarril.")
                )
              ),
              footer_p2
            )
          )
        )
      )
      
    } else {
      # CERTIFICADO COMPLETO DE PREDIO CON ZONIFICACIÓN MÚLTIPLE, VÍAS Y MAPA
      poly_data <- poligono_actual()
      mapa_img_uri <- generar_mapa_certificado(poly_data$poly_4326, es_poligono = TRUE, capas_pdu = capas, pal_subzonas = colores_subzonas, ancho_in = 7.6, alto_in = 8.35)
      
      doc_html <- tags$html(
        tags$head(
          tags$meta(charset = "utf-8"),
          tags$meta(name = "viewport", content = "width=device-width, initial-scale=1, shrink-to-fit=no"),
          tags$title("Ficha Informativa de Zonificación de Predio - PDU Anta"),
          tags$style(HTML(css_certificado))
        ),
        tags$body(
          div(
            class = "cert-card",
            
            # --- PÁGINA 1: HOJA DEL PLANO CARTOGRÁFICO OFICIAL OFICIAL ---
            div(
              class = "cert-page",
              div(class = "cert-watermark", "DOCUMENTO INFORMATIVO"),
              div(
                class = "cert-page-body",
                header_banner_p1,
                div(
                  class = "legal-notice-box",
                  icon("circle-info"), " ", tags$b("Carácter del Documento: "), CARACTER_INFORMATIVO
                ),
                if (!is.null(mapa_img_uri)) {
                  tagList(
                    tags$div(class = "section-heading", "PLANO DE UBICACIÓN Y ZONIFICACIÓN DEL PREDIO"),
                    div(class = "mapa-container", tags$img(src = mapa_img_uri, class = "mapa-img-fullpage"))
                  )
                }
              ),
              footer_p1
            ),
            
            # --- PÁGINA 2: CERTIFICADO INFORMATIVO NORMATIVO ---
            div(
              class = "cert-page",
              div(
                class = "cert-page-body",
                header_banner_p2,
                tags$div(class = "section-heading", "1. DATOS MÉTRICOS DEL PREDIO Y ÁMBITO PDU"),
                tags$table(
                  class = "table-cert table-compact mb-2",
                  tags$tbody(
                    tags$tr(tags$th("Área Total del Predio:"), tags$td(tags$b(paste0(poly_data$area_m2, " m² (", poly_data$area_has, " ha)")))),
                    tags$tr(tags$th("Perímetro Total:"), tags$td(paste0(poly_data$perimetro_m, " ml"))),
                    tags$tr(tags$th("Distrito(s) Administrativo(s):"), tags$td(paste(poly_data$distritos, collapse = ", "))),
                    tags$tr(tags$th("Ámbito Reglamentado PDU:"), tags$td(if (!ambito_disponible) "No disponible" else paste0(poly_data$pct_en_ambito, "% dentro del área PDU Anta"))),
                    tags$tr(tags$th("Faja de Servidumbre Eléctrica:"), tags$td(if (poly_data$pct_at > 0) tags$b(class = "text-danger", paste0("⚠️ Afectación: ", poly_data$area_at_m2, " m² (", poly_data$pct_at, "% del predio)", if (!is.null(poly_data$lineas_at_txt) && nzchar(poly_data$lineas_at_txt)) paste0(" — Línea: ", poly_data$lineas_at_txt) else "")) else "✓ Sin afectación")),
                    tags$tr(tags$th("Zona de Influencia Ferrocarril:"), tags$td(if (poly_data$pct_ffcc > 0) tags$b(class = "text-warning", paste0("⚠️ Proximidad: ", poly_data$area_ffcc_m2, " m² (", poly_data$pct_ffcc, "% del predio)", if (!is.null(poly_data$lineas_ffcc_txt) && nzchar(poly_data$lineas_ffcc_txt)) paste0(" — Vía: ", poly_data$lineas_ffcc_txt) else "")) else "✓ Sin proximidad"))
                  )
                ),
                
                                tags$div(class = "section-heading", "2. DESGLOSE DE ZONIFICACIÓN EN EL LOTE"),
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
                
                tags$div(class = "section-heading", "3. AFECTACIONES POR INFRAESTRUCTURA"),
                tags$ul(
                  class = "cert-list",
                  tags$li(if (poly_data$pct_at > 0) tags$b(class = "text-danger", paste0("⚠️ Servidumbre Alta Tensión: ", poly_data$area_at_m2, " m² (", poly_data$pct_at, "% del predio)", if (!is.null(poly_data$lineas_at_txt) && nzchar(poly_data$lineas_at_txt)) paste0(" — Línea: ", poly_data$lineas_at_txt) else "", ". Prohibida edificación dentro de la faja.")) else "✓ Sin afectación por fajas de servidumbre de líneas de alta tensión (CNE)."),
                  tags$li(if (poly_data$pct_ffcc > 0) tags$b(class = "text-warning", paste0("⚠️ Zona de influencia del ferrocarril: ", poly_data$area_ffcc_m2, " m² (", poly_data$pct_ffcc, "% del predio)", if (!is.null(poly_data$lineas_ffcc_txt) && nzchar(poly_data$lineas_ffcc_txt)) paste0(" — Vía: ", poly_data$lineas_ffcc_txt) else "", ". Requiere verificación sectorial ante el MTC.")) else "✓ Sin proximidad a la zona de influencia del ferrocarril (D.S. 032-2005-MTC).")
                ),
                
                tags$div(class = "section-heading", "4. PARÁMETROS URBANÍSTICOS POR ZONA"),
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
                          tags$tr(tags$th("Retiros:"), tags$td(p_row$RETIRO_FRONTAL)),
                          tags$tr(tags$th("Usos Permitidos y Compatibles:"), tags$td(tags$small(p_row$USOS_PERMITIDOS))),
                          pdu_filas_reglamento(p_row)
                        )
                      )
                    )
                  })
                } else {
                  div(class = "alert alert-warning small", "No se registran parámetros normativos aplicables.")
                }
              ),
              footer_p2
            )
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
    codigo_consulta <- paste0("PDU-ANTA-", format(Sys.time(), "%Y%m%d%H%M"))
    temp_id <- paste0("constancia_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", sample(1000:9999, 1))
    mapa_png_rel <- file.path("outputs", paste0("mapa_", temp_id, ".png"))
    on.exit({
      if (file.exists(mapa_png_rel)) unlink(mapa_png_rel)
    }, add = TRUE)
    
    if (modo == "punto") {
      pt_data <- punto_actual()
      pt_sf <- st_sf(geometry = pt_data$geom_4326)
      en_ambito <- any(st_intersects(pt_sf, capas$ambito, sparse = FALSE)[1, ])
      dist_match <- if (nrow(capas$distritos) > 0) st_join(pt_sf, capas$distritos, join = st_intersects)$NOMBDIST[1] else NA_character_
      distrito_nombre <- if (!is.na(dist_match)) dist_match else if (nrow(capas$ambito) > 0 && "NOMBDIST" %in% names(capas$ambito)) capas$ambito$NOMBDIST[1] else "Anta"
      idx_at <- which(st_intersects(pt_sf, capas$alta_tension_buffer, sparse = FALSE)[1, ])
      en_serv_at <- length(idx_at) > 0
      lineas_at_pt_txt <- if (en_serv_at) {
        nom_l <- unique(na.omit(capas$alta_tension_buffer$NOM_LINEA[idx_at]))
        volt_l <- unique(na.omit(capas$alta_tension_buffer$TENS_NOMIN[idx_at]))
        paste0(paste(nom_l, collapse = " / "), " (", paste(volt_l, collapse = ", "), ")")
      } else ""
      
      idx_ffcc <- which(st_intersects(pt_sf, capas$ferrocarril_buffer, sparse = FALSE)[1, ])
      en_serv_ffcc <- length(idx_ffcc) > 0
      lineas_ffcc_pt_txt <- if (en_serv_ffcc) {
        nom_f <- unique(na.omit(capas$ferrocarril_buffer$NOM_FERR[idx_ffcc]))
        tramo_f <- unique(na.omit(capas$ferrocarril_buffer$TRAMO_FERR[idx_ffcc]))
        paste0(paste(nom_f, collapse = " / "), " (Tramo: ", paste(tramo_f, collapse = ", "), ")")
      } else "" 
      
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
      
      sz_intersectadas <- capas$zonificacion$COD_S_ZONA[idx_zonif_punto]
      sz_validas <- intersect(unique(sz_intersectadas), df_parametros$COD_S_ZONA)
      lista_parametros <- if (length(sz_validas) > 0) {
        pdu_buscar_parametros(df_parametros, sz_validas)
      } else {
        list()
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
      
      generar_mapa_certificado(pt_sf, es_poligono = FALSE, ruta_salida_png = mapa_png_rel, capas_pdu = capas, pal_subzonas = colores_subzonas, ancho_in = 7.6, alto_in = 8.85)
      
      payload <- list(
        codigo_consulta = codigo_consulta,
        fecha_hora = format(Sys.time(), "%d/%m/%Y %H:%M"),
        distrito = distrito_nombre,
        ambito_pdu = if (!ambito_disponible) "Ámbito no disponible en datos locales" else if (en_ambito) "SÍ (Dentro del Ámbito PDU Anta)" else "NO (Fuera de Ámbito)",
        es_poligono = FALSE,
        coords_utm = paste0("E: ", round(pt_data$este, 2), " m | N: ", round(pt_data$norte, 2), " m (Zona 18S)"),
        coords_geo = paste0("Lat: ", round(pt_data$lat, 5), "° | Lng: ", round(pt_data$lng, 5), "° (WGS84)"),
        area_m2 = "N/A (Consulta Puntual)",
        area_has = "N/A",
        perimetro_m = "N/A",
        pct_en_ambito = if (!ambito_disponible) "No disponible" else if (en_ambito) "100" else "0",
        servidumbre_at = if (en_serv_at) {
          if (nzchar(lineas_at_pt_txt)) paste0("⚠️ Faja de servidumbre: Línea ", lineas_at_pt_txt, " (CNE)") else "⚠️ Afectación por faja de alta tensión (CNE)"
        } else "No",
        servidumbre_ffcc = if (en_serv_ffcc) {
          if (nzchar(lineas_ffcc_pt_txt)) paste0("⚠️ Zona de influencia ferroviaria: ", lineas_ffcc_pt_txt, " (MTC)") else "⚠️ Proximidad a la zona de influencia del ferrocarril (MTC)"
        } else "No",
        tabla_zonif = tabla_zonif,
        tabla_vias = tabla_vias,
        lista_parametros = lista_parametros,
        mapa_path = mapa_png_rel,
        escudo_path = "www/escudo_muni_anta.png",
        logo_pdu_path = "www/pdu_actualizado_sf.png"
      )
      
    } else {
      poly_data <- poligono_actual()
      generar_mapa_certificado(poly_data$poly_4326, es_poligono = TRUE, ruta_salida_png = mapa_png_rel, capas_pdu = capas, pal_subzonas = colores_subzonas, ancho_in = 7.6, alto_in = 8.35)
      
      payload <- list(
        codigo_consulta = codigo_consulta,
        fecha_hora = format(Sys.time(), "%d/%m/%Y %H:%M"),
        distrito = paste(poly_data$distritos, collapse = ", "),
        ambito_pdu = if (!ambito_disponible) "No disponible" else paste0(poly_data$pct_en_ambito, "% dentro del ámbito PDU"),
        es_poligono = TRUE,
        coords_utm = "Polígono catastral delimitado en coordenadas UTM 18S",
        coords_geo = "Polígono catastral delimitado en coordenadas WGS84",
        area_m2 = format(poly_data$area_m2, big.mark = ","),
        area_has = format(poly_data$area_has, big.mark = ","),
        perimetro_m = format(poly_data$perimetro_m, big.mark = ","),
        pct_en_ambito = as.character(poly_data$pct_en_ambito),
        servidumbre_at = if (poly_data$pct_at > 0) {
          base_at <- paste0(poly_data$area_at_m2, " m² (", poly_data$pct_at, "% del predio)")
          if (!is.null(poly_data$lineas_at_txt) && nzchar(poly_data$lineas_at_txt)) paste0(base_at, " — Línea: ", poly_data$lineas_at_txt) else base_at
        } else "No",
        servidumbre_ffcc = if (poly_data$pct_ffcc > 0) {
          base_ffcc <- paste0(poly_data$area_ffcc_m2, " m² (", poly_data$pct_ffcc, "% del predio)")
          if (!is.null(poly_data$lineas_ffcc_txt) && nzchar(poly_data$lineas_ffcc_txt)) paste0(base_ffcc, " — Vía: ", poly_data$lineas_ffcc_txt) else base_ffcc
        } else "No",
        tabla_zonif = poly_data$tabla_zonif,
        tabla_vias = poly_data$tabla_vias_predio,
        lista_parametros = poly_data$lista_parametros_zonas,
        mapa_path = mapa_png_rel,
        escudo_path = "www/escudo_muni_anta.png",
        logo_pdu_path = "www/pdu_actualizado_sf.png"
      )
    }
    
    # 1. Renderizado principal con Quarto + Typst. Renderizar en un directorio
    # temporal propio evita depender del directorio de trabajo del servidor y
    # evita colisiones entre descargas simultáneas de distintas sesiones.
    if (quarto_disponible()) {
      qmd_path <- normalizePath("constancia_pdu_template.qmd", winslash = "/", mustWork = TRUE)
      render_dir <- tempfile("constancia_quarto_")
      dir.create(render_dir, recursive = TRUE, showWarnings = FALSE)
      render_dir <- normalizePath(render_dir, winslash = "/", mustWork = TRUE)
      render_qmd <- file.path(render_dir, "constancia_pdu_template.qmd")
      temp_rds <- file.path(render_dir, "payload.rds")
      temp_pdf_out <- file.path(render_dir, "constancia.pdf")
      temp_pdf_name <- basename(temp_pdf_out)
      on.exit(unlink(render_dir, recursive = TRUE, force = TRUE), add = TRUE)

      if (!file.copy(qmd_path, render_qmd, overwrite = TRUE)) {
        stop("No se pudo preparar la plantilla temporal para generar la constancia.")
      }
      # La plantilla carga el mapa, los logotipos y funciones de R mediante rutas relativas.
      for (recurso in c("outputs", "www", "logo", "R")) {
        if (dir.exists(recurso)) {
          file.copy(recurso, render_dir, recursive = TRUE, copy.mode = FALSE)
        }
      }
      saveRDS(payload, temp_rds)

      render_error <- NULL

      # Opción A: A través del paquete R quarto
      if (requireNamespace("quarto", quietly = TRUE)) {
        tryCatch({
          quarto::quarto_render(
            input = render_qmd,
            output_file = temp_pdf_name,
            execute_params = list(data_rds = basename(temp_rds)),
            output_format = "typst",
            quiet = TRUE
          )
        }, error = function(e) {
          render_error <<- conditionMessage(e)
        })
      }

      # Opción B: CLI directo. El código de salida debe ser cero; system2
      # devuelve el estado del proceso cuando se captura la salida.
      pdf_valido <- function(path) {
        if (!file.exists(path)) return(FALSE)
        info <- file.info(path)
        if (is.na(info$size) || info$size <= 100) return(FALSE)
        con <- file(path, open = "rb")
        on.exit(close(con), add = TRUE)
        identical(readBin(con, what = "raw", n = 5L), charToRaw("%PDF-"))
      }

      if (!pdf_valido(temp_pdf_out) && nzchar(Sys.which("quarto"))) {
        cli_output <- tryCatch(
          system2(
            "quarto",
            args = c(
              "render", render_qmd,
              "--to", "typst",
              "--output", temp_pdf_name,
              "--output-dir", ".",
              "--execute-dir", ".",
              "-P", paste0("data_rds:", basename(temp_rds))
            ),
            stdout = TRUE, stderr = TRUE
          ),
          error = function(e) {
            render_error <<- conditionMessage(e)
            structure(character(), status = 1L)
          }
        )
        cli_status <- attr(cli_output, "status")
        if (is.null(cli_status)) cli_status <- 0L
        if (cli_status != 0L) {
          render_error <- paste(tail(cli_output, 8L), collapse = "\n")
        }
      }

      if (pdf_valido(temp_pdf_out) && file.copy(temp_pdf_out, destino_file, overwrite = TRUE) && pdf_valido(destino_file)) {
        return(invisible(destino_file))
      }
      if (is.null(render_error)) {
        render_error <- "Quarto no produjo un archivo PDF válido en la ruta esperada."
      }
      message("No se pudo generar la constancia con Quarto: ", render_error)
    }
    
    # 2. Fallback con Chrome / pagedown si Quarto no estuviera instalado
    if (chrome_disponible()) {
      temp_html <- tempfile(fileext = ".html")
      on.exit(unlink(temp_html), add = TRUE)
      doc_html <- generar_html_certificado()
      save_html(doc_html, file = temp_html)
      tryCatch(
        pagedown::chrome_print(
          input = temp_html,
          output = destino_file,
          extra_args = c("--no-sandbox", "--disable-gpu", "--allow-file-access-from-files")
        ),
        error = function(e) {
          message("No se pudo generar la constancia con Chrome: ", conditionMessage(e))
        }
      )
      con <- if (file.exists(destino_file)) file(destino_file, open = "rb") else NULL
      firma_pdf <- if (is.null(con)) raw() else {
        on.exit(close(con), add = TRUE)
        readBin(con, what = "raw", n = 5L)
      }
      if (length(firma_pdf) == 5L && identical(firma_pdf, charToRaw("%PDF-")) && file.info(destino_file)$size > 100) {
        return(invisible(destino_file))
      }
    }
    
    stop("No fue posible generar la constancia en PDF.")
  }
  
  # Descarga PDF Oficial (Botón en el panel lateral)
  output$btn_descargar_pdf <- downloadHandler(
    filename = function() {
      paste0("Ficha_Informativa_PDU_Anta_", format(Sys.time(), "%Y%m%d_%H%M"), ".pdf")
    },
    content = function(file) {
      if (!sesion_vigente()) {
        cerrar_sesion_pdu("tiempo_agotado")
        stop("El tiempo de consulta asignado ha finalizado.")
      }
      generar_constancia_pdf(file)
      metricas_supa(supabase_registrar_constancia())
    },
    contentType = "application/pdf"
  )

  output$btn_descargar_pdf_tab <- downloadHandler(
    filename = function() {
      paste0("Ficha_Informativa_PDU_Anta_", format(Sys.time(), "%Y%m%d_%H%M"), ".pdf")
    },
    content = function(file) {
      if (!sesion_vigente()) {
        cerrar_sesion_pdu("tiempo_agotado")
        stop("El tiempo de consulta asignado ha finalizado.")
      }
      generar_constancia_pdf(file)
      metricas_supa(supabase_registrar_constancia())
    },
    contentType = "application/pdf"
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

  # Modal Informativo y Panel de Configuración de Privacidad (Ley N° 29733)
  mod_privacidad_server(input, output, session)

  output$ui_metricas_publicas <- renderUI({
    metricas <- metricas_supa()
    if (is.null(metricas) || is.na(metricas$visitas_total)) return(NULL)

    div(
      class = "header-counters-wrap d-none d-md-inline-flex",
      span(
        class = "counter-chip-mini",
        title = "Visitas registradas a la plataforma",
        icon("eye"), tags$span(class = "counter-chip-val", format(metricas$visitas_total, big.mark = ",", scientific = FALSE)), " visitas"
      ),
      span(
        class = "counter-chip-mini",
        title = "Fichas informativas generadas",
        icon("file-lines"), tags$span(class = "counter-chip-val", format(metricas$constancias_total, big.mark = ",", scientific = FALSE)), " fichas"
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
    if (isTRUE(info$es_local) || info$modo %in% c("local", "offline")) {
      span(
        class = "status-pill-cloud status-pill-local d-none d-md-inline-flex",
        title = "Operando en modo local autónomo con capas Shapefile de data/ (Supabase deprecado).",
        icon("laptop"), "Modo Local (Autónomo)"
      )
    } else if (isTRUE(info$conectado)) {
      span(
        class = "status-pill-cloud status-pill-online d-none d-md-inline-flex",
        title = paste("Infraestructura Cloud activa vía", toupper(info$modo), paste0("(", info$latencia_ms, " ms)")),
        icon("database"), paste0("Cloud DB Activa (", toupper(info$modo), ")")
      )
    } else {
      span(
        class = "status-pill-cloud status-pill-offline d-none d-md-inline-flex",
        title = "Servicio remoto no conectado.",
        icon("circle-info"), "Modo Local / Sin Conexión Cloud"
      )
    }
  })
  
  # Tarjeta de diagnóstico de base de datos en la pestaña de Buzón
  output$ui_card_estado_supabase <- renderUI({
    info <- estado_supa()
    tagList(
      div(
        class = "d-flex justify-content-between align-items-center py-1 border-bottom",
        span(class = "text-muted small", "Entorno de Datos:"),
        span(class = "badge bg-primary", "💻 Local Autónomo")
      ),
      div(
        class = "d-flex justify-content-between align-items-center py-1 border-bottom",
        span(class = "text-muted small", "Fuente Territorial:"),
        span(class = "fw-bold small", "Capas Shapefile y Datos Locales (data/)")
      ),
      div(
        class = "d-flex justify-content-between align-items-center py-1 border-bottom",
        span(class = "text-muted small", "Conexiones Externas:"),
        span(class = "badge bg-success", "Desacoplado / Sin dependencia externa")
      ),
      div(
        class = "d-flex justify-content-between align-items-center py-1",
        span(class = "text-muted small", "Despliegue Institucional:"),
        span(class = "badge bg-light text-dark", "Provincial Anta")
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
          icon("info-circle"), " El PDU Anta 2024-2034 fue aprobado formalmente mediante O.M. Nº 04-2025-A-MPA/C (11 de abril de 2025, publicado en El Peruano) y actualizado mediante O.M. N° 008-2026-A-MPA-C (04 de septiembre del 2026), encontrándose vigente para trámites de habilitación urbana y licencias de edificación."
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
    
    withProgress(message = "Registrando observación ciudadana...", value = 0.5, {
      res <- supabase_enviar_reporte_ciudadano(
        nombre_ciudadano = nombre,
        contacto = contacto,
        tipo_observacion = tipo,
        ubicacion_predio = if (nzchar(ubicacion)) ubicacion else "No especificada",
        mensaje = mensaje
      )
      
      if (isTRUE(res$ok)) {
        cod_ticket <- if (!is.null(res$ticket)) res$ticket else paste0("PDU-OBS-", format(Sys.time(), "%y%m%d%H%M"))
        feedback_msg(list(
          tipo = "success",
          texto = paste0("¡Observación registrada con éxito! Código asignado: ", cod_ticket, ". La Gerencia de Desarrollo Urbano revisará su reporte.")
        ))
        updateTextInput(session, "in_buzon_nombre", value = "")
        updateTextInput(session, "in_buzon_contacto", value = "")
        updateTextInput(session, "in_buzon_ubicacion", value = "")
        updateTextAreaInput(session, "in_buzon_mensaje", value = "")
        showNotification(
          if (identical(res$origen, "local")) "Observación registrada exitosamente en modo local." else "Observación enviada exitosamente.",
          type = "message",
          duration = 5
        )
      } else {
        feedback_msg(list(
          tipo = "error",
          texto = paste("Error al registrar:", res$error)
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
  mod_catalogo_zonas_server(input, output, session, df_parametros, colores_subzonas, colores_zonas)
}

# ------------------------------------------------------------------------------
# 3. LANZADOR DE LA APLICACIÓN
# ------------------------------------------------------------------------------
shinyApp(ui, server)
