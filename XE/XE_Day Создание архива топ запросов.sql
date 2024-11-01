/* =============================================
-- Author:				Sotivoli
-- Create date:			11 August 2024
-- Description:	Формирование информации по top запросам (XE_Top) и сумме за день (XE_Sum) из
--			выборки запросов за один день из [dbo].[XE_]	и суммарных данных за день в [dbo].[XE_Day]
-- =============================================
exec [dbo].[XE_Day] 
	 @Option='\List \only'
	,@Date		='2024-07-12'
--	,@Session	= 'sql251'
--	,@Table		= null
	,@Records	= 100
	,@Percent	= 0.05
	,@Addsum	= 70.0
-- ============================================= */
--	 
GO
drop procedure if exists	[dbo].[XE_Day]
GO
	CREATE	PROCEDURE		[dbo].[XE_Day]
 @Session		as nvarchar(128)	= null	-- Имя сессии XE
,@Date			as date				= null	-- Дата отбора данных, по умолчанию - вчера
,@Table			as nvarchar(128)	= null	-- Имя таблицы полных данных
,@Option		as nvarchar(256)	= null	-- Параметры 
,@Records		as bigint			= null	
,@Percent		as numeric(13,6)	= null
,@AddSum		numeric(13,6)		= null	
	AS BEGIN

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

-- ********** Step 0: Инициализация ********** --
-- 0.1 Определение переменных

Declare  @Version				as nvarchar(30)	= N'XE_Day v 5.0.p'
		,@Max_Time				as datetime2(7)
		,@Min_Time				as datetime2(7)

		,@CPU					as bigint
		,@Duration				as bigint
		,@Reads_physical		as bigint
		,@Reads_logical			as bigint
		,@Writes				as bigint
		,@Spills				as bigint
		,@Page_server_reads		as bigint
		,@Row_count				as bigint

		,@Session#				as int
		,@Orders				as bigint
		,@OrdersProc			as nvarchar(128)	= null
		,@Reqs					as bigint
		,@Cmd					as nvarchar(max)
		,@ParamDef				as nvarchar(max)

		,@List					as bit				= 'False'	-- Выводить информацию о выполнении
		,@Only					as bit				= 'False'	-- Только информация, но не выполнение
		,@NoClear				as bit				= 'False'	-- Не удалять архивные данные 

-- 0.2 Проверка корректности и модификация входных данных

declare @Object		nvarchar(128)	= @Table

exec [dbo].[XE_CheckParams]	 @Session		= @Session		output
							,@Session#		= @Session#		output
							,@Table			= @Table		output
							,@OrdersProc	= @OrdersProc	output
							,@Records		= @Records		output
							,@Percent		= @Percent		output 
							,@AddSum		= @AddSum		output
							,@Object		= @Object		output

-- 0.3	@Option: Установка параметров выполнения:

if upper(' '+@Option+' ') like upper(N'% ' + N'List'	+N' %')	Set @List		= 'True'
if upper(' '+@Option+' ') like upper(N'% ' + N'Only'	+N' %')	Set @Only		= 'True'
if upper(' '+@Option+' ') like upper(N'% ' + N'NoClear'	+N' %')	Set @NoClear	= 'True'

-- ********** Step 1: Информационный блок ********** --

if @List = 'TRUE' 
	print	 N'***   ' + @Version + ': @Session = ' + coalesce(@Session, '<null>')
