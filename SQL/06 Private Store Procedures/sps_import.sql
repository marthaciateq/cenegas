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
	, @actionForNewPoints  CHAR(1) = NULL
	, @viewHowChanges      BIT
AS
BEGIN
	DECLARE @NULLERROR     BIGINT = 515;
	DECLARE @USERERROR     BIGINT = 50000;
	DECLARE @SEVERITY      INT    = 15;     --Severity levels from 0 through 18 can be specified by any user.
	DECLARE @STATE         INT    = 100;    --Is an integer from 0 through 255. Negative values or values larger than 255 generate an error.
	DECLARE @errorMsg      VARCHAR(max)='SQL%d%s';
	
	
	DECLARE @idHours    CHAR(32) = dbo.fn_randomKey();
	DECLARE @idSummary  CHAR(32) = dbo.fn_randomKey();
	DECLARE @date       DATETIME = GETDATE();
	DECLARE @isUpdate   CHAR(1);
	DECLARE @userId     CHAR(32);
	DECLARE @errorType  CHAR(1) = 'S';
	
	
	

	SET NOCOUNT ON;
	
	SET @isUpdate = CASE WHEN @updateRecords = 1 THEN 'S' ELSE 'N' END;
	
	
	
	
	BEGIN TRY
	BEGIN TRANSACTION;
	
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

		
		--2.5 Agregar los puntos de muestro que aun no existen
		EXEC dbo.spp_insertNuevosPuntosMuestreo   @idHours, @idSummary, @actionForNewPoints;
		
		
		
		
		-- 2.75 Agregar el idpmuestreo a los registros
		UPDATE importacionesH 
			SET importacionesH.idpmuestreo = pmuestreo.idpmuestreo
		FROM dbo.importacionesHorarios AS importacionesH 
		INNER JOIN (
				SELECT pmuestreo.idpmuestreo, importacionesHorarios.punto, nombreAlterno 
				FROM dbo.importacionesHorarios 
					INNER JOIN pmuestreo ON importacionesHorarios.punto = pmuestreo.punto AND importacionesHorarios.nombreAlterno = pmuestreo.nalterno
				WHERE dbo.importacionesHorarios.idbdatos = @idHours
			) AS pmuestreo
		 ON importacionesH.punto = pmuestreo.punto AND importacionesH.nombreAlterno = pmuestreo.nombreAlterno
		;
		
		
		UPDATE importacionesP
			SET importacionesP.idpmuestreo = pmuestreo.idpmuestreo
		FROM dbo.importacionesPromedios AS importacionesP
		INNER JOIN (
				SELECT pmuestreo.idpmuestreo, importacionesPromedios.punto, nombreAlterno 
				FROM dbo.importacionesPromedios 
					INNER JOIN pmuestreo ON importacionesPromedios.punto = pmuestreo.punto AND importacionesPromedios.nombreAlterno = pmuestreo.nalterno
				WHERE dbo.importacionesPromedios.idbdatos = @idSummary
			) AS pmuestreo
		 ON importacionesP.punto = pmuestreo.punto AND importacionesP.nombreAlterno = pmuestreo.nombreAlterno
		;
		
		-- Eliminar los registros que no tienen idpuntomuestreo (ignorarlos)
		DELETE FROM dbo.importacionesHorarios  WHERE idpmuestreo IS NULL;
		DELETE FROM dbo.importacionesPromedios WHERE idpmuestreo IS NULL;
		
		-- 3.- Tratar los registros fuera de fecha
		EXEC dbo.spp_horarios_processOutOfDateRecords @idHours;
		EXEC dbo.spp_promedios_processOutOfDateRecords @idSummary;
		
		
		-- 4.- Iniciar el guardado de registros
		EXEC dbo.spp_horarios_processImportsTable   @idHours, @updateRecords;
		EXEC dbo.spp_promedios_processImportsTable   @idSummary, @updateRecords;
		
		
		---- 5.- Si no definió rangos de fecha, Registrar la fecha inicial y final de la carga de registros importados a la tabla Registros.
		
		IF (@initDate IS NULL   AND   @finalDate IS NULL) BEGIN
			-- Actualizar el registro de importacion de mediciones por hora
			SELECT @initDate = MIN (fecha), @finalDate = MAX(fecha) FROM dbo.HORARIOS WHERE idbdatos =  @idHours;
			UPDATE dbo.bdatos SET finicial = @initDate, ffinal = @finalDate WHERE idbdatos = @idHours;
			
			
			-- Actualizar el registro de importacion de mediciones por promedio
			SELECT @initDate = MIN (fecha), @finalDate = MAX(fecha) FROM dbo.PROMEDIOS WHERE idbdatos =  @idSummary;
			UPDATE dbo.bdatos SET finicial = @initDate, ffinal = @finalDate WHERE idbdatos = @idSummary;
		END
		
		IF (@viewHowChanges = 1) BEGIN
		
			DECLARE @NEWS    INT = 0;
			DECLARE @UPDATES INT = 0;
			DECLARE @message VARCHAR(256);
			
			SET @errorType = 'U';
			
			SELECT @NEWS    = COUNT(idbdatos)  FROM   dbo.BHORARIOS   WHERE idbdatos = @idHours AND estatus = 'I';
			SELECT @UPDATES = COUNT(idbdatos)  FROM   dbo.BHORARIOS   WHERE idbdatos = @idHours AND estatus = 'U';
			
			SET @message = 'VALIDATION_HOW_CHANGE:{';
			
			SET @message = @message + '"horarios": { "inserts": ' + CAST(@NEWS AS VARCHAR(12)) + ', "updates":' + CAST(@UPDATES AS VARCHAR(12)) + '}'
			
			SELECT @NEWS    = COUNT(idbdatos)  FROM   dbo.BPROMEDIOS   WHERE idbdatos = @idSummary AND estatus = 'I';
			SELECT @UPDATES = COUNT(idbdatos)  FROM   dbo.BPROMEDIOS   WHERE idbdatos = @idSummary AND estatus = 'U';
			
			
			SET @message = @message + ', "promedios": { "inserts": ' + CAST(@NEWS AS VARCHAR(12)) + ', "updates":' + CAST(@UPDATES AS VARCHAR(12)) + '}'
			
			SET @message = @message + ', "CSVs": { "horarios":"' + @originalHoursName + '", "promedios": "' + @originalSummaryName + '"}'
			
			SET @message = @message + '}';
			
			RAISERROR (@message, @SEVERITY, @STATE);
		END
		
		
		-- Eliminar de las tablas de importacion los registros importados.
		DELETE FROM dbo.importacionesHorarios  WHERE idbdatos = @idHours;
		DELETE FROM dbo.importacionesPromedios WHERE idbdatos = @idSummary;
		
		
		
		
		
		
		COMMIT TRANSACTION;
		
	END TRY	
	BEGIN CATCH
		ROLLBACK TRANSACTION;

		SET @errorMsg= ERROR_MESSAGE();
		EXECUTE sp_error @errorType, @errorMsg;
	END CATCH

END


