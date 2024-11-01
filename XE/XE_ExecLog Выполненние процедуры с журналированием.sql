/*-- =============================================
-- Author:				Sotivoli
-- Create date:			03 October 2024
-- Description:			Выполнение указанной процедуры с журналированием выполнения
--						в журнал [dbo].[XEd_Log]
-- ============================================= 
exec XE_ExecLog	 @Proc			= '[dbo].[XE_Test]'
				,@Caller		= 'Я сам'
				,@Option		= 'list only'			
				,@Comm			= 'Для теста'
				,@Table			= '[dbo].[XE_SQL251]'
				,@Session		= 'SQL251'
				,@Date			= '2024-09-30'
				,@Records		= 200
				,@Percent		= 0.01
				,@AddSum		= 85.
				,@Start			= '2024-01-01'
				,@Stop			= '2024-12-31'
				,@Source		= 'C:\log\*.*'
				,@Offset		= 400
				,@Orders		= 200
				,@OrdersProc	= 'XE_JDECount'
				,@Steps			= 'Step1 Step 2 3'
				,@Error			= null
-- truncate table [dbo].[XEd_Log]
-- ============================================= */

--	Declare
	drop procedure if exists	[dbo].[XE_ExecLog]
GO
	Create	procedure			[dbo].[XE_ExecLog]
 @Proc			nvarchar(128)	= null --  Имя выполняемой процедуры
,@Caller		nvarchar(128)	= null -- кто вызывает
,@Option		nvarchar(256)	= null -- опции выполнения
,@Comm			nvarchar(256)	= null -- 'комментарий к программе'	-- Комментарий в журнал
,@Table			nvarchar(128)	= null -- 
,@Session		nvarchar(128)	= null -- 
,@Date			date			= null
,@Records		bigint			= null
,@Percent		numeric(13,6)	= null
,@AddSum		numeric(13,6)	= null
,@Start			date			= null
,@Stop			date			= null
,@Source		nvarchar(2048)	= null
,@Offset		int				= null
,@Orders		int				= null
,@OrdersProc	nvarchar(128)	= null
,@Steps			nvarchar(256)	= null
,@Error			int				= null
	AS BEGIN
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

Declare  @Version		nvarchar(30)	= 'XE_ExecLog v 5.0p'
		,@Cmd			nvarchar(max)	= ''
		,@StartTime		datetime2(7)

if @Proc is null 
	begin	-- no @Procedure
		Set @Cmd = 	 N'***   ' + @Version + N' Error: Не указано имя процедуры (@Procedure),'
					+nchar(13) +N'               Обработка невозможна.'
		RAISERROR(@Cmd, 16, 1)
		return 		
	end -- no @Procedure

Set @Cmd = @Proc + ' '

-- Анализ параметров и формирование процедур

if @Option	 is not null Set @Cmd = @Cmd + ' @Option='''  + @Option							 + ''','
if @Table	 is not null Set @Cmd = @Cmd + ' @Table='''	  + @Table							 + ''','
if @Session	 is not null Set @Cmd = @Cmd + ' @Session=''' + @Session						 + ''','
if @Date	 is not null Set @Cmd = @Cmd + ' @Date='''	  + cast(@Date		as nvarchar(20)) + ''','
if @Records  is not null Set @Cmd = @Cmd + ' @Records=''' + cast(@Records	as nvarchar(20)) + ''','
if @Percent	 is not null Set @Cmd = @Cmd + ' @Percent=''' + cast(@Percent	as nvarchar(20)) + ''','
if @AddSum	 is not null Set @Cmd = @Cmd + ' @AddSum='''  + cast(@AddSum	as nvarchar(20)) + ''','
if @Start	 is not null Set @Cmd = @Cmd + ' @Start='''	  + cast(@Start		as nvarchar(20)) + ''','
if @Stop	 is not null Set @Cmd = @Cmd + ' @Stop='''	  + cast(@Stop		as nvarchar(20)) + ''','

if @Source	 is not null Set @Cmd = @Cmd + ' @Source='''  + @Source							 + ''','
if @Offset	 is not null Set @Cmd = @Cmd + ' @Offset='''  + cast(@Offset	as nvarchar(20)) + ''','
if @Orders	 is not null Set @Cmd = @Cmd + ' @Orders='''  + cast(@Orders	as nvarchar(20)) + ''','
if @OrdersProc is not null Set @Cmd = @Cmd + ' @OrdersProc=''' + cast(@OrdersProc as nvarchar(20)) + ''','
if @Steps	 is not null Set @Cmd = @Cmd + ' @Steps='''	  + @Steps							 + ''','

Set @Cmd = left(@Cmd, len(@Cmd)-1)
Set @StartTime = getdate()
-- print '@Cmd =		"' + coalesce(@Cmd,			'<null>')	+ '"'

if @Error is null execute sp_sqlexec @Cmd

Insert into [dbo].[XEd_Log]	
	([Дата]
	,[Caller]
	,[Procedure]
		
	,[Option]
	,[Table]
	,[Session]
	,[Date]
	,[Records]
	,[Percent]
	,[AddSum]
	,[Start]
	,[Stop]
	,[Source]
	,[Offset]
	,[Orders]
	,[OrdersProc]
	,[Steps]

	,[@@ERROR]
	,[@@ROWCOUNT]
	,[ERROR_LINE]

	,[Begin]
	,[End]
	,[Duration]

	,[Comment]

	,[HOST_ID]
	,[HOST_NAME]
							 )
	values	(
			cast(@StartTime as date)
			,@Caller
			,@Proc

			,@Option
			,@Table
			,@Session
			,@Date
			,@Records
			,@Percent
			,@AddSum
			,@Start
			,@Stop
			,@Source
			,@Offset
			,@Orders
			,@OrdersProc
			,@Steps

			,@@ERROR
			,@@ROWCOUNT
			,ERROR_LINE()

			,@StartTime
			,getdate()
			,coalesce(datediff(second, @StartTime,  getdate()), 0)

			,@Comm

			,HOST_ID()
			,HOST_NAME()
			)

END	-- PROCEDURE [dbo].[XE_Execution]