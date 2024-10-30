/* =============================================
-- Author:		Sotivoli
-- Create date: 18 August 2024
-- Description:	Копирование таблиц из списка в таблицы с префиксом
-- =============================================
exec [dbo].[BaReTa] @Option	= N' list \only Noreplace'
	,@Action	= N' Backup \Restore \Clear '
	,@Table		= N'Dic_Application Dic_Database Dic_Event Dic_Exec Dic_Hash Dic_Host Dic_Server Dic_Source Dic_Table Dic_User Log_Set Log_Sum Log_Top Log_XE Log_XE_Sotivoli'
	,@Prefix	= N'[Back_DEM].[dbo].[4_4_Backup_]'
-- ============================================= */
--	Declare
	drop procedure if exists	[dbo].[BaReTa]
GO
	CREATE	PROCEDURE			[dbo].[BaReTa]
--	ALTER	PROCEDURE			[dbo].[BaReTa]
		 @Option	as nvarchar(128)	= null
		,@Action	as nvarchar(128)	= null
		,@Prefix	as nvarchar(128)	= 'BaReTa_'
		,@Table		as nvarchar(max)	
	AS BEGIN
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

Declare	 @Version	as nvarchar(30)	= 'BaReTa v 5.0p'
		,@Pos		as int
		,@Cmd		as nvarchar(max)
		,@Name		as nvarchar(128)
		,@BaName	as nvarchar(128)
		,@ReName	as nvarchar(128)

		,@Clear		as bit	= 'False'
		,@Backup	as bit	= 'False'
		,@Restore	as bit	= 'False'
		,@Replace	as bit	= 'False'
		,@List		as bit	= 'False'
		,@Only		as bit	= 'False'

set @Table = coalesce(@Table, '')

if upper(' ' + @Action + ' ') like upper('% ' + N'Backup'	+ N' %')	set @Backup		= 'True'
if upper(' ' + @Action + ' ') like upper('% ' + N'Restore'	+ N' %')	set @Restore	= 'True'
if upper(' ' + @Action + ' ') like upper('% ' + N'Clear'	+ N' %')	set @Clear		= 'True'
if upper(' ' + @Option + ' ') like upper('% ' + N'Replace'	+ N' %')	set @Replace	= 'True'
if upper(' ' + @Option + ' ') like upper('% ' + N'List'		+ N' %')	set @List		= 'True'
if upper(' ' + @Option + ' ') like upper('% ' + N'Only'		+ N' %')	set @Only		= 'True'

if (cast(@Backup as int) + cast(@Restore as int) + cast(@Clear as int)) > 1 or (@Backup | @Restore | @Clear) = 'False'
		begin
			set @Cmd = nchar(0x26a0) + nchar(0x26a0) + nchar(0x26a0) 
					+N'   ' + @Version + ' Error: Недопустимый параметр / комбинация параметра,'
					+N' либо не определено действие в параметре @Option="' + @Option + '"'
			RAISERROR(@Cmd, 16, 1)
			return
		end

if @List = 'True' print
 N'***   ' + @Version + '   Параметры выполнения:'
+nchar(13) +N'***                        Действие:' + case 
											when @Backup	= 'True' then ' Backup '     
											when @Restore	= 'True' then ' Restore '     
											when @Clear		= 'True' then ' Clear '     
										end
+nchar(13) +N'***           Префикс таблиц Backup:' + coalesce(@Prefix, '<null>')
+nchar(13) +N'***        Замещать имеющиеся файлы:' + case
														when @Replace = 'True' then ' Замещать '
														else ' Пропускать '
													end
+nchar(13) +N'***        Выполнять ли копирование:' + case
														when @Only = 'False' then ' Выполнять '
														else ' Не выполнять, только вывод информации '
													end

-- ********** Step 1: Цикл по именам таблиц в @Table ********** --

Set @Table = ltrim(rtrim(replace(replace(replace(replace(@Table, ',', ' '), char(10), ' '), char(13), ' '), CHAR(9), ' ')))

while LEN(@Table) > 0
begin	-- @Table

-- 1.1  Вычленяем имя таблицы из списка @Table

	Set @Pos = CHARINDEX(' ', @Table)
	if @Pos > 0 
			begin
				Set @Name = left(@Table, @Pos-1)
				Set @Table = ltrim(rtrim(right(@Table, len(@Table) - @Pos)))
			end
		else 
			begin
				Set @Name = @Table
				Set @Table = '' 
			end

