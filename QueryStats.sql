--see reads, duration, cpu usage etc' for top 10 queries according to sys.dm_exec_query_stats
select top 10 text, query_plan, total_worker_time / 1000000.0 / execution_count as AvgWorkerTime,
total_physical_reads * 1.0 / execution_count as AvgPhysicalReads,
total_logical_reads * 1.0 / execution_count as AvgLogicalReads,
total_elapsed_time / 1000000.0 / execution_count as AvgExecutionTime,
execution_count,
total_rows * 1.0 / execution_count as AvgRows
from sys.dm_exec_query_stats t cross apply sys.dm_exec_sql_text(t.sql_handle)
cross apply sys.dm_exec_query_plan (plan_handle)
where execution_count > 50
order by total_elapsed_time / 1000000.0 / execution_count desc


--check number of processes that are waiting for each wait type
with HC as (
	select sql_handle, plan_handle, count(*) as n , avg(wait_time) as wait_time 
	from sys.dm_exec_requests group by sql_handle, plan_handle)
select plan_handle, text, n, wait_time 
from HC cross apply sys.dm_exec_sql_text(sql_handle)
order by n desc


--check what is waiting for a specific wait type
with HC as (
	select r.sql_handle, r.plan_handle, count(*) as n , avg(wait_time) as wait_time 
	from sys.dm_exec_requests r inner join sys.dm_os_waiting_tasks w on r.session_id = w.session_id
	where w.wait_type = 'RESOURCE_SEMAPHORE'
	group by sql_handle, plan_handle)
select plan_handle, text, n, wait_time 
from HC cross apply sys.dm_exec_sql_text(sql_handle)
order by n desc
