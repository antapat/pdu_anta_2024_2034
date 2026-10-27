-- Preparación de Supabase para las capas del GeoVisor PDU Anta.
-- Ejecutar en el SQL Editor una vez antes del primer proceso de carga.
-- Las capas geográficas no se exponen a anon/authenticated: se cargan desde
-- un proceso administrativo R mediante la conexión PostgreSQL.

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.pdu_importaciones (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conjunto text NOT NULL,
  filas bigint NOT NULL,
  importado_en timestamptz NOT NULL DEFAULT now(),
  commit_fuente text
);

ALTER TABLE public.pdu_importaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pdu_importaciones FROM anon, authenticated;

-- Bloqueo explícito para que las capas espaciales permanezcan privadas
-- aunque se creen desde una herramienta que otorgue privilegios por defecto.
DO $$
DECLARE
  tabla text;
BEGIN
  FOREACH tabla IN ARRAY ARRAY[
    'ambito', 'distritos', 'zonificacion', 'vias', 'alta_tension',
    'alta_tension_buffer', 'ferrocarril', 'ferrocarril_buffer',
    'parametros_urbanisticos'
  ] LOOP
    IF to_regclass(format('public.%I', tabla)) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tabla);
      EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated', tabla);
    END IF;
  END LOOP;
END $$;
