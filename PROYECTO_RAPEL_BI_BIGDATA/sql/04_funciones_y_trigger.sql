USE DM_Rapel_ComercioExterior;
GO

-- Función Escalar 1: Precio por Kg
CREATE OR ALTER FUNCTION dm.fn_PrecioKg (@FOB DECIMAL(18,2), @Peso DECIMAL(18,2))
RETURNS DECIMAL(18,4)
AS
BEGIN
    IF @Peso IS NULL OR @Peso <= 0 RETURN 0;
    RETURN ROUND(@FOB / @Peso, 4);
END;
GO

-- Función Escalar 2: Clasificación de Campaña Agrícola por Año y Mes
CREATE OR ALTER FUNCTION dm.fn_Campania (@Año INT, @Mes INT)
RETURNS VARCHAR(20)
AS
BEGIN
    IF @Mes >= 8
        RETURN 'Campaña ' + CAST(@Año AS VARCHAR(4)) + '-' + CAST(@Año + 1 AS VARCHAR(4));
    RETURN 'Campaña ' + CAST(@Año - 1 AS VARCHAR(4)) + '-' + CAST(@Año AS VARCHAR(4));
END;
GO

-- Función de Tabla: Resumen Anual
CREATE OR ALTER FUNCTION dm.fn_KPI_Rapel_Anual (@Año INT)
RETURNS TABLE
AS
RETURN (
    SELECT 
        p.TipoCultivo,
        SUM(f.ValorFOB_USD) AS Facturacion_USD,
        SUM(f.PesoNeto_Kg)  AS Kilos_Totales,
        ROUND(SUM(f.ValorFOB_USD) / NULLIF(SUM(f.PesoNeto_Kg), 0), 4) AS PrecioMedio_Kg
    FROM dm.Fact_ExportacionComercial f
    INNER JOIN dm.Dim_Tiempo t          ON f.IdTiempo = t.IdTiempo
    INNER JOIN dm.Dim_ProductoArancel p ON f.IdProducto = p.IdProducto
    INNER JOIN dm.Dim_Operador o        ON f.IdOperador = o.IdOperador
    WHERE t.Año = @Año AND o.EsEmpresaFoco = 1
    GROUP BY p.TipoCultivo
);
GO

-- Disparador: Bloqueo de Modificación Manual
IF OBJECT_ID(N'audit.LogCambiosHechos', N'U') IS NULL
CREATE TABLE audit.LogCambiosHechos (
    IdLogAudit   INT IDENTITY(1,1) PRIMARY KEY,
    Accion       VARCHAR(10),
    Usuario      NVARCHAR(128) DEFAULT SUSER_SNAME(),
    Fecha        DATETIME2(0) DEFAULT SYSDATETIME(),
    IdHecho      BIGINT
);
GO

CREATE OR ALTER TRIGGER dm.trg_Fact_Auditoria
ON dm.Fact_ExportacionComercial
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO audit.LogCambiosHechos (Accion, IdHecho)
    SELECT 'DELETE', IdHechoExportacion FROM deleted;
END;
GO