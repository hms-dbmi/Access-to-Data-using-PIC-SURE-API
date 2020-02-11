import pandas as pd
import numpy as np

import PicSureHpdsLib
import PicSureClient

from typing import List

def get_multiIndex_variablesDict(variablesDict: pd.DataFrame) -> pd.DataFrame:

    def _varName_toMultiIndex(index_varDictionnary: pd.Index) -> pd.MultiIndex:
        long_names = index_varDictionnary.tolist()
        splits = [long_name.strip('\\').split('\\') for long_name in long_names]
        multi_index = pd.MultiIndex.from_tuples(splits)
        return multi_index

    def _get_simplified_varname(variablesDict_index: pd.MultiIndex) -> pd.DataFrame:
        tup_index = variablesDict_index.tolist()
        last_valid_name_list = [[x for x in tup if str(x) != 'nan'][-1] for tup in tup_index]
        return last_valid_name_list
    
    def _get_number_modalities(categoryValues: pd.Series) -> pd.Series:
        for elem in categoryValues:
            if isinstance(elem, list):
                yield len(elem)
            else:
                yield np.NaN
        
    
    variablesDict = variablesDict.rename_axis("name", axis=0).sort_index()
    multi_index = _varName_toMultiIndex(variablesDict.index)
    last_valid_name_list = _get_simplified_varname(multi_index)
    variablesDict = variablesDict.reset_index(drop=False)
    variablesDict.index = multi_index.rename(["level_" + str(n) for n, _ in enumerate(multi_index.names)])
    variablesDict["nb_modalities"] = list(_get_number_modalities(variablesDict["categoryValues"]))
    variablesDict["simplified_name"] = last_valid_name_list
    columns_order = ["simplified_name", "name", "observationCount", "categorical", "categoryValues", "nb_modalities", "min", "max", "HpdsDataType"]
    return variablesDict[columns_order]


def get_dic_renaming_vars(variablesDict: pd.DataFrame) -> dict:
    simplified_varName = variablesDict["simplified_name"].tolist()
    varName = variablesDict["name"].tolist()
    dic_renaming = {long: simple for long, simple in zip(varName, simplified_varName)}
    return dic_renaming


def match_dummies_to_varNames(plain_columns: pd.Index,
                             dummies_columns: pd.Index,
                             columns: list =["simplified_name", "dummies_name"]) -> pd.DataFrame:
    dic_map = {}
    for plain_col in plain_columns:
        dic_map[plain_col] = [dummy_col for dummy_col in dummies_columns if dummy_col.startswith(plain_col)]
    matching_df = pd.DataFrame([[k, v] for k, v_list in dic_map.items() for v in v_list], columns=columns)
    return matching_df


def joining_variablesDict_onCol(variablesDict: pd.DataFrame,
                                 df: pd.DataFrame,
                                 left_col="simplified_name",
                                 right_col="simplified_name",
                                overwrite: bool = True) ->pd.DataFrame:
    # Allow to join a df to variablesDict on a specified columns, keeping the MultiIndex
    # Might become a method of object variablesDict because very specific
    variablesDict_to_join = variablesDict.reset_index(drop=False).set_index(left_col)
    df_to_join = df.set_index(right_col)
    variablesDict_index_names = [col for col in variablesDict_to_join.columns if col not in variablesDict.columns]
    if np.any([col in variablesDict_to_join.columns for col in  df_to_join.columns]):
        col_overlap = [col for col in  df_to_join.columns if col in variablesDict_to_join.columns]
        if overwrite is True:
            variablesDict_to_join = variablesDict_to_join.drop(col_overlap, axis=1)
        else:
            print("{0} already in variableTable".format(col_overlap))
            return variablesDict
    variablesDict_joined = variablesDict_to_join.join(df_to_join, how="left")
    variablesDict_joined = variablesDict_joined.reset_index(drop=False)\
        .set_index(variablesDict_index_names)
    return variablesDict_joined


def get_plt_grid_indices(nb_values: int=None, 
                         nb_cols  : int=None, 
                         nb_rows  : int=None) -> List[tuple]:
    """
    A utility function to get list of tuples (matplotlib-like grid indices) from given parameters
    Iterate column first
    Return 
    """
    passed_args = locals()
    def _check_args(nb_values=None, 
                   nb_cols=None, 
                   nb_rows=None):
        args = locals()
        args = {k:v for k,v in args.items() if v is not None}
        if len(args) == 3:
            assert(args["nb_cols"] * args["nb_rows"] >= args["nb_values"]), "discrepancies in the passed arguments values"
            assert((max(args["nb_cols"], args["nb_rows"]) - 1) * min(args["nb_cols"], args["nb_rows"]) < args["nb_values"]), "discrepancies in the passed arguments values"
        elif (len(args) == 1) & ("nb_values" not in args):
            raise ValueError("Only {0} passed, please pass the complementary\
            dimension argument, or the nb_values".format(args))
        elif len(args) == 0:
            raise ValueError("No arguments passed")

    def _get_complementary_values(nb_values: int=None, 
                                  nb_cols  : int=None, 
                                  nb_rows  : int=None) -> tuple:
        args = locals()
        args = {k:v for k,v in args.items() if v is not None}
        if ("nb_values" in args) & (len(args) == 1):
            nb_cols = np.floor(np.sqrt(nb_values))
            nb_rows = nb_cols + 1
            return int(nb_values), int(nb_cols), int(nb_rows)
        elif ("nb_values" in args) & (len(args) == 2):
            if "nb_cols" in args:
                nb_rows = np.ceil(nb_values/nb_cols)
            elif "nb_rows" in args:
                nb_cols = np.ceil(nb_values/nb_rows)
            return int(nb_values), int(nb_cols), int(nb_rows)
        elif "nb_values" not in args:
            nb_values = nb_rows * nb_cols
            return int(nb_values), int(nb_cols), int(nb_rows)
        else:
            return nb_values, nb_cols, nb_rows
    
    def _get_facet_grid_vec(nb_values, nb_cols, nb_rows):
        first_dim = np.arange(0, nb_cols)
        second_dim = np.arange(0, nb_rows)
        vec_indices = []
        for ind_col in second_dim:
            for ind_row in first_dim:
                vec_indices.append((ind_col, ind_row))
        return vec_indices[0:nb_values]
    
    _check_args(**passed_args)
    nb_values, nb_cols, nb_rows = _get_complementary_values(**passed_args)
    vec_indices = _get_facet_grid_vec(nb_values, nb_cols, nb_rows)
    return vec_indices, (nb_cols, nb_rows)
