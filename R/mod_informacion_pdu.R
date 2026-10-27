# ==============================================================================
# MÓDULO: INFORMACIÓN INSTITUCIONAL Y MARCO NORMATIVO DEL PDU
# GeoVisor PDU Anta 2024 - 2034 (GDUR Municipalidad Provincial de Anta)
# ==============================================================================

#' UI para la pestaña de Información Institucional del PDU
#' @return nav_panel con la presentación institucional, ordenanzas y sectorización
mod_informacion_pdu_ui <- function(proyecto_nombre = NULL) {
  if (is.null(proyecto_nombre)) {
    proyecto_nombre <- get0(
      "PROYECTO_NOMBRE_OFICIAL",
      envir = .GlobalEnv,
      ifnotfound = "Mejoramiento de los Servicios de Gestión Territorial y Desarrollo Urbano Sostenible, del distrito de Anta, provincia de Anta, departamento del Cusco"
    )
  }
  nav_panel(
    title = "Información del PDU",
    value = "tab_informacion",
    icon = icon("circle-info"),
    div(
      class = "container-fluid px-2 px-sm-4 py-3",
      
      # HERO BANNER INSTITUCIONAL
      div(
        class = "hero-pdu mb-4",
        div(
          class = "d-flex flex-column flex-md-row align-items-md-center justify-content-between gap-4",
          div(
            class = "d-flex align-items-center gap-3",
            img(src = "escudo_muni_anta.png", style = "height: 65px; width: auto; background: white; padding: 4px; border-radius: 8px;", alt = "Escudo Anta"),
            div(
              tags$h3(class = "fw-bold mb-1 text-white", "PLAN DE DESARROLLO URBANO DE ANTA (2024 - 2034)"),
              tags$h6(class = "mb-2", style = "color: #E2E8F0;", "Municipalidad Provincial de Anta — Gestión Territorial y Desarrollo Urbano Sostenible"),
              div(
                class = "d-flex flex-wrap gap-2 mt-2",
                span(class = "badge", style = "background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.4); font-size: 0.78rem;", icon("calendar-days"), " Vigencia: 2024 - 2034"),
                span(class = "badge", style = "background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.4); font-size: 0.78rem;", icon("certificate"), " O.M. Nº 04-2025-A-MPA/C"),
                span(class = "badge", style = "background: rgba(197, 155, 39, 0.4); border: 1px solid #C59B27; font-size: 0.78rem;", icon("arrows-rotate"), " O.M. N° 008-2026-A-MPA-C (Actualización)")
              )
            )
          ),
          img(src = "pdu_actualizado_sf.png", style = "height: 60px; width: auto; background: white; padding: 4px; border-radius: 8px;", alt = "Logo PDU")
        )
      ),
      
      div(
        class = "card shadow-sm border-0 p-3 p-sm-4 mb-4",
        style = "background-color: #FFFFFF; border-radius: var(--radius-md);",
        
        # 1. DENOMINACIÓN OFICIAL DEL PROYECTO
        div(
          class = "card p-3 p-sm-4 mb-4 text-center shadow-sm border-0",
          style = "background-color: #FDF9EE; border: 1px solid #EADBB6 !important; border-top: 4px solid #C59B27 !important; border-radius: var(--radius-md);",
          tags$div(
            class = "text-uppercase fw-bold mb-2",
            style = "color: #174A3A; font-size: 0.95rem; letter-spacing: 0.5px;",
            icon("folder-open"), " Denominación Oficial del Proyecto:"
          ),
          tags$p(
            class = "mb-0 fw-bold",
            style = "color: #1E293B; font-size: 1.12rem; line-height: 1.5; font-weight: 700; text-align: justify; text-align-last: center; text-justify: inter-word; max-width: 920px; margin-left: auto; margin-right: auto;",
            paste0("«", proyecto_nombre, "»")
          )
        ),
        
        # 2. BLOQUE DE APROBACIÓN LEGAL Y ACTUALIZACIÓN NORMATIVA
        div(
          class = "mb-4",
          div(
            class = "pdu-section-header",
            icon("file-signature", class = "fs-4 text-success"),
            tags$h5("Marco Legal de Aprobación y Vigencia Normativa")
          ),
          div(
            class = "row g-3",
            div(
              class = "col-lg-6 col-md-12",
              div(
                class = "p-3 p-sm-4 pdu-ordenanza-card pdu-ordenanza-card--aprobacion h-100 d-flex flex-column justify-content-between",
                div(
                  div(
                    class = "d-flex justify-content-between align-items-start mb-2",
                    span(class = "badge", style = "background-color: #174A3A; color: white;", icon("stamp"), " Aprobación Primigenia"),
                    span(class = "text-muted small fw-bold", icon("calendar"), " Anta, 11 de abril de 2025")
                  ),
                  tags$h5(class = "fw-bold mb-2", style = "color: #174A3A;", "ORDENANZA MUNICIPAL Nº 04-2025-A-MPA/C"),
                  tags$p(
                    class = "small text-secondary mb-3",
                    "Aprueba formalmente el ", tags$b("Plan de Desarrollo Urbano de Anta (PDU 2024 - 2034)"),
                    " como instrumento técnico-normativo de gestión territorial, planificación del uso de suelo y acondicionamiento urbano sostenible para la provincia de Anta."
                  ),
                  div(
                    class = "p-2 rounded-2 mb-3",
                    style = "background-color: #EEF5F1; border-left: 3px solid #174A3A;",
                    tags$small(
                      class = "fw-semibold", style = "color: #174A3A;",
                      icon("newspaper"), " Publicada oficialmente en el Diario Oficial El Peruano"
                    )
                  )
                ),
                div(
                  class = "d-flex flex-wrap gap-2 pt-2 border-top",
                  tags$a(
                    href = "https://busquedas.elperuano.pe/dispositivo/NL/2407024-1",
                    target = "_blank",
                    rel = "noopener",
                    class = "btn btn-outline-success btn-sm fw-bold",
                    icon("arrow-up-right-from-square"), " Ver en El Peruano"
                  ),
                  tags$a(
                    href = "aprobacion/ORDENANZA%20MUNICIPAL%20N%C2%B0004-2025-A-MPA-C.pdf",
                    target = "_blank",
                    class = "btn btn-outline-secondary btn-sm",
                    icon("file-pdf"), " Descargar Ordenanza (PDF)"
                  ),
                  tags$a(
                    href = "aprobacion/ORDENANZA%20MUNICIPAL%20N%C2%B0004-2025-A-MPA-C_EL_PERUANO.pdf",
                    target = "_blank",
                    class = "btn btn-outline-secondary btn-sm",
                    icon("file-lines"), " Facsímil El Peruano (PDF)"
                  )
                )
              )
            ),
            div(
              class = "col-lg-6 col-md-12",
              div(
                class = "p-3 p-sm-4 pdu-ordenanza-card pdu-ordenanza-card--actualizacion h-100 d-flex flex-column justify-content-between",
                div(
                  div(
                    class = "d-flex justify-content-between align-items-start mb-2",
                    span(class = "badge", style = "background-color: #B68A2C; color: white;", icon("arrows-rotate"), " Actualización Oficial Vigente"),
                    span(class = "text-muted small fw-bold", icon("calendar"), " Anta, 04 de septiembre del 2026")
                  ),
                  tags$h5(class = "fw-bold mb-2", style = "color: #86651F;", "ORDENANZA MUNICIPAL N° 008-2026-A-MPA-C"),
                  tags$p(
                    class = "small text-secondary mb-3",
                    "Aprueba la ", tags$b("actualización, adecuación técnica y precisiones normativas"),
                    " del Plan de Desarrollo Urbano de Anta (2024 - 2034) para consolidar su concordancia territorial, delimitación de sectores, parámetros urbanísticos y dinámica conurbada."
                  ),
                  div(
                    class = "p-2 rounded-2 mb-3",
                    style = "background-color: #FBF7EB; border-left: 3px solid #B68A2C;",
                    tags$small(
                      class = "fw-semibold", style = "color: #86651F;",
                      icon("circle-check"), " Instrumento legal vigente aplicable en la jurisdicción provincial"
                    )
                  )
                ),
                div(
                  class = "d-flex flex-wrap gap-2 pt-2 border-top",
                  tags$a(
                    href = "aprobacion/ORDENANZA%20MUNICIPAL%20N%C2%B0008-2026-A-MPA-C.pdf",
                    target = "_blank",
                    class = "btn btn-outline-warning btn-sm fw-bold text-dark",
                    style = "border-color: #B68A2C;",
                    icon("file-pdf"), " Descargar Ordenanza de Actualización (PDF)"
                  )
                )
              )
            )
          )
        ),
        
        # 3. ÁMBITO DE INTERVENCIÓN Y CONTINUIDAD URBANA
        div(
          class = "mb-4",
          div(
            class = "pdu-section-header",
            icon("map-location-dot", class = "fs-4 text-success"),
            tags$h5("Ámbito de Intervención Territorial")
          ),
          tags$p(
            class = "lead mb-3", style = "font-size: 1.05rem; line-height: 1.6; color: #1E293B;",
            "El PDU Anta abarca ", tags$b(style = "color: #174A3A;", "9,469.35 ha"),
            ", conformadas por ", tags$b(style = "color: #174A3A;", "55 continuos poblados"),
            ". Incluye la ciudad menor de Anta (capital provincial, departamento de Cusco) y los centros poblados rurales inmediatos, como Chacan, Compone, Inquilpata, Cconchacalla, Markjo y Mosocllacta. Todos forman parte de una misma continuidad física, social, económica y funcional. La delimitación del ámbito de intervención se basa en el ",
            tags$b("art. 44°"), " del Reglamento de Acondicionamiento Territorial y Planificación Urbana del Desarrollo Urbano Sostenible (",
            tags$b("D.S. N° 012-2022-VIVIENDA"), ")."
          ),
          
          # Mini-KPIs del Ámbito
          div(
            class = "row g-3 mb-4",
            div(
              class = "col-md-4 col-sm-6",
              div(
                class = "pdu-kpi-box",
                div(class = "pdu-kpi-icon pdu-kpi-icon--green", icon("maximize")),
                div(
                  tags$small(class = "text-muted text-uppercase fw-bold", "Superficie Reglamentada"),
                  tags$h4(class = "mb-0 fw-bold", style = "color: #174A3A;", "9,469.35 ha")
                )
              )
            ),
            div(
              class = "col-md-4 col-sm-6",
              div(
                class = "pdu-kpi-box",
                div(class = "pdu-kpi-icon pdu-kpi-icon--green", icon("city")),
                div(
                  tags$small(class = "text-muted text-uppercase fw-bold", "Integración Territorial"),
                  tags$h4(class = "mb-0 fw-bold", style = "color: #174A3A;", "55 Continuos Poblados")
                )
              )
            ),
            div(
              class = "col-md-4 col-sm-12",
              div(
                class = "pdu-kpi-box",
                div(class = "pdu-kpi-icon pdu-kpi-icon--gold", icon("scale-balanced")),
                div(
                  tags$small(class = "text-muted text-uppercase fw-bold", "Base Normativa"),
                  tags$h6(class = "mb-0 fw-bold", style = "color: #86651F;", "Art. 44° RATDUS (D.S. 012-2022)")
                )
              )
            )
          ),
          
          # EJES DE PROXIMIDAD
          tags$h6(class = "fw-bold mb-3", style = "color: #174A3A;", icon("route"), " Ejes de Proximidad y Articulación Vial:"),
          div(
            class = "row g-3",
            div(
              class = "col-md-4",
              div(
                class = "p-3 pdu-eje-card h-100",
                div(class = "pdu-eje-badge", icon("compass"), " Eje Noroeste"),
                tags$h6(class = "fw-bold text-dark mb-1", "Vía CU-110 (Izcuchaca - Huarocondo)"),
                tags$p(class = "small text-muted mb-2", "Desde el núcleo urbano de Anta por la CU-110 vía Izcuchaca - Huarocondo:"),
                div(
                  class = "p-2 rounded bg-light border small",
                  tags$b(style = "color: #174A3A;", icon("location-dot"), " Centros Poblados: "),
                  "Chacacurqui, Haparquilla y Markjo."
                )
              )
            ),
            div(
              class = "col-md-4",
              div(
                class = "p-3 pdu-eje-card h-100",
                div(class = "pdu-eje-badge", icon("road"), " Eje Suroeste"),
                tags$h6(class = "fw-bold text-dark mb-1", "PE-3S & Ramal PE-3SF"),
                tags$p(class = "small text-muted mb-2", "Por la PE-3S – vía nacional Cusco Abancay y el ramal PE-3SF vía nacional Cusco - Cotabambas:"),
                div(
                  class = "p-2 rounded bg-light border small",
                  tags$b(style = "color: #174A3A;", icon("location-dot"), " Centros Poblados: "),
                  "Hospital Pampa, Inquilpata, Compone y Cconchacalla."
                )
              )
            ),
            div(
              class = "col-md-4",
              div(
                class = "p-3 pdu-eje-card h-100",
                div(class = "pdu-eje-badge", icon("mountain-sun"), " Eje Chacan"),
                tags$h6(class = "fw-bold text-dark mb-1", "Vía CU-111 (Izcuchaca - Urubamba)"),
                tags$p(class = "small text-muted mb-2", "Por la CU-111 vía Izcuchaca - Urubamba:"),
                div(
                  class = "p-2 rounded bg-light border small",
                  tags$b(style = "color: #174A3A;", icon("location-dot"), " Centros Poblados: "),
                  "Santa Ana, Agua Dulce, Lucre Acconhuaylla, Santiago y Chillapucjio."
                )
              )
            )
          )
        ),
        
        # 4. SECTORIZACIÓN URBANA
        div(
          class = "mb-4 pt-3 border-top",
          div(
            class = "pdu-section-header",
            icon("layer-group", class = "fs-4 text-success"),
            tags$h5("Sectorización Urbana")
          ),
          tags$p(
            class = "mb-3", style = "font-size: 0.98rem; line-height: 1.55; color: #1E293B;",
            "Los sectores identifican áreas homogéneas de la trama urbana. Se definieron según estos criterios: ",
            tags$b("elementos divisorios"), " (ríos, vías), ",
            tags$b("geomorfología"), " (planicies o laderas), ",
            tags$b("dinámica urbana"), ", ",
            tags$b("tejido urbano"), " (discontinuo y disperso), ",
            tags$b("conurbación"), " (núcleo Anta–Izcuchaca–Nueva Anta) y ",
            tags$b("discontinuidad física"),
            ". El ámbito se extiende por conurbación a los distritos de ",
            tags$b("Pucyura, Huarocondo y Zurite"), "."
          ),
          
          # Chips de Criterios
          div(
            class = "mb-3",
            span(class = "pdu-criterio-chip", icon("water"), " Elementos divisorios (ríos, vías)"),
            span(class = "pdu-criterio-chip", icon("mountain"), " Geomorfología (planicies o laderas)"),
            span(class = "pdu-criterio-chip", icon("chart-line"), " Dinámica urbana"),
            span(class = "pdu-criterio-chip", icon("border-all"), " Tejido urbano (discontinuo y disperso)"),
            span(class = "pdu-criterio-chip", icon("city"), " Conurbación (núcleo Anta–Izcuchaca–Nueva Anta)"),
            span(class = "pdu-criterio-chip", icon("arrows-split-up-and-left"), " Discontinuidad física e interdistrital")
          ),
          
          # Tabla de Sectores
          div(
            class = "table-responsive mt-3",
            tags$table(
              class = "pdu-sector-table",
              tags$thead(
                tags$tr(
                  tags$th(style = "width: 15%;", "Sector"),
                  tags$th(style = "width: 15%; text-align: right;", "Área (ha)"),
                  tags$th(style = "width: 18%; text-align: center;", "% del total"),
                  tags$th("Centros poblados principales")
                )
              ),
              tags$tbody(
                tags$tr(
                  tags$td(tags$b(style = "color: #174A3A;", "Sector I")),
                  tags$td(style = "text-align: right; font-weight: 600;", "2,973.65 ha"),
                  tags$td(
                    div(class = "d-flex flex-column align-items-center",
                      span(class = "fw-bold", "31.4 %"),
                      div(class = "pdu-mini-progress w-75",
                        div(class = "pdu-mini-progress-bar", style = "width: 31.4%;")
                      )
                    )
                  ),
                  tags$td("Chacan (Santa Ana, Santiago, Agua Dulce, Lucre, Chico, Chillapucjio), Munaypata, Pancarhuaylla, Llaulliray, Tantañay, Acconhuaylla")
                ),
                tags$tr(
                  tags$td(tags$b(style = "color: #174A3A;", "Sector II")),
                  tags$td(style = "text-align: right; font-weight: 600;", "3,677.79 ha"),
                  tags$td(
                    div(class = "d-flex flex-column align-items-center",
                      span(class = "fw-bold", "38.8 %"),
                      div(class = "pdu-mini-progress w-75",
                        div(class = "pdu-mini-progress-bar", style = "width: 38.8%;")
                      )
                    )
                  ),
                  tags$td("Anta, Izcuchaca, Nueva Anta, Compone, Inquilpata, Yungaqui, Pacca, Kehuar, Piñanccay, Lluscanay, Chacacurqui, Pichoc, Hospitalpampa, entre otros")
                ),
                tags$tr(
                  tags$td(tags$b(style = "color: #174A3A;", "Sector III")),
                  tags$td(style = "text-align: right; font-weight: 600;", "2,817.91 ha"),
                  tags$td(
                    div(class = "d-flex flex-column align-items-center",
                      span(class = "fw-bold", "29.8 %"),
                      div(class = "pdu-mini-progress w-75",
                        div(class = "pdu-mini-progress-bar", style = "width: 29.8%;")
                      )
                    )
                  ),
                  tags$td("Sangarará, Huerta, Markjo, Siuna, San Juan Bosco, San Marcos, Occoruro, Mosocllacta, San José, Pampallamaq, Haparquilla")
                )
              ),
              tags$tfoot(
                tags$tr(
                  tags$td(tags$b("TOTAL PDU")),
                  tags$td(style = "text-align: right; font-weight: 700;", "9,469.35 ha"),
                  tags$td(style = "text-align: center; font-weight: 700;", "100.0 %"),
                  tags$td(tags$b("Ámbito Integral del Plan de Desarrollo Urbano de Anta (55 continuos poblados conurbados)"))
                )
              )
            )
          )
        ),
        
        # 5. COMPONENTES ESTRUCTURANTES: SISTEMA VIAL Y SERVIDUMBRES
        div(
          class = "mb-4 pt-3 border-top",
          div(
            class = "pdu-section-header",
            icon("network-wired", class = "fs-4 text-success"),
            tags$h5("Componentes Estructurantes del Modelo Territorial")
          ),
          div(
            class = "row g-3",
            div(
              class = "col-md-6",
              div(
                class = "p-3 p-sm-4 bg-light rounded-3 border h-100",
                h5(class = "fw-bold mb-2", style = "color: #174A3A;", icon("road"), " Sistema Vial Propuesto y Secciones Normativas"),
                p(
                  "El Sistema Vial Propuesto establece la jerarquización de la red vial en ",
                  tags$b("Sistema Vial Provincial-Metropolitano, Primario, Secundario y Especial"),
                  ", determinando para cada eje el código de vía y su ",
                  tags$b("Sección Vial Normativa (SV en metros lineales)"),
                  " para asegurar la reserva obligatoria del derecho de vía y la transitabilidad futura ordenada."
                )
              )
            ),
            div(
              class = "col-md-6",
              div(
                class = "p-3 p-sm-4 bg-light rounded-3 border h-100",
                h5(class = "fw-bold mb-2", style = "color: #174A3A;", icon("bolt"), " Servidumbres Eléctricas y Ferroviarias"),
                p(
                  "Comprende las fajas de servidumbre de líneas de alta tensión (",
                  tags$b("138 kV - L-1007"), " y ", tags$b("220 kV - L-1002"),
                  " de 20 m y 25 m de ancho) y la zona de influencia y derecho de vía del ",
                  tags$b("Ferrocarril Trasandino"), " (D.S. N° 032-2005-MTC), que restringen edificaciones para salvaguardar la seguridad pública."
                )
              )
            )
          )
        ),
        
        # 6. MARCO NORMATIVO ASOCIADO A LA PLANIFICACIÓN URBANA
        div(
          class = "mb-4 pt-3 border-top",
          div(
            class = "p-3 p-sm-4 bg-white rounded-3 border",
            h5(class = "fw-bold mb-2", style = "color: #174A3A;", icon("gavel"), " Normativa Nacional Asociada a la Planificación Urbana"),
            p(class = "text-muted small", "Marco normativo de referencia del PDU de Anta, resumido a partir de los documentos legales de la carpeta normativa:"),
            tags$ul(
              class = "mb-3",
              tags$li(
                tags$b("Ley N.º 31313 — Ley de Desarrollo Urbano Sostenible: "),
                "establece el marco nacional para el acondicionamiento territorial, la planificación urbana y la gestión del suelo, con principios de sostenibilidad, equidad, participación y gestión del riesgo. ",
                tags$a("Ver texto oficial", href = "https://busquedas.elperuano.pe/dispositivo/NL/1976352-2", target = "_blank", rel = "noopener")
              ),
              tags$li(
                tags$b("D.S. N.º 012-2022-VIVIENDA — RATDUS: "),
                "reglamenta los procesos e instrumentos de planificación, incluido el PDU y sus etapas de formulación, participación, aprobación, implementación y actualización. ",
                tags$a("Ver norma en el MVCS", href = "https://www.gob.pe/institucion/vivienda/normas-legales/3588833-012-2022-vivienda", target = "_blank", rel = "noopener")
              ),
              tags$li(
                tags$b("D.Leg. N.º 1674: "),
                "modifica la Ley N.º 31313 y refuerza la planificación urbana y rural, la gestión del suelo, la participación ciudadana y la gestión del riesgo. ",
                tags$a("Ver texto oficial", href = "https://busquedas.elperuano.pe/dispositivo/NL/2329855-10", target = "_blank", rel = "noopener")
              )
            ),
            p(class = "small text-muted mb-0", "El PDU aplica este marco mediante su zonificación, clasificación del suelo, parámetros urbanísticos y sistema vial. Para trámites o licencias sobre predios específicos, aplican las ordenanzas municipales citadas y las normas del Reglamento Nacional de Edificaciones (RNE).")
          )
        )
      )
    )
  )
}
