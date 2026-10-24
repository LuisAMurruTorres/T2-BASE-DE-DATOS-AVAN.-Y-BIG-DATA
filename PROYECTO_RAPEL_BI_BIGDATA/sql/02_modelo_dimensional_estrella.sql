USE DM_Rapel_ComercioExterior;
GO

-- 1. Dimensión Tiempo (con Año)
IF OBJECT_ID(N'dm.Dim_Tiempo', N'U') IS NOT NULL DROP TABLE dm.Dim_Tiempo;
CREATE TABLE dm.Dim_Tiempo
(
    IdTiempo         INT          NOT NULL PRIMARY KEY, -- YYYYMMDD
    Fecha            DATE         NOT NULL,
    Año              INT          NOT NULL,
    Mes              TINYINT      NOT NULL,
    NombreMes        VARCHAR(15)  NOT NULL,
    SemanaAño        TINYINT      NOT NULL,
    CampaniaAgricola VARCHAR(20)  NOT NULL,
    EsSemanaPico     BIT          NOT NULL DEFAULT 0
);
GO

-- 2. Dimensión Operador / Exportador
IF OBJECT_ID(N'dm.Dim_Operador', N'U') IS NOT NULL DROP TABLE dm.Dim_Operador;
CREATE TABLE dm.Dim_Operador
(
    IdOperador       INT IDENTITY(1,1) PRIMARY KEY,
    RUC              CHAR(11)      NOT NULL UNIQUE,
    RazonSocial      NVARCHAR(200) NOT NULL,
    EsEmpresaFoco    BIT           NOT NULL DEFAULT 0
);
GO

-- 3. Dimensión Producto Arancelario
IF OBJECT_ID(N'dm.Dim_ProductoArancel', N'U') IS NOT NULL DROP TABLE dm.Dim_ProductoArancel;
CREATE TABLE dm.Dim_ProductoArancel
(
    IdProducto          INT IDENTITY(1,1) PRIMARY KEY,
    SubpartidaNacional  CHAR(10)      NOT NULL UNIQUE,
    DescripcionArancel  NVARCHAR(250) NOT NULL,
    TipoCultivo         VARCHAR(50)   NOT NULL
);
GO

-- 4. Dimensión País Destino
IF OBJECT_ID(N'dm.Dim_PaisDestino', N'U') IS NOT NULL DROP TABLE dm.Dim_PaisDestino;
CREATE TABLE dm.Dim_PaisDestino
(
    IdPais           INT IDENTITY(1,1) PRIMARY KEY,
    CodigoISO        CHAR(2)       NOT NULL UNIQUE,
    NombrePais       NVARCHAR(100) NOT NULL,
    Continente       VARCHAR(50)   NOT NULL,
    EsTradicional    BIT           NOT NULL DEFAULT 0
);
GO

-- 5. Dimensión Aduana / Puerto
IF OBJECT_ID(N'dm.Dim_AduanaPuerto', N'U') IS NOT NULL DROP TABLE dm.Dim_AduanaPuerto;
CREATE TABLE dm.Dim_AduanaPuerto
(
    IdAduana         INT IDENTITY(1,1) PRIMARY KEY,
    CodigoAduana     CHAR(3)       NOT NULL UNIQUE,
    NombreAduana     NVARCHAR(100) NOT NULL,
    PuertoEmbarque   NVARCHAR(100) NOT NULL,
    EsPuertoPropio   BIT           NOT NULL DEFAULT 0
);
GO

-- 6. Tabla Puente Spark -> Data Mart
IF OBJECT_ID(N'dm.Agg_Spark_PaisSemana', N'U') IS NOT NULL DROP TABLE dm.Agg_Spark_PaisSemana;
CREATE TABLE dm.Agg_Spark_PaisSemana
(
    IdAggSpark       BIGINT IDENTITY(1,1) PRIMARY KEY,
    Año              INT            NOT NULL,
    SemanaAño        TINYINT        NOT NULL,
    CodigoPais       CHAR(2)        NOT NULL,
    TotalFOB_USD     DECIMAL(18,2)  NOT NULL,
    TotalPesoNeto_Kg DECIMAL(18,2)  NOT NULL,
    PrecioMedio_Kg   DECIMAL(18,4)  NOT NULL,
    IndiceHHI_Semanal DECIMAL(10,2) NULL,
    FechaProceso     DATETIME2(0)   NOT NULL DEFAULT SYSDATETIME()
);
GO

-- 7. Tabla de Hechos Comercial
IF OBJECT_ID(N'dm.Fact_ExportacionComercial', N'U') IS NOT NULL DROP TABLE dm.Fact_ExportacionComercial;
CREATE TABLE dm.Fact_ExportacionComercial
(
    IdHechoExportacion   BIGINT IDENTITY(1,1) PRIMARY KEY,
    IdTiempo             INT           NOT NULL REFERENCES dm.Dim_Tiempo(IdTiempo),
    IdOperador           INT           NOT NULL REFERENCES dm.Dim_Operador(IdOperador),
    IdProducto           INT           NOT NULL REFERENCES dm.Dim_ProductoArancel(IdProducto),
    IdPais               INT           NOT NULL REFERENCES dm.Dim_PaisDestino(IdPais),
    IdAduana             INT           NOT NULL REFERENCES dm.Dim_AduanaPuerto(IdAduana),
    NumeroDeclaracion    NVARCHAR(40)  NOT NULL,
    ValorFOB_USD         DECIMAL(18,2) NOT NULL,
    PesoNeto_Kg          DECIMAL(18,2) NOT NULL,
    PrecioUnitarioFOB_Kg AS (CASE WHEN PesoNeto_Kg > 0 THEN ROUND(ValorFOB_USD / PesoNeto_Kg, 4) ELSE 0 END) PERSISTED,
    HashFila             BINARY(32)    NOT NULL,
    IdCarga              BIGINT        NULL REFERENCES audit.BitacoraCarga(IdCarga)
);
GO

CREATE NONCLUSTERED INDEX IX_Fact_Tiempo   ON dm.Fact_ExportacionComercial(IdTiempo);
CREATE NONCLUSTERED INDEX IX_Fact_Operador ON dm.Fact_ExportacionComercial(IdOperador);
CREATE NONCLUSTERED INDEX IX_Fact_Pais     ON dm.Fact_ExportacionComercial(IdPais);
CREATE NONCLUSTERED INDEX IX_Fact_Hash     ON dm.Fact_ExportacionComercial(HashFila);
GO