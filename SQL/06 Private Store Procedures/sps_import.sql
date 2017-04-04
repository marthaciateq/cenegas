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
	
	
	
		
	
	
	
	BEGIN TRANSACTION;
	
	BEGIN TRY
		EXECUTE sp_servicios_validar @idsesion, @@PROCID, @userId OUTPUT;
		
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
				 )
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
				
		FROM @recordsByHour
		WHERE  punto IS NOT NULL   AND   nombreAlterno IS NOT NULL   AND   fecha IS NOT NULL;
		
		
		-- 1.- Registrar el intento de importación de registros por hora
		INSERT INTO bdatos ( idbdatos, idusuario, fcarga, finicial , ffinal    , actualizar, narchivo  , noriginal         , insertados, actualizados, tipoArchivo )
		            VALUES ( @idHours, @userId  , @date , @initDate, @finalDate, @isUpdate , @hoursName, @originalHoursName,          0,            0, 'H' );



		


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
				 )
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
				
		FROM @summaryOfRecords
		WHERE  punto IS NOT NULL   AND   nombreAlterno IS NOT NULL   AND    fecha IS NOT NULL;
		
		
		-- 2.- Insertar los registros del resumen
		
		INSERT INTO bdatos ( idbdatos  , idusuario, fcarga, finicial , ffinal    , actualizar, narchivo    , noriginal           , insertados, actualizados, tipoArchivo )
		            VALUES ( @idSummary, @userId  , @date , @initDate, @finalDate, @isUpdate , @summaryName, @originalSummaryName,          0,            0, 'P' );

		
		
		
		--3.- Iniciar el guardado de registros
		EXEC dbo.spp_horarios_processImportsTable   @idHours, @updateRecords;
		EXEC dbo.spp_promedios_processImportsTable   @idSummary, @updateRecords;
		
		
		-- 4.- Si no definió rangos de fecha, Registrar la fecha inicial y final de la carga de registros importados a la tabla Registros.
		
		IF (@initDate IS NULL   AND   @finalDate IS NULL) BEGIN
			-- Actualizar el registro de importacion de mediciones por hora
			SELECT @initDate = MIN (fecha), @finalDate = MAX(fecha) FROM dbo.registros WHERE idbdatos =  @idHours;
			UPDATE dbo.bdatos SET finicial = @initDate, ffinal = @finalDate WHERE idbdatos = @idHours;
			
			
			-- Actualizar el registro de importacion de mediciones por promedio
			SELECT @initDate = MIN (fecha), @finalDate = MAX(fecha) FROM dbo.rpromedio WHERE idbdatos =  @idSummary;
			UPDATE dbo.bdatos SET finicial = @initDate, ffinal = @finalDate WHERE idbdatos = @idSummary;
		END
		
		
		
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

