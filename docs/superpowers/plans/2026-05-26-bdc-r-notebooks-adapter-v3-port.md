# BDC R Notebooks → `picsure` R Adapter (v3) Port — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the in-scope R notebooks in `NHLBI_BioData_Catalyst/R/` to use the rewritten `picsure` **R** adapter API (the reticulate wrapper over the v3 Python adapter), then verify each executes against live BDC.

**Architecture:** Same shape as the completed Python port (`docs/superpowers/plans/2026-05-26-bdc-python-notebooks-adapter-v3-port.md`). Each notebook is edited in place: legacy `picsure::bdc.*` + `addClause` + `runQuery(resultType=)` calls are replaced with the v3 `picsure::connect` / `searchDictionary` / `buildClause` / `buildClauseGroup` / `buildQuery` / `runQuery` API; legacy dictionary column names are renamed; API-describing markdown is updated. Verification is a single live pass after all rewrites.

**Tech Stack:** R Jupyter notebooks (IRkernel), `picsure` R package installed from `devtools::install_github("hms-dbmi/pic-sure-r-adapter-hpds", ref="main")` (which provisions the Python adapter via reticulate), `dplyr`/`stringr`/`ggplot2` etc. Work happens directly on the `adapters_v3` branch.

**Prior art / required reading:**
- Python port plan + spec: `docs/superpowers/plans/2026-05-26-bdc-python-notebooks-adapter-v3-port.md`, `docs/superpowers/specs/2026-05-26-bdc-python-notebooks-adapter-v3-port-design.md`
- **Python live-verification handoff: `docs/superpowers/2026-05-26-python-notebook-verification-handoff.md`** — the R notebooks run the same analyses against the same backend, so they will hit the SAME live-data issues. Pre-apply those fixes (see "Known live-data carryovers" below).
- Canonical v3 R idioms: `pic-sure-r-adapter-hpds/notebooks/` (`0_Connect`, `1_Search`, `2_Query`, `4_Complex_Open_Queries`, …) — the source of truth for R API style.

---

## Scope

Rewrite these R notebooks onto the v3 R API:

- `0_Export_from_UI.ipynb`
- `1_PICSURE_API_101.ipynb`
- `2_TOPMed_DCC_Harmonized_Variables_analysis.ipynb`
- `3_PheWAS.ipynb`
- `5_LongitudinalData.ipynb`
- `6_Sickle_Cell.ipynb`
- `7_Harmonization_with_PICSURE.ipynb`
- `8_RECOVER.ipynb`
- `ORCHID_COVID19.ipynb`

`Workspace_setup.ipynb` gets only its setup cells reviewed (it just writes `token.txt`; likely no change).

### Out of scope
- `4_Genomic_Queries.ipynb` — the v3 adapter exposes only phenotypic filters (`FILTER`/`ANYRECORD`/`REQUIRE`); no genomic/variant filter. Leave untouched.

## Standard Header Block (every notebook)

Legacy install/connect:
```r
devtools::install_github("hms-dbmi/pic-sure-r-adapter-hpds", ref="main", force=T, quiet=FALSE)
# ...
PICSURE_network_URL = "https://picsure.biodatacatalyst.nhlbi.nih.gov/picsure"
token <- scan("token.txt", what = "character")
session <- picsure::bdc.initializeSession(PICSURE_network_URL, token)
session <- picsure::bdc.setResource(session = session, resourceName = "AUTH")
```
becomes:
```r
# install cell (keep the devtools::install_github line as-is; it already targets ref="main")
Sys.setenv(TAR = "/bin/tar")
options(unzip = "internal")
devtools::install_github("hms-dbmi/pic-sure-r-adapter-hpds", ref="main", force=T, quiet=FALSE)
library(dplyr)   # plus the notebook's other libraries (stringr/ggplot2/...)
```
```r
library(picsure)
token_file <- "token.txt"
my_token <- readLines(token_file, warn = FALSE)[1]
session <- picsure::connect(
  platform = picsure::Platform$BDC_AUTHORIZED,
  token    = my_token
)
```
Notes:
- Use `readLines(...)[1]` (matches the v3 reference notebooks) rather than `scan(...)`.
- The hard-coded `/picsure` URL and the `bdc.setResource(..., "AUTH")` step are gone — `Platform$BDC_AUTHORIZED` carries the URL and resource.
- Enums are R lists accessed with `$`: `picsure::PhenotypicFilterType$FILTER`, `picsure::GroupOperator$OR`, `picsure::QueryType$PARTICIPANT`, `picsure::Platform$BDC_AUTHORIZED`.

## API translation map

