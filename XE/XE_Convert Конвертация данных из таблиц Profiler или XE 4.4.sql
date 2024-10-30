/* =============================================	
-- Author:		Sotivoli
-- Create date: 11 October 2024
-- Description:	Конвертация данных из Profiler Log или XE версии 4.4
-- =============================================
exec [dbo].[XE_Convert]
						 @Session	= null 
						,@Option	= N'\list \only \replace Nodb \compact'
						,@Source	= '[alidi backup].[dbo].[Prof_log_251_char_View]'
						,@Table		= 'Profiler_sql251' 
						,@Action	= 'Profiler'


exec [dbo].[XE_Convert]
						 @Option	= N'\list \only \replace Nodb compact'
--						 @Session	= 'sql251'
						,@Source	= '[alidi backup].[dbo].[Log_XE_SQL251]'
						,@Table		= 'convert_sql251'
						,@Action	= 'XE'
-- ,@Uncertainty		= 180		-- Погрешность границы времени, секунд

truncate table [dbo].[XE_SOTIVOLI]
-- ============================================= */
--	Declare
GO
	drop procedure if exists	[dbo].[XE_Convert]
GO
	CREATE	PROCEDURE			[dbo].[XE_Convert]
 @Session		nvarchar(128)	= null	-- Имя сессии XE
,@Action		nvarchar(20)	= null	-- Действие
,@Source		nvarchar(2048)	= null	-- источник
,@Option		nvarchar(256)	= null	-- Параметры
,@Table			nvarchar(128)	= null	-- целевая таблица
,@Uncertainty	as int			= 0	-- неопределенность границ времени,секунд
	AS BEGIN	-- [dbo].[XE_Convert]

-- ********** Step 0: Инициализация	********** --

Declare	 @Version	nvarchar(30)	= N'XE_Convert v. 5.0p'
		,@Cmd		nvarchar(max)
		,@ParamDef	nvarchar(max)	
		,@Start		datetime
		,@Stop		datetime

		,@List		bit				= 'False'
		,@Only		bit				= 'False'
		,@Profiler	bit				= 'False'
		,@XE		bit				= 'False'
		,@Replace	bit				= 'False'
		,@Skip		bit				= 'False'

-- 0.1	@Option: активация параметров:

if upper(' '+@Option +' ') like upper(N'% ' + N'List'		+ N' %') Set @List		= 'True'
if upper(' '+@Option +' ') like upper(N'% ' + N'Only'		+ N' %') Set @Only		= 'True'
if upper(' '+@Action +' ') like upper(N'% ' + N'Profiler'	+ N' %') Set @Profiler	= 'True'
if upper(' '+@Action +' ') like upper(N'% ' + N'XE'			+ N' %') Set @XE		= 'True'
if upper(' '+@Option +' ') like upper(N'% ' + N'Replace'	+ N' %') Set @Replace	= 'True'
if upper(' '+@Option +' ') like upper(N'% ' + N'Skip'		+ N' %') Set @Skip		= 'True'

-- 0.2 Проверка корректности и модификация входных данных

exec [dbo].[XE_CheckParams]	 @Session		= @Session		output
							,@Table			= @Table		output

-- 0.2  Проверка сущуствования исходной таблицы

if (@Source is null) or ((OBJECT_ID(@Source, N'U') is null) and (OBJECT_ID(@Source, N'V') is null))
	begin -- @Table not exists
		Set @Cmd =	 N' ' + @Version 
					+N' Error: Таблица с исходными данными, указанная в параметре @Source="' 
					+ coalesce(@Source, N'<null>')	
					+ N'" не существует, обработка невозможна"';			 
		RAISERROR(@Cmd, 16, 1)
		return
	end -- @Table not exists

-- 0.3  Должна быть указана только одна опция выбора данных для конвертации:
--		либо Profiler, лио XE
	
if (@Profiler= 'False' and @XE = 'False')
	begin	-- не указан тип данных
		Set @Cmd =	 N' ' + @Version 
					+N' Error: Не указан, или неверно указан тип данных в @Action ="'
					+ coalesce(@Action, N'<null>')	
					+ N'" (допустимые значения: Profiler или XE). Обработка невозможна"'
		RAISERROR(@Cmd, 16, 1)
		return
	end	-- не указан тип данных

-- 0.5  Создаем таблицу для записи конвертации, если ее еще нет

exec XE_Install	 @Steps = N'XEL'
				,@Table = @Table
				,@Option = @Option
				,@Session = @Session

