/* =============================================
	Author:			Sotivoli
	Date:			13 October 2024
	Description:	Проверка и корректировка параметра @Table
					по значению @Session и справочнику XEd_Set
-- =============================================
declare  @Action		as nvarchar(256)	= 'Session Table Source OrdersProc Records Object Offset'
		,@Session		as nvarchar(128)	= null --'alidi'	
		,@Table			as nvarchar(128)	= null
		,@Source		as nvarchar(max)	= null
		,@OrdersProc	as nvarchar(128)	= null
		,@Records		as int				= null
		,@Percent		as numeric(13,6)	= null 
		,@AddSum		as numeric(13,6)	= null 
		,@Session#		as int				= null
		,@Object		as nvarchar(128)	= null --'xe_sql251'

		,@Parameter		as nvarchar(128)	= 'XEL'	-- для Offset
		,@Offset		as int				= null 

exec [dbo].[XE_CheckParams]  @Session= @Session output ,@Table=@Table output,@Source=@Source output, @OrdersProc=@OrdersProc output, @Records=@Records output,@Percent=@Percent output,@AddSum=@AddSum output, @Session#=@Session# output, @Object=@Object output, @Offset=@Offset output, @Action=@Action,@Parameter=@Parameter
select   @Session as [Session], @Table as [Table], @Source as [Source], @OrdersProc as [OrdersProc]
		,@Records as [Records], @Percent	as [Percent], @AddSum as [AddSum], @Session# as[Session#], @Object as [Object], @Parameter as [Parameter], @Offset as [Offset]
--select * from [dbo].[XEd_Set]   where upper([Parameter]) = upper('records')
--order by [Session] desc, [Object] desc, [Value] desc
=============================================== */

	drop procedure if exists	[dbo].[XE_CheckParams]
GO
	CREATE PROCEDURE			[dbo].[XE_CheckParams]
 @Action		as nvarchar(256)	= null			-- 'Session Table Source OrdersProc Records Object Offset'
,@Parameter		as nvarchar(128)	= null			-- для Offset
,@Session		as nvarchar(128)	= null output
,@Table			as nvarchar(128)	= null output
,@Source		as nvarchar(max)	= null output
,@OrdersProc	as nvarchar(128)	= null output
,@Records		as int				= null output
,@Percent		as numeric(13,6)	= null output
,@AddSum		as numeric(13,6)	= null output
,@Session#		as int				= null output
,@Object		as nvarchar(128)	= null output
,@Offset		as int				= null output
	AS BEGIN	-- [dbo].[XE_CheckParams]

Declare @Version as nvarchar(30)	= N'XE_CheckParams v 5.1'

-- ********** Step 1. Уточнение @Session и @Session# **********

if upper(' ' + @Action + ' ') like N'% ' + upper('Session') + N' %'	
begin -- @Session 

	If ltrim(rtrim(@Session)) = '' set @Session = null	

	If @Session is not null 
			set @Session = upper(ltrim(rtrim(@Session)))
  		else
			select top(1) @Session = upper(ltrim(rtrim([Session])))
				from [dbo].[XEd_Set] 
				where ltrim(rtrim(upper([Parameter]))) = upper(N'Session')
				order by [Session] desc

-- Уточнение @Session#

	if @Session# is null
		select top(1) @Session# = [Session#]
			from  [dbo].[XEd_Session]
			where upper(ltrim(rtrim([Session]))) = @Session

end	-- @Session

-- ********** Step 2. Уточнение @Table **********

if upper(' ' + @Action + ' ') like N'% ' + upper('Table') + N' %'	
begin -- @Table 

	If ltrim(rtrim(@Table )) = '' set @Table = null

	If @Table is null 
		select top(1) @Table = coalesce(ltrim(rtrim([Object])), N'[dbo].[XE_xel]')
			from [dbo].[XEd_Set] 
			where ltrim(rtrim(upper([Parameter])))	= upper(N'Xel')
			  and (		ltrim(rtrim(upper([Session])))			= @Session
					or	ltrim(rtrim(coalesce([Session], '')))	= '')
			order by [Session] desc 
		else set @Table = ltrim(rtrim(@Table))

	set @Table = case when coalesce(parsename(@Table,3), '') = ''
					then ''
					else quotename(PARSENAME(@Table,3)) + '.'
					end

				+ quotename(coalesce(parsename(@Table,2), 'dbo')) + '.'
	-- для таблиц типа XE_...  имя таблицы всегда в верхнем регистре во избежании путаницы

				+ quotename(
					case when left(upper(parsename(@Table, 1)), 3) = upper(N'XE_')
						then upper('XE_') + upper(right(parsename(@Table, 1), LEN(parsename(@Table, 1))-3))
						else upper('XE_') + upper(parsename(@Table,1))
						end
							)

end	-- @Table

-- ********** Step 3. Уточнение @Source **********

if upper(' ' + @Action + ' ') like N'% ' + upper('Source') + N' %'	
begin -- @Source 

	if @Source is null 
		select top(1) @Source = ltrim(rtrim([Object]))
			from [dbo].[XEd_Set] 
			where upper(ltrim(rtrim([Parameter])))		= upper(N'Source')
			  and ltrim(rtrim(coalesce([Object], '')))	<> ''
			  and (		upper(ltrim(rtrim([Session])))			= @Session
					or	ltrim(rtrim(coalesce([Session], '')))	= '')
			order by [Session] desc 

end	-- @Source

