/* =============================================	
-- Author:		Sotivoli
-- Create date: 07 October 2024
-- Description:	Импорт данных из данных XE 4.4 за день.
-- =============================================
exec [dbo].[XE_Import_XE44]  @Option= '\PROFILER LIST \ONLY REPLACE NODB Skip'   
					 ,@Source='[dbo].[Log_XE_Sotivoli]' 
					 ,@Table ='[dbo].[XE_SOTIVOLI]' 
					 ,@Session='SOTIVOLI'
					 ,@Start = '2024-09-18 00:00:00'
					 ,@Stop = '2024-09-19 00:00:00'

exec [dbo].[XE_Import_XE44]
	 @Start		= '2024-07-14 00:00:00'
	,@Stop		= '2024-07-15 00:00:00'
	,@Source		= '[alidi backup].[dbo].[Log_XE_SQL251]'
	,@Table		= 'XE_Convert'
	,@Session	= null
	,@Option	= 'nodb \list \only'

--	truncate table XE_CONVERT
-- ============================================= */
--	Declare
	drop procedure if exists	[dbo].[XE_Import_XE44];
GO
	CREATE	PROCEDURE [dbo].[XE_Import_XE44]
 @Start			datetime		= null	-- '2024-06-19 00:00:00'
,@Stop			datetime		= null	-- '2024-06-20 00:00:00'
,@Source		nvarchar(2048)	= null	-- '[Prof_log_251_char]' 
,@Table			nvarchar(128)	= null	-- 'XE_Profiler'
,@Session		nvarchar(128)	= null	-- Имя сессии XE
,@Option		nvarchar(256)	= null	-- 

	AS BEGIN	-- [dbo].[XE_Import_XE44]

-- ********** Step 0: Инициализация ********** --
		
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;
Declare	 @Version		as nvarchar(30)	= N'XE_Import_XE44 v5.0.d'
		,@Cmd			as nvarchar(max)
		,@Date			as date
		,@MaxDate		as date
		,@Session#		as int
		,@Min_XE_Date	as datetime
		,@List			as bit			= 'False'
		,@Only			as bit			= 'False'
		,@NoDB			as bit			= 'False'
		,@Skip			as bit			= 'False'
		,@Max_Time		as datetime2(7) = @Start 
		,@Min_Time		as datetime2(7)	= @Stop
		,@TimeShift		as int			= datediff(hh, getutcdate(), getdate())

-- **********  Step 1: Проверка параметров вызова ********** --
-- 0.2 Проверка корректности и модификация входных данных

exec [dbo].[XE_CheckParams]	 @Session = @Session output
							,@Table   = @Table  output

-- 1.3	@Option: проверка на наличие параметров:
--					List (только вывод справочной информации) 
--					NoDB (не заполнять поля DBname - имя БД по id БД)
--					Only (только информация,  не выполнять действия)

if upper(' '+@Option+' ') like upper(N'% ' + N'List'	+ N' %') Set @List = 'True'
if upper(' '+@Option+' ') like upper(N'% ' + N'NoDB'	+ N' %') Set @NoDB = 'True'
if upper(' '+@Option+' ') like upper(N'% ' + N'Only'	+ N' %') Set @Only = 'True'
if upper(' '+@Option+' ') like upper(N'% ' + N'SKIP'	+ N' %') Set @Skip = 'True'

-- 1.4	@Source: проверка на наличие таблицы с данными Profiler:

if (@Source is null) or ((OBJECT_ID(@Source, N'U') is null) and (OBJECT_ID(@Source, N'V') is null))
	begin -- указанной Profiler table не существует
		Set @Cmd =	 N' ' + @Version 
					+N' Error: Таблица с данными XE, указанная в параметре @Source="' 
					+ coalesce(@Source, N'<null>')	
					+ N'" не существует, обработка невозможна"';			 
		RAISERROR(@Cmd, 16, 1)
		return --(8)
	end -- указанной Profiler table не существует

--1.5 Если целевая таблица отсутствует, то делаем ее по образу и подобию Log_XE

if  OBJECT_ID (@Table, N'U') IS NULL 
	execute [dbo].[XE_ExecLog]	 @Proc		= N'[dbo].[XE_Install]', @Caller	= @Version	
								,@Steps		= N'XEL'
								,@Session	= @Session
								,@Table		= @Table
								,@Option	= @Option

