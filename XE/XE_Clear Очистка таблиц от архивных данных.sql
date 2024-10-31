/* =============================================
-- Author:		Sotivoli
-- Create date: 27 September 2024
-- Description:	�������� �������� ������ �� �������
-- =============================================
exec [dbo].[XE_Clear] 
		 @Option	= 'list only'
		,@Table		= null	'[dbo].[XE_sql251]'
		,@Session	= null	-- 'sotivoli'

select * from [dbo].[XEd_Set] order by [Object] desc, [Session] desc
-- ============================================= */
--	Declare
	drop procedure if exists	[dbo].[XE_Clear]
GO
	CREATE PROCEDURE [dbo].[XE_Clear]
			 @Option	as nvarchar(256)	= null		-- 'Skip' -- �� ������ �������� ������
			,@Table		as nvarchar(128)	= null
			,@Session	as nvarchar(128)	= null
	AS BEGIN
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

-- ********** Step 0: �������� ������������ ���������� ********** --
-- 0.1 �������������

Declare	 @Version	as nvarchar(25) = N'XE_Clear v 5.1'
		,@Offset	as int
		,@Cmd		as nvarchar(max)

		,@List		as bit = 'False'	-- ����� ���������� ��� ���������� �������
		,@Only		as bit = 'False'	-- ����� �������� ���������� � ������������ �������

If upper(' ' + @Option + ' ')	like upper(N'% ' + N'List' + ' %')	Set @List	= 'True'
If upper(' ' + @Option + ' ')	like upper(N'% ' + N'Only' + N' %')	Set @Only	= 'True'

-- ********** Step 1 ��������� ����������

exec [dbo].[XE_CheckParams]  @Action    = 'Session Table Offset'
							,@Session	= @Session	output
							,@Table		= @Table	output
							,@Offset	= @Offset   output

-- ********** Step 3: ��������� ��������� List 

 if @List = 'True' 
	exec  XE_PrintParam	 @Caller	= @Version
						,@Option	= @Option
						,@Table		= @Table
						,@Session	= @Session
						,@Offset	= @Offset

-- ********** Step 4: ���������� ������� ������� �� ��������� ������

if object_id(@Table, N'U') is null	-- ��������� ������� �����������
or @Offset <= 0						-- ��� ����� ���������� ������ ���������������
or @Offset is null					-- ��� ����� ���������� �� �������
or @Only = 'True'					-- ��� ������ ����� �� ��������� ��������
	return

Set @Cmd =	 N'Delete from ' + @Table 
			+N' where [Date] < ' 
			+'''' + format(dateadd(day, -@Offset, getdate()) ,'d' ,'en-US') + ''''
Execute sp_executesql @Cmd 

	END --  [dbo].[XE_Clear]