/* =============================================
-- Author:				Sotivoli
-- Create date:			11 October 2024
-- Description:			Формирование выборки запросов из файлов Extended Events в [dbo].[XE_]
-- =============================================
	exec [dbo].[XE_Xel]	 @Option	= ' /noclear /list /only /Skip compact /replace'	
						,@Start		= null --'2024-07-14'
						,@Stop		= null --'2024-07-13'
						,@Session	= 'sotivoli' 
						,@Table		= 'XE_Alidi'
						,@Source	=  N'C:\Документы\Проекты\Alidi\XE data\sql1250\XE_Log_*.xel' 
--	select * from ##tmp1
--	select * from #tmp0
drop table ##tmp1
-- ============================================= */
--
--	Declare
	drop procedure if exists	[dbo].[XE_Xel]
GO
	CREATE	PROCEDURE			[dbo].[XE_Xel]
 @Session	as nvarchar(128)	= null		-- Имя сессии XE
,@Table		as nvarchar(128)	= null		-- Имя таблицы для полных данных_
,@Source	as nvarchar(max)	= null		-- Путь к файлам .xel
,@Option	as nvarchar(256)	= null		-- Опции выполнения:
,@Start		as date				= null		-- Начало периода
,@Stop		as date				= null		-- Окончание периода
	AS BEGIN

-- ********** Step 0: Инициализация ********** --
-- 0.1 Инициализация

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

Drop table if exists #tmp0, ##tmp1, #tmp3, #Dir, #Files;
Declare	 @Version			as nvarchar(30)		= 'XE_Xel v 5.0x'
		,@Max_Time			as datetime2(7) 
		,@Min_Time			as datetime2(7)
		,@Cmd				as nvarchar(max)
		,@Session#			as int
		,@Offset			as bigint			= null
		,@Count				as bigint

		,@List				as bit				= 'False'
		,@Only				as bit				= 'False'
		,@NoClear			as bit				= 'False'
		,@Compact			as bit				= 'False'
		,@Skip				as bit				= 'False'
		,@Replace			as bit				= 'False'

--			'List'		= Отображение информации
--			'Only'		= Только вывести информацию, не выполнять
--			'NoClear'	= Не выполнять  обрезку архивных данных в таблицах
--			'Compact'	= Не записывать преобразованный TextData в поле Text таблицы XEd_Hash
--			'Skip'		= не вызывать процедуру XE_TextData

		,@Directory			as nvarchar(max)
		,@Command			as nvarchar(1050)
		,@ParamDef			as nvarchar(max)
		,@TimeShift			as int				= datediff(hh, getutcdate(), getdate())

Create table #Dir	([ItemName]		[nvarchar](256)	COLLATE DATABASE_DEFAULT)

Create table #Files	([RowNumber]	[bigint]		NOT NULL IDENTITY(1,1) PRIMARY KEY	
					,[Date]			[date]
					,[Time]			[time]
					,[Directory]	[nvarchar](2048) COLLATE DATABASE_DEFAULT
					,[File_Name]	[nvarchar](256) COLLATE DATABASE_DEFAULT
					,[Records]		[bigint]
					,[Events]		[bigint]		DEFAULT 0
					)

-- 0.2 Проверка корректности и модификация входных данных

exec [dbo].[XE_CheckParams]	 @Session = @Session  output
							,@Table   = @Table    output
							,@Source  = @Source   output

if @Source is null or @Source = ''
	begin	-- @Source is null
		Set @Cmd =
			 N'*** ' + @Version + ' Error: Не определен путь для файлов с данными '
			+N'сессии extended events для сессии @Session="' 
			+ coalesce(@Session, '<null>')
			+N'", обработка невозможна."'
		RAISERROR(@Cmd, 16, 1)
		return 
	end	-- @Source is null

-- 0.3	@Option: проверка на наличие параметров:

if upper(' '+@Option+' ') like upper(N'% ' + 'List'		+' %')	Set @List		= 'True'
if upper(' '+@Option+' ') like upper(N'% ' + 'Only'		+' %')	Set @Only		= 'True'
if upper(' '+@Option+' ') like upper(N'% ' + 'Noclear'	+' %')	Set @NoClear	= 'True'
if upper(' '+@Option+' ') like upper(N'% ' + 'Compact'	+' %')	Set @Compact	= 'True'
if upper(' '+@Option+' ') like upper(N'% ' + 'Skip'		+' %')	Set @Skip		= 'True'
if upper(' '+@Option+' ') like upper(N'% ' + 'Replace'	+' %')	Set @Replace	= 'True'

