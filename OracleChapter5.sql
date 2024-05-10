-- 第五章
-- 普通堆表，全局临时表，分区表，索引组织表，簇表

-- 5-1 做索引高度较低应用试验前的构造表
drop table t1 purge;
drop table t2 purge;
drop table t3 purge;
drop table t4 purge;
drop table t5 purge;
drop table t6 purge;
drop table t7 purge;

create table t1 as select rownum as id,rownum+1 as id2 from dual connect by level<=5;
create table t2 as select rownum as id,rownum+1 as id2 from dual connect by level<=50;
create table t3 as select rownum as id,rownum+1 as id2 from dual connect by level<=500;
create table t4 as select rownum as id,rownum+1 as id2 from dual connect by level<=5000;
create table t5 as select rownum as id,rownum+1 as id2 from dual connect by level<=50000;
create table t6 as select rownum as id,rownum+1 as id2 from dual connect by level<=500000;
create table t7 as select rownum as id,rownum+1 as id2 from dual connect by level<=3000000;
--create table t7 as select rownum as id,rownum+1 as id2 from dual connect by level<=5000000; -- 内存不足

-- 5-2 创建索引
create index idx_id_t1 on t1(id);
create index idx_id_t2 on t2(id);
create index idx_id_t3 on t3(id);
create index idx_id_t4 on t4(id);
create index idx_id_t5 on t5(id);
create index idx_id_t6 on t6(id);
create index idx_id_t7 on t7(id);

-- 5-3 查看索引大小
select segment_name,bytes/1024 from user_segments
where segment_name in ('IDX_ID_T1','IDX_ID_T2','IDX_ID_T3'
,'IDX_ID_T4','IDX_ID_T5','IDX_ID_T6','IDX_ID_T7');

-- 5-4 查看索引层高
select index_name,blevel,leaf_blocks,num_rows,
distinct_keys,clustering_factor from user_ind_statistics
where table_name in ('T1','T2','T3','T4','T5','T6','T7')
order by table_name
;

set autotrace traceonly
set linesize 1000
set timing on
select * from t6 where id =10;

-- 全表扫描的优势为一次性可以读多个块

-- 5-9 分区索引相关试验的准备工作
drop table part_tab purge;
create table part_tab(id int,col2 int,col3 int) -- 构建分区表part_tab
partition by range(id)
(
partition p1 values less than (10000),
partition p2 values less than (20000),
partition p3 values less than (30000),
partition p4 values less than (40000),
partition p5 values less than (50000),
partition p6 values less than (60000),
partition p7 values less than (70000),
partition p8 values less than (80000),
partition p9 values less than (90000),
partition p10 values less than (100000),
partition p11 values less than (maxvalue)
);
insert into part_tab select rownum,rownum+1,rownum+2 from dual connect by rownum<=110000;
create index idx_par_tab_col2 on part_tab(col2) local;
create index idx_par_tab_col3 on part_tab(col3);

-- 5-10 分区索引情况查看
col segment_name format a20
select segment_name,partition_name,segment_type
from user_segments where segment_name ='PART_TAB';

select segment_name,partition_name,segment_type
from user_segments where segment_name ='IDX_PAR_TAB_COL2'; --分区索引

select segment_name,partition_name,segment_type
from user_segments where segment_name ='IDX_PAR_TAB_COL3'; --全局索引

-- 5-16 count(*) 优化试验前的建表及索引
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id);
select count(*) from t;

-- count(*)在索引列有空值时无法使用索引（索引不能存空值）

-- 5-18 明确索引列非空，count(*)可以用到索引
select count(*) from t where object_id is not null;

-- 5-19 查看t表列是否为空
desc t;

-- 5-20 修改object_id的属性
alter table t modify object_id not null; -- 若列存在空值则会报错

-- 5-23 SUM/AVG 优化试验
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id);

-- 5-24 列为空SUM/AVG也用不到索引
set autotrace on
set linesize 1000
set timing on
select sum(object_id) from t; -- 这里貌似用到了（新版特性？）

select avg(object_id) from t;

select count(object_id) from t; -- count(*)不走索引但object_id走

-- 5-29 MAX性能测试
create table t_max as select * from dba_objects;
create index idx_t_max_obj on t_max(object_id);
insert into t_max select * from t_max;

select count(*) from t_max;

-- 5-30 MIN和MAX同时写的优化(空值导致用不到索引)
select min(object_id),max(object_id) from t;

-- 5-33 优化写法
select max,min 
from (select max(object_id) max from t) a,(select min(object_id) min from t) b;
-- 或者
select (select max(object_id) max from t)max_id,(select min(object_id)min from t)min_id
from dual;

-- 利用联合索引消除回表，一般超过三个字段的联合索引都是不合适的

-- 5-39 聚合因子试验准备 建立有序无序表各一张
drop table t_colocated purge;
create table t_colocated (id number,col2 varchar2(100));
begin 
    for i in 1 .. 100000
    loop
        insert into t_colocated(id,col2)
        values(i,rpad(dbms_random.random,95,'*'));
    end loop;
