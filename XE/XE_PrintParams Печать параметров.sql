/* =============================================
	Author:			Sotivoli
	Date:			31 October 2024
	Description:	Печать параметров
-- =============================================
exec	[dbo].[XE_PrintParams]
		 @Caller		= 'XE_Import_Profiler 5.0d'
		,@Action		= 'Profiler XE'
		,@Option		= 'list only create compression noclear compact skip replace nodb dummy'
		,@Session		= 'alidi'	
		,@Session#		= '123'
		,@Source		= 'C:\*.xel'
		,@Table			= '[dbo].[XEd_Set]'
		,@Records		= 300
		,@Percent		= 1.05 
		,@AddSum		= 80 
		,@OrdersProc	= 'XE_Import_XE44'
		,@Object		= 'xe_sql251'
		,@Steps			= 'XEl Set '	-- Перечень выполняемых шагов, по умолчанию - все шаги 
		,@Offset		= 3650
		,@Start			= '2044-01-01'	-- Начало периода
		,@Stop			= '2024-09-08'	-- Окончание периода
		,@Date			= '2024-12-31'	
		,@Uncertainty	= 180			-- неопределенность границ времени,секунд
		,@Comm			= 'комментарий к программе'	-- Комментарий в журнал
		,@Error			= 28
		,@Cmd			= 'Select * from XEd_Set'
		,@Count			= 18345
		,@Max_Time		= '2024-05-01'
=============================================== */

	drop procedure if exists	[dbo].[XE_PrintParams]
GO
	CREATE PROCEDURE			[dbo].[XE_PrintParams]
 @Caller		nvarchar(128)		= null -- кто вызывает
,@Session		as nvarchar(128)	= null 
,@Table			as nvarchar(128)	= null 
,@Source		as nvarchar(max)	= null 
,@OrdersProc	as nvarchar(128)	= null 
,@Records		as int				= null 
,@Percent		as numeric(13,6)	= null 
,@AddSum		as numeric(13,6)	= null 
,@Session#		as int				= null 
,@Object		as nvarchar(128)	= null
,@Start			as date				= null		-- Начало периода
,@Stop			as date				= null		-- Окончание периода
,@Action		nvarchar(20)		= null	-- Действие
,@Uncertainty	as int				= null	-- неопределенность границ времени,секунд
,@Date			as date				= null
,@Steps			nvarchar(max)		= null	-- Перечень выполняемых шагов, по умолчанию - все шаги 
,@Comm			nvarchar(256)		= null -- 'комментарий к программе'	-- Комментарий в журнал
,@Offset		int					= null
,@Error			int					= null
,@Option		as nvarchar(256)	= null
,@Cmd			as nvarchar(max)	= null
,@Parameter		as nvarchar(128)	= null
,@Count			bigint				= null
,@Max_Time		as datetime2(7)		= null


,@Prefix		as nvarchar(10)		= N'***   '	-- Префикс всех выводимых строк
,@S				as nvarchar(16)		= N'      '	-- сдвиг для заголовков
,@L				as int				= 50		-- ширина левой части
,@R				as int				= 80		-- ширина правой части
	AS BEGIN	-- [dbo].[XE_PrintParams]

-- ********** Step 0: Инициализация **********

Declare  @Version	as nvarchar(30)	= N'XE_PrintParams v 5.1'	
		,@F			as nvarchar(80)								-- Строка для выравнивания (заполнения) 

Set		 @F	= replicate(' ', @R + @L)	

-- ********** Step 1: Печать Заголовка **********

print replicate('*', len(@Prefix) + @L + @R)
print @Prefix + @S + left(coalesce(@Caller, '') +':    ПАРАМЕТРЫ вызова процедуры ', @L + @R)
print replicate('*', len(@Prefix) + @L + @R)

-- ********** Step 2: Базовые параметры **********