-- 0.4  Определяем максимальное время записи в таблице полных данных 

if OBJECT_ID (@Table, N'U') IS NOT NULL 
begin	-- макс. дата
	SET @ParamDef	= N'@Res datetime OUTPUT, @Session nvarchar(128)';
	SET @Cmd		= N'SELECT @Res = coalesce(max([DateTime_Stop]), ''1965-04-02'') '
					 +N' from ' 
					 + '[' + coalesce(parsename(@Table,2), 'dbo')
					 + '].[' + parsename(@Table, 1) + ']'
					 +N' as [l]' 
					 +N'left join [dbo].[XEd_Session] as [r] on upper([l].[Session#]) = upper([r].[Session#]) '
	execute sp_executesql @Cmd, @ParamDef, @Res = @Max_Time OUTPUT, @Session = @Session;
end		-- макс. дата 

-- 0.5 Упорядочивание дат @Start и @Stop

declare @Start0 as date

if @Start > @Stop
	begin
		set @Start0	= @Stop
		set @Stop	= @Start
		set @Start	= @Start0
	end

-- 0.6 Info print

if @List = 'True' 
		print	 N'***   ' + @Version +' parameters: '
	+nchar(13)	+N'***     @Session  =' + coalesce(@Session, N'<null>')
	+nchar(13)	+N'***     @Source   =' + coalesce(@Source,	  N'<null>')
	+nchar(13)	+N'***     @Table    =' + coalesce(@Table,    N'<null>')
	+nchar(13)	+N'***     @Start    =' + coalesce(cast(@Start	  as nvarchar(20)), N'<null>')
	+nchar(13)	+N'***     @Stop     =' + coalesce(cast(@Stop	  as nvarchar(20)), N'<null>')
	+nchar(13)	+N'***     @Max_Time =' + coalesce(cast(@Max_Time as nvarchar(20)), N'<null>')
	+nchar(13)	+N'***     @List     =' + case when @List	= 'True' then 'TRUE' else 'FALSE' end
	+nchar(13)	+N'***     @Only     =' + case when @Only	= 'True' then 'TRUE' else 'FALSE' end
	+nchar(13)	+N'***     @NoClear  =' + case when @NoClear= 'True' then 'TRUE' else 'FALSE' end
	+nchar(13)	+N'***     @Compact  =' + case when @Compact= 'True' then 'TRUE' else 'FALSE' end
	+nchar(13)	+N'***     @Skip     =' + case when @Skip	= 'True' then 'TRUE' else 'FALSE' end
	+nchar(13)	+N'***     @Replace  =' + case when @Replace= 'True' then 'TRUE' else 'FALSE' end

-- ********** Step 1: Чтение данных из файлов Extended Events ********** --

-- 1.1	Получаются данные команды dir @Source в таблицу #Dir

set @Command = N'dir "' + @Source + N'" /4 /-C'
insert #Dir execute sys.xp_cmdshell @Command

-- 1.2  Парсим результат команды Dir, помещаем в #Files только строки, описывающие файлы .xel

set @Directory = case 
					when @Source like N'%\%' 
						then left(@Source, len(@Source)-charindex('\', reverse(@Source)))
					when @Source like N'%:%' 
						then left(@Source, charindex(':', @Source))
						else ''
					end

insert into #Files ( [Date]
					,[Time]
					,[Directory]
					,[File_Name]
					,[Records]
					,[Events]
					)
	select	case 
				when substring(ItemName, 3,1) = N'/' 
					then DATEFROMPARTS	(substring(ItemName,7,4)
										,substring(ItemName,1,2)
										,substring(ItemName,4,2))
					else DATEFROMPARTS	(substring(ItemName,7,4)
										,substring(ItemName,4,2)
										,substring(ItemName,1,2))
				end													as [Date]
			,cast(substring(ItemName,13,8) as time)					as [Time]
			,@Directory												as [Directory]
			,substring	(ltrim(substring(ItemName, 21, 8000))
						,patindex(N'% %', ltrim(substring(ItemName, 21, 8000))) + 1
						,8000
						)											as [File_Name]
			,cast(replace(substring(ltrim(substring(ItemName, 21, 8000))
									,1
									, patindex(N'% %', ltrim(substring(ItemName, 21, 8000))) - 1
									)
									,N','
									, N''
							) as bigint
				)													as [Records]
			,0														as [Events]
	from #Dir as [d]
	where upper(right(ltrim(rtrim(ItemName)), 4)) = N'.XEL'

-- 1.3	Считываются данные из всех файлов (фильтрация по дате увеличивает время)
	Declare  @Step			as int = 1
			,@fDate			as date
			,@fTime			as time
			,@fName			as nvarchar(256)
			,@fRecords		as bigint
			,@fDirectory	as nvarchar(2048)

			,@sDate			as date
			,@sTime			as time
			,@sName			as nvarchar(256)
			,@sRecords		as bigint
			,@sEvents		as bigint
			,@sDirectory	as nvarchar(2048)

			,@Events_Before as bigint = 0
			,@Events_After	as bigint = 0

-- 1.4  Создаем таблицу #tmp0 для накопления данных из файлов extended events

drop table if exists #tmp0
create table #tmp0	([Object_name]	nvarchar(max)
					,[XML]			xml
					)

