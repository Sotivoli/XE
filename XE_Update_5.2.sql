/* =============================================
-- Author:				Sotivoli
-- Create date:			25 December 2024
-- Description:	Обновление структуры данных с верисии 5.5 до версии 5.5.2 и заполнение новых полей
--				В таблицу XE_Sum добавляются новые данные по полям HashCount, OK, Abort, Error
-- =============================================
exec [dbo].[XE_Update_5_2] 
	 @Option='List \only'
--	,@Session	= 'sql251'
-- ============================================= */
--	 
--Declare
GO
drop procedure if exists	[dbo].[XE_Update_5_2]
GO
	CREATE	PROCEDURE		[dbo].[XE_Update_5_2]

 @Session		as nvarchar(128)	= null	-- Имя сессии XE
,@Option		as nvarchar(256)	= null	-- Параметры 
,@Table			as nvarchar(128)	= null	-- Имя таблицы с данными XE
	AS BEGIN

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

-- ********** Step 0: Инициализация ********** --
-- 0.1 Определение переменных

Declare  @Version				as nvarchar(30)	= N'XE_Update 5.2'
		,@Session#				as int				= null		-- номер сессии
		,@Cmd					as nvarchar(max)	= null		-- текст динамического SQL
		,@List					as bit				= 'False'	-- Выводить информацию о выполнении
		,@Only					as bit				= 'False'	-- Только информация, но не выполнение

-- 0.2 Проверка корректности и модификация входных данных

exec [dbo].[XE_CheckParams]	 @Action		= 'Session Table Session#'
							,@Session		= @Session		output
							,@Table			= @Table		output
							,@Session#		= @Session#		output

-- 0.3	@Option: Установка параметров выполнения:

if upper(' '+@Option+' ') like upper(N'% ' + N'List'	+N' %')	Set @List		= 'True'
if upper(' '+@Option+' ') like upper(N'% ' + N'Only'	+N' %')	Set @Only		= 'True'

-- ********** Step 1: Информационный блок ********** --

if @List = 'TRUE' exec [dbo].[XE_PrintParams]	 @Caller		= @Version
												,@Session		= @Session
												,@Session#		= @Session#
												,@Table			= @Table
												,@Option		= @Option

-- ********* Step 2: добавление столбцов в таблицу XE_Sum если они отсутствуют **********

if @Only = 'False' and COLUMNPROPERTY(object_id('[dbo].[XE_Sum]'), 'HashCount', 'ColumnId') is null
	begin -- [HashCount]
		Set @Cmd = 'alter table [dbo].[XE_Sum] add [HashCount] bigint NULL'	
		if @List = 'True' print '*** Add [HashCount] columb to XE.Sum (CMD = ' + @Cmd + ')'
		execute sp_executesql @Cmd
	end -- [HashCount]

if @Only = 'False' and COLUMNPROPERTY(object_id('[dbo].[XE_Sum]'), 'OK', 'ColumnId') is null
	begin -- [OK]
		Set @Cmd = 'alter table [dbo].[XE_Sum] add [OK] bigint NULL'	
		if @List = 'True' print '*** Add [OK] columb to XE.Sum (CMD = ' + @Cmd +')'
		execute sp_executesql @Cmd
	end -- [OK]

if @Only = 'False' and COLUMNPROPERTY(object_id('[dbo].[XE_Sum]'), 'Error', 'ColumnId') is null
	begin -- [Error]
		Set @Cmd = 'alter table [dbo].[XE_Sum] add [Error] bigint NULL'	
		if @List = 'True' print '*** Add [Error] columb to XE.Sum (CMD = ' + @Cmd + ')'
		execute sp_executesql @Cmd
	end -- [Error]

if @Only = 'False' and COLUMNPROPERTY(object_id('[dbo].[XE_Sum]'), 'Abort', 'ColumnId') is null
	begin -- [Abort]
		Set @Cmd = 'alter table [dbo].[XE_Sum] add [Abort] bigint NULL'	
		if @List = 'True' print '*** Add [Abort] columb to XE.Sum (CMD = ' + @Cmd  +')'
		execute sp_executesql @Cmd
	end -- [Abort]

-- ********** Step 3: Вывод вычисляемых данных, если стоит опция List **********

if @List = 'True'
begin -- List option
	SET @Cmd = '
select	 [Date]					as [Date]
		,sum([OK])				as [OK]
		,sum([Abort])			as [Abort]
		,sum([Error])			as [Error]
		,count(DISTINCT Hash#)	as [HashCount]
		,' + cast(@Session# as nvarchar(20)) + '		as [Session#]
from	(
		select	 [XE].[Date]
				,[Hash#]
				,case [R].[Result_Text] when ''OK''		then 1 else 0 end as [OK]
				,case [R].[Result_Text] when ''Abort''	then 1 else 0 end as [Abort]
				,case [R].[Result_Text] when ''Error''	then 1 else 0 end as [Error]
			from ' + @Table + ' as [XE]
			left join [dbo].[XEd_Result] as [R] on [R].Result# = [XE].[Result#]
		) as [q]
	group by [Date]
' -- end of @Cmd
	execute sp_executesql @Cmd

end -- List option
-- ********** Step 4: Обновление столбцов HashCount, OK, Abort, Error

;
if @only = 'False' 
begin -- recalculate XE_SUM
	SET @Cmd = '
MERGE [dbo].[XE_Sum] AS target 
		USING	(
					select	 [Date]					as [Date]
							,sum([OK])				as [OK]
							,sum([Abort])			as [Abort]
							,sum([Error])			as [Error]
							,count(DISTINCT Hash#)	as [HashCount]
							,' + cast(@Session# as nvarchar(20)) + '		as [Session#]
					from	(
							select	 [XE].[Date]
									,[Hash#]
									,case [R].[Result_Text] when ''OK''		then 1 else 0 end as [OK]
									,case [R].[Result_Text] when ''Abort''	then 1 else 0 end as [Abort]
									,case [R].[Result_Text] when ''Error''	then 1 else 0 end as [Error]
								from ' + @Table + ' as [XE]
								left join [dbo].[XEd_Result] as [R] on [R].Result# = [XE].[Result#]
							) as [q]
						group by [Date]		
				) AS source (
							  [Date]
							 ,[OK]
							 ,[Abort]
							 ,[Error]
							 ,[HashCount]
							 ,[Session#]
							)  
		ON	(target.[Date]	= source.[Date]) 
		and	(target.[Session#]	= source.[Session#])

		WHEN MATCHED 
			THEN UPDATE SET 
				target.[OK]			= source.[OK],
				target.[Abort]		= source.[Abort], 
				target.[Error]		= source.[Error],
				target.[HashCount]	= source.[HashCount];
'	-- end of @Cmd
				
	if @List = 'True' print '*** Add values for new cols in XE.SUM (CMD = ' + @Cmd  +')'
	execute sp_executesql @Cmd
end -- recalculate XE_SUM

-- ********** Скажем Good bye **********

if @List = 'TRUE' print N'
***
*************************************************************************************************************************************
***      ' + left(@Version + replicate(' ', 25), 25) 
+N'   Завершена                         ***
*************************************************************************************************************************************

'	-- конец текстовой строки

END -- [dbo].[XE_Update_5_5_2] 

