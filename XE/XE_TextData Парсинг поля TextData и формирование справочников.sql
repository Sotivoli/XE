/* =============================================
-- Author:		Sotivoli
-- Create date: 07 October 2024
-- Description:	������� ������ �� ���� TextData
-- =============================================
exec [dbo].[XE_TextData] @Option = 'list /only compact'
	,@Session = 'alidi'
-- ============================================= */
--			'List'		= ������ ����������� ���������� ��� ������ ������ � ������
--			'Info'		= �������� �� ����� ���������� � ����������
--			'NoClear'	= �� ���������  ������� �������� ������ � ��������
--			'Compact'	= �� ���������� ��������������� TextData � ���� Text ������� XEd_Hash
--	Declare
	drop procedure if exists	[dbo].[XE_TextData]
GO
	CREATE	PROCEDURE			[dbo].[XE_TextData]
 @Session	as nvarchar(128)	= null	-- ��� ������, c ���������� ������� Extended Event
,@Option	as nvarchar(256)	= null	-- ����� ����������:
	AS BEGIN	-- [dbo].[XE_TextData]

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

-- ********** Step 0: �������� ������������ ���������� ********** --
-- 0.1 �������������

Declare	 @Version	as nvarchar(30)		= 'XE_TextData v 5.1'
		,@Cmd		as nvarchar(max)
		,@List		as bit				= 'FALSE'	--
		,@Only		as bit				= 'FALSE'	--
		,@NoClear	as bit				= 'FALSE'	-- 
		,@Compact	as bit				= 'FALSE'	--
		,@Offset	as bigint
		,@Count		as bigint

-- 0.2 �������� ������������ � ����������� ������� ������
--					List	������ ����� ���������� ����������
--					Only	�� ��������� ������ � �������
--					NoClear (�� ������� ������� �� ���������� ������)
--					Compact (���� Text �� ��������� ��� ������� ������������)

if upper(' ' + @Option + ' ')	like upper('% ' + 'Noclear'	+ ' %') Set @NoClear	= 'TRUE'
if upper(' ' + @Option + ' ')	like upper('% ' + 'List'	+ ' %')	Set @List		= 'TRUE'
if upper(' ' + @Option + ' ')	like upper('% ' + 'Only'	+ ' %')	Set @Only		= 'TRUE'
if upper(' ' + @Option + ' ')	like upper('% ' + 'Compact'	+ ' %')	Set @Compact	= 'TRUE'

-- 0.3 �������� ������������ � ����������� ������� ������

exec [dbo].[XE_CheckParams]	 @Action = 'Session'
							,@Session = @Session output

-- ********** Step 1: ������ ������ �� XEd_Hash ********** --

Select	 [Hash#]
 		,cast(ltrim(rtrim(replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(
				replace(	 lower([TextData]) 
-- �������� ��������� � "�������" ��� �������� ��������
					,N'''exec''',	N'''����''')-- ������ �� �������� �� ������� �����
					,N'[exec]',		N'[����]')-- ������ �� �������� �� ������� �����
					,N'% exec',		N'% ����')	-- ������ �� �������� �� ������� �����
					,N'%exec',		N'%����')	-- ������ �� �������� �� ������� �����
					,char(9), ' ')
					,'[', '')
					,']', '')
					,'"', '')
					,' n''', ' ')
					,';',' ')
-- ������ ������� �� ������������� ������������
					, '        ',' ')
					, '       ',' ')
					, '      ',' ')
					, '     ',' ')
					, '    ',' ')
					, '   ',' ')
					, '  ',' ')
-- ����������� ����� ������
					,N'exec sp_execute '	, N' exec sp_execute. ')
					,N'execute sp_execute '	, N' exec sp_execute. ')
					,N' execute '			, N' exec ')
					,N' sp_execute '		, N' exec ')	
					,N' exec sp_execute. '	, N' exec sp_execute ')
		 ))	as nvarchar(max))													as [Text]
		 ,[Date]
		 ,[First_Date]
		 ,[Cnt]
	into #tmp1
	from  [dbo].[XEd_Hash] 
	where [HashText] is null


-- ********** Step 2: ����� ��������������� ����������  ********** --

Select @Count = count(1) from #tmp1