+nchar(13)	+N'***                     @Session# = '	+ coalesce(cast(@Session# as nvarchar(10)), '<null>')
+nchar(13)	+N'***                       @Table = '	+ coalesce(@Table, '<null>')
+nchar(13)	+N'***                        @List = '	+ coalesce(cast(@List as nvarchar(8)), '<null>')
+nchar(13)	+N'***                        @Only = '	+ coalesce(cast(@Only as nvarchar(8)), '<null>')
+nchar(13)	+N'***                     @NoClear = ' + coalesce(cast(@NoClear as nvarchar(8)), '<null>')
+nchar(13)	+N'***                        @Date = '	+ coalesce(cast(@Date as nvarchar(20)), '<null>')
+nchar(13)	+N'***                  @OrdersProc = '	+ coalesce(cast(@OrdersProc as nvarchar(20)), '<null>')
+nchar(13)	+N'***                     @Records = '	+ coalesce(cast(@Records as nvarchar(20)), '<null>')
+nchar(13)	+N'***                     @Percent = '	+ coalesce(cast(@Percent as nvarchar(20)), '<null>')
+nchar(13)	+N'***                      @Addsum = '	+ coalesce(cast(@AddSum as nvarchar(20)), '<null>')


-- ********** Step 2: Считываем данные за день в промежуточную таблицу ##tmp0 ********** --

drop table if exists ##tmp0
Set @Cmd = 
'select	 * '
+	'into ##tmp0 '
+	'from ' + @Table 
+		'where [Date]	= '''	+cast(@Date		as nvarchar(20)) +''' '
+		  'and [Session#]	= '		+ cast(coalesce(@Session#,1)	as nvarchar(10)) + ' ' 
EXECUTE sp_executesql @Cmd 

if (select COUNT(1) from ##tmp0) = 0 return 

-- ********** Step 2: Обработка суммарных значений за сутки ********** --

-- 2.1 Суммируем данные, отобранные ранее за день
--	Заменяем значение суммы, если она равна нулю на null чтобы избежать деления на ноль 

select	 
	@Reqs				= count(1)
	,@CPU				= case when sum([CPU])				 = 0 then null else sum([CPU])				end
	,@Duration			= case when sum([Duration])			 = 0 then null else sum([Duration])			end
	,@Reads_physical	= case when sum([Reads_physical])	 = 0 then null else sum([Reads_physical])	end
	,@Reads_logical		= case when sum([Reads_logical])	 = 0 then null else sum([Reads_logical])	end
	,@Writes			= case when sum([Writes])			 = 0 then null else sum([Writes])			end
	,@Spills			= case when sum([Spills])			 = 0 then null else sum([Spills])			end
	,@Page_server_reads	= case when sum([Page_server_reads]) = 0 then null else sum([Page_server_reads])end
	,@Row_count			= case when sum([Row_count])		 = 0 then null else sum([Row_count])		end
	from ##tmp0

-- 2.2 Определяем число заказов (в JDE или иных приложениях) - имя процедуры (@Otrders) - из XEd_Set

if @OrdersProc is not null
	begin -- @Orders
		SET @ParamDef	= N'@Date date, @Orders int OUTPUT';
		Set @Cmd = 'exec [dbo].[' + parsename(@OrdersProc, 1) +']  @Date = @Date, @Orders	= @Orders output'
		EXEC sp_executesql @Cmd, @ParamDef, @Date = @Date, @Orders = @Orders OUTPUT

-- Фальшивый вызов ExecLog (@Error is not null) для фиксации вызова в XEd_Log
		
		execute [dbo].[XE_ExecLog]	 @Proc		= @OrdersProc, @Caller	= @Version
									,@Date		= @Date
									,@Orders	= @Orders
									,@Error		= @@ERROR
									,@Comm		= 'Фиксация результата выполнения'

	end	-- @Orders

-- ********** Step 3: Обновляем таблицу XE_Sum ********** --

-- 3.1 Удаление данных за пределами границы хранения данных (@Offset_Sum)

if @NoClear = 'FALSE' and @Only = 'FALSE' 
	execute [dbo].[XE_ExecLog]	 @Proc		= '[dbo].[XE_Clear]', @Caller	= @Version
								,@Session	= @Session
								,@Table		= '[dbo].[XE_Sum]'
								,@Option	= @Option

-- 3.2 Удаление данных за указанное число от указанной сессии
--		для исключения возможного дублирования данных

if @Only = 'FALSE' 
	begin	-- Перезапись строки данных в XE_Sum
		Delete from [dbo].[XE_Sum] 
			where [Date]	= @Date
			  and [Session]	= @Session;

-- 3.3 Запись суммарных данных за день в таблицу [dbo].[XE_Sum]

		Insert into [dbo].[XE_Sum]
									([Session#]
									,[Session]
									,[Date]
									,[CPU]
									,[Duration]
									,[Page_server_reads]
									,[Reads_physical]
									,[Reads_logical]
									,[Writes]
									,[Spills]
									,[Row_count]
									,[Reqs_Cnt]
									,[Orders]
									)
			select	 @Session#			as [Session#]
					,@Session			as [Session]
					,@Date				as [Date]
					,@CPU				as [CPU]
					,@Duration			as [Duration]
					,@Page_server_reads as [Page_server_reads]
					,@Reads_physical	as [Reads_physical]
					,@Reads_logical		as [Reads_logical]
					,@Writes			as [Writes]
					,@Spills			as [Spills]
					,@Row_count			as [Row_count]
					,@Reqs				as [Reqs_Cnt]
					,@Orders			as [Orders]
			
	end		-- Перезапись строки данных в XE_Sum

-- ********** Step 4: Вычисляем различные ранги запросов за день ********** --
-- Вынесено из предыдущего шага, чтобы убрать множественные coalesce в расчетах

drop table if exists #tmp1
Select	 [RowNumber]
		,[Hash#]
--	4.1	Определяем простой ранг запросов по каждому из интересующих ресурсов
		,case when @CPU is null
			then null 
			else rank() over(order by CPU desc,	RowNumber) 
			end													as [CPU_Rank]
		,case when @Duration is null 
			then null 
			else rank() over(order by Duration desc,	RowNumber) 
			end													as [Duration_Rank]
		,case when @Reads_physical is null 
			then null 
			else rank() over(order by Reads_logical desc,	RowNumber) 
			end													as [Reads_logical_Rank]
		,case when @Reads_physical is null
			then null 
			else rank() over(order by Reads_physical desc,	RowNumber) 
			end													as [Reads_physical_Rank]
		,case when @Writes is null
			then null 
			else rank() over(order by Writes desc,	RowNumber) 
			end													as [Writes_Rank]
		,case 
			when @Spills is null then null 
			when [Spills] is null then 99999999
			when [Spills] = 0 then 99999999
			else rank() over(order by Spills desc,	RowNumber) 
			end													as [Spills_Rank]
-- 4.2	Вычисление % от общего потребления ресурса
		,100. * CPU				/ @CPU						as [CPU_Pct]
		,100. * Duration		/ @Duration					as [Duration_Pct]
		,100. * Reads_physical	/ @Reads_physical			as [Reads_physical_Pct]
		,100. * Reads_logical	/ @Reads_logical			as [Reads_logical_Pct]
		,100. * Writes			/ @Writes					as [Writes_Pct]
		,100. * Spills			/ @Spills					as [Spills_Pct]
-- 4.3	Вычисление для запросов процента потребления ресурсов нарастающим итогом
		,100. * sum(coalesce(CPU,0))			
			over(order by CPU            desc, RowNumber desc)
			/ @CPU											as [CPU_Add]
		,100. * sum(coalesce(Duration,0))		
			over(order by Duration       desc, RowNumber desc)
			/ @Duration										as [Duration_Add]
		,100. * sum(coalesce(Reads_physical,0))	
			over(order by Reads_physical desc, RowNumber desc)
			/ @Reads_physical								as [Reads_physical_Add]
		,100. * sum(coalesce(Reads_logical,0))	
			over(order by Reads_logical  desc, RowNumber desc)
			/ @Reads_logical								as [Reads_logical_Add]
		,100. * sum(coalesce(Writes,0))			
			over(order by Writes         desc, RowNumber desc)
			/ @Writes										as [Writes_Add]
		,100. * sum(coalesce(Spills,0))			
			over(order by Spills         desc, RowNumber desc)
			/ @Spills										as [Spills_Add]
	into	#tmp1
	from	##tmp0

-- ********** Step 5: Блок отбора ********** --
-- 5.1. Формируем флаги отбора по каждой строке на основании прараметров отбора

drop table if exists #tmp2
create table #tmp2
					([RowNumber]	[bigint]
					,[Hash#]		[bigint]
					,[C]			[bit]
					,[D]			[bit]
					,[P]			[bit]
					,[L]			[bit]
					,[W]			[bit]
					,[S]			[bit]
					,[C%]			[bit]
					,[D%]			[bit]
					,[P%]			[bit]
					,[L%]			[bit]
					,[W%]			[bit]
					,[S%]			[bit]
					,[C%A]			[bit]
					,[D%A]			[bit]
					,[P%A]			[bit]
					,[L%A]			[bit]
					,[W%A]			[bit]
					,[S%A]			[bit]
					)

insert into #tmp2
	select	 [RowNumber]	[bigint]
			,[Hash#]		[bigint]
			,case when [CPU_Rank]				<= @Records 
						then 'TRUE' else 'FALSE' end			as [C]
			,case when [Duration_Rank]			<= @Records 
						then 'TRUE' else 'FALSE' end			as [D]
			,case when [Reads_physical_Rank]	<= @Records 
						then 'TRUE' else 'FALSE' end			as [P]
			,case when [Reads_logical_Rank]		<= @Records 
						then 'TRUE' else 'FALSE' end			as [L]
			,case when [Writes_Rank]			<= @Records 
						then 'TRUE' else 'FALSE' end			as [W]
			,case when [Spills_Rank]			<= @Records 
						then 'TRUE' else 'FALSE' end			as [S]

			,case when [CPU_Pct]				>  @Percent 
						then 'TRUE' else 'FALSE' end			as [C%]
			,case when [Duration_Pct]			>  @Percent 
						then 'TRUE' else 'FALSE' end			as [D%]
			,case when [Reads_physical_Pct]		>  @Percent 
						then 'TRUE' else 'FALSE' end			as [P%]
			,case when [Reads_logical_Pct]		>  @Percent 
						then 'TRUE' else 'FALSE' end			as [L%]
			,case when [Writes_Pct]				>  @Percent 
						then 'TRUE' else 'FALSE' end			as [W%]
			,case when [Spills_Pct]				>  @Percent 
						then 'TRUE' else 'FALSE' end			as [S%]

			,case when [CPU_Add]				<= @AddSum 
						then 'TRUE' else 'FALSE' end			as [C%A]
			,case when [Duration_Add]			<= @AddSum 
						then 'TRUE' else 'FALSE' end			as [D%A]
			,case when [Reads_physical_Add]		<= @AddSum 
						then 'TRUE' else 'FALSE' end			as [P%A]
			,case when [Reads_logical_Add]		<= @AddSum 
						then 'TRUE' else 'FALSE' end			as [L%A]
			,case when [Writes_Add]				<= @AddSum 
						then 'TRUE' else 'FALSE' end			as [W%A]
			,case when [Spills_Add]				<= @AddSum 
						then 'TRUE' else 'FALSE' end			as [S%A]
	from #tmp1

-- 5.2. Формируем список номеров хешей для отобранных строк

drop table if exists #tmp3
select distinct	[Hash#]
	into #tmp3
	from #tmp2
	where	[C] | [C%] | [C%A] | [D] | [D%] | [D%A] | 
			[P] | [P%] | [P%A] | [L] | [L%] | [L%A] |
			[W] | [W%] | [W%A] | [S] | [S%] | [S%A] = 'TRUE'

if @Only = 'FALSE'
begin -- Блок записи данных в XE_Top

-- ********** Step 6. Запись данных в журнал Top_Log  **********

-- 6.1 Удаляем архивные записи

	execute [dbo].[XE_ExecLog]	 @Proc		= '[dbo].[XE_Clear]', @Caller	= @Version
								,@Session	= @Session
								,@Table		= '[dbo].[XE_Top]'
								,@Option	= @Option
								

-- 6.2 Удаление данных за указанное число от указанной сессии
--		для исключения возможного дублирования данных

	Delete from [dbo].[XE_Top] 
					where [Date]	= @Date
					  and [Session#]	= @Session#;

-- 6.3 Запись суммарных данных за день в таблицу [dbo].[XE_Sum]

	insert into [dbo].[XE_Top]
				(
				 [RowNumber]
				,[Date]
				,[CPU]
				,[Duration]
				,[Page_server_reads]
				,[Reads_physical]
				,[Reads_logical]
				,[Writes]
				,[Spills]
				,[Row_count]
				,[Hash#]
				,[Session#]
				,[Host#]
				,[Database#]
				,[User#]
				,[Application#]
				,[Event#]
				,[Result#]
				,[Output#]
				,[Is_System]
				,[Session_id]
				,[Client_pid]
				,[Event_sequence]
				,[DateTime_Start]
				,[DateTime_Stop]
				,[C],   [D],   [P],   [L],   [W],   [S]
				,[C%],	[D%],  [P%],  [L%],  [W%],  [S%]
				,[C%A], [D%A], [P%A], [L%A], [W%A], [S%A]
				)
	select		 [x].[RowNumber]
				,[Date]
				,[CPU]
				,[Duration]
				,[Page_server_reads]
				,[Reads_physical]
				,[Reads_logical]
				,[Writes]
				,[Spills]
				,[Row_count]
				,[x].[Hash#]
				,[Session#]
				,[Host#]
				,[Database#]
				,[User#]
				,[Application#]
				,[Event#]
				,[Result#]
				,[Output#]
				,[Is_System]
				,[Session_id]
				,[Client_pid]
				,[Event_sequence]
				,[DateTime_Start]
				,[DateTime_Stop]
				,[s].[C],   [s].[D],   [s].[P],   [s].[L],   [s].[W],   [s].[S]
				,[s].[C%],  [s].[D%],  [s].[P%],  [s].[L%],  [s].[W%]  ,[s].[S%]
				,[s].[C%A], [s].[D%A], [s].[P%A], [s].[L%A], [s].[W%A], [s].[S%A]
		from #tmp3 as [h]
		left join  ##tmp0	as [x] on [x].[Hash#]	= [h].[Hash#]
		left join #tmp2		as [s] on [s].[RowNumber]	= [x].[RowNumber]

end -- Запись данных в XE_Top

if @List = 'FALSE'  
	begin	-- no list
		Drop table if exists ##tmp0
		return
	end	-- no List	

-- ********** Step 7: Информация об отборе **********

Select	 coalesce(@Session,'') +' : ' + format(@Date,'D','en-gb')				as [Parameter] 
		,format(@Records,	'N0', 'ru-RU')										as [Records]
		,format(@Percent,	'N6', 'ru-RU') + N'%'								as [Percent]
		,format(@AddSum,	'N6', 'ru-RU') + N'%'								as [AddSum]
		,''																		as [All criteria]
union all
Select	 replicate('—',10)														as [Parameter] 
		,replicate('—',10)														as [Records]
		,replicate('—',10)														as [Percent]
		,replicate('—',10)														as [AddSum]
		,replicate('—',10)														as [All criteria]
union all
Select	 'CPU' as [Parameter] 
		,format(sum(case when [C]   = 'True' then 1 else 0 end),'N0','ru-RU')	as [Records]
		,format(sum(case when [C%]  = 'True' then 1 else 0 end),'N0','ru-RU')	as [Percent]
		,format(sum(case when [C%A] = 'True' then 1 else 0 end),'N0','ru-RU')	as [AddSum]
		,format(sum(case when [C] | [C%] | [C%A] = 'True'
											 then 1 else 0 end),'N0','ru-RU')	as [All criteria]
		from #tmp3 as [h]
		left join  ##tmp0	as [x] on [x].[Hash#]		= [h].[Hash#]
		left join #tmp2		as [s] on [s].[RowNumber]	= [x].[RowNumber]
union all							
Select	 'Duration' as [Parameter] 
		,format(sum(case when [D]   = 'True' then 1 else 0 end),'N0','ru-RU')	as [Records]
		,format(sum(case when [D%]  = 'True' then 1 else 0 end),'N0','ru-RU')	as [Percent]
		,format(sum(case when [D%A] = 'True' then 1 else 0 end),'N0','ru-RU')	as [AddSum]
		,format(sum(case when [D] | [D%] | [D%A] ='True' 
											then 1 else 0 end),'N0','ru-RU')	as [All criteria]
		from #tmp3	as [h]
		left join	##tmp0	as [x] on [x].[Hash#]		= [h].[Hash#]
		left join	#tmp2	as [s] on [s].[RowNumber]	= [x].[RowNumber]
union all
Select	 'Physical Reads' as [Parameter] 
		,format(sum(case when [P]   = 'True' then 1 else 0 end),'N0','ru-RU')	as [Records]
		,format(sum(case when [P%]  = 'True' then 1 else 0 end),'N0','ru-RU')	as [Percent]
		,format(sum(case when [P%A] = 'True' then 1 else 0 end),'N0','ru-RU')	as [AddSum]
		,format(sum(case when [P] | [P%] | [P%A] = 'True'
											 then 1 else 0 end),'N0','ru-RU')	as [All criteria]
		from #tmp3 as [h]
		left join  ##tmp0	as [x] on [x].[Hash#]		= [h].[Hash#]
		left join #tmp2		as [s] on [s].[RowNumber]	= [x].[RowNumber]
union all
Select	 'Logical Reads' as [Parameter] 
		,format(sum(case when [L]   = 'True' then 1 else 0 end),'N0','ru-RU')	as [Records]
		,format(sum(case when [L%]  = 'True' then 1 else 0 end),'N0','ru-RU')	as [Percent]
		,format(sum(case when [L%A] = 'True' then 1 else 0 end),'N0','ru-RU')	as [AddSum]
		,format(sum(case when [L] | [L%] | [L%A] = 'True' 
											 then 1 else 0 end),'N0','ru-RU')	as [All criteria]
		from #tmp3 as [h]
		left join  ##tmp0	as [x] on [x].[Hash#]		= [h].[Hash#]
		left join #tmp2		as [s] on [s].[RowNumber]	= [x].[RowNumber]
union all
Select	 'Writes' as [Parameter] 
		,format(sum(case when [W]   = 'True' then 1 else 0 end),'N0','ru-RU')	as [Records]
		,format(sum(case when [W%]  = 'True' then 1 else 0 end),'N0','ru-RU')	as [Percent]
		,format(sum(case when [W%A] = 'True' then 1 else 0 end),'N0','ru-RU')	as [AddSum]
		,format(sum(case when [W] | [W%] | [W%A] = 'True'
											 then 1 else 0 end),'N0','ru-RU')	as [All criteria]
		from #tmp3 as [h]
		left join  ##tmp0	as [x] on [x].[Hash#]		= [h].[Hash#]
		left join #tmp2		as [s] on [s].[RowNumber]	= [x].[RowNumber]
union all
Select	 'Splits' as [Parameter] 
		,format(sum(case when [S]   = 'True' then 1 else 0 end),'N0','ru-RU')	as [Records]
		,format(sum(case when [S%]  = 'True' then 1 else 0 end),'N0','ru-RU')	as [Percent]
		,format(sum(case when [S%A] = 'True' then 1 else 0 end),'N0','ru-RU')	as [AddSum]
		,format(sum(case when [S] | [S%] | [S%A] = 'True'
											 then 1 else 0 end),'N0','ru-RU')	as [All criteria]
		from #tmp3 as [h]
		left join  ##tmp0	as [x] on [x].[Hash#]		= [h].[Hash#]
		left join #tmp2		as [s] on [s].[RowNumber]	= [x].[RowNumber]
union all
Select	 replicate('═',10)														as [Parameter] 
		,replicate('═',10)														as [Records]
		,replicate('═',10)														as [Percent]
		,replicate('═',10)														as [AddSum]
		,replicate('═',10)														as [All criteria]
union all
Select	 'Total'		as [Parameter] 
		,format(sum(case when   [C] | [D] | [P] | [L] | [W] | [S] = 'True' 
									then 1 else 0 end),'N0','ru-RU')			as [Records]
		,format(sum(case when   [C%] | [D%] | [P%] | [L%] | [W%] | [S%] = 'True' 
										then 1 else 0 end),'N0','ru-RU')		as [Percent]
		,format(sum(case when   [C%A] | [D%A] | [P%A] | [L%A] | [W%A] | [S%A] = 'True' 
										then 1 else 0 end),'N0','ru-RU')		as [AddSum]
		,format(sum(case when   [C] | [C%] | [C%A] | [D] | [D%] | [D%A] | 
								[P] | [P%] | [P%A] | [L] | [L%] | [L%A] |  
								[W] | [W%] | [W%A] | [S] | [S%] | [S%A] = 'True'  
										then 1 else 0 end),'N0','ru-RU')		as [All criteria]
	from #tmp3 as [h]
		left join  ##tmp0	as [x] on [x].[Hash#]		= [h].[Hash#]
		left join #tmp2		as [s] on [s].[RowNumber]	= [x].[RowNumber]
union all
Select	 'All by Hash'															as [Parameter] 
		,''																		as [Records]
		,''																		as [Percent]
		,''																		as [AddSum]
		,format(COUNT(1), 'N0', 'ru-RU')											as [All criteria]
		from #tmp3 as [h]
		left join  ##tmp0	as [x] on [x].[Hash#]		= [h].[Hash#]
		left join #tmp2		as [s] on [s].[RowNumber]	= [x].[RowNumber]


-- ********** Step 8. Очистка после выполнения ********** --

Drop table if exists ##tmp0

	END	-- PROCEDURE [dbo].[XE_Day]