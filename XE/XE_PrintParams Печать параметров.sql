/* =============================================
	Author:			Sotivoli
	Date:			31 October 2024
	Description:	������ ����������
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
		,@Steps			= 'XEl Set '	-- �������� ����������� �����, �� ��������� - ��� ���� 
		,@Offset		= 3650
		,@Start			= '2044-01-01'	-- ������ �������
		,@Stop			= '2024-09-08'	-- ��������� �������
		,@Date			= '2024-12-31'	
		,@Uncertainty	= 180			-- ���������������� ������ �������,������
		,@Comm			= '����������� � ���������'	-- ����������� � ������
		,@Error			= 28
		,@Cmd			= 'Select * from XEd_Set'
		,@Count			= 18345
		,@Max_Time		= '2024-05-01'
=============================================== */

	drop procedure if exists	[dbo].[XE_PrintParams]
GO
	CREATE PROCEDURE			[dbo].[XE_PrintParams]
 @Caller		nvarchar(128)		= null -- ��� ��������
,@Session		as nvarchar(128)	= null 
,@Table			as nvarchar(128)	= null 
,@Source		as nvarchar(max)	= null 
,@OrdersProc	as nvarchar(128)	= null 
,@Records		as int				= null 
,@Percent		as numeric(13,6)	= null 
,@AddSum		as numeric(13,6)	= null 
,@Session#		as int				= null 
,@Object		as nvarchar(128)	= null
,@Start			as date				= null		-- ������ �������
,@Stop			as date				= null		-- ��������� �������
,@Action		nvarchar(20)		= null	-- ��������
,@Uncertainty	as int				= null	-- ���������������� ������ �������,������
,@Date			as date				= null
,@Steps			nvarchar(max)		= null	-- �������� ����������� �����, �� ��������� - ��� ���� 
,@Comm			nvarchar(256)		= null -- '����������� � ���������'	-- ����������� � ������
,@Offset		int					= null
,@Error			int					= null
,@Option		as nvarchar(256)	= null
,@Cmd			as nvarchar(max)	= null
,@Parameter		as nvarchar(128)	= null
,@Count			bigint				= null
,@Max_Time		as datetime2(7)		= null


,@Prefix		as nvarchar(10)		= N'***   '	-- ������� ���� ��������� �����
,@S				as nvarchar(16)		= N'      '	-- ����� ��� ����������
,@L				as int				= 50		-- ������ ����� �����
,@R				as int				= 80		-- ������ ������ �����
	AS BEGIN	-- [dbo].[XE_PrintParams]

-- ********** Step 0: ������������� **********

Declare  @Version	as nvarchar(30)	= N'XE_PrintParams v 5.1'	
		,@F			as nvarchar(80)								-- ������ ��� ������������ (����������) 

Set		 @F	= replicate(' ', @R + @L)	

-- ********** Step 1: ������ ��������� **********

print replicate('*', len(@Prefix) + @L + @R)
print @Prefix + @S + left(coalesce(@Caller, '') +':    ��������� ������ ��������� ', @L + @R)
print replicate('*', len(@Prefix) + @L + @R)

-- ********** Step 2: ������� ��������� **********

