begin
	declare @user varchar(max); set @user='cenegasDefault';
	declare @grantScript varchar(max);
	set @grantScript = STUFF((select 'revoke execute on ' + name + ' to ' + @user + '; ' from sys.procedures order by 1 desc for xml path('')),1,0,'')
		+ STUFF((select 'grant execute on ' + name + ' to ' + @user + '; ' from sys.procedures where name like 'sps_%' or name like 'spp_%' order by 1 desc for xml path('')),1,0,'')
	exec(@grantScript);
	
	
	
	-- Asignar permisos de ejecución al type de importacion
	GRANT EXEC ON TYPE::[dbo].[importarType] TO [cenegasDefault]
	
end