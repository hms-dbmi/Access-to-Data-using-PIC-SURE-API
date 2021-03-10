--Script Name - CtakeNotes_PICSURE_API_validations.sql
--Data Extract for - CtakeNotes_PICSURE_API_validations.ipyn
--Save extract as CTakesNotes_Data_Ext_1.csv

create table i2b2_blue.CTakesNotes_Data_Ext_1 as
SELECT COUNT(*) counts,concept_path,tval_char,nval_num 
FROM
(
select distinct patient_num,concept_path ,tval_char,nval_num 
FROM i2b2_blue.bch_hpds_data c
WHERE concept_path LIKE  '\Notes\%'
and tval_char in ( 'NEGATIVE','POSITIVE')
 )
GROUP BY concept_path,tval_char,nval_num 
ORDER BY concept_path,tval_char,nval_num ;


select *
FROM i2b2_blue.CTakesNotes_Data_Ext_1 ;