if @Session is not null or @Session# is not null or @Steps is not null begin -- mail
	if @Session is not null	print
		@Prefix + right(@F + N'������ XE    (@Session) = '	,@L) + @Session
	if @Session# is not null print
		@Prefix + right(@F + N'ID ������ XE (@Session#) = '	,@L) + cast(@Session# as nvarchar(10))
	if @Steps is not null print
		@Prefix + right(@F + N'����������� ���� ��������� (@Steps) = '	,@L) + N'"' + upper(ltrim(rtrim(@Steps))) + N'"'
	print @Prefix
end -- main

-- ********** Step 3: ��������� ������ **********

if @Source is not null or @Table is not null or @Offset is not null begin -- source
	if @Source is not null	print
		@Prefix + right(@F + N'�������� ������ (@Source) = '			,@L) + @Source
	if @Table is not null print
		@Prefix + right(@F + N'������� ������ ������ XE (@Table) = '	,@L) + @Table
	if @Offset is not null print
		@Prefix + right(@F + N'���� �������� ������ (@Offset) = '	,@L) + cast(@Offset as nvarchar(10))
	print @Prefix
end -- source 

-- ********** Step 4: ��������� ������ **********

if @Records is not null or @Percent is not null  or @AddSum is not null begin -- selection
	if @Records is not null	print
		@Prefix + right(@F + N'����� Top ������� (@Records) = '			,@L) + cast(@Records as nvarchar(10)) + ' �������'
	if @Percent is not null print
		@Prefix + right(@F + N'������� �� ������ ������� (@Percent) = '	,@L) + cast(@Percent as nvarchar(10)) + ' %'
	if @AddSum is not null print
		@Prefix + right(@F + N'������������� ������� ������� (@AddSum) = '	,@L) + cast(@AddSum as nvarchar(10)) + ' %%'
	print @Prefix 
end -- selection

-- ********** Step 5: ��������� ��������� ������ ������ **********

if @Start is not null or @Stop is not null  or @Date is not null or @Uncertainty is not null or @Max_Time is not null begin -- date
	if @Start is not null	print
		@Prefix + right(@F + N'������ ������� ����� ������ (@Start) = '			,@L) + format(@Start, 'D', 'en-gb')
	if @Stop is not null print
		@Prefix + right(@F + N'��������� ������� ������ ������ (@Stop) = '	,@L) + format(@Stop, 'D', 'en-gb') 
	if @Date is not null print
		@Prefix + right(@F + N'���� ������ ������ (@Date) = '	,@L) + format(@Date, 'D', 'en-gb')
	if @Max_Time is not null print
		@Prefix + right(@F + N'���� � ����� (@Max_Time) = '	,@L) +  cast(@Max_Time as nvarchar(30))
	if @Uncertainty is not null print
		@Prefix + right(@F + N'���������������� ���� (@Uncertainty) = '	,@L) + cast(@Uncertainty as nvarchar(10)) + ' ������'
	print @Prefix
end -- date

-- ********** Step 6: ������ ��������� **********

if @OrdersProc is not null or @Object is not null begin -- other
	if @OrdersProc is not null	print
		@Prefix + right(@F + N'��������� �������� ���� [Orders] (@OrdersProc)  = ',@L) + @OrdersProc
	if @Object is not null	print
		@Prefix + right(@F + N'��� ������� (@Object)  = '		,@L) + @Object
	print @Prefix
end -- other

-- ********** Step 7: ��������� ��������� ExecLog **********

if @Comm is not null or @Error is not null begin -- @ExecLog
	print replicate('*', len(@Prefix) + @L + @R)
	if @Error is not null print
		@Prefix + right(@F + N'������ ���������� (@Error) = '	,@L) + cast(@Error as nvarchar(10))  
	if @Comm is not null print
		@Prefix + right(@F + N'����������� � ������ (@Comm) = '	,@L) + N'"' + @Comm + '"'
end -- ExecLog

-- ********** Step 8: ��������� ��������� Count **********

if @Count is not null begin -- @Count
	if @Count is not null print
		@Prefix + right(@F + N'����� ����� �������� (@Count) = '	,@L) + cast(@Count as nvarchar(20))  
end -- @Count


-- ********** Step 9: ������ �������� �� @Action  **********

if @Action is not null begin -- @Action
	print replicate('*', len(@Prefix) + @L + @R)
	print @Prefix + @S + right(N'��� �������� (@Action) :', @R)

	if upper(' ' + @Action + ' ') like N'% ' + upper('Profiler')	+ N' %'	print
		@Prefix + right(@F + N'Profiler'	,@L) + left(N': ���������� ������, ��������� Profiler', @R)
	if upper(' ' + @Action + ' ') like N'% ' + upper('XE')			+ N' %'	print
		@Prefix + right(@F + N'XE'			,@L) + left(N': ����������� ������, ��������� ���������� ������� XE', @R) 
end -- @Action


-- ********** Step 10: ������ ������� �� Options **********

if @Option is not null begin -- @Option
	print replicate('*', len(@Prefix) + @L + @R)
	print @Prefix + @S + left(N'������ ��������� (@Option) :', @R)

	if upper(' ' + @Option + ' ') like N'% ' + upper('List')		+ N' %'	print
		@Prefix + right(@F + N'List'		,@L) + left(N': ����������� ����� ����������', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Only')		+ N' %'	print
		@Prefix + right(@F + N'Only'		,@L) + left(N': ������ ����� ���������� ��� ��������� ������', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Create')		+ N' %'	print
		@Prefix + right(@F + N'Create'		,@L) + left(N': ������� ��� ����������� ������ ����� ������ XE', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Compression')	+ N' %'	print
		@Prefix + right(@F + N'Compression'	,@L) + left(N': ��� ����������� ������� ������ ��� ������ XE', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Noclear')		+ N' %'	print
		@Prefix + right(@F + N'NoClear'		,@L) + left(N': �� ������� ���������� ������', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Compact')		+ N' %'	print
		@Prefix + right(@F + N'Compact'		,@L) + left(N': �� ���������� ���������������� ����� �������� (���� Text)', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Skip')		+ N' %'	print
		@Prefix + right(@F + N'Skip'		,@L) + left(N': �� �������� ��������� XEd_Hash (��������� XE_TextData)', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('Replace')		+ N' %'	print
		@Prefix + right(@F + N'Replace'		,@L) + left(N': ��������� ��������� ������ (�� ����)', @R)
	if upper(' ' + @Option + ' ') like N'% ' + upper('NoDB')		+ N' %'	print
		@Prefix + right(@F + N'NoDB'		,@L) + left(N': ��� ���������� �� ���������� ��� �� �� �� id', @R)
end -- @Option

-- ********** Step 11: ��������� ���������� ������� **********

if @Cmd is not null or @Parameter is not null begin -- @ExecLog
	print replicate('*', len(@Prefix) + @L + @R)
	print @Prefix + @S + left(N'��������� ���������� ������������� SQL:', @R)

	if @Parameter is not null print
		@Prefix + right(@F + N'�������� ���������� (@Parameter) = '	,@L) + N'"' + @Parameter + N'"'    
	if @Cmd is not null print
		@Prefix + right(@F + N'����� ����������� ������� (@Cmd) = '	,@L)
	if @Cmd is not null print @Cmd
end -- ExecLog

-- ********** Step 12: ��������� ������� **********

print replicate('*', len(@Prefix) + @L + @R)

	END	-- [dbo].[XE_PrintParams]