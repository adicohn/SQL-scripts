SELECT  TOP 100
         qs.execution_count,
         DatabaseName = DB_NAME(qp.dbid),
         ObjectName = OBJECT_NAME(qp.objectid,qp.dbid),
         StatementDefinition =
                SUBSTRING (
                        st.text,
                        (
                                qs.statement_start_offset / 2
                        ) + 1,
                 (
                                       (
                                               CASE qs.statement_end_offset
                         WHEN -1 THEN DATALENGTH(st.text)
                         ELSE qs.statement_end_offset
                                               END - qs.statement_start_offset
                                       ) / 2
                                ) + 1
                ),
         query_plan,
         st.text, total_elapsed_time
 FROM    sys.dm_exec_query_stats AS qs
         CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
         CROSS APPLY sys.dm_exec_query_plan (qs.plan_handle) qp
where text like '%WITH CurrencyPrice AS (%'


---------------------------------------------------------------------------------------
--Get the process that runs the master dealing query.
select * from sys.dm_exec_sessions where program_name = 'SqlReader'


select s.session_id, s.login_time, s.login_name
     , s.host_name, s.program_name, s.last_request_end_time
     , r.start_time, r.command, r.open_transaction_count
     , SUBSTRING(st.text, (r.statement_start_offset/2)+1, 
        ((CASE r.statement_end_offset
          WHEN -1 THEN DATALENGTH(st.text)
          ELSE r.statement_end_offset
          END - r.statement_start_offset)/2) + 1) as statement_text
     , coalesce(QUOTENAME(DB_NAME(st.dbid)) + N'.'
              + QUOTENAME(OBJECT_SCHEMA_NAME(st.objectid, st.dbid)) + N'.'
              + QUOTENAME(OBJECT_NAME(st.objectid, st.dbid))

              , '<Adhoc Batch>') as command_text
  from sys.dm_exec_sessions as s
  join sys.dm_exec_requests as r
    on r.session_id = s.session_id
 cross apply sys.dm_exec_sql_text(r.sql_handle) as st
where s.seesion_id = 1