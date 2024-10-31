/* =============================================
-- Author:		Sotivoli
-- Create date: 27 September 2024
-- Description:	Удаление архивных данных из таблицы
-- =============================================
exec [dbo].[XE_Clear] 
		 @Option	= 'list only'
		,@Table		= null	'[dbo].[XE_sql251]'
		,@Session	= null	-- 'sotivoli'

select * from [dbo].[XEd_Set] order by [Object] desc, [Session] desc
-- ============================================= */
--	Declare
	drop procedure if exists	[dbo].[XE_Clear]
GO
	CREATE PROCEDURE [dbo].[XE_Clear]
			 @Option	as nvarchar(256)	= null		-- 'Skip' -- Не удалть архивные данные
			,@Table		as nvarchar(128)	= null
			,@Session	as nvarchar(128)	= null
	AS BEGIN
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

-- ********** Step 0: Проверка корректности параметров ********** --
-- 0.1 Инициализация

Declare	 @Version	as nvarchar(25) = N'XE_Clear v 5.1'
		,@Offset	as int
		,@Cmd		as nvarchar(max)

		,@List		as bit = 'False'	-- Вывод информации без выполнения команды
		,@Only		as bit = 'False'	-- Вывод итоговой информации с выполенением команды

If upper(' ' + @Option + ' ')	like upper(N'% ' + N'List' + ' %')	Set @List	= 'True'
If upper(' ' + @Option + ' ')	like upper(N'% ' + N'Only' + N' %')	Set @Only	= 'True'

-- ********** Step 1 Уточнение параметров

exec [dbo].[XE_CheckParams]  @Action    = 'Session Table Offset'
							,@Session	= @Session	output
							,@Table		= @Table	output
							,@Offset	= @Offset   output

-- ********** Step 3: Обработка параметра List 

 if @List = 'True' 
	exec  XE_PrintParam	 @Caller	= @Version
						,@Option	= @Option
						,@Table		= @Table
						,@Session	= @Session
						,@Offset	= @Offset

-- ********** Step 4: Собственно очистка таблицы от архиавных данных

if object_id(@Table, N'U') is null	-- урезаемая таблица отсутствует
or @Offset <= 0						-- или время сохранения данных недействительно
or @Offset is null					-- или время сохранения не указано
or @Only = 'True'					-- или задано опция не выполнять операции
	return

Set @Cmd =	 N'Delete from ' + @Table 
			+N' where [Date] < ' 
			+'''' + format(dateadd(day, -@Offset, getdate()) ,'d' ,'en-US') + ''''
Execute sp_executesql @Cmd 

	END --  [dbo].[XE_Clear]