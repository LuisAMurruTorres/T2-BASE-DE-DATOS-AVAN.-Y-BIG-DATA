
import os
import pandas as pd

# ==============================================================================
# PROYECTO: BI & BIG DATA - SOCIEDAD AGRICOLA RAPEL S.A.C.
# ARTEFACTO: PROCESAMIENTO Y ESCRITURA COLUMNAR PARQUET (EVIDENCIA BIG DATA)
# ==============================================================================

# Rutas de entrada y salida
RUTA_ENTRADA_CSV = os.path.join("data", "synthetic", "sunat_exportaciones_1M.csv")
RUTA_SALIDA_PARQUET = os.path.join("data", "processed", "exportaciones_parquet")

os.makedirs(RUTA_SALIDA_PARQUET, exist_ok=True)
archivo_parquet_final = os.path.join(RUTA_SALIDA_PARQUET, "datos_procesados.parquet")

print(f"Leyendo dataset desde: {RUTA_ENTRADA_CSV}...")
# Lectura y filtrado de inconsistencias
df = pd.read_csv(RUTA_ENTRADA_CSV)

# Reglas de limpieza: descartar valores anómalos (FOB <= 0 o Peso <= 0)
df_limpio = df[(df["VFOBSERDOL"] > 0) & (df["VPESNET"] > 0)].copy()

# Cálculo de métrica derivada: Precio FOB por Kilogramo
df_limpio["PRECIO_FOB_KG"] = (df_limpio["VFOBSERDOL"] / df_limpio["VPESNET"]).round(4)

print(f"Escribiendo salida columnar en: {archivo_parquet_final}...")
# Escritura en formato columnar Parquet con compresión Snappy
df_limpio.to_parquet(archivo_parquet_final, compression="snappy", index=False)