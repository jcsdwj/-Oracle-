-- 2.2.2
drop table t;
create table t as select * from all_objects;
create index idx_object_id on t (object_id);
--EXPLAIN PLAN FOR

-- sql plus下可以执行
--SET AUTOTRACE ON;
--SET LINESIZE 1000;
--SET TIMING ON;
select object_name from t where object_id=29;

-- 不走索引情况
SELECT /*+full(t)*/ object_name from t where object_id=29;

--SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

-- PGA 开辟空间大小
-- show PARAMETER sga;

CREATE OR REPLACE PROCEDURE proc1
AS 
BEGIN 
	FOR i IN 1 .. 100000
	LOOP 
		EXECUTE IMMEDIATE 
		'insert into t values('||i||')';
	COMMIT;
	END LOOP;
END;

DROP TABLE t purge;

CREATE TABLE t (x int);

ALTER system flush shared_pool;

-- SET timing ON;
-- EXEC proc1;
begin
	proc1;
END;

SELECT count(*) FROM t;


SELECT t.sql_text,t.sql_id,t.parse_calls,t.executions
FROM v$sql t
WHERE sql_text LIKE '%insert into t values%';

CREATE OR REPLACE PROCEDURE proc2
AS 
BEGIN 
	FOR i IN 1 .. 100000
	LOOP 
		EXECUTE IMMEDIATE 
		'insert into t values(:x)' USING i;
	COMMIT;
		
	END LOOP;
	
END;

begin
	proc2;
END;

