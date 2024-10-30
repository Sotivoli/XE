/* =============================================
-- Author:		Sotivoli
-- Create date: 27 September 2024
-- Description:	Удаление архивных данных из таблицы
-- =============================================
exec [dbo].[XE_Clear] 
		 @Option	= 'list only'
		,@Table		= '[dbo].[XE_sql251]'
		,@Session	= 'sotivoli'

select * from [dbo].[XEd_Set] order by [Object] desc, [Session] desc
-- ============================================= */
--	Declare
	drop procedure if exists	[dbo].[XE_Clear]
GO
	CREATE	PROCEDURE			[dbo].[XE_Clear]
			 @Option	as nvarchar(256)	= null		-- 'Skip' -- Не удалть архивные данные
			,@Table		as nvarchar(128)	= null
			,@Session	as nvarchar(128)	= null
	AS BEGIN
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

-- ********** Step 0: Проверка корректности параметров ********** --
-- 0.1 Инициализация

Declare	 @Version	as nvarchar(25) = N'XE_Clear v 5.0'
		,@Offset	as int
		,@Cmd		as nvarchar(max)
		,@Parameter as nvarchar(128)
		,@Utable    as nvarchar(128)
		,@List		as bit = 'False'	-- Вывод информации без выполнения команды
		,@Only		as bit = 'False'	-- Вывод итоговой информации с выполенением команды

set @Utable = @Table

exec [dbo].[XE_CheckParams]  @Session	= @Session	output
							,@Table		= @Utable	output

If upper(' ' + @Option + ' ')	like upper(N'% ' + N'List' + ' %')	Set @List	= 'True'
If upper(' ' + @Option + ' ')	like upper(N'% ' + N'Only' + N' %')	Set @Only	= 'True'

-- ********** Step 1 Определяем по имени таблицы имя поля параметра в XEd_Set
-- для таблиц типа XED_name берем name справочника , в противном случае XEL (таблицы XE)

Select @Parameter = 
	case	
		when parsename(@Utable,1) like N'XED_%' 
			then right(parsename(@Utable,1), len(parsename(@Utable,1))-4)
		else N'XEL'
		end

-- ********** Step 2: Считывание @Offset из XEd_Set

set @Offset =
(Select top(1) [Value] from (
	select	 ltrim(rtrim(upper([Session])))		as [Session]
			,ltrim(rtrim(upper([Parameter])))	as [Parameter]
			,ltrim(rtrim(upper([Object])))		as [Object]
			,[Value]							as [Value]
		from [dbo].[XEd_Set]
		where upper(ltrim(rtrim([Parameter])))				= @Parameter
		  and	(	upper(ltrim(rtrim([Session])))			= @Session
				 or	ltrim(rtrim(coalesce([Session], '')))	= ''
				)
	union all
	 select	 ltrim(rtrim(upper([Session])))		as [Session]
			,ltrim(rtrim(upper([Parameter])))	as [Parameter]
			,ltrim(rtrim(upper([Object])))		as [Object]
			,[Value]							as [Value]
		from [dbo].[XEd_Set]
		where [Parameter]								 = N'OFFSET'
		and (	upper(ltrim(rtrim([Session])))			= @Session
			 or ltrim(rtrim(coalesce([Session], '')))	= ''
			)
		and (	upper(parsename([Object],1)) = parsename(@Table,1) 
			 or ltrim(rtrim(coalesce([Object], '')))	= '' 
			)	
	) as [q] 
	order by [Object] desc, [Session] desc
	)

if @Parameter = N'XEL' set @Table = @Utable

set @Table =     N'[' + coalesce(parsename(@Table, 2), N'dbo') 
						+ N'].[' + parsename(@Table,1) + N']'

if object_id(@Table, N'U') is null return

if @Offset > 0 Set @Cmd =	 N'Delete from	' + @Table + N' '
							+N'where [Date]	< ' 
							+ '''' 
							+ format	(dateadd(day, -@Offset, getdate())
										,'d'
										,'en-US'
										) 
							+ ''''

-- ********** Step 3: Обработка параметров List и / или Info
 if @List = 'True' 
	begin	-- Info
		Print	 N'*** ' + left(@Version + replicate(N' ', 25), 25) + ': Параметры выполнения'
		+nchar(13) +N'***           @Offset = '	+ coalesce(cast(@Offset as nvarchar(10)), '<null>')
		+nchar(13) +N'***           @Session = '	+ coalesce(@Session, '<null>')
		+nchar(13) +N'***            @Table = '	+ coalesce(@Table, '<null>')
		+nchar(13) +N'***           @Option = '	+ coalesce(@Option, '<null>')
		+nchar(13) +N'***        @Parameter = '	+ coalesce(@Parameter, '<null>')
		+nchar(13) +N'***              @Cmd = '	+ coalesce(@Cmd, '<null>')
	end		-- Info

-- ********** Step 4: Собственно очистка таблицы от архиавных данных

if @Only = 'False' and @Offset > 0 
	Execute sp_executesql @Cmd 

	END --  [dbo].[XE_Clear]