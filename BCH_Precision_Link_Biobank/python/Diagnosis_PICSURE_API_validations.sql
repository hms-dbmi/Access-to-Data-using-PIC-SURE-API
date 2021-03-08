--ScriptName - Diagnosis_PICSURE_API_validations.sql
--Extracts data for - Diagnosis_PICSURE_API_validations.ipynb
--  Generates data files from this script with names listed
--  Needed for the patient count validations for Diagnosis node.
--  Diag_Data_Ext_1.csv
--All the categorical data for \Diagnosis\ .

create table i2b2_blue.Diag_Data_Ext_1 as
SELECT COUNT(*) counts,concept_path,tval_char,nval_num 
FROM
(select distinct patient_num,concept_path ,tval_char,nval_num 
FROM i2b2_blue.bch_hpds_data c
WHERE concept_path LIKE  '\Diagnosis\%'
 )
GROUP BY concept_path,tval_char,nval_num 
ORDER BY concept_path,tval_char,nval_num ;

select * from i2b2_blue.Diag_Data_Ext_1 ;



        