| Legacy R | v3 R |
|---|---|
| `bdc.initializeSession(URL, token)` + `bdc.setResource(session, "AUTH")` | `session <- picsure::connect(platform = picsure::Platform$BDC_AUTHORIZED, token = my_token)` |
| `picsure::bdc.searchPicsure(session, kw, includeValues=TRUE)` | `picsure::searchDictionary(session, kw, include_values = TRUE)` → data.frame |
| `picsure::bdc.getStudies(session)` | no direct equivalent — derive from a search (`unique(df$studyId)`) or use facets; for a pure "list studies" cell, replace with a short note + `unique(picsure::searchDictionary(session, "")$studyId)` (may be large) or drop |
| `picsure::bdc.newQuery(session)` | (removed — build clauses directly) |
| `addClause(query, keys, type="FILTER", categories=list("X"))` | `picsure::buildClause(keys, type = picsure::PhenotypicFilterType$FILTER, categories = c("X"))` |
| `addClause(query, keys, type="FILTER", min=, max=)` | `picsure::buildClause(keys, type = picsure::PhenotypicFilterType$FILTER, min = , max = )` |
| `addClause(query, keys, type="REQUIRE")` | `picsure::buildClause(keys, type = picsure::PhenotypicFilterType$REQUIRE)` |
| `addClause(query, keys, type="ANYOF")` | OR group of per-key `ANYRECORD` clauses (see helper) |
| `addClause(query, keys, type="SELECT")` | put those keys in `picsure::buildQuery(includeConcepts = ...)` — **no SELECT clause type in v3** |
| combine clauses | `picsure::buildClauseGroup(list(c1, c2, ...), operator = picsure::GroupOperator$AND)` |
| assemble + run | `q <- picsure::buildQuery(phenotypicFilter = tree, includeConcepts = c(paths)); picsure::runQuery(session, q, type = picsure::QueryType$PARTICIPANT)` |
| `runQuery(query, resultType='DATA_FRAME')` / `runQuery(query)` | `picsure::runQuery(session, q, type = picsure::QueryType$PARTICIPANT)` |
| `bdc.getQueryByUUID(session, id)` | `picsure::loadQueryByID(session, id)`; to run by id: `picsure::runQueryByID(session, id, type = picsure::QueryType$PARTICIPANT)` |
| `query$requiredFields` / `query$categoryFilters` (introspection) | no live query object — inspect the R objects from `buildClause`/`buildClauseGroup`/`buildQuery`; replace `.show`-style cells with a markdown note |

### Column renames (legacy R search df → v3 R search df)
| Legacy R column | v3 R column |
|---|---|
| `name` (concept path) | `conceptPath` |
| `var_name` (short name) | `name` |
| `var_description` | `description` |
| `study_id` | `studyId` |
| `data_type` | `dataType` |
| `group_id` (var group) | no column — use the `conceptPath` category segment (e.g. `grepl("\\\\demographic\\\\", conceptPath)`) |
| `var_id` (phv accession) | no column — the phv id is a segment of `conceptPath` (`grepl("phv00021300|...", conceptPath)`) |
| `values` | `values` (list-column, unchanged) |

### `ANYOF` helper (R)
Legacy `addClause(q, keys = <vector>, type = "ANYOF")` means "participant has a record in ANY listed concept." Translate to an OR group of ANYRECORD clauses:
```r
anyof_clauses <- lapply(keys, function(p) picsure::buildClause(p, type = picsure::PhenotypicFilterType$ANYRECORD))
anyof_group   <- picsure::buildClauseGroup(anyof_clauses, operator = picsure::GroupOperator$OR)
q <- picsure::buildQuery(phenotypicFilter = anyof_group, includeConcepts = keys)
res <- picsure::runQuery(session, q, type = picsure::QueryType$PARTICIPANT)
```
`includeConcepts = keys` reproduces the legacy behavior where queried variables are also output columns.

## Known live-data carryovers (pre-apply; same backend as the Python port)

These were discovered during the Python live verification and WILL recur in R. Apply the equivalent fix while porting (still confirm at verification):

- **Participant results have only `patient_id` + concept columns** (NOT 4 leading metadata columns). Any positional `colnames(results) <- c(...)` or column-position logic is off by 3. Rebuild renames by matching concept path → label (order-independent), e.g.:
  ```r
  results <- results %>% rename(eclipse_sex = !!eclipse_sex_var, eclipse_bmi = !!eclipse_bmi_var, ...)
  ```
  (`8_RECOVER` cell ~26 and `7_Harmonization` rename cells both assume `Patient_ID, Parent, Topmed, consents, ...`.)
