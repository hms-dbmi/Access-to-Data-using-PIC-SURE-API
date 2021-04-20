install.packages("versions", dependencies=TRUE)
library(versions)


required_libraries <- c(
    "tidyverse", # imports ggplot2, dplyr, tidyr, readr, purrr, tibble, stringr, forcats
    "arsenal", # depends on R, stats; imports knitr, utils       
    "urltools", 
    "ggtext", # impoera ggplot2, grid, gridtext, rland, scales
    "SparseM", # depends on methods; imports graphics, stats, utils
    "quantreg", # depends on R, stats, sparseM; imports methods, graphics, Matrix, MatrixModels, conquer
    "MASS",  # depends on R, grDevices, graphics, stats, utils; imports 
    "ggpubr",   
    "survminer", # depends on ggplot2, ggpubr; imports a lot of things
    "survival", # imports graphics, Matrix, methods, splines, stats, utils
    "kableExtra", # imports knitr, magrittr, among other things
    "devtools", # many imports 
    "usethis", # many imports
    #"magrittr", # imported by kableExtra
    "DescTools", # imports MASS and others
    "cmprsk", #depeds on survival
    'coin'
)

required_versions <- c(
    "1.3.1",
    "3.6.2",
    "1.7.3",
    "0.1.1",
    "1.81",
    "5.85",
    "7.3-53.1",
    "0.4.0",
    "0.4.9",
    "3.2-10",
    "1.3.4",
    "2.4.0",
    "2.0.1",
    "0.99.41",
    "2.2-10",
    "1.4-1"
)

install.versions(required_libraries, required_versions)


### test versions command

#install.packages(required_libraries)

#for (pkg in required_libraries) {
#    print(paste0(pkg, ': ', packageVersion(pkg)))
#}

#for (i in c(1:length(required_libraries))) {
#    install.versions(required_libraries[i], required_versions[i])
#}

###

#install.packages('tibble')
#library(tibble)

for (package in required_libraries) {
    library(package, character.only = TRUE)
}
