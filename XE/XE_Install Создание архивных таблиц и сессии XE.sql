/* =============================================
-- Author:		Sotivoli
-- Create date: 10 October 2024
-- Description:	�������� �������� ������, ��������, �����������, �������������, ������ XE
-- =============================================
	exec [dbo].[XE_Install] @Option	= 'replace /list /only /session Compression'	-- ����� ����������
		,@Session	= 'sotivoli' -- 'sql251'							-- ������ XE �� ���������
		,@Source	= 'C:\temp\XE_Log_*.xel'	-- 'C:\���������\�������\Alidi\XE data\sql251\XE_Log_*.xel'	-- ����� .xel
		,@OrdersProc= '[dbo].[XE_Count_JDE]'			-- ��������� �� �������� ����� ������� (JDE � ��.)

		 
--		,@Records	=  200		-- ����� ����� ����� �� ��� ����������� ��������
--		,@Percent	=  0.01		-- ����� �� ������� �������, %% �� ������ �� �����
--		,@AddSum	=  50		-- ����� �� ������������ ����� �������, %% �� ������ �� �����
--		,@Offset	=  400		-- ���� �������� ������ � �������� �� ���������
--		,@Table		=  null		-- ��� ������� ��� ������ ������

		,@Steps		=  'Xel'	-- ������ ����������� �����, ���� null (= ��� ����)

-- ============================================= */

--	Declare
	drop procedure if exists	[dbo].[XE_Install]
GO
	CREATE PROCEDURE			[dbo].[XE_Install]
		 @Steps			nvarchar(2048)	= null -- ������ ����������� �����, ���� null (= ��� ����)
		,@Option		nvarchar(256)	= null -- ����� ����������
		,@Table			nvarchar(128)	= null -- ��� ������� ��� ������ ������
		,@Session		nvarchar(128)	= null -- ������ XE �� ���������
		,@Source		nvarchar(2048)	= null -- ������ ����� ������ .xel ���������
		,@Records		int				= null -- ����� ����� ����� �� ��� ����������� ��������
		,@Percent		numeric(9,6)	= null -- ����� �� ������� �������, %% �� ������ �� �����
		,@AddSum		numeric(9,6)	= null -- ����� �� ������������ ����� �������, %% �� ������
		,@Offset		int				= null -- ���� �������� ������ � �������� �� ���������)
		,@OrdersProc	nvarchar(128)	= null -- ��� ��������� ��� �������� @Orders (JDE � ��.)
	AS BEGIN

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

-- ********** Step 0: ������������� � �������� ���������� ********** --

-- 0.1 ����������� ����������

Declare  @Version			as nvarchar(30)		= 'XE_Install v 5.1'
		,@Cmd				as nvarchar(max)
		,@List				as bit				= 'FALSE'
		,@Replace			as bit				= 'FALSE'
		,@Create			as bit				= 'FALSE'
		,@Only				as bit				= 'FALSE'
		,@Compression		as bit				= 'False'
		,@View				as nvarchar(128)	= null
		,@Rows				as int				= 0
		,@Table_default		nvarchar(128)		= N'XE_'	-- ��� ������� ��� ������ ������
		,@Offset_default	int					= 400	-- ���� �������� ������ � ��������
		,@Procedures		nvarchar(max)		
		,@Pos				int
		,@Name				nvarchar(128)
		,@ErrMax			int					= 0		-- ������������ ������ SQL

