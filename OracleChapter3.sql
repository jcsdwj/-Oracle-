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