if @List = 'TRUE' exec	[dbo].[XE_PrintParams]	 @Caller		= 'XE_Import_Profiler 5.0d'
												,@Session		= @Session
												,@Count			= @Count
												,@Option		= @Option

if @Only = 'TRUE' 
	begin
		Drop table if exists #tmp1, #tmp3, #Dir, #Files;
		return
	end	

-- ********** Step 3: ��������� ����������� ���� /* ... */ ********** --
-- 3.1.	����������� ��������� ����� Text, �������� �� ������� /* �� 
--		����� ����� ([Left]) � ������ ����� ([Right])
--		����� ����� �����������, ��� [PatIndex] = 0 ��������� ���������

;With comm
as (
	Select	 [Hash#]
			,substring([Text], 1, patindex(N'%/*%',[Text]) -1)				as [Left]
			,substring([Text], patindex(N'%*/%',[Text]) + 2, 8000)+N'/**/'	as [Right] 
			,patindex(N'%/*%',substring([Text], patindex(N'%*/%',[Text]) + 2, 8000)+N'/**/') as [PatIndex]
		from (select	 [Hash#]
						,min([Text])										as [Text]
				from #tmp1 
				where [Text] like N'%/*%'
				group by [Hash#]
			) as [q0]
	union all
	select	 [Hash#]
			,[Left] +substring([Right], 1, patindex(N'%/*%',[Right]) -1) as [Left]
			,substring([Right], patindex(N'%*/%',[Right]) + 2, 8000)		as [Right] 
			,patindex(N'%/*%',substring([Right], patindex(N'%*/%',[Right]) + 2, 8000)) as [PatIndex]
		from comm
		where patindex(N'%/*%',[Right]) > 0
)

-- 3.2	���������� ���� Text � #tmp1 �� ������ [Left], 
--		���������� � ����������� ��������� comm

Update #tmp1 
	set #tmp1.[Text] = r.[Text]
	from		#tmp1 as [l]
	left join	(
				select	 [Hash#]
						,ltrim(rtrim([Left])) as [Text] 
					from comm where [PatIndex] = 0
				) as [r] 
		on	l.[Hash#] = r.[Hash#]
	 where r.[Text] is not null
	OPTION (MAXRECURSION 5000);

-- ********** Step 4. �������� �������� ������������ (���� --... ) ********** --

--	4.1 ���������� Step 3.1, �� �� �������� '--' � ������� ����� ������ char(10)
--		��������� ����� ����� ([Left]) � ������ ����� ([Right])
--		����� ����� �����������, ��� [PatIndex] = 0 ��������� ���������

;With comm
as (
	Select	 [Hash#] 
			,substring([Text], 1, patindex(N'%--%',[Text]) -1) as [Left]
			,substring(
						/*R*/substring([Text], patindex(N'%--%',[Text])+2, 8000)/*R*/
						,patindex(
							N'%' +char(10) +N'%'
							,/*R*/substring([Text], patindex(N'%--%',[Text])+2, 8000)/*R*/
							)+1
						, 8000
						)+'--' as [Right] 
			,patindex(
					N'%' +char(10) +N'%'
					,/*R*/substring([Text], patindex(N'%--%',[Text])+2, 8000)/*R*/
					) as [PatIndex]
		from	(select	 [Hash#]
						,min([Text]) as [Text]
					from #tmp1 
					where [Text] like N'%--%' 
					  and patindex(N'%''--''%', [Text]) = 0
					group by [Hash#]
				) as [q0]
	union all
	select	 [Hash#] 
			,[Left] +' ' +substring([Right], 1, patindex(N'%--%',[Right]) -1) as [Left]
			,substring(
						/*R*/substring([Right], patindex(N'%--%',[Right])+2, 8000)/*R*/
						,patindex(
							N'%'+char(10)+N'%'
							,/*R*/substring([Right], patindex(N'%--%',[Right])+2, 8000)/*R*/
							)+1
						, 8000
						) as [Right] 
			,patindex(
					N'%'+char(10)+N'%'
					,/*R*/substring([Right], patindex(N'%--%',[Right])+2, 8000)/*R*/
					) as [PatIndex]
		from comm
		where patindex(N'%--%',[Right]) > 0
)
-- 4.2.	���������� ���� Text � #tmp1 �� ������ [Left], 
--		���������� � ����������� ��������� comm

Update #tmp1
	set #tmp1.[Text] = r.[Text] 
	from		#tmp1 as [l]
	left join	(
				select	 [Hash#]
						,ltrim(rtrim([Left])) as [Text] 
					from comm where [PatIndex] = 0
				) as [r] 
		on	l.[Hash#] = r.[Hash#]
	where r.[Text] is not null
	OPTION (MAXRECURSION 5000);

-- �������� char(10) �� ������ � [Text]

Update #tmp1
	set [Text] = replace([Text], char(10), ' ');

-- ********** Step 5 ������ ������� �� ������������� �������� ********** ---

-- 5.1.	����������� ��������� ����� Text, �������� �� ������� '  ' �� 
--		����� ����� ([Left]) � ������ ����� ([Right])
--		����� ����� �����������, ��� [PatIndex] = 0 ��������� ���������

;With comm
as (
	select	 [Hash#]											as [Hash#]
			,ltrim(rtrim(replace([Text], '  ', ' ')))		as [Text]
			,patindex(N'%  %', replace([Text], '  ', ' '))	as [Flag]
		from (select	 [Hash#]
						,[Text]
				from #tmp1 
				where [Text] like N'%  %'
			   or substring([Text],1,1) = ' '
			  ) as [q0]
	union all
	select	 [Hash#]
			,replace([Text], '  ', ' ') as [Text]
			,patindex(N'%  %', replace([Text], '  ', ' '))	as [Flag]
		from comm
		where [Flag] > 0
)

-- 5.2.	���������� ���� Text � #tmp1 �� ������ [Left], 
--		���������� � ����������� ��������� comm

Update #tmp1 
	set [#tmp1].[Text] = cast(r.[Text] as nvarchar(max))
	from		#tmp1 as [l]
	right join	(
				select	 [Hash#]
						,[Text]
					from comm 
					where [Flag] = 0
				 ) as [r] 
		on	[l].[Hash#] = [r].[Hash#]
	OPTION (MAXRECURSION 5000);

-- ********** Step 6 ����� ���� �������� � ������ �� ������� �������� �� ��������� ������� ********** --
-- 6.1.	����� �����, ���������� exec ��� from � �� �������

Select	 [Hash#]
		,ltrim(rtrim(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace(
		 replace([Text]
				,char(10), ' ')
				,N'''from''',		N'''fr0m''')
				,N'from(select',	N'fr0m(select')
				,N'from (select',	N'fr0m (select')
				,N'from( select',	N'fr0m( select')
				,N'from ( select',	N'fr0m ( select')
				,N'_exec',	N'_����')
				,N'%from',	N'%fr0m')
				,N'exec,',	N'����,')
				,'(', ' ')
				,')', ' ')
				,',', ' ')
				,'''', '')
				,' =', '=')
				,'= ', '=')
		))								as [Text]
		,[Date]
		,[First_Date]
		,[Cnt]
		,HASHBYTES('SHA2_256', [Text])	as [HashText]
		into #tmp2 
		from #tmp1 

-- 6.2.	����� ������ ����� ����� �������� ���� exec � from

Select	 [Hash#] 
		,ltrim(rtrim(
		case	when [Text] like N'% from %' 
					then ltrim(rtrim(substring(
							/*S*/ltrim(rtrim(substring	([Text] + N' from ', patindex(N'% from %', [Text] +N' from ' )+5, 8000)))/*S*/
							,1
							,patindex(N'% %', /*S*/ltrim(rtrim(substring	([Text] + N' from ', patindex(N'% from %', [Text] +N' from ' )+5, 8000)))/*S*/)
							)))
						else null
					end
				)) as [Table]
	into #tmp2t
	from #tmp2
	where ' '+[Text] like '% from %';

Select	 [Hash#] 
		,ltrim(rtrim(
		case	when ' '+[Text] like N'% exec %'
					then ltrim(rtrim(substring(
								/*S*/ltrim(rtrim(substring	(' '+[Text]+ ' ', patindex(N'%exec %', ' '+[Text]+ ' ')+5, 8000)))/*S*/+' '
								,1
								,patindex(N'% %', /*S*/ltrim(rtrim(substring	(' '+[Text]+ ' ', patindex(N'%exec %', ' '+[Text]+ ' ')+5, 8000)))/*S*/+' ')
								))) 
					else null
				end 
			)) as [Exec]
	into #tmp2e
	from #tmp2
	where ' '+[Text] like '% exec %';

-- ********** Step 7 ����������� �� ����������� ���� @rc=@cmd=add_dic ********** --

Update #tmp2e 
	set [#tmp2e].[Exec] = r.[Exec]
	from		#tmp2e as [l]
	right join	(select	 [Hash#]
						,substring	(
									 [Exec]
									,len([Exec])-patindex('%=%',reverse('.'+[Exec]))+2
									,256
									) as [Exec]
					from #tmp2e
					where [Exec] like '%=%'
				 ) as [r] 
		on	[l].[Hash#] = [r].[Hash#]

-- ********** Step 8 ��������� ���������� ���� Table ********** --

-- 8.1 ��� ���� ��������

select	 [Hash#]
		,[Exec]
		,PARSENAME([Exec], 1) as [Exec_Name]
		,coalesce(PARSENAME([Exec], 2), '') as [Exec_Schema]
		,coalesce(PARSENAME([Exec], 3), '') as [Exec_DB]
		,coalesce(PARSENAME([Exec], 4), '') as [Exec_Server]
	into #tmp3e
	from #tmp2e
	where [Exec] is not null

-- 8.2 ��� ���� ������
select	 [Hash#]
		,[Table]
		,PARSENAME([Table], 1)					as [Table_Name]
		,coalesce(PARSENAME([Table], 2), '')	as [Table_Schema]
		,coalesce(PARSENAME([Table], 3), '')	as [Table_DB]
		,coalesce(PARSENAME([Table], 4), '')	as [Table_Server]
	into #tmp3t
	from #tmp2t
	where ([Table] is not null) 
	  and ([Table] <> '::')

-- ********** Step 9: ���������� ������������ �� ���������� ����� ������ ********** --

--9.1 Exec:

if @NoClear <> 'TRUE' 
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Exec]'

MERGE [dbo].[XEd_Exec] AS target
	USING	(
			SELECT	 [e].[Exec_Server]						as [Exec_Server]
					,[e].[Exec_DB]							as [Exec_DB]
					,[e].[Exec_Schema]						as [Exec_Schema]
					,[e].[Exec_Name]						as [Exec_Name]
					,max([h].[Date])						as [Date]
					,min([h].[Date])						as [First_Date]
					,count(1)								as [Cnt]
		from		#tmp1	as [h]
		left join	#tmp3e	as [e] on [h].[Hash#] = [e].[Hash#]
				where	[Exec_Name] is not null
				  and	[Exec_Name] <> ''
				GROUP BY [Exec_Server], [Exec_DB], [Exec_Schema], [Exec_Name]
			) AS source (
						 [Exec_Server]
						,[Exec_DB]
						,[Exec_Schema]
						,[Exec_Name]
						,[First_Date]
						,[Date]
						,[Cnt]
						)  
	ON (	
			target.[Exec_Server]	= source.[Exec_Server]
		and target.[Exec_DB]		= source.[Exec_DB]
		and target.[Exec_Schema]	= source.[Exec_Schema]
		and target.[Exec_Name]		= source.[Exec_Name]
		) 
	WHEN MATCHED THEN UPDATE SET
		target.[Date]		= source.[Date],
			target.[First_Date]	= case 
				when source.[First_Date] < target.[First_Date]  
					then source.[First_Date]
				else target.[First_Date]
				end,
		target.[Cnt]	= target.[Cnt] + source.[Cnt]
	WHEN NOT MATCHED  
		THEN INSERT VALUES(
							 source.[Exec_Server]
							,source.[Exec_DB]
							,source.[Exec_Schema]
							,source.[Exec_Name]
							,source.[Date]
							,source.[First_Date]
							,source.[Cnt]
							);

--9.2 Table:
if @NoClear <> 'TRUE' 
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Table]'

MERGE [dbo].[XEd_Table] AS target
	USING	(
			SELECT	 [t].[Table_Server]					as [Table_Server]
					,[t].[Table_DB]						as [Table_DB]
					,[t].[Table_Schema]					as [Table_Schema]
					,[t].[Table_Name]					as [Table_Name]
					,max([h].[Date])					as [Date]
					,min([h].[Date])					as [First_Date]
					,count(1)							as [Cnt]
		from		#tmp1	as [h]
		left join	#tmp3t	as [t] on [h].[Hash#] = [t].[Hash#]
				where	[Table_Name] is not null
				  and	[Table_Name] <> ''
				GROUP BY [Table_Server], [Table_DB], [Table_Schema], [Table_Name]
			) AS source (
						 [Table_Server]
						,[Table_DB]
						,[Table_Schema]
						,[Table_Name]
						,[Date]
						,[First_Date]
						,[Cnt]
						)  
	ON (
			target.[Table_Server] = source.[Table_Server]
		and target.[Table_DB] = source.[Table_DB]
		and target.[Table_Schema] = source.[Table_Schema]
		and target.[Table_Name] = source.[Table_Name]
		) 
	WHEN MATCHED THEN UPDATE SET
		target.[Date]		= source.[Date],
			target.[First_Date]	= case 
				when source.[First_Date] < target.[First_Date]  
					then source.[First_Date]
				else target.[First_Date]
				end,
		target.[Cnt]	= target.[Cnt] + source.[Cnt]
	WHEN NOT MATCHED  
		THEN INSERT VALUES(
							 source.[Table_Server]
							,source.[Table_DB]
							,source.[Table_Schema]
							,source.[Table_Name]
							,source.[Date]
							,source.[First_Date]
							,source.[Cnt]
							);

--9.3 Hash:

if @NoClear <> 'TRUE' 
	execute [dbo].[XE_ExecLog]	 @Proc = '[dbo].[XE_Clear]', @Caller = @Version
								,@Session = @Session
								,@Option = @Option
								,@Table = '[dbo].[XEd_Hash]'

MERGE [dbo].[XEd_Hash] AS target
	USING	(
			SELECT	 [r].[Hash#]						as [Hash#]
					,null								as [Hash]
					,[r].[HashText]						as [HashText]
					,min([e].[Exec#])					as [Exec#]
					,min([t].[Table#])					as [Table#]
					,null								as [Is_system]
					,null								as [Date]
					,null								as [First_Date]
					,null								as [Cnt]
					,null								as [TextData]
					,min([Text])						as [Text]
	from		#tmp2				as [r]
	left join	#tmp3e				as [re]	on [r].[Hash#]	= [re].[Hash#]
	left join	#tmp3t				as [rt]	on [r].[Hash#]	= [rt].[Hash#]
	left join	[dbo].[XEd_Exec]	as [e]	on (
													[e].[Exec_Server]	= [re].[Exec_Server]
												and [e].[Exec_DB]		= [re].[Exec_DB]
												and [e].[Exec_Schema]	= [re].[Exec_Schema]
												and [e].[Exec_Name]		= [re].[Exec_Name]
												)
	left join	[dbo].[XEd_Table]	as [t]	on (
													[t].[Table_Server]	= [rt].[Table_Server]
												and [t].[Table_DB]		= [rt].[Table_DB]
												and [t].[Table_Schema]	= [rt].[Table_Schema]
												and [t].[Table_Name]	= [rt].[Table_Name]
												)
				GROUP BY [r].[Hash#], [r].[HashText]
			) AS source (
						 [Hash#]
						,[Hash]
						,[HashText]
						,[Exec#]
						,[Table#]
						,[Is_system]
						,[Date]
						,[First_Date]
						,[Cnt]
						,[TextData]
						,[Text]
						)  
	ON target.[Hash#] = source.[Hash#]
	WHEN MATCHED THEN UPDATE SET
		 target.[Exec#]		= source.[Exec#]
		,target.[Table#]	= source.[Table#]
		,target.[Text]		= case when @Compact = 'TRUE' then null else source.[Text] end
		,target.[HashText]	= HASHBYTES('SHA2_256',source.[Text]);

-- ********** Step 10: ������� �� ����������  ********** --

Drop table if exists #tmp1, #tmp2, #tmp2e, #tmp2t, #tmp3e, #tmp3t 

END --  [dbo].[XE_TextData]