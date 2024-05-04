-- 第四章
-- 普通堆表，全局临时表，分区表，索引组织表，簇表

-- 4-1 查看产生多少日志
select a.name,b.value from 
v$statname a,v$mystat b -- 动态性能视图
where a.statistic#=b.statistic#
and a.name='redo size';

-- 4-2 构建观察redo的视图(sysdba)
grant all on v_$mystat to ljb;
grant all on v_$statname to ljb;
-- 连接ljb
drop table t purge;
create table t as select * from dba_objects;
create or replace view v_redo_size as select 
a.name,b.value from v$statname a,v$mystat b where 
a.statistic#=b.statistic#
and a.name='redo size';

-- 4-3 观察删除记录产生多少redo
select * from v_redo_size; --379756
delete from t;
select * from v_redo_size; -- 11497268

-- 4-4 观察插入记录产生多少redo
insert into t select * from dba_objects;
select * from v_redo_size; -- 22761524

-- 4-5 更新记录redo
update t set object_id = rownum;
select * from v_redo_size; -- 32892176

-- 4-6 未删除表时产生的逻辑读
drop table t purge;
create table t as select * from dba_objects;
set autotrace on
select count(*) from t; -- 1790次逻辑读

-- 4-7 delete表t后的逻辑读不变
set autotrace off 
delete from t;
commit;
set autotrace on
select count(*) from t; -- 1418次逻辑读

-- 4-8 truncate清空表 逻辑读减少
truncate table t;
select count(*) from t; -- 逻辑读1

-- 4-9 观察table access by index rowid产生的开销
drop table t purge;
create table t as select * from dba_objects where rownum<=200;
create index idx_obj_id on t(object_id);
set linesize 1000
set autotrace traceonly
select * from t where object_id<=10;

-- 4-10 观察如果消除table access by index rowid产生的开销
select object_id from t where object_id<=10;

-- 4-11 测试表记录顺序插入难以保证顺序读出
drop table t purge;
create table t
(
a int,
b varchar2(4000) default rpad('*',4000,'*'),
c varchar2(3000) default rpad('*',3000,'*')
);
insert into t(a) values(1);
insert into t(a) values(2);
insert into t(a) values(3);
select A from t;
delete from t where a=2;
insert into t(a) values(4);
commit;
select A from t;

-- 4-13 基于事务和Session的全局临时表
drop table t_tmp_seession purge;
drop table t_tmp_transaction purge;
create global temporary table t_tmp_session on commit preserve rows
as select * from dba_objects where 1=2;
select table_name,temporary,duration from user_tables where table_name='T_TMP_SESSION';
create global temporary table t_tmp_transaction on commit delete rows as 
select * from dba_objects where 1=2;
select table_name,temporary,duration from user_tables where table_name='T_TMP_TRANSACTION';

-- 4-16 基于事务的全局临时表的高效删除
select count(*) from t_tmp_transaction;
select * from v_redo_size;
insert into t_tmp_transaction select * from dba_objects;
select * from v_redo_size;
commit;
select count(*) from t_tmp_transaction;

-- 基于Session的全局临时表commit不清空记录
select * from v_redo_size;
insert into t_tmp_session select * from dba_objects;
select * from v_redo_size;
commit;
select count(*) from t_tmp_session;

-- 4-19 基于全局临时表的会话独立性之观察第一个session
select * from v$mystat where rownum=1;
select * from t_tmp_session;
insert into t_tmp_session select * from dba_objects;
commit;
select count(*) from t_tmp_session;

-- 4-21 范围分区示例
drop table range_part_tab purge;
create table range_part_tab(id number,deal_date date,area_code number,
contents varchar2(4000)) partition by range(deal_date)
(
partition p1 values less than (TO_DATE('2024-01-01','YYYY-MM-DD')),
partition p2 values less than (TO_DATE('2024-02-01','YYYY-MM-DD')),
partition p3 values less than (TO_DATE('2024-03-01','YYYY-MM-DD')),
partition p4 values less than (TO_DATE('2024-04-01','YYYY-MM-DD')),
partition p5 values less than (TO_DATE('2024-05-01','YYYY-MM-DD')),
partition p6 values less than (TO_DATE('2024-06-01','YYYY-MM-DD')),
partition p7 values less than (TO_DATE('2024-07-01','YYYY-MM-DD')),
partition p8 values less than (TO_DATE('2024-08-01','YYYY-MM-DD')),
partition p9 values less than (TO_DATE('2024-09-01','YYYY-MM-DD')),
partition p10 values less than (TO_DATE('2024-10-01','YYYY-MM-DD')),
partition p11 values less than (TO_DATE('2024-11-01','YYYY-MM-DD')),
partition p12 values less than (TO_DATE('2024-12-01','YYYY-MM-DD')),
partition p_max values less than(maxvalue)
)
;

insert into range_part_tab(id,deal_date,area_code,contents)
select rownum,to_date(to_char(sysdate-365,'J')+TRUNC(DBMS_RANDOM.VALUE(0,365)),'J'),
ceil(dbms_random.value(590,599)),
rpad('*',400,'*') from dual
connect by rownum<=100000;
commit;

-- 4-25 分别建索引组织表和普通表
drop table head_addresses purge;
drop table iot_addresses purge;
create table head_address
(
empno number(10),
addr_type varchar2(10),
street varchar2(10),
city varchar2(10),
state varchar2(2),
zip number,
primary key(empno)
);

create table iot_addresses
(
empno number(10),
addr_type varchar2(10),
street varchar2(10),
city varchar2(10),
state varchar2(2),
zip number,
primary key(empno)
)
organization index
;

insert into head_addresses
select object_id,'WORK','123street','washington','DC',20123 from all_objects;

insert into iot_addresses
select object_id,'WORK','123street','washington','DC',20123 from all_objects;