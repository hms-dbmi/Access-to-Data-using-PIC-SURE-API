The **Patient Information Commons: Standard Unification of Research Elements (PIC-SURE)** integrates clinical and genomic data to allow users to search, query, and export data at the variable and variant levels. This allows users to create analysis-ready data frames without manually mapping and merging files. 

# *NHLBI BioData Catalyst®*
*NHLBI BioData Catalyst® (BDC)* is a cloud-based platform providing tools, applications, and workflows in secure workspaces. By increasing access to data and innovative data analysis capabilities, *BDC* accelerates efficient biomedical research that drives discovery and scientific advancement, leading to novel diagnostic tools, therapeutics, and prevention strategies for heart, lung, blood, and sleep disorders.

As part of *BDC*, the PIC-SURE platform has been integrating clinical and genomic datasets funded by the National Heart Lung and Blood Institute (NHLBI). 

## PIC-SURE API Overview
The main goal of the PIC-SURE Application Programming Interface (API) is to provide a simple and reliable way to work with restricted-access data from NHLBI Trans-Omics for Precision Medicine (TOPMed) and TOPMed-related studies that are part of *BDC*. Each individual study is accessible in a unique, easy-to-use, tabular format directly in an R or Python environment. The API allows also to query studies subset, based on patients matching specified criteria, as well as to retrieve a cohort that has been created using the [PIC-SURE user interface (UI)](https://picsure.biodatacatalyst.nhlbi.nih.gov). Additionally, the TOPMed Data Coordinating Center curation team has harmonized 43 specific phenotype variables across multiple TOPMed studies, which are  accessible directly through the PIC-SURE API. 

Original data exposed through the PIC-SURE API encompasses a large heterogeneity of data organization underneath. PIC-SURE hides this complexity and exposes the different study datasets in a single tabular format. Simplifying the process of data extraction allows investigators to focus on downstream analysis and to facilitate reproducible sciences.

## *BDC Powered by PIC-SURE* Example Notebooks
This folder contains various *BDC Powered by PIC-SURE (BDC-PIC-SURE)* API use cases and illustration examples using studies available on *BDC*. The API is available in two different programming languages, python and R, enabling investigators to query the databases the same way using either language. It is actively developed by the Avillach Lab at Harvard Medical School.

The PIC-SURE API requires R 3.4 or later or Python 3.6 or later.

**Before running these example notebooks, please be sure to review the "Get your security token" documentation below. It explains about how to get a security token, which is mandatory to access the databases.**

### Get your security token

**In order to be able to run any one of these examples, you'll need to get a personal user security token**. This is the way the API grants access to individual users to protected-access data. **The user token is strictly personal, be careful not to share it with anyone**.

To get your token, process as follows:
1. In a web browser, navigate to the [*BDC-PIC-SURE* home page](https://picsure.biodatacatalyst.nhlbi.nih.gov/) and click on the 'eRA Commons' button to log in.
2. Once logged in, click on the **Prepare for Analysis** tab.
3. Click **Copy** to copy the user token to your clipboard.
4. In the analysis environment where you are running the example notebooks, create a file called `token.txt` into the home folder and paste the user token into it. Save the file.

### Available notebooks

Example Jupyter notebooks are available in Python and R. Additionally, R Markdown examples are available for RStudio environments. In the R, python, and RStudio folders, six notebooks are available:
- 0_Export_from_UI.ipynb: A tutorial on how to export a data frame built in the UI into an analysis workspace.
- 1_PICSURE_API_101: An illustration of the main functionalities of the PIC-SURE API.
- 2_PheWAS: A straightforward PIC-SURE API use-case, using a PheWAS (Phenome-Wide Association Study) analysis as an illustration example.
- 3_HarmonizedVariables_analysis: An example of how to access and work with the "harmonized variables" across the TOPMed studies.
- 4_Genomic_Queries: An example of how to filter participants using categorical variant filters. 
- 5_LongitudinalData: An example of how to find longitudinal variables in the data dictionary, use these variables to extract data, and perform analysis. 
- 6_Sickle_Cell: An example of how to search and query the Hematopoietic Cell Transplant for Sickle Cell Disease (HCT for SCD) dataset.
- 7_Harmonization_with_PICSURE: Examples of harmonization across studies using (1) sex and BMI variables (including TOPMed Harmonized dataset and others) and (2) orthopnea and pneumonia variables.
- 8_RECOVER.ipynb & 8_RECOVER_executed.html: An example using the RECOVER Adult Cohort study to investigate post-acute sequelae of SARS-CoV-2 infection (PASC), also known as long COVID, and headaches.  
- ORCHID (COVID19): the code accompanying the JAMA publication on November 7th 2021: "[Effect of Hydroxychloroquine on Clinical Status at 14 Days in Hospitalized Patients With COVID-19](https://jamanetwork.com/journals/jama/fullarticle/2772922)"

## Contact
For bug reports or additional information, please visit: https://biodatacatalyst.nhlbi.nih.gov/contact

## Additional resources

PIC-SURE API GitHub repository links:
* https://github.com/hms-dbmi/pic-sure-biodatacatalyst-python-adapter-hpds
* https://github.com/hms-dbmi/pic-sure-python-adapter-hpds
* https://github.com/hms-dbmi/pic-sure-python-client

*BDC* homepage: https://biodatacatalyst.nhlbi.nih.gov/

*BDC Powered by PIC-SURE* homepage: https://picsure.biodatacatalyst.nhlbi.nih.gov

### Grant information
As part of *BDC*, PIC-SURE development is funded by the following grant:
- “The development and integration of advanced cyberinfrastructure, leading-edge tools, and FAIR data to accelerate discovery by the NHLBI research community”
- Grant Number: OT3 HL 142480