end;
alter table t_colocated add constraint pk_t_colocated primary key(id);
drop table t_disorganized purge;
create table t_disorganized
as select id,col2 from t_colocated order by col2;
alter table t_disorganized add constraint pk_t_disorg primary key(id);

-- 5-40 分析两张表的聚合因子情况
set linesize 1000
select index_name,blevel,leaf_blocks,num_rows,
distinct_keys,clustering_factor from user_ind_statistics
where table_name in ('T_COLOCATED','T_DISORGANIZED');

-- 5-48 DISTINCT 测试准备
drop table t purge;
create table t as select * from dba_objects;
alter table t modify object_id not null;
update t set object_id=2;
update t set object_id=3 where rownum<=25000;

-- 5-49 DISTINCT会产生排序
set autotrace traceonly
select distinct object_id from t; -- cost 622

-- 5-50 不加distinct
select object_id from t; -- cost 296

-- 5-52 为t表构建索引
create index idx_t_object_id on t(object_id);

-- 无关排序走INDEX FAST FULL SCAN 需要排序INDEX FULL SCAN

-- 5-56 UNION 需要排序
drop table t1 purge;
create table t1 as select * from dba_objects;
alter table t1 modify object_id not null;
update t1 set object_id=-1 where object_id is null;
drop table t2 purge;
create table t2 as select * from dba_objects;
update t2 set object_id=-1 where object_id is null;
alter table t2 modify object_id not null;

set linesize 1000
set autotrace traceonly
select object_id from t1
union
select object_id from t2;

-- 5-59 外键索引性能研究准备
drop table t_p cascade constraints purge;
drop table t_c cascade constraints purge;
create table t_p(id number,name varchar2(500));
alter table t_p add constraint t_p_id_pk primary key(id);
create table t_c(id number,fid number,name varchar2(500));
alter table t_c add constraint fk_t_c foreign key(fid) references t_p(id);
insert into t_p select rownum,table_name from all_tables;
insert into t_c select rownum,mod(rownum,1000)+1,object_name from all_objects;

-- 5-61 外键建索引
create index ind_t_c_fid on t_c(fid);
select a.id,a.name,b.name from t_p a,t_c b where a.id=b.fid and a.id=880;

-- 5-62 
select sid from v$mystat where rownum=1;
delete t_p where id=2000;

-- 5-63 删除外键索引
drop index ind_t_c_fid;

-- 5-64 确实卡住了

-- 5-70 在T表的ID列建普通索引
drop table t cascade constraints purge;
create table t(id number,name varchar2(30));
insert into t select rownum,table_name from all_tables;

create index idx_t_id on t(id);

-- 5-71 为ID列增加主键约束
alter table t add constraint t_id_pk primary key(id);

-- 5-72 观察object_id,object_type顺序的组合索引
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id,object_type);
create index idx2_object_id on t(object_type,object_id);

select /*+index(t,idx1_object_id)*/ * from t where object_id=20 and object_type='TABLE';
select /*+index(t,idx2_object_id)*/ * from t where object_id=20 and object_type='TABLE';
-- 二者效率一样 等值查询情况，组合索引的列无论哪一列在前性能都一样
-- 组合索引的两列，当一列是范围查询，一列是等值查询，等值查询在前，范围查询在后，这样的索引效率最高

-- 5-86 索引监控的查询脚本
-- 对需要跟踪的索引进行监控
-- alter index 索引名 monitoring usage;
-- 通过观察v$object_usage 进行跟踪
select * from v$object_usage;
drop table t purge;
create table t as select * from dba_objects;
create index idx_t_id on t(object_id);
create index idx_t_name on t(object_name);

-- 5-87 索引监控的实施
alter index idx_t_id monitoring usage; -- nomonitoring为不监控
alter index idx_t_name monitoring usage;
set linesize 166
col INDEX_ANME for a10
col TABLE_NAME for a10
col MONITORING for a10
col USED for a10
col START_MONITORING for a25
col END_MONITORING for a25
select * from v$object_usage; 

-- 5-89 位图索引跟踪准备
drop table t purge;
create table t as select * from dba_objects;
insert into t select * from t; -- 2,330,080 行已插入

-- 5-90 全表扫描代价
select count(*) from t; -- 396

-- 5-91 普通索引代价
create index idx_t_obj on t(object_id);
alter table t modify object_id not null;
update t set object_id=-1 where object_id is null;
select count(*) from t; -- 396 没影响？ 

-- 5-92 位图索引的代价
create bitmap index idx_bitm_t_status on t(status);
select count(*) from t; -- 104

-- 5-107 函数索引准备
drop table t purge;
create table t as select * from dba_objects;
create index idx_object_id1 on t(object_id);
create index idx_object_name on t(object_name);
create index idx_created on t(created);
select count(*) from t;

-- 5-112 比较写法性能差异
select * from t where object_id-10<=30; -- 全表扫描
select * from t where object_id<=40;