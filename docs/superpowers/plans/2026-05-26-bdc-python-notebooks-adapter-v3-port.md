# BDC Python Notebooks → `picsure` Adapter Port — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the 9 in-scope BDC Python notebooks in `NHLBI_BioData_Catalyst/python/` to use the rewritten `picsure` adapter API, then verify each executes clean against live BDC.

**Architecture:** Each notebook is edited in place (cell content swapped legacy→new API; API-describing markdown updated). All notebooks share one Standard Header Block for install/import/connect. The query-build model is the 3-function `buildClause` / `buildClauseGroup` / `buildQuery` + `session.runQuery`. Verification is a single live pass with `jupyter nbconvert --execute` after all rewrites (per spec), iterating on failures.

**Tech Stack:** Jupyter notebooks (`.ipynb`), `picsure` package (installed from `git+…@main`), pandas, `jupyter nbconvert`. Work happens directly on the `adapters_v3` branch (no worktree — the user pinned this branch).

**Spec:** `docs/superpowers/specs/2026-05-26-bdc-python-notebooks-adapter-v3-port-design.md`

---

## Standard Header Block (used by every notebook task)

Every notebook's legacy install/import/connect cells get replaced by these.

**Install cell** (replaces the 3 legacy `pip install` lines):
```python
!{sys.executable} -m pip install --upgrade --force-reinstall git+https://github.com/hms-dbmi/pic-sure-python-adapter-hpds.git@main
```

**Import cell** (replaces `import PicSureClient` / `import PicSureBdcAdapter`).
Keep each notebook's other imports (`pandas`, `matplotlib`, `numpy`, etc.); only the PIC-SURE imports change:
```python
import picsure
```

**Connect cell** (replaces the `PICSURE_network_URL` + `PicSureBdcAdapter.Adapter(...)` cell):
```python
token_file = "token.txt"

with open(token_file, "r") as f:
    my_token = f.read()

session = picsure.connect(picsure.Platform.BDC_AUTHORIZED, my_token)
```

**Per-notebook the legacy `sys`/`pandas`/etc. setup cell is kept as-is** (it does not reference PIC-SURE). Do not remove `import sys` — the install cell needs `sys.executable`.

## Translation cheatsheet (used by every notebook task)

