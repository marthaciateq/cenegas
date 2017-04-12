-- =============================================
-- Author:		Angel Hernandez
-- Create date: marzo 2017
-- Description:	Inserta los reguistros fuera de fecha en la tabla de bitácora de registros
-- =============================================
CREATE PROCEDURE [dbo].[spp_promedios_processOutOfDateRecords]
	  @idbdatos    CHAR(32)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @outOfDateMessage    VARCHAR(32) = 'F';
	DECLARE @DAYS_AGO            INT         = 365 * -1;
	DECLARE @INIT_DATE           DATETIME    =  DATEADD( DAY, @DAYS_AGO, GETDATE() );
	DECLARE @OUT_OF_DATE_RECORDS INT         = 0;
	
	
	-- El manejo de la TRANSACCION y el CATCH se hacen en la llamada principal

	-- Insertar los registros que estan fuera de la fecha valida, desde la tabla de importación a la tabla de bitacora
	INSERT INTO dbo.BPROMEDIOS(idbdatos 
					, idpmuestreo
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
					, estatus ) 
			SELECT  @idbdatos
					, idpmuestreo
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
					, estatus
			FROM dbo.importacionesPromedios
			WHERE idbdatos = @idbdatos
				AND dbo.fn_dateTimeToDate( fecha ) < dbo.fn_dateTimeToDate( @INIT_DATE ) ;
			
		-- Borrar de la tabla de importacion los reguistros fuera de fecha
		DELETE FROM dbo.importacionesPromedios WHERE   idbdatos = @idbdatos   AND dbo.fn_dateTimeToDate( fecha ) < dbo.fn_dateTimeToDate( @INIT_DATE ) ;
		
		-- Contar cuantos registros hubo fuera de fecha
		SELECT @OUT_OF_DATE_RECORDS = COUNT(idbdatos) FROM dbo.BPROMEDIOS WHERE idbdatos = @idbdatos   AND  estatus = @outOfDateMessage;
		
		
		UPDATE dbo.bdatos SET fueraFecha = @OUT_OF_DATE_RECORDS WHERE idbdatos = @idbdatos;
		
END



