ALTER PROCEDURE sps_reporte_mensualCRE
	@idsesion varchar(max),
	@pmuestreo varchar(max),
	@finicial varchar(max),
	@ffinal varchar(max),
	@resultado int --(1) Solo puntos de muestreo que cuentan con información fuera de especificacion (2) Informacion completa	
AS
BEGIN
	declare @error varchar(max)
	declare @idusuarioSESION varchar(max)
	declare @d_finicial date
	declare @d_ffinal date

	begin try
		execute sp_servicios_validar @idsesion, @@PROCID, @idusuarioSESION output
		if @finicial is null execute sp_error 'U','Favor de seleccionar fecha inicial'
		if @ffinal is null execute sp_error 'U','Favor de seleccionar fecha final'
		
		set @d_finicial=convert(date,@finicial,103)
		set @d_ffinal=convert(date,@ffinal,103)		
		
		if(@d_finicial>@d_ffinal) execute sp_error 'U','La fecha inicial debe ser menor que la final'
		if ( (@pmuestreo is null and DATEDIFF(day,@d_finicial,@d_ffinal)>31) or (@pmuestreo is not null and DATEDIFF(day,@d_finicial,@d_ffinal)>90) )
			execute sp_error 'U','El máximo rango de consulta sin puntos de muestreo son 31 dias y con puntos de muestreo 3 meses'
	
		declare @fcero datetime
		declare @fechas table(
			fecha datetime
		)
		
		select a.*,
			dateadd(hh,a.hcorte,convert(datetime,convert(date,a.fecha))) fcorte,	
			dateadd(hh, -23, dateadd(hh,a.hcorte,convert(datetime,convert(date,a.fecha)))) rango		
		into #base_rpromedio
		from v_promedios a
		where 
			(fecha>=@d_finicial and convert(date,fecha)<=@d_ffinal)
			and (@pmuestreo is null or idpmuestreo in (select col1 from dbo.fn_table(1,@pmuestreo)))

		select @d_finicial=min(fecha),@d_ffinal=max(fecha) 
		from #base_rpromedio
		
		select 
			a.idpmuestreo,
			a.idelemento,
			a.nalterno,
			a.elemento,
			a.fecha fpromedio,
			b.fecha fhorario,
			b.valor
		into #horarios
		from #base_rpromedio a 
			left join v_horarios b on a.idpmuestreo=b.idpmuestreo and a.idelemento=b.idelemento
				and b.fecha>=a.rango and b.fecha<=a.fcorte
				
		if @resultado=1
		begin
			select 
				distinct idpmuestreo,
				punto+'_'+dbo.fn_depurateText(nalterno) pmuestreo,
				null as idelemento,
				null as descripcion
			from 
				#base_rpromedio
		end
		else
		begin				

			select 
				idpmuestreo,
				idelemento,
				nalterno pmuestreo,
				elemento,
				fpromedio,
				max(valor) max_horario,
				avg(valor) prom_horario,
				min(valor) min_horario		
			into #maximos_horarios
			from #horarios
			group by idpmuestreo,idelemento,nalterno,elemento,fpromedio
			
			select idpmuestreo,idelemento,pmuestreo,elemento,fpromedio,max_horario valor,'grupo1' grupo into #tabla1 from #maximos_horarios
			union
			select idpmuestreo,idelemento,pmuestreo,elemento,fpromedio,prom_horario valor,'grupo2' grupo from #maximos_horarios
			union
			select idpmuestreo,idelemento,pmuestreo,elemento,fpromedio,min_horario valor,'grupo3' grupo from #maximos_horarios
			
			select 
				*,
				case 
					when celemento='metano' then 1					
					when celemento='oxigeno' then 1
					when celemento='bioxidocarbono' then 2
					when celemento='nitrogeno' then 3
					when celemento='totalinertes' then 4
					when celemento='etano' then 5										
					when celemento='temprocio' then 6
					when celemento='humedad' then 7
					when celemento='podercalorifico' then 8
					when celemento='indicewoobe' then 9																		
					when celemento='acidosulfhidrico' then 10
					when celemento='azufretotal' then 11
				end orden
			from #tabla1
			
			--select * from #tabla1

			select 
				idpmuestreo,
				idelemento,
				pmuestreo,
				elemento,		
				min(max_horario) minimo,
				max(max_horario) maximo,
				avg(max_horario) promedio,
				stdev(max_horario) desviacion,
				'grupo1' grupo2
			into #tabla2
			from #maximos_horarios
			group by idpmuestreo,idelemento,pmuestreo,elemento
			union
			select 
				idpmuestreo,
				idelemento,
				pmuestreo,
				elemento,		
				min(prom_horario) minimo,
				max(prom_horario) maximo,
				avg(prom_horario) promedio,
				stdev(prom_horario) desviacion,
				'grupo2' grupo2			
			from #maximos_horarios
			group by idpmuestreo,idelemento,pmuestreo,elemento	
			union
			select 
				idpmuestreo,
				idelemento,
				pmuestreo,
				elemento,		
				min(min_horario) minimo,
				max(min_horario) maximo,
				avg(min_horario) promedio,
				stdev(min_horario) desviacion,
				'grupo3' grupo2			
			from #maximos_horarios
			group by idpmuestreo,idelemento,pmuestreo,elemento								
			
			select a.*,b.minimo,b.maximo,b.promedio,b.desviacion,b.grupo2,
				dbo.fn_datetimeToString(a.fpromedio,2) fpromedioS	
			from #tabla1 a
				left join #tabla2 b on a.idpmuestreo=b.idpmuestreo and a.idelemento=b.idelemento
			order by a.pmuestreo,a.orden
			
		end
		
	end try
	begin catch
		set @error = error_message()
		execute sp_error 'S', @error
	end catch
END
	