while @Step <= (select max([RowNumber]) from #Files)
begin	-- цикл по строкам @Step таблицы #Files 

	select	 @fDate			= [f].[Date]
			,@fTime			= [f].[Time]
			,@fName			= [f].[File_Name]
			,@fRecords		= [f].[Records]
			,@fDirectory	= [f].[Directory]

			,@sDate			= [s].[Date]
			,@sTime			= [s].[Time]
			,@sName			= [s].[File_Name]
			,@sRecords		= [s].[Records]
			,@sEvents		= [s].[Events]
			,@sDirectory	= [s].[Directory]

		from #Files	as [f]
		left join (select * 
						from [dbo].[XEd_Source] 
						where upper([Session])	= upper(@Session)
						  and upper([Source])		= upper(@Source)
					)	as [s] on [f].[File_Name] = [s].[File_Name]
		COLLATE DATABASE_DEFAULT
		where [f].[RowNumber] = @Step

		if	@sDate is null
		or	(@fDate		<> @sDate) 
		or	(@fTime		<> @sTime) 
		or	(@fRecords	<> @sRecords)
		or  (@Directory <> @sDirectory)
		or	(@fName		<> @sName)
		or  (@Replace	=  'True')	-- при опции Replace читаем все файлы
		begin -- Считываем файл @fName 
			print	N'*** ' + @Version + ' Information: Обрабатывается файл: ' 
					+ @Directory 
					+N'\' 
					+ @fName 

			select @Events_Before = count(1) from #tmp0				
			
			Insert into #tmp0
				select	 [object_name]				as [Object_name]
						,cast([event_data] as xml)	as [XML]
					from sys.fn_xe_file_target_read_file(@Directory + N'\' + @fName, null,null,null);
			
			select	@Events_After = count(1) from #tmp0
			Set		@sEvents = @Events_After - @Events_Before

		update #Files 
			set		[Events] = @sEvents
			where	[RowNumber] = @Step

	end	-- Считываем файл @fName

	else
		begin -- файл уже обработан ранее
			print N'*** ' + @Version +' Information: Пропускается файл ' + @fName + N' (прочитан при предыдущихх запусках XE_Xel'

			delete #Files
				where [RowNumber] = @Step
		end	-- файл уже обработан ранее

	Set @Step			= @Step + 1
	Set @Events_After	= 0
	Set @Events_Before	= 0

end		-- цикл по строкам @Step таблицы #Files 

-- ********** Step 2: Парсинг данных и их фильтруются данные по дате ********** --

--      Row - временная нумерация строк внутри процедуры
-- *) Выделяются поля из считанных строк файла xml
-- *) Вычисляем хеш по тексту запроса
-- *) Удаляются служебные символы из поля Text
-- *) Грубая очистка текста от множественных пробелов (чтобы уменьшить
--	  число строк, в которых будут удаляться произвольное число пробелов подряд)
--	P.S.	[TextData]	- Данное поле не изменяется
--			[Text]		- Поле будет изменяться для вычлененич имен таблиц и процедур

if OBJECT_ID('tempdb..#tmp0') IS NULL return

drop table if exists ##tmp1

