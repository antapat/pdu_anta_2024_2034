# ==============================================================================
# MÓDULO: AVISO LEGAL, TÉRMINOS DE USO Y POLÍTICA DE PRIVACIDAD
# GeoVisor PDU Anta 2024 - 2034 (GDUR Municipalidad Provincial de Anta)
# Cumplimiento: Ley N° 29733 (Datos Personales), RATDUS (D.S. 012-2022)
# ==============================================================================

#' Construye y muestra la ventana modal del Aviso Legal y Privacidad
#' @param es_inicio Lógico. Si es TRUE, el modal actúa como bienvenida bloqueante.
mostrar_modal_privacidad <- function(es_inicio = FALSE) {
  showModal(modalDialog(
    title = NULL,
    size = "l",
    easyClose = !es_inicio, # Al iniciar la app es modal de ingreso bloqueante
    fade = TRUE,
    footer = NULL,

    div(
      class = "pdu-onboarding-modal-wrap p-2 p-md-3",

      # Cabecera Institucional Unificada
      div(
        class = "text-center mb-3",
        div(
          class = "d-flex align-items-center justify-content-center gap-2 mb-1",
          tags$img(src = "escudo_muni_anta.png", height = "46px", alt = "Escudo Anta", onerror = "this.style.display='none'"),
          div(
            class = "text-start",
            div(class = "fw-bold text-dark fs-5 text-uppercase", style = "letter-spacing: 0.5px;", "Municipalidad Provincial de Anta"),
            div(class = "text-muted small", "Gerencia de Desarrollo Urbano y Rural · GeoVisor PDU (2024 - 2034)")
          )
        ),
        
        # Título y Stepper estructurado de Onboarding
        div(
          class = "mt-3",
          tags$h3(class = "fw-bold text-dark mb-1", style = "letter-spacing: -0.5px;", "Aviso Legal y Condiciones de Uso"),
          div(
            class = "sunarp-multibar mx-auto mb-2",
            style = "height: 4px; width: 140px; border-radius: 2px; background: linear-gradient(to right, #00A896 25%, #028090 25% 50%, #F4A261 50% 75%, #E63946 75%);"
          ),
          if (es_inicio) {
            div(
              class = "pdu-stepper-container d-inline-flex align-items-center gap-2 px-3 py-1 rounded-pill bg-light border mb-1",
              span(class = "badge bg-success rounded-pill px-2 py-1 text-white shadow-xs", icon("shield-halved"), " Paso 1 de 2: Términos y Condiciones"),
              icon("chevron-right", class = "text-muted small"),
              span(class = "badge bg-white text-muted border rounded-pill px-2 py-1", icon("id-card"), " Paso 2: Validación con DNI")
            )
          }
        )
      ),

      div(
        class = "privacy-modal-body p-2",
        style = "text-align: justify; max-height: 52vh; overflow-y: auto; padding-right: 8px;",

      # Alerta de Carácter Informativo y Legal
      div(
        class = "p-3 mb-3 rounded-2 border",
        style = "background-color: #FEF3C7; border-color: #F59E0B !important; color: #92400E;",
        div(class = "fw-bold small d-flex align-items-center gap-2", icon("triangle-exclamation"), "Aviso Legal y Carácter Informativo:"),
        tags$p(class = "small mb-0 mt-1",
          "La información cartográfica, zonificación, secciones viales y parámetros contenidos en esta plataforma son de carácter ", tags$b("exclusivamente informativo y referencial"), ". ",
          "No constituye certificado oficial ni genera derechos urbanísticos o de edificación. ",
          "Cualquier trámite formal de habilitación urbana o licencias de edificación debe tramitarse ante la ",
          tags$b("Gerencia de Desarrollo Urbano y Rural (GDUR)"), " de la Municipalidad Provincial de Anta."
        )
      ),

      div(
        class = "alert alert-success border-0 py-2 px-3 mb-3 d-flex align-items-center gap-2",
        icon("certificate"),
        tags$span(class = "small", tags$b("Marco Normativo de Cumplimiento: "), "Ley N° 29733 (Ley de Protección de Datos Personales del Perú), D.S. N° 003-2013-JUS, R.D. N° 019-2013-JUS/DGPDP (Directiva de Seguridad), Ley N° 27972 (Ley Orgánica de Municipalidades), D.S. N° 012-2022-VIVIENDA (RATPUDUS) y estándares internacionales de privacidad (RGPD / ISO 27001).")
      ),

      tags$h6(class = "fw-bold text-success mb-1", icon("landmark"), " 1. Entidad Responsable y Banco de Datos"),
      tags$p(
        class = "small text-secondary mb-3",
        "El tratamiento de datos es efectuado por la ", tags$b("Municipalidad Provincial de Anta"), " (Plaza de Armas s/n, Anta, Cusco) a través de la ", tags$b("Gerencia de Desarrollo Urbano y Rural (GDUR)"), ". ",
        "Los datos recabados forman parte del banco de datos institucional ", tags$i("«Usuarios del GeoVisor PDU Anta»"), ", gestionado bajo medidas de seguridad técnicas y organizativas para garantizar su confidencialidad e integridad."
      ),

      tags$h6(class = "fw-bold text-success mb-1", icon("database"), " 2. Finalidades Determinadas y Explícitas (Art. 6 Ley 29733)"),
      tags$ul(class = "small text-secondary mb-3",
        tags$li(tags$b("Control de Acceso Equitativo: "), "Garantizar la disponibilidad del servicio y prevenir la saturación de los servidores mediante un límite de 2 periodos de 10 minutos por día por ciudadano."),
        tags$li(tags$b("Generación de Fichas Informativas: "), "Emitir reportes cartográficos preliminares referenciales de zonificación y vías a solicitud expresa del usuario.")
      ),

      tags$h6(class = "fw-bold text-success mb-1", icon("list-check"), " 3. Carácter Obligatorio o Facultativo de la Entrega de Datos"),
      tags$ul(class = "small text-secondary mb-3",
        tags$li(tags$b("Datos Obligatorios para Acceso: "), "El número de DNI y su fecha de emisión son indispensables para verificar la identidad ciudadana y habilitar la sesión temporal. La negativa a suministrarlos impide el acceso al visor web interactivo, pudiendo el ciudadano consultar el PDU de manera presencial en la sede municipal."),
        tags$li(tags$b("Datos Facultativos: "), "La geolocalización GPS en el mapa es estrictamente voluntaria (Opt-In) y solo se procesa bajo autorización expresa en el navegador para centrar el mapa en la posición actual del usuario.")
      ),

      tags$h6(class = "fw-bold text-success mb-1", icon("user-shield"), " 4. Medidas de Seguridad, Pseudonimización y Retención Temporal"),
      tags$ul(class = "small text-secondary mb-3",
        tags$li(tags$b("Cifrado Hash Irreversible: "), "Los números de DNI no se almacenan en texto plano en la base de datos de sesiones; se procesan mediante funciones criptográficas unidireccionales (SHA-256) con sal institucional del servidor."),
        tags$li(tags$b("Enmascaramiento en Bitácoras: "), "Los registros de auditoría protegen la privacidad de los ciudadanos enmascarando los documentos (ej. 47****15) conforme a la Directiva de Seguridad de la ANPD."),
        tags$li(tags$b("Depuración Automática (Plazo de Conservación): "), "Los registros de control de cuotas se eliminan automáticamente cada 7 días, cumpliendo con el principio de limitación de conservación."),
        tags$li(tags$b("Sin Transferencias ni Fines Comerciales: "), "La plataforma no utiliza cookies publicitarias, no cede datos a terceros y procesa las coordenadas geográficas únicamente en memoria volátil de sesión.")
      ),

      tags$h6(class = "fw-bold text-success mb-1", icon("address-card"), " 5. Ejercicio de Derechos ARCO (Acceso, Rectificación, Cancelación y Oposición)"),
      tags$p(class = "small text-secondary mb-0",
        "El titular de los datos personales puede ejercer sus derechos ARCO de forma gratuita conforme a la Ley N° 29733 y el D.S. N° 003-2013-JUS, dirigiendo una solicitud a la Gerencia de Desarrollo Urbano y Rural al correo ",
        tags$b("gdur@munidistritoanta.gob.pe"), " o presencialmente en la Mesa de Partes de la Municipalidad Provincial de Anta (Plaza de Armas s/n, Anta, Cusco)."
      )
    ),

    # Pie de Acciones Estructurado
    div(
      class = "pt-3 mt-3 border-top",
      if (es_inicio) {
        div(
          class = "d-flex flex-column flex-sm-row justify-content-between align-items-center gap-3",
          div(
            class = "small text-muted d-flex align-items-center gap-2",
            icon("circle-info", class = "text-success"),
            tags$span("Al continuar, acepta las condiciones y procede a la validación con DNI.")
          ),
          tags$button(
            type = "button",
            class = "btn btn-lg fw-bold text-white shadow-sm px-4",
            style = "background-color: #174A3A; border-color: #0E3529; border-radius: 8px; font-size: 0.95rem;",
            onclick = "aceptarTerminosYProceder();",
            icon("arrow-right"), " Aceptar y Continuar a Validar DNI"
          )
        )
      } else {
        div(
          class = "text-center",
          tags$button(
            type = "button",
            class = "btn btn-secondary fw-semibold px-4 py-2",
            style = "border-radius: 8px;",
            onclick = "$('#shiny-modal').modal('hide');",
            icon("xmark"), " Cerrar y Volver al Visor"
          )
        )
      }
    )
  )))
}

