/* =============================================
	Author:			Sotivoli
	Date:			13 October 2024
	Description:	Проверка и корректировка параметра @Table
					по значению @Session и справочнику XEd_Set
-- =============================================
declare  @Session		as nvarchar(128)	= null --'alidi'	
		,@Table			as nvarchar(128)	= null
		,@Source		as nvarchar(max)	= null
		,@OrdersProc	as nvarchar(128)	= null
		,@Records		as int				= null
		,@Percent		as numeric(13,6)	= null 
		,@AddSum		as numeric(13,6)	= null 
		,@Session#		as int				= null
		,@Object		as nvarchar(128)	= null --'xe_sql251'
exec [dbo].[XE_CheckParams]  @Session= @Session output ,@Table=@Table output,@Source=@Source output, @OrdersProc=@OrdersProc output, @Records=@Records output,@Percent=@Percent output,@AddSum=@AddSum output, @Session#=@Session# output, @Object=@Object output
select   @Session as [Session], @Table as [Table], @Source as [Source], @OrdersProc as [OrdersProc]
		,@Records as [Records], @Percent	as [Percent], @AddSum as [AddSum], @Session# as[Session#], @Object as [Object]
--select * from [dbo].[XEd_Set]   where upper([Parameter]) = upper('records')
--order by [Session] desc, [Object] desc, [Value] desc
=============================================== */

	drop procedure if exists	[dbo].[XE_CheckParams]
GO
	CREATE PROCEDURE			[dbo].[XE_CheckParams]
 @Session		as nvarchar(128)	= null output
,@Table			as nvarchar(128)	= null output
,@Source		as nvarchar(max)	= null output
,@OrdersProc	as nvarchar(128)	= null output
,@Records		as int				= null output
,@Percent		as numeric(13,6)	= null output
,@AddSum		as numeric(13,6)	= null output
,@Session#		as int				= null output
,@Object		as nvarchar(128)	= null output
	AS BEGIN	-- [dbo].[XE_CheckParams]

Declare @Version as nvarchar(30)	= N'XE_CheckParams v 5.0p'

-- 1. Уточнение @Session

If ltrim(rtrim(@Session)) = '' set @Session = null	

If @Session is not null 
		set @Session = upper(ltrim(rtrim(@Session)))
  	else
		select top(1) @Session = upper(ltrim(rtrim([Session])))
			from [dbo].[XEd_Set] 
			where ltrim(rtrim(upper([Parameter]))) = N'SESSION'
			order by [Session] desc

-- 2. Уточнение @Table

If ltrim(rtrim(@Table )) = '' set @Table = null

If @Table is null 
	select top(1) @Table = coalesce(ltrim(rtrim([Object])), N'[dbo].[XE_xel]')
		from [dbo].[XEd_Set] 
		where ltrim(rtrim(upper([Parameter])))	= N'XEL'
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
				case when left(upper(parsename(@Table, 1)), 3) = N'XE_' 
					then 'XE_' + upper(right(parsename(@Table, 1), LEN(parsename(@Table, 1))-3))
					else 'XE_' + upper(parsename(@Table,1))
					end
						)

-- 3. Уточнение @Source 	

if @Source is null 
	select top(1) @Source = ltrim(rtrim([Object]))
		from [dbo].[XEd_Set] 
		where upper(ltrim(rtrim([Parameter])))		= upper(N'Source')
		  and ltrim(rtrim(coalesce([Object], '')))	<> ''
		  and (		upper(ltrim(rtrim([Session])))			= @Session
				or	ltrim(rtrim(coalesce([Session], '')))	= '')
		order by [Session] desc 
-- 4. Уточнение @OrdersProc

if @OrdersProc is null
	select top(1) @OrdersProc = ltrim(rtrim([Object]))
		from [dbo].[XEd_Set] 
		where ltrim(rtrim(upper([Parameter])))		= N'ORDERSPROC'
		  and ltrim(rtrim(coalesce([Object], '')))	<> ''
		  and (		upper(ltrim(rtrim([Session])))			= @Session 
				or	ltrim(rtrim(coalesce([Session], '')))	<> '')
		order by [Session] desc 

-- 5 @Records

if @Records is null
	select top (1) @Records = [Value] -- @Object as [@Object], @Session as [@Session], * 
		from [dbo].[XEd_Set]
		where	upper(ltrim(rtrim([Parameter])))= 'RECORDS'
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

-- 6. @Percent

if @Percent is null
	select top (1) @Percent = [Value] -- @Object as [@Object], @Session as [@Session], * 
		from [dbo].[XEd_Set]
		where	upper(ltrim(rtrim([Parameter])))= 'PERCENT'
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

-- 7. @AddSum

if @AddSum is null
	select top (1) @AddSum = [Value] -- @Object as [@Object], @Session as [@Session], * 
		from [dbo].[XEd_Set]
		where	upper(ltrim(rtrim([Parameter])))= 'ADDSUM'
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

-- 8. Уточнение @Session#

if @Session# is null
	select top(1) @Session# = [Session#]
		from  [dbo].[XEd_Session]
		where upper(ltrim(rtrim([Session]))) = @Session

-- 9. Object

set @Object = case when PARSENAME(@Object, 3) is null
						then ''
						else QUOTENAME(parsename(@Object, 3)) + '.'
						end
			+ quotename(coalesce(PARSENAME(@Object, 2), schema_name())) + '.'
			+ case when UPPER(left(parsename(@Object, 1), 3)) = 'XE_'
					and UPPER(left(parsename(@Object, 1), 3)) <> 'XE_SUM'
					and UPPER(left(parsename(@Object, 1), 3)) <> 'XE_TOP'
					then quotename(UPPER(parsename(@Object, 1)))
					else quotename(parsename(@Object, 1))
					end

	END	-- [dbo].[XE_CheckParams]