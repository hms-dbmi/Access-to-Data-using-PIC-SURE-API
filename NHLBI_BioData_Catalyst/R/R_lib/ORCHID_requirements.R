required_libraries <- c(
    "ggplot2",
    "dplyr",
    "tidyr",
    "devtools",
    "ggrepel",
    'tidyverse',
    'devtools',
    'hms', # for kableExtra
    'knitr',
    #'kableExtra',
    'survival',
    #'survminer',
    'cmprsk',
    'MASS',
    'quantreg',
    'DescTools', 
    'IRdisplay', 
    'ggtext',
    'urltools', 
    'arsenal')

for (package in required_libraries) {
  if (!package %in% installed.packages()) {
      install.packages(package, dependencies=TRUE)
      }
  library(package, character.only = TRUE)
}