/* ============================================================================
   06_job_sql_server_agent.sql
   Proyecto : Data Mart de Inteligencia Comercial - Sociedad Agrícola Rapel S.A.C.
   Contenido:
     1. Creación y asignación de Roles de Seguridad (sin contraseñas)
     2. Configuración y automatización del Job en SQL Server Agent
   ============================================================================ */

USE DM_Rapel_ComercioExterior;
GO

-- ============================================================================
-- PARTE 1: ROLES DE SEGURIDAD Y PERMISOS POR ESQUEMA (SIN CONTRASEÑAS)
-- ============================================================================

-- 1. Rol para el Proceso ETL (Escribe en Staging, Hechos y Auditoría)
IF DATABASE_PRINCIPAL_ID('Rol_ETL') IS NULL
    CREATE ROLE Rol_ETL;
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::stg TO Rol_ETL;
GRANT SELECT, INSERT, UPDATE ON SCHEMA::audit TO Rol_ETL;
GRANT EXECUTE ON SCHEMA::dm TO Rol_ETL;
GRANT SELECT, INSERT ON SCHEMA::dm TO Rol_ETL;
GO

-- 2. Rol para Power BI y Analistas Comerciales (Solo Lectura)
IF DATABASE_PRINCIPAL_ID('Rol_Analista_BI') IS NULL
    CREATE ROLE Rol_Analista_BI;
GO

GRANT SELECT ON SCHEMA::dm TO Rol_Analista_BI;    -- Solo lee vistas y tablas dimensionales
DENY SELECT ON SCHEMA::audit TO Rol_Analista_BI;  -- Protege logs de errores y bitácoras
DENY SELECT ON SCHEMA::stg TO Rol_Analista_BI;    -- No accede a datos crudos en Staging
GO

-- 3. Rol para Auditoría y Gobierno de Datos (Lectura de Bitácoras)
IF DATABASE_PRINCIPAL_ID('Rol_Auditor') IS NULL
    CREATE ROLE Rol_Auditor;
GO

GRANT SELECT ON SCHEMA::audit TO Rol_Auditor;
GRANT SELECT ON SCHEMA::dm TO Rol_Auditor;
GO


-- ============================================================================
-- PARTE 2: AUTOMATIZACIÓN DEL JOB EN SQL SERVER AGENT
-- ============================================================================

USE msdb;
GO

-- Si el Job ya existe, se elimina para recrearlo limpiamente
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = N'Job_Carga_DataMart_Comercial')
BEGIN
    EXEC sp_delete_job @job_name = N'Job_Carga_DataMart_Comercial';
END
GO

-- 1. Crear el Job
EXEC sp_add_job 
    @job_name = N'Job_Carga_DataMart_Comercial',
    @enabled = 1,
    @notify_level_eventlog = 2,
    @description = N'Carga semanal automatizada del Data Mart Comercial de Sociedad Agrícola Rapel S.A.C.';
GO

-- 2. Paso 1 del Job: Ejecutar el Procedimiento Almacenado ETL
EXEC sp_add_jobstep 
    @job_name = N'Job_Carga_DataMart_Comercial',
    @step_name = N'Paso 1: Ejecutar ETL Data Mart Comercial',
    @subsystem = N'TSQL',
    @command = N'EXEC DM_Rapel_ComercioExterior.dm.usp_CargarDataMartComercial;',
    @database_name = N'DM_Rapel_ComercioExterior',
    @retry_attempts = 1,
    @retry_interval = 5;
GO

-- 3. Programación semanal (Ejecución automática cada domingo a las 23:00)
EXEC sp_add_jobschedule 
    @job_name = N'Job_Carga_DataMart_Comercial', 
    @name = N'Horario_Semanal_Domingo_Noche',
    @enabled = 1,
    @freq_type = 8,                  -- Semanal
    @freq_interval = 1,              -- Domingo
    @freq_recurrence_factor = 1,
    @active_start_time = 230000;     -- 23:00:00 hrs
GO

-- 4. Asociar el Job al Servidor Local
EXEC sp_add_jobserver 
    @job_name = N'Job_Carga_DataMart_Comercial', 
    @server_name = N'(local)';
GO