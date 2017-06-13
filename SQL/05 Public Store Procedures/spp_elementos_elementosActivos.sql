CREATE PROCEDURE [dbo].[spp_elementos_elementosActivos] 
	@deleted CHAR(1) = NULL
AS
BEGIN
	select COUNT(idelemento) AS activeRows 
	from v_elementos
	where @deleted IS NULL OR UPPER( deleted ) = UPPER( @deleted ) 
	;
END

