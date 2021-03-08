--Script Name - Labs_PICSURE_API_101.sql
--Data extract for -Labs_PICSURE_API_101.ipynb

--Using this script data will be extracted for PL Picsure Laboratory Results.
--ALS-1723
/*
root.bch_hpds_data  --Orignal HPDS data extract.
root.Bch_Hpds_Data_Lab_App_All -- Data uploaded from API extract.
root.bch_hpds_data_lab -- Lab nodes grouped as categorical values from the API extract.
root.bch_hpds_data_get_list --Has data aggregated at concept_path level 
root.bch_hpds_data_get_list_func  -- for performance improvement of function created distinct concept_path and categorical values.
root.bch_hpds_data_get_list_map -- Pre populated categorical_values for all the concept_paths for performance.
root.bch_hpds_data_lab_extract -- Final extract to be generated from this table.

--Database functions
Get_format_min_max  
Get_tval_array
*/

--Create table root.Bch_Hpds_Data_Lab_App_All
--And upload API data from Lab Picsure API - Labs_PICSURE_API_101.ipynb ( data_lab_to_csv.csv )

CREATE TABLE ROOT.BCH_HPDS_DATA_LAB_APP_ALL 
   (	KEY VARCHAR2(4000 BYTE), 
	PATIENTCOUNT VARCHAR2(4000 BYTE), 
	CATEGORICAL VARCHAR2(4000 BYTE), 
	CATEGORYVALUES LONG, 
	OBSERVATIONCOUNT VARCHAR2(4000 BYTE), 
	HPDSDATATYPE VARCHAR2(4000 BYTE), 
	MIN VARCHAR2(4000 BYTE), 
	MAX VARCHAR2(4000 BYTE)
   );
   
create table root.bch_hpds_data_lab as
(select  PATIENT_NUM ,
	CONCEPT_PATH ,
	NVAL_NUM ,
	TVAL_CHAR ,start_date
from root.bch_hpds_data a , root.Bch_Hpds_Data_Lab_App_All  b
where concept_path like '\Laboratory Results\%'
and a.concept_path = b.key 
and B.Categorical = 'False' 
and TVAL_CHAR in ('GE',
'LE',
'E',
'L',
'G')
union all
select  PATIENT_NUM ,
	CONCEPT_PATH ,
	NVAL_NUM ,
	TVAL_CHAR ,start_date
from  ROOT.bch_hpds_data a, root.Bch_Hpds_Data_Lab_App_All  b
where  concept_path like '\Laboratory Results\%'
and a.concept_path = b.key 
and B.Categorical = 'True'
and TVAL_CHAR not in ('GE',
'LE',
'E',
'L',
'G')
union all
select  PATIENT_NUM ,
	CONCEPT_PATH ,
	NVAL_NUM ,
	TVAL_CHAR ,start_date
from  ROOT.bch_hpds_data a, root.Bch_Hpds_Data_Lab_App_All  b
where  concept_path like '\Laboratory Results\%' 
and a.concept_path = b.key 
and B.Categorical = 'True'
and (TVAL_CHAR = 'E' and nval_num is null)
) ;

---Patient level data with aggregated values

create table root.bch_hpds_data_get_list( CONCEPT_PATH varchar2(4000) , 
patientCount  varchar2(4000) ,
categorical varchar2(4000) ,
categoryValues varchar2(4000) , 
observationCount varchar2(4000) , 
HpdsDataType varchar2(4000) ,
MIN varchar2(4000) ,
MAX varchar2(4000)  );

begin
insert into root.bch_hpds_data_get_list( CONCEPT_PATH ,  patientCount, categorical ,categoryValues , observationCount, HpdsDataType)
 select 
	  CONCEPT_PATH , count(distinct patient_num) OVER (PARTITION BY CONCEPT_PATH) AS patientCount, 'True' categorical ,
   tval_char categoryValues , 
    count( patient_num) OVER (PARTITION BY CONCEPT_PATH) AS observationCount, 'phenotypes' HpdsDataType
  from

 ( 
select *
from  root.bch_hpds_data_lab a, root.Bch_Hpds_Data_Lab_App_All  b
where a.concept_path = b.key 
and B.Categorical = 'True'
and length(TVAL_CHAR) >= 1  
);
commit;

end;


begin



insert into root.bch_hpds_data_get_list( CONCEPT_PATH ,  patientCount, categorical ,categoryValues , observationCount, HpdsDataType,MIN,MAX)
 ( select 
	 CONCEPT_PATH , count(distinct patient_num) OVER (PARTITION BY CONCEPT_PATH) AS patientCount, 'False' categorical ,null categoryValues , 
    count( patient_num) OVER (PARTITION BY CONCEPT_PATH) AS observationCount, 'phenotypes' HpdsDataType,min(nval_num) OVER (PARTITION BY CONCEPT_PATH)  min, 
 max(nval_num) OVER (PARTITION BY CONCEPT_PATH)  max
    from
(
select *
from  ROOT.bch_hpds_data_lab a, root.Bch_Hpds_Data_Lab_App_All  b
where a.concept_path = b.key 
and B.Categorical = 'False'
and a.nval_num is not null
)

); 
commit;
end;