- **`2_TOPMed` demographic group** (`grepl('demographic', group_id)`): `group_id` has no v3 column → `grepl("\\\\demographic\\\\", conceptPath)`.
- **`7_Harmonization` pneumonia** (`grepl('phv...', var_id)`): `var_id` has no v3 column → `grepl("phv00021300|phv00087211|phv00283208", conceptPath)`.
- **`5_LongitudinalData`**: current FHS lipid data has the variable described as "Taking lipid lowering medication for any reason" (not "Treated for lipids,"), and only ~2 exams. Update the `grepl('Treated for lipids,', var_description)` filter and expect thin longitudinal data; the `>= 20 recorded values` filter (cell ~39) may need lowering or will yield few rows.
- **`7_Harmonization` COPDGene sex** (`copdgene_sex_df$var_name == 'gender'`) may return empty against current data (Python hit the same) — verify the COPDGene sex variable's `name` value live and adjust the filter.
- **`ORCHID`** expects a `rand_trt` column among results — confirm it's returned by `searchDictionary("ORCHID")` (Python failed here); if absent, the downstream `tableby(rand_trt ~ ...)` analysis can't run.
- **`3_PheWAS`**: the `categorical_cholesterol` case/control split and FHS male/female subsets must be non-empty or the stats blow up (Python hit `ZeroDivisionError`); verify the cohort has both classes.

## File structure
Edit in place, one notebook per task:
- `NHLBI_BioData_Catalyst/R/<name>.ipynb`

---

## Task 1: R verification environment

**Files:** scratch R library + IRkernel (not committed).

- [ ] **Step 1: Confirm R + install the adapter and IRkernel**

Run:
```bash
Rscript -e 'install.packages(c("devtools","IRkernel","dplyr","stringr","ggplot2","ggrepel"), repos="https://cloud.r-project.org")'
Rscript -e 'devtools::install_github("hms-dbmi/pic-sure-r-adapter-hpds", ref="main", force=TRUE)'
Rscript -e 'IRkernel::installspec(name="picsure-r", displayname="picsure-r")'
```
Expected: `picsure` R package installs; IRkernel `picsure-r` registered. (The R adapter provisions the Python adapter via reticulate on first use — `.PICSURE_PY_SPEC` in `R/zzz.R` pins `picsure @ ...@main`.)

- [ ] **Step 2: Smoke-test connect + search**

Run:
```bash
cd NHLBI_BioData_Catalyst/R   # token.txt present here
Rscript -e 'library(picsure); tok<-readLines("token.txt",warn=FALSE)[1]; s<-picsure::connect(platform=picsure::Platform$BDC_AUTHORIZED, token=tok); df<-picsure::searchDictionary(s,"tutorial"); cat("rows:",nrow(df),"cols:",paste(head(colnames(df)),collapse=","),"\n")'
```
Expected: connects, prints rows + the v3 columns (`conceptPath,name,display,description,dataType,studyId`). If 401, refresh `token.txt`.

No commit.

---

## Task 2: Port `1_PICSURE_API_101.ipynb`

**Files:** Modify `NHLBI_BioData_Catalyst/R/1_PICSURE_API_101.ipynb`

Legacy calls: `bdc.initializeSession`+`bdc.setResource`; `bdc.getStudies(session)`; `bdc.searchPicsure(session, keyword=search_term, includeValues=TRUE)`; `bdc.newQuery`; `addClause(... type="FILTER", categories=list("Current smoker"))`; `addClause(... type="FILTER", min=20)`; `addClause(keys=c(age,hyperten), type="REQUIRE")`; `runQuery(query_example, resultType='DATA_FRAME')`. Study scoping via `my_variables_df$study_id == "tutorial-biolincc_framingham"`.