Set @Session	= ltrim(rtrim(coalesce(@Session	,N'Alidi')))
Set @Source		= ltrim(rtrim(coalesce(@Source	,N'C:\temp\XE_Log_*.xel')))
Set @Records	=			  coalesce(@Records	,200)
Set @Percent	=			  coalesce(@Percent	,0.01)
Set @AddSum		=			  coalesce(@AddSum	,50)
Set @Offset		=			  coalesce(@Offset	,400)
Set @Procedures = ltrim(rtrim(replace(replace(replace(replace('
	XE_Install
	XE_Xel
	XE_TextData
	XE_ExecLog
	XE_TopSum
	XE_Day
	XE_Count_JDE
	XE_Clear
	XE_CheckParams
	XE_PrintParams
	',NCHAR(9), ' '), nchar(10), ' '), nchar(13), ' '), ',', ' ')))

-- 0.2 ���������� ��������� @Steps (���������, �������� ���������) ��� null 

if ltrim(rtrim(@Steps)) = '' set @Steps = null
						else set @Steps = upper(' ' + @Steps + ' ')
-- 0.3	@Option: �������� �� ������� ����������:

if upper(' '+@Option+' ') like N'% ' + upper('LIST')		+ N' %'	Set @List		= 'TRUE'
if upper(' '+@Option+' ') like N'% ' + upper('REPLACE')		+ N' %'	Set @Replace	= 'TRUE'
if upper(' '+@Option+' ') like N'% ' + upper('CREATE')		+ N' %'	Set @Create		= 'TRUE'
if upper(' '+@Option+' ') like N'% ' + upper('ONLY')		+ N' %'	Set @Only		= 'TRUE'
if upper(' '+@Option+' ') like N'% ' + upper('Compression')	+ N' %'	Set @Compression= 'TRUE'

-- 0.4	��������� ��� ������������ XEd_Set: �������� null ���������� �� �������� �� ���������

if ltrim(rtrim(@Table)) = '' set @Table = null


-- 0.5 ���������� ����� ������� XE � ������� [schema].[name], �� ��������� schema = 'dbo'

If ltrim(rtrim(coalesce(@Table, ''))) = ''  or @Table is null
		Set @Table = N'[dbo].[XE_' + coalesce(@Session, N'Xel') + N']'	
	else
		set @Table =	 N'[' + coalesce(parsename(@Table, 2), N'dbo')
						+N'].['
						+ case when parsename(@Table, 1) like N'XE_%'
							 then parsename(@Table, 1)
							 else N'XE_' + parsename(@Table,1)
							 end
						+N']'

-- 0.6 �������� �������� ��������
if @Steps is null 
begin  -- check procedures
	while LEN(@Procedures) > 0
	begin	-- @Procedures

		Set @Pos = CHARINDEX(' ', @Procedures)
		if @Pos > 0 
				begin
					Set @Name = left(@Procedures, @Pos-1)
					Set @Procedures = ltrim(rtrim(right(@Procedures, len(@Procedures) - @Pos)))
				end
			else 
				begin
					Set @Name = @Procedures
					Set @Procedures = '' 
				end
			if object_id(@Name, N'P') is null
				begin -- procedure not exists
					set @Cmd = nchar(0x26a0) + nchar(0x26a0) + nchar(0x26a0) 
							+N'   ' + @Version + ' Error: ����������� �������� ��������� '
							+@Name
							+N', ���������� ��������� ����e���� � ��������� ' + @Version
					RAISERROR(@Cmd, 16, 1)
					return

				end	-- procedure not exists

	end	-- @Procedures
end  -- check procedures

-- 0.7  ������ ������� �������

if @Steps is null or @List = 'TRUE' exec [dbo].[XE_PrintParams]  @Caller		= @Version
																,@Option		= @Option
																,@Steps			= @Steps
																,@Session		= @Session
																,@Table			= @Table
																,@Source		= @Source
																,@Records		= @Records
																,@Percent		= @Percent
																,@AddSum		= @AddSum
																,@Offset		= @Offset

if @Only = 'TRUE' return

-- ********** Step 01 SUM: ������� � ���������� ��������� �� ���� **********

If		(@Steps is null	or @Steps like N'% SUM %')
	and (object_id(N'[dbo].[XE_Sum]', N'U') is null or @Replace = 'TRUE')
begin -- [XE_Sum]

	drop table if exists [dbo].[XE_Sum]
	print N'*** ' + @Version + ': Step 01/17          SUM: �������� �������     [dbo].[XE_Sum]'
	CREATE TABLE [dbo].[XE_Sum] 
		(
		 [Session#]							[bigint]		NULL	-- Session Id
		,[Session]							[nvarchar](128)	NOT NULL-- XE collection Session
		,[Date]								[date]			NULL	-- ���� ������� 

		,[CPU]								[bigint]		NULL	-- cpu_time
		,[Duration]							[bigint]		NULL	--	duration
		,[Page_server_reads]				[bigint]		NULL
		,[Reads_physical]					[bigint]		NULL	-- physical_reads
		,[Reads_logical]					[bigint]		NULL	-- logical_reads
		,[Writes]							[bigint]		NULL	-- writes
		,[Spills]							[bigint]		NULL	-- spills
		,[Row_count]						[bigint]		NULL	-- row_count
		,[Reqs_Cnt]							[bigint]		NULL
		,[Orders]							[bigint]		NULL
		 ) 
		on	[PRIMARY] 
end -- [XE_Sum]

-- ********** Step 02 LOG: ���������� � �������� ���������� ���������� �������� ********** --

If		(@Steps is null	or @Steps like N'% LOG %')
	and (object_id(N'[dbo].[XEd_Log]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Log]

	drop table if exists[dbo].[XEd_Log]
	print N'*** ' + @Version + ': Step 02/17          LOG: �������� ����������� [dbo].[XEd_Log]'
	create table [dbo].[XEd_Log] 
	(
	 [RowNumber]		[bigint]		NOT NULL IDENTITY(1,1) PRIMARY KEY	
	,[����]				[date]			NULL	-- ���� ���������� ���������
	,[Caller]			[nvarchar](128) NULL	-- ��� ��������

	,[Procedure]		[nvarchar](128) NULL	-- ��� ����������� ���������
	,[Option]			[nvarchar](max) NULL	-- �������
	,[Table]			[nvarchar](128)	NULL
	,[Session]			[nvarchar](128)	NULL
	,[Date]				[date]			NULL
	,[Records]			[bigint]		NULL
	,[Percent]			[numeric](13,6)	NULL
	,[AddSum]			[numeric](13,6)	NULL
	,[Start]			[date]			NULL	-- ���� � ����� �������
	,[Stop]				[date]			NULL	-- ���� � ����� ����������
	,[Source]				[nvarchar](2048) NULL
	,[Offset]			[int]			NULL
	,[Orders]			[bigint]		NULL
	,[OrdersProc]		[nvarchar](128)	NULL
	,[Steps]			[nvarchar](256) NULL

	,[@@ERROR]			[int]			NULL	-- ��� �������� ������
	,[@@ROWCOUNT]		[int]			NULL	-- ����� ������������� �����
	,[ERROR_LINE]		[int]			NULL	-- ������ � �������

	,[Begin]			[datetime]		NULL	-- ���� � ����� �������
	,[End]				[datetime]		NULL	-- ���� � ����� ����������
	,[Duration]			[float]			NULL	-- ����� ����������, ���.

	,[Comment]			[nvarchar](128) NULL	-- ����������� ������

	,[HOST_ID]			[char](128)		NULL	-- Host Id
	,[HOST_NAME]		[nvarchar](128) NULL	-- Host Name
	)
	on [PRIMARY] 

end -- [XEd_Log]

-- ********** Step 03 SOURCE: ���������� ��������� ������ ********** --

If		(@Steps is null	or @Steps like N'% SOURCE %')
	and (object_id(N'[dbo].[XEd_Source]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Source]

	drop table if exists [dbo].[XEd_Source]
	print N'*** ' + @Version + ': 03/17            SOURCE: �������� ����������� [dbo].[XEd_Source]'
	create table [dbo].[XEd_Source] 
	(
	 [DateTime]			[datetime2](7)	NULL	-- ���� ���������� ���������
	,[Session]			[nvarchar](128) NULL	-- ��� ������� XE
	,[Source]			[nvarchar](2048) NULL	-- ���� � ������ ����� ������ XE
	,[Date]				[date]			NULL	-- ����  �������� ������
	,[Time]				[time]			NULL	-- ��������: ���� ���������� 
	,[Directory]		[nvarchar](2048)	COLLATE DATABASE_DEFAULT	-- ���� � ����� � �������
	,[File_Name]		[nvarchar](128) COLLATE DATABASE_DEFAULT	-- ��� �����
	,[Records]			[bigint]		NULL	-- ��� ������� ��� ������ ������
	,[Events]			[bigint]		NULL	-- ����� ��������� �������
	)
	on [PRIMARY] 
end -- [XEd_Source]

-- ********** Step 04 HASH: ���������� ������������ Hash (TextData) ********** --

If		(@Steps is null	or @Steps like N'% HASH %')
	and (object_id(N'[dbo].[XEd_Hash]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Hash]

	drop table if exists [dbo].[XEd_Hash]
	print N'*** ' + @Version + ' : 04/17             HASH: �������� ����������� [dbo].[XEd_Hash]'
	create table [dbo].[XEd_Hash] 
		(
		 [Hash#]						[bigint]	NOT NULL	IDENTITY(1,1) PRIMARY KEY
		,[Hash]							[nchar](32)		NULL	
		,[HashText]						[nchar](32)		NULL	
		,[Exec#]						[bigint]		NULL	-- Exec Id
		,[Table#]						[bigint]		NULL	-- Table Id
		,[Date]							[date]			NULL	-- ���� ���������� �������������
		,[First_Date]					[date]			NULL	-- ���� ������� ����������
		,[Cnt]							[bigint]		NULL default 0	-- ����� ������������� 
		,[TextData]						[nvarchar](max)	NULL	-- ������������ ����� �������
		,[Text]							[nvarchar](max) NULL	-- ��������� ������
		 ) 
		on	[PRIMARY] 

	alter table [dbo].[XEd_Hash]
		add constraint cUI_XEd_Hash 
		UNIQUE ([Hash])

-- ���������� ������� - �� ������, �.�. ����������� ������� ��� ���������� ������ �����������\
-- ����� �������.
/*
if @Compression = 'True' 
	ALTER TABLE dbo.XEd_Hash REBUILD PARTITION = ALL
		WITH (DATA_COMPRESSION = ROW);
*/
end -- [XEd_Hash]

-- ********** Step 05 HOST: ���������� ������������ Host ********** --

If		(@Steps is null	or @Steps like N'% HOST %')
	and (object_id(N'[dbo].[XEd_Host]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Host]

	drop table if exists [dbo].[XEd_Host]
	print N'*** ' + @Version + ': Step 05/17         HOST: �������� ����������� [dbo].[XEd_Host]'
	create table [dbo].[XEd_Host] 
		(
		 [Host#]			[bigint]	NOT NULL IDENTITY(1,1) PRIMARY KEY
		,[HostName]			[varchar](128)	NULL 	-- client_hostname
		,[Date]				[date]			NULL	-- ���� ���������� �������������
		,[First_Date]		[date]			NULL		-- ���� ������� ����������
		,[Cnt]				[bigint]		NULL default 0	-- ����� ������������� � ��������������� ������
		 ) 
		on	[PRIMARY] 

	alter table [dbo].[XEd_Host]
		add constraint cUI_XEd_Host 
		UNIQUE ([HostName])
end -- [XEd_Host]

-- ********** Step 06 TABLE: ���������� ������������ Table ********** --

If		(@Steps is null	or @Steps like N'% TABLE %')
	and (object_id(N'[dbo].[XEd_Table]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Table]
	drop table if exists [dbo].[XEd_Table]
	print N'*** ' + @Version + ': Step 06/17        TABLE: �������� ����������� [dbo].[XEd_Table]'
	create table [dbo].[XEd_Table] 
		(
		 [Table#]		[bigint]		NOT NULL IDENTITY(1,1)  -- Table Id
		,[Table_Server]	[nvarchar](128) NULL					-- Table DB Id
		,[Table_DB]		[nvarchar](128) NULL					-- Table DB Id
		,[Table_Schema]	[nvarchar](128) NULL					-- Table Schema id
		,[Table_Name]	[nvarchar](128) NULL					-- Name of table (non-qualified)
		,[Date]			[date]			NULL					-- ���� ���������� �������������
		,[First_Date]	[date]			NULL					-- ���� ������� ����������
		,[Cnt]			[bigint]		NULL default 0			-- ����� ������������� 
		)
		on	[PRIMARY] 

	alter table [dbo].[XEd_Table]
		add constraint cUI_XEd_Table 
		UNIQUE (
				 [Table_Server]
				,[Table_DB]
				,[Table_Schema]
				,[Table_Name]
				)
end -- [XEd_Table]

-- ********** Step 07 Exec: ���������� ������������ EXEC ********** --

If		(@Steps is null	or @Steps like N'% EXEC %')
	and (object_id(N'[dbo].[XEd_Exec]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Exec]

	drop table if exists [dbo].[XEd_Exec]
	print N'*** ' + @Version + ': Step 07/17         EXEC: �������� ����������� [dbo].[XEd_Exec]'
	create table [dbo].[XEd_Exec] 
		(
		 [Exec#]		[bigint]		NOT NULL IDENTITY(1,1)  PRIMARY KEY -- Exec Id
		,[Exec_Server]	[nvarchar](128) NULL			-- Exec DB Id
		,[Exec_DB]		[nvarchar](128) NULL			-- Exec DB Id
		,[Exec_Schema]	[nvarchar](128) NULL			-- Exec Schema id
		,[Exec_Name]	[nvarchar](128) NULL			-- Name of Exec (non-qualified)
		,[Date]			[date]			NULL			-- ���� ���������� �������������
		,[First_Date]	[date]			NULL			-- ���� ������� ����������
		,[Cnt]			[bigint]		NULL default 0	-- ����� ������������� 
		) 
		on	[PRIMARY] 

	alter table [dbo].[XEd_Exec]
		add constraint cUI_XEd_Exec 
		UNIQUE (
				 [Exec_Server]
				,[Exec_DB]
				,[Exec_Schema]
				,[Exec_Name]
				)
end -- [XEd_Exec]

-- ********** Step 08 SESSION: ���������� ������������ Session ********** --

If		(@Steps is null	or @Steps like N'% SESSION %')
	and (object_id(N'[dbo].[XEd_Session]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Session]

	drop table if exists [dbo].[XEd_Session]
	print N'*** ' + @Version + ': Step 08/17      SESSION: �������� ����������� [dbo].[XEd_Session]'
	create table [dbo].[XEd_Session] 
		(
		 [Session#]		[bigint]		NOT NULL IDENTITY(1,1)  PRIMARY KEY -- Exec Id
		,[Session]		[nvarchar](128) NOT NULL 
		,[Date]			[date]			NULL		-- ���� ���������� �������������
		,[First_Date]	[date]			NULL		-- ���� ������� ����������
		,[Cnt]			[bigint]		NULL	default 0	-- ����� ������������� 			)
		) 
		on	[PRIMARY] 

	alter table [dbo].[XEd_Session]
		add constraint cUI_XEd_Session 
		UNIQUE ([Session])
end -- [XEd_Session]

-- ********** Step 09 DATABASE: ���������� ������������ Database ********** --

If		(@Steps is null	or @Steps like N'% DATABASE %')
	and (object_id(N'[dbo].[XEd_Database]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Database]

	drop table if exists [dbo].[XEd_Database]
	print N'*** ' + @Version + ': Step 09/17     DATABASE: �������� ����������� [dbo].[XEd_Database]'
	create table [dbo].[XEd_Database] 
		(
		 [Database#]		[bigint]			NOT NULL IDENTITY(1,1)  PRIMARY KEY --  Id
		,[Database_name]	[nvarchar](128)	NULL
		,[DatabaseID]		[int]				NOT NULL	
		,[Date]				[date]				NULL			-- ���� ���������� �������������
		,[First_Date]		[date]				NULL			-- ���� ������� ����������
		,[Cnt]				[bigint]			NULL default 0	-- ����� ������������� 
		) 
		on	[PRIMARY] 

	alter table [dbo].[XEd_Database]
		add constraint cUI_XEd_Database 
		UNIQUE (
				[Database_name]
				,[DatabaseID]
				)
end -- [XEd_Database]

-- ********** Step 10 USER: ���������� ������������ User ********** --

If		(@Steps is null	or @Steps like N'% USER %')
	and (object_id(N'[dbo].[XEd_User]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_User]

	drop table if exists [dbo].[XEd_User]
	print N'*** ' + @Version + ': Step 10/17         USER: �������� ����������� [dbo].[XEd_User]'
	create table [dbo].[XEd_User] 
		(
		 [User#]		[bigint]		NOT NULL IDENTITY(1,1)  PRIMARY KEY -- Id
		,[Nt_username]	[nvarchar](128) NULL	
		,[Nt_AD]		[nvarchar](128) NULL  	
		,[LoginName]	[nvarchar](128) NULL	
		,[Login_AD]		[nvarchar](128) NULL	
		,[Date]			[date]			NULL			-- ���� ���������� �������������
		,[First_Date]	[date]			NULL			-- ���� ������� ����������
		,[Cnt]			[bigint]		NULL default 0	-- ����� ������������� 
		) 
		on	[PRIMARY] 

	alter table [dbo].[XEd_User]
		add constraint cUI_XEd_User 
			UNIQUE	([Nt_username]
					,[Nt_AD]
					,[LoginName]
					,[Login_AD]
					)
end	-- [XEd_User]

-- ********** Step 11 EVENT: ���������� ������������ ������� Event ********** --

If		(@Steps is null	or @Steps like N'% EVENT %')
	and (object_id(N'[dbo].[XEd_Event]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Event]

	drop table if exists [dbo].[XEd_Event]
	print N'*** ' + @Version + ': Step 11/17        EVENT: �������� ����������� [dbo].[XEd_Event]'
	create table [dbo].[XEd_Event] 
		(
		 [Event#]		[bigint]		NOT NULL IDENTITY(1,1)  PRIMARY KEY -- Id
		,[Session]		[nvarchar](128) NULL	
		,[Package]		[nvarchar](128) NULL	
		,[Event]		[nvarchar](128) NULL
		,[Date]			[date]			NULL			-- ���� ���������� �������������
		,[First_Date]	[date]			NULL			-- ���� ������� ����������
		,[Cnt]			[bigint]		NULL default 0	-- ����� ������������� 
		)
		on	[PRIMARY] 

	alter table [dbo].[XEd_Event]
		add constraint cUI_XEd_Event 
		UNIQUE (
				 [Session]
				,[Package]
				,[Event]
				)
end -- [XEd_Event]

-- ********** Step 12 APPLICATION: ���������� ���������� Application ********** --

If		(@Steps is null	or @Steps like N'% APPLICATION %')
	and (object_id(N'[dbo].[XEd_Application]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Application]

	drop table if exists [dbo].[XEd_Application]
	print N'*** ' + @Version + ': Step 12/17  APPLICATION: �������� ����������� [dbo].[XEd_Application]'
	create table [dbo].[XEd_Application] 
		(
		 [Application#]	[bigint]		NOT NULL IDENTITY(1,1)  PRIMARY KEY -- Id
		,[Application]	[nvarchar](128) NULL 
		,[Date]			[date]			NULL			-- ���� ���������� �������������
		,[First_Date]	[date]			NULL			-- ���� ������� ����������
		,[Cnt]			[bigint]		NULL default 0	-- ����� ������������� 
		) 
		on	[PRIMARY] 

	alter table [dbo].[XEd_Application]
		add constraint cUI_XEd_App 
		UNIQUE (
				[Application]
				)
end -- [XEd_App]

-- ********** Step 13 RESULT: ���������� ����� Result ********** --

If		(@Steps is null	or @Steps like N'% RESULT %')
	and (object_id(N'[dbo].[XEd_Result]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Result]

	drop table if exists [dbo].[XEd_Result]
	print N'*** ' + @Version + ': Step 13/17       RESULT: �������� ����������� [dbo].[XEd_Result]'
create table [dbo].[XEd_Result] 
	(
	 [Result#]		[bigint]		NOT NULL IDENTITY(1,1)  PRIMARY KEY -- Id
	,[Result_Code]	int				NULL	
	,[Result_Text]	[nvarchar](128) NULL	
	,[Date]			[date]			NULL			-- ���� ���������� �������������
	,[First_Date]	[date]			NULL			-- ���� ������� ����������
	,[Cnt]			[bigint]		NULL default 0	-- ����� ������������� 
	)
		on	[PRIMARY] 

	alter table [dbo].[XEd_Result]
		add constraint cUI_XEd_Result 
		UNIQUE (
				[Result_Code]
				,[Result_Text]
				)
end -- [XEd_Result]

-- ********** Step 14 OUTPUT: ���������� ����� Output ********** --

If		(@Steps is null	or @Steps like N'% OUTPUT %')
	and (object_id(N'[dbo].[XEd_Output]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Output]

	drop table if exists [dbo].[XEd_Output]
	print N'*** ' + @Version + ':  Step 14/17      OUTPUT: �������� ����������� [dbo].[XEd_Output]'
	create table [dbo].[XEd_Output] 
		(
		 [Output#]				[bigint]	NOT NULL IDENTITY(1,1)  PRIMARY KEY -- Id
		,[Output_parameters]	[nvarchar](128)	NULL 			-- output_parameters
		,[Date]					[date]			NULL			-- ���� ���������� �������������
		,[First_Date]			[date]			NULL			-- ���� ������� ����������
		,[Cnt]					[bigint]		NULL default 0	-- ����� ������������� 
		)
		on	[PRIMARY] 

	alter table [dbo].[XEd_Output]
		add constraint cUI_XEd_Output 
		UNIQUE ([Output_parameters])
end -- [XEd_Output]

-- ********** Step 15 SET: ������� ���������� ������ ********** --

If		(@Steps is null	or @Steps like N'% SET %')
	and (object_id(N'[dbo].[XEd_Set]', N'U') is null or @Replace = 'TRUE')
begin -- [XEd_Set]

	if @Replace = 'TRUE' drop table if exists [dbo].[XEd_Set]


	print N'*** ' + @Version + ': Step 15/17          SET: �������� ����������� [dbo].[XEd_Set]'
	CREATE TABLE [dbo].[XEd_Set]
		(
		 [Parameter]	[nvarchar](16)	NULL	-- ��� ��������� 
		,[Session]		[nvarchar](128)	NULL	-- ��� ������ XE ��� null
		,[Object]		[nvarchar](128)	NULL	-- ��� �������(�������)  ��� null
		,[Value]		[numeric](13,6)	NULL	-- �������� ��������� ��� ���� �������� ��� �������
		) 
		ON	[PRIMARY] 

-- ������� ������������ ��������

Insert into [dbo].[XEd_Set]
	(
	[Parameter]
	,[Session]
	,[Object]
	,[Value]
	)
	values
			 (null,			N'-- ������ �� ���������',  null, null)
--			Parameter		Session			Object			Value
--			-----------		---------		---------		---------
			,(N'Session'		,@Session		,null			,null)

			,(null,			N'-- ��������� ������ � XE_Top'	,null, null)
--			Parameter		Session			Object			Value
--			-----------		---------		---------		---------
			,(N'Records'	,null			,null			,@Records)
			,(N'Percent'	,null			,null			,@Percent)
			,(N'AddSum'		,null			,null			,@AddSum)
-- � �������� ������� ��������� ��������� ��� ������ sotivoli
			,(N'Records'	,N'sotivoli'	,'XE_sotivoli'	,300)

			,(null,			N'-- ���� � ������ ������ XE', null, null)
--			Parameter		Session			Object			Value
--			-----------		---------		---------		---------
			,(N'Source'		,null			,@Source		,null)
			,(N'Source'		,@Session		,@Source		,null)

			,(null,			N'-- ������� ������ ������',	null,	null)
--			Parameter		Session			Object			Value
--			-----------		---------		---------		---------
			,(N'xel'		,null			,'XE_Xel'		,@Offset)
			,(N'xel'		,@Session		,@Table			,@Offset)
-- � �������� ������� ��������� ��������� ��� ������ sotivoli
			,(N'xel'		,N'sotivoli'	,N'XE_sotivoli'	,1000)

			,(null	,N'-- ����������� ���� �������� ������ � ������������',  null, null)
--			Parameter		Session			Object			Value
--			-----------		---------		---------		---------
			,(N'Offset'		,null			,null			,@Offset)
			,(N'Offset'		,@Session		,null			,@Offset)
-- � �������� ������� ��������� ��������� ��� ������ sotivoli
			,(N'Offset'		,N'sotivoli'	,N'XEd_Hash'	,3650)
			,(null	,N'-- ��� ���������, ����������� @Orders',  null, null)
			,(N'OrdersProc'	,null			,'XE_Count_JDE'		,null)
			,(N'OrdersProc'	,@Session		,@OrdersProc		,null)

end -- [XEd_Set]

-- *********** Step  16 XEL: ������� ��� ���������� ������ � ������ Extended Events ************ --

If	( @Steps is null or  @Steps like N'% XEL %')
BEGIN -- [dbo].[XE_]

		print N'*** ' + @Version + ': Step 16/17          XEL: �������� ������� xel � � �������������:'

-- ������� ������� #tmp1 - �������� ������ � ������������� ���� XEL

	drop table if exists #tmp1
	create table #tmp1 ([Row]  int identity(1,1), [Table] nvarchar(128))
-- ��������� ������� ��� ������
	if @Table is not null
		insert into #tmp1	([Table]) select @Table			as [Table]
	
-- ���� ���, �� - ������ ������ xel �� XEd_Set
	if @Table is null
--			begin	-- list of XEL tables in #tmp1
	insert into #tmp1	([Table])	
		select [Object]										as [Table] 
			from [dbo].[XEd_Set]
			where upper(ltrim(rtrim([Parameter]))) = 'XEL'
			  and [Session] not like '-%'
			  and [Session] not like '#%'
			group by [Object]
--			order by [Object] desc

-- ��������� �������: ��� ������� �� ���������
	if (select count(1) from #tmp1) is null 
		insert into #tmp1	([Table]) select @Table_default	as [Table]

-- ���� �� ������ ������

Declare @Ti as int = 1

While @Ti <= (select count(1) from #tmp1)
	begin	-- loop by tables name

		select  @Table = N'[dbo].' 
						+ case when left(upper(parsename([Table],1)), 3) = 'XE_'
									then quotename(upper(parsename([Table],1)))
									else quotename('XE_' + upper(parsename([Table],1)))
									end
			from #tmp1
			where [Row] = @Ti

		set @View =  N'[dbo].' 
					+ QUOTENAME('XEv_' + right(parsename(@Table,1), len(parsename(@Table,1))-3))

-- ������� ������������ ������� � �������������

		if @Replace = 'TRUE' 
			begin	-- delete table and view
				set @Cmd = 'drop table if exists ' + @Table
				if @List = 'TRUE' print N'*** ' + @Version + ':                   	       �������� ������� '+ @Table
				exec sp_sqlexec @Cmd
				set @Cmd = 'drop view if exists ' + @View
				if @List = 'TRUE' print N'*** ' + @Version + ':                   	 �������� ������������� '+ @View
				exec sp_sqlexec @Cmd
			end		-- delete table and view

-- ������� ������� xel
	
		if object_id(@Table, 'U') is null 
			begin		-- ������� ������� @Table

				print N'*** ' + @Version + ':                   	       �������� ������� '+ @Table
				Set @Cmd =
N'create table ' + @Table + ' '
	+N'('
	+N' [RowNumber]			[bigint]		NOT NULL IDENTITY(1,1) PRIMARY KEY ' 	
	+N',[Date]				[date]			NULL'	-- ���� ������� 

	+N',[CPU]				[bigint]		NULL'	-- cpu_time
	+N',[Duration]			[bigint]		NULL'	-- duration
	+N',[Page_server_reads]	[bigint]		NULL'
	+N',[Reads_physical]	[bigint]		NULL'	-- physical_reads
	+N',[Reads_logical]		[bigint]		NULL'	-- logical_reads
	+N',[Writes]			[bigint]		NULL'	-- writes
	+N',[Spills]			[bigint]		NULL'	-- spills

	+N',[Row_count]			[bigint]		NULL'	-- row_count
	+N',[Is_System]			[bit]			NULL'	-- is_System
	+N',[Session_id]		[bigint]		NULL'	-- session_id
	+N',[Client_pid]		[bigint]		NULL'	-- client_pid
	+N',[Event_sequence]	[bigint]		NULL'	-- event_sequence

	+N',[DateTime_Start]	[datetime2](7)	NULL'	-- Start date & time
	+N',[DateTime_Stop]		[datetime2](7)	NULL'	-- End date & time
	
	+N',[Hash#]				[bigint]		NULL'	-- ������ �� ���������� Session
	+N',[Session#]			[bigint]		NULL'	-- ������ �� ���������� Session
	+N',[Host#]				[bigint]		NULL'	-- ������ �� ���������� Host
	+N',[Database#]			[bigint]		NULL'	-- ������ �� ���������� Database
	+N',[User#]				[bigint]		NULL'	-- ������ �� ���������� User
	+N',[Application#]		[bigint]		NULL'	-- ������ �� ���������� Application
	+N',[Event#]			[bigint]		NULL'	-- ������ �� ���������� Event
	+N',[Result#]			[bigint]		NULL'	-- ������ �� ���������� Result
	+N',[Output#]			[bigint]		NULL'	-- ������ �� ���������� Output
	+N' ) '
		+N'		on	[PRIMARY] '

				EXECUTE sp_executesql @Cmd 

-- �������������� ��������, ������������ ��� ������ � �������

				set @Cmd =	 N'Create index iXE_Date on ' 
							+@Table 
							+N' ([Date])'

				EXECUTE sp_executesql @Cmd 
			end		---- ������� ������� @Table

-- ��������� ���������� �������

set @Cmd = 'ALTER TABLE ' + @Table + ' REBUILD PARTITION = ALL
WITH (DATA_COMPRESSION = ROW);'

if @Compression = 'True' EXECUTE sp_executesql @Cmd 

-- 0.5	���������� ��� ������������� ��� ������� @Table

		if object_id(@View, 'V') is null 
			begin		-- ������� ������������� @View
				print N'*** ' + @Version + ':                        �������� ������������� ' + @View
				set @Cmd = 
 N'Create view ' + @View + N' '
+N'as '
+N'select '
		+N' [l].[RowNumber] '
		+N',[l].[Date] '

		+N',[l].[CPU] '
		+N',[l].[Duration] '
		+N',[l].[Page_server_reads] '
		+N',[l].[Reads_physical] '
		+N',[l].[Reads_logical] '
		+N',[l].[Writes] '
		+N',[l].[Spills] '
		+N',[l].[Row_count] '

		+N',[l].[Hash#] '
		+N',[Ha].[TextData] '
		+N',[Ha].[Text] '
		+N',[S].[Session] '
		+N',[Ho].[HostName] '
		+N',[D].[DatabaseID] '
		+N',[D].[Database_name] '
		+N',[U].[Nt_AD] '
		+N',[U].[Nt_username] '
		+N',[U].[Login_AD] '
		+N',[U].[LoginName] '
		+N',[A].[Application] '
		+N',[E].[Package] '
		+N',[E].[Event] '
		+N',[R].[Result_Code] '
		+N',[O].[Output_parameters] '
		+N',[R].[Result_Text] '
		+N',[X].[Exec_Server] '
		+N',[X].[Exec_DB] '
		+N',[X].[Exec_Schema] '
		+N',[X].[Exec_Name] '
		+N',[T].[Table_Server] '
		+N',[T].[Table_DB] '
		+N',[T].[Table_Schema] '
		+N',[T].[Table_Name] '

		+N',[Is_System] '
		+N',[l].[Session_id] '
		+N',[l].[Client_pid] '
		+N',[l].[Event_sequence] '

		+N',[l].[DateTime_Start] '
		+N',[l].[DateTime_Stop] '
	+N'from ' + @Table + N' as [l] '
	+N'left join	[dbo].[XEd_Hash]		as [Ha]	on [Ha].[Hash#]			= [l].[Hash#] '
	+N'left join	[dbo].[XEd_Host]		as [Ho]	on [Ho].[Host#]			= [l].[Host#] '
	+N'left join	[dbo].[XEd_Session]		as [S]	on [S].[Session#]		= [l].[Session#] '
	+N'left join	[dbo].[XEd_Database]	as [D]	on [D].[Database#]		= [l].[Database#] '
	+N'left join	[dbo].[XEd_Event]		as [E]	on [E].[Event#]			= [l].[Event#] '
	+N'left join	[dbo].[XEd_User]		as [U]	on [U].[User#]			= [l].[User#] '
	+N'left join	[dbo].[XEd_Application]	as [A]	on [A].[Application#]	= [l].[Application#] '
	+N'left join	[dbo].[XEd_Output]		as [O]	on [O].[Output#]		= [l].[Output#] '
	+N'left join	[dbo].[XEd_Result]		as [R]	on [R].[Result#]		= [l].[Result#] '
	+N'left join	[dbo].[XEd_Exec]		as [X]  on [X].[Exec#]			= [Ha].[Exec#] '
	+N'left join	[dbo].[XEd_Table]	as [T]	on [T].[Table#]			= [Ha].[Table#] '
				EXECUTE sp_executesql @Cmd 
			end		-- ������� ������������� @View

		set @Ti = @Ti + 1
	end		-- loop by tables name

END -- [dbo].[XE_]

-- ********** Step 17 TOP: �������� ������� � ������ �������� ********** --

If		(@Steps is null	or @Steps like N'% TOP %')
	and (object_id(N'[dbo].[XE_Top]', N'U') is null or @Replace = 'TRUE')
begin -- [XE_Top]

	drop table if exists [dbo].[XE_Top]
	drop view  if exists [dbo].[XEv_Top]
	print N'*** ' + @Version + ': Step 17/17          TOP:     �������� ������� [dbo].[XE_Top]'
	CREATE TABLE [dbo].[XE_Top] 
		(
		 [RowNumber]					[bigint]		NULL 
		,[Date]							[date]			NULL	-- ���� ������� 

		,[CPU]							[bigint]		NULL	-- cpu_time
		,[Duration]						[bigint]		NULL	--	duration
		,[Page_server_reads]			[bigint]		NULL
		,[Reads_physical]				[bigint]		NULL	-- physical_reads
		,[Reads_logical]				[bigint]		NULL	-- logical_reads
		,[Writes]						[bigint]		NULL	-- writes
		,[Spills]						[bigint]		NULL	-- spills
		,[Row_count]					[bigint]			NULL	-- row_count

		,[Hash#]						[bigint]		NULL	-- ������ �� ���������� Session
		,[Session#]						[bigint]		NULL	-- ������ �� ���������� Session
		,[Host#]						[bigint]		NULL	-- ������ �� ���������� Host
		,[Database#]					[bigint]		NULL	-- ������ �� ���������� Database
		,[User#]						[bigint]		NULL	-- ������ �� ����������
		,[Application#]					[bigint]		NULL	-- ������ �� ����������
		,[Event#]						[bigint]		NULL	-- ������ �� ���������� Event
		,[Result#]						[bigint]		NULL	-- ������ �� ���������� Result
		,[Output#]						[bigint]		NULL	-- ������ �� ���������� Output
		,[Is_System]					[bit]			NULL	-- is_System

		,[Session_id]					[bigint]			NULL	-- session_id
		,[Client_pid]					[bigint]			NULL	-- client_pid
		,[Event_sequence]				[bigint]			NULL	-- event_sequence

		,[DateTime_Start]				[datetime2](7)	NULL	-- Start date & time
		,[DateTime_Stop]				[datetime2](7)	NULL	-- End date & time

-- �������� ������ (top ��������)
		,[C]							[bit]			NULL	-- CPU
		,[D]							[bit]			NULL	-- Duration
		,[P]							[bit]			NULL	-- Reads_physical
		,[L]							[bit]			NULL	-- Reads_logical
		,[W]							[bit]			NULL	-- Writes
		,[S]							[bit]			NULL	-- Spills
-- �������� ������ (%% �� ������ �� �����)
		,[C%]							[bit]			NULL	-- CPU
		,[D%]							[bit]			NULL	-- Duration
		,[P%]							[bit]			NULL	-- Reads_physical
		,[L%]							[bit]			NULL	-- Reads_logical
		,[W%]							[bit]			NULL	-- Writes
		,[S%]							[bit]			NULL	-- Spills
-- �������� ������ ( ����������� %% �� ������ �� �����)
		,[C%A]							[bit]			NULL	-- CPU
		,[D%A]							[bit]			NULL	-- Duration
		,[P%A]							[bit]			NULL	-- Reads_physical
		,[L%A]							[bit]			NULL	-- Reads_logical
		,[W%A]							[bit]			NULL	-- Writes
		,[S%A]							[bit]			NULL	-- Spills
		 ) 
	on	[PRIMARY] 
	print N'*** ' + @Version + ':                        �������� ������������� [dbo].[XEv_Top]' 

-- ������������ SQL, �.�. Create view must be only first...

	Set @Cmd =
N'Create view  [dbo].[XEv_Top] as '
	+N'select '
				+N'[l].[RowNumber] '
				+N',[l].[Date] '

				+N',[l].[CPU] '
				+N',[l].[Duration] '
				+N',[l].[Page_server_reads] '
				+N',[l].[Reads_physical] '
				+N',[Reads_logical] '
				+N',[l].[Writes] '
				+N',[l].[Spills] '
				+N',[l].[Row_count] '

				+N',[l].[Hash#] '
				+N',[Ha].[TextData] '
				+N',[Ha].[Text] '
				+N',[S].[Session] '
				+N',[Ho].[HostName] '
				+N',[D].[DatabaseID] '
				+N',[D].[Database_name] '
				+N',[U].[Nt_AD] '
				+N',[U].[Nt_username] '
				+N',[U].[Login_AD] '
				+N',[U].[LoginName] '
				+N',[A].[Application] '
				+N',[E].[Package] '
				+N',[E].[Event] '
				+N',[R].[Result_Code] '
				+N',[O].[Output_parameters] '
				+N',[R].[Result_Text] '
				+N',[X].[Exec_Server] '
				+N',[X].[Exec_DB] '
				+N',[X].[Exec_Schema] '
				+N',[X].[Exec_Name] '
				+N',[T].[Table_Server] '
				+N',[T].[Table_DB] '
				+N',[T].[Table_Schema] '
				+N',[T].[Table_Name] '

				+N',[l].[Is_System] '
				+N',[l].[Session_id] '
				+N',[l].[Client_pid] '
				+N',[l].[Event_sequence] '
				+N',[l].[DateTime_Start] '
				+N',[l].[DateTime_Stop] '

				+N',[l].[C] '
				+N',[l].[D] '
				+N',[l].[P] '
				+N',[l].[L] '
				+N',[l].[W] '
				+N',[l].[S] '
				+N',[l].[C%] '
				+N',[l].[D%] '
				+N',[l].[P%] '
				+N',[l].[L%] '
				+N',[l].[W%] '
				+N',[l].[S%] '
				+N',[l].[C%A] '
				+N',[l].[D%A] '
				+N',[l].[P%A] '
				+N',[l].[L%A] '
				+N',[l].[W%A] '
				+N',[l].[S%A] '
	+N'from [dbo].[XE_Top] as [l] '
		+N'left join	[dbo].[XEd_Hash]		as [Ha]	on [Ha].[Hash#]			= [l].[Hash#] '
		+N'left join	[dbo].[XEd_Host]		as [Ho]	on [Ho].[Host#]			= [l].[Host#] '
		+N'left join	[dbo].[XEd_Session]		as [S]	on [S].[Session#]		= [l].[Session#] '
		+N'left join	[dbo].[XEd_Database]	as [D]	on [D].[Database#]		= [l].[Database#] '
		+N'left join	[dbo].[XEd_Event]		as [E]	on [E].[Event#]			= [l].[Event#] '
		+N'left join	[dbo].[XEd_User]		as [U]	on [U].[User#]			= [l].[User#] '
		+N'left join	[dbo].[XEd_Application]	as [A]	on [A].[Application#]	= [l].[Application#] '
		+N'left join	[dbo].[XEd_Output]		as [O]	on [O].[Output#]		= [l].[Output#] '
		+N'left join	[dbo].[XEd_Result]		as [R]	on [R].[Result#]		= [l].[Result#] '
		+N'left join	[dbo].[XEd_Exec]		as [X]  on [X].[Exec#]			= [Ha].[Exec#] '
		+N'left join	[dbo].[XEd_Table]	as [T]	on [T].[Table#]			= [Ha].[Table#] '

	EXECUTE sp_executesql @Cmd 

-- ���������� �������

if @Compression = 'True' 
	ALTER TABLE dbo.XE_Top REBUILD PARTITION = ALL
		WITH (DATA_COMPRESSION = ROW);

end -- [XE_Top]

-- ********** Step  18 (������������)  SESSION: �������� � ������ ������ Extended Events (XE) ********** --

If @Create = 'True'
BEGIN -- Event

-- ������ "exec sp_trace_setevent @TraceID, 10, trace_column_id, @on", �������� trace_column_id ����:

if @Replace = 'TRUE' and NOT EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='XEs_' + @Session)
	begin	-- Drop XE session
		set @Cmd = 'DROP EVENT SESSION XEs_' + @Session + ' ON SERVER'
		EXECUTE sp_executesql @Cmd 
	end		-- Drop XE Session

if NOT EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='XEs_' + @Session)
	begin -- Create Session
		print N'*** ' + @Version + ':  Step 18        SESSION:   �������� XE ������ XEs_' + @Session + ' '

		set @Cmd =
		 N'Create event session XEs_' + @Session + ' on server '

		+N'Add event sqlserver.rpc_completed '			
	-- �������� ����������� ���������:	01	(TextData) 
	--									03	(DatabaseID)
	--									13	(Duration)
	--									14	(StartTime)
	--									16	(Reads)
	--									17	(Writes)
	--									18	(CPU)

	--�������������� ���������:	
			+N'(action	(package0.event_sequence '
					+N',sqlserver.client_app_name '			-- 10	(ApplicationName)
					+N',sqlserver.client_pid '				-- 9	(ClientProcessID)
					+N',sqlserver.database_name '
					+N',sqlserver.database_id '				-- 3	(DatabaseID)
					+N',sqlserver.server_principal_name '	-- 11	(LoginName)
					+N',sqlserver.client_hostname '			-- 8	(HostName)
					+N',sqlserver.nt_username '				-- 6	(NTUserName)
					+N',sqlserver.session_id '				-- 12	(SPID)
					+N',sqlserver.is_system '
					+N') '
			+N'where	sqlserver.Reads_physical > 0 '				-- 300
			  +N'and	sqlserver.client_app_name not like N''SQL Profiler'' '
	--	  and sqlserver.database_name		=			'INT_DEM'
			  +N'and ('
					 +N'[package0].[equal_boolean]([sqlserver].[is_system],(0))'
					 +N') '
			+N'), '	-- Add event sqlserver.rpc_completed

	-- ������ "exec sp_trace_setevent @TraceID, 12, trace_column_id, @on", �������� trace_column_id ����:

		+N'Add event sqlserver.sql_batch_completed '			
			+N'( '
	-- �������� ����������� ���������:	01	(TextData) 
	--									13	(Duration)
	--									14	(StartTime)
	--									16	(Reads)
	--									17	(Writes)
	--									18	(CPU)

	--�������������� ���������:	
			+N'action	( '
					 +N'package0.event_sequence '
					+N',sqlserver.client_app_name '			-- 10	(ApplicationName)
					+N',sqlserver.client_pid '				-- 9	(ClientProcessID)
					+N',sqlserver.database_name '
					+N',sqlserver.database_id '				-- 3	(DatabaseID)
					+N',sqlserver.server_principal_name '	-- 11	(LoginName)
					+N',sqlserver.client_hostname '			-- 8	(HostName)
					+N',sqlserver.nt_username '				-- 6	(NTUserName)
					+N',sqlserver.session_id '				-- 12	(SPID)
					+N',sqlserver.is_system '
					 +N') '
			+N'where	sqlserver.Reads_physical > 0 '				-- 300
			 + N'and	sqlserver.client_app_name not like	N''SQL Profiler'' '
	--	  and	sqlserver.database_name			=			'INT_DEM'
			  +N'and ([package0].[equal_boolean]([sqlserver].[is_system],(0))) '

			+N') '	-- Add event sqlserver.sql_batch_completed

		+N'add target package0.event_file ( '
										 +N'set	filename =N''' + @Source + ''' '
										+N',max_file_size=(100) '
										+N',max_rollover_files=(10) '
										+N') '
			 +N'with	( '
					 +N'max_memory=4096 kb '
					+N',event_retention_mode=allow_single_event_loss '
					+N',max_dispatch_latency=30 seconds '
					+N',max_event_size=0 kb '
					+N',memory_partition_mode=none '
					+N',track_causality=off '
					+N',startup_state=on '
					 +N') '

		EXECUTE sp_executesql @Cmd 
	end	-- Create Session
END		-- Event 

-- ********** Step 19 Finish:                                ********** --

if @Steps is null or @List = 'TRUE' print N'
***
**************************************************************************
***      ' + left(@Version + replicate(' ', 25), 25) 
+N'   ���������                         ***
*** �������������� ���� �����������:                                   ***
***   1) �������������� ��������� ������ XE (������� XEd_Set)          ***
***   2) �������������� ��������� XE_Days � ������������ ��            ***
***          ���������� ����������                                     ***
***                                                                    ***
***   ���� ������������� �������� ������ ����������� ���������         ***
***	     XE_Convert	  ��� ������ �� XE ������ 4.4 � Profiler           ***
***   2) �������������� ��������� XE_Days � ������������ ��            ***
**************************************************************************'

	end		-- XE_Install