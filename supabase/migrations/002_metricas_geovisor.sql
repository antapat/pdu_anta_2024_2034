-- Métricas públicas y anónimas del GeoVisor PDU Anta.
-- La integración GitHub/Supabase puede aplicar esta migración sin exponer
-- las tablas subyacentes. Los visitantes solo ejecutan las RPC autorizadas.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.metricas_geovisor (
  id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  visitas_total bigint NOT NULL DEFAULT 0 CHECK (visitas_total >= 0),
  constancias_total bigint NOT NULL DEFAULT 0 CHECK (constancias_total >= 0),
  actualizado_en timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.metricas_geovisor (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.visitas_geovisor (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  visitante_hash text NOT NULL,
  fecha_visita date NOT NULL DEFAULT (timezone('America/Lima', now()))::date,
  primera_visita_en timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT visitas_geovisor_visitante_dia_key UNIQUE (visitante_hash, fecha_visita)
);

ALTER TABLE public.metricas_geovisor ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitas_geovisor ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.metricas_geovisor FROM anon, authenticated;
REVOKE ALL ON TABLE public.visitas_geovisor FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_metricas_geovisor()
RETURNS TABLE (visitas_total bigint, constancias_total bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT m.visitas_total, m.constancias_total
  FROM public.metricas_geovisor AS m
  WHERE m.id = 1;
$$;

CREATE OR REPLACE FUNCTION public.registrar_visita(p_visitante text)
RETURNS TABLE (visitas_total bigint, constancias_total bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_insertada bigint;
BEGIN
  IF p_visitante IS NULL OR length(trim(p_visitante)) < 16 OR length(p_visitante) > 200 THEN
    RAISE EXCEPTION 'Identificador de visita inválido';
  END IF;

  INSERT INTO public.visitas_geovisor (visitante_hash)
  VALUES (encode(extensions.digest(trim(p_visitante), 'sha256'), 'hex'))
  ON CONFLICT (visitante_hash, fecha_visita) DO NOTHING;

  GET DIAGNOSTICS v_insertada = ROW_COUNT;

  IF v_insertada = 1 THEN
    UPDATE public.metricas_geovisor
    SET visitas_total = visitas_total + 1,
        actualizado_en = now()
    WHERE id = 1;
  END IF;

  RETURN QUERY SELECT * FROM public.get_metricas_geovisor();
END;
$$;

CREATE OR REPLACE FUNCTION public.registrar_constancia()
RETURNS TABLE (visitas_total bigint, constancias_total bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.metricas_geovisor
  SET constancias_total = constancias_total + 1,
      actualizado_en = now()
  WHERE id = 1;

  RETURN QUERY SELECT * FROM public.get_metricas_geovisor();
END;
$$;

REVOKE ALL ON FUNCTION public.get_metricas_geovisor() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.registrar_visita(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.registrar_constancia() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_metricas_geovisor() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_visita(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_constancia() TO anon, authenticated;

-- El buzón ciudadano se retira del servicio. Se conservan los registros
-- históricos, pero se cierra cualquier inserción anónima que hubiera quedado.
DO $$
BEGIN
  IF to_regclass('public.reportes_ciudadanos') IS NOT NULL THEN
    DROP POLICY IF EXISTS "Permitir registro ciudadano anonimo" ON public.reportes_ciudadanos;
    REVOKE INSERT ON TABLE public.reportes_ciudadanos FROM anon, authenticated;
  END IF;
END $$;

