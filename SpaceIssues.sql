
---see the space that each table uses and to which file group it belongs
SELECT schema_name(schema_id) + '.' + o.name as TableName,
CONVERT(numeric(15,2),(((CONVERT(numeric(15,2),SUM(i.reserved)) * 8192) / 1024)/1024)) AS TotalSpaceUsedInMB,
f.name As FileGroupName
FROM sys.sysindexes i (NOLOCK) INNER JOIN sys.objects o (NOLOCK) ON i.id = o.object_id  INNER JOIN sys.filegroups f ON i.groupid = f.data_space_id
WHERE indid IN (0, 1, 255)
AND i.groupid = f.data_space_id
GROUP BY o.schema_id, o.name, f.name
ORDER BY TotalSpaceUsedInMB DESC




--Space per file - How much space is allocated, used and free for each file
SELECT  b.groupname AS 'File Group',Name, [Filename],
CONVERT(Decimal(15,2),ROUND(a.Size/128.000,2)) [Currently Allocated Space
(MB)],
CONVERT(Decimal(15,2),ROUND(FILEPROPERTY(a.Name,'SpaceUsed')/128.000,2)) AS
[Space Used (MB)],
CONVERT(Decimal(15,2),ROUND((a.Size-FILEPROPERTY(a.Name,'SpaceUsed'))/128.000,2))
AS [Available Space (MB)]
FROM dbo.sysfiles a (NOLOCK)
LEFT JOIN sysfilegroups b (NOLOCK)
ON a.groupid = b.groupid
ORDER BY b.groupname


--Find out details about AutoGrow in your DB
DECLARE @curr_tracefilename VARCHAR(500);
DECLARE @base_tracefilename VARCHAR(500);
DECLARE @indx INT;

SELECT @curr_tracefilename = PATH
FROM   sys.traces
WHERE  is_default = 1;

SET @curr_tracefilename = reverse(@curr_tracefilename);

SELECT @indx = patindex('%\%', @curr_tracefilename);

SET @curr_tracefilename = reverse(@curr_tracefilename);
SET @base_tracefilename = LEFT(@curr_tracefilename, len(@curr_tracefilename) - @indx) + '\log.trc';

SELECT ( dense_rank() OVER (ORDER BY StartTime DESC) )%2 AS l1,
       CONVERT(INT, EventClass)                          AS EventClass,
       DatabaseName,
       Filename,
       ( Duration / 1000 )                               AS Duration,
       StartTime,
       EndTime,
       ( IntegerData * 8.0 / 1024 )                      AS ChangeInSize
FROM   ::fn_trace_gettable(@base_tracefilename, DEFAULT)
WHERE  EventClass >= 92
   AND EventClass <= 95
--   AND ServerName = @@SERVERNAME
--   AND DatabaseName = db_name()
--AND Filename = 'tradonomiHistory' --If you need the infor for one file, change the filename.  if you want for all files, remark the line
ORDER  BY StartTime DESC 


select min(StartTime) from ::fn_trace_gettable(@base_tracefilename, DEFAULT)
go

--see the drives and the free space that you have
exec xp_fixeddrives

--find out the size of each log and how much is used from the log
dbcc sqlperf('logspace')

--Check pages allocations in tempdb
select * from sys.dm_db_file_space_usage 


--Check pages allocations in tempdb per session_id
select * from sys.dm_db_task_space_usage 
go
---------------

--Getting details about configured file growth for all databases
-- Drop temporary table if it exists
IF OBJECT_ID('tempdb..#info') IS NOT NULL
       DROP TABLE #info;
 
-- Create table to house database file information
CREATE TABLE #info (
     databasename VARCHAR(128)
     ,name VARCHAR(128)
    ,fileid INT
    ,filename VARCHAR(1000)
    ,filegroup VARCHAR(128)
    ,size VARCHAR(25)
    ,maxsize VARCHAR(25)
    ,growth VARCHAR(25)
    ,usage VARCHAR(25));
    
-- Get database file information for each database   
SET NOCOUNT ON; 
INSERT INTO #info
EXEC sp_MSforeachdb 'use ? 
select ''?'',name,  fileid, filename,
filegroup = filegroup_name(groupid),
''size'' = convert(nvarchar(15), convert (bigint, size) * 8 / 1024)  + N'' MB'',
''maxsize'' = (case maxsize when -1 then N''Unlimited''
else
convert(nvarchar(15), convert (bigint, maxsize) * 8) + N'' KB'' end),
''growth'' = (case status & 0x100000 when 0x100000 then
convert(nvarchar(15), growth) + N''%''
else
convert(nvarchar(15), convert (bigint, growth) * 8 / 1024)  + N'' MB'' end),
''usage'' = (case status & 0x40 when 0x40 then ''log only'' else ''data only'' end)
from sysfiles
';
 
-- Identify database files that use default auto-grow properties
SELECT databasename AS [Database Name]
      ,name AS [Logical Name]
      ,filename AS [Physical File Name],
	  size
      ,growth AS [Auto-grow Setting] FROM #info 
--WHERE (usage = 'data only' AND growth = '1024 KB') 
--   OR (usage = 'log only' AND growth = '10%')
ORDER BY databasename
 
-- get rid of temp table 
DROP TABLE #info;
go