-- 2.2 Считываем данные в ##tmp1

drop table if exists ##tmp1	

create table ##tmp1	(
					 [Row]				bigint			null
					,[Session]			nvarchar(128)	COLLATE DATABASE_DEFAULT null  
					,[DateTime_Start]	datetime2(7)	null
					,[DateTime_Stop]	datetime2(7)	null
					,[Object_name]		nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[Event]			nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[Package]			nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[CPU]				bigint			null
					,[Duration]			bigint			null
					,[Page_server_reads] bigint			null
					,[Reads_physical]	bigint			null
					,[Reads_logical]	bigint			null
					,[Writes]			bigint			null
					,[Spills]			bigint			null
					,[Result_Code]		int				null
					,[Result_Text]		nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[Row_count]		bigint			null
					,[Output_parameters] nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[DatabaseID]		int				null
					,[LoginName]		nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[HostName]			nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[Session_id]		bigint			null
					,[Nt_username]		nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[Is_system]		bit				null
					,[Database_name]	nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[Client_pid]		bigint			null	
					,[Client_app_name]	nvarchar(128)	COLLATE DATABASE_DEFAULT null
					,[Event_sequence]	bigint			null
					,[TextData]			nvarchar(max)	COLLATE DATABASE_DEFAULT null
					,[Hash]				nchar(32)		COLLATE DATABASE_DEFAULT null
					)

declare @DB as nvarchar(128) 
set @DB = coalesce(quotename(parsename(@Source,3)) + '.', '')
		+ coalesce(quotename(parsename(@Source,2)) + '.', '.')

