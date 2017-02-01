--Check how many pages in the cache each database is using
DECLARE @total_buffer INT;

SELECT @total_buffer = cntr_value
FROM sys.dm_os_performance_counters 
WHERE RTRIM([object_name]) LIKE 'SQLServer:Buffer Manager'
AND RTRIM(LTRIM(counter_name)) = 'Database pages';


--See amount of memory and precentage of cache that is used by objects and indexes.
--you need to run it in the database that you want to check.
;WITH src AS
(
SELECT 
database_id, db_buffer_pages = COUNT_BIG(*)
FROM sys.dm_os_buffer_descriptors
--WHERE database_id BETWEEN 5 AND 32766
GROUP BY database_id
)
SELECT
[db_name] = CASE [database_id] WHEN 32767 
THEN 'Resource DB' 
ELSE DB_NAME([database_id]) END,
db_buffer_pages,
db_buffer_MB = db_buffer_pages / 128,
db_buffer_percent = CONVERT(DECIMAL(6,3), 
db_buffer_pages * 100.0 / @total_buffer)
FROM src
ORDER BY db_buffer_MB DESC; 



--select top 10 * from sys.dm_os_buffer_descriptors
WITH  CTE_1
        AS (SELECT DB_NAME() AS dbName,
                obj.name AS objectname,
                ind.name AS indexname,
                COUNT(*) AS cached_pages_count
              FROM sys.dm_os_buffer_descriptors AS bd
              INNER JOIN (SELECT object_id AS objectid,
                              OBJECT_NAME(object_id) AS name,
                              index_id,
                              allocation_unit_id
                            FROM sys.allocation_units AS au
                            INNER JOIN sys.partitions AS p
                            ON
                              au.container_id = p.hobt_id
                              AND (au.type = 1
                              OR au.type = 3)
                          UNION ALL
                          SELECT object_id AS objectid,
                              OBJECT_NAME(object_id) AS name,
                              index_id,
                              allocation_unit_id
                            FROM sys.allocation_units AS au
                            INNER JOIN sys.partitions AS p
                            ON
                              au.container_id = p.partition_id
                              AND au.type = 2
                         ) AS obj
              ON
                bd.allocation_unit_id = obj.allocation_unit_id
              LEFT OUTER JOIN sys.indexes ind
              ON
                obj.objectid = ind.object_id
                AND obj.index_id = ind.index_id
              WHERE bd.database_id = DB_ID()
                AND bd.page_type IN ('DATA_PAGE', 'INDEX_PAGE')
              GROUP BY obj.name,
                ind.name,
                obj.index_id
           )
  SELECT TOP 10 *, -- Uncomment to return the object name
      ObjPercent = CONVERT(NUMERIC(18, 2),
        (CONVERT(NUMERIC(18, 2), cached_pages_count)
        / SUM(cached_pages_count) OVER ()) * 100)
    FROM CTE_1
    ORDER BY cached_pages_count DESC;
