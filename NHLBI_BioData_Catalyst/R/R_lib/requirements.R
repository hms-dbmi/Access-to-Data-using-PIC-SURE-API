list_packages <- c("ggplot2",
                   "dplyr",
                   "tidyr",
                   "devtools",
                   "ggrepel")

if (grepl("amzn", Sys.info()[["release"]])) {
    install.packages("cli")
    install.packages("usethis")
    install.packages("devtools")
}

cat("installing: \n")
for (package in list_packages)  {
    cat("- ", package, "\n")
}

for (package in list_packages){
     if(! package %in% installed.packages()){
         install.packages(package, dependencies = TRUE)
    }
}

for (package in list_packages) {
    library(package, character.only = TRUE)
}