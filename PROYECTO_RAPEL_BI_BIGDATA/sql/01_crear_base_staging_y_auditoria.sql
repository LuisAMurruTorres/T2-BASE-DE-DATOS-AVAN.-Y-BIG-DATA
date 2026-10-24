USE master;
GO

IF DB_ID(N'DM_Rapel_ComercioExterior') IS NULL
    CREATE DATABASE DM_Rapel_ComercioExterior;
GO

USE DM_Rapel_ComercioExterior;
GO

-- Esquemas
IF SCHEMA_ID(N'stg')   IS NULL EXEC (N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'dm')    IS NULL EXEC (N'CREATE SCHEMA dm');
IF SCHEMA_ID(N'audit') IS NULL EXEC (N'CREATE SCHEMA audit');
GO

-- Staging SUNAT (columnas oficiales del microdato)
IF OBJECT_ID(N'stg.SUNAT_Export', N'U') IS NOT NULL DROP TABLE stg.SUNAT_Export;
CREATE TABLE stg.SUNAT_Export
(
    CADU        NVARCHAR(10)  NULL,
    FANO        NVARCHAR(10)  NULL,
    NDCL        NVARCHAR(40)  NULL,
    FNUM        NVARCHAR(20)  NULL,
    FEMB        NVARCHAR(20)  NULL,
    NDOC        NVARCHAR(15)  NULL,
    DNOMBRE     NVARCHAR(200) NULL,
    CPAIDES     NVARCHAR(10)  NULL,
    PART_NANDI  NVARCHAR(15)  NULL,
    DCOM        NVARCHAR(250) NULL,
    VFOBSERDOL  NVARCHAR(40)  NULL,
    VPESNET     NVARCHAR(40)  NULL
);
GO

-- Staging BCRP
IF OBJECT_ID(N'stg.BCRP_Mensual', N'U') IS NOT NULL DROP TABLE stg.BCRP_Mensual;
CREATE TABLE stg.BCRP_Mensual
(
    PeriodoTexto NVARCHAR(20) NULL,
    ValorTexto   NVARCHAR(40) NULL
);
GO

-- Staging Catálogo ISO Países
IF OBJECT_ID(N'stg.Pais_ISO', N'U') IS NOT NULL DROP TABLE stg.Pais_ISO;
CREATE TABLE stg.Pais_ISO
(
    CodigoISO  CHAR(2)       NOT NULL PRIMARY KEY,
    NombrePais NVARCHAR(100) NOT NULL,
    Continente NVARCHAR(50)  NOT NULL
);
GO

-- Auditoría: Bitácora de Carga
IF OBJECT_ID(N'audit.BitacoraCarga', N'U') IS NOT NULL DROP TABLE audit.BitacoraCarga;
CREATE TABLE audit.BitacoraCarga
(
    IdCarga          BIGINT IDENTITY(1,1) PRIMARY KEY,
    FechaInicio      DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    FechaFin         DATETIME2(0) NULL,
    FilasStaging     INT          NULL,
    FilasBuenas      INT          NULL,
    FilasRechazadas  INT          NULL,
    Estado           VARCHAR(20)  NOT NULL DEFAULT 'EN PROCESO',
    MensajeError     NVARCHAR(MAX) NULL,
    Usuario          NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()
);
GO

-- Auditoría: Filas Rechazadas
IF OBJECT_ID(N'audit.FilasRechazadas', N'U') IS NOT NULL DROP TABLE audit.FilasRechazadas;
CREATE TABLE audit.FilasRechazadas
(
    IdRechazo     BIGINT IDENTITY(1,1) PRIMARY KEY,
    IdCarga       BIGINT        NULL REFERENCES audit.BitacoraCarga(IdCarga),
    FechaRechazo  DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME(),
    CADU          NVARCHAR(10)  NULL,
    NDCL          NVARCHAR(40)  NULL,
    FNUM          NVARCHAR(20)  NULL,
    FEMB          NVARCHAR(20)  NULL,
    NDOC          NVARCHAR(15)  NULL,
    DNOMBRE       NVARCHAR(200) NULL,
    CPAIDES       NVARCHAR(10)  NULL,
    PART_NANDI    NVARCHAR(15)  NULL,
    VFOBSERDOL    NVARCHAR(40)  NULL,
    VPESNET       NVARCHAR(40)  NULL,
    MotivoRechazo NVARCHAR(250) NOT NULL
);
GO