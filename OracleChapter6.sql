-- 第6章 经典，表的连接学以致用

-- 6-1 Nested Loops Join访问次数的准备
drop table t1 cascade constraints purge;
drop table t2 cascade constraints purge;
create table t1 (
id number not null,
n number,
contents varchar2(4000)
);
create table t2 (
id number not null,
t1_id number not null,
n number,
contents varchar2(4000)
);
execute dbms_random.seed(0);
insert into t1
select rownum,rownum,dbms_random.string('a',50)
from dual
connect by level <= 100
order by dbms_random.random;

insert into t2
select rownum,rownum,rownum,dbms_random.string('b',50)
from dual
connect by level <= 100000
order by dbms_random.random;

select count(*) from t1;
select count(*) from t2;

-- 6-2 Nested Loops Join
select /*+leading(t1) use_nl(t2)*/ * -- use_nl 强制嵌套循环连接
from t1,t2 where t1.id=t2.id;
set linesize 1000
alter session set statistics_level=all;

select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));

-- 6-7 Hash Join
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
select /*+leading(t1) use_hash(t2)*/ *
from t1,t2 where t1.id=t2.t1_id;

-- 6-17 Merge Sort Join取所有字段
select * from table(dbms_xplan.display_cursor(null,null,'allstats last')); -- 8677k 2048
select /*+leading(t2) use_merge(t1)*/ *
from t1,t2 where t1.id=t2.t1_id and t1.n=19;

-- 6-18 Merge Sort Join取部分字段
select * from table(dbms_xplan.display_cursor(null,null,'allstats last')); -- 2188k 2048
select /*+leading(t2) use_merge(t1)*/ t1.id
from t1,t2 where t1.id=t2.t1_id and t1.n=19;

-- 6-19 Hash Join不支持不等值连接条件
explain plan for 
select /*+leading(t1) use_hash(t2)*/ *
from t1,t2
where t1.id<>t2.t1_id and t1.n=19;
select * from table(dbms_xplan.display); -- 为NL连接查询

-- 6-20 Hash Join不支持大于或小于的连接条件
explain plan for 
select /*+leading(t1) use_hash(t2)*/ *
from t1,t2
where t1.id>t2.t1_id and t1.n=19;
select * from table(dbms_xplan.display); 

-- 6-21 Hash Join不支持like的连接条件
explain plan for 
select /*+leading(t1) use_hash(t2)*/ *
from t1,t2
where t1.id like t2.t1_id and t1.n=19;
select * from table(dbms_xplan.display);

-- 哈希连接不支持不等值连接<>，不支持>和<的连接方式，也不支持like的连接方式
-- 排序合并连接不支持不等值连接<>，不支持like，支持>和<
-- 嵌套循环支持所有的SQL连接

-- 6-25 Nested Loops Join两表无索引试验
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));

select /*+leading(t1) use_nl(t2)*/ * from
t1,t2 where t1.id=t2.t1_id and t1.n=19;

-- 6-26 无索引不用HINT
select * from
t1,t2 where t1.id=t2.t1_id and t1.n=19; -- 走hash join

-- 6-27 创建索引
create index t1_n on t1(n);

-- 6-28 Nested Loops Join性能提升
select /*+leading(t1) use_nl(t2)*/ * from t1,t2 where t1.id=t2.t1_id and t1.n=19;

-- 6-29 构建t2的索引
create index t2_t1_id on t2(t1_id);

-- 嵌套循环连接要在驱动表的限制条件加索引，在被驱动表的连接查询条件加索引