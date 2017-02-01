--Getting blocking chains headers
select blocking.session_id, program_name, login_name, status
from sys.dm_exec_sessions blocking inner join sys.dm_os_waiting_tasks blocked
on blocked.blocking_session_id = blocking.session_id and blocked.blocking_session_id <> blocked.session_id
where blocking.session_id not in (select session_id from sys.dm_os_waiting_tasks where blocking_session_id <> session_id)


--Getting details about sessions that are in sleep status, but still hold key and page locks
select distinct  des.session_id, program_name, login_name, resource_associated_entity_id, resource_type, request_mode, so.name, 
schema_name(so.schema_id) as SchemaName, text
from sys.dm_tran_locks dtl inner join sys.dm_exec_sessions des on dtl.request_session_id = des.session_id 
inner join sys.partitions p on p.hobt_id = dtl.resource_associated_entity_id
inner join sys.objects so on p.object_id = so.object_id
inner join sys.dm_exec_connections dec on dec.session_id = des.session_id
cross apply sys.dm_exec_sql_text(most_recent_sql_handle)
where resource_type <> 'DATABASE' and des.status = 'sleeping'
and resource_type in ('KEY', 'PAGE')
order by 1 desc


--findout if there is a sleeping session that has an open transaction
select * from master.dbo.sysprocesses where open_tran > 0 and status = 'sleeping'


--Getting the details about locks that were not granted
select  * from sys.dm_tran_locks where request_status <> 'GRANT' or request_status is null


--get blocked processes information
select des.program_name,  dowt.*, dest.text as FullObjectDeff, substring(dest.text, statement_start_offset / 2, 
case when statement_end_offset = -1 then len(text) else statement_end_offset / 2 - statement_start_offset /2 end) as SQLStatement
from sys.dm_os_waiting_tasks dowt inner join sys.dm_exec_requests der on dowt.session_id = der.session_id
inner join sys.dm_exec_sessions des on des.session_id = der.session_id
cross apply sys.dm_exec_sql_text (der.sql_handle) as dest
where dowt.session_id > 49

--Get sql statement for blocking process
;With MyCTE as (
	select blocking.session_id, program_name, login_name, status
	from sys.dm_exec_sessions blocking inner join sys.dm_os_waiting_tasks blocked
	on blocked.blocking_session_id = blocking.session_id and blocked.blocking_session_id <> blocked.session_id
	where blocking.session_id not in (select session_id from sys.dm_os_waiting_tasks where blocking_session_id <> session_id))
select MyCTE.*, text as BlockingChainHeader_DEFF
from MyCTE inner join sys.dm_exec_connections dec on MyCTE.session_id = dec.session_id 
CROSS APPLY sys.dm_exec_sql_text (dec.most_recent_sql_handle)




