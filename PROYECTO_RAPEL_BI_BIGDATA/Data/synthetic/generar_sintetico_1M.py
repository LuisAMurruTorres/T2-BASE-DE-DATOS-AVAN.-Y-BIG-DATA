import csv
import os
import random
from datetime import datetime, timedelta

# ==============================================================================
# PROYECTO: BI & BIG DATA - AGROEXPORTACIÓN PERUANA
# GENERADOR SINTÉTICO LIMPIO (OPTIMIZADO PARA EXCEL EN ESPAÑOL Y SQL SERVER)
# ==============================================================================

CARPETA_SALIDA = os.path.join("data", "synthetic")
os.makedirs(CARPETA_SALIDA, exist_ok=True)
ARCHIVO_SALIDA = os.path.join(CARPETA_SALIDA, "sunat_exportaciones_1M.csv")

TOTAL_REGISTROS = 1000000

EMPRESAS = [
    ("20451779711", "SOCIEDAD AGRICOLA RAPEL S.A.C.", 40),
    ("20481541005", "ECOSAC AGRICOLA S.A.C.", 20),
    ("20467534026", "COMPLEJO AGROINDUSTRIAL BETA S.A.", 15),
    ("20100017491", "CAMPOSOL S.A.", 15),
    ("20397894988", "EL PEDREGAL S.A.", 10),
]

CULTIVOS = [
    ("0806100000", "UVA FRESCA SWEET GLOBE", 2.20, 3.80, [11, 12, 1]),
    ("0810400000", "ARANDANOS FRESCOS VENTURA", 4.50, 7.80, [9, 10, 11]),
    ("0804400000", "PALTA HASS FRESCA", 1.80, 2.90, [5, 6, 7]),
    ("0804502000", "MANGO FRESCO KENT", 1.20, 2.10, [12, 1, 2]),
]

DESTINOS = [
    ("US", 42, 1.00),
    ("NL", 28, 0.98),
    ("CN", 10, 1.25),
    ("GB", 8, 1.08),
    ("ES", 5, 0.95),
    ("KR", 4, 1.30),
    ("CO", 3, 0.85),
]

ADUANAS = [("118", 70), ("262", 25), ("181", 5)]

fecha_inicio = datetime(2021, 1, 1)
fecha_fin = datetime(2026, 6, 30)
dias_totales = (fecha_fin - fecha_inicio).days

ruc_lista, razon_lista, empresas_pesos = zip(*EMPRESAS)
paises_lista, destinos_pesos, factores_mercado = zip(*DESTINOS)
aduanas_lista, aduanas_pesos = zip(*ADUANAS)

print(f"Generando {TOTAL_REGISTROS} filas limpias hacia {ARCHIVO_SALIDA}...")

# newline='' y lineterminator='\n' eliminan el retorno de carro (\r) que causaba errores en SQL
with open(
    ARCHIVO_SALIDA, mode="w", newline="", encoding="utf-8-sig"
) as f:  # utf-8-sig para tildes y eñes
  writer = csv.writer(f, delimiter=";", lineterminator="\n")

  writer.writerow([
      "CADU",
      "FANO",
      "NDCL",
      "FNUM",
      "FEMB",
      "NDOC",
      "DNOMBRE",
      "CPAIDES",
      "PART_NANDI",
      "DCOM",
      "VFOBSERDOL",
      "VPESNET",
  ])

  for i in range(1, TOTAL_REGISTROS + 1):
    fecha_emb = fecha_inicio + timedelta(days=random.randint(0, dias_totales))
    fnum_int = int(fecha_emb.strftime("%Y%m%d"))
    fano_int = fecha_emb.year
    mes = fecha_emb.month

    idx_emp = random.choices(range(len(EMPRESAS)), weights=empresas_pesos)[0]
    ndoc = ruc_lista[idx_emp]
    dnombre = razon_lista[idx_emp]

    cultivo = random.choice(CULTIVOS)
    partida, dcom, p_min, p_max, meses_pico = cultivo

    factor_estacional = (
        random.uniform(0.75, 0.85) if mes in meses_pico else 1.05
    )

    idx_dest = random.choices(range(len(DESTINOS)), weights=destinos_pesos)[0]
    cpaides = paises_lista[idx_dest]
    factor_pais = factores_mercado[idx_dest]

    cadu = random.choices(aduanas_lista, weights=aduanas_pesos)[0]
    ndcl = f"{random.randint(1000, 9999)}"

    vpesnet = round(random.uniform(15000.0, 21500.0), 2)
    precio_kg = random.uniform(p_min, p_max) * factor_estacional * factor_pais
    vfobserdol = round(vpesnet * precio_kg, 2)

    # Inconsistencias controladas para el ETL (1.5%)
    prob = random.random()
    if prob < 0.005:
      vfobserdol = 0.00
    elif prob < 0.010:
      vpesnet = -100.00
    elif prob < 0.015:
      cpaides = "XX"

    # Decimales con coma para Excel en español
    vfob_str = str(vfobserdol).replace(".", ",")
    vpesnet_str = str(vpesnet).replace(".", ",")

    writer.writerow([
        cadu,
        fano_int,
        ndcl,
        fnum_int,
        fnum_int,
        ndoc,
        dnombre,
        cpaides,
        partida,
        dcom,
        vfob_str,
        vpesnet_str,
    ])

print("Generación finalizada con éxito. Archivo limpio y listo.")