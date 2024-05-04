-- 数据库(DATABASE)由若干表空间(TABLESPACE)组成
-- 表空间由若干段(SEGMENT)组成
-- 段由若干区(EXTENT)组成
-- 区由最小单元块(BLOCK)组成

-- 3.2.5.1
-- 查看块大小
show parameter db_block_size;

-- 通过观察表空间视图dba_tablespaces的block_size值获取
select block_size from dba_tablespaces where tablespace_name='SYSTEM';

-- 普通数据表空间
create tablespace TBS_LJB
datafile 'D:\Oracle\oradata\ORCL\TBS_LJB_01.DBF' size 100M
extent management local segment space management auto
;

col file_name format a50
set linesize 366
select file_name,tablespace_name,autoextensible,bytes
from DBA_DATA_FILES
where tablespace_name='TBS_LJB'
order by substr(file_name,'-12')
;

-- 临时表空间
create temporary tablespace temp_ljb
TEMPFILE 'D:\Oracle\oradata\ORCL\TMP_LJB.DBF' size 100M;

select file_name,tablespace_name,autoextensible,bytes from dba_temp_files where tablespace_name='TEMP_LJB';

-- 回滚表空间
create undo tablespace undotbs2 datafile 'D:\Oracle\oradata\ORCL\UNDOTBS2.DBF' size 100M;

select file_name,tablespace_name,autoextensible, (bytes/1024/1024) from
dba_data_files where tablespace_name='UNDOTBS2'
order by substr(file_name,-12);

-- 系统表空间(SYSAUS作为辅助系统表空间使用)
select file_name,tablespace_name,autoextensible,bytes/1024/1024
from dba_data_files
where tablespace_name like 'SYS%'
order by substr(file_name,-12);

-- 系统表空间和用户表空间都属于永久保留内容的表空间
select tablespace_name,contents from dba_tablespaces where tablespace_name in 
('TBS_LJB','TEMP_LJB','UNDOTBS2','SYSTEM','SYSAUX');

--3.2.5.3 逻辑结构之USER
-- 删除ljb用户
drop user ljb cascade;
-- 建用户，并将先前建的表空间tbs_ljb和临时表空间temp_ljb作为ljb用户的默认使用空间
create user ljb
identified by ljb
default tablespace tbs_ljb
temporary tablespace temp_ljb;
-- 授权最大权限给ljb
grant dba to ljb;
-- 登陆ljb
connect ljb/ljb;

drop table t purge;
create table t(id int) tablespace tbs_ljb;

-- 查询数字字典获取extent相关信息(no rows selected,表中无数据)
select segment_name,extent_id,tablespace_name,
bytes/1024/1024,blocks from user_extents
where segment_name='T';

-- 插入数据
insert into t select rownum from dual connect by level<=1000000;
commit;

select segment_name,extent_id,tablespace_name,bytes/1024/1024,blocks from user_extents where segment_name='T';

-- 逻辑结构之SEGMENT
drop table t purge;
create table t(id int) tablespace tbs_ljb;
select segment_name,segment_type,tablespace_name,blocks,extents,
bytes/1024/1024 from user_segments
where segment_name='T';

-- 插入数据
insert into t select rownum from dual connect by level <= 1000000;
select segment_name,segment_type,tablespace_name,blocks,extents,
bytes/1024/1024 from user_segments
where segment_name='T';

-- 索引段
create index idx_id on t(id);
select segment_name,segment_type,tablespace_name,blocks,extents,
bytes/1024/1024 from user_segments
where segment_name='IDX_ID';

select count(*) from user_extents where segment_name='IDX_ID';

-- 3.2.6
-- 查看块的大小
show parameter cache_size;

alter system set db_16k_cache_size='100M';
show parameter 16k;

-- 创建表空间
create tablespace TBD_LJB_16k blocksize 16k
datafile 'D:\Oracle\admin\orcl\pfile\TBS_LJB_16k_01.DBF' size 100M
autoextend on extent management local
segment space management auto;