-- 0.6   Печатаем отбивку и параметры

if @List = 'TRUE' 
		print	 N'************************************************************************
***   ' + @Version + ', входные параметры:       
************************************************************************'
	+nchar(13)	+N'***     @Session   = ' + coalesce(@Session, N'<null>')
	+nchar(13)	+N'***     @Source     = ' + coalesce(@Source,	N'<null>')
	+nchar(13)	+N'***     @Table    = ' + coalesce(@Table,  N'<null>')
	+nchar(13)	+N'***     @Option   = ' + coalesce(@Option,  N'<null>')
	+nchar(13)	+N'***     @List     = ' + case when @List	  = 'TRUE' then 'Yes' else '-' end
	+nchar(13)	+N'***     @Only     = ' + case when @Only	  = 'TRUE' then 'Yes' else '-' end
	+nchar(13)	+N'***  @Uncertainty = ' + coalesce(cast(@Uncertainty as nvarchar(10)),  N'<null>') + ' seconds'
	+nchar(13)	+N'***     @Profiler = ' + case when @Profiler= 'TRUE' then 'Yes' else '-' end
	+nchar(13)	+N'***     @XE       = ' + case when @XE	  = 'TRUE' then 'Yes' else '-' end
	+nchar(13)	+N'***     @Replace  = ' + case when @Replace = 'TRUE' then 'Yes' else '-' end
	+nchar(13) + N'************************************************************************'

--  0.5   Модифицируем @Option  для передачи в другие процедуры. Добавляем опцию 
--			Skip - чтобы не вызывать XE_TextData в каждой процедуре импорта за день

	set @Option = rtrim(ltrim(replace(replace(upper(' ' + @Option + ' '), N' XE ', ' '), N' PROFILER ', ' '))) + N' Skip '

-- ********** Step 1:Определяем интервал в таблицах источника и назначения ********** --

Declare	 @Source_Min_Date	date
		,@Source_Max_Date	date
		,@Table_Min_Date	date
		,@Table_Max_Date	date

		,@Source_Min_Time	datetime
		,@Source_Max_Time	datetime
		,@Table_Min_Time	datetime
		,@Table_Max_Time	datetime

		,@DateDef			nvarchar(128)

-- 1.0	Определяем диапазон дат в исходной таблице @Source
--		в зависимости от типа таблицы форматы дат (и поля) отличаются

Set @DateDef = case
					when @Profiler = 'True' 
						then N'dateadd(ms,[Duration]/1000,[StartTime])'
						else N'[DateTime_Stop]'
					end
SET @ParamDef	= N' @Source_Min_Date datetime output, @Source_Max_Date datetime output'

Set @Cmd =	N'select	 @Source_Min_Date = min(' + @DateDef + N')
						,@Source_Max_Date = max(' + @DateDef + N')
					from ' + @Source

EXEC sp_executesql   @Cmd, @ParamDef
					,@Source_Min_Date	= @Source_Min_Date output
					,@Source_Max_Date	= @Source_Max_Date output

-- 1.1  Если таблица с исходными данными пустая, то нам нечего делать 

if (@Source_Min_Date is null) or (@Source_Max_Date is null)
	begin	-- нет данных в исходной таблице
		Set @Cmd =	 N' ' + @Version 
					+ ' Error: Некорректные значения данных в исходной таблице типа'
					+case when @Profiler = 'True' then N'"Profiler"'
						else N'"XE"'
						end
					+N' : от '
					+ coalesce(cast(@Source_Min_Date as nvarchar(30)), N'<null>')	
					+ N' до '
					+ coalesce(cast(@Source_Max_Date as nvarchar(30)), N'<null>')	
		RAISERROR(@Cmd, 16, 1)
		return
	end	-- -- нет данных в исходной таблице

-- 1.2  Исходная таблица не пустая, печатаем диапазон

print nchar(13) + N'*** Диапазон в исходной таблице: '
				+coalesce(format(@Source_Min_Date, 'D', 'ru-ru'), N'<null>')
				+'   -   '
				+coalesce(format(@Source_Max_Date, 'D', 'ru-ru'), N'<null>')

-- 1.3  Делаем цикл по всем датам из исходной таблицы @Source

Declare @Day as date
Set @Day =  @Source_Min_Date

while @Day <= @Source_Max_Date
	begin -- обработка одного дня

-- Begin  ============= Обработка одной даты, начало  ================

-- 1.3.1  Определяем времена начала событий на дату @Day как для исходной 
--			таблицы (@Source), так и для целевой таблицы (@Table)