select	 row_number() over(order by XML.value('(event/@timestamp)[1]', 'datetime') 
			at time zone 'Russian Standard Time')							as [Row]
		,ltrim(rtrim(@Session))												as [Session]

		,dateadd(hh, @TimeShift 
				,XML.value('(event/@timestamp)[1]', 'datetime') 
				 at time zone 'Russian Standard Time')						as [DateTime_Start]		
		,dateadd(hh, @TimeShift
				,dateadd(second
						,XML.value('(event/data[@name="duration"]/value)[1]', 'bigint') / 1000000 
						,XML.value('(event/@timestamp)[1]', 'datetime')
						)
				)															as [DateTime_Stop]
		,[Object_name]														as [Object_name]
		,coalesce(XML.value('(event/@name)[1]', 'nvarchar(128)'), '')		as [Event]
		,coalesce(XML.value('(event/@package)[1]', 'nvarchar(128)'), '')	as [Package]
		,XML.value('(event/data[@name="cpu_time"]/value)[1]','bigint')		as [CPU]
		,XML.value('(event/data[@name="duration"]/value)[1]', 'bigint')		as [Duration]
		,XML.value('(event/data[@name="page_server_reads"]/value)[1]', 'bigint') as [Page_server_reads]
		,XML.value('(event/data[@name="physical_reads"]/value)[1]', 'bigint')as [Reads_physical]
		,XML.value('(event/data[@name="logical_reads"]/value)[1]','bigint')	as [Reads_logical]
		,XML.value('(event/data[@name="writes"]/value)[1]', 'bigint')		as [Writes]
		,XML.value('(event/data[@name="spills"]/value)[1]', 'bigint')		as [Spills]   
		,XML.value('(event/data[@name="result"]/value)[1]', 'bigint')		as [Result_Code]
		,XML.value('(event/data[@name="result"]/text)[1]', 'varchar(20)')	as [Result_Text]
		,XML.value('(event/data[@name="row_count"]/value)[1]', 'bigint')	as [Row_count]
		,XML.value('(event/data[@name="output_parameters"]/value)[1]', 'varchar(max)')	as [Output_parameters]
		,XML.value('(event/action[@name="database_id"]/value)[1]', 'varchar(128)')		as [DatabaseID]
		,XML.value('(event/action[@name="server_principal_name"]/value)[1]' , 'varchar(128)')	as [LoginName]
		,XML.value('(event/action[@name="client_hostname"]/value)[1]', 'varchar(128)')	as [HostName]
		,XML.value('(event/action[@name="session_id"]/value)[1]', 'bigint')	as [Session_id]
		,XML.value('(event/action[@name="nt_username"]/value)[1]', 'varchar(128)')		as [Nt_username]
		,XML.value('(event/action[@name="is_system"]/value)[1]', 'bit')			as [Is_system]
		,XML.value('(event/action[@name="database_name"]/value)[1]', 'varchar(8)')		as [Database_name]
		,XML.value('(event/action[@name="client_pid"]/value)[1]', 'bigint')	as [Client_pid]
		,XML.value('(event/action[@name="client_app_name"]/value)[1]', 'varchar(128)')	as [Client_app_name]
		,XML.value('(event/action[@name="event_sequence"]/value)[1]', 'bigint') as [Event_sequence]
		,/*[Text]*/
case when [Object_name] = 'rpc_completed'
		then XML.value('(event/data[@name="statement"]/value)[1]','nvarchar(max)')
	when [Object_name] = 'sql_batch_completed'
		then +XML.value('(event/data[@name="batch_text"]/value)[1]','nvarchar(max)')
	end																			as [TextData]
		,HASHBYTES('SHA2_256', 
case when [Object_name] = 'rpc_completed'
		then XML.value('(event/data[@name="statement"]/value)[1]','nvarchar(max)')
	when [Object_name] = 'sql_batch_completed'
		then +XML.value('(event/data[@name="batch_text"]/value)[1]','nvarchar(max)')
	end				)															as [Hash]	
	into ##tmp1
	from #tmp0

--  2.1   Фильтруем (удаляем) лишние строки: 

--  2.1.1  оставляем только строки, соответствующие диапазону @Start - @Stop если он задан

if @Start is not null
	Delete from ##tmp1
		where cast([DateTime_Stop] as date) < @Start
if @Stop is not null
	Delete from ##tmp1
		where cast([DateTime_Stop] as date) > @Stop

if @Replace ='False'
	Delete from ##tmp1
		where [DateTime_Stop] <= @Max_Time

-- ********** Step 3: Действия по @Option = 'List' ********** --

select	 @Min_Time = MIN([DateTime_Stop])
		,@Max_Time = MAX([DateTime_Stop])
	from ##tmp1

if @List = 'TRUE'
	print   	+N'*** Начало периода = ' + coalesce(cast(@Min_Time as nvarchar(20)), '<null>')
	+nchar(13)	+N'***  Конец периода = ' + coalesce(cast(@Max_Time as nvarchar(20)), '<null>')
	+nchar(13)	+N'*** Отобрано строк = ' + coalesce(cast(@Count as nvarchar(20)), '<null>')

