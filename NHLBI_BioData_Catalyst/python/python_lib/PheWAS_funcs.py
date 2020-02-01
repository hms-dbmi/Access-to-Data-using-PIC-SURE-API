import pandas as pd
import numpy as np 
from scipy import stats

import PicSureHpdsLib
import PicSureClient



def _query_HPDS(variables: list,
                resource,
                qtype="select") -> pd.DataFrame:
    query = resource.query()
    if qtype == "select":
        query.select().add(variables)
    else:
        raise ValueError("only select implemented right now")
    return query.getResultsDataFrame(timeout=60)


def _independent_var_selection(subset_variablesDict,
                               phenotypes=True,
                               nb_categories: tuple=None, 
                               ):
    if phenotypes is True:
        mask_pheno = subset_variablesDict["HpdsDataType"] == "phenotypes"
        subset_variablesDict = subset_variablesDict.loc[mask_pheno,:]
    if nb_categories is not None:
        mask_modalities = subset_variablesDict["categorical"] == False | subset_variablesDict["nb_modalities"].between(*nb_categories, inclusive=True)
        subset_variablesDict = subset_variablesDict.loc[mask_modalities, :]

    return subset_variablesDict

def _LRT(dependent_var_name: str,
        independent_var_names: str,
        variablesDict: pd.DataFrame,
        facts: pd.DataFrame) -> dict:
    
    from statsmodels.discrete.discrete_model import Logit
    from scipy.linalg import LinAlgError
    from statsmodels.tools.sm_exceptions import PerfectSeparationError
    from tqdm import tqdm
    
    dic_pvalues = {}
    for independent_var_name in tqdm(independent_var_names, position=0, leave=True):
        matrix = facts.loc[:, [dependent_var_name, independent_var_name]]\
                  .dropna(how="any")
        if matrix.shape[0] == 0:
            dic_pvalues[independent_var_name] = np.NaN
            continue
            
        simple_index_variablesDict = variablesDict.set_index("varName", append=False)
        if simple_index_variablesDict.loc[independent_var_name, "categorical"]:
            matrix = pd.get_dummies(matrix,
                                    columns=[independent_var_name],
                                    drop_first=False)\
                        .iloc[:, 0:-1]
        dependent_var = matrix[dependent_var_name].cat.codes
        independent_var = matrix.drop(dependent_var_name, axis=1)\
                                .assign(intercept = 1)
        model = Logit(dependent_var, independent_var)
        try:
            results = model.fit(disp=0)
            dic_pvalues[independent_var_name] = results.llr_pvalue
        except (LinAlgError, PerfectSeparationError) as e:
            dic_pvalues[independent_var_name] = np.NaN
        
    return dic_pvalues


def PheWAS(study_name: str,
           dependent_var_name: str,
           studies_info_df: pd.DataFrame,
           variablesDict: pd.DataFrame,
          resource) -> dict:
    study_varnames = variablesDict.loc[study_name, "varName"].values.tolist()
    subject_id_varname = studies_info_df.loc[study_name, "ID varName"]
    
    mask_subsetDict = variablesDict["varName"].isin(study_varnames)
    subset_variablesDict = variablesDict.loc[mask_subsetDict]
    print("subset_variablesDict shape: {0}".format(subset_variablesDict.shape))
    print("querying")
    fact = _query_HPDS(study_varnames + [dependent_var_name],
                      resource=resource)
    print("Shape of retrieved HPDS dataframe {0}".format(fact.shape))
    
    subset_ids = fact[subject_id_varname].replace({0: np.NaN}).notnull()
    
    subset_variablesDict = _independent_var_selection(subset_variablesDict, nb_categories = (2, 20))
    
    independent_var_names = subset_variablesDict.loc[:, "varName"].tolist()
    try:
        independent_var_names.remove(dependent_var_name)
    except:
        print("dependent_var_name not in independent_var_names")
        
    subset_fact = fact.loc[subset_ids, independent_var_names + [dependent_var_name]]   
    subset_fact[dependent_var_name] = subset_fact[dependent_var_name].astype("category")
    print("subset_fact shape {0}".format(subset_fact.shape))
    dic_pvalues = _LRT(dependent_var_name, 
                       independent_var_names,
                       subset_variablesDict,
                       subset_fact)
    return dic_pvalues