-- 1.2 Формируем имена таблиц в источнике (@ReName) и для бекапа (@BaName) 

	Set @BaName = N'' + case when parsename(@Prefix,3) is null
							then QUOTENAME(coalesce(parsename(@Name, 3), db_name()))
							else QUOTENAME(coalesce(parsename(@Prefix, 3), db_name()))
						  end
					+N'.'
					+case when parsename(@Prefix, 2) is null
							then QUOTENAME(coalesce(parsename(@Name, 2), schema_name()))
							else QUOTENAME(coalesce(parsename(@Prefix, 2), schema_name()))
						  end
					+N'.'
					+QUOTENAME(coalesce(parsename(@Prefix, 1), 'BaReTa_') + parsename(@Name, 1))

	Set @ReName =	QUOTENAME(coalesce(parsename(@Name, 3), db_name()))
					+'.'
					+QUOTENAME(coalesce(parsename(@Name, 2), schema_name()))
					+'.'
					+QUOTENAME(parsename(@Name, 1))

	if @List = 'True'
		print	 N'***      Таблица: "' + coalesce(@Name,  N'<null>') 
				+N'" ("' + coalesce(@ReName, '<null>')  
				+ '" / "' + coalesce(@BaName, '<null>') + '")'

-- 1.3 Выполнение очистки таблицы бекапа (@Action = Clear)

	if @Clear = 'TRUE'
		begin	-- Clear
			Set @Cmd = N'Drop table if exists '  + @BaName
			if @List = 'True' print N'***      Drop Table ' + @BaName
			if @Only = 'False' execute sp_executesql @Cmd
		end		-- Clear

-- 1.4 Резервное копирование таблицы (@Action = Backup)
	
	set @Cmd = N'create database ' + PARSENAME(@BaName, 3)
	if (SELECT [name] 
			FROM [sys].[databases]
			where [name] = PARSENAME(@BaName, 3)) is null 
		execute sp_executesql @Cmd

	if @Backup = 'TRUE'
		begin	-- Backup
			if @Only = 'True' print '***   План копирования: ' + @ReName + ' ===> ' + @BaName
				else begin -- Копирование  Backup
--VVVV Backup VVVV --
if OBJECT_ID (@ReName, N'U') IS NULL

	begin	-- @Table isn't exist
		print	 nchar(0x26a0) + nchar(0x26a0) + nchar(0x26a0) 
		+N'              : Исходная таблица ' 
		+ @ReName +N' не существует, копирование прервано'
	end		-- @Table isn't exist

	else begin	-- @Table exist
		Set @Cmd =   N'drop table if exists ' + @BaName
		if @Replace = 'True' execute sp_executesql @Cmd
		
		if OBJECT_ID(@BaName, N'U') is not null
			begin	-- что то не то...
				set @Cmd = nchar(0x26a0) + nchar(0x26a0) + nchar(0x26a0) 
						+N'   ' + @Version + ' Error: Невозможно скоприровать таблицу '
						+@ReName
						+N' так как целевая таблица' + @BaName + ' уже существует, '
						+N' а опция Replace не задана'
				RAISERROR(@Cmd, 16, 1)
				return
			end -- что то не то...
			
			Set @Cmd =	N'select * into ' + @BaName +N' from ' + @ReName
			execute sp_executesql @Cmd

			print '***        Копирование: ' + @ReName + ' ===> ' + @BaName 

	end		-- @Table exist
-- ^^^ Backup ^^^ --

			end	-- Копирование Backup
		end		-- Backup	

-- 1.4 Восстановление таблиц (Restore)
	
	if @Restore = 'TRUE'
		begin	-- Restore
			if @Only = 'True' print '***   План восстановления: ' + @BaName + ' ===> ' + @ReName
				else begin -- Копирование  Restore
--VVVV Restore VVVV --
if OBJECT_ID (@BaName, N'U') IS NULL

	begin	-- @Table isn't exist
		print	 nchar(0x26a0) + nchar(0x26a0) + nchar(0x26a0) 
		+N'              : Таблица  бекапа ' 
		+ @BaName +N' не существует, восстановление прервано'
	end		-- @Table isn't exist

	else begin	-- @Table exist
		Set @Cmd =   N'drop table if exists ' + @ReName
		if @Replace = 'True' execute sp_executesql @Cmd
		
		if OBJECT_ID(@ReName, N'U') is not null
			begin	-- что то не то...
				set @Cmd = nchar(0x26a0) + nchar(0x26a0) + nchar(0x26a0) 
						+N'   ' + @Version + ' Error: Невозможно восстановить из таблицы '
						+@BaName
						+N' так как целевая таблица' + @ReName + ' уже существует, '
						+N' а опция Replace не задана'
				RAISERROR(@Cmd, 16, 1)
				return
			end -- что то не то...
			
			Set @Cmd =	N'select * into ' + @ReName +N' from ' + @BaName
			execute sp_executesql @Cmd

			print '***        Копирование: ' + @BaName + ' ===> ' + @ReName 

	end		-- @Table exist
-- ^^^ Restore ^^^ --

			end	-- Копирование Restore
		end		-- Restore	

end	-- @Table

	END		-- [dbo].[BaReTa]