if @Only = 'TRUE' Return


Print '***' + @Version +' ============ Update Dictionaries ======='

-- **********                      Блок обновления информации				********** --
-- ********** Step 4: Обновление справочников по отобранным ранее данным	********** --

--4.1 Host:

if @NoClear <> 'TRUE' 
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Host]'
								
merge [dbo].[XEd_Host] as target
	using	(
			select	 [HostName]								as [HostName]
					,max(cast([DateTime_Stop] as date)	)	as [Date]
					,min(cast([DateTime_Start] as date)	)	as [First_Date]
					,count (1)								as [Cnt]
				from ##tmp1	as [h]
				where	[HostName]is not null
				group by [HostName]
			) as source (
						 [HostName] 
						,[Date]
						,[First_Date]
						,[Cnt]
						)  
	on (target.[HostName] = source.[HostName]) 
	when matched 
		then update set 
			target.[Date]		= source.[Date],
			target.[First_Date]	= case 
				when source.[First_Date] < target.[First_Date]  
					then source.[First_Date]
				else target.[First_Date]
				end,
			target.[Cnt]	= target.[Cnt] + source.[Cnt]
	when not matched  
		then insert values(
							source.[HostName]
							,source.[Date]
							,source.[First_Date]
							,source.[Cnt]
							);

--4.2 Database:

if @NoClear <> 'TRUE' 
	execute [dbo].[XE_ExecLog]	@Proc = '[dbo].[XE_Clear]', @Caller = @Version 

								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Database]'

merge [dbo].[XEd_Database] as target
	using	(
			selecT	 [Database_name]						as [Database_name]
					,[DatabaseID]							as [DatabaseID]
					,max(cast([DateTime_Stop] as date)	)	as [Date]
					,min(cast([DateTime_Stop] as date)	)	as [First_Date]
					,count(1)								as [Cnt]
		from		##tmp1
				where	[Database_name] is not null
				  and	[DatabaseID]	is not null
				group by [Database_name],[DatabaseID]
			) as source (
						 [Database_name] 
						,[DatabaseID]
						,[Date]
						,[First_Date]
						,[Cnt]
						)  
		on	(target.[Database_name]	= source.[Database_name] 
		and target.[DatabaseID]		= source.[DatabaseID])

	when matched then update set
		target.[Date]		= source.[Date],
		target.[First_Date]	= case 
				when source.[First_Date] < target.[First_Date]  
					then source.[First_Date]
				else target.[First_Date]
				end,
		target.[Cnt]	= target.[Cnt] + source.[Cnt]
	when not matched  
		then insert values(
							source.[Database_name]
							,source.[DatabaseID]
							,source.[Date]
							,source.[First_Date]
							,source.[Cnt]
							);
--4.3 Event:

if @NoClear <> 'TRUE' 
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Event]'

merge [dbo].[XEd_Event] as target
	using	(
			select	 @Session								as [Session]
					,[Package]								as [Package]
					,[Event]								as [Event]
					,max(cast([DateTime_Stop] as date)	)	as [Date]
					,min(cast([DateTime_Stop] as date)	)	as [First_Date]
					,count(1)								as [Cnt]
		from		##tmp1
				where	[Event]		is not null
				  or	[Package]	is not null
				GROUP BY [Session], [Package], [Event] 
			) AS source (
						 [Session]
						,[Package]
						,[Event] 
						,[Date]
						,[First_Date]
						,[Cnt]
						)  
		on	(target.[Event]		= source.[Event] 
		and  target.[Package]	= source.[Package]
		and  target.[Session]	= source.[Session])

	when matched then update set
		target.[Date]		= source.[Date],
		target.[First_Date]	= case 
				when source.[First_Date] < target.[First_Date]  
					then source.[First_Date]
				else target.[First_Date]
				end,
		target.[Cnt]	= target.[Cnt] + source.[Cnt]
	when not matched  
		then insert values(
							 source.[Session]
							,source.[Package]
							,source.[Event]
							,source.[Date]
							,source.[First_Date]
							,source.[Cnt]
							);

--4.4 Session:

if @NoClear <> 'TRUE' 
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Session]'

