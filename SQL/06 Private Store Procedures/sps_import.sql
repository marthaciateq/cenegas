
-- =============================================
-- Author:		Angel Hernandez
-- Create date: marzo 2017
-- Description:	Importa las mediciones y las guarda en la tabla importaciones pasa ser tratadas posteriormente.
-- =============================================
CREATE PROCEDURE [dbo].[sps_import]
	-- Add the parameters for the stored procedure here
	  @initDate            DATETIME = NULL
	, @finalDate           DATETIME = NULL
	, @updateRecords       BIT
	, @idsesion            CHAR(32) 
	, @hoursName           VARCHAR(256)
	, @originalHoursName   VARCHAR(256)
	, @summaryName         VARCHAR(256)
	, @originalSummaryName VARCHAR(256)
	, @recordsByHour       AS dbo.importarType READONLY
	, @summaryOfRecords    AS dbo.importarType READONLY
	
AS
BEGIN
	DECLARE @NULLERROR     BIGINT = 515
	DECLARE @USERERROR     BIGINT = 50000
	DECLARE @SEVERITY      INT    = 15     --Severity levels from 0 through 18 can be specified by any user.
	DECLARE @STATE         INT    = 100    --Is an integer from 0 through 255. Negative values or values larger than 255 generate an error.
	DECLARE @errorMsg      VARCHAR(max)='SQL%d%s'
	
	
	DECLARE @idHours    CHAR(32) = dbo.fn_randomKey();
	DECLARE @idSummary  CHAR(32) = dbo.fn_randomKey();
	DECLARE @date       DATETIME = GETDATE();
	DECLARE @isUpdate   CHAR(1)
	DECLARE @userId     CHAR(32) 
	

	SET NOCOUNT ON;
	
	SET @isUpdate = CASE WHEN @updateRecords = 1 THEN 'S' ELSE 'N' END;
	
	
	BEGIN TRY
		
		EXECUTE sp_servicios_validar @idsesion, @@PROCID, @userId OUTPUT;
	
		
		BEGIN TRANSACTION;
	
		-- 1.5.- Insertar de inmediato los registros que cumplen el rango de fechas valido
		INSERT INTO dbo.importacionesHorarios( 
				idbdatos
				, punto
				, nombreAlterno
				, fecha
				, metano
				, bioxidoCarbono
				, nitrogeno
				, totalInertes
				, etano
				, tempRocio
				, humedad
				, poderCalorifico
				, indiceWoobe
				, acidoSulfhidrico
				, azufreTotal
				, oxigeno )
		SELECT  DISTINCT  
				@idHours
				, punto
				, nombreAlterno
				, fecha
				, metano
				, bioxidoCarbono
				, nitrogeno
				, totalInertes
				, etano
				, tempRocio
				, humedad
				, poderCalorifico
				, indiceWoobe
				, acidoSulfhidrico
				, azufreTotal
				, oxigeno
		FROM @recordsByHour;
		
		
		-- 1.- Registrar el intento de importación de registros por hora
		INSERT INTO bdatos ( idbdatos, idusuario, fcarga, finicial , ffinal    , actualizar, narchivo  , noriginal         , insertados, actualizados )
		            VALUES ( @idHours, @userId  , @date , @initDate, @finalDate, @isUpdate , @hoursName, @originalHoursName,          0,            0 );



		


		-- 2.5.- Insertar de inmediato los registros de resumen que cumplen el rango de fechas valido
		INSERT INTO dbo.importacionesPromedios( 
				idbdatos
				, punto
				, nombreAlterno
				, fecha
				, metano
				, bioxidoCarbono
				, nitrogeno
				, totalInertes
				, etano
				, tempRocio
				, humedad
				, poderCalorifico
				, indiceWoobe
				, acidoSulfhidrico
				, azufreTotal
				, oxigeno )
		SELECT    DISTINCT
				  @idSummary
				, punto
				, nombreAlterno
				, fecha
				, metano
				, bioxidoCarbono
				, nitrogeno
				, totalInertes
				, etano
				, tempRocio
				, humedad
				, poderCalorifico
				, indiceWoobe
				, acidoSulfhidrico
				, azufreTotal
				, oxigeno
		FROM @summaryOfRecords;
		
		
		-- 2.- Insertar los registros del resumen
		
		INSERT INTO bdatos ( idbdatos  , idusuario, fcarga, finicial , ffinal    , actualizar, narchivo    , noriginal           , insertados, actualizados )
		            VALUES ( @idSummary, @userId  , @date , @initDate, @finalDate, @isUpdate , @summaryName, @originalSummaryName,          0,            0 );

		
		
		
		--3.- Iniciar el guardado de registros
		EXEC dbo.spp_horarios_processImportsTable   @idHours, @updateRecords;
		EXEC dbo.spp_promedios_processImportsTable   @idSummary, @updateRecords;
		
		
		
		-- Eliminar de las tablas de importacion los registros importados.
		DELETE FROM dbo.importacionesHorarios  WHERE idbdatos = @idHours;
		DELETE FROM dbo.importacionesPromedios WHERE idbdatos = @idSummary;
		
		-- Eliminar los registros de las tablas de swap
		
		DELETE FROM dbo.registros_swap WHERE idbdatos = @idHours;
		DELETE FROM dbo.rpromedio_swap WHERE idbdatos = @idSummary;
		
		
		COMMIT TRANSACTION;
		
	END TRY	
	BEGIN CATCH
		ROLLBACK TRANSACTION;

		SET @errorMsg= ERROR_MESSAGE();
		EXECUTE sp_error 'S', @errorMsg;
	END CATCH

END
