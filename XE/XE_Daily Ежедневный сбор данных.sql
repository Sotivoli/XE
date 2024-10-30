/* =============================================	
-- Author:		Sotivoli
-- Create date: 12 August 2024
-- Description:	Ежедневная обработка данных XE
-- =============================================
exec [dbo].[XE_Daiy]	 @Session	= null
						
-- ============================================= */

--	Declare
	drop procedure if exists	[dbo].[XE_Daiy]
GO
	CREATE	PROCEDURE			[dbo].[XE_Daiy]
 @Session		nvarchar(256)	= null	-- Имя сессии XE
,@Source		nvarchar(max)	= null	-- 'C:\'	-- Путь хранения файлов XE
,@Table			nvarchar(256)	= null	-- 'Dic'	-- Имя базы данных для всех записей (базовая)
,@Steps			nvarchar(max)	= null	-- Перечень выполняемых шагов, по умолчанию - все шаги 
,@Option		nvarchar(256)	= 'Compact'
	AS BEGIN
		
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;

declare	 @Version	nvarchar(30)	= 'XE_Daily v 5.0.p'
		
-- ********** Обработка статистики запросов за один день ********** --
--
--  ⚠ Отбор идет по дате завершения запроса, т.к. только такой вариант
--		позволяет избежать дублирования запросов, выполняющихся на 
--		границе суток

-- 1. Сохранение данных из файлов XE (@Source) в таблицу полных данных @Table

if	(@Steps is null) or (upper(' '+@Steps+' ') like '% XEL %')
	execute [dbo].[XE_ExecLog]	 @Proc		= '[dbo].[XE_Xel]', @Caller	= @Version
								,@Comm		= N'Ежедневный сбор данных сессии по умолчанию'
								,@Option	= @Option
								,@Session	= @Session
								,@Source	= @Source
								,@Table		= @Table

-- 2. Обработка полей TextData (только если для п.1 указана опция Skip)

if	(@Steps is null) or (upper(' '+@Steps+' ') like '% TEXTDATA %')
and (upper(' ' + @Option + ' ') like upper('% ' + 'Skip' + ' %'))
	execute [dbo].[XE_ExecLog]	 @Proc		= '[dbo].[XE_TextData]', @Caller	= @Version
								,@Comm		= N'Ежедневеное уточнение полей по TextData'
								,@Option	= @Option
								,@Session	= null

-- 3. Заполнение таблиц XE_Sum и XE_Top

if	(@Steps is null) 
	or (upper(' '+@Steps+' ') like '% TOP %')
	or (upper(' '+@Steps+' ') like '% SUM %')
	or (upper(' '+@Steps+' ') like '% TOPSUM %')
	or (upper(' '+@Steps+' ') like '% SUMTOP %')
	execute [dbo].[XE_ExecLog]	 @Proc		= '[dbo].[XE_TopSum]', @Caller	= @Version
								,@Comm		= N'Ежедневное обновление таблиц XE_Sum и XE_Top'
								,@Option	= @Option
								,@Session	= null
								,@Table		= @Table

END