if @Session is not null or @Session# is not null or @Steps is not null begin -- mail
	if @Session is not null	print
		@Prefix + right(@F + N'Сессия XE    (@Session) = '	,@L) + @Session
	if @Session# is not null print
		@Prefix + right(@F + N'ID сессии XE (@Session#) = '	,@L) + cast(@Session# as nvarchar(10))
	if @Steps is not null print
		@Prefix + right(@F + N'Исполняемые шаги процедуры (@Steps) = '	,@L) + N'"' + upper(ltrim(rtrim(@Steps))) + N'"'
	print @Prefix
end -- main

-- ********** Step 3: Источники данных **********

if @Source is not null or @Table is not null or @Offset is not null begin -- source
	if @Source is not null	print
		@Prefix + right(@F + N'Источник данных (@Source) = '			,@L) + @Source
	if @Table is not null print
		@Prefix + right(@F + N'Таблица полных данных XE (@Table) = '	,@L) + @Table
	if @Offset is not null print
		@Prefix + right(@F + N'Срок хранения данных (@Offset) = '	,@L) + cast(@Offset as nvarchar(10))
	print @Prefix
end -- source 

-- ********** Step 4: Параметры отбора **********

if @Records is not null or @Percent is not null  or @AddSum is not null begin -- selection
	if @Records is not null	print
		@Prefix + right(@F + N'Число Top записей (@Records) = '			,@L) + cast(@Records as nvarchar(10)) + ' Записей'
	if @Percent is not null print
		@Prefix + right(@F + N'Процент от общего ресурса (@Percent) = '	,@L) + cast(@Percent as nvarchar(10)) + ' %'
	if @AddSum is not null print
		@Prefix + right(@F + N'Накопительный процент ресурса (@AddSum) = '	,@L) + cast(@AddSum as nvarchar(10)) + ' %%'
	print @Prefix 
end -- selection

-- ********** Step 5: Временные параметры отбора данных **********

if @Start is not null or @Stop is not null  or @Date is not null or @Uncertainty is not null or @Max_Time is not null begin -- date
	if @Start is not null	print
		@Prefix + right(@F + N'Начало периода отора данных (@Start) = '			,@L) + format(@Start, 'D', 'en-gb')
	if @Stop is not null print
		@Prefix + right(@F + N'Окончание периода отбора данных (@Stop) = '	,@L) + format(@Stop, 'D', 'en-gb') 
	if @Date is not null print
		@Prefix + right(@F + N'Дата отбора данных (@Date) = '	,@L) + format(@Date, 'D', 'en-gb')
	if @Max_Time is not null print
		@Prefix + right(@F + N'Дата и время (@Max_Time) = '	,@L) +  cast(@Max_Time as nvarchar(30))
	if @Uncertainty is not null print
		@Prefix + right(@F + N'Неопределенность даты (@Uncertainty) = '	,@L) + cast(@Uncertainty as nvarchar(10)) + ' секунд'
	print @Prefix
end -- date

-- ********** Step 6: Прочие параметры **********

if @OrdersProc is not null or @Object is not null begin -- other
	if @OrdersProc is not null	print
		@Prefix + right(@F + N'Процедура подсчета поля [Orders] (@OrdersProc)  = ',@L) + @OrdersProc
	if @Object is not null	print
		@Prefix + right(@F + N'Имя объекта (@Object)  = '		,@L) + @Object
	print @Prefix
end -- other

-- ********** Step 7: параметры процедуры ExecLog **********

if @Comm is not null or @Error is not null begin -- @ExecLog
	print replicate('*', len(@Prefix) + @L + @R)
	if @Error is not null print
		@Prefix + right(@F + N'Ошибка выполнения (@Error) = '	,@L) + cast(@Error as nvarchar(10))  
	if @Comm is not null print
		@Prefix + right(@F + N'Комментарий к вызову (@Comm) = '	,@L) + N'"' + @Comm + '"'
end -- ExecLog

-- ********** Step 8: параметры процедуры Count **********

if @Count is not null begin -- @Count
	if @Count is not null print
		@Prefix + right(@F + N'Всего строк отобрано (@Count) = '	,@L) + cast(@Count as nvarchar(20))  
end -- @Count


-- ********** Step 9: Печать действий из @Action  **********

if @Action is not null begin -- @Action
	print replicate('*', len(@Prefix) + @L + @R)
	print @Prefix + @S + right(N'Тип действия (@Action) :', @R)

	if upper(' ' + @Action + ' ') like N'% ' + upper('Profiler')	+ N' %'	print
		@Prefix + right(@F + N'Profiler'	,@L) + left(N': Конвертаци данных, собранных Profiler', @R)
	if upper(' ' + @Action + ' ') like N'% ' + upper('XE')			+ N' %'	print
		@Prefix + right(@F + N'XE'			,@L) + left(N': Конвертация данных, собранных предыдущей версией XE', @R) 
end -- @Action


-- ********** Step 10: Печать режимов из Options **********

if @Option is not null begin -- @Option
	print replicate('*', len(@Prefix) + @L + @R)
	print @Prefix + @S + left(N'Режимы обработки (@Option) :', @R)

	if upper(' ' + @Option + ' ') like N'% ' + upper('List')		+ N' %'	print
		@Prefix + right(@F + N'List'		,@L) + left(N': Расширенный вывод информации', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Only')		+ N' %'	print
		@Prefix + right(@F + N'Only'		,@L) + left(N': Только вывод информации без изменения данных', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Create')		+ N' %'	print
		@Prefix + right(@F + N'Create'		,@L) + left(N': Создать при инсталляции сессию сбора данных XE', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Compression')	+ N' %'	print
		@Prefix + right(@F + N'Compression'	,@L) + left(N': При инсталляции указать сжатие для таблиц XE', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Noclear')		+ N' %'	print
		@Prefix + right(@F + N'NoClear'		,@L) + left(N': Не удалять устаревшие данные', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Compact')		+ N' %'	print
		@Prefix + right(@F + N'Compact'		,@L) + left(N': Не записывать модифицированный текст запросов (поле Text)', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Skip')		+ N' %'	print
		@Prefix + right(@F + N'Skip'		,@L) + left(N': Не вызывать обработку XEd_Hash (процедура XE_TextData)', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Replace')		+ N' %'	print
		@Prefix + right(@F + N'Replace'		,@L) + left(N': Заместить имеющиеся данные (по дням)', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('NoDB')		+ N' %'	print
		@Prefix + right(@F + N'NoDB'		,@L) + left(N': При конвертаци не определять имя БД по ее id', @R)
end -- @Option

-- ********** Step 11: параметры выполнения команды **********

if @Cmd is not null or @Parameter is not null begin -- @ExecLog
	print replicate('*', len(@Prefix) + @L + @R)
	print @Prefix + @S + left(N'Параметры выполнения динамического SQL:', @R)

	if @Parameter is not null print
		@Prefix + right(@F + N'Параметр выполнения (@Parameter) = '	,@L) + N'"' + @Parameter + N'"'    
	if @Cmd is not null print
		@Prefix + right(@F + N'Текст выполняемой команды (@Cmd) = '	,@L)
	if @Cmd is not null print @Cmd
end -- ExecLog

-- ********** Step 12: Финальная отбивка **********

print replicate('*', len(@Prefix) + @L + @R)

	END	-- [dbo].[XE_PrintParams]