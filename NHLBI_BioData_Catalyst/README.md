# NHLBI BioData Catalyst®
*NHLBI BioData Catalyst®* (BDC) is a cloud-based platform providing tools, applications, and workflows in secure workspaces. By increasing access to NHLBI datasets and innovative data analysis capabilities, BDC accelerates efficient biomedical research that drives discovery and scientific advancement, leading to novel diagnostic tools, therapeutics, and prevention strategies for heart, lung, blood, and sleep disorders.

https://biodatacatalyst.nhlbi.nih.gov/

Access to data: https://picsure.biodatacatalyst.nhlbi.nih.gov

# Grant information

As part of BDC, PIC-SURE development is funded by the following grant:
- “The development and integration of advanced cyberinfrastructure, leading-edge tools, and FAIR data to accelerate discovery by the NHLBI research community”
- Grant Number: OT3 HL 142480

# PIC-SURE_API BioData Catalyst examples

This folder contains various PIC-SURE API use-cases and illustration examples using BDC studies. PIC-SURE API is available in two languages --R and python. PIC-SURE API requires R 3.4 or later, or python 3.6 or later.


## PIC-SURE API Overview
The main goal of the PIC-SURE API is to provide a simple and reliable way to work with restricted-access data from NHLBI Trans-Omics for Precision Medicine (TOPMed) and TOPMed related studies that are part of BDC. Each individual study is accessible in a unique, easy to use, tabular format directly in an R or python environment. The API allows also to query studies subset, based on patients matching specified criteria, as well as to retrieve a cohort that has been created using the [PIC-SURE interface](https://picsure.biodatacatalyst.nhlbi.nih.gov). Finally, 43 specific phenotype variables that have been harmonized across multiple TOPMed studies are also accessible directly through the PIC-SURE API. 

### What is PIC-SURE? 

As part of BDC, the Patient Information Commons Standard Unification of Research Elements (PIC-SURE) platform has been integrating clinical and genomic datasets funded by the National Heart Lung and Blood Institute (NHLBI). 

Original data exposed through the PIC-SURE API encompasses a large heterogeneity of data organization underneath. PIC-SURE hides this complexity and exposes the different study datasets in a single tabular format. By simplifying the process of data extraction, it allows investigators to focus on downstream analysis and to facilitate reproducible sciences.

The API is available in two different programming languages, python and R, enabling investigators to query the databases the same way using either language. It is actively developed by the Avillach Lab at Harvard Medical School.

The API is only a small part of the PIC-SURE project. Among other things, PIC-SURE also offers a graphical user interface that allows researchers to explore variables across multiple studies, filter patients that match criteria, and create cohorts from this interactive exploration.


PIC-SURE API GitHub repo:
* https://github.com/hms-dbmi/pic-sure-biodatacatalyst-python-adapter-hpds
* https://github.com/hms-dbmi/pic-sure-python-adapter-hpds
* https://github.com/hms-dbmi/pic-sure-python-client

**Before running this notebook, please be sure to review the "Get your security token" documentation, which exists in the NHLBI_BioData_Catalyst [README.md file](https://github.com/hms-dbmi/Access-to-Data-using-PIC-SURE-API/tree/master/NHLBI_BioData_Catalyst#get-your-security-token). It explains about how to get a security token, which is mandatory to access the databases.**

## Get your security token

**In order to be able to run any one of these examples, you'll need to get a personal user security token**. This is the way the API grants access to individual users to protected-access data. **The user token is strictly personal, be careful not to share it with anyone**.

To get your token, process as follows:
1. In a web browser, open the PIC-SURE UI login page: https://picsure.biodatacatalyst.nhlbi.nih.gov/, and click on the 'eRA Commons' button to log in.
2. On the user-interface click on USER PROFILE
3. On the pop-up window, click on REFRESH and then COPY
4. Back into your Jupyter environment, create a text file called `token.txt` into the python and/or R folders and paste the token into it.

<img src="https://drive.google.com/uc?id=1WjPgOqKAuaEs6BEpzCHBEMpdhiua7Jez">

## Available notebooks

Example Jupyter notebooks are available in python and R. Additionally, R Markdown examples are available for RStudio environments. In the R, python, and RStudio folders, six notebooks are available:
- 0_Export_from_UI.ipynb: A tutorial on how to export a dataframe built in the UI into an analysis workspace.
- 1_PICSURE_API_101: An illustration of the main functionalities of the PIC-SURE API.
- 2_PheWAS: A straightforward PIC-SURE API use-case, using a PheWAS (Phenome-Wide Association Study) analysis as an illustration example.
- 3_HarmonizedVariables_analysis: An example of how to access and work with the "harmonized variables" across the TOPMed studies.
- 4_Genomic_Queries: An example of how to filter partipants using categorical variant filters. 
- 5_LongitudinalData: An example of how to find longitudinal variables in the data dictionary, use these variables to extract data, and perform analysis. 
- 6_Sickle_Cell: An example on how to search and query the Hematopoietic Cell Transplant for Sickle Cell Disease (HCT for SCD) dataset.
- 7_Harmonization_with_PICSURE: Examples of harmonization across studies using (1) sex and BMI variables (including TOPMed Harmonized dataset and others) and (2) orthopnea and pneumonia variables.
- ORCHID (COVID19): the code accompanying the JAMA publication on November 7th 2021: "[Effect of Hydroxychloroquine on Clinical Status at 14 Days in Hospitalized Patients With COVID-19](https://jamanetwork.com/journals/jama/fullarticle/2772922)"

## Contact

For bug report or additional information, please visit: https://biodatacatalyst.nhlbi.nih.gov/contact
