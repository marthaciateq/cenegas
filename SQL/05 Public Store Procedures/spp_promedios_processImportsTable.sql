-- =============================================
-- Author:		Angel Hernandez
-- Create date: marzo 2017
-- Description:	Trata la información de la tabla de importaciones para ser guardada en la tabla destino registros.
-- =============================================
CREATE PROCEDURE [dbo].[spp_promedios_processImportsTable]
	-- Add the parameters for the stored procedure here
	    @idbdatos       VARCHAR(32)
	  , @isUpdate       BIT
	  , @viewHowChanges BIT
AS
BEGIN
	
	SET NOCOUNT ON;
	

	DECLARE @VALIDO  CHAR(1) = 1;
	
	DECLARE @UPDATED_RECORDS INT = 0;
	DECLARE @INSERTED_RECORDS INT = 0;
	

	IF ( @isUpdate = 1 ) BEGIN
	-- Se insertan nuevos registros y se actualiza el valor de los existentes porque así lo solicito el usuario
		MERGE dbo.PROMEDIOS AS targetTable
		USING dbo.importacionesPromedios AS sourceTable
		ON (     sourceTable.idbdatos    = @idbdatos
			 AND targetTable.idpmuestreo = sourceTable.idpmuestreo
			 AND convert(date,targetTable.fecha)       = convert(date,sourceTable.fecha)
		 )
		 WHEN NOT MATCHED BY TARGET THEN -- Si son registros nuevos, se insertan
			INSERT (idbdatos 
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
					, oxigeno ) 
			VALUES (@idbdatos
					, sourceTable.idpmuestreo
					, sourceTable.fecha
					, sourceTable.metano
					, sourceTable.bioxidoCarbono
					, sourceTable.nitrogeno
					, sourceTable.totalInertes
					, sourceTable.etano
					, sourceTable.tempRocio
					, sourceTable.humedad
					, sourceTable.poderCalorifico
					, sourceTable.indiceWoobe
					, sourceTable.acidoSulfhidrico
					, sourceTable.azufreTotal
					, sourceTable.oxigeno)
		WHEN MATCHED AND (
					   sourceTable.metano            <> targetTable.metano
					OR sourceTable.bioxidoCarbono    <> targetTable.bioxidoCarbono
					
					OR sourceTable.nitrogeno         <> targetTable.nitrogeno
					OR sourceTable.totalInertes      <> targetTable.totalInertes
					OR sourceTable.etano             <> targetTable.etano
					OR sourceTable.tempRocio         <> targetTable.tempRocio
					OR sourceTable.humedad           <> targetTable.humedad
					
					OR sourceTable.poderCalorifico   <> targetTable.poderCalorifico
					OR sourceTable.indiceWoobe       <> targetTable.indiceWoobe
					OR sourceTable.acidoSulfhidrico  <> targetTable.acidoSulfhidrico
					OR sourceTable.azufreTotal       <> targetTable.azufreTotal
					OR sourceTable.oxigeno           <> targetTable.oxigeno
			 )	THEN   -- Si ya existen, se actualizan
			UPDATE SET  targetTable.fecha = sourceTable.fecha
					,targetTable.metano         = sourceTable.metano
					 , targetTable.bioxidoCarbono  = sourceTable.bioxidoCarbono
					 , targetTable.nitrogeno       = sourceTable.nitrogeno
					 , targetTable.totalInertes    = sourceTable.totalInertes
					 , targetTable.etano           = sourceTable.etano
					 , targetTable.tempRocio       = sourceTable.tempRocio
					 , targetTable.humedad         = sourceTable.humedad
					 , targetTable.poderCalorifico = sourceTable.poderCalorifico
					 , targetTable.indiceWoobe     = sourceTable.indiceWoobe
					 , targetTable.acidoSulfhidrico  = sourceTable.acidoSulfhidrico
					 , targetTable.azufreTotal     = sourceTable.azufreTotal
					 , targetTable.oxigeno         = sourceTable.oxigeno
			 
		OUTPUT -- Guardar los registros en labitacora
			@idbdatos
			, INSERTED.idpmuestreo 
			, INSERTED.fecha       
			, INSERTED.metano        
			, INSERTED.bioxidoCarbono
			
			, INSERTED.nitrogeno   
			, INSERTED.totalInertes 
			, INSERTED.etano        
			, INSERTED.tempRocio   
			, INSERTED.humedad      
			
			, INSERTED.poderCalorifico  
			, INSERTED.indiceWoobe      
			, INSERTED.acidoSulfhidrico 
			, INSERTED.azufreTotal      
			, INSERTED.oxigeno          
			, SUBSTRING($ACTION, 1, 1)
			INTO BPROMEDIOS
		;
		
		
	END
	ELSE BEGIN
		-- Se insertan los nuevos registros
		MERGE dbo.PROMEDIOS AS targetTable
		USING dbo.importacionesPromedios AS sourceTable
		ON (     sourceTable.idbdatos    = @idbdatos
			 AND targetTable.idpmuestreo = sourceTable.idpmuestreo
			 AND convert(date,targetTable.fecha)       =  convert(date,sourceTable.fecha)
		 )
		 WHEN NOT MATCHED BY TARGET THEN -- Si son registros nuevos, se insertan
			INSERT (idbdatos 
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
					, oxigeno ) 
			VALUES (@idbdatos
					, sourceTable.idpmuestreo
					, sourceTable.fecha
					, sourceTable.metano
					, sourceTable.bioxidoCarbono
					, sourceTable.nitrogeno
					, sourceTable.totalInertes
					, sourceTable.etano
					, sourceTable.tempRocio
					, sourceTable.humedad
					, sourceTable.poderCalorifico
					, sourceTable.indiceWoobe
					, sourceTable.acidoSulfhidrico
					, sourceTable.azufreTotal
					, sourceTable.oxigeno)
		OUTPUT
			  @idbdatos
			, INSERTED.idpmuestreo
			, INSERTED.fecha      
			, INSERTED.metano      
			, INSERTED.bioxidoCarbono
			
			, INSERTED.nitrogeno   
			, INSERTED.totalInertes
			, INSERTED.etano        
			, INSERTED.tempRocio    
			, INSERTED.humedad      
			
			, INSERTED.poderCalorifico  
			, INSERTED.indiceWoobe      
			, INSERTED.acidoSulfhidrico 
			, INSERTED.azufreTotal      
			, INSERTED.oxigeno          
			
			, SUBSTRING($ACTION, 1, 1)
			INTO BPROMEDIOS
		;
		
		
		
			
	END		
	
	
	IF ( @viewHowChanges = 0) BEGIN
	
		INSERT INTO RPROMEDIO
		SELECT dbo.fn_randomKey(),a.idbdatos,a.idpmuestreo,b.idelemento,a.fecha,valor
		FROM 
		   (SELECT bpromedios.*
		   FROM bpromedios where idbdatos=@idbdatos and estatus='I') p
		UNPIVOT
		   (valor FOR concepto IN 
			  (metano, bioxidocarbono, nitrogeno, totalinertes,etano,temprocio,humedad,podercalorifico,indicewoobe,acidosulfhidrico,oxigeno,azufretotal)
		)AS a
			inner join elementos b on b.codigo=a.concepto;
			
		UPDATE x set promedio=z.valor
			from rpromedio x inner join (
				SELECT a.idpmuestreo,b.idelemento,a.fecha,valor
				FROM 
				   (
					   select bpromedios.*
					   from bpromedios
					   where idbdatos=@idbdatos 
						and estatus='U' 
						and(
							metano<>null
							or bioxidocarbono<>null
							or nitrogeno<>null
							or totalinertes<>null
							or etano<>null
							or temprocio<>null
							or humedad<>null
							or podercalorifico<>null
							or indicewoobe<>null
							or acidosulfhidrico<>null			    
							or oxigeno<>null	
							or azufretotal<>null
						)	    			    
				   ) p
				UNPIVOT
				   (valor FOR concepto IN 
					  (metano, bioxidocarbono, nitrogeno, totalinertes,etano,temprocio,humedad,podercalorifico,indicewoobe,acidosulfhidrico,oxigeno,azufretotal)
				)AS a
					inner join elementos b on b.codigo=a.concepto	
		) z	 on x.idpmuestreo=z.idpmuestreo and x.fecha=z.fecha	and x.idelemento=z.idelemento
		
	END
	
	
	SELECT @INSERTED_RECORDS  = COUNT(idbdatos) FROM dbo.BPROMEDIOS WHERE idbdatos = @idbdatos AND estatus = 'I';
	SELECT @UPDATED_RECORDS   = COUNT(idbdatos) FROM dbo.BPROMEDIOS WHERE idbdatos = @idbdatos AND estatus = 'U';
		
	UPDATE dbo.bdatos SET insertados = @INSERTED_RECORDS, actualizados = @UPDATED_RECORDS    WHERE idbdatos = @idbdatos;
	
END