-- 查看tbs_ljb_16k和tbs_ljb2表空间的不同
select tablespace_name,block_size from dba_tablespaces
where tablespace_name in ('TBS_LJB2','TBS_LJB_16K');

-- 3.2.6.4 EXTENT 尺寸与调整
create tablespace TBS_LJB2
datafile 'D:\Oracle\oradata\ORCL\TBS_LJB2_01.DBF' size 100M
extent management local

-- 区大小设为10M
uniform size 10M
segment space management auto;

-- 表空间剩余
select sum(bytes)/1024/1024 from dba_free_space where tablespace_name='TBS_LJB';

create table t2(id int) tablespace TBS_LJB2;

-- extent 分配情况
select segment_name,extent_id,tablespace_name,bytes/1024/1024,blocks
from user_extents where segment_name='T2';

insert into t2 select rownum from dual connect by level <=1000000;

-- 原始表空间容量
select sum(bytes)/1024/1024 from dba_data_files where tablespace_name='TBS_LJB';

insert into t select rownum from dual connect by level<=1000000;

-- 扩大数据库表空间
alter tablespace tbs_ljb add datafile 'D:\Oracle\oradata\ORCL\TBS_LJB_02.DBF'
size 100M;

-- 观察表空间是否自动扩展
colile f_name format a50
select file_name,tablespace_name,autoextensible,bytes/1024/1024 from dba_data_files
where tablespace_name='TBS_LJB';

-- 将表空间属性改为自动扩展
alter database datafile 'D:\Oracle\oradata\ORCL\TBS_LJB_02.DBF' autoextend on;
   
-- 删除表空间自动删除数据文件方法
drop tablespace TBS_LJB
including contents and datafiles;

create tablespace TBS_LJB datafile
'D:\Oracle\oradata\ORCL\TBS_LJB_01.DBF' size 100M
autoextend on 
extent management local
segment space management auto;

-- 建自动扩展表空间可控制最大扩展到多少 (每次扩展增加64k,表空间最大不超过5G)
create tablespace TBS_LJB3
datafile 'D:\Oracle\oradata\ORCL\TBS_LJB3_01.DBF' size 100M
autoextend on next 64k maxsize 5G;

-- 3-23 查看数据库当前所在回滚段
-- undo_management的取值为auto表示是系统自动管理表空间而不是手动
show parameter undo;

-- 3-24 查看数据库有几个回滚段
select tablespace_name,status from dba_tablespaces where contents='UNDO';

-- 3-25 查看数据库有几个回滚段，并得出大小
select tablespace_name,sum(bytes)/1024/1024 from dba_data_files
where tablespace_name in ('UNDOTBS1','UNDOTBS2')
group by tablespace_name;

-- 3-26 切换回滚表空间
alter system set undo_tablespace = undotbs2 scope = both;

-- 出现 write to SPFILE requested but no SPFILE is in use
-- pfile和spfile的区别

-- 3-29 查看临时表空间大小
select tablespace_name, sum(bytes)/1024/1024 from dba_temp_files
group by tablespace_name;

-- 3-31 查看用户的默认表空间和临时表空间
select default_tablespace,temporary_tablespace from dba_users where username='LJB';

-- 3-32 查看其他用户的临时表空间
select default_tablespace,temporary_tablespace from dba_users where username='SYSTEM';

-- 3-34 不同用户在不同临时表空间的分配情况
select temporary_tablespace,count(*) from dba_users
group by temporary_tablespace;

-- 3-37 查询临时表空间情况
select * from dba_tablespace_groups;

-- 3-38 新建临时表空间组
create temporary tablespace temp1_1 tempfile 'D:\Oracle\oradata\ORCL\TMP1_1.DBF' size 100M
tablespace group tmp_grp1
;
create temporary tablespace temp1_2 tempfile 'D:\Oracle\oradata\ORCL\TMP1_2.DBF' size 100M
tablespace group tmp_grp1
;
create temporary tablespace temp1_3 tempfile 'D:\Oracle\oradata\ORCL\TMP1_3.DBF' size 100M
tablespace group tmp_grp1
;

