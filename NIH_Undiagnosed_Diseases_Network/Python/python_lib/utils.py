import pandas as pd
import numpy as np


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

    variablesDict = variablesDict.rename_axis("varName", axis=0).sort_index()
    multi_index = _varName_toMultiIndex(variablesDict.index)
    last_valid_name_list = _get_simplified_varname(multi_index)
    variablesDict = variablesDict.reset_index(drop=False)
    variablesDict.index = multi_index.rename(["level_" + str(n) for n, _ in enumerate(multi_index.names)])
    variablesDict["simplified_varName"] = last_valid_name_list
    columns_order = ["simplified_varName", "varName", "observationCount", "categorical", "categoryValues", "min", "max", "HpdsDataType"]
    return variablesDict[columns_order]


def get_dic_renaming_vars(variablesDict: pd.DataFrame) -> dict:
    simplified_varName = variablesDict["simplified_varName"].tolist()
    varName = variablesDict["varName"].tolist()
    dic_renaming = {long: simple for long, simple in zip(varName, simplified_varName)}
    return dic_renaming


def match_dummies_to_varNames(plain_columns: pd.Index,
                             dummies_columns: pd.Index,
                             columns: list =["simplified_varName", "dummies_varName"]) -> pd.DataFrame:
    dic_map = {}
    for plain_col in plain_columns:
        dic_map[plain_col] = [dummy_col for dummy_col in dummies_columns if dummy_col.startswith(plain_col)]
    matching_df = pd.DataFrame([[k, v] for k, v_list in dic_map.items() for v in v_list], columns=columns)
    return matching_df


def joining_variablesDict_onCol(variablesDict: pd.DataFrame,
                                 df: pd.DataFrame,
                                 left_col="simplified_varName",
                                 right_col="simplified_varName",
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
