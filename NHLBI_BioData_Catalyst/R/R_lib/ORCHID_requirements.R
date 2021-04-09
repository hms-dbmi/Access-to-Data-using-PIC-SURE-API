required_libraries <- c(
    "arsenal",
    "urltools",
    "ggtext",
    "IRdisplay",
    "DescTools",
    "quantreg",
    "SparseM",
    "MASS",
    "survminer",
    "ggpubr",
    "survival",
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
    "ggrepel",
    "cmprsk",
    "versions"
)

for (package in required_libraries) {
  if (!package %in% installed.packages()) {
      install.packages(package, dependencies=TRUE)
      }
  library(package, character.only = TRUE)
}

install.versions("kableExtra", "1.3.1")
library(kableExtra)