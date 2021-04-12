install.packages("versions", dependencies=TRUE)
library(versions)


required_libraries <- c(
    "arsenal",        
    "urltools", 
    "ggtext",
    "IRdisplay",
    #"DescTools", 
    "quantreg",
    "SparseM",
    "MASS",  
    "survminer",
    "ggpubr",   
    "survival",
    "kableExtra",
    "devtools",
    "usethis", 
    "forcats", 
    "stringr",
    "dplyr",       
    "purrr",     
    "readr",     
    "tidyr",  
    "tibble", 
    "ggplot2", 
    "tidyverse",
    "magrittr"
)

required_versions <- c(
    "3.5.0", 
    "1.7.3",
    "0.1.1",
    "1.0", 
    #"0.99.40",
    "5.82", 
    "1.78",   
    "7.3-53",
    "0.4.8",
    "0.4.0",
    "3.2-7",
    "1.3.1", 
    "2.4.0",
    "2.0.1",  
    "0.5.0",
    "1.4.0",
    "1.0.3",
    "0.3.4", 
    "1.4.0",
    "1.1.2", 
    "3.0.5",
    "3.3.3",
    "1.3.0",
    "2.0.1"
)

install.versions(required_libraries, required_versions)

for (package in required_libraries) {
    library(package, character.only = TRUE)
}


install.packages("DescTools")
library(DescTools)