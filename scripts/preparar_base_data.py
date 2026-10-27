"""Consolida los Shapefiles originales en GeoPackage y SQL PostGIS.

Ejecutar desde la raíz: python scripts/preparar_base_data.py
Dependencias: geopandas, pyogrio, shapely. No requiere credenciales.
"""
from pathlib import Path
import hashlib
import json
import math
import sqlite3
from contextlib import closing

import geopandas as gpd
import pandas as pd
from shapely import make_valid


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
LAYERS = {
    "zonificacion": "P_080301_Zonificacion_urbana",
    "vias": "P_080301_Sistema_vial",
    "alta_tension": "D_080301_Red_electrica",
    "alta_tension_buffer": "D_080301_Red_electrica_servidumbre",
    "ferrocarril": "B_080301_Red_ferroviaria",
    "ferrocarril_buffer": "B_080301_Red_ferroviaria_zif",
}


def identifier(value):
    return '"' + value.replace('"', '""') + '"'


def literal(value):
    if pd.isna(value):
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def main():
    # Validar todo antes de escribir resultados o generar operaciones SQL.
    frames = {}
    inventory = []
    for name, stem in LAYERS.items():
        for extension in (".shp", ".shx", ".dbf", ".prj"):
            path = DATA / (stem + extension)
            if not path.is_file():
                raise FileNotFoundError(path)
        frame = gpd.read_file(DATA / (stem + ".shp"))
        if frame.empty or frame.crs is None:
            raise ValueError(f"{name}: capa vacía o sin CRS")
        if frame.geometry.isna().any() or frame.geometry.is_empty.any():
            raise ValueError(f"{name}: contiene geometrías nulas o vacías")
        invalid = int((~frame.geometry.is_valid).sum())
        frame.geometry = frame.geometry.map(make_valid)
        frame = frame.to_crs(4326)
        if not frame.geometry.is_valid.all() or frame.geometry.is_empty.any():
            raise ValueError(f"{name}: geometrías inválidas tras reparación")
        if not all(math.isfinite(v) for v in frame.total_bounds):
            raise ValueError(f"{name}: coordenadas no finitas")
        frames[name] = frame
        inventory.append({
            "tabla": name, "archivo": stem + ".shp", "filas": len(frame),
            "epsg_origen": gpd.read_file(DATA / (stem + ".shp"), rows=1).crs.to_epsg(),
            "epsg_destino": 4326, "geometrias_reparadas": invalid,
            "campos": list(frame.columns),
            "sha256_componentes": {
                ext: hashlib.sha256((DATA / (stem + ext)).read_bytes()).hexdigest()
                for ext in (".shp", ".shx", ".dbf", ".prj")
            },
        })

    output = DATA / "base_preparada"
    output.mkdir(exist_ok=True)
    target = output / "pdu_fuentes.gpkg"
    temporary = output / "pdu_fuentes.tmp.gpkg"
    if temporary.exists():
        temporary.unlink()
    for name, frame in frames.items():
        frame.to_file(temporary, layer=name, driver="GPKG", engine="pyogrio")
    with closing(sqlite3.connect(temporary)) as con:
        if con.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise ValueError("GeoPackage no supera la verificación de integridad")
        for name, frame in frames.items():
            count = con.execute(f"SELECT count(*) FROM {identifier(name)}").fetchone()[0]
            if count != len(frame):
                raise ValueError(f"Conteo incorrecto: {name}")
    temporary.replace(target)

    # Esquema de fuentes separado: no reemplaza las tablas públicas del visor.
    with (output / "cargar_fuentes_postgis.sql").open("w", encoding="utf-8") as sql:
        sql.write("-- Fuentes originales; no modifica public ni asigna códigos normativos.\n")
        sql.write("BEGIN;\nSET LOCAL standard_conforming_strings = on;\n")
        sql.write("CREATE EXTENSION IF NOT EXISTS postgis;\n")
        sql.write("CREATE SCHEMA IF NOT EXISTS pdu_fuentes;\n")
        sql.write("REVOKE ALL ON SCHEMA pdu_fuentes FROM PUBLIC;\n")
        for name, frame in frames.items():
            table = "pdu_fuentes." + identifier(name)
            columns = [c for c in frame.columns if c != frame.geometry.name]
            sql.write(f"DROP TABLE IF EXISTS {table};\n")
            definitions = ", ".join(identifier(c) + " text" for c in columns)
            sql.write(f"CREATE TABLE {table} ({definitions}, geom geometry(Geometry,4326));\n")
            sql.write(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;\n")
            sql.write(f"REVOKE ALL ON {table} FROM PUBLIC;\n")
            for _, row in frame.iterrows():
                values = [literal(row[c]) for c in columns]
                values.append(f"ST_GeomFromWKB(decode('{row.geometry.wkb_hex}', 'hex'),4326)")
                sql.write(f"INSERT INTO {table} VALUES ({', '.join(values)});\n")
            sql.write(f"CREATE INDEX ON {table} USING GIST (geom);\nANALYZE {table};\n")
            sql.write(f"DO $$ BEGIN IF (SELECT count(*) FROM {table}) <> {len(frame)} "
                      f"THEN RAISE EXCEPTION 'Conteo incorrecto: {name}'; END IF; END $$;\n")
        sql.write("COMMIT;\n")
    report = {
        "capas": inventory, "total_registros": sum(len(f) for f in frames.values()),
        "pendientes_visor": ["ambito", "distritos", "conciliación de atributos y códigos normativos"],
        "nota": "Fuentes originales. No equivale a las tablas normalizadas que requiere app.R.",
    }
    (output / "inventario.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Base verificada: {target}")
    print(f"{len(frames)} capas, {report['total_registros']} registros. SQL e inventario generados.")


if __name__ == "__main__":
    main()