create table root.bch_hpds_data_get_list_func as
select distinct l.CONCEPT_PATH  ,l.categoryValues 
from root.bch_hpds_data_get_list l
where l.categorical = 'True'  ;

truncate table root.bch_hpds_data_get_list_map drop storage ;


insert into root.bch_hpds_data_get_list_map ( concept_path )
select distinct concept_path from  root.bch_hpds_data_get_list_func ;

CREATE OR REPLACE FUNCTION Get_tval_array (P_ConceptPath varchar2)
   return long
is
v_str  long;
v_countr number := 0;

begin

for r_data in ( select distinct categoryValues from  root.bch_hpds_data_get_list_func  where concept_path =  P_ConceptPath  order by 1 ) loop

v_str := v_str||', '||chr(39)||r_data.categoryValues||chr(39) ;
v_countr := v_countr + 1;
end loop;
if v_countr > 1 then
v_str := '['||ltrim(v_str,', ')||']';
else  v_str := '['||ltrim(v_str,', ')||']';
end if;
return  v_str ;
exception
when others then
 v_str := ' ' ;
 dbms_output.put_line('v_str excep '||v_str ) ;
 return  v_str ;
end Get_tval_array;


DECLARE
  P_CONCEPTPATH VARCHAR2(200);
  v_Return LONG;
BEGIN

for r_data in ( select concept_path from root.bch_hpds_data_get_list_map
 ) loop

  P_CONCEPTPATH := r_data.concept_path ;

  v_Return := Get_tval_array(
    P_CONCEPTPATH => P_CONCEPTPATH
  );
  update root.bch_hpds_data_get_list_map
  set categoryValues = v_Return
  where concept_path = r_data.concept_path ;

DBMS_OUTPUT.PUT_LINE('v_Return = ' || v_Return);

end loop;
commit;
END;


CREATE OR REPLACE FUNCTION Get_format_min_max (p_value varchar2)
   return varchar2
is
v_str  varchar2(4000);
v_countr number := 0;

begin
--v_str := p_value ;
IF instr( p_value,'.',1) = 0 THEN
    v_str := p_value ||'.0' ;
    
ELSIF  instr( p_value,'.',1) =  1 THEN
   v_str := '0'||p_value  ;   
ELSE
    v_str := p_value  ;   
END IF;

 return  v_str ;
end Get_format_min_max;


  CREATE TABLE ROOT.BCH_HPDS_DATA_LAB_EXTRACT 
   (	KEY VARCHAR2(4000), 
	PATIENTCOUNT VARCHAR2(4000), 
	CATEGORICAL VARCHAR2(4000), 
	CATEGORYVALUES VARCHAR2(4000), 
	OBSERVATIONCOUNT VARCHAR2(4000), 
	HPDSDATATYPE VARCHAR2(4000), 
	MIN VARCHAR2(4000), 
	MAX VARCHAR2(4000), 
	CATEGORYVALUES_1 LONG
   );
   
--truncate table ROOT.BCH_HPDS_DATA_LAB_EXTRACT  ;

begin

insert into root.BCH_HPDS_DATA_LAB_EXTRACT ( KEY ,  patientCount, categorical , categoryValues, observationCount, HpdsDataType ,min ,max )
SELECT distinct '"'||CONCEPT_PATH||'"' KEY ,  patientCount patientCount, categorical categorical, null categoryValues 
 , observationCount observationCount, HpdsDataType HpdsDataType,Get_format_min_max (min) min ,Get_format_min_max (max) max 
from root.bch_hpds_data_get_list where categorical = 'False';

commit;
end;


begin
    for r_data in ( select distinct '"'||l.CONCEPT_PATH||'"' concept_path ,  l.patientCount, l.categorical , l.observationCount, l.HpdsDataType,l.MIN, l.MAX  
from root.bch_hpds_data_get_list l
where l.categorical = 'True'  ) loop
           for r_data_map in (  select  * from root.bch_hpds_data_get_list_map m where r_data.concept_path = '"'||m.CONCEPT_PATH||'"' and rownum = 1  )  loop
              insert into root.BCH_HPDS_DATA_LAB_EXTRACT ( KEY ,  patientCount, categorical , categoryValues, observationCount, HpdsDataType ,min ,max )
              values ( r_data.concept_path ,   r_data.patientCount,  r_data.categorical ,  r_data_map.categoryValues,  r_data.observationCount,  r_data.HpdsDataType , r_data.min , r_data.max ); 
           end loop;
    
    end loop;
commit;
end;


