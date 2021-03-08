--Script Name - Medications_PICSURE_API_validations.sql
--Extracts data for Medications_PICSURE_API_validations.ipynb

--  Generate 2 data files from this script with names listed
--  Needed for the patient count validations.
--  Med_Data_Ext_1.csv
--  Med_Data_Ext_2.csv
--
--*******Data Extract for script 1
--All the categorical data for \Medications\ excluding \Medications\Any  derived rows.

create table i2b2_blue.Med_Data_Ext_1_meta as
SELECT count(distinct patient_num) count,concept_path, tval_char
FROM i2b2_blue.bch_hpds_data
WHERE concept_path LIKE  '\Medications\%'
AND concept_path NOT LIKE  '\Medications\Any%'
GROUP BY concept_path, tval_char ;


create table i2b2_blue.Med_Data_Ext_1 as
SELECT COUNT(*) counts,concept_path,tval_char,nval_num 
FROM
(select distinct patient_num,concept_path ,tval_char,nval_num 
FROM i2b2_blue.bch_hpds_data c
WHERE concept_path LIKE  '\Medications\%'
AND concept_path NOT LIKE  '\Medications\Any%'
and concept_path not in (  select concept_path from i2b2_blue.Med_Data_Ext_1_meta a
where count = (select max(count) 
                from i2b2_blue.Med_Data_Ext_1_meta b
                where a.concept_path = b.concept_path
                and b.tval_char in ('E','1','0') )   )
)
GROUP BY concept_path,tval_char,nval_num 
ORDER BY concept_path,tval_char,nval_num ;

--Save data extract from this SQL as Med_Data_Ext_1.csv
select * from i2b2_blue.Med_Data_Ext_1 ;


--*******Data Extract for script 2
-- Only  \Medications\Any  derived rows.
create table i2b2_blue.Med_Data_Ext_2_meta as
 SELECT count(distinct patient_num) count,concept_path, tval_char
        FROM i2b2_blue.bch_hpds_data
        WHERE concept_path  LIKE  '\Medications\Any%'
        group by concept_path, tval_char ;

---
create table i2b2_blue.Med_Data_Ext_2 as
SELECT COUNT(*) counts,concept_path,tval_char,nval_num 
FROM
(select distinct patient_num,concept_path ,tval_char,nval_num 
FROM i2b2_blue.bch_hpds_data c
WHERE concept_path  LIKE  '\Medications\Any%'
and concept_path not in (  select concept_path from i2b2_blue.Med_Data_Ext_2_meta a
where count = (select max(count) 
                from i2b2_blue.Med_Data_Ext_2_meta b
                where a.concept_path = b.concept_path
                and b.tval_char in ('E','1','0') )   ) )
GROUP BY concept_path,tval_char,nval_num 
ORDER BY concept_path,tval_char,nval_num ;


--Save data extract from this SQL as Med_Data_Ext_2.csv
select * from i2b2_blue.Med_Data_Ext_2 ;

----

        