SET @ParamDef	= 
N' @Source_Min_Time time output, @Source_Max_Time time output, @Day date'

-- 	Сначала для таблицы @Source

Set @Cmd = 
	N'select  @Source_Min_Time = cast(min(' + @DateDef + N') as time) 
			 ,@Source_Max_Time = cast(max(' + @DateDef + N') as time)
		from ' + @Source + N'
		where cast(' + @DateDef + N' as date) = @Day'
EXEC sp_executesql   @Cmd, @ParamDef
					,@Source_Min_Time	= @Source_Min_Time output
					,@Source_Max_Time	= @Source_Max_Time output
					,@Day			= @Day

-- 1.3.2  ... теперь то же самое - для таблицы @Table, но только 
--			если в @Source есть данные за @Day

if @Source_Min_Time is not null and @Source_Max_Time is not null
begin	-- Data in @Source exists

-- Begin  @@@@@@@@@@@@@@@@@@@@@@@ В @Source есть данные за @Day @@@@@@@@@@@@@@@@

-- ********** Step 2: Анализ дат и вызов процедур импорта

-- 2.1  Для опции Replace удаляем данные в @Table по датам, существующим в @Source

	if @Replace = 'True'
		begin -- Удаляем данные в @Table
			set @Cmd = N'delete from ' + @Table 
					  +N' where [Date] = ''' + cast(@Day as nvarchar(30)) + ''' '
			EXEC sp_executesql   @Cmd
		end	--Удаляем данные в @Table

-- 2.2  Импортируем данные из @Source за время, отсутствующее в @Table

	SET @ParamDef	= 
	N' @Table_Min_Time time output, @Table_Max_Time time output, @Day date'

-- 2.2.1 Определяем диапазон имеющихся данных в таблице назначения @Table

	Set @Cmd = 
		N'select  @Table_Min_Time = min([DateTime_Stop])
				 ,@Table_Max_Time = max([DateTime_Stop])
			from ' + @Table + N'
			where [Date] = @Day' 

	EXEC sp_executesql   @Cmd, @ParamDef
						,@Table_Min_Time	= @Table_Min_Time output
						,@Table_Max_Time	= @Table_Max_Time output
						,@Day				= @Day

-- 2.2.2  Выводим информационное сообщение

	print	 N'***      Обработка за дату: '
			+format(@Day, 'D', 'ru-ru')
			+ cast(-datediff(day, @Day, @Source_Min_Date) + 1	as nvarchar(10))
			+N' из '
			+ cast(datediff(day, @Source_Min_Date, @Source_Max_Date) + 1 as nvarchar(10))
			+N'   ('
			+cast(cast(		
						  (-datediff(day, @Day, @Source_Min_Date) + 1) * 100
						/ ( datediff(day, @Source_Min_Date, @Source_Max_Date) + 1 )
						as int) as nvarchar(3))
			+N'% )'
			+N',  Диапазон в исходной [целевой] времени: '
			+coalesce(convert(nvarchar, @Source_Min_Time, 108), N'<null>')
			+'   -   '
			+coalesce(convert(nvarchar, @Source_Max_Time, 108), N'<null>')
			+N'  ['
			+coalesce(convert(nvarchar, @Table_Min_Time, 108), N'<null>')
			+'   -   '
			+coalesce(convert(nvarchar, @Table_Max_Time, 108), N'<null>')
			+N']'

-- 2.3 Обрабатываем разные варианты с датами исходной (@Source)
--		 и целевой (@Table) таблиц 

-- 2.3.1  В целевой таблице нет данных за день @Day:
--				импортируем все данные за день  из @Source

	if @Table_Min_Time is null or @Table_Max_Time is null
		begin	-- Full Day
			set @Start	= cast(@Day						as datetime)
			set @Stop	= cast(dateadd(day, 1, @Day)	as datetime)

			if @List = 'True' print	 N'Full day: '	+ cast(@Start as nvarchar(30))
									+N' <= time < '	+ cast(@Stop  as nvarchar(30))
			
			if @Only = 'False' and @Profiler = 'True'
				exec XE_Import_Profile	 @Option	= @Option 
			 							,@Start		= @Start
										,@Stop		= @Stop
										,@Source	= @Source
										,@Table		= @Table
										,@Session	= @Session
			if @Only = 'False' and @XE = 'True'
				exec XE_Import_XE44		 @Option	= @Option 
			 							,@Start		= @Start
										,@Stop		= @Stop
										,@Source	= @Source
										,@Table		= @Table
										,@Session	= @Session
		end	-- Full Day

-- 2.3.2  В целевой таблице нет данных за  начало дня @Day:
--				импортируем нехватающие данные из @Source

	if  @Table_Min_Time is not null 
	and @Source_Min_Time < dateadd(ss, -@Uncertainty, @Table_Min_Time)
		begin	-- Start of Day
			set @Start	= cast(@Day as datetime)
			set @Stop	= dateadd(day, datediff(day, 0, @Day), cast(@Table_Min_Time as datetime))
			if @List = 'True' print	 N'<<<< of day: '	+ cast(@Start as nvarchar(30))
									+N' <= time < '		+ cast(@Stop  as nvarchar(30))
			if @Only = 'False' and @Profiler = 'True'
				exec XE_Import_Profile	 @Option	= @Option 
			 							,@Start		= @Start
										,@Stop		= @Stop
										,@Source	= @Source
										,@Table		= @Table
										,@Session	= @Session
			if @Only = 'False' and @XE = 'True'
				exec XE_Import_XE44		 @Option	= @Option 
			 							,@Start		= @Start
										,@Stop		= @Stop
										,@Source	= @Source
										,@Table		= @Table
										,@Session	= @Session
		end	-- Start of Day

-- 2.3.3  В целевой таблице нет данных за конец дня @Day:
--				импортируем нехватающие данные из @Source

	if  @Table_Max_Time is not null 
	and @Source_Max_Time > dateadd(ss, @Uncertainty, @Table_Max_Time)
		begin	-- End of Day
			set @Start	= DATEADD(day, DATEDIFF(day, 0, @Day), CAST(@Table_Max_Time AS DATETIME))
			set @Stop	= cast(dateadd(day, 1, @Day) as datetime)
			if @List = 'True' print	 N'>>>>> of day: '	+ cast(@Start as nvarchar(30))
									+N' <= time < '		+ cast(@Stop  as nvarchar(30))
			if @Only = 'False' and @Profiler = 'True'
				exec XE_Import_Profile	 @Option	= @Option 
			 							,@Start		= @Start
										,@Stop		= @Stop
										,@Source	= @Source
										,@Table		= @Table
										,@Session	= @Session
			if @Only = 'False' and @XE = 'True'
				exec XE_Import_XE44		 @Option	= @Option 
			 							,@Start		= @Start
										,@Stop		= @Stop
										,@Source	= @Source
										,@Table		= @Table
										,@Session	= @Session
		end	-- Full Day

-- 2.3.3  Данные из целевой таблицы полностью перекрывают данные 
--			из исходной таблице по дню @Day: ничего не делаем

		if   @Source_Min_Time > dateadd(ss, -@Uncertainty, @Table_Min_Time)
		and  @Source_Max_Time < dateadd(ss,  @Uncertainty, @Table_Max_Time)
			print	 N'***      Данные за ' + cast(@Day as nvarchar(30)) 
					+N' уже присутствуют в ' + @Table + ', импорт не осуществляется'

-- End   @@@@@@@@@@@@@@@@@@@@@@@ В @Source есть данные за @Day @@@@@@@@@@@@@@@@

	end	-- Data in @Source exists

-- End  ============= Обработка одной даты, окончание  ================\

-- Переходим на следующую дату

set @Day = dateadd(day, 1, @Day)
	end	-- обработка одного дня

-- ********** Step 4 завершающие операции ********** --

-- 5.1  Вызываем XE_TextData для обработки поля TextData из целевой таблицы @Table


if @Skip = 'False' and @List = 'True' and @Only = 'False'
	print '***   Обработка информации из полей [TextData]'
if @Skip = 'False' 	
	execute [dbo].[XE_ExecLog]	 @Proc		= N'[dbo].[XE_TextData]', @Caller = @Version
								,@Session	= @Session
								,@Option	= @Option

-- 5.2  Вызываем XE_TopSum 


if @Skip = 'False' and @List = 'True' and @Only = 'False'
	print '***   Обработка XE_TopSum'
if @Skip = 'False' 	
	execute [dbo].[XE_ExecLog]	 @Proc		= N'[dbo].[XE_TopSum]', @Caller = @Version
								,@Session	= @Session
								,@Option	= @Option
								,@Table		= @Table

-- 5.2 Печатаем  good bye

if @List = 'TRUE' 
		print	 N'************************************************************************
***   ' + @Version + N' Завершена                 ***
************************************************************************'

	END -- [dbo].[XE_Convert]