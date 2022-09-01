install.packages("versions", dependencies=TRUE)
library(versions)


required_libraries <- c(
    "tidyverse", # imports ggplot2, dplyr, tidyr, readr, purrr, tibble, stringr, forcats
    "urltools", 
    "SparseM", # depends on methods; imports graphics, stats, utils
    "MASS",  # depends on R, grDevices, graphics, stats, utils; imports 
    "ggpubr",   
    "survival", # imports graphics, Matrix, methods, splines, stats, utils
    "kableExtra", # imports knitr, magrittr, among other things
    "devtools", # many imports 
    "usethis", # many imports
    'coin'
)

required_versions <- c(
    "1.3.1",
    "1.7.3",
    "1.81",
    "7.3-53.1",
    "0.4.0",
    "3.2-10",
    "1.3.4",
    "2.4.0",
    "2.0.1",
    "1.4-1"
)

install.versions(required_libraries, required_versions, verbose = FALSE, quiet = TRUE)

# the following packages do not install correctly in all environments when controlling version
#install.packages('ggpubr')
#library(ggpubr)


for (package in required_libraries) {
    library(package, character.only = TRUE)
}
