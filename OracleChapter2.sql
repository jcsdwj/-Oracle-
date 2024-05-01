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

-- SGA 开辟空间大小
-- show PARAMETER sga;

-- PGA开辟空间大小
-- show parameter pga;

-- 共享池和数据缓冲区大小
-- show parameter shared_pool_size;
-- show parameter db_cache_size;

-- 日志缓存区大小
-- show parameter log_buffer;

-- 问题：日志缓冲区满了会怎么样，例如填满15MB
-- 答：触发LGWR进程，写入磁盘

-- 查看Oracle实例名
-- show parameter instance_name;

-- 查看数据库归档是开启还是关闭(管理员权限)
-- archive log list;

-- 参数文件位置
-- show parameter spfile;

-- 控制文件位置
-- show parameter control;

-- 数据文件位置(管理员权限)
-- select file_name from dba_data_files;

-- 日志文件位置
-- select group#,member from v$logfile;

-- 归档文件位置
-- show parameter recovery;

-- 告警日志文件
-- show parameter dump;

drop table t purge;
create table t(x int);
-- 清空共享池
alter system flush shared_pool ;

-- 将1到10万插入t表的存储过程
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
-- sql plus执行
-- SET timing ON;
-- EXEC proc1;
begin
	proc1;
END;

SELECT count(*) FROM t;

-- 查询proc1在数据库共享池中执行的情况
SELECT t.sql_text,t.sql_id,t.parse_calls,t.executions
FROM v$sql t
WHERE sql_text LIKE '%insert into t values%';

-- 绑定变量优化
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

DROP TABLE t purge;

CREATE TABLE t (x int);

ALTER system flush shared_pool;

-- set timing on;

begin
	proc2;
END;
-- exec proc2;
select count(*) from t;

-- 静态SQL（编译的过程就解析好了）
CREATE OR REPLACE PROCEDURE proc3
AS 
BEGIN 
	FOR i IN 1 .. 100000
	LOOP 
		insert into t values(i);
	COMMIT;
	END LOOP;
END; 
DROP TABLE t purge;

CREATE TABLE t (x int);

ALTER system flush shared_pool;

set timing on
exec proc3;

select count(*) from t;

SELECT t.sql_text,t.sql_id,t.parse_calls,t.executions
FROM v$sql t
WHERE sql_text LIKE '%insert into t values%';

CREATE OR REPLACE PROCEDURE proc4
AS 
BEGIN 
	FOR i IN 1 .. 100000
	LOOP 
		insert into t values(i);
	END LOOP;
    COMMIT;
END; 
DROP TABLE t purge;

CREATE TABLE t (x int);

ALTER system flush shared_pool;

--set timing on
exec proc4; -- 2s

select count(*) from t;

-- 集合写法
DROP TABLE t purge;

CREATE TABLE t (x int);

ALTER system flush shared_pool;

--set timing on
insert into t select rownum from dual connect by level<=100000;

select count(*) from t;

-- 
DROP TABLE t purge;

CREATE TABLE t (x int);

ALTER system flush shared_pool;

-- set timing on
insert into t select rownum from dual connect by level<=10000000;