- [ ] **Step 1: Apply the Standard Header Block** (install/library + connect). Keep `dplyr`, `stringr`.
- [ ] **Step 2: `bdc.getStudies(session)`** → replace with `unique(picsure::searchDictionary(session, "")$studyId)` (or a markdown note + a small example), since v3 has no `getStudies`.
- [ ] **Step 3: Search** → `my_variables_df <- picsure::searchDictionary(session, search_term, include_values = TRUE)`.
- [ ] **Step 4: Column renames** in the study-scoping + path-lookup cells: `study_id`→`studyId`, `var_name`→`name`, `name`(path)→`conceptPath`, `var_description`→`description`. So `tutorial_df <- my_variables_df[my_variables_df$studyId == "tutorial-biolincc_framingham", ]`; concept-path lookups pull `conceptPath`.
- [ ] **Step 5: Query** → replace the `bdc.newQuery` + three `addClause` cells + `runQuery` with:
```r
smoke_clause   <- picsure::buildClause(smoke_variable_path, type = picsure::PhenotypicFilterType$FILTER, categories = c("Current smoker"))
bmi_clause     <- picsure::buildClause(bmi_variable_path,   type = picsure::PhenotypicFilterType$FILTER, min = 20)
require_clause <- picsure::buildClause(c(age_variable_path, hyperten_variable_path), type = picsure::PhenotypicFilterType$REQUIRE)
filter_tree    <- picsure::buildClauseGroup(list(smoke_clause, bmi_clause, require_clause), operator = picsure::GroupOperator$AND)
example_query  <- picsure::buildQuery(phenotypicFilter = filter_tree, includeConcepts = c(age_variable_path, bmi_variable_path, smoke_variable_path, hyperten_variable_path))
example_results <- picsure::runQuery(session, example_query, type = picsure::QueryType$PARTICIPANT)
head(example_results)
```
- [ ] **Step 6:** Leave the downstream `dplyr` select/rename/summary cells unchanged (they index result columns by concept path).
- [ ] **Step 7:** Update API-describing markdown (`bdc.searchPicsure`, `addClause`, `runQuery` prose) to the v3 model. Leave the Framingham narrative.
- [ ] **Step 8: Verify** (valid JSON; no `bdc.`/`addClause`/`newQuery`/`resultType`/`study_id`/`var_name` in code) and **commit**:
```bash
git add NHLBI_BioData_Catalyst/R/1_PICSURE_API_101.ipynb
git commit -m "Port R 1_PICSURE_API_101 to picsure v3 API"
```

---

## Task 3: Port `2_TOPMed_DCC_Harmonized_Variables_analysis.ipynb`

**Files:** Modify `NHLBI_BioData_Catalyst/R/2_TOPMed_DCC_Harmonized_Variables_analysis.ipynb`

Legacy: `bdc.searchPicsure(session,'harmonized') %>% filter(study_id=='DCC Harmonized data set')`; var filter `grepl("age at measurement|harmonization unit", var_name)`; demographic via `grepl('demographic', group_id)`; `vars_of_interest <- demographic_df$name`; `bdc.newQuery` + `addClause(type='ANYOF')`; `runQuery(demographic_query)`.

- [ ] **Step 1:** Standard Header Block.
- [ ] **Step 2: Search + filters** with renames:
```r
harmonized_df <- picsure::searchDictionary(session, "harmonized") %>% filter(studyId == "DCC Harmonized data set")
harmonized_df <- harmonized_df[!grepl("age at measurement|harmonization unit", harmonized_df$name), ]   # legacy var_name -> name
```
- [ ] **Step 3: Demographic subset via conceptPath** (legacy `group_id` has no v3 column):
```r
demographic_df <- harmonized_df[grepl("\\\\demographic\\\\", harmonized_df$conceptPath), ]
vars_of_interest <- demographic_df$conceptPath
```
- [ ] **Step 4: ANYOF query** via the helper (`keys = vars_of_interest`), result var `demographic_results`, `runQuery(session, ..., type = QueryType$PARTICIPANT)`.
- [ ] **Step 5:** Downstream `select("\\DCC Harmonized data set\\demographic\\annotated_sex_1\\", ...)` cells operate on result concept-path columns — leave unchanged.
- [ ] **Step 6:** Markdown updates; **commit** `Port R 2_TOPMed_DCC_Harmonized_Variables_analysis to picsure v3 API`.

---

## Task 4: Port `3_PheWAS.ipynb`

**Files:** Modify `NHLBI_BioData_Catalyst/R/3_PheWAS.ipynb`

Legacy: harmonized search + `grepl("age at measurement|harmonization unit", var_name)`; `cholesterol_path <- cholesterol_variables %>% pull(name)`; `selected_vars <- ... %>% pull(name)`; two `addClause(type='ANYOF')` (cholesterol, then selected_vars); `runQuery(myquery)`; large PheWAS functions; `subgroup_var <- '\\DCC Harmonized data set\\demographic\\subcohort_1\\'`.

