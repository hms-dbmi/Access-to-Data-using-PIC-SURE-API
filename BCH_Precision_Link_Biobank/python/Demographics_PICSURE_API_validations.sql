--Script Name -  Demographics_PICSURE_API_validations.sql
--Data Extract for - Demographics_PICSURE_API_validations.ipynb
--Save data with file name - Diag_Data_Ext_1.csv

select count(*) COUNTS,  concept_path,tval_char, nval_num from
( SELECT distinct patient_num, replace( (replace ( CONCEPT_PATH,tval_char,''  ) ),'\\','\') CONCEPT_PATH ,tval_char, nval_num
FROM      i2b2_blue.bch_hpds_data
WHERE CONCEPT_PATH LIKE '\Demographics\%'
AND concept_path not in ( '\Demographics\Age\',
 '\Demographics\Ethnicity\A-C\Black\261705316\',
'\Demographics\Ethnicity\D-M\Dominican (Republic)\855802575\',
'\Demographics\Ethnicity\T-Z\Unknown\312508\',
'\Demographics\Ethnicity\D-M\Guatamalan\855802589\',
'\Demographics\Ethnicity\D-M\Hispanic or Latino\312506\',
'\Demographics\Ethnicity\D-M\Declined to Answer\261672357\',
'\Demographics\Race\White\311\')
 )
group by   concept_path,
    nval_num,
    tval_char 

UNION
select count(*) COUNTS,  concept_path, tval_char, nval_num 
from
(
select distinct concept_path,patient_num,tval_char,nval_num 
from i2b2_blue.bch_hpds_data
where concept_path  like '\Demographics\Ethnicity\%'
and i2b2_blue.DATA_UTILITY_PKG.NUM_OCCURANCES(
concept_path,'\'
  ) = 6)
  group by   concept_path,
    nval_num,
    tval_char 

UNION 
select count(*) COUNTS,  concept_path,  tval_char, nval_num
from
(  
select distinct concept_path,patient_num,tval_char,nval_num  from i2b2_blue.bch_hpds_data
where concept_path  like '\Demographics\Race\%'
and i2b2_blue.DATA_UTILITY_PKG.NUM_OCCURANCES(
concept_path,'\'
  ) = 5)
   group by   concept_path,
    nval_num,
    tval_char 
   order by concept_path, nval_num, tval_char  ;
   