merge [dbo].[XEd_Session] as target
	using	(
			select	 @Session								as [Session]
					,max(cast([DateTime_Stop] as date)	)	as [Date]
					,min(cast([DateTime_Start] as date)	)	as [First_Date]
					,count (1)								as [Cnt]
				from ##tmp1	
			) AS source (
						 [Session]
						,[Date]
						,[First_Date]
						,[Cnt]
						)  
	on (target.[Session] = source.[Session]) 
	when matched 
		then update set 
			target.[Date]		= source.[Date],
			target.[First_Date]	= case 
				when source.[First_Date] < target.[First_Date]  
					then source.[First_Date]
				else target.[First_Date]
				end,
			target.[Cnt]	= target.[Cnt] + source.[Cnt]
	when not matched  
		then insert values(
							source.[Session]
							,source.[Date]
							,source.[First_Date]
							,source.[Cnt]
							);

--4.5 User:

if @NoClear <> 'TRUE' 	
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version 
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_User]'

merge [dbo].[XEd_User] as target
	using	(
			select	 case
						when [Nt_username] is null then ''
						else substring([Nt_username], patindex(N'%\%',[Nt_username])+1, 8000)
						end															as [Nt_username]
					,case
						when [Nt_username] is null then ''
						else substring([Nt_username], 0, patindex(N'%\%',[Nt_username]))
						end															as [Nt_AD]
					,case
						when [LoginName] is null then ''
						else substring([LoginName], patindex(N'%\%',[LoginName])+1, 8000)
						end															as [LoginName]
					,case
						when [LoginName] is null then ''
						else substring([LoginName], 0, patindex(N'%\%',[LoginName]))
						end															as [Login_AD]
					,max(cast([DateTime_Stop] as date)	)							as [Date]
					,min(cast([DateTime_Start] as date)	)							as [First_Date]
					,count (1)														as [Cnt]
				from ##tmp1	as [h]
				where		([LoginName] is not null) 
						or	([Nt_username] is not null)
				group by [LoginName], [Nt_username] 
			) as source (
						 [Nt_username]
						,[Nt_AD]
						,[LoginName]
						,[Login_AD]
						,[Date]
						,[First_Date]
						,[Cnt]
						)  
	on		(target.[Nt_username]	= source.[Nt_username])
		and	(target.[Nt_AD]			= source.[Nt_AD])
		and (target.[LoginName]		= source.[LoginName])
		and (target.[Login_AD]		= source.[Login_AD])
	when matched 
		then update set 
			target.[Date]		= source.[Date],
			target.[First_Date]	= case 
				when source.[First_Date] < target.[First_Date]  
					then source.[First_Date]
				else target.[First_Date]
				end,
			target.[Cnt]	= target.[Cnt] + source.[Cnt]
	when not matched  
		then insert values(
							source.[Nt_username]
							,source.[Nt_AD]
							,source.[LoginName]
							,source.[Login_AD]
							,source.[Date]
							,source.[First_Date]
							,source.[Cnt]
							);

--4.6 Application:

if @NoClear <> 'TRUE' 	
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version 
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Application]'

merge [dbo].[XEd_Application] as target
	using	(
			select	[Client_app_name] 						as [Application]
					,max(cast([DateTime_Stop] as date)	)	as [Date]
					,min(cast([DateTime_Start] as date)	)	as [First_Date]
					,count (1)								as [Cnt]
				from ##tmp1	as [h]
				where	[Client_app_name] is not null
				group by [Client_app_name]
			) as source (
						 [Application] 
						,[Date]
						,[First_Date]
						,[Cnt]
						)  
	on (target.[Application] = source.[Application]) 
	when matched 
		then update set 
			target.[Date]		= source.[Date],
			target.[First_Date]	= case 
				when source.[First_Date] < target.[First_Date]  
					then source.[First_Date]
				else target.[First_Date]
				end,
			target.[Cnt]	= target.[Cnt] + source.[Cnt]
	when not matched  
		then insert values(
							source.[Application]
							,source.[Date]
							,source.[First_Date]
							,source.[Cnt]
							);

-- 4.7 Result:

if @NoClear <> 'TRUE' 
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version 
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Result]'

merge [dbo].[XEd_Result] as target 
	 	using	(select	 coalesce([Result_Code], '') 
						,coalesce([Result_Text], '')
					,max(cast([DateTime_Stop] as date)	)	as [Date]
					,min(cast([DateTime_Start] as date)	)	as [First_Date]
					,count (1)								as [Cnt]
				from ##tmp1	as [h]
					where ([Result_Code] is not null)
					  and ([Result_Text] is not null)
					group by [Result_Code]
							,[Result_Text]
				)
		as source	([Result_Code]
					,[Result_Text]
					,[Date]
					,[First_Date]
					,[Cnt]
					)
		on  ([target].[Result_Code] = [source].[Result_Code])
		and ([target].[Result_Text] = [source].[Result_Text])
		when matched then update set
			target.[Date]	= source.[Date],
			target.[Cnt]	= target.[Cnt] + source.[Cnt]
		when not matched
			then insert values	([Result_Code]
								,[Result_Text]
								,[Date]
								,[First_Date]
								,[Cnt]
								);

--4.8 Output

if @NoClear <> 'TRUE'
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Output]'

	 merge [dbo].[XEd_Output] as target
		using	(select	 coalesce([Output_parameters], '')
					,max(cast([DateTime_Stop] as date)	)	as [Date]
					,min(cast([DateTime_Start] as date)	)	as [First_Date]
					,count (1)								as [Cnt]
				from ##tmp1	as [h]
					where ([Output_parameters] is not null)
					group by [Output_parameters]
				)
		as source	([Output_parameters]
					,[Date]
					,[First_Date]
					,[Cnt]
					)
		on  ([target].[Output_parameters] = [source].[Output_parameters])
		when matched then update set
			target.[Date]	= source.[Date],
			target.[Cnt]	= target.[Cnt] + source.[Cnt]
		when not matched
			then insert values	([Output_parameters]
								,[Date]
								,[First_Date]
								,[Cnt]
								);

--4.9 Hash:

if @NoClear <> 'TRUE'
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version 
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Hash]'

merge [dbo].[XEd_Hash] as [target]
	using	(
			select	 [Hash]											as [Hash]
					,null											as [HashText]
					,null											as [Exec#]
					,null											as [Table#]
					,max(cast([DateTime_Stop] as date)	)			as [Date]
					,min(cast([DateTime_Start] as date)	)			as [First_Date]
					,count(1)										as [Cnt]
					,min([TextData])								as [TextData]
					,null											as [Text]
				from ##tmp1	as [h]
				group by [Hash]
			) as source (
						 [Hash] 
						,[HashText]
						,[Exec#]
						,[Table#]
						,[Date]
						,[First_Date]
						,[Cnt]
						,[TextData]
						,[Text]
						)  
	on (target.[Hash] = source.[Hash]) 
	when matched then update set
		target.[Date]	= source.[Date],
		target.[Cnt]	= target.[Cnt] + source.[Cnt]
	when not matched  
		then insert values(
							 source.[Hash]
							,source.[HashText]
							,source.[Exec#]
							,source.[Table#]
							,source.[Date]
							,source.[First_Date]
							,source.[Cnt]
							,source.[TextData]
							,source.[Text]
							);

-- ********** Step 5: записываем информацию по всем запросам в журнал ********** --

-- 5.1 Очищаем данные чтобы избежать их возможного дублирования

if @NoClear <> 'TRUE' 	
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version 
								,@Session = @Session
								,@Option = @Option
								,@Table  = @Table
		
-- 5.2 Формируем данные для таблицы @Table в таблице #tmp3

update ##tmp1
set [Nt_username] = ''
where [Nt_username] is null 

update ##tmp1
set [LoginName] = ''
where [LoginName] is null 

select		 cast([l].[DateTime_Stop] as date)							as [Date]
 
 			,[CPU]														as [CPU]
			,[Duration]													as [Duration]
			,[Page_server_reads]										as [Page_server_reads]
			,[Reads_physical]											as [Reads_physical]
			,[Reads_logical]											as [Reads_logical]
			,[Writes]													as [Writes]
			,[Spills]													as [Spills]   
			,[Row_count]												as [Row_count]

			,cast([Is_System] as bit)									as [Is_System]
			,[Session_id]												as [Session_id]
			,[Client_pid]												as [Client_pid]
			,[Event_sequence]											as [Event_sequence]

			,[l].[DateTime_Start]											as [DateTime_Start]
			,[l].[DateTime_Stop]											as [DateTime_Stop]

			,[Ha].[Hash#]												as [Hash#]
			,[S].[Session#]												as [Session#]
			,[Ho].[Host#]												as [Host#]
			,[D].[Database#]											as [Database#]
			,[U].[User#]												as [User#]
			,[A].[Application#]											as [Application#]
			,[E].[Event#]												as [Event#]
			,[R].[Result#]												as [Result#]
			,[O].[Output#]												as [Output#]

		into		#tmp3
		from		##tmp1		as [l]
		left join	[dbo].[XEd_Hash]		as [Ha]	on   [Ha].[Hash]			= [l].[Hash]
		left join	[dbo].[XEd_Host]		as [Ho]	on   [Ho].[HostName]		= [l].[HostName]
		left join	[dbo].[XEd_Database]	as [D]	on   [D].[Database_name]	= [l].[Database_name]
		left join	[dbo].[XEd_Event]		as [E]	on  ([E].[Event]			= [l].[Event])
													and (upper([E].[Session])	= upper([l].[Session]))
													and ([E].[Package]			= [l].[Package])
		left join	[dbo].[XEd_Session]		as [S]	on	 upper([S].[Session])	= upper([l].[Session])
		left join	[dbo].[XEd_User]		as [U]	on	
					([U].[Nt_AD]	+ [U].[Nt_username]	= replace([l].[Nt_username],	'\', ''))
				and ([U].[Login_AD]	+ [U].[LoginName]	= replace([l].[LoginName],		'\', ''))
		left join	[dbo].[XEd_Application]	as [A]	on   [A].[Application]		= [l].[Client_app_name]
		left join	[dbo].[XEd_Output]		as [O]	on	 [O].[Output_parameters]= [l].[Output_parameters]
		left join	[dbo].[XEd_Result]		as [R]	on	([R].[Result_Code]		= [l].[Result_Code])
													and ([R].[Result_Text]		= [l].[Result_Text])

--5.3 Если целевая таблица отсутствует, то создаем ее

set @Option = @Option + ' INFO '

if  OBJECT_ID (@Table, N'U') IS NULL 
	execute [dbo].[XE_ExecLog]	 @Proc		= '[dbo].[XE_Install]', @Caller	= @Version	
								,@Steps		= 'XEL'
								,@Session	= @Session
								,@Table		= @Table
								,@Option	= @Option

set @Option = LEFT(@Option, len(@Option)-5)
										
-- 5.4 Очищаем данные при опции Replace

if		(@Replace = 'True') 
	and (@Max_Time is not null) 
	and (@Min_Time is not null )
		begin -- Replace Clear
			Set @Cmd =	 N'delete from ' + @Table + ' '
						+N' where [DateTime_Stop] >= ''' + cast(@Min_Time as nvarchar(30)) + ''' '	
						+N'   and [DateTime_Stop] <= ''' + cast(@Max_Time as nvarchar(30)) + ''' '
			EXECUTE sp_executesql @Cmd 
		end	-- Replace Clear

--5.5 Переносим данные в целевую таблицу

Set @Cmd = 
			'insert into ' + @Table + ' '
			+' select * '
			+' from #tmp3 '
			+' order by [DateTime_Stop] '

EXECUTE sp_executesql @Cmd 

-- 5.6 Обрабатываем данных от TextData

if @Skip = 'FALSE' 
	execute [dbo].[XE_ExecLog]	 @Proc		= '[dbo].[XE_TextData]', @Caller	= @Version
								,@Session	= @Session
								,@Option	= @Option
										
-- 5.7 Обновляем справочник обработанных файлов XEd_Source

MERGE [dbo].[XEd_Source] AS target
	USING	(
			SELECT	 getdate()								as [DateTime]
					,@Session								as [Session]
					,@Source								as [Source]
					,[Date]									as [Date]
					,[Time]									as [Time]
					,[Directory]							as [Directory]
					,[File_Name]							as [File_Name]
					,[Records]								as [Records]
					,[Events]								as [Events]
				from #Files	as [f]
			) AS source (
						  [DateTime]
						 ,[Session]
						 ,[Source]
						 ,[Date]
						 ,[Time]
						 ,[Directory]
						 ,[File_Name]
						 ,[Records]
						 ,[Events]
						)  
	ON	(target.[Session]	= source.[Session]) 
	and	(target.[Directory]	= source.[Directory])
	and	(target.[File_Name]	= source.[File_Name])

	WHEN MATCHED 
		THEN UPDATE SET 
			target.[Date]		= source.[Date],
			target.[Time]		= source.[Time], 
			target.[Records]	= source.[Records],
			target.[Events]		= source.[Events] 
	WHEN NOT MATCHED  
		THEN INSERT VALUES(
							source.[DateTime]
							,source.[Session]
							,source.[Source]
							,source.[Date]
							,source.[Time]
							,source.[Directory]
							,source.[File_Name]
							,source.[Records]
							,source.[Events]
							);

-- ********** Step 6: Очистка по завершению  ********** --

Drop table if exists #tmp0, ##tmp1, #tmp3, #Dir, #Files;

	END	-- procedure [dbo].[XE_Xel]