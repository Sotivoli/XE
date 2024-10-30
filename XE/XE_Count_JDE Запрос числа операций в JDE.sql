/* =============================================
-- Author:				Sotivoli
-- Create date:			01 October 2024
-- Description:			Определение числа заказов JDE за день
-- =============================================
declare  @Date		as date		= '2024-02-15'
		,@Orders	as bigint	= 0
exec [dbo].[XE_Count_JDE]    @Date		= @Date
							,@Orders	= @Orders output
select @Date as [Input Date], @Orders as [Output Orders]
=============================================== */
-- declare 
	drop procedure if exists	[dbo].[XE_Count_JDE]
GO
	CREATE PROCEDURE			[dbo].[XE_Count_JDE]
 @Date		as date 
,@Orders	as bigint = null output
	AS BEGIN	-- [dbo].[XE_Count_JDE]

declare	 @Version	as nvarchar(30) = N'XE_Count_JDE v 5.0.p'
		,@JDE_Date	as nvarchar(10)

-- Блок ниже можно убрать в Alidi (заменить на текст в комментарии)

if upper(@@SERVERNAME) = N'SOTIVOLI'
	begin	-- sotivoli only
		Select	 @Orders = coalesce([Orders], 0)
					from [PROFLOG1].[dbo].[Prof_log_Orders]
					where [Date] = @Date
					  and [Date] < dateadd(day, 1, @Date)
		if @Orders is null set @Orders = 0 
		return

	end	-- sotivoli only

/* Убрать комментарий в Alidi 

SET @JDE_Date = ALIDI_UTL.[dbo].fncDateToJDEDate(@Date)

if upper(@@SERVERNAME) <> 'SOTIVOLI'		
	select	 @Orders = count(*) 
		from [JDEENT].[JDE_PRODUCTION].[PRODDTA].[F554243] 
			with (nolock) 
		inner join [JDEENT].[JDE_PRODUCTION].[PRODDTA].[F40039] 
			with (nolock) 
			on    AJDCTO = DTDCT 
			  and DTIBOR in ('20','21')
			where	AJOAC = '00' 
			  and AJCRDJ = @JDE_Date
*/

	END	-- [dbo].[XE_Count_JDE]