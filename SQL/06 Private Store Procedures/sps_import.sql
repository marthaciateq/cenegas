-- =============================================
-- Author:		Angel Hernandez
-- Create date: marzo 2017
-- Description:	Importa las mediciones y las guarda en la tabla importaciones pasa ser tratadas posteriormente.
-- =============================================
CREATE PROCEDURE [dbo].[sps_import]
	-- Add the parameters for the stored procedure here
	  @initDate            DATETIME = NULL
	, @finalDate           DATETIME = NULL
	, @idsesion            CHAR(32) 
	, @hoursName           VARCHAR(256)
	, @originalHoursName   VARCHAR(256)
	, @summaryName         VARCHAR(256)
	, @originalSummaryName VARCHAR(256)
	, @recordsByHour       AS dbo.importarType READONLY
	, @summaryOfRecords    AS dbo.importarType READONLY
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
	DECLARE @userId     CHAR(32);
	
	DECLARE @duplicates TABLE (fecha DATETIME, punto VARCHAR(128), nombrealterno VARCHAR(128), Regs INT, origen CHAR(1))
	
	DECLARE @message VARCHAR(256);
	DECLARE @errorType  CHAR(1) = 'S';
	DECLARE @actionForNewPoints  CHAR(1) = NULL
	
	
	
	SET NOCOUNT ON;
	
	
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
				, azufreTotal
				, oxigeno
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
				, azufreTotal
				, oxigeno
		FROM @recordsByHour
		WHERE  punto IS NOT NULL   AND   nombreAlterno IS NOT NULL   AND   fecha IS NOT NULL;
		
		
		-- 1.- Registrar el intento de importación de registros por hora
		INSERT INTO bdatos ( idbdatos, idusuario, fcarga, finicial , ffinal    , narchivo  , noriginal         , nuevosPuntos       , insertados, tipoArchivo, deleted )
		            VALUES ( @idHours, @userId  , @date , @initDate, @finalDate, @hoursName, @originalHoursName, @actionForNewPoints,          0,   'H'      , 'N' );


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
				, oxigeno
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
				, azufreTotal
				, oxigeno
		FROM @summaryOfRecords
		WHERE  punto IS NOT NULL   AND   nombreAlterno IS NOT NULL   AND    fecha IS NOT NULL;
		
		
		-- 2.- Insertar los registros del resumen
		
		INSERT INTO bdatos ( idbdatos  , idusuario, fcarga, finicial , ffinal    , narchivo    , noriginal           , nuevosPuntos      , insertados, tipoArchivo, deleted )
		            VALUES ( @idSummary, @userId  , @date , @initDate, @finalDate, @summaryName, @originalSummaryName, @actionForNewPoints,         0, 'P'        , 'N' );
		            
		            
			-- 2.1 - Verificar si existen registros con la misma fecha y hora, punto y nombre Alterno
			INSERT INTO @duplicates( fecha, punto, nombrealterno, regs, origen)
			SELECT fecha, punto, nombrealterno, count(fecha) as regs, 'H' AS origen  FROM (
				SELECT fecha, dbo.fn_depurateText(punto) AS punto, dbo.fn_depurateText(nombrealterno) AS nombrealterno
				FROM [CENEGAS].[dbo].importacionesHorarios
				WHERE idbdatos =  @idHours
			) AS p
			GROUP BY fecha, punto, nombrealterno
			HAVING COUNT(fecha) > 1		  
			
			UNION ALL
			
			SELECT fecha, punto, nombrealterno, count(fecha) as regs, 'P' AS origen  FROM (
				SELECT fecha, dbo.fn_depurateText(punto) AS punto, dbo.fn_depurateText(nombrealterno) AS nombrealterno
				FROM [CENEGAS].[dbo].importacionesPromedios
				WHERE idbdatos =  @idSummary
			) AS p
			GROUP BY fecha, punto, nombrealterno
			HAVING COUNT(fecha) > 1		             
			
			
			IF ( ( SELECT ISNULL( COUNT(fecha), 0) FROM @duplicates ) > 0 ) BEGIN
				SET @message   = '';
				SET @errorType = 'U';
						
				RAISERROR (@message, @SEVERITY, @STATE);
			END
		
		
		--2.5 Agregar los puntos de muestro que aun no existen
		EXEC dbo.spp_insertNuevosPuntosMuestreo   @idHours, @idSummary, @actionForNewPoints OUTPUT;
		
		UPDATE dbo.bdatos SET nuevosPuntos = @actionForNewPoints WHERE idbdatos IN (@idHours, @idSummary);
		
	
		-- 2.75 Agregar el idpmuestreo a los registros
		UPDATE a
			SET a.idpmuestreo = b.idpmuestreo
		FROM importacionesHorarios a
			INNER JOIN pmuestreo b on dbo.fn_depurateText(a.punto)=dbo.fn_depurateText(b.punto) and dbo.fn_depurateText(a.nombreAlterno)=dbo.fn_depurateText(b.nalterno)
		WHERE a.idbdatos=@idHours
		
		UPDATE a
			SET a.idpmuestreo = b.idpmuestreo
		FROM importacionesPromedios a
			INNER JOIN pmuestreo b on dbo.fn_depurateText(a.punto)=dbo.fn_depurateText(b.punto) and dbo.fn_depurateText(a.nombreAlterno)=dbo.fn_depurateText(b.nalterno)
		WHERE a.idbdatos=@idSummary	
		
	
		-- Eliminar los registros que no tienen idpuntomuestreo (ignorarlos)
		DELETE FROM dbo.importacionesHorarios  WHERE idpmuestreo IS NULL;
		DELETE FROM dbo.importacionesPromedios WHERE idpmuestreo IS NULL;
		
			
		-- 4.- Iniciar el guardado de registros
		EXEC dbo.spp_horarios_processImportsTable    @idHours  , @viewHowChanges;
		EXEC dbo.spp_promedios_processImportsTable   @idSummary, @viewHowChanges;
		
		
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
		
			DECLARE @NEWS_H  INT = 0;
			DECLARE @NEWS_P  INT = 0;
			
			
			SET @errorType = 'U';
			
			SELECT @NEWS_H    = COUNT(idbdatos)  FROM   dbo.BHORARIOS    WHERE idbdatos = @idHours   AND estatus = 'I';
			SELECT @NEWS_P    = COUNT(idbdatos)  FROM   dbo.BPROMEDIOS   WHERE idbdatos = @idSummary AND estatus = 'I';
			
			SET @message = 'VALIDATION_HOW_CHANGE:{';
			
			SET @message = @message + '"inserts":{"horarios":' + CAST(@NEWS_H AS VARCHAR(12)) + ', "promedios":' + CAST(@NEWS_P AS VARCHAR(12)) + '}'
			
			SET @message = @message + ', "CSVs":{ "horarios":"' + @originalHoursName + '", "promedios": "' + @originalSummaryName + '"}'
			
			SET @message = @message + '}';
			
			RAISERROR (@message, @SEVERITY, @STATE);
		END
		
		
		---- Eliminar de las tablas de importacion los registros importados.
		DELETE FROM dbo.importacionesHorarios  WHERE idbdatos = @idHours;
		DELETE FROM dbo.importacionesPromedios WHERE idbdatos = @idSummary;
		
		COMMIT TRANSACTION;
		
	END TRY	
	BEGIN CATCH
		
	
	
		IF ( ( SELECT ISNULL( COUNT(fecha), 0) FROM @duplicates ) > 0 ) BEGIN
			
		
			DECLARE @records TABLE (idbdatos VARCHAR(32), punto  VARCHAR(128), nombreAlterno VARCHAR(128), fecha DATETIME
			, metano decimal(18, 10)
			, bioxidoCarbono decimal(18, 10)
			, nitrogeno decimal(18, 10)
			, totalInertes decimal(18, 10)
			, etano decimal(18, 10)
			, tempRocio decimal(18, 10)
			, humedad decimal(18, 10)
			, poderCalorifico decimal(18, 10)
			, indiceWoobe decimal(18, 10)
			, acidoSulfhidrico decimal(18, 10)
			, azufreTotal decimal(18, 10)
			, oxigeno decimal(18, 10)
			, origen CHAR(1)
			)
			
			INSERT INTO @records ( idbdatos
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
					, origen
			)
			SELECT  @idHours
					, horarios.punto
					, horarios.nombreAlterno
					, horarios.fecha
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
					, 'H'
			FROM @duplicates AS duplicates
			INNER JOIN dbo.importacionesHorarios AS horarios
			ON duplicates.fecha = horarios.fecha AND  duplicates.punto = dbo.fn_depurateText(horarios.punto) AND duplicates.nombrealterno = dbo.fn_depurateText(horarios.nombrealterno)
			WHERE origen = 'H'
		
			UNION
		
			SELECT   @idSummary
					, promedios.punto
					, promedios.nombreAlterno
					, promedios.fecha
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
					, 'P'
			FROM @duplicates AS duplicates
			INNER JOIN dbo.importacionesPromedios AS promedios
			ON duplicates.fecha = promedios.fecha AND  duplicates.punto = dbo.fn_depurateText(promedios.punto) AND duplicates.nombrealterno = dbo.fn_depurateText(promedios.nombrealterno)
			WHERE origen = 'P'
		END
	
	
		ROLLBACK TRANSACTION;
		
		DECLARE @horarios VARCHAR(56) = 'null';
		DECLARE @promedios VARCHAR(56) = 'null';
		
		-- Si existen registros duplicados se crean los registros para posteriormente consultar un reporte.
		IF ( ( SELECT ISNULL( COUNT(fecha), 0) FROM @duplicates ) > 0 ) BEGIN
			
			IF ( (SELECT COUNT (idbdatos) FROM @records WHERE origen = 'H') > 0 ) BEGIN
				INSERT INTO dbo.bdatosDuplicados( idbdatos, idusuario, fcarga, noriginal, tipoArchivo) VALUES (@idHours  , @userId, @date, @originalHoursName  , 'H');
				
				SET @horarios = '"' + @idHours + '"';
			
			END
			
			IF ( (SELECT COUNT (idbdatos) FROM @records WHERE origen = 'P') > 0 ) BEGIN
			    INSERT INTO dbo.bdatosDuplicados( idbdatos, idusuario, fcarga, noriginal, tipoArchivo) VALUES (@idSummary, @userId, @date, @originalSummaryName, 'P');
			
				SET @promedios = '"' + @idSummary + '"';
			END
		
			INSERT INTO dbo.importacionesRegistrosDuplicados
						( idbdatos
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
						)
			SELECT        idbdatos
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
			FROM @records;
			
			SET @errorMsg = 'VALIDATION_DUPLICATE_RECORDS:{"idHorarios":' + @horarios + ', "idPromedios":' + @promedios + '}';
			EXECUTE sp_error @errorType, @errorMsg;
		END 
		ELSE  BEGIN
			SET @errorMsg= ERROR_MESSAGE();
			EXECUTE sp_error @errorType, @errorMsg;
		END
	END CATCH

END






