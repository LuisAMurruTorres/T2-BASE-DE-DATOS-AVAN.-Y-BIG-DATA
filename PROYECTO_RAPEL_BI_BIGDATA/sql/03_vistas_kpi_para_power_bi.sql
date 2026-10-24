USE DM_Rapel_ComercioExterior;
GO

-- Vista 1: Precios y Estacionalidad
CREATE OR ALTER VIEW dm.vw_KPI_Precios_Estacionalidad AS
SELECT 
    t.Año,
    t.Mes,
    t.NombreMes,
    t.SemanaAño,
    t.CampaniaAgricola,
    p.TipoCultivo,
    o.EsEmpresaFoco,
    SUM(f.ValorFOB_USD) AS TotalFOB_USD,
    SUM(f.PesoNeto_Kg)  AS TotalPesoNeto_Kg,
    ROUND(SUM(f.ValorFOB_USD) / NULLIF(SUM(f.PesoNeto_Kg), 0), 4) AS PrecioPromedio_Kg
FROM dm.Fact_ExportacionComercial f
INNER JOIN dm.Dim_Tiempo t          ON f.IdTiempo = t.IdTiempo
INNER JOIN dm.Dim_ProductoArancel p ON f.IdProducto = p.IdProducto
INNER JOIN dm.Dim_Operador o        ON f.IdOperador = o.IdOperador
GROUP BY t.Año, t.Mes, t.NombreMes, t.SemanaAño, t.CampaniaAgricola, p.TipoCultivo, o.EsEmpresaFoco;
GO

-- Vista 2: Mercados Premium y Diversificación
CREATE OR ALTER VIEW dm.vw_Mercados_Premium AS
WITH PromediosPorPais AS (
    SELECT 
        t.Año,
        t.SemanaAño,
        d.NombrePais,
        d.EsTradicional,
        SUM(f.ValorFOB_USD) AS TotalFOB_USD,
        SUM(f.PesoNeto_Kg)  AS TotalPesoNeto_Kg,
        ROUND(SUM(f.ValorFOB_USD) / NULLIF(SUM(f.PesoNeto_Kg), 0), 4) AS Precio_Kg
    FROM dm.Fact_ExportacionComercial f
    INNER JOIN dm.Dim_Tiempo t      ON f.IdTiempo = t.IdTiempo
    INNER JOIN dm.Dim_PaisDestino d ON f.IdPais = d.IdPais
    GROUP BY t.Año, t.SemanaAño, d.NombrePais, d.EsTradicional
),
ReferenciaTradicional AS (
    SELECT 
        Año,
        SemanaAño,
        ROUND(SUM(TotalFOB_USD) / NULLIF(SUM(TotalPesoNeto_Kg), 0), 4) AS PrecioTradicional_Kg
    FROM PromediosPorPais
    WHERE EsTradicional = 1
    GROUP BY Año, SemanaAño
)
SELECT 
    p.Año,
    p.SemanaAño,
    p.NombrePais,
    p.Precio_Kg,
    r.PrecioTradicional_Kg,
    ROUND(((p.Precio_Kg - r.PrecioTradicional_Kg) / NULLIF(r.PrecioTradicional_Kg, 0)) * 100, 2) AS PrimaPorcentual,
    CASE WHEN ((p.Precio_Kg - r.PrecioTradicional_Kg) / NULLIF(r.PrecioTradicional_Kg, 0)) >= 0.12 THEN 1 ELSE 0 END AS EsMercadoPremium
FROM PromediosPorPais p
LEFT JOIN ReferenciaTradicional r ON p.Año = r.Año AND p.SemanaAño = r.SemanaAño
WHERE p.EsTradicional = 0;
GO

-- Vista 3: Logística Paita vs Callao
CREATE OR ALTER VIEW dm.vw_Paita_vs_Callao AS
SELECT 
    t.Año,
    t.Mes,
    t.NombreMes,
    a.PuertoEmbarque,
    a.EsPuertoPropio,
    SUM(f.ValorFOB_USD) AS TotalFOB_USD,
    SUM(f.PesoNeto_Kg)  AS TotalPesoNeto_Kg,
    ROUND(SUM(f.ValorFOB_USD) / NULLIF(SUM(f.PesoNeto_Kg), 0), 4) AS PrecioPromedio_Kg
FROM dm.Fact_ExportacionComercial f
INNER JOIN dm.Dim_Tiempo t        ON f.IdTiempo = t.IdTiempo
INNER JOIN dm.Dim_AduanaPuerto a  ON f.IdAduana = a.IdAduana
GROUP BY t.Año, t.Mes, t.NombreMes, a.PuertoEmbarque, a.EsPuertoPropio;
GO