- [ ] **Step 1:** Standard Header Block (keep `dplyr`,`stringr`,`ggplot2`,`ggrepel`).
- [ ] **Step 2:** Search + filter with renames (`study_id`→`studyId`, `var_name`→`name` in the grepl, `name`→`conceptPath` in `pull`):
```r
harmonized_df <- picsure::searchDictionary(session, "harmonized") %>% filter(studyId == "DCC Harmonized data set")
harmonized_df <- harmonized_df[!grepl("age at measurement|harmonization unit", harmonized_df$name), ]
```
- [ ] **Step 3: Cholesterol selection** — pick the real total cholesterol measurement (exclude unit/age-at), via `conceptPath` (Python carryover):
```r
cholesterol_variables <- harmonized_df %>% filter(grepl("total_cholesterol", conceptPath) & !grepl("unit_|age_at_", conceptPath))
cholesterol_path <- cholesterol_variables %>% pull(conceptPath)
selected_vars <- harmonized_df %>% filter(conceptPath != cholesterol_path) %>% pull(conceptPath)
```
- [ ] **Step 4: Query** — the legacy did ANYOF on cholesterol AND ANYOF on selected_vars (two clauses). Combine into one OR group of ANYRECORD over `c(cholesterol_path, selected_vars)`, and `includeConcepts = c(cholesterol_path, selected_vars)`:
```r
all_paths <- c(cholesterol_path, selected_vars)
anyof_clauses <- lapply(all_paths, function(p) picsure::buildClause(p, type = picsure::PhenotypicFilterType$ANYRECORD))
anyof_group <- picsure::buildClauseGroup(anyof_clauses, operator = picsure::GroupOperator$OR)
myquery <- picsure::buildQuery(phenotypicFilter = anyof_group, includeConcepts = all_paths)
facts <- picsure::runQuery(session, myquery, type = picsure::QueryType$PARTICIPANT)
```
- [ ] **Step 5: data_type → dataType** in `categorical_df`/`continuous_df` filters; `pull(name)` → `pull(conceptPath)` for `categorical_varnames`/`continuous_varnames`.
- [ ] **Step 6:** Leave the PheWAS functions, FHS subset, glm/fisher tests, and ggplot Manhattan cells unchanged (they reference result concept-path columns and `subgroup_var`/`sex_path`). NOTE the Python carryover: verify the FHS cohort and `categorical_cholesterol` case/control split are non-empty at verification.
- [ ] **Step 7:** Markdown updates; **commit** `Port R 3_PheWAS to picsure v3 API`.

---

## Task 5: Port `5_LongitudinalData.ipynb`

**Files:** Modify `NHLBI_BioData_Catalyst/R/5_LongitudinalData.ipynb`

Legacy: `bdc.searchPicsure(session,'lipid|triglyceride')`; `filter(grepl('phs000007', study_id))`; exam/visit parsing on `var_description`; `names <- lipid_df %>% filter(grepl('Treated for lipids,', var_description)) %>% pull(name)`; `bdc.newQuery` + `addClause(keys=names, type='ANYOF')`; `runQuery`.

- [ ] **Step 1:** Standard Header Block (keep `dplyr`,`stringr`).
- [ ] **Step 2: Search** → `lipid_df <- picsure::searchDictionary(session, "lipid|triglyceride")`. (If the regex term returns too few, note the split-search fallback in a comment.)
- [ ] **Step 3: Column renames** through the filtering chain: `study_id`→`studyId`, `var_description`→`description`, `var_name`→`name`. So `filter(grepl('phs000007', studyId))`, exam parsing on `description`, etc.
- [ ] **Step 4: Variable selection (Python carryover — stale string + thin data):** legacy `grepl('Treated for lipids,', var_description)` matches nothing in current data. Use:
```r
names <- lipid_df %>% filter(grepl('Taking lipid lowering medication for any reason', description)) %>% pull(conceptPath)
```
- [ ] **Step 5: ANYOF query** via helper (`keys = names`), result `longitudinal_results`, `runQuery(session, ..., type = QueryType$PARTICIPANT)`.
- [ ] **Step 6:** Downstream pivot/plot cells operate on results. NOTE: current data is thin (≈2 exams); the `filter(recorded_values >= 20)` cell (~39) may yield empty — verify and lower the threshold if the plot needs data. Leave logic otherwise unchanged.
- [ ] **Step 7:** Markdown updates; **commit** `Port R 5_LongitudinalData to picsure v3 API`.

---

## Task 6: Port `6_Sickle_Cell.ipynb`

**Files:** Modify `NHLBI_BioData_Catalyst/R/6_Sickle_Cell.ipynb`

Legacy: `bdc.searchPicsure(session,'phs002385')`; vars via `grepl('Sex|Avascular necrosis|Year of transplant$', var_description)`, `... ,'name']`; `bdc.newQuery` + three `bdc.addClause(type='FILTER', categories=list('Male')/'Yes'/min=1999)`; `addClause(age_transplant_var, type='SELECT')`; `runQuery(myquery)`.

