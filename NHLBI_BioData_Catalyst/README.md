# NHLBI BioData Catalyst
For NHLBI research investigators who need to find, access, share, store, cross-link, and compute on large scale data sets, NHLBI BioData Catalyst will serve as a cloud-based platform providing tools, applications, and workflows to enable these capabilities in secure workspaces. BioData Catalyst is a rationally organized digital environment that will accelerate efficient biomedical research and maximize community engagement and productivity through increased access to NHLBI data sets and innovative data analysis capabilities. By making these data sets accessible and usable to varied users, BioData Catalyst will drive discovery and scientific advancement, leading to novel diagnostic tools, therapeutic options, and prevention strategies for heart, lung, blood, and sleep disorders.

https://biodatacatalyst.nhlbi.nih.gov/

Access to data: https://picsure.biodatacatalyst.nhlbi.nih.gov

# PIC-SURE_API BioData Catalyst examples
This folder contains various PICSURE API use-cases and illustration examples using BioData Catalyst studies. PIC-SURE API is available in two languages --R and python. PIC-SURE API requires R 3.5 or later, or python 3.6 or later.

## Repo organisation

Several Jupyter/RMarkdown notebooks examples are available for both R and python in the respective subfolders:
  - get_your_token.ipynb: **Start from here if you're using the PIC-SURE API for the first time**. This notebook explain how to get a user specific security token, mandatory to be able to run the other notebooks.
  - PICSURE-API_101.ipynb: An illustration of the main functionalities of the PIC-SURE API.
  - PheWAS.ipynb: A straightforward PIC-SURE API use-case, using a PheWAS analysis as an illustration example.
  - HarmonizedVariables_analysis.ipynb: An example of how to access and work with the "harmonized variables" across the TOPMed studies.
