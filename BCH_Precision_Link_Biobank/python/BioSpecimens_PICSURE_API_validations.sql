--
--Script Name - BioSpecimens_PICSURE_API_validations.sql
--Used by - BioSpecimens_PICSURE_API_validations.ipynb
--Save data from table i2b2_blue.Bio_Samples_Data_Ext_1 as Bio_Samples_Data_Ext_1.csv 


create table i2b2_blue.Bio_Samples_Data_Ext_1 as
SELECT COUNT(*) counts,concept_path,tval_char,nval_num 
FROM
(select distinct patient_num,concept_path ,tval_char,nval_num 
FROM i2b2_blue.bch_hpds_data c
WHERE concept_path LIKE  '\Bio Specimens\_%'
AND tval_char <> 'E'
 )
GROUP BY concept_path,tval_char,nval_num 
ORDER BY concept_path,tval_char,nval_num ;