- [ ] **Step 1:** Standard Header Block.
- [ ] **Step 2: Search** → `df <- picsure::searchDictionary(session, "phs002385")`.
- [ ] **Step 3: Var derivations** with renames (`var_description`→`description`, `'name'`→`'conceptPath'`):
```r
sex_var               <- df[grepl("Sex", df$description), "conceptPath"]
avascular_necrosis_var<- df[grepl("Avascular necrosis", df$description), "conceptPath"]
transplant_yr_var     <- df[grepl("Year of transplant$", df$description), "conceptPath"]
age_transplant_var    <- df[grepl("age at transplant, years$", df$description), "conceptPath"]
```
- [ ] **Step 4: Query** — three FILTER clauses AND-combined; SELECT → includeConcepts:
```r
sex_clause       <- picsure::buildClause(sex_var, type = picsure::PhenotypicFilterType$FILTER, categories = c("Male"))
necrosis_clause  <- picsure::buildClause(avascular_necrosis_var, type = picsure::PhenotypicFilterType$FILTER, categories = c("Yes"))
transplant_clause<- picsure::buildClause(transplant_yr_var, type = picsure::PhenotypicFilterType$FILTER, min = 1999)
filter_tree <- picsure::buildClauseGroup(list(sex_clause, necrosis_clause, transplant_clause), operator = picsure::GroupOperator$AND)
myquery <- picsure::buildQuery(phenotypicFilter = filter_tree, includeConcepts = c(age_transplant_var))
results <- picsure::runQuery(session, myquery, type = picsure::QueryType$PARTICIPANT)
```
  (If a derivation returns multiple rows, take `[1]` as the legacy did. Include in `includeConcepts` whatever result columns the downstream plot reads.)
- [ ] **Step 5:** Downstream plot cells unchanged.
- [ ] **Step 6:** Markdown updates; **commit** `Port R 6_Sickle_Cell to picsure v3 API`.

---

## Task 7: Port `7_Harmonization_with_PICSURE.ipynb`

**Files:** Modify `NHLBI_BioData_Catalyst/R/7_Harmonization_with_PICSURE.ipynb`

Legacy: searches `sex|gender`, `body mass index|bmi`, `orthopnea`, `pillows`, `orthopnea|pillows`, `pneumonia`; ECLIPSE/COPDGene subsets via `grepl('phs001252'|'phs000179', study_id)`; `copdgene_sex_var <- copdgene_sex_df[copdgene_sex_df$var_name=='gender','name']`; pneumonia via `grepl('phv...', var_id)`; multiple `addClause(type='ANYOF')`; result column renames; venn diagrams.

- [ ] **Step 1:** Standard Header Block (keep the venn/ggplot libs).
- [ ] **Step 2:** Replace every `bdc.searchPicsure(session, TERM)` with `picsure::searchDictionary(session, TERM)` for all 6 terms.
- [ ] **Step 3: Column renames everywhere:** `study_id`→`studyId`, `var_name`→`name`, `var_description`→`description`, `name`(path)→`conceptPath`. So ECLIPSE/COPDGene subsets `filter(grepl('phs001252', studyId))`, `select(name, description, values, conceptPath)`, and `copdgene_sex_var <- copdgene_sex_df[copdgene_sex_df$name == "gender", "conceptPath"]`.
- [ ] **Step 4: pneumonia via conceptPath** (Python carryover; `var_id` has no v3 column):
```r
pneumonia_variables_of_interest <- harmonized_df %>% filter(grepl("phv00021300|phv00087211|phv00283208", conceptPath))
pneumonia_variable_paths_of_interest <- pneumonia_variables_of_interest$conceptPath
```
- [ ] **Step 5: ANYOF queries** (eclipse sex; combined sex+bmi; orthopnea+pneumonia) via the helper, `keys` = the relevant `conceptPath` vectors, `includeConcepts` = same; `runQuery(session, ..., type = QueryType$PARTICIPANT)`. Preserve result var names.
- [ ] **Step 6: Result renames (Python carryover — only patient_id + concepts returned):** replace any positional `colnames(...) <- c(...)`/`select(complete_df...rownames)` logic with order-independent renames keyed on concept path, and derive study labels from the phs id in the path (`fhs`=phs000007, `whi`=phs000200, `mesa`=phs000209). NOTE: COPDGene sex filter (`name == "gender"`) may return empty against current data — verify the COPDGene sex variable's `name` value live.
- [ ] **Step 7:** Markdown updates; **commit** `Port R 7_Harmonization_with_PICSURE to picsure v3 API`.

---

## Task 8: Port `8_RECOVER.ipynb`

**Files:** Modify `NHLBI_BioData_Catalyst/R/8_RECOVER.ipynb`

Legacy: `bdc.searchPicsure(session, keyword="pasc", includeValues=TRUE)`; `filter(grepl("pasc_jama2024", var_name))`; head-pain search + `filter(study_id == "phs003463")`; `pasc_0..9`/`headpain_0..9` derivations; `addClause(keys=c(...), type="REQUIRE")`; `runQuery(query, resultType="DATA_FRAME")`; positional `colnames(results) <- c("Patient_ID","Parent","Topmed","consents", ...)`.