#' UI para la pestaña completa de Política de Privacidad y Términos de Uso
#' @return nav_panel estructurado de forma semejante a Información del PDU
mod_privacidad_ui <- function() {
  nav_panel(
    title = "Aviso Legal y Privacidad",
    value = "tab_privacidad",
    icon = icon("shield-halved"),
    
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
              tags$h3(class = "fw-bold mb-1 text-white", "POLÍTICA DE PRIVACIDAD, AVISO LEGAL Y TÉRMINOS DE USO"),
              tags$h6(class = "mb-2", style = "color: #E2E8F0;", "Municipalidad Provincial de Anta — Gerencia de Desarrollo Urbano y Rural (GDUR)"),
              div(
                class = "d-flex flex-wrap gap-2 mt-2",
                span(class = "badge", style = "background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.4); font-size: 0.78rem;", icon("scale-balanced"), " Ley N° 29733 (Protección de Datos)"),
                span(class = "badge", style = "background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.4); font-size: 0.78rem;", icon("certificate"), " D.S. N° 003-2013-JUS / R.D. N° 019-2013-JUS"),
                span(class = "badge", style = "background: rgba(197, 155, 39, 0.4); border: 1px solid #C59B27; font-size: 0.78rem;", icon("lock"), " Cifrado SHA-256 / Anonimización Técnica")
              )
            )
          ),
          img(src = "pdu_actualizado_sf.png", style = "height: 60px; width: auto; background: white; padding: 4px; border-radius: 8px;", alt = "Logo PDU")
        )
      ),
      
      # TARJETA PRINCIPAL DE CONTENIDO ESTRUCTURADO
      div(
        class = "card shadow-sm border-0 p-3 p-sm-4 mb-4",
        style = "background-color: #FFFFFF; border-radius: var(--radius-md);",
        
        # Barra superior con botón para regresar al mapa
        div(
          class = "d-flex flex-column flex-sm-row justify-content-between align-items-stretch align-items-sm-center gap-2 pb-3 mb-4 border-bottom",
          actionButton(
            "btn_volver_al_visor_desde_privacidad",
            "← Volver al Visor Territorial",
            class = "btn btn-outline-success fw-bold",
            icon = icon("map-location-dot")
          ),
          span(class = "badge bg-light text-muted border px-3 py-2", icon("clock"), " Sesión ciudadana regulada a 10 minutos (máximo 2 diarias)")
        ),
        
        # ALERTA DE CARÁCTER INFORMATIVO Y LEGAL
        div(
          class = "p-3 mb-4 rounded-3 border",
          style = "background-color: #FEF3C7; border-color: #F59E0B !important; color: #92400E;",
          div(class = "fw-bold small d-flex align-items-center gap-2", icon("triangle-exclamation", class = "fs-5"), "Carácter Exclusivamente Informativo y Referencial:"),
          tags$p(class = "small mb-0 mt-2", style = "line-height: 1.6;",
            "La información cartográfica, zonificación, secciones viales y parámetros contenidos en esta plataforma son de carácter ", tags$b("exclusivamente informativo y referencial"), ". ",
            "No constituye certificado oficial ni genera derechos urbanísticos o de edificación. ",
            "Cualquier trámite formal de habilitación urbana o licencias de edificación debe tramitarse ante la ",
            tags$b("Gerencia de Desarrollo Urbano y Rural (GDUR)"), " de la Municipalidad Provincial de Anta."
          )
        ),
        
        # SECCIÓN 1: ENTIDAD RESPONSABLE Y BANCO DE DATOS
        div(
          class = "mb-4 pb-3 border-bottom",
          div(
            class = "d-flex align-items-center gap-2 mb-2",
            icon("landmark", class = "fs-5 text-success"),
            tags$h5(class = "fw-bold mb-0 text-dark", "1. Entidad Responsable y Titularidad del Banco de Datos")
          ),
          tags$p(class = "small text-secondary mb-2", style = "line-height: 1.6;",
            "El tratamiento de datos es efectuado por la ", tags$b("Municipalidad Provincial de Anta"),
            " (RUC: 20146091219, Plaza de Armas s/n, distrito y provincia de Anta, departamento del Cusco), a través de la ",
            tags$b("Gerencia de Desarrollo Urbano y Rural (GDUR)"), ". ",
            "Los datos de acceso recabados forman parte del banco de datos institucional ",
            tags$i("«Usuarios del GeoVisor PDU Anta»"), ", gestionado bajo estrictas medidas de seguridad técnicas y organizativas para garantizar su confidencialidad e integridad (Nivel Medio según D.S. N° 003-2013-JUS)."
          )
        ),
        
        # SECCIÓN 2: FINALIDADES DETERMINADAS Y LEGÍTIMAS
        div(
          class = "mb-4 pb-3 border-bottom",
          div(
            class = "d-flex align-items-center gap-2 mb-2",
            icon("database", class = "fs-5 text-success"),
            tags$h5(class = "fw-bold mb-0 text-dark", "2. Finalidades Determinadas y Explícitas (Art. 6 Ley 29733)")
          ),
          tags$p(class = "small text-secondary mb-2", "La plataforma tiene fines estrictamente públicos, informativos y de transparencia en el marco de la vigencia del Plan de Desarrollo Urbano de Anta (2024 - 2034) aprobado por O.M. Nº 04-2025-A-MPA/C y actualizado por O.M. N° 008-2026-A-MPA-C:"),
          tags$ul(class = "small text-secondary mb-0", style = "line-height: 1.7;",
            tags$li(tags$b("Control de Acceso Equitativo: "), "Garantizar la disponibilidad del servicio y prevenir la saturación de los servidores mediante un límite de 2 periodos de 10 minutos por día por ciudadano."),
            tags$li(tags$b("Generación de Fichas Informativas: "), "Emitir reportes cartográficos preliminares referenciales de zonificación y vías a solicitud expresa del usuario."),
            tags$li(tags$b("Transparencia Activa: "), "Poner a disposición ciudadana los planos de zonificación, secciones de vías y parámetros urbanísticos y edificatorios según el D.S. N° 012-2022-VIVIENDA.")
          )
        ),
        
        # SECCIÓN 3: OBLIGATORIEDAD VS FACULTATIVIDAD
        div(
          class = "mb-4 pb-3 border-bottom",
          div(
            class = "d-flex align-items-center gap-2 mb-2",
            icon("list-check", class = "fs-5 text-success"),
            tags$h5(class = "fw-bold mb-0 text-dark", "3. Carácter Obligatorio o Facultativo de la Entrega de Datos")
          ),
          tags$ul(class = "small text-secondary mb-0", style = "line-height: 1.7;",
            tags$li(tags$b("Datos Obligatorios para Acceso: "), "El número de DNI y su fecha de emisión son indispensables para verificar la identidad ciudadana e impedir accesos automatizados (robots). La negativa a suministrarlos impide el acceso al visor web interactivo, pudiendo el ciudadano consultar el PDU de manera presencial en la sede municipal."),
            tags$li(tags$b("Datos Facultativos (GPS Móvil): "), "La geolocalización GPS en el mapa es estrictamente voluntaria (Opt-In) y solo se procesa bajo autorización expresa en el navegador para centrar el mapa en la posición actual del usuario. Las coordenadas no son almacenadas.")
          )
        ),
        
        # SECCIÓN 4: MEDIDAS DE SEGURIDAD Y PRIVACIDAD POR DISEÑO
        div(
          class = "mb-4 pb-3 border-bottom",
          div(
            class = "d-flex align-items-center gap-2 mb-2",
            icon("user-shield", class = "fs-5 text-success"),
            tags$h5(class = "fw-bold mb-0 text-dark", "4. Medidas de Seguridad, Pseudonimización y Retención Temporal")
          ),
          tags$ul(class = "small text-secondary mb-0", style = "line-height: 1.7;",
            tags$li(tags$b("Seudonimización Criptográfica Irreversible: "), "Los números de DNI no se almacenan en texto plano en la base de datos de sesiones; se procesan mediante funciones criptográficas unidireccionales (SHA-256) con sal institucional del servidor."),
            tags$li(tags$b("Enmascaramiento en Bitácoras: "), "Los registros de auditoría protegen la privacidad de los ciudadanos enmascarando los documentos (ej. 47****15) conforme a la Directiva de Seguridad de la ANPD."),
            tags$li(tags$b("Depuración Automática (Plazo de Conservación de 7 Días): "), "Los registros de control de cuotas se eliminan automáticamente cada 7 días, cumpliendo con el principio de limitación de conservación."),
            tags$li(tags$b("Sin Cookies Comerciales ni Rastreadores: "), "No se emplean cookies publicitarias ni de redes sociales (sin rastreadores externos ni cesión a terceros)."),
            tags$li(tags$b("Consultas de Predios Seguras: "), "Las coordenadas o polígonos consultados por los ciudadanos se procesan en memoria volátil de sesión y no se asocian a datos comerciales.")
          )
        ),
        
        # SECCIÓN 5: DERECHOS ARCO
        div(
          class = "mb-2",
          div(
            class = "d-flex align-items-center gap-2 mb-2",
            icon("address-card", class = "fs-5 text-success"),
            tags$h5(class = "fw-bold mb-0 text-dark", "5. Ejercicio de Derechos ARCO (Acceso, Rectificación, Cancelación y Oposición)")
          ),
          tags$p(class = "small text-secondary mb-0", style = "line-height: 1.6;",
            "El titular de los datos personales puede ejercer sus derechos ARCO de forma gratuita conforme a la Ley N° 29733 y el D.S. N° 003-2013-JUS, dirigiendo una solicitud a la Gerencia de Desarrollo Urbano y Rural al correo ",
            tags$b("gdur@munidistritoanta.gob.pe"), " o presencialmente en la Mesa de Partes de la Municipalidad Provincial de Anta (Plaza de Armas s/n, Anta, Cusco)."
          )
        )
      )
    )
  )
}

#' Lógica de servidor para la pestaña de privacidad
#' @param input Objeto input de Shiny
#' @param output Objeto output de Shiny
#' @param session Objeto session de Shiny
mod_privacidad_server <- function(input, output, session) {
  # Navegación hacia la pestaña de privacidad desde cualquier enlace o botón
  observeEvent(input$abrir_modal_privacidad, {
    nav_select("main_navbar", "tab_privacidad")
  })
  
  # Botón para volver al mapa desde la pestaña de privacidad
  observeEvent(input$btn_volver_al_visor_desde_privacidad, {
    nav_select("main_navbar", "tab_visor")
  })
}

#' Alias retrocompatible para llamadas previas
mod_privacidad_link_ui <- mod_privacidad_ui

