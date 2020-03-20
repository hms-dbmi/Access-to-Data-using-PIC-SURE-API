#!/usr/bin/env python
# coding: utf-8

# In[138]:


#PIC-SURE
import PicSureClient
import PicSureHpdsLib
#STATS
import pandas as pd
import numpy as np
import matplotlib
import matplotlib.pyplot as plt

fig_size = matplotlib.rcParams["figure.figsize"]
 
# Prints: [8.0, 6.0]
fig_size[0] = 14
fig_size[1] = 8
matplotlib.rcParams["figure.figsize"] = fig_size

font = {'weight' : 'bold',
        'size'   : 12}

matplotlib.rc('font', **font)

import seaborn as sns
from lifelines import KaplanMeierFitter
import tokenManager
import re


# In[108]:


def getTermList(srch):
    terms = resource.dictionary().find(srch)
    term_list = terms.keys()
    term_list.sort()
    i = 0
    print("-------------------------")
    print("List for", srch)
    print("-------------------------")
    for term in term_list:
        print(i, " | ", term)
        i += 1
    return term_list 

def printColumnsIndex(df):
    i = 0
    for col in df.columns:
        print(i," | ",col)
        i += 1

def recodeHematocrit(hematocrit):
        if float(hematocrit) <= 20:
            return "20 or less"
        else:
            if float(hematocrit) >= 30:
                return "30 or more"
            else:
                return "between 20 and 30"


# In[7]:


PICSURE_network_URL = "<PIC-SURE_URL_for_SCD>"
resource_id = "<Resource_ID>"
token_name = "token.txt"
__token__ = tokenManager.importToken(token_name)


# In[8]:


client = PicSureClient.Client()
connection = client.connect(PICSURE_network_URL, __token__)
adapter = PicSureHpdsLib.Adapter(connection)
#adapter.list()
resource = adapter.useResource(resource_id)


# In[64]:


scdTerms = getTermList("sickle cell disease or s beta thalassemia")
asthmaTerms = getTermList("diagnosis of asthma")
medicationTerms = getTermList("medication name")
hematocritTerms = getTermList("hematocrit")


# In[65]:


query = resource.query()
query.select().add(scdTerms)
query.select().add(asthmaTerms)
query.select().add(medicationTerms)
query.select().add(hematocritTerms)


# In[100]:


result_df = query.getResultsDataFrame()
result_df = result_df.iloc[:, [0,1,2,4,5]]
result_df.head()


# In[101]:


columns = result_df.columns.values
columns[1] = "hematocrit"
columns[2] = "sickleCellDisease"
columns[3] = "medication"
columns[4] = "asthma"
result_df.columns = columns


# In[105]:


result_df['hematocrit'].unique()


# In[114]:


sc_asthma_df = result_df[(result_df['asthma'] == 'Yes') & (result_df['sickleCellDisease'] == 'Yes')]
sc_no_asthma_df = result_df[(result_df['asthma'] == 'No') & (result_df['sickleCellDisease'] == 'Yes')]


# In[115]:


sc_asthma_df['hematocritCategories'] = sc_asthma_df.hematocrit.apply(recodeHematocrit)
sc_no_asthma_df['hematocritCategories'] = sc_no_asthma_df.hematocrit.apply(recodeHematocrit)


# In[118]:


sc_no_asthma_df.shape


# In[119]:


sc_asthma_df.shape


# In[120]:


sc_no_asthma_hem_cat_df = pd.DataFrame(sc_no_asthma_df.groupby("hematocritCategories").hematocritCategories.count())
sc_no_asthma_hem_cat_df["pct"] = sc_no_asthma_hem_cat_df.hematocritCategories / sc_no_asthma_hem_cat_df.hematocritCategories.sum()*100
sc_no_asthma_hem_cat_df


# In[121]:


sc_asthma_hem_cat_df = pd.DataFrame(sc_asthma_df.groupby("hematocritCategories").hematocritCategories.count())
sc_asthma_hem_cat_df["pct"] = sc_asthma_hem_cat_df.hematocritCategories / sc_asthma_hem_cat_df.hematocritCategories.sum()*100
sc_asthma_hem_cat_df


# In[124]:


med_df1 = pd.DataFrame(sc_asthma_df.groupby("medication").medication.count())
med_df1['pct'] = med_df1.medication / med_df1.medication.sum()*100
med_df1


# In[125]:


med_df2 = pd.DataFrame(sc_no_asthma_df.groupby("medication").medication.count())
med_df2['pct'] = med_df2.medication / med_df2.medication.sum()*100
med_df2


# In[195]:


n_groups = len(med_df2) if len(med_df2) > len(med_df1) else len(med_df1)
ref_df, nonref_df = (med_df2, med_df1) if len(med_df2) > len(med_df1) else (med_df1, med_df2)
second_set = []
for i in range(n_groups):
    ref = ref_df.index[i]
    second_set.append(0) if ref not in list(nonref_df.index.values) else second_set.extend(list(nonref_df.loc[[ref],['pct']]['pct']))
    


# In[199]:


fig, ax = plt.subplots()
index = np.arange(n_groups)
bar_width = 0.35
opacity = 0.8 

rects1 = plt.barh(index, tuple(ref_df['pct']), bar_width, alpha=opacity, color='b', label='SCD without Asthma')
rects2 = plt.barh(index + bar_width, tuple(second_set), bar_width, alpha=opacity, color='g', label='SCD with Asthma')

plt.ylabel('Medication')
plt.xlabel('Percentages')
plt.title('Medication: Comparison between SCD Patients with and without Asthma')
plt.yticks(index + bar_width / 2, tuple(ref_df.index.values))
plt.legend()

plt.tight_layout()
plt.show()


# In[ ]:




