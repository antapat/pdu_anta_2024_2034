-- Corrige la ambigüedad entre las columnas de metricas_geovisor y los
-- parámetros de salida de las funciones PL/pgSQL.

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
    UPDATE public.metricas_geovisor AS m
    SET visitas_total = m.visitas_total + 1,
        actualizado_en = now()
    WHERE m.id = 1;
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
  UPDATE public.metricas_geovisor AS m
  SET constancias_total = m.constancias_total + 1,
      actualizado_en = now()
  WHERE m.id = 1;

  RETURN QUERY SELECT * FROM public.get_metricas_geovisor();
END;
$$;

REVOKE ALL ON FUNCTION public.registrar_visita(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.registrar_constancia() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.registrar_visita(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_constancia() TO anon, authenticated;