-- ********** Step 4. Уточнение @OrdersProc **********

if upper(' ' + @Action + ' ') like N'% ' + upper('OrdersProc') + N' %'	
begin -- @OrdersProc 

	if @OrdersProc is null
		select top(1) @OrdersProc = ltrim(rtrim([Object]))
			from [dbo].[XEd_Set] 
			where ltrim(rtrim(upper([Parameter])))		= upper(N'OrdersProc')
			  and ltrim(rtrim(coalesce([Object], '')))	<> ''
			  and (		upper(ltrim(rtrim([Session])))			= @Session 
					or	ltrim(rtrim(coalesce([Session], '')))	<> '')
			order by [Session] desc 

end	-- @OrdersProc

-- ********** Step 5. Уточнение @Records, @Percent, @AddSum **********

if upper(' ' + @Action + ' ') like N'% ' + upper('Records') + N' %'	
begin -- @Records 

	if @Records is null
		select top (1) @Records = [Value] -- @Object as [@Object], @Session as [@Session], * 
			from [dbo].[XEd_Set]
			where	upper(ltrim(rtrim([Parameter])))= upper('Records')
			  and	(
						upper(ltrim(rtrim([Session]))) = @Session
					 or ltrim(rtrim(coalesce([Session], ''))) = ''
					)
			and		(
					 (
						 upper(parsename([Object], 1)) = upper(parsename(@Object, 1))
					 and upper(coalesce(parsename([Object], 2), DB_NAME())) = upper(coalesce(parsename(@Object, 2), DB_NAME()))
					 and upper(coalesce(parsename([Object], 3), SCHEMA_NAME())) = upper(coalesce(parsename(@Object, 3), schema_name()))
					 ) or ltrim(rtrim(coalesce([Object], ''))) = ''
					)
	
			order by [Session] desc, [Object] desc, [Value] desc

	if @Percent is null
		select top (1) @Percent = [Value] -- @Object as [@Object], @Session as [@Session], * 
			from [dbo].[XEd_Set]
			where	upper(ltrim(rtrim([Parameter])))= upper('Percent')
			  and	(
						upper(ltrim(rtrim([Session]))) = @Session
					 or ltrim(rtrim(coalesce([Session], ''))) = ''
					)
			and		(
					 (
						 upper(parsename([Object], 1)) = upper(parsename(@Object, 1))
					 and upper(coalesce(parsename([Object], 2), DB_NAME())) = upper(coalesce(parsename(@Object, 2), DB_NAME()))
					 and upper(coalesce(parsename([Object], 3), SCHEMA_NAME())) = upper(coalesce(parsename(@Object, 3), schema_name()))
					 ) or ltrim(rtrim(coalesce([Object], ''))) = ''
					)

	if @AddSum is null
		select top (1) @AddSum = [Value] -- @Object as [@Object], @Session as [@Session], * 
			from [dbo].[XEd_Set]
			where	upper(ltrim(rtrim([Parameter])))= upper('AddSum')
			  and	(
						upper(ltrim(rtrim([Session]))) = @Session
					 or ltrim(rtrim(coalesce([Session], ''))) = ''
					)
			and		(
					 (
						 upper(parsename([Object], 1)) = upper(parsename(@Object, 1))
					 and upper(coalesce(parsename([Object], 2), DB_NAME())) = upper(coalesce(parsename(@Object, 2), DB_NAME()))
					 and upper(coalesce(parsename([Object], 3), SCHEMA_NAME())) = upper(coalesce(parsename(@Object, 3), schema_name()))
					 ) or ltrim(rtrim(coalesce([Object], ''))) = ''
					)

end	-- @Records

-- ********** Step 6. Уточнение @Object **********

if upper(' ' + @Action + ' ') like N'% ' + upper('Object') + N' %'	
begin -- @Object 

	set @Object = case when PARSENAME(@Object, 3) is null
							then ''
							else QUOTENAME(parsename(@Object, 3)) + '.'
							end
				+ quotename(coalesce(PARSENAME(@Object, 2), schema_name())) + '.'
				+ case when UPPER(left(parsename(@Object, 1), 3)) =  upper('XE_')
						and UPPER(left(parsename(@Object, 1), 3)) <> upper('XE_Sum')
						and UPPER(left(parsename(@Object, 1), 3)) <> upper('XE_Top')
						then quotename(UPPER(parsename(@Object, 1)))
						else quotename(parsename(@Object, 1))
						end

end	-- @Object

-- ********** Step 7. Уточнение @Offset (Считывание из XEd_Set) **********

if upper(' ' + @Action + ' ') like N'% ' + upper('Offset') + N' %'	
begin -- @Offset 

Select @Parameter = 
	case	
		when parsename(upper(@Table) ,1) like upper(N'XEd_%') 
			then right(parsename(@Table ,1), len(parsename(@Table,1))-4)
		else upper(N'Xel')
		end

	-- Считывание @Offset из XEd_Set

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
			where [Parameter]								 = upper(N'Offset')
			and (	upper(ltrim(rtrim([Session])))			= @Session
				 or ltrim(rtrim(coalesce([Session], '')))	= ''
				)
			and (	upper(parsename([Object],1)) = parsename(@Table,1) 
				 or ltrim(rtrim(coalesce([Object], '')))	= '' 
				)	
			) as [q] 
		order by [Object] desc, [Session] desc
		)

end	-- @Offset

	END	-- [dbo].[XE_CheckParams]