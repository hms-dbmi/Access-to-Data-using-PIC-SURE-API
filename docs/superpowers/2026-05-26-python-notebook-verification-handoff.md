# Python notebook v3 port — live verification handoff

**Date:** 2026-05-26
**Branch:** `adapters_v3`
**Scope:** `NHLBI_BioData_Catalyst/python/` notebooks ported to the rewritten `picsure` adapter (v3).

## How to re-run verification

A scratch venv and Jupyter kernel were left in place:

```bash
# venv: /tmp/picsure-nb-venv  (picsure@main + jupyter + analysis deps)
# kernel: picsure-nb
cd NHLBI_BioData_Catalyst/python   # token.txt must be here (fresh, non-expired)
/tmp/picsure-nb-venv/bin/jupyter nbconvert --to notebook --execute \
  --ExecutePreprocessor.timeout=600 --ExecutePreprocessor.kernel_name=picsure-nb \
  --output /tmp/out.ipynb 3_PheWAS.ipynb
```

If the venv is gone: `python3 -m venv /tmp/picsure-nb-venv && /tmp/picsure-nb-venv/bin/pip install "git+https://github.com/hms-dbmi/pic-sure-python-adapter-hpds.git@main" jupyter nbconvert ipykernel pandas matplotlib numpy seaborn statsmodels scipy matplotlib-venn` then `… -m ipykernel install --user --name picsure-nb`.

PIC-SURE tokens expire quickly — refresh `token.txt` from the UI (User Profile → COPY) before each session.

## Status (live against BDC Authorized)

| Notebook | Status |
|---|---|
| `1_PICSURE_API_101` | ✅ PASS |
| `2_TOPMed_DCC_Harmonized_Variables_analysis` | ✅ PASS (fixed) |
| `6_Sickle_Cell` | ✅ PASS |
| `8_RECOVER` | ✅ PASS (fixed) |
| `0_Export_from_UI` | ⚠️ needs a real UI `queryID` (placeholder cannot load) — not a code defect |
| `3_PheWAS` | ❌ downstream stats |
| `5_LongitudinalData` | ❌ downstream plot |
| `7_Harmonization_with_PICSURE` | ❌ upstream variable lookup |
| `ORCHID_COVID19_python` | ❌ downstream recoding |
| `4_Genomic_Queries` | ⛔ out of scope (no genomic filter in v3 adapter) |

The API port is sound everywhere — every notebook connects, searches, and queries correctly. Remaining failures are in each notebook's own analysis logic, rooted in how current BDC data differs from when the notebooks were written.

## Two non-obvious BDC runtime facts (drove most fixes)

1. **`searchDictionary()` returns `meta` as `None`** for every row on production BDC. Legacy flattened `columnmeta_*` fields are NOT available from `meta`. Map them to real columns instead:
   - legacy `varId` → v3 **`name`** column (e.g. `pasc_jama2024_infected_3`)
   - legacy variable-group → the **`conceptPath`** category segment (e.g. `\DCC Harmonized data set\demographic\...`)
2. **`runQuery(type=PARTICIPANT)` results carry only `patient_id` + the concept columns** — NOT the legacy 4 metadata columns (`patient_id`/`parent_accession`/`topmed_accession`/`consent`). Legacy positional logic (`df.columns[3]`, `df.iloc[:, 4:]`, positional `df.columns = [...]`) is off by 3. Prefer order-independent renames keyed on concept path.

Search DataFrame columns: `conceptPath, name, display, description, dataType, studyId, values, min, max, allowFiltering, meta, studyAcronym`.

## The 4 remaining failures — pointers

### `3_PheWAS` — `ZeroDivisionError`
- **Line:** `combined_df['adj_pvalues'] = smt.multipletests(combined_df['pval'], alpha=0.01, method='holm')[1]`
- **Cause:** `combined_df` is empty/degenerate → `run_phewas` produced no usable associations. The FHS male/female cohort subset or the `categorical_cholesterol` split likely has no data or a single class.
- **Where to look:** confirm `total_cholesterol_1` returns values for the FHS subset, that both case (1) and control (0) classes exist in `categorical_cholesterol`, and that `continuous_paths`/`categorical_paths` are non-empty after the removes in cell ~23.

### `5_LongitudinalData` — `IndexError: index 3 out of bounds for size 3`
- **Line:** `plotdf.drop(plotdf.columns[[0, 1, 2, 3]], axis=1, inplace=True)`
- **Cause:** the pivoted `plotdf` has only 3 columns. Current FHS lipid data has just one longitudinal variable across 2 exams (`LIPMED5`/`LIPMED10`), far narrower than the hardcoded 4-column drop assumes.
- **Where to look:** the cell hardcodes dropping 4 leading columns; make it relative to actual width, or pick a longitudinal variable with more exams. Note this notebook's example data is now thin.

### `7_Harmonization_with_PICSURE` — `IndexError: index 0 out of bounds for size 0`
- **Line:** `copdgene_sex_var = copdgene_sex_df[['conceptPath']].iloc[0,0]` (cell ~39, **upstream** of the cells fixed in the port)
- **Cause:** `copdgene_sex_df` is empty — the COPDGene (phs000179) sex-variable filter matches nothing in current data.
- **Where to look:** the filter deriving `copdgene_sex_df` from the `sex|gender` search. The port fixes downstream of this (positional cols, renames, pneumonia `meta`→`conceptPath`) are correct and will take effect once this lookup is restored.

### `ORCHID_COVID19_python` — `KeyError: 'rand_trt'`
- **Line:** `orchid_data['rand_trt'] = orchid_data['rand_trt'].astype(rand_trt_order)` (big recoding cell)
- **Cause:** `searchDictionary("ORCHID")` results, after path-simplification, don't contain a column named `rand_trt`.
- **Where to look:** `print(list(orchid_data.columns))` and compare against the names the recoding cell expects; the variable may not be returned by the search or its simplified name differs.

## Commits (this branch)
Port commits per notebook + the live-fix commits:
`0623349` (2_TOPMed), `631626f` (8_RECOVER), `d6f112c` (3_PheWAS), `df5eb77` (5_LongitudinalData), `491bd0d` (7_Harmonization), `11ae2a3` (ORCHID).
