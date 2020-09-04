# Cure Sickle Cell
The Cure Sickle Cell Initiative (CureSCi) was established in 2018 by the National Heart, Lung, and Blood Institute to accelerate the development of treatments aimed at a genetic-based cure for sickle cell disease (SCD).

http://curesci.azurewebsites.net

Access to data: https://curesc.hms.harvard.edu

# Grant information



# PIC-SURE_API Cure Sickle Cell examples

This folder contains various PIC-SURE API use-cases and illustration examples using Cure Sickle Cell studies. PIC-SURE API is available in two languages --R and python. PIC-SURE API requires R 3.5 or later, or python 3.6 or later.


## PIC-SURE API Overview

The main goal of the PIC-SURE API is to provide a simple and reliable way to work with restricted-access data studies that are part of CureSC. Each individual study is accessible in a unique, easy to use, tabular format directly in an R or python environment. The API allows also to query studies subset, based on patients matching specified criteria, as well as to retrieve a cohort that has been created using the [PIC-SURE interface](https://curesc.hms.harvard.edu). 

## Setting up your environment
Prior to exploring the data you will need to set up your local JupyterNotebook. 
1. In a web browser, open the PIC-SURE UI login page: https://curesc.hms.harvard.edu, and login with the authentication provider you have been assigned.
2. On the user-interface click on ADMIN
3. On the user-interface click on APPLICATIONS, in the dropdown select JupyterHub. This is your own local instance of JupyterHub. 
4. On the user-interface click on NEW, in the dropdown select Terminal.  This will open a new window. Copy and paste the below:
git clone https://github.com/hms-dbmi/Access-to-Data-using-PIC-SURE-API 
5. Click enter and close the window. 
6. Access-to-Data-using-PIC-SURE-API folder has been created. Click the folder to open it. Click the Cure_Sickle_Cell folder.
7. Choose Python or R folder.

![Set up JupyterHub](curesc_jupyterhub.gif)

Follow the directions below to add your security token. 

## Get your security token

**In order to be able to run any one of these examples, you'll need to get a personal user security token**. This is the way the API grants access to individual users to protected-access data. **The user token is strictly personal, be careful not to share it with anyone**.

To get your token, follow the process below:
1. In a web browser, open the PIC-SURE UI login page: https://curesc.hms.harvard.edu, and login with the authentication provider you have been assigned.
2. On the user-interface click on ADMIN
3. On the user-interface click on USER PROFILE
4. On the pop-up window, click on REFRESH and then COPY
5. In your Jupyter environment, python and/or R folders, click NEW, in the dropdown select Text File. Paste your security token into the text file. Click File and in the dropdown select Rename. In the pop-up window name the file `token.txt`. Click File and in the dropdown select Save. 



## Available notebooks

In each R and python folders, the example notebooks are available: 
- 1_PICSURE-API_101.ipynb: an illustration of the main functionalities of the PIC-SURE API.


## Contact

For bug report or additional information, please submit a ticket to: http://avillachlabsupport.hms.harvard.edu 
