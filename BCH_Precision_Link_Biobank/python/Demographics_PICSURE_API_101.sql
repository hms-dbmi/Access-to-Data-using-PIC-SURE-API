-- Script Name - Demographics_PICSURE_API_101.sql
-- root.bch_hpds_data
-- root.bch_hpds_data_demo
-- root.bch_hpds_data_get_list
-- FUNCTION Get_tval_array (P_ConceptPath varchar2)
-- root.bch_hpds_data_get_list_demo
-- Data extract for Demographics_PICSURE_API_101.ipynb

create table ROOT.bch_hpds_data_demo as
select * from i2b2_blue.bch_hpds_data
where concept_path like '\Demographics\%' ;

 create table root.bch_hpds_data_get_list
   (	concept_path varchar2(4000), 
	patientcount number, 
	categorical varchar2(20), 
	categoryvalues varchar2(2000), 
	observationcount number, 
	hpdsdatatype varchar2(20), 
	min varchar2(20), 
	max varchar2(20)
   ) 
 nocompress logging ;

select * from root.bch_hpds_data_demo ;

--1. add Age
--Added Age data.

insert into root.bch_hpds_data_get_list( CONCEPT_PATH ,  patientCount, categorical ,categoryValues , observationCount, HpdsDataType,MIN,MAX)
 (select 
	 CONCEPT_PATH , count(distinct patient_num) OVER (PARTITION BY CONCEPT_PATH) AS patientCount, 'False' categorical ,null categoryValues , 
    count( patient_num) OVER (PARTITION BY CONCEPT_PATH) AS observationCount, 'phenotypes' HpdsDataType,min(nval_num) OVER (PARTITION BY CONCEPT_PATH)  min, 
 max(nval_num) OVER (PARTITION BY CONCEPT_PATH)  max
    from
(select distinct PATIENT_NUM ,
	CONCEPT_PATH ,
	NVAL_NUM ,
	TVAL_CHAR 
from root.bch_hpds_data_demo
where TVAL_CHAR = 'E'
) );
commit;


--2. Add Ethnicity data

insert into root.bch_hpds_data_get_list( CONCEPT_PATH ,  patientCount, categorical ,categoryValues , observationCount, HpdsDataType)
 select 
	  CONCEPT_PATH , count(distinct patient_num) OVER (PARTITION BY CONCEPT_PATH) AS patientCount, 'True' categorical ,
   tval_char categoryValues , 
    count( patient_num) OVER (PARTITION BY CONCEPT_PATH) AS observationCount, 'phenotypes' HpdsDataType
  from

