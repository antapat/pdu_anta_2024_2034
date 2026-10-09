-- ==============================================================================
-- ESQUEMA SQL PARA SUPABASE - GEOVISOR PDU ANTA (2024 - 2034)
-- Ejecutar este script en el SQL Editor de su proyecto de Supabase
-- Proyecto: GeoVisor PDU Anta (Posit Connect Cloud / connect.posit.cloud/patantampa)
-- NOTA: para instalaciones nuevas use, en orden, los archivos versionados de
-- supabase/migrations. Este archivo se conserva únicamente por compatibilidad.
-- ==============================================================================

-- 1. EXTENSIÓN UUID (Si no está habilitada)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 2. TABLA: consultas_pdu
-- Almacena las consultas puntuales y de predios para auditoría y analítica territorial
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.consultas_pdu (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo_consulta VARCHAR(50) NOT NULL, -- 'punto' o 'poligono'
    coordenadas TEXT NOT NULL,
    distrito VARCHAR(100),
    en_ambito BOOLEAN DEFAULT TRUE,
    zona_principal VARCHAR(100),
    metadata JSONB DEFAULT '{}'::jsonb,
    creado_en TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.consultas_pdu ENABLE ROW LEVEL SECURITY;

-- Política: Permitir inserción anónima desde el GeoVisor Shiny
CREATE POLICY "Permitir insercion anonima de consultas" 
    ON public.consultas_pdu 
    FOR INSERT 
    TO anon, authenticated 
    WITH CHECK (true);

-- Política: Lectura pública o solo administradores (por defecto solo authenticated)
CREATE POLICY "Lectura de consultas para usuarios autenticados" 
    ON public.consultas_pdu 
    FOR SELECT 
    TO authenticated 
    USING (true);

-- Índices de búsqueda y analítica
CREATE INDEX IF NOT EXISTS idx_consultas_pdu_creado_en ON public.consultas_pdu (creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_consultas_pdu_distrito ON public.consultas_pdu (distrito);
CREATE INDEX IF NOT EXISTS idx_consultas_pdu_zona ON public.consultas_pdu (zona_principal);

-- ------------------------------------------------------------------------------
-- 3. TABLA: reportes_ciudadanos
-- Buzón de observaciones, reclamos y consultas de vecinos sobre el PDU
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reportes_ciudadanos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre_ciudadano VARCHAR(255) NOT NULL,
    contacto VARCHAR(255) NOT NULL,
    tipo VARCHAR(100) NOT NULL, -- 'Zonificación', 'Vía proyectada', 'Servidumbre', 'Otro'
    ubicacion TEXT,
    mensaje TEXT NOT NULL,
    estado VARCHAR(50) DEFAULT 'PENDIENTE', -- 'PENDIENTE', 'EN_REVISION', 'ATENDIDO'
    respuesta_municipal TEXT,
    creado_en TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    actualizado_en TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.reportes_ciudadanos ENABLE ROW LEVEL SECURITY;

-- El servicio ya no recibe aportes u observaciones desde el GeoVisor.
-- Se conserva la tabla únicamente para no perder registros históricos.
DROP POLICY IF EXISTS "Permitir registro ciudadano anonimo" ON public.reportes_ciudadanos;
REVOKE INSERT ON TABLE public.reportes_ciudadanos FROM anon, authenticated;

-- Política: Lectura solo para administradores autenticados
CREATE POLICY "Lectura de reportes para administradores" 
    ON public.reportes_ciudadanos 
    FOR SELECT 
    TO authenticated 
    USING (true);

-- ------------------------------------------------------------------------------
-- 4. TABLA: avisos_municipales
-- Comunicados oficiales emitidos por la Gerencia de Desarrollo Urbano
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.avisos_municipales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    titulo VARCHAR(255) NOT NULL,
    contenido TEXT NOT NULL,
    nivel VARCHAR(50) DEFAULT 'info', -- 'info', 'warning', 'success'
    activo BOOLEAN DEFAULT TRUE,
    creado_en TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.avisos_municipales ENABLE ROW LEVEL SECURITY;

-- Política: Lectura pública de avisos activos
CREATE POLICY "Lectura publica de avisos activos" 
    ON public.avisos_municipales 
    FOR SELECT 
    TO anon, authenticated 
    USING (activo = true);

-- Inserción de ejemplo inicial
INSERT INTO public.avisos_municipales (titulo, contenido, nivel, activo)
VALUES (
    'Vigencia del PDU Anta 2024 - 2034',
    'El Plan de Desarrollo Urbano se encuentra plenamente vigente desde el 04 de abril del 2025 bajo la supervisión de la Municipalidad Provincial de Anta.',
    'info',
    true
) ON CONFLICT DO NOTHING;