- [ ] **Step 1:** Standard Header Block.
- [ ] **Step 2: Searches** → `searchDictionary(session, "pasc", include_values = TRUE)` and `searchDictionary(session, "head pain", include_values = TRUE) %>% filter(studyId == "phs003463")`.
- [ ] **Step 3:** `filter(grepl("pasc_jama2024", var_name))` → `filter(grepl("pasc_jama2024", name))` (legacy `var_name` → v3 `name`; `pasc_jama2024_infected_N` lives in `name`). Update `pasc_0..9`/`headpain_0..9` derivations to pull `conceptPath`.
- [ ] **Step 4: REQUIRE query:**
```r
require_paths <- c(pasc_0, pasc_3, pasc_6, pasc_9, headpain_0, headpain_3, headpain_6, headpain_9)
require_clause <- picsure::buildClause(require_paths, type = picsure::PhenotypicFilterType$REQUIRE)
pasc_headpain_query <- picsure::buildQuery(phenotypicFilter = require_clause, includeConcepts = require_paths)
results <- picsure::runQuery(session, pasc_headpain_query, type = picsure::QueryType$PARTICIPANT)
```
- [ ] **Step 5: Result rename (Python carryover):** the positional `colnames(results) <- c("Patient_ID","Parent","Topmed","consents", headpain_0..9, pasc_0..9)` assumes 4 metadata columns; v3 returns only `patient_id` + the 8 concept columns. Rename order-independently by concept path:
```r
results <- results %>% rename(
  headpain_0 = !!headpain_0, headpain_3 = !!headpain_3, headpain_6 = !!headpain_6, headpain_9 = !!headpain_9,
  pasc_0 = !!pasc_0, pasc_3 = !!pasc_3, pasc_6 = !!pasc_6, pasc_9 = !!pasc_9
)
```
- [ ] **Step 6:** Downstream plotting unchanged. **Commit** `Port R 8_RECOVER to picsure v3 API`.

---

## Task 9: Port `ORCHID_COVID19.ipynb`

**Files:** Modify `NHLBI_BioData_Catalyst/R/ORCHID_COVID19.ipynb`

Legacy: `bdc.searchPicsure(session, 'ORCHID')`; `list_variables <- dictionary_df$name`; `bdc.newQuery` + `bdc.addClause(keys=list_variables, type='ANYOF')`; `runQuery(query) %>% as_tibble()`; large `tableby`/`pivot_longer` analysis referencing short column names (`rand_trt`, `bl_sex`, `d_covid*`, ...).

- [ ] **Step 1:** Standard Header Block (keep `arsenal`/`tidyr`/`forcats` etc. — whatever the notebook imports).
- [ ] **Step 2: Search + ANYOF query:**
```r
dictionary_df <- picsure::searchDictionary(session, "ORCHID")
list_variables <- dictionary_df$conceptPath
anyof_clauses <- lapply(list_variables, function(p) picsure::buildClause(p, type = picsure::PhenotypicFilterType$ANYRECORD))
anyof_group <- picsure::buildClauseGroup(anyof_clauses, operator = picsure::GroupOperator$OR)
query <- picsure::buildQuery(phenotypicFilter = anyof_group, includeConcepts = list_variables)
raw_df <- picsure::runQuery(session, query, type = picsure::QueryType$PARTICIPANT) %>% as_tibble()
```
- [ ] **Step 3:** The notebook renames result columns to short names somewhere (the analysis uses `rand_trt`, `bl_sex`, etc.). Find that renaming step and ensure it maps the v3 concept-path columns (which now include only `patient_id` + concepts) to short names — likely by taking the last non-empty path segment. NOTE (Python carryover): verify `rand_trt` is actually returned by the ORCHID search; if not, that analysis cell can't run.
- [ ] **Step 4:** Leave the large recoding/`tableby`/plot cells unchanged. **Commit** `Port R ORCHID_COVID19 to picsure v3 API`.

---

## Task 10: Port `0_Export_from_UI.ipynb`

**Files:** Modify `NHLBI_BioData_Catalyst/R/0_Export_from_UI.ipynb`

Legacy: connect; `queryID <- 'paste your query ID here'`; `query <- picsure::bdc.getQueryByUUID(session, queryID)`; introspection `query$requiredFields`, `query$categoryFilters`; edit demo `addClause(query, keys="\\phs000820\\...\\sex\\", type="FILTER", ...)`.

- [ ] **Step 1:** Standard Header Block.
- [ ] **Step 2: Load/run by ID:**
```r
# queryID copied from the PIC-SURE UI ("Copy Query ID")
df_UI <- picsure::runQueryByID(session, queryID, type = picsure::QueryType$PARTICIPANT)
head(df_UI)
```
  Keep `queryID` as a placeholder the user fills.
