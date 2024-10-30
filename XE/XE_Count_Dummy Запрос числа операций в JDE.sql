/* =============================================
-- Author:				Sotivoli
-- Create date:			01 October 2024
-- Description:			Определение числа заказов бизнес-системы за день
-- =============================================
declare  @Date		as date		= '2024-10-02'
		,@Orders	as bigint	= 0
exec [dbo].[XE_Count_Dummy]  @Date		= @Date
						,@Orders	= @Orders output

select @Date as [Input Date], @Orders as [Output Orders]
=============================================== */
-- declare 
	drop procedure if exists	[dbo].[XE_Count_Dummy]
GO
	CREATE PROCEDURE			[dbo].[XE_Count_Dummy]
 @Date		as date 
,@Orders	as bigint = null output
	AS BEGIN	-- [dbo].[XE_CheckParams]

declare	 @Version	as nvarchar(30) = N'XE_Count_Dummy v 5.0.s'

set @Orders = 02041965	-- заглушка 

	END	-- [dbo].[XE_Count_Dummy]