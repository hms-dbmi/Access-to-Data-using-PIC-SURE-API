library("stringr")
library("dplyr")

TokenManager <- function(token_file) {
    token = scan(token_file, what = "character")
    return(token)
}

## Parse variables Dictionary variable names and return a DataFrame with as much columns as their are levels
get_multiIndex_variablesDict <- function(variablesDict) {
    splitted <- gsub("^\\\\", "", variablesDict[["name"]]) %>% 
        strsplit("\\\\") 
    multiIndex <- lapply(splitted, function(x) {
        names(x) <- paste0("level_", 1:length(x) - 1)
        return(x)
    }) %>% do.call(dplyr::bind_rows, .)
    multiIndex[["name"]] <- variablesDict[["name"]]
    multiIndex[["simplified_name"]] <- sapply(splitted, function(x) x[length(x)])
    multiIndex <- dplyr::left_join(multiIndex, variablesDict, by="name")
    multiIndex["nb_modalities"] <- ifelse(sapply(variablesDict[["categoryValues"]], is.na) %>% unname(), 
              sapply(variablesDict[["categoryValues"]], length) %>% unname(), 
              NA)
    level_col_names <- names(multiIndex)[grep("^.*level.*$", names(multiIndex))]
    columns_order <- c(level_col_names, "simplified_name", "name", "observationCount", "categorical", "categoryValues", "nb_modalities", "min", "max", "HpdsDataType")
    return(multiIndex[columns_order])
}
                                              
### Since data frame names aren't the same between dictionary and data, workaround needed: parsing and transforming variable names
parsing_varNames <- function(varNames) {
    parsed <- str_replace_all(varNames, "[\\W]", ".") %>%
                str_c("X", .) 
    return(parsed)
}

checking_parsing <- function(df_varNames, parsed_varNames) {
    tryCatch({
        stopifnot(all(df_varNames %in% parsed_varNames)) 
        stopifnot(all(parsed_varNames %in% df_varNames))        
        print("Every names match!")
    }, warning = function(w) {
        
    }, error = function(e) {
        mask = ! df_varNames %in% parsed_varNames
        cat(df_varNames[mask], "not found in parsed varnames", "\n", sep = "\n")
        mask = ! parsed_varNames %in% df_varNames
        cat(parsed_varNames[mask], "not found in original varnames", "\n", sep = "\n")                
    })
}