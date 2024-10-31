/* =============================================
-- Author:				Sotivoli
-- Create date:			13 October 2024
-- Description:	Цикл вызова процедуры XE_Day в диапазоне дат
-- =============================================

exec [dbo].[XE_TopSum] @Option='Compact \list \only'
	,@Start		= null -- '2024-07-10'
	,@Stop		= '2024-07-10'
--	,@Session	= 'sql251'
--	,@Table		= null
	,@Records	= 100
	,@Percent	= 0.05
	,@Addsum	= 70.0

--	truncate table XE_Top
-- ============================================= */
--	Declare
GO
drop procedure if exists	[dbo].[XE_TopSum]
GO
	CREATE	PROCEDURE		[dbo].[XE_TopSum]
	 @Session		as nvarchar(128)	= null	-- Имя сессии XE
	,@Start			as date				= null
	,@Stop			as date				= null
	,@Table			as nvarchar(128)	= null	-- Имя таблицы полных данных
	,@Option		as nvarchar(256)	= null	-- Параметры 
	,@Records		as bigint			= null	
	,@Percent		as numeric(13,6)	= null
	,@AddSum		numeric(13,6)		= null
	AS BEGIN

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

-- ********** Step 0: Инициализация ********** --
-- 0.1 Определение переменных

Declare  @Version				as nvarchar(30)	= N'XE_Day v 5.1'

		,@Session#				as int
		,@Cmd					as nvarchar(max)
		,@ParamDef				as nvarchar(max)
		,@Date					as date

		,@List					as bit				= 'FALSE'	-- Выводить информацию о выполнении
		,@Only					as bit				= 'FALSE'	-- Только информация, не выполнение

-- 0.2 Проверка корректности и модификация входных данных

exec [dbo].[XE_CheckParams]	 @Action = 'Session Table Records' 
							,@Session		= @Session		output
							,@Session#		= @Session#		output
							,@Table			= @Table		output
							,@Records		= @Records		output
							,@Percent		= @Percent		output 
							,@AddSum		= @AddSum		output

-- 0.3	@Option: Установка параметров выполнения:

if upper(' '+ @Option +' ') like upper(N'% '+'List'	+' %')	Set @List		= 'True'
if upper(' '+ @Option +' ') like upper(N'% '+'Only'	+' %')	Set @Only		= 'True'

-- 0.4 Упорядочивание дат @Start и @Stop 

if @Start > @Stop
		begin
			set @Date	= @Start
			set @Start	= @Stop
			set @Stop	= @Date
		end

-- 0.5  Формируем таблицу дат для обработки

drop table if exists ##XE, #Dates, #Table

-- 0.6 Получаем перечень имеющихся дней в данных @Table

set @Cmd = 'select 1 as [Row], [Date] into ##XE from ' + @Table + ' group by [Date]'
EXEC sp_executesql   @Cmd

-- 0.6.1 джойним с датами из XE_Top за вычетом текущего дня т.к. за него данные еще неполные

select	 [l].[Date] as [XE_Date]
		,[r].[Date] as [Top_Date]
	into #Dates 
	from ##XE as [l]
	left join (select [Date] from XE_Top group by [Date]) as [r] 
		on [l].[Date] = [r].[Date]
	where [l].[Date] <> CAST(getdate() as date)

-- 0.6.2  Если @Start и @Stop не заданы, выбираем отсутствующие в XE_Top, 
--		но присутствующие в XE_Table даты

if @Start is null and @Stop is null
	delete from #Dates where [Top_Date] is not null

-- 0.6.3 Если задано, то отсекаем даты по нижней границе (@Start)

if @Start is not null 
	delete from #Dates where [XE_Date] < @Start

-- 0.6.4 Если задано, то отсекаем даты по верхней границе (@Stop)

if @Stop is not null
	delete from #Dates where [XE_Date] > @Stop

-- 0.6.5 Создаем индекс как порядковый номер строки [Row]

drop table ##XE
	select  row_number() over(order by [XE_Date])	as [Row]
			,[XE_Date]								as [Date]
		into #Table
		from #Dates

-- ********** Step 1: Информационный блок ********** --

if @List = 'TRUE' exec	[dbo].[XE_PrintParams]	 @Caller		= @Version
												,@Session		= @Session
												,@Table			= @Table
												,@Option		= @Option
												,@Start			= @Start
												,@Stop			= @Stop
												,@Records		= @Records
												,@Percent		= @Percent
												,@AddSum		= @AddSum

-- ********** Step 2: Цикл по дате и вызов XE_Day ********** --

declare @Row as int = 1

while @Row <= (select COUNT(1) from #Table) 
	begin -- цикл по датам

		select @Date = [Date] 
			from #Table
			where [Row] = @Row

		if @List = 'TRUE' 
				print	 N'*** ' + @Version + ' Date   = '	
						+ coalesce(cast(@Date as nvarchar(30)), '<null>')

			if @Only = 'False' 
				begin -- XE_Day
					print	 N'*** ' + @Version +' Обработка данных из ' + @Table 
							+N',  дата: ' + cast(@Date as nvarchar(30))

					execute [dbo].[XE_ExecLog]	 @Proc		= '[dbo].[XE_Day]', @Caller	= @Version
												,@Option	= @Option
												,@Session	= @Session
												,@Date		= @Date
												,@Table		= @Table
												,@Records	= @Records	
												,@Percent	= @Percent
												,@AddSum	= @AddSum
				end -- XE_Day

			set @Row = @Row + 1

	end -- цикл по датам

-- ********** Step 3: Скажем Goodbye ********** --

if @List = 'TRUE' 
	print	 replicate('*', 70)
+nchar(13)	+N'*** ' + @Version + ' Завершена ********** '
+nchar(13)	+replicate('*', 70)

	END	-- PROCEDURE [dbo].[XE_TopSum]