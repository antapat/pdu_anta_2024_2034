# Matriz informativa existente; pendiente de validación municipal.
df_parametros <- data.frame(
  COD_S_ZONA = c(
    "ZDA - C", "ZDA - S",
    "ZDM - C - I", "ZDM - C - II", "ZDM - S - I", "ZDM - S - II", "ZDM - CR - I", "ZDM - CR - II",
    "ZDB - C - I", "ZDB - C - II", "ZDB - S - I", "ZDB - S - II", "ZDB - CR - I", "ZDB - CR - II",
    "ZDMB - S - I", "ZDMB - S - II", "ZDMB - S - III", "ZDMB - CR",
    "I1", "I2",
    "E1", "E1?", "E2",
    "H1", "H2", "H3",
    "ZRP", "ZOU", "ZA", "ZM",
    "ZPA - CE", "ZPA - IERE", "ZPA - RH",
    "ZRE - NU - P", "ZRE - NU - RE", "ZRE - PMA - S", "ZRE - VHC - CH", "ZRE - CBIP", "ZRE - PA - C", "ZRE - PA - HYI"
  ),
  COD_ZONA = c(
    "ZDA", "ZDA",
    "ZDM", "ZDM", "ZDM", "ZDM", "ZDM", "ZDM",
    "ZDB", "ZDB", "ZDB", "ZDB", "ZDB", "ZDB",
    "ZDMB", "ZDMB", "ZDMB", "ZDMB",
    "ZI", "ZI",
    "ZSPC-E", "ZSPC-E", "ZSPC-E",
    "ZSPC-S", "ZSPC-S", "ZSPC-S",
    "ZRP", "ZOU", "ZA", "ZM",
    "ZPA", "ZPA", "ZPA",
    "ZRE", "ZRE", "ZRE", "ZRE", "ZRE", "ZRE", "ZRE"
  ),
  NOMBRE_COMPLETO = c(
    "Zona de Densidad Alta - Corredor", "Zona de Densidad Alta - Sector",
    "Zona de Densidad Media - Corredor I", "Zona de Densidad Media - Corredor II", "Zona de Densidad Media - Sector I", "Zona de Densidad Media - Sector II", "Zona de Densidad Media - Condiciones de Riesgo I", "Zona de Densidad Media - Condiciones de Riesgo II",
    "Zona de Densidad Baja - Corredor I", "Zona de Densidad Baja - Corredor II", "Zona de Densidad Baja - Sector I", "Zona de Densidad Baja - Sector II", "Zona de Densidad Baja - Condiciones de Riesgo I", "Zona de Densidad Baja - Condiciones de Riesgo II",
    "Zona de Densidad Muy Baja - Sector tipo I", "Zona de Densidad Muy Baja - Sector tipo II", "Zona de Densidad Muy Baja - Sector tipo III", "Zona de Densidad Muy Baja - Condiciones de Riesgo",
    "Industria Elemental y Complementaria", "Industria Liviana",
    "Educación Básica (Inicial, Primaria, Secundaria)", "Educación Técnico Productivo (CETPRO)", "Educación Superior Tecnológica",
    "Posta Médica (I-1, I-2)", "Centro de Salud (I-3, I-4)", "Hospital General (II-1, II-2)",
    "Zona de Recreación Pública", "Zona de Otros Usos", "Zona Agraria", "Zona Monumental",
    "Protección Ambiental por Conservación Ecológica", "Protección Ambiental por Intervención Especial y Recuperación", "Protección Ambiental por Recursos Hídricos / Fajas Marginales",
    "Reglamentación Especial No Urbanizable por Peligro Alto y Muy Alto", "Reglamentación Especial No Urbanizable por Riesgo Eléctrico (Alta Tensión)", "Reglamentación Especial por Peligro Muy Alto por Sismicidad", "Reglamentación Especial por Valores Históricos Culturales - Centro Histórico", "Reglamentación Especial por Bien Inmueble Prehispánico", "Reglamentación Especial por Protección Ambiental Calpitocasa", "Reglamentación Especial por Protección Ambiental Humedal Yungaqui-In"
  ),
  DENSIDAD_NETA_MAX = c(
    "Multifamiliar: 1,670 Hab/Ha", "Multifamiliar: 1,670 Hab/Ha",
    "Multifamiliar: 650 Hab/Ha", "Multifamiliar: 1,350 Hab/Ha", "Unifamiliar: 160 Hab/Ha | Multifamiliar: 650 Hab/Ha", "Unifamiliar: 350 Hab/Ha | Multifamiliar: 1,350 Hab/Ha", "Unifamiliar: 160 Hab/Ha", "Unifamiliar: 350 Hab/Ha",
    "Unifamiliar: 160 Hab/Ha | Multifamiliar: 480 Hab/Ha", "Unifamiliar: 200 Hab/Ha | Multifamiliar: 600 Hab/Ha", "Unifamiliar: 150 Hab/Ha | Multifamiliar: 400 Hab/Ha", "Unifamiliar: 200 Hab/Ha", "Unifamiliar: 150 Hab/Ha", "Unifamiliar: 200 Hab/Ha",
    "Unifamiliar - Agrícola: 30 Hab/Ha", "Unifamiliar - Huerto: 70 Hab/Ha", "Unifamiliar: 90 Hab/Ha", "Unifamiliar: 90 Hab/Ha",
    "No aplicable", "No aplicable",
    "Según tipología educativa", "Según tipología educativa", "Según tipología educativa",
    "Según categoría de salud", "Según categoría de salud", "Según categoría de salud",
    "No aplicable", "Según proyecto", "No aplicable (Actividad rural/agro)", "Según directiva de patrimonio",
    "No urbanizable / Protección", "No urbanizable / Recuperación", "No urbanizable / Faja marginal",
    "No urbanizable / Peligro", "No urbanizable / Servidumbre eléctrica", "Condicionado por EMS sísmico", "Según normativa del Centro Histórico", "Intangible / Arqueológico", "No urbanizable / Protección", "No urbanizable / Humedal"
  ),
  LOTE_MINIMO = c(
    "Multifamiliar: 120.00 m²", "Multifamiliar: 120.00 m²",
    "Multifamiliar: 250.00 m²", "Multifamiliar: 120.00 m²", "Unifamiliar: 250.00 m² | Multifamiliar: 250.00 m²", "Unifamiliar: 120.00 m² | Multifamiliar: 120.00 m²", "Unifamiliar: 250.00 m²", "Unifamiliar: 120.00 m²",
    "Unifamiliar: 250.00 m² | Multifamiliar: 250.00 m²", "Unifamiliar: 200.00 m² | Multifamiliar: 200.00 m²", "Unifamiliar: 300.00 m² | Multifamiliar: 300.00 m²", "Unifamiliar: 200.00 m²", "Unifamiliar: 300.00 m²", "Unifamiliar: 200.00 m²",
    "Unifamiliar: 1,500.00 m²", "Unifamiliar: 600.00 m²", "Unifamiliar: 450.00 m²", "Unifamiliar: 450.00 m²",
    "300.00 m²", "1,000.00 m²",
    "Inicial: 840 m² | Primaria: 2,000 m² | Secundaria: 2,500 m²", "CETPRO: 2,500 - 10,000 m²", "2,500 - 10,000 m²",
    "500.00 m²", "2,800.00 m²", "10,000.00 m²",
    "800.00 m²", "Según proyecto específico", "Segregación según Ley Agraria", "Lote existente / Conservación",
    "No aplicable", "No aplicable", "No aplicable",
    "Prohibido fraccionamiento", "Faja de servidumbre (20m / 25m)", "Según EMS y microzonificación", "Lote normativo CH", "Área protegida Mincul", "Protección de ladera", "Área de amortiguamiento humedal"
  ),
  FRENTE_MINIMO = c(
    "6.00 ml", "6.00 ml",
    "8.00 ml", "6.00 ml", "Unifamiliar: 8.00 ml | Multifamiliar: 8.00 ml", "Unifamiliar: 6.00 ml | Multifamiliar: 6.00 ml", "8.00 ml", "6.00 ml",
    "Unifamiliar: 10.00 ml | Multifamiliar: 10.00 ml", "Unifamiliar: 8.00 ml | Multifamiliar: 8.00 ml", "Unifamiliar: 10.00 ml | Multifamiliar: 10.00 ml", "Unifamiliar: 8.00 ml | Multifamiliar: 8.00 ml", "10.00 ml", "8.00 ml",
    "25.00 ml", "15.00 ml", "10.00 ml", "10.00 ml",
    "10.00 ml", "20.00 ml",
    "Inicial: 20 ml | Primaria/Secundaria: 40 ml", "40.00 ml", "60.00 ml",
    "20.00 ml", "30.00 ml / Según proyecto", "50.00 ml / Según proyecto",
    "25.00 ml", "Según proyecto", "Según vía de acceso", "Fachada tradicional conservada",
    "No aplicable", "No aplicable", "No aplicable",
    "Prohibido", "Prohibido frente a servidumbre", "6.00 ml", "Según perfil urbano CH", "No aplicable", "No aplicable", "No aplicable"
  ),
  ALTURA_MAXIMA = c(
    "15.00 ml o 5 niveles más azotea", "15.00 ml o 5 niveles más azotea",
    "12.00 ml o 4 niveles más azotea", "12.00 ml o 4 niveles más azotea", "Unifamiliar: 9.00 ml (3 niveles) | Multifamiliar: 12.00 ml (4 niveles), más azotea", "Unifamiliar: 9.00 ml (3 niveles) | Multifamiliar: 12.00 ml (4 niveles), más azotea", "9.00 ml o 3 niveles", "9.00 ml o 3 niveles",
    "Unifamiliar / Multifamiliar: 9.00 ml o 3 niveles más azotea", "Unifamiliar / Multifamiliar: 9.00 ml o 3 niveles más azotea", "Unifamiliar: 6.00 ml (2 niveles) | Multifamiliar: 9.00 ml (3 niveles), más azotea", "Unifamiliar: 6.00 ml o 2 niveles más azotea", "6.00 ml o 2 niveles", "6.00 ml o 2 niveles",
    "6.00 ml o 2 niveles", "6.00 ml o 2 niveles", "6.00 ml o 2 niveles", "6.00 ml o 2 niveles",
    "6.00 ml o 2 niveles", "6.00 ml o 2 niveles",
    "Inicial: 6 ml (2 pisos) | Primaria/Secundaria: según RNE", "Según RNE", "Según zona de densidad adyacente",
    "Según zona adyacente", "Según proyecto y RNE", "Según proyecto y RNE",
    "No aplica (Equipamiento recreativo)", "Según zona de densidad adyacente", "1 nivel (Vivienda rural/granja)", "2 niveles con tipología tradicional",
    "Prohibida edificación", "Prohibida edificación", "Prohibida edificación",
    "Prohibida edificación", "Prohibida edificación (Riesgo alta tensión)", "Máximo 2 niveles con diseño sismorresistente", "2 niveles respetando volumetría patrimonial", "Intangible", "Prohibida edificación", "Prohibida edificación"
  ),
  AREA_LIBRE_MIN = c(
    "30%", "30%",
    "35%", "30%", "Unifamiliar: 35% | Multifamiliar: 35%", "Unifamiliar: 30% | Multifamiliar: 30%", "35%", "30%",
    "Unifamiliar: 40% | Multifamiliar: 40%", "Unifamiliar: 35% | Multifamiliar: 35%", "Unifamiliar: 40% | Multifamiliar: 40%", "Unifamiliar: 35%", "40%", "35%",
    "90%", "75%", "65%", "65%",
    "30%", "30%",
    "40% a 50% según RNE", "40%", "40%",
    "40%", "40%", "50%",
    "70% mínimo de áreas verdes y peatonales", "Según proyecto", "80% (Área rústica libre)", "30% patio interior",
    "100% natural", "100% natural", "100% faja ribereña",
    "100% libre", "100% servidumbre libre", "40%", "30%", "100% libre", "100% libre", "100% libre"
  ),
  COEFICIENTE_EDIF = c(
    "3.5", "3.5",
    "2.6", "2.8", "Unifamiliar: 2.0 | Multifamiliar: 2.6", "Unifamiliar: 2.1 | Multifamiliar: 2.8", "2.0", "2.1",
    "1.8", "2.0", "Unifamiliar: 1.2 | Multifamiliar: 1.8", "1.3", "1.2", "1.3",
    "0.2", "0.5", "0.7", "0.7",
    "1.5", "1.5",
    "Según RNE / Norma A.040", "Según RNE", "Según RNE",
    "Según RNE / Norma A.050", "Según RNE", "Según RNE",
    "0.2 (Servicios complementarios)", "Según proyecto", "0.2", "1.5",
    "0.0", "0.0", "0.0",
    "0.0", "0.0", "1.2", "1.4", "0.0", "0.0", "0.0"
  ),
  RETIRO_FRONTAL = c(
    "No aplica", "No aplica",
    "No aplica", "No aplica", "No aplica", "No aplica", "No aplica", "No aplica",
    "3.00 ml", "3.00 ml", "3.00 ml", "3.00 ml", "3.00 ml", "3.00 ml",
    "3.00 ml", "3.00 ml", "3.00 ml", "3.00 ml",
    "5.00 ml", "5.00 ml",
    "5.00 ml", "5.00 ml", "5.00 ml",
    "5.00 ml", "5.00 ml", "5.00 ml",
    "Segun diseño paisajístico", "3.00 ml", "5.00 ml", "0.00 ml (Línea municipal histórica)",
    "No aplica", "No aplica", "Faja marginal ANA",
    "No aplica", "Faja de servidumbre obligatoria", "3.00 ml", "Alineamiento histórico", "No aplica", "No aplica", "No aplica"
  ),
  USOS_PERMITIDOS = c(
    "Residencial, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto), sujeto a restricciones por riesgo.",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto), sujeto a restricciones por riesgo.",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Comercial y Usos Especiales (uso mixto), sujeto a restricciones por riesgo.",
    "Residencial, Comercial y Usos Especiales (uso mixto), sujeto a restricciones por riesgo.",
    "Residencial, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Comercial y Usos Especiales (uso mixto).",
    "Residencial, Taller, Comercial y Usos Especiales (uso mixto), sujeto a restricciones por riesgo.",
    "Industria elemental y complementaria (no molesta ni contaminante), talleres de maestranza, almacenes livianos.",
    "Industria liviana, depósitos y almacenes industriales, plantas de transformación agropecuaria.",
    "Centros educativos de nivel Inicial, Primaria y Secundaria de EBR y EBE.",
    "Centros de Educación Técnico-Productiva (CETPRO) y formación ocupacional.",
    "Institutos de Educación Superior Tecnológica y Pedagógica.",
    "Puestos de salud (Nivel I-1, I-2) y consultorios médicos comunitarios.",
    "Centros de salud con y sin internamiento (Nivel I-3, I-4).",
    "Hospitales de segundo y tercer nivel de atención (Nivel II-1, II-2, III-1).",
    "Parques zonales, plazas, losas deportivas, áreas de recreación activa y pasiva.",
    "Instituciones cívicas, sedes administrativas, seguridad ciudadana, cultos religiosos.",
    "Cultivos agrícolas, pastizales, granjas pecuarias y agroforestería.",
    "Conservación de patrimonio histórico, actividades culturales, museos y turismo controlado.",
    "Conservación de ecosistemas, protección de flora y fauna, investigación científica.",
    "Recuperación de ecosistemas degradados, forestación y estabilización de laderas.",
    "Protección de riberas, ríos, quebradas y lagunas (Laguna Huaypo). Intangibilidad de faja marginal.",
    "Zona NO urbanizable por riesgo alto de deslizamiento, derrumbe o inundación. Solo recreación pasiva.",
    "Faja de servidumbre de líneas de transmisión de 138kV (20m) y 220kV (25m). PROHIBIDA edificación y presencia masiva.",
    "Zona urbana con requerimiento obligatorio de Estudio de Mecánica de Suelos (EMS) sismo-resistente.",
    "Conservación del patrimonio arquitectónico y urbano tradicional del Centro Histórico de Anta.",
    "Protección de sitios arqueológicos y bienes inmuebles prehispánicos (Mincul).",
    "Protección y conservación ambiental del sector Calpitocasa.",
    "Protección y conservación integral del Humedal Yungaqui-In."
  ),
  stringsAsFactors = FALSE
)

df_parametros$ESTADO_VALIDACION <- "PENDIENTE DE VALIDACIÓN MUNICIPAL"
df_parametros$FUENTE_NORMATIVA <- "ZONIFICACIÓN Y USOS DE SUELO.docx"
df_parametros$TABLA_FUENTE <- c(
  paste0("Tabla N° ", 15:32),
  rep("Pendiente de conciliación en matriz XLSX", nrow(df_parametros) - 18)
)

# Conservar explícitamente UTF-8 al serializar para ejecución Linux/shinyapps.io.
columnas_texto <- vapply(df_parametros, is.character, logical(1))
df_parametros[columnas_texto] <- lapply(df_parametros[columnas_texto], function(x) {
  Encoding(x) <- "UTF-8"
  x
})

