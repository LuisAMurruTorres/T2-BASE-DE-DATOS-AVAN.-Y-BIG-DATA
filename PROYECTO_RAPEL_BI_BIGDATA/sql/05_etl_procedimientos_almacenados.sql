USE DM_Rapel_ComercioExterior;
GO

CREATE OR ALTER PROCEDURE dm.usp_CargarDataMartComercial
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdCarga BIGINT;
    DECLARE @TotalStaging INT = 0;
    DECLARE @Buenas INT = 0;
    DECLARE @Malas INT = 0;

    INSERT INTO audit.BitacoraCarga (Estado) VALUES ('EN PROCESO');
    SET @IdCarga = SCOPE_IDENTITY();

    BEGIN TRY
        SELECT @TotalStaging = COUNT(1) FROM stg.SUNAT_Export;

        -- 1. Separar Filas Rechazadas
        INSERT INTO audit.FilasRechazadas (IdCarga, CADU, NDCL, FNUM, FEMB, NDOC, DNOMBRE, CPAIDES, PART_NANDI, VFOBSERDOL, VPESNET, MotivoRechazo)
        SELECT 
            @IdCarga, CADU, NDCL, FNUM, FEMB, NDOC, DNOMBRE, CPAIDES, PART_NANDI, VFOBSERDOL, VPESNET,
            CASE 
                WHEN TRY_CAST(VFOBSERDOL AS DECIMAL(18,2)) IS NULL OR TRY_CAST(VFOBSERDOL AS DECIMAL(18,2)) <= 0 THEN 'Valor FOB invalido o <= 0'
                WHEN TRY_CAST(VPESNET AS DECIMAL(18,2)) IS NULL OR TRY_CAST(VPESNET AS DECIMAL(18,2)) <= 0 THEN 'Peso neto invalido o <= 0'
                WHEN TRY_CAST(COALESCE(FEMB, FNUM) AS INT) IS NULL THEN 'Fecha invalida'
                ELSE 'Dato no reconocido'
            END
        FROM stg.SUNAT_Export
        WHERE TRY_CAST(VFOBSERDOL AS DECIMAL(18,2)) IS NULL 
           OR TRY_CAST(VFOBSERDOL AS DECIMAL(18,2)) <= 0
           OR TRY_CAST(VPESNET AS DECIMAL(18,2)) IS NULL 
           OR TRY_CAST(VPESNET AS DECIMAL(18,2)) <= 0
           OR TRY_CAST(COALESCE(FEMB, FNUM) AS INT) IS NULL;

        SET @Malas = @@ROWCOUNT;

        BEGIN TRANSACTION;

        -- 2. Sincronizar Dimensiones
        MERGE dm.Dim_Operador AS TARGET
        USING (SELECT DISTINCT NDOC, DNOMBRE FROM stg.SUNAT_Export WHERE NDOC IS NOT NULL AND LEN(NDOC) = 11) AS SOURCE
        ON TARGET.RUC = SOURCE.NDOC
        WHEN NOT MATCHED THEN
            INSERT (RUC, RazonSocial, EsEmpresaFoco)
            VALUES (SOURCE.NDOC, UPPER(SOURCE.DNOMBRE), CASE WHEN SOURCE.NDOC = '20451779711' THEN 1 ELSE 0 END);

        MERGE dm.Dim_ProductoArancel AS TARGET
        USING (
            SELECT DISTINCT PART_NANDI, MAX(DCOM) AS DCOM,
                CASE WHEN PART_NANDI LIKE '0806%' THEN 'Uva de Mesa' ELSE 'Arandano' END AS Cultivo
            FROM stg.SUNAT_Export 
            WHERE PART_NANDI IS NOT NULL
            GROUP BY PART_NANDI
        ) AS SOURCE
        ON TARGET.SubpartidaNacional = SOURCE.PART_NANDI
        WHEN NOT MATCHED THEN
            INSERT (SubpartidaNacional, DescripcionArancel, TipoCultivo)
            VALUES (SOURCE.PART_NANDI, UPPER(SOURCE.DCOM), SOURCE.Cultivo);

        MERGE dm.Dim_PaisDestino AS TARGET
        USING (SELECT DISTINCT CPAIDES FROM stg.SUNAT_Export WHERE CPAIDES IS NOT NULL) AS SOURCE
        ON TARGET.CodigoISO = SOURCE.CPAIDES
        WHEN NOT MATCHED THEN
            INSERT (CodigoISO, NombrePais, Continente, EsTradicional)
            VALUES (SOURCE.CPAIDES, UPPER(SOURCE.CPAIDES), 'EXTERIOR', CASE WHEN SOURCE.CPAIDES IN ('US', 'NL') THEN 1 ELSE 0 END);

        MERGE dm.Dim_AduanaPuerto AS TARGET
        USING (SELECT DISTINCT CADU FROM stg.SUNAT_Export WHERE CADU IS NOT NULL) AS SOURCE
        ON TARGET.CodigoAduana = SOURCE.CADU
        WHEN NOT MATCHED THEN
            INSERT (CodigoAduana, NombreAduana, PuertoEmbarque, EsPuertoPropio)
            VALUES (SOURCE.CADU, 'ADUANA ' + SOURCE.CADU, CASE WHEN SOURCE.CADU = '118' THEN 'PAITA' ELSE 'CALLAO' END, CASE WHEN SOURCE.CADU = '118' THEN 1 ELSE 0 END);

        -- Población dinámica de Dim_Tiempo
        INSERT INTO dm.Dim_Tiempo (IdTiempo, Fecha, Año, Mes, NombreMes, SemanaAño, CampaniaAgricola, EsSemanaPico)
        SELECT DISTINCT 
            CAST(COALESCE(s.FEMB, s.FNUM) AS INT) AS IdTiempo,
            CAST(CAST(COALESCE(s.FEMB, s.FNUM) AS VARCHAR(8)) AS DATE) AS Fecha,
            YEAR(CAST(CAST(COALESCE(s.FEMB, s.FNUM) AS VARCHAR(8)) AS DATE)) AS Año,
            MONTH(CAST(CAST(COALESCE(s.FEMB, s.FNUM) AS VARCHAR(8)) AS DATE)) AS Mes,
            DATENAME(MONTH, CAST(CAST(COALESCE(s.FEMB, s.FNUM) AS VARCHAR(8)) AS DATE)) AS NombreMes,
            DATEPART(WEEK, CAST(CAST(COALESCE(s.FEMB, s.FNUM) AS VARCHAR(8)) AS DATE)) AS SemanaAño,
            dm.fn_Campania(YEAR(CAST(CAST(COALESCE(s.FEMB, s.FNUM) AS VARCHAR(8)) AS DATE)), MONTH(CAST(CAST(COALESCE(s.FEMB, s.FNUM) AS VARCHAR(8)) AS DATE))),
            CASE WHEN MONTH(CAST(CAST(COALESCE(s.FEMB, s.FNUM) AS VARCHAR(8)) AS DATE)) IN (11, 12, 1) THEN 1 ELSE 0 END
        FROM stg.SUNAT_Export s
        WHERE TRY_CAST(COALESCE(s.FEMB, s.FNUM) AS INT) IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dm.Dim_Tiempo t WHERE t.IdTiempo = CAST(COALESCE(s.FEMB, s.FNUM) AS INT));

        -- 3. Inserción de Hechos
        INSERT INTO dm.Fact_ExportacionComercial (IdTiempo, IdOperador, IdProducto, IdPais, IdAduana, NumeroDeclaracion, ValorFOB_USD, PesoNeto_Kg, HashFila, IdCarga)
        SELECT 
            CAST(COALESCE(s.FEMB, s.FNUM) AS INT),
            o.IdOperador,
            p.IdProducto,
            d.IdPais,
            a.IdAduana,
            s.NDCL,
            CAST(s.VFOBSERDOL AS DECIMAL(18,2)),
            CAST(s.VPESNET AS DECIMAL(18,2)),
            HASHBYTES('SHA2_256', CONCAT(s.NDCL, s.CADU, s.PART_NANDI, s.VFOBSERDOL, s.VPESNET)),
            @IdCarga
        FROM stg.SUNAT_Export s
        INNER JOIN dm.Dim_Operador o        ON s.NDOC = o.RUC
        INNER JOIN dm.Dim_ProductoArancel p ON s.PART_NANDI = p.SubpartidaNacional
        INNER JOIN dm.Dim_PaisDestino d     ON s.CPAIDES = d.CodigoISO
        INNER JOIN dm.Dim_AduanaPuerto a    ON s.CADU = a.CodigoAduana
        WHERE TRY_CAST(s.VFOBSERDOL AS DECIMAL(18,2)) > 0
          AND TRY_CAST(s.VPESNET AS DECIMAL(18,2)) > 0
          AND NOT EXISTS (
              SELECT 1 FROM dm.Fact_ExportacionComercial f 
              WHERE f.HashFila = HASHBYTES('SHA2_256', CONCAT(s.NDCL, s.CADU, s.PART_NANDI, s.VFOBSERDOL, s.VPESNET))
          );

        SET @Buenas = @@ROWCOUNT;

        COMMIT TRANSACTION;

        UPDATE audit.BitacoraCarga
        SET FechaFin = SYSDATETIME(),
            FilasStaging = @TotalStaging,
            FilasBuenas = @Buenas,
            FilasRechazadas = @Malas,
            Estado = 'EXITOSO'
        WHERE IdCarga = @IdCarga;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        UPDATE audit.BitacoraCarga
        SET FechaFin = SYSDATETIME(),
            Estado = 'ERROR',
            MensajeError = ERROR_MESSAGE()
        WHERE IdCarga = @IdCarga;

        THROW;
    END CATCH
END;
GO