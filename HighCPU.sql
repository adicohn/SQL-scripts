--Get the top 30 queries in the cache that use most CPU (by avarage).  Don't forget, that you might have quries that don't have query
--plan in the cache that also can use lots of CPU, so don't base all your work on this query.
SELECT top 30
	((1.0 * qs.total_worker_time) /qs.execution_count) / 1000000.0 as AvgCPUTime, 
	Last_Execution_Time,
    substring(text,qs.statement_start_offset/2
        ,(CASE    
            WHEN qs.statement_end_offset = -1 THEN len(convert(nvarchar(max), text)) * 2 
            ELSE qs.statement_end_offset 
        END - qs.statement_start_offset)/2) as QueryText
    ,qs.plan_generation_num as recompiles
    ,qs.execution_count as execution_count
    ,qs.total_elapsed_time - qs.total_worker_time as total_wait_time
    ,qs.total_worker_time as cpu_time
    ,qs.total_logical_reads as reads
    ,qs.total_logical_writes as writes
FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    LEFT JOIN sys.dm_exec_requests r 
        ON qs.sql_handle = r.sql_handle
ORDER BY 1 DESC    --AvgCPUTime
--Order by 5 DESC  --execution_count
--order by qs.total_worker_time  desc  
go


--Get the current top sessions that use the CPU (just to get the filling how many sessions are active and how much CPU is used)
declare @t table (cpu bigint, spid int, LoginTime datetime)

insert into @t (spid, cpu, LoginTime)
select session_id, cpu_time, login_time 
from sys.dm_exec_sessions


waitfor delay '00:00:2'

select t.spid, des.cpu_time - t.cpu as cpu_used, text, statement_start_offset, statement_end_offset
from sys.dm_exec_sessions des inner join @t t on des.session_id = t.spid and des.login_time = t.LoginTime and des.cpu_time - t.cpu > 0
left join sys.dm_exec_requests der on des.session_id = der.session_id
outer apply sys.dm_exec_sql_text (sql_handle)

order by 2 desc



--You can also use this part just to see what the process that used the most CPU was running
declare @spid int
select top 1 @spid =  t.spid
from sys.dm_exec_sessions des inner join @t t on des.session_id = t.spid
order by des.cpu_time - t.cpu desc

dbcc inputbuffer (@spid)
go

exec sp_configure


exec sp_who2

--If you are working on active/active cluster check and you don't feel confident working with Cluster Admin, you can make sure that 
--you have only one node working on the phisical machine that you check by running this statements on all nodes and check
--that the value from from the serverproperty function (which gives the name of the phisical machine) returns only once.
select serverproperty('ComputerNamePhysicalNetBIOS') as PhisicalMachine, @@servername as VirtualMachine


/*
Other things that you can check:
PerfMon - Some things that can cause high CPU usage and we can get imformation about it with perfmon:
1 - Compilation and recompilation.  We can use the counters SQL Compilation/sec and SQL Re-compilation/Sec (under SQLServer:SQLStatistics).  
By the way, we can compare it to the value in the counter Batch Request/sec (under SQLServer:SQLStatistics) in order to find out about

2 - Use the profiler to check procedures and batches with fillter on CPU.  You can also use another profiler to check errors and warnings.  If you'll
check the Hash Warning, Missing Column Statistics, Missing Join Predicate and Sort Warnings (those are operations that are causes to high CPU usage)
*/