- [ ] **Step 3: Introspection cells** (`query$requiredFields`, `query$categoryFilters`) → there is no live query object; if a load-and-inspect example is desired use `query <- picsure::loadQueryByID(session, queryID)` and inspect the returned R object (`str(query)`), else replace with a markdown note describing the v3 build/inspect model.
- [ ] **Step 4: Edit demo** → rebuild a clause:
```r
sex_path <- "\\phs000820\\pht004332\\phv00219057\\sex\\"
sex_clause <- picsure::buildClause(sex_path, type = picsure::PhenotypicFilterType$FILTER, categories = c("Male", "Female"))
# include sex_clause in picsure::buildClauseGroup(list(...)) / picsure::buildQuery(...)
```
- [ ] **Step 5:** Markdown updates; **commit** `Port R 0_Export_from_UI to picsure v3 API`.

---

## Task 11: Review `Workspace_setup.ipynb`

**Files:** `NHLBI_BioData_Catalyst/R/Workspace_setup.ipynb`

- [ ] **Step 1:** Confirm it only writes `token.txt` (no `picsure::bdc.` calls): `grep -c "bdc\\.\\|initializeSession" NHLBI_BioData_Catalyst/R/Workspace_setup.ipynb` → expect `0`.
- [ ] **Step 2:** If any install markdown lists the legacy approach, align it with the `devtools::install_github(..., ref="main")` from the Standard Header Block; otherwise leave as-is and skip the commit.

---

## Task 12: Live verification pass against BDC

- [ ] **Step 1:** Ensure the `picsure-r` IRkernel (Task 1) is registered and `token.txt` is in `NHLBI_BioData_Catalyst/R/` (fresh, non-expired).
- [ ] **Step 2:** Execute each in-scope notebook (skip `4_Genomic`):
```bash
cd /Users/george/code_workspaces/adapters/Access-to-Data-using-PIC-SURE-API/NHLBI_BioData_Catalyst/R
for nb in 0_Export_from_UI 1_PICSURE_API_101 2_TOPMed_DCC_Harmonized_Variables_analysis 3_PheWAS 5_LongitudinalData 6_Sickle_Cell 7_Harmonization_with_PICSURE 8_RECOVER ORCHID_COVID19; do
  echo "=== $nb ==="
  jupyter nbconvert --to notebook --execute --ExecutePreprocessor.timeout=1200 \
    --ExecutePreprocessor.kernel_name=picsure-r --output "/tmp/${nb}_r_out.ipynb" "${nb}.ipynb" \
    && echo "PASS $nb" || echo "FAIL $nb"
done
```
  (The in-notebook `devtools::install_github` cell re-installs; to skip during verification, comment those lines in temp copies as the Python verification did.)
- [ ] **Step 3: Triage.** `0_Export_from_UI` needs a real `queryID` (expected fail unless provided). Map remaining failures to the same root causes the Python port hit (see the carryovers section + the Python handoff doc). For any new failure, capture the failing line and report.
- [ ] **Step 4: Final sweep** — no legacy API remains:
```bash
grep -lE "bdc\\.|initializeSession|setResource|newQuery|addClause|resultType|getQueryByUUID|searchPicsure|\\bstudy_id\\b|\\bvar_name\\b|\\bvar_description\\b" \
  NHLBI_BioData_Catalyst/R/[0-9]*.ipynb NHLBI_BioData_Catalyst/R/ORCHID*.ipynb | grep -v 4_Genomic || echo "clean"
```
- [ ] **Step 5:** Commit any verification fixes; write a short pass/fail summary (mirror `docs/superpowers/2026-05-26-python-notebook-verification-handoff.md`).

---

## Self-review checklist (done while writing this plan)
- Every in-scope notebook (0,1,2,3,5,6,7,8,ORCHID) has a task; Workspace_setup reviewed; 4_Genomic excluded. ✓
- API names match the R adapter exports (`connect`, `searchDictionary`, `buildClause`, `buildClauseGroup`, `buildQuery`, `runQuery`, `runQueryByID`, `loadQueryByID`, `facets`, `Platform$`, `PhenotypicFilterType$`, `GroupOperator$`, `QueryType$`). ✓
- Column-rename table is consistent across tasks (`name`→`conceptPath`, `var_name`→`name`, `var_description`→`description`, `study_id`→`studyId`, `data_type`→`dataType`). ✓
- Known live-data carryovers from the Python port are pre-applied per notebook. ✓
- `session`-first argument order used for `searchDictionary`/`runQuery`/`runQueryByID`/`loadQueryByID`/`facets`; `buildClause`/`buildClauseGroup`/`buildQuery` take no session. ✓
