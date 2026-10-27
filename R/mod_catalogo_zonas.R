# ==============================================================================
# MÓDULO: CATÁLOGO DE ZONIFICACIÓN Y PARÁMETROS URBANÍSTICOS
# GeoVisor PDU Anta 2024 - 2034 (GDUR Municipalidad Provincial de Anta)
# ==============================================================================

#' UI para la pestaña de Catálogo Normativo de Zonas
#' @param total_subzonas Número entero con el total de subzonas cargadas
#' @return nav_panel con buscador, KPIs y tabla interactiva
mod_catalogo_zonas_ui <- function(total_subzonas = 28) {
  nav_panel(
    title = "Catálogo Normativo de Zonas",
    value = "tab_catalogo",
    icon = icon("book-bookmark"),
    
    div(
      class = "container-fluid px-2 px-sm-4 py-3",
      div(
        class = "card shadow-sm border-0 mb-4 p-3 p-sm-4 catalogo-card",
        
        div(
          class = "d-flex flex-column flex-md-row justify-content-between align-items-md-center gap-3 mb-3",
          div(
            h3(class = "fw-bold mb-1 catalogo-title", icon("book-open"), " Catálogo de Zonificación y Parámetros Urbanísticos"),
            p(class = "text-muted mb-0", "Parámetros técnicos y edificatorios aprobados conforme al Reglamento de Acondicionamiento Territorial y Planificación Urbana del Desarrollo Urbano Sostenible (D.S. Nº 012-2022-VIVIENDA - RATPUDUS) para el PDU Anta 2024 - 2034.")
          ),
          div(
            class = "d-flex align-items-center gap-2",
            div(
              style = "min-width: 240px; width: 100%;",
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
              class = "p-3 rounded-3 border d-flex align-items-center gap-3 catalogo-kpi h-100",
              div(class = "p-2 rounded-2 text-white catalogo-kpi-icon catalogo-kpi-icon--green", icon("layer-group", class = "fs-4")),
              div(
                tags$small(class = "text-muted text-uppercase fw-bold", "Total Subzonas"),
                tags$h4(class = "mb-0 fw-bold", as.character(total_subzonas))
              )
            )
          ),
          div(
            class = "col-md-4 col-sm-6",
            div(
              class = "p-3 rounded-3 border d-flex align-items-center gap-3 catalogo-kpi h-100",
              div(class = "p-2 rounded-2 text-white catalogo-kpi-icon catalogo-kpi-icon--gold", icon("gavel", class = "fs-4")),
              div(
                tags$small(class = "text-muted text-uppercase fw-bold", "Marco Normativo"),
                tags$h6(class = "mb-1 fw-bold text-dark", style = "line-height: 1.25;", "D.S. Nº 012-2022-VIVIENDA"),
                tags$small(
                  class = "text-muted d-block",
                  style = "font-size: 0.74rem; line-height: 1.2;",
                  "Reglamento de Acondicionamiento Territorial y Planificación Urbana del Desarrollo Urbano Sostenible (RATPUDUS)"
                )
              )
            )
          ),
          div(
            class = "col-md-4 col-sm-12",
            div(
              class = "p-3 rounded-3 border d-flex align-items-center gap-3 catalogo-kpi h-100",
              div(class = "p-2 rounded-2 text-white catalogo-kpi-icon catalogo-kpi-icon--dark", icon("circle-check", class = "fs-4")),
              div(
                tags$small(class = "text-muted text-uppercase fw-bold", "Aprobación Oficial"),
                tags$h5(class = "mb-0 fw-bold", "11 de abril de 2025"),
                tags$small(class = "text-muted", "Act.: 04/09/2026")
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
  )
}

#' Lógica del servidor para el Catálogo de Zonificación
#' @param input Objeto input de Shiny
#' @param output Objeto output de Shiny
#' @param session Objeto session de Shiny
#' @param df_parametros Dataframe con los parámetros normativos
#' @param colores_subzonas Paleta de colores para subzonas
#' @param colores_zonas Paleta de colores para macrozonas
mod_catalogo_zonas_server <- function(input, output, session, df_parametros,
                                      colores_subzonas, colores_zonas) {
  output$ui_tabla_catalogo_dinamica <- renderUI({
    busqueda <- trimws(tolower(input$txt_buscar_catalogo %||% ""))
    df_mostrar <- pdu_filtrar_catalogo(df_parametros, busqueda)

    if (nrow(df_mostrar) == 0) {
      return(div(
        class = "p-4 text-center text-muted",
        icon("magnifying-glass", class = "fs-2 mb-2 d-block"),
        "No se encontraron tipologías de zonificación que coincidan con la búsqueda."
      ))
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
          tags$th(class = "text-center", "Ficha y Normativa")
        )
      ),
      tags$tbody(
        lapply(1:nrow(df_mostrar), function(i) {
          row <- df_mostrar[i, ]
          color <- colores_subzonas[row$COD_S_ZONA]
          if (is.na(color)) color <- colores_zonas[row$COD_ZONA]
          if (is.na(color)) color <- "#BCBDBE"

          tags$tr(
            tags$td(tags$span(
              class = "badge text-dark fw-bold",
              style = paste0("background-color:", color, "; font-size: 0.9em; border: 1px solid rgba(0,0,0,0.15);"),
              row$COD_S_ZONA
            )),
            tags$td(tags$b(row$NOMBRE_COMPLETO)),
            tags$td(div(style = "white-space: pre-line; font-size: 0.85rem; line-height: 1.3;", row$DENSIDAD_NETA_MAX)),
            tags$td(div(style = "white-space: pre-line; font-size: 0.85rem; line-height: 1.3;", row$LOTE_MINIMO)),
            tags$td(div(style = "white-space: pre-line; font-size: 0.85rem; line-height: 1.3;", row$FRENTE_MINIMO)),
            tags$td(
              if (is.na(row$ALTURA_MAXIMA) || !nzchar(trimws(row$ALTURA_MAXIMA)) || grepl("No establecido", row$ALTURA_MAXIMA)) {
                tags$span(class = "text-muted fst-italic small", "No aplica / Según proyecto")
              } else {
                div(
                  style = "white-space: pre-line; font-size: 0.85rem; line-height: 1.35; min-width: 175px; max-width: 290px;",
                  row$ALTURA_MAXIMA
                )
              }
            ),
            tags$td(div(style = "white-space: pre-line; font-size: 0.85rem; line-height: 1.3;", row$AREA_LIBRE_MIN)),
            tags$td(
              class = "text-center",
              tags$button(
                type = "button",
                class = "btn btn-sm btn-outline-success d-inline-flex align-items-center gap-1 shadow-sm px-2 py-1",
                style = "white-space: nowrap; font-weight: 500; font-size: 0.82rem;",
                `data-cod` = row$COD_S_ZONA,
                onclick = "Shiny.setInputValue('btn_ver_ficha_zona', (this.closest('button') || this).getAttribute('data-cod'), {priority: 'event'});",
                icon("circle-info"),
                "Ver ficha completa"
              )
            )
          )
        })
      )
    )
  })

  # Ventana modal completa con toda la pantalla disponible para la ficha técnica
  observeEvent(input$btn_ver_ficha_zona, {
    cod <- input$btn_ver_ficha_zona
    req(cod)
    param <- df_parametros[df_parametros$COD_S_ZONA == cod, , drop = FALSE]
    req(nrow(param) > 0)
    p <- param[1, ]

    color <- colores_subzonas[p$COD_S_ZONA]
    if (is.na(color)) color <- colores_zonas[p$COD_ZONA]
    if (is.na(color) || !nzchar(color)) color <- "#174A3A"

    showModal(modalDialog(
      title = div(
        class = "d-flex align-items-center gap-2 flex-wrap",
        tags$span(
          class = "badge text-dark fw-bold px-3 py-2",
          style = paste0("background-color:", color, "; font-size: 1.1rem; border: 1px solid rgba(0,0,0,0.2);"),
          p$COD_S_ZONA
        ),
        tags$span(class = "fw-bold fs-5 text-dark", p$NOMBRE_COMPLETO)
      ),
      div(
        class = "p-2",
        # Sección 1: Parámetros Técnicos y Edificatorios
        tags$h6(class = "fw-bold text-uppercase text-secondary mb-3", icon("ruler-combined"), " Parámetros Urbanísticos y Edificatorios Normativos"),
        div(
          class = "row g-3 mb-4",
          div(class = "col-md-3 col-sm-6",
            div(class = "p-3 rounded-3 bg-light border h-100",
              tags$small(class = "text-muted text-uppercase fw-bold d-block mb-1", "Densidad Neta Máxima"),
              div(style = "white-space: pre-line; font-size: 0.95rem; font-weight: 600;", p$DENSIDAD_NETA_MAX)
            )
          ),
          div(class = "col-md-3 col-sm-6",
            div(class = "p-3 rounded-3 bg-light border h-100",
              tags$small(class = "text-muted text-uppercase fw-bold d-block mb-1", "Lote Mínimo"),
              div(style = "white-space: pre-line; font-size: 0.95rem; font-weight: 600;", p$LOTE_MINIMO)
            )
          ),
          div(class = "col-md-3 col-sm-6",
            div(class = "p-3 rounded-3 bg-light border h-100",
              tags$small(class = "text-muted text-uppercase fw-bold d-block mb-1", "Frente Mínimo"),
              div(style = "white-space: pre-line; font-size: 0.95rem; font-weight: 600;", p$FRENTE_MINIMO)
            )
          ),
          div(class = "col-md-3 col-sm-6",
            div(class = "p-3 rounded-3 bg-light border h-100",
              tags$small(class = "text-muted text-uppercase fw-bold d-block mb-1", "Área Libre Mínima"),
              div(style = "white-space: pre-line; font-size: 0.95rem; font-weight: 600;", p$AREA_LIBRE_MIN)
            )
          ),
          div(class = "col-md-6 col-sm-12",
            div(class = "p-3 rounded-3 bg-light border h-100",
              tags$small(class = "text-muted text-uppercase fw-bold d-block mb-1", "Altura Máxima de Edificación"),
              div(style = "white-space: pre-line; font-size: 0.95rem; font-weight: 600; line-height: 1.45;", p$ALTURA_MAXIMA)
            )
          ),
          div(class = "col-md-3 col-sm-6",
            div(class = "p-3 rounded-3 bg-light border h-100",
              tags$small(class = "text-muted text-uppercase fw-bold d-block mb-1", "Coeficiente Edificación"),
              div(style = "white-space: pre-line; font-size: 0.95rem; font-weight: 600;", p$COEFICIENTE_EDIF)
            )
          ),
          div(class = "col-md-3 col-sm-6",
            div(class = "p-3 rounded-3 bg-light border h-100",
              tags$small(class = "text-muted text-uppercase fw-bold d-block mb-1", "Retiro Frontal"),
              div(style = "white-space: pre-line; font-size: 0.95rem; font-weight: 600;", p$RETIRO_FRONTAL)
            )
          )
        ),
        
        # Parámetros complementarios (Estacionamientos y Voladizos)
        if ((!is.na(p$ESTACIONAMIENTOS) && nzchar(trimws(p$ESTACIONAMIENTOS))) ||
            (!is.na(p$VOLADIZOS) && nzchar(trimws(p$VOLADIZOS)))) {
          div(
            class = "row g-3 mb-4",
            if (!is.na(p$ESTACIONAMIENTOS) && nzchar(trimws(p$ESTACIONAMIENTOS))) {
              div(class = "col-md-6",
                div(class = "p-3 rounded-3 bg-light border h-100",
                  tags$small(class = "text-muted text-uppercase fw-bold d-block mb-1", "Estacionamientos Normativos"),
                  div(style = "white-space: pre-line; font-size: 0.9rem;", p$ESTACIONAMIENTOS)
                )
              )
            },
            if (!is.na(p$VOLADIZOS) && nzchar(trimws(p$VOLADIZOS))) {
              div(class = "col-md-6",
                div(class = "p-3 rounded-3 bg-light border h-100",
                  tags$small(class = "text-muted text-uppercase fw-bold d-block mb-1", "Voladizos sobre Retiro / Vía"),
                  div(style = "white-space: pre-line; font-size: 0.9rem;", p$VOLADIZOS)
                )
              )
            }
          )
        },

        # Sección 2: Usos permitidos
        if (!is.na(p$USOS_PERMITIDOS) && nzchar(trimws(p$USOS_PERMITIDOS))) {
          div(
            class = "card border-0 shadow-sm mb-3",
            style = "background: #F4F7F5; border-left: 4px solid #174A3A !important;",
            div(
              class = "card-body py-2 px-3",
              tags$h6(class = "fw-bold mb-1 text-success", icon("check-circle"), " Usos Permitidos"),
              p(class = "mb-0", style = "white-space: pre-line; font-size: 0.92rem; color: #1C2421;", p$USOS_PERMITIDOS)
            )
          )
        },

        # Sección 3: Restricciones
        if (!is.na(p$RESTRICCIONES) && nzchar(trimws(p$RESTRICCIONES)) && !grepl("Sin restricciones adicionales", p$RESTRICCIONES)) {
          div(
            class = "card border-0 shadow-sm mb-3",
            style = "background: #FDF9EE; border-left: 4px solid #D6A43A !important;",
            div(
              class = "card-body py-2 px-3",
              tags$h6(class = "fw-bold mb-1 text-warning-emphasis", icon("triangle-exclamation"), " Restricciones Normativas"),
              p(class = "mb-0", style = "white-space: pre-line; font-size: 0.92rem; color: #5B4413;", p$RESTRICCIONES)
            )
          )
        },

        # Sección 4: Notas de aplicación y condiciones
        if (!is.na(p$NOTAS_APLICACION) && nzchar(trimws(p$NOTAS_APLICACION))) {
          div(
            class = "card border-0 shadow-sm mb-3",
            style = "background: #F8F9FA; border-left: 4px solid #6c757d !important;",
            div(
              class = "card-body py-2 px-3",
              tags$h6(class = "fw-bold mb-1 text-secondary", icon("file-lines"), " Notas de Aplicación"),
              p(class = "mb-0", style = "white-space: pre-line; font-size: 0.88rem; color: #495057;", p$NOTAS_APLICACION)
            )
          )
        },

        # Sección 5: Respaldo legal y fuente institucional
        div(
          class = "d-flex flex-wrap justify-content-between align-items-center gap-2 pt-2 border-top text-muted small",
          div(
            tags$span(class = "fw-semibold", "Fuente oficial: "),
            "Plan de Desarrollo Urbano de Anta (2024 - 2034) — Ordenanza Municipal Nº 04-2025-A-MPA/C"
          ),
          div(
            tags$span(class = "badge bg-light text-secondary border", "PDU Anta 2024 - 2034 — GDUR MPA")
          )
        )
      ),
      size = "xl",
      easyClose = TRUE,
      footer = tagList(
        modalButton(label = "Cerrar", icon = icon("xmark"))
      )
    ))
  })
}