- `bdc.useDictionary().dictionary().find(TERM)` + `.dataframe()` → `session.searchDictionary(TERM)` (already a DataFrame).
- DataFrame columns: `HPDS_PATH` / `columnmeta_HPDS_PATH` → `conceptPath`; `columnmeta_name` → `name`; `columnmeta_description` → `description`; `columnmeta_study_id` → `studyId`; `studyId`, `values` unchanged.
- `bdc.useAuthPicSure().query()` → no object; build clauses directly.
- `query.filter().add(path, "Cat")` → `picsure.buildClause(path, picsure.PhenotypicFilterType.FILTER, categories="Cat")`.
- `query.filter().add(path, min=X)` → `picsure.buildClause(path, picsure.PhenotypicFilterType.FILTER, min=X)`.
- `query.require().add([paths])` → `picsure.buildClause(paths, picsure.PhenotypicFilterType.REQUIRE)`.
- `query.anyof().add([paths])` → OR group of per-path ANYRECORD clauses (see helper below).
- `query.select().add([paths])` → pass those paths to `buildQuery(includeConcepts=[...])`.
- combine multiple filter clauses → `picsure.buildClauseGroup([c1, c2, ...], operator=picsure.GroupOperator.AND)`.
- assemble + run for rows → `q = picsure.buildQuery(phenotypicFilter=TREE, includeConcepts=[...])`; `session.runQuery(q, type=picsure.QueryType.PARTICIPANT)`.
- `query.getResultsDataFrame()` / `getResultsDataFrame(low_memory=...)` → `session.runQuery(q, type=picsure.QueryType.PARTICIPANT)` (drop `low_memory`; it's not a param).
- `query.getCount()` → `session.runQuery(q, type=picsure.QueryType.COUNT).value`.
- `resource.retrieveQueryResults(uuid)` → `session.runQueryByID(uuid, type=picsure.QueryType.PARTICIPANT)`.

**`anyof` helper** — when legacy did `query.anyof().add(paths)` over a list `paths`, the
participant set is "has a record in ANY listed concept." Build it as:
```python
anyof_group = picsure.buildClauseGroup(
    [picsure.buildClause(p, picsure.PhenotypicFilterType.ANYRECORD) for p in list(paths)],
    operator=picsure.GroupOperator.OR,
)
q = picsure.buildQuery(phenotypicFilter=anyof_group, includeConcepts=list(paths))
df = session.runQuery(q, type=picsure.QueryType.PARTICIPANT)
```
`includeConcepts=list(paths)` reproduces the legacy behavior where the queried
variables also appear as output columns.

---

## Task 1: Environment setup for verification

**Files:**
- Create: `/tmp/picsure-nb-venv/` (scratch venv, not committed)

- [ ] **Step 1: Create a scratch venv and install the adapter + jupyter**

Run:
```bash
python3 -m venv /tmp/picsure-nb-venv
/tmp/picsure-nb-venv/bin/pip install --upgrade pip
/tmp/picsure-nb-venv/bin/pip install \
    "git+https://github.com/hms-dbmi/pic-sure-python-adapter-hpds.git@main" \
    jupyter nbconvert ipykernel pandas matplotlib numpy seaborn statsmodels scipy matplotlib-venn
```
Expected: installs succeed; `picsure` resolves.

- [ ] **Step 2: Verify the adapter imports and the API names exist**

Run:
```bash
/tmp/picsure-nb-venv/bin/python -c "import picsure; [getattr(picsure, n) for n in ['connect','Platform','buildClause','buildClauseGroup','buildQuery','PhenotypicFilterType','GroupOperator','QueryType']]; print('OK')"
```
Expected: prints `OK` with no AttributeError.

- [ ] **Step 3: Confirm token is present**

Run: `test -s /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API/NHLBI_BioData_Catalyst/python/token.txt && echo "token present"`
Expected: `token present`.

No commit (scratch env only).

---

## Task 2: Port `1_PICSURE_API_101.ipynb`

The canonical intro notebook. Legacy cells (numbers from current file): 7 (imports), 8 (3 pip installs), 9 (`import PicSureClient`/`PicSureBdcAdapter`), 11 (connect), 13 (`bdc.help()`), 17 (`dictionary.find`), 18 (`.count()`), 20 (`.dataframe().head()`), 23 (`.listPaths()[0:10]`), 25 (`.listPaths()[0]` + `.varInfo`), 27 (`find("sex")`), 29 (`useAuthPicSure().query()`), 32 (studyId filter), 34/41/47 (path lookups), 38 (`filter().add(smoke,"Current smoker")`), 45 (`filter().add(bmi,min=20)`), 49 (`require().add([age,hyperten])`), 52 (`getResultsDataFrame`).

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/1_PICSURE_API_101.ipynb`

- [ ] **Step 1: Apply the Standard Header Block** to the install/import/connect cells (see top). Keep cell 7's `pandas`/`matplotlib`/`sys` imports.

- [ ] **Step 2: Replace `bdc.help()` (cell 13)** with a brief markdown note + `session.getResourceID()` showing available resources.

- [ ] **Step 3: Replace search cells.** `dictionary = bdc.useDictionary().dictionary()` / `my_variables = dictionary.find("tutorial")` →
```python
my_variables_df = session.searchDictionary("tutorial")
```
Then `.count()` → `my_variables_df.shape[0]`; `.dataframe().head(5)` → `my_variables_df.head(5)`; `.listPaths()[0:10]` → `my_variables_df["conceptPath"].head(10).tolist()`; `.varInfo(first_var)` → `my_variables_df[my_variables_df["conceptPath"] == first_var]`.

- [ ] **Step 4: Replace the study-scoping cell (32).** Legacy `tutorial_df = my_variables_df[my_variables_df.studyId == "tutorial-biolincc_framingham"]` stays valid (`studyId` still exists). Update the path-lookup cells to use `conceptPath` instead of `HPDS_PATH` and `name` instead of `columnmeta_name`:
```python
smoke_variable_path = tutorial_df.conceptPath[tutorial_df.description == "Current cigarette smoking at exam"].item()
bmi_variable_path  = tutorial_df.conceptPath[tutorial_df.name == "BMI"].item()
age_variable_path      = tutorial_df.loc[tutorial_df.description == "Age at exam (years)", "conceptPath"].item()
hyperten_variable_path = tutorial_df.loc[tutorial_df.name == "HYPERTEN", "conceptPath"].item()
```

- [ ] **Step 5: Replace query construction.** Cells 29/38/45/49/52 become a single build + run flow:
```python
smoke_clause = picsure.buildClause(smoke_variable_path, picsure.PhenotypicFilterType.FILTER, categories="Current smoker")
bmi_clause   = picsure.buildClause(bmi_variable_path, picsure.PhenotypicFilterType.FILTER, min=20)
require_clause = picsure.buildClause([age_variable_path, hyperten_variable_path], picsure.PhenotypicFilterType.REQUIRE)

filter_tree = picsure.buildClauseGroup([smoke_clause, bmi_clause, require_clause], operator=picsure.GroupOperator.AND)
example_query = picsure.buildQuery(
    phenotypicFilter=filter_tree,
    includeConcepts=[age_variable_path, bmi_variable_path, smoke_variable_path, hyperten_variable_path],
)
example_results = session.runQuery(example_query, type=picsure.QueryType.PARTICIPANT)
example_results.head()
```

- [ ] **Step 6: Leave the downstream analysis cells unchanged** (cells 54–57: `clean_results`, `mean_multiple_values`, `ever_smoker`). These operate on the result DataFrame's concept-path columns, which `includeConcepts` preserves.

- [ ] **Step 7: Update API-describing markdown** — replace explanations of `bdc.help()`, `filter`/`require`/`anyof`, and `getResultsDataFrame` with the new build/run model. Leave Framingham narrative prose intact.

- [ ] **Step 8: Commit**
```bash
git add NHLBI_BioData_Catalyst/python/1_PICSURE_API_101.ipynb
git commit -m "Port 1_PICSURE_API_101 notebook to picsure v3 API"
```

---

## Task 3: Port `2_TOPMed_DCC_Harmonized_Variables_analysis.ipynb`

Legacy API cells: 7 (pip), 8 (imports), 10 (connect), 16 (`find('harmonized')` + studyId filter), 28 (`anyof().add(HPDS_PATH list)` + `getResultsDataFrame`).

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/2_TOPMed_DCC_Harmonized_Variables_analysis.ipynb`

- [ ] **Step 1: Apply the Standard Header Block.**

- [ ] **Step 2: Replace the dictionary search (cell 16):**
```python
harmonized_dataframe = session.searchDictionary("harmonized")
harmonized_dataframe = harmonized_dataframe[harmonized_dataframe["studyId"] == "DCC Harmonized data set"]
print(harmonized_dataframe.shape)
harmonized_dataframe.head()
```

- [ ] **Step 3: Update any intermediate cell that derives `demographic_harmonized_dataframe`** to use `conceptPath` instead of `HPDS_PATH` when collecting paths (`vars_of_interest = demographic_harmonized_dataframe["conceptPath"].tolist()`).

- [ ] **Step 4: Replace the query (cell 28)** using the `anyof` helper:
```python
vars_of_interest = demographic_harmonized_dataframe["conceptPath"].tolist()
anyof_group = picsure.buildClauseGroup(
    [picsure.buildClause(p, picsure.PhenotypicFilterType.ANYRECORD) for p in vars_of_interest],
    operator=picsure.GroupOperator.OR,
)
demographic_query = picsure.buildQuery(phenotypicFilter=anyof_group, includeConcepts=vars_of_interest)
demographic_results = session.runQuery(demographic_query, type=picsure.QueryType.PARTICIPANT)
demographic_results.head()
```

- [ ] **Step 5: Update API-describing markdown; leave analysis/plot cells unchanged.**

- [ ] **Step 6: Commit**
```bash
git add NHLBI_BioData_Catalyst/python/2_TOPMed_DCC_Harmonized_Variables_analysis.ipynb
git commit -m "Port 2_TOPMed_DCC_Harmonized_Variables_analysis notebook to picsure v3 API"
```

---

## Task 4: Port `3_PheWAS.ipynb`

Legacy API cells: 7 (pip), 8 (imports), 11 (connect), 15 (`find('harmonized')` + `columnmeta_name` filter + studyId filter), 20 (`anyof().add(cholesterol_path)` + `select().add(selected_vars)` + `getResultsDataFrame`).

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/3_PheWAS.ipynb`

- [ ] **Step 1: Apply the Standard Header Block.**

- [ ] **Step 2: Replace the dictionary search (cell 15)** — note `columnmeta_name` → `name`:
```python
harmonized_dataframe = session.searchDictionary("harmonized")
vars_to_remove = harmonized_dataframe.name.str.contains("age at measurement|harmonization unit")
harmonized_dataframe = harmonized_dataframe[-vars_to_remove]
harmonized_dataframe = harmonized_dataframe[harmonized_dataframe["studyId"] == "DCC Harmonized data set"]
print(harmonized_dataframe.shape)
harmonized_dataframe.head()
```

- [ ] **Step 3: Update the cells that derive `cholesterol_path` and `selected_vars`** to reference `conceptPath` (not `HPDS_PATH`).

- [ ] **Step 4: Replace the query (cell 20)** — `anyof` on cholesterol + `select` becomes `includeConcepts`:
```python
cholesterol_paths = cholesterol_path if isinstance(cholesterol_path, list) else [cholesterol_path]
anyof_group = picsure.buildClauseGroup(
    [picsure.buildClause(p, picsure.PhenotypicFilterType.ANYRECORD) for p in cholesterol_paths],
    operator=picsure.GroupOperator.OR,
)
myquery = picsure.buildQuery(phenotypicFilter=anyof_group, includeConcepts=list(selected_vars))
facts = session.runQuery(myquery, type=picsure.QueryType.PARTICIPANT)
facts.head()
```

- [ ] **Step 5: Verify downstream cells** (cell 28 `facts.filter(regex='sex')`, statsmodels analysis, Manhattan plot) still reference result columns by concept path — leave their logic unchanged; only fix column-name references if they used legacy dictionary column names.

- [ ] **Step 6: Update API-describing markdown; leave PheWAS analysis prose unchanged.**

- [ ] **Step 7: Commit**
```bash
git add NHLBI_BioData_Catalyst/python/3_PheWAS.ipynb
git commit -m "Port 3_PheWAS notebook to picsure v3 API"
```

---

## Task 5: Port `5_LongitudinalData.ipynb`

Legacy API cells: 5 (pip), 6 (imports), 8 (connect), 10 (`find('lipid|triglyceride')`), 28 (`query()`), 30 (`anyof().add(hpds_paths)`), 32 (`getResultsDataFrame`).

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/5_LongitudinalData.ipynb`

- [ ] **Step 1: Apply the Standard Header Block.**

- [ ] **Step 2: Replace the dictionary search (cell 10):**
```python
lipid_dataframe = session.searchDictionary("lipid|triglyceride")
print(lipid_dataframe.shape)
lipid_dataframe.head()
```
If the regex-style `lipid|triglyceride` returns nothing as a single search term, fall back to two searches concatenated:
```python
lipid_dataframe = pd.concat([session.searchDictionary("lipid"), session.searchDictionary("triglyceride")]).drop_duplicates(subset="conceptPath")
```
(Decide at execution time based on the live result; prefer the single-term call if it works.)

- [ ] **Step 3: Update the cell deriving `hpds_paths`** to use `conceptPath`.

- [ ] **Step 4: Replace the query (cells 28/30/32)** with the `anyof` helper over `hpds_paths`:
```python
anyof_group = picsure.buildClauseGroup(
    [picsure.buildClause(p, picsure.PhenotypicFilterType.ANYRECORD) for p in list(hpds_paths)],
    operator=picsure.GroupOperator.OR,
)
longitudinal_query = picsure.buildQuery(phenotypicFilter=anyof_group, includeConcepts=list(hpds_paths))
longitudinal_results = session.runQuery(longitudinal_query, type=picsure.QueryType.PARTICIPANT)
```

- [ ] **Step 5: Update API-describing markdown; leave longitudinal plotting cells unchanged.**

- [ ] **Step 6: Commit**
```bash
git add NHLBI_BioData_Catalyst/python/5_LongitudinalData.ipynb
git commit -m "Port 5_LongitudinalData notebook to picsure v3 API"
```

---

## Task 6: Port `6_Sickle_Cell.ipynb`

Legacy API cells: 5 (pip), 6 (imports), 10 (connect), 13 (`find('phs002385')`), 19 (`filter().add` ×3), 21 (`select().add(age_at_transplant)`), 24 (`getResultsDataFrame`). Note cell 21 uses `columnmeta_description` and `HPDS_PATH`.

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/6_Sickle_Cell.ipynb`

- [ ] **Step 1: Apply the Standard Header Block.** (Cell 6 also imports pandas/matplotlib — keep those.)

- [ ] **Step 2: Replace the dictionary search (cell 13):**
```python
scd_dataframe = session.searchDictionary("phs002385")
print(scd_dataframe.shape)
scd_dataframe.head()
```

- [ ] **Step 3: Update path-derivation cells** for `sex_var`, `necrosis_var`, `transplant_var` to read `conceptPath` (and `description`/`name` instead of `columnmeta_*`). Cell 21 becomes:
```python
age_at_transplant = scd_dataframe[scd_dataframe.description.str.contains("age at transplant, years$")][["conceptPath"]].iloc[0, 0]
```

- [ ] **Step 4: Replace the query (cells 19/21/24)** — three FILTER clauses AND-combined, age column via `includeConcepts`:
```python
sex_clause        = picsure.buildClause(sex_var, picsure.PhenotypicFilterType.FILTER, categories="Male")
necrosis_clause   = picsure.buildClause(necrosis_var, picsure.PhenotypicFilterType.FILTER, categories="Yes")
transplant_clause = picsure.buildClause(transplant_var, picsure.PhenotypicFilterType.FILTER, min=1999)

filter_tree = picsure.buildClauseGroup([sex_clause, necrosis_clause, transplant_clause], operator=picsure.GroupOperator.AND)
myquery = picsure.buildQuery(phenotypicFilter=filter_tree, includeConcepts=[age_at_transplant])
results = session.runQuery(myquery, type=picsure.QueryType.PARTICIPANT)
```

- [ ] **Step 5: Update API-describing markdown; leave plotting/analysis unchanged.**

- [ ] **Step 6: Commit**
```bash
git add NHLBI_BioData_Catalyst/python/6_Sickle_Cell.ipynb
git commit -m "Port 6_Sickle_Cell notebook to picsure v3 API"
```

---

## Task 7: Port `7_Harmonization_with_PICSURE.ipynb`

The heaviest user of `columnmeta_*` column names. Legacy API cells: 8 (pip), 9 (imports), 11 (connect), 17/41/70/72/75/80 (`find(...)` + `.dataframe()`), 25/50/84 (`anyof().add(...)`), 33 (`varInfo`), 48 (`query()`). Cell 7 also `pip install matplotlib-venn` — keep that line.

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/7_Harmonization_with_PICSURE.ipynb`

- [ ] **Step 1: Apply the Standard Header Block.** Keep cell 7's `!pip install matplotlib-venn` and `from matplotlib_venn import venn2`.

- [ ] **Step 2: Replace every `bdc.useDictionary().dictionary().find(TERM)` + `.dataframe()`** with `session.searchDictionary(TERM)`. Affected cells: 17 (`'sex|gender'`), 41 (`'body mass index|bmi'`), 70 (`'orthopnea'`), 72 (`'pillows'`), 75 (`'orthopnea|pillows'`), 80 (`'pneumonia'`).

- [ ] **Step 3: Rename all legacy dictionary columns** throughout the notebook:
  - `columnmeta_HPDS_PATH` and `HPDS_PATH` → `conceptPath`
  - `columnmeta_name` → `name`
  - `columnmeta_description` → `description`
  - `columnmeta_study_id` → `studyId`
  Cells touched include 33 (`filtered_eclipse_sex_results.columns[3]`), 70/72 (`[['columnmeta_name','columnmeta_description','values','columnmeta_study_id']]`), 75 (`studyId.str.contains(...)`), 80 (`columnmeta_study_id.str.contains(...)` + `varId`). For `varId`, check the new search columns — if absent, drop it from the display list.

- [ ] **Step 4: Replace the `anyof` queries** (cells 25, 50, 84) using the helper. Example for cell 25:
```python
eclipse_paths = list(eclipse_sex_df["conceptPath"])
eclipse_group = picsure.buildClauseGroup(
    [picsure.buildClause(p, picsure.PhenotypicFilterType.ANYRECORD) for p in eclipse_paths],
    operator=picsure.GroupOperator.OR,
)
eclipse_sex_query = picsure.buildQuery(phenotypicFilter=eclipse_group, includeConcepts=eclipse_paths)
eclipse_sex_results = session.runQuery(eclipse_sex_query, type=picsure.QueryType.PARTICIPANT)
eclipse_sex_results.head()
```
Apply the same shape to cell 50 (`[eclipse_sex_var, eclipse_bmi_var, copdgene_sex_var, copdgene_bmi_var]`) and cell 84 (`orthopnea_variable_paths_of_interest + pneumonia_variable_paths_of_interest`).

- [ ] **Step 5: Replace `sex_dictionary.varInfo(eclipse_sex_var)` (cell 33)** with a DataFrame lookup against a stored search result:
```python
sex_dataframe[sex_dataframe["conceptPath"] == eclipse_sex_var]
```

- [ ] **Step 6: Update API-describing markdown; leave harmonization narrative + venn-diagram cells unchanged.**

- [ ] **Step 7: Commit**
```bash
git add NHLBI_BioData_Catalyst/python/7_Harmonization_with_PICSURE.ipynb
git commit -m "Port 7_Harmonization_with_PICSURE notebook to picsure v3 API"
```

---

## Task 8: Port `8_RECOVER.ipynb`

Legacy API cells: 4 (pip), 5 (imports), 7 (connect), 10 (`dictionary.find("pasc")` + `columnmeta_study_id` filter), 16 (`find("head pain")` + studyId filter), 22 (`require().add([...])`), 23 (`getResultsDataFrame`).

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/8_RECOVER.ipynb`

- [ ] **Step 1: Apply the Standard Header Block.**

- [ ] **Step 2: Replace the searches.** Cell 10:
```python
pasc_vars = session.searchDictionary("pasc")
pasc_vars = pasc_vars[pasc_vars.studyId == "phs003463"]
pasc_vars.head()
```
Cell 16:
```python
headpain_vars = session.searchDictionary("head pain")
headpain_vars = headpain_vars[headpain_vars.studyId == "phs003463"]
headpain_vars.head()
```
(Note cell 10 used `columnmeta_study_id`, cell 16 used `studyId` — both become `studyId`.)

- [ ] **Step 3: Update the cells deriving `pasc_0…pasc_9` / `headpain_0…headpain_9`** to read `conceptPath`.

- [ ] **Step 4: Replace the query (cells 22/23)** — REQUIRE over all 8 paths:
```python
require_paths = [pasc_0, pasc_3, pasc_6, pasc_9, headpain_0, headpain_3, headpain_6, headpain_9]
require_clause = picsure.buildClause(require_paths, picsure.PhenotypicFilterType.REQUIRE)
pasc_headpain_query = picsure.buildQuery(phenotypicFilter=require_clause, includeConcepts=require_paths)
results = session.runQuery(pasc_headpain_query, type=picsure.QueryType.PARTICIPANT)
```

- [ ] **Step 5: Update API-describing markdown; leave RECOVER analysis unchanged.**

- [ ] **Step 6: Commit**
```bash
git add NHLBI_BioData_Catalyst/python/8_RECOVER.ipynb
git commit -m "Port 8_RECOVER notebook to picsure v3 API"
```

---

## Task 9: Port `ORCHID_COVID19_python.ipynb`

Legacy API cells: 11 (pip), 12 (imports), 14 (connect), 16 (`find('ORCHID')` + `anyof().add(HPDS_PATH)` + `getResultsDataFrame`).

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/ORCHID_COVID19_python.ipynb`

- [ ] **Step 1: Apply the Standard Header Block.**

- [ ] **Step 2: Replace the search + query (cell 16):**
```python
orchid_dataframe = session.searchDictionary("ORCHID")
orchid_paths = list(orchid_dataframe["conceptPath"])
anyof_group = picsure.buildClauseGroup(
    [picsure.buildClause(p, picsure.PhenotypicFilterType.ANYRECORD) for p in orchid_paths],
    operator=picsure.GroupOperator.OR,
)
orchid_query = picsure.buildQuery(phenotypicFilter=anyof_group, includeConcepts=orchid_paths)
raw_df = session.runQuery(orchid_query, type=picsure.QueryType.PARTICIPANT)
```

- [ ] **Step 3: Leave the large recoding/analysis cell (25) unchanged** — it operates purely on the result DataFrame.

- [ ] **Step 4: Update API-describing markdown; leave ORCHID analysis prose unchanged.**

- [ ] **Step 5: Commit**
```bash
git add NHLBI_BioData_Catalyst/python/ORCHID_COVID19_python.ipynb
git commit -m "Port ORCHID_COVID19_python notebook to picsure v3 API"
```

---

## Task 10: Port `0_Export_from_UI.ipynb`

This notebook loads a query built in the PIC-SURE UI by its query ID and shows
how to edit it. Legacy API cells: 6 (pip), 7 (imports), 9 (connect), 12
(`resource.retrieveQueryResults(queryID)`), 18–21 (`query.select()/require()/anyof()/filter().show()`), 23 (`filter().delete()` + `filter().add()`).

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/0_Export_from_UI.ipynb`

- [ ] **Step 1: Apply the Standard Header Block.** Keep cell 5's pandas/matplotlib/sys imports.

- [ ] **Step 2: Replace the retrieve-by-ID cell (12)** with `runQueryByID`:
```python
# `queryID` is copied from the PIC-SURE UI ("Copy Query ID").
df_UI = session.runQueryByID(queryID, type=picsure.QueryType.PARTICIPANT)
df_UI.head()
```
Remove the legacy `useResource(...)` / `retrieveQueryResults` / `StringIO`/`read_csv`
plumbing — `runQueryByID` returns a DataFrame directly.

- [ ] **Step 3: Replace the query-introspection demo cells (18–21).** The new API
has no live query object to introspect (`.select()/.require()/.anyof()/.filter().show()`).
Replace these four cells with a single markdown cell explaining that in the v3
adapter you compose a query in Python from `buildClause` / `buildClauseGroup` /
`buildQuery`, and inspect it by examining those Python objects (e.g.
`my_clause_group.clauses`) rather than calling `.show()` on the query.

- [ ] **Step 4: Replace the edit-a-filter demo cell (23)** with the v3 equivalent —
to change a categorical filter you rebuild the clause:
```python
# EXAMPLE CODE — adjust to your own query and research purposes.
# To change a "Gender of participant" filter from "Male" to both "Male" and
# "Female", rebuild the clause with the new categories and reassemble the query:
sex_path = "\\phs000820\\pht004332\\phv00219057\\sex\\"
sex_clause = picsure.buildClause(
    sex_path, picsure.PhenotypicFilterType.FILTER, categories=["Male", "Female"]
)
# then include sex_clause when you call picsure.buildClauseGroup([...]) / buildQuery(...)
```

- [ ] **Step 5: Update markdown** describing the export-from-UI workflow to match
`runQueryByID` and the Python-composition editing model. Note in prose that the
notebook needs a real `queryID` from the UI to execute.

- [ ] **Step 6: Commit**
```bash
git add NHLBI_BioData_Catalyst/python/0_Export_from_UI.ipynb
git commit -m "Port 0_Export_from_UI notebook to picsure v3 API"
```

---

## Task 11: Update `Workspace_setup.ipynb`

This notebook only writes `token.txt` (cells: `my_token = "enter_your_token"`,
then writes the file). It has no PIC-SURE API calls.

**Files:**
- Modify: `NHLBI_BioData_Catalyst/python/Workspace_setup.ipynb`

- [ ] **Step 1: Read the notebook** and confirm it contains no `PicSureClient`/`PicSureBdcAdapter` references (only the token-writing cells).

Run:
```bash
grep -c "PicSure" NHLBI_BioData_Catalyst/python/Workspace_setup.ipynb || echo 0
```
Expected: `0`.

- [ ] **Step 2: If any install/setup markdown references the legacy three-package
install, update it** to the single `pic-sure-python-adapter-hpds.git@main`
install from the Standard Header Block. If there is nothing to change, leave the
notebook as-is and skip the commit.

- [ ] **Step 3: Commit (only if changed)**
```bash
git add NHLBI_BioData_Catalyst/python/Workspace_setup.ipynb
git commit -m "Update Workspace_setup notebook install instructions for picsure v3"
```

---

## Task 12: Live verification pass against BDC

Run all rewritten notebooks end-to-end and fix failures. Per the spec, this is
the single batch verification step.

**Files:**
- Modify: any notebook that fails (re-commit per the relevant task's pattern).

- [ ] **Step 1: Register the scratch venv as a Jupyter kernel**
```bash
/tmp/picsure-nb-venv/bin/python -m ipykernel install --user --name picsure-nb --display-name "picsure-nb"
```

- [ ] **Step 2: Execute each in-scope notebook** from inside the notebooks
directory (so `token.txt` resolves), skipping the install cell's network call by
allowing errors only on that cell is not possible — instead pre-install is done
(Task 1), and the in-notebook `!pip install …@main` line will re-install the same
version (harmless). Run:
```bash
cd /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API/NHLBI_BioData_Catalyst/python
for nb in 0_Export_from_UI 1_PICSURE_API_101 2_TOPMed_DCC_Harmonized_Variables_analysis 3_PheWAS 5_LongitudinalData 6_Sickle_Cell 7_Harmonization_with_PICSURE 8_RECOVER ORCHID_COVID19_python; do
  echo "=== $nb ==="
  /tmp/picsure-nb-venv/bin/jupyter nbconvert --to notebook --execute --ExecutePreprocessor.timeout=1200 \
    --ExecutePreprocessor.kernel_name=picsure-nb --output "/tmp/${nb}_executed.ipynb" "${nb}.ipynb" \
    && echo "PASS $nb" || echo "FAIL $nb"
done
```
Expected: each prints `PASS`. Capture the error for any `FAIL`.

- [ ] **Step 3: Triage each failure.**
  - `0_Export_from_UI` will fail unless a real `queryID` is defined — this is
    expected (it needs a UI query ID). Flag it as "requires user queryID," not a
    code failure, unless the failure is an API/translation error.
  - Any error mentioning data access / 401 / empty results on a study the token
    can't reach → flag as access-limited, not a translation failure.
  - Any `AttributeError` / `TypeError` / wrong-kwarg / wrong-column error → a
    real port bug; fix in the source notebook per its task's patterns and re-run
    just that notebook.

- [ ] **Step 4: Re-run until each notebook either PASSes or is flagged** as
access/queryID-limited with a clear reason.

- [ ] **Step 5: Final sweep — confirm no legacy API remains**
```bash
cd /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API
grep -lE "PicSureClient|PicSureBdcAdapter|useAuthPicSure|getResultsDataFrame|\.anyof\(|\.require\(\)|\.select\(\)|\.filter\(\)\.add" \
  NHLBI_BioData_Catalyst/python/[0-9]*.ipynb NHLBI_BioData_Catalyst/python/ORCHID*.ipynb \
  | grep -v 4_Genomic_Queries || echo "no legacy API references remain"
```
Expected: `no legacy API references remain` (4_Genomic excluded — out of scope).

- [ ] **Step 6: Commit any verification fixes** (per-notebook commits as needed),
then write a short pass/fail summary to the PR/branch description or as a final
report.

---

## Notes / risks

- **`anyof` semantics**: the OR-of-ANYRECORD modeling must be sanity-checked
  against expected counts where the original notebook stated them. If a count is
  wildly off, reconsider whether the legacy `anyof` actually meant "any record
  in any of these" (OR) vs. a different grouping.
- **`searchDictionary` regex terms** (e.g. `"lipid|triglyceride"`,
  `"sex|gender"`): confirm the new dictionary search treats these as intended; if
  not, split into multiple searches and concat (see Task 5 Step 2).
- **`varId` / other legacy columns**: if a notebook displays a dictionary column
  that no longer exists in the v3 search output, drop it from the display list.
- **`0_Export_from_UI`** genuinely needs a user-supplied `queryID` to execute;
  it cannot be fully verified without one.
