list_packages <- c("ggplot2",
                   "dplyr",
                   "tidyr",
                   "urltools",
                   "devtools",
                   "ggrepel")

if (grepl("(amzn)|(aws)", Sys.info()[["release"]])) {
    install.packages("cli")
    install.packages("usethis")
    install.packages("openssl")
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
if (getRversion() < "3.5.0") {
    isFALSE = function(x) {
      is.logical(x) && length(x) == 1L && !is.na(x) && !x
    }
    isTRUE = function(x) {
      is.logical(x) && length(x) == 1L && !is.na(x) && x
    }
}