( (  select distinct PATIENT_NUM ,
	'\Demographics\Ethnicity\'||I2B2_BLUE.DATA_UTILITY_PKG.PARSE_NTH_VALUE (CONCEPT_PATH,4,'\')||'\' CONCEPT_PATH ,
	NVAL_NUM ,
	TVAL_CHAR 
from  ROOT.bch_hpds_data_demo
where TVAL_CHAR <> 'E'
and concept_path like '\Demographics\Ethnicity\%'
and I2B2_BLUE.DATA_UTILITY_PKG.NUM_OCCURANCES(CONCEPT_PATH,'\')= 5
group by PATIENT_NUM, '\Demographics\Ethnicity\'||I2B2_BLUE.DATA_UTILITY_PKG.PARSE_NTH_VALUE (CONCEPT_PATH,4,'\'),NVAL_NUM,TVAL_CHAR
union all
select distinct PATIENT_NUM ,
	 CONCEPT_PATH ,
	NVAL_NUM ,
	TVAL_CHAR 
from  ROOT.bch_hpds_data_demo
where TVAL_CHAR <> 'E'
and concept_path like '\Demographics\Ethnicity\%'
and I2B2_BLUE.DATA_UTILITY_PKG.NUM_OCCURANCES(CONCEPT_PATH,'\')= 6
) );--ethnicity
commit;

--3. Add Race data

insert into root.bch_hpds_data_get_list( CONCEPT_PATH ,  patientCount, categorical ,categoryValues , observationCount, HpdsDataType)
 select 
	  CONCEPT_PATH , count(distinct patient_num) OVER (PARTITION BY CONCEPT_PATH) AS patientCount, 'True' categorical ,
   tval_char categoryValues , 
    count( patient_num) OVER (PARTITION BY CONCEPT_PATH) AS observationCount, 'phenotypes' HpdsDataType
  from

(
select distinct PATIENT_NUM ,
	'\Demographics\Race\' CONCEPT_PATH ,
	NVAL_NUM ,
	TVAL_CHAR 
from root.bch_hpds_data_demo
where TVAL_CHAR <> 'E'
and concept_path like '\Demographics\Race\%'
and I2B2_BLUE.DATA_UTILITY_PKG.NUM_OCCURANCES(CONCEPT_PATH,'\')= 4
group by PATIENT_NUM, '\Demographics\Race\',NVAL_NUM,TVAL_CHAR
union all
select distinct PATIENT_NUM ,
	 CONCEPT_PATH ,
	NVAL_NUM ,
	TVAL_CHAR 
from root.bch_hpds_data_demo
where TVAL_CHAR <> 'E'
and concept_path like '\Demographics\Race\%'
and I2B2_BLUE.DATA_UTILITY_PKG.NUM_OCCURANCES(CONCEPT_PATH,'\') = 5
);
commit;


--4 Gender data.

insert into root.bch_hpds_data_get_list( CONCEPT_PATH ,  patientCount, categorical ,categoryValues , observationCount, HpdsDataType)
 select 
	  CONCEPT_PATH , count(distinct patient_num) OVER (PARTITION BY CONCEPT_PATH) AS patientCount, 
      'True' categorical ,
    categoryValues , 
    count( patient_num) OVER (PARTITION BY CONCEPT_PATH) AS observationCount, 
    'phenotypes' HpdsDataType from
(select patient_num, '\Demographics\Gender\' CONCEPT_PATH , tval_char categoryValues 
from root.bch_hpds_data_demo
where concept_path like '\Demographics\Gender\%');

commit;

CREATE OR REPLACE FUNCTION Get_tval_array (P_ConceptPath varchar2)
   return varchar2
is
v_str  varchar2(32767);
v_countr number := 0;

begin

for r_data in ( select distinct categoryValues from  root.bch_hpds_data_get_list  where concept_path =  P_ConceptPath  order by 1 ) loop

v_str := v_str||', '||chr(39)||r_data.categoryValues||chr(39) ;
v_countr := v_countr + 1;
end loop;
if v_countr > 1 then
v_str := '"['||ltrim(v_str,', ')||']"';
else  v_str := '['||ltrim(v_str,', ')||']';
end if;
return  v_str ;
exception
when others then
 v_str := ' ' ;
 dbms_output.put_line('v_str excep '||v_str ) ;
 return  v_str ;
end Get_tval_array;

--create table  root.bch_hpds_data_get_list_demo as select *  from root.bch_hpds_data_get_list ;
--Data extract SQL.
SELECT distinct CONCEPT_PATH "KEY" ,  patientCount "patientCount", categorical "categorical",get_tval_array(concept_path) "categoryValues" 
 , observationCount "observationCount", HpdsDataType "HpdsDataType",'' as "min" ,'' as "max"
from root.bch_hpds_data_get_list_demo where categorical = 'True'
union all
SELECT distinct CONCEPT_PATH "KEY" ,  patientCount "patientCount", categorical "categorical", NULL "categoryValues" 
 , observationCount "observationCount", HpdsDataType "HpdsDataType",min||'.0' "min" ,max||'.0' "max" 
from root.bch_hpds_data_get_list_demo where categorical = 'False'
order by 1 ;