-- 3-48 分别建统一尺寸和自动扩展的两个表空间
set timing on
create tablespace TBS_LJB_A
datafile 'D:\Oracle\oradata\ORCL\TBS_LJB_A_01_01.DBF' size 1M
autoextend on uniform size 64k;

create tablespace TBS_LJB_B
datafile 'D:\Oracle\oradata\ORCL\TBS_LJB_B_01_01.DBF' size 2G;

-- 3-49 分别在两个不同表空间建表
set timing on
create table t_a(id int) tablespace TBS_LJB_A;
create table t_b(id int) tablespace TBS_LJB_B;

-- 3-50 分别比较插入的速度差异
insert into t_a select rownum from dual connect by level <= 1000000; -- 1.218s
insert into t_b select rownum from dual connect by level <= 1000000; -- 0.82s

-- 3-51 速度差异原因（表空间申请扩大空间花费大量时间）
select count(*) from user_extents where segment_name='T_A'; -- 扩展194次
select count(*) from user_extents where segment_name='T_B'; -- 扩展28次

-- 3-52 表在uniform为64k的tablespace的插入情况
create tablespace TBS_LJB_C
datafile 'D:\Oracle\oradata\ORCL\TBS_LJB_C_01.DBF' size 2G
autoextend on uniform size 64k;

create table t_c(id int) tablespace TBS_LJB_C;

insert into t_c select rownum from dual connect by level<=1000000; -- 0.78s

-- 3-53 PCTFREE 试验准备之建表
drop table employees purge;
create table employees as select * from HR.employees;
desc employees;

-- 3-54 PCTFREE 试验准备之扩大字段
alter table employees modify first_name varchar2(2000);
alter table employees modify last_name varchar2(2000);
alter table employees modify email varchar2(2000);
alter table employees modify phone_number varchar2(2000);

-- 3-55 更新表
update employees set first_name = LPAD('1',2000,'*'),
last_name = LPAD('1',2000,'*'),email = lpad('1',2000,'*'),
phone_number=lpad('1',2000,'*');

-- 3-62 块的大小应用环境（分别建8k和16k的表空间）
drop tablespace TBS_LJB INCLUDING CONTENTS AND DATAFILES;
create tablespace TBS_LJB 
datafile 'D:\Oracle\oradata\ORCL\TBS_LJB_01.DBF' size 1G;

drop tablespace TBS_LJB_16K including CONTENTS AND DATAFILES;
create tablespace TBS_LJB_16K
blocksize 16K
datafile 'D:\Oracle\oradata\ORCL\TBS_LJB_16k_01.DBF' size 1G;

-- 3-63 块的大小应用准备工作（在16k表空间建表）
drop table t_16k purge;
create table t_16k tablespace tbs_ljb_16k as select * from dba_objects;
insert into t_16k select * from t_16k;
insert into t_16k select * from t_16k;
insert into t_16k select * from t_16k;
insert into t_16k select * from t_16k;
insert into t_16k select * from t_16k;

insert into t_16k select * from t_16k;
commit;

create index idx_object_id on t_16k(object_id);

-- 3-64 块的大小应用准备工作（在8K表空间建表）
drop table t_8k purge;
create table t_8k tablespace tbs_ljb as select * from dba_objects;
insert into t_8k select * from t_8k;
insert into t_8k select * from t_8k;
insert into t_8k select * from t_8k;
insert into t_8k select * from t_8k;
insert into t_8k select * from t_8k;
insert into t_8k select * from t_8k;
commit;
update t_8k set object_id = rownum;
commit;
create index idx_object_id_8k on t_8k(object_id);

-- 3-65 BLOCK为16K的表空间全表扫描性能
set autotrace on
set linesize 1000
set timing on
select count(*) from t_16k;

-- 3-66 BLOCK为8K的表空间的全表扫描性能
select count(*) from t_8k;

-- 3-67,68 block为8K和16K的表空间索引读性能
select * from t_8k where object_id=29;
select * from t_16k where object_id=29;