Set @Cmd = 
N'insert into ##tmp1
([Row],[Session],[DateTime_Start],[DateTime_Stop],[Object_name],[Event],[Package]
,[CPU],[Duration],[Page_server_reads],[Reads_physical],[Reads_logical],[Writes]
,[Spills],[Result_Code],[Result_Text],[Row_count],[Output_parameters],[DatabaseID]
,[LoginName],[HostName],[Session_id],[Nt_username],[Is_system],[Database_name]
,[Client_pid],[Client_app_name],[Event_sequence],[TextData],[Hash])
SELECT 
	[RowNumber] as [Row]
	,[s].[Server] as [Session]
	,dateadd(hh, ' + cast(@TimeShift as nvarchar(10)) + ', [DateTime_Start]) as [DateTime_Start]
	,dateadd(hh, ' + cast(@TimeShift as nvarchar(10)) + ', [DateTime_Stop])  as [DateTime_Stop]
	,''' + @Version + N'''	as [Object_name]
	,[e].[Event]
	,[e].[Package]
	,[CPU]
	,[Duration]
	,[Page_server_reads]
	,[Reads_physical]
	,[Reads_logical]
	,[Writes]
	,[Spills]
	,[Result_Code]
	,[Result_Text]
	,[Row_count]
	,[Output_parameters]
	,[d].[DatabaseID]	as [DatabaseID]
	,coalesce([u].[Login_AD], '''')	+ ''\'' + [u].[LoginName] as [LoginName]
	,[t].[HostName]		as [HostName]
	,[Session_id]
	,coalesce([u].[Nt_AD], '''')		+ ''\'' + [u].[Nt_username] as [Nt_username]
	,[h].[Is_system]	as [Is_system]
	,[d].[Database_name]
	,[Client_pid]
	,[a].[Application]			as [Client_app_name]
	,[Event_sequence]
	,[h].[TextData]
	,cast(HASHBYTES(''SHA2_256'', [h].[TextData]) as nchar(32))	as	[Hash]
from	  ' + @Source + N'	as [x]
left join ' + @DB   + N'[Dic_Server]	as [s] on [s].[Server#]		= [x].[Server#]
left join ' + @DB   + N'[Dic_Event]		as [e] on [e].[Event#]		= [x].[Event#]
left join ' + @DB   + N'[Dic_Hash]		as [h] on [h].[Hash#]		= [x].[Hash#]
left join ' + @DB   + N'[Dic_Database]	as [d] on [d].[Database#]	= [x].[Database#]
left join ' + @DB   + N'[Dic_User]		as [u] on [u].[User#]		= [x].[User#]
left join ' + @DB   + N'[Dic_Host]		as [t] on [t].[Host#]		= [x].[Host#]
left join ' + @DB   + N'[Dic_Application]as [a] on [a].[Application#]= [x].[Application#]
  where dateadd(hh, ' + cast(@TimeShift as nvarchar(10)) + ', [DateTime_Stop])  <  ''' + cast(@Stop as nvarchar(30)) + N''' '
 +N' and dateadd(hh,' + cast(@TimeShift as nvarchar(10)) + ', [DateTime_Stop]) >= ''' + cast(@Start as nvarchar(30)) + N''' '
 +N' order by [DateTime_Stop] '

EXECUTE sp_executesql @Cmd

declare @Count as bigint
select @Count = COUNT(1) from ##tmp1 


-- ********** Далее идет копия куска из XE_Xel, кроме удаления архивов и записи в XEd_Source ********** --

-- ********** Step 3: Действия по @Option = 'List' ********** --

if @List = 'TRUE'
	print   	+N'*** Начало периода = ' + coalesce(cast(@Min_Time as nvarchar(20)), N'<null>')
	+nchar(13)	+N'***  Конец периода = ' + coalesce(cast(@Max_Time as nvarchar(20)), N'<null>')
	+nchar(13)	+N'*** Отобрано строк = ' + coalesce(cast(@Count as nvarchar(20)),    N'<null>')

if @Only = 'TRUE' Return

-- **********                      Блок обновления информации				********** --
-- ********** Step 4: Обновление справочников по отобранным ранее данным	********** --

--4.1 Host:

								
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
	on (target.[HostName] COLLATE DATABASE_DEFAULT = source.[HostName] COLLATE DATABASE_DEFAULT)
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
		on	(target.[Database_name] COLLATE DATABASE_DEFAULT = source.[Database_name] COLLATE DATABASE_DEFAULT  
		and target.[DatabaseID] = source.[DatabaseID])

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
		on	(target.[Event] COLLATE DATABASE_DEFAULT = source.[Event]  COLLATE DATABASE_DEFAULT 
		and  target.[Package] COLLATE DATABASE_DEFAULT = source.[Package] COLLATE DATABASE_DEFAULT 
		and  target.[Session] COLLATE DATABASE_DEFAULT = source.[Session] COLLATE DATABASE_DEFAULT )

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
	on		(target.[Nt_username] COLLATE DATABASE_DEFAULT = source.[Nt_username] COLLATE DATABASE_DEFAULT )
		and	(target.[Nt_AD] COLLATE DATABASE_DEFAULT = source.[Nt_AD] COLLATE DATABASE_DEFAULT )
		and (target.[LoginName] COLLATE DATABASE_DEFAULT = source.[LoginName] COLLATE DATABASE_DEFAULT)
		and (target.[Login_AD]	 COLLATE DATABASE_DEFAULT = source.[Login_AD] COLLATE DATABASE_DEFAULT)
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
	on (target.[Application] COLLATE DATABASE_DEFAULT = source.[Application] COLLATE DATABASE_DEFAULT ) 
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
		and ([target].[Result_Text] COLLATE DATABASE_DEFAULT  = [source].[Result_Text] COLLATE DATABASE_DEFAULT )
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
		on  ([target].[Output_parameters] COLLATE DATABASE_DEFAULT = [source].[Output_parameters] COLLATE DATABASE_DEFAULT)
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
	on (target.[Hash]  COLLATE DATABASE_DEFAULT = cast(source.[Hash] as nchar(32)) COLLATE DATABASE_DEFAULT ) 
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
		
-- 5.2 Формируем данные для таблицы @Table в таблице #tmp3
update ##tmp1
set [Nt_username] = ''
where [Nt_username] is null 

update ##tmp1
set [LoginName] = ''
where [LoginName] is null 

drop table if exists #tmp3

select		 cast([l].[DateTime_Stop] as date)							as [Date]
 			,[CPU]														as [CPU]
			,[Duration]													as [Duration]
			,[Page_server_reads]										as [Page_server_reads]
			,[Reads_physical]											as [Reads_physical]
			,[Reads_logical]											as [Reads_logical]
			,[Writes]													as [Writes]
			,[Spills]													as [Spills]   
			,[Row_count]												as [Row_count]

			,cast([Is_system] as bit)									as [Is_System]
			,[Session_id]												as [Session_id]
			,[Client_pid]												as [Client_pid]
			,[Event_sequence]											as [Event_sequence]

			,[l].[DateTime_Start]										as [DateTime_Start]
			,[l].[DateTime_Stop]										as [DateTime_Stop]

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
		left join	[dbo].[XEd_Hash] as [Ha]	on   [Ha].[Hash] COLLATE DATABASE_DEFAULT = cast([l].[Hash] as NCHAR(32)) COLLATE DATABASE_DEFAULT 
		left join	[dbo].[XEd_Host] as [Ho]		on   [Ho].[HostName] COLLATE DATABASE_DEFAULT = [l].[HostName] COLLATE DATABASE_DEFAULT 
		left join	[dbo].[XEd_Database]	as [D]	on   [D].[Database_name] COLLATE DATABASE_DEFAULT 	= [l].[Database_name] COLLATE DATABASE_DEFAULT 
		left join	[dbo].[XEd_Event]		as [E]	on  ([E].[Event] COLLATE DATABASE_DEFAULT 			= [l].[Event] COLLATE DATABASE_DEFAULT )
													and (upper([E].[Session] COLLATE DATABASE_DEFAULT )	= upper([l].[Session] COLLATE DATABASE_DEFAULT ))
													and ([E].[Package] COLLATE DATABASE_DEFAULT 			= [l].[Package] COLLATE DATABASE_DEFAULT )
		left join	[dbo].[XEd_Session]		as [S]	on	 upper([S].[Session] COLLATE DATABASE_DEFAULT )	= upper([l].[Session] COLLATE DATABASE_DEFAULT )
		left join	[dbo].[XEd_User]		as [U]	on	
					([U].[Nt_AD]	+ [U].[Nt_username] COLLATE DATABASE_DEFAULT 	= replace([l].[Nt_username] COLLATE DATABASE_DEFAULT ,	'\', ''))
				and ([U].[Login_AD] COLLATE DATABASE_DEFAULT 	+ [U].[LoginName] COLLATE DATABASE_DEFAULT 	= replace([l].[LoginName] COLLATE DATABASE_DEFAULT ,		'\', ''))
		left join	[dbo].[XEd_Application]	as [A]	on   [A].[Application] COLLATE DATABASE_DEFAULT 		= [l].[Client_app_name] COLLATE DATABASE_DEFAULT 
		left join	[dbo].[XEd_Output]		as [O]	on	 [O].[Output_parameters] COLLATE DATABASE_DEFAULT  = [l].[Output_parameters] COLLATE DATABASE_DEFAULT 

		left join	[dbo].[XEd_Result]		as [R]	on	([R].[Result_Code]		= [l].[Result_Code])
													and ([R].[Result_Text] COLLATE DATABASE_DEFAULT 		= [l].[Result_Text] COLLATE DATABASE_DEFAULT )

--5.3 Если целевая таблица отсутствует, то создаем ее

set @Option = @Option + N' INFO '

if  OBJECT_ID (@Table, N'U') IS NULL 
	execute [dbo].[XE_ExecLog]	 @Proc		= N'[dbo].[XE_Install]', @Caller	= @Version	
								,@Steps		= N'XEL'
								,@Session	= @Session
								,@Table		= @Table
								,@Option	= @Option

set @Option = LEFT(@Option, len(@Option)-5)
										
--5.4 Переносим данные в целевую таблицу
Set @Cmd = 
			 N'insert into ' + @Table + ' '
			+N' select * '
			+N' from #tmp3 '
			+N' order by [DateTime_Stop] '

EXECUTE sp_executesql @Cmd 

-- 5.5 Обрабатываем данных от TextData

if @Skip = 'FALSE' 
	execute [dbo].[XE_ExecLog]	 @Proc		= N'[dbo].[XE_TextData]', @Caller	= @Version
								,@Session	= @Session
								,@Option	= @Option
									
-- ********** Step 6: Очистка по завершению  ********** --
Drop table if exists #tmp0, ##tmp1, #tmp3, #Dir, #Files;

	END	-- [dbo].[XE_Import_XE44]