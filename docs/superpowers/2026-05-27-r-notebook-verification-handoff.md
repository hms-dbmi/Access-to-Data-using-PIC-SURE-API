# R notebook v3 port — live verification handoff

**Date:** 2026-05-27
**Branch:** `adapters_v3`
**Scope:** `NHLBI_BioData_Catalyst/R/` notebooks ported to the rewritten `picsure` **R** adapter (v3, reticulate wrapper over the v3 Python adapter).
**Plan:** `docs/superpowers/plans/2026-05-26-bdc-r-notebooks-adapter-v3-port.md`

## Status (live against BDC Authorized)

| Notebook | Status |
|---|---|
| `1_PICSURE_API_101` | ✅ PASS |
| `2_TOPMed_DCC_Harmonized_Variables_analysis` | ✅ PASS |
| `6_Sickle_Cell` | ✅ PASS |
| `8_RECOVER` | ✅ PASS |
| `0_Export_from_UI` | ⚠️ needs a real UI `queryID` (placeholder cannot load) — not a code defect |
| `3_PheWAS` | ❌ downstream analysis |
| `5_LongitudinalData` | ❌ downstream plot |
| `7_Harmonization_with_PICSURE` | ❌ upstream variable lookup empty |
| `ORCHID_COVID19` | ❌ downstream missing variable |
| `4_Genomic_Queries` | ⛔ out of scope (no genomic filter in v3 adapter) |

This mirrors the Python port exactly (same 4 pass; same notebooks fail with the same root causes — they run the same analyses against the same backend). The API port itself is sound everywhere; every notebook connects, searches, and queries correctly. Remaining failures are in each notebook's own analysis logic / current-data assumptions.

## Environment setup (IMPORTANT — the notebooks' install cell is broken on macOS)

The notebooks' install cell sets `Sys.setenv(TAR = "/bin/tar")` then `devtools::install_github("hms-dbmi/pic-sure-r-adapter-hpds", ref="main")`. On this machine `tar` is at `/usr/bin/tar`, not `/bin/tar`, so `install_github` fails with tar error code 127 — and an **older** `picsure` (without `buildClause`/`buildQuery`) silently remains installed, causing `Error: 'buildClause' is not an exported object from 'namespace:picsure'`.

For verification the adapter was installed from local source instead:
```bash
cd /Users/george/code_workspaces/adapters/pic-sure-r-adapter-hpds && R CMD INSTALL .
```
On BDC-Seven Bridges (the notebooks' target env) `/bin/tar` may exist; on macOS, either drop the `Sys.setenv(TAR=...)` line or set it to `/usr/bin/tar`.

R analysis packages installed for verification: `dplyr stringr ggplot2 ggrepel tidyr forcats arsenal DescTools cmprsk coin ggtext kableExtra quantreg survival survminer tibble` + `IRkernel` (kernel `picsure-r`).

## How to re-run verification
```bash
# token.txt (fresh, non-expired) must be in the run dir
cd NHLBI_BioData_Catalyst/R
jupyter nbconvert --to notebook --execute --ExecutePreprocessor.timeout=900 \
  --ExecutePreprocessor.kernel_name=picsure-r --output /tmp/out.ipynb 3_PheWAS.ipynb
```
The driver `/tmp/run_r_nb_verification.py` runs all in-scope notebooks (it neutralizes the in-notebook `install_github` line and copies the token into the run dir). PIC-SURE tokens expire quickly — refresh `token.txt` from the UI before each session.

## The 4 remaining failures — pointers

### `3_PheWAS` — `get(sex_path)`: "first argument has length > 1"
- The cell `fhs_subset %>% filter(get(sex_path) == 'Female')`. `sex_path` resolved to MORE THAN ONE column (multiple 'sex' columns matched in the harmonized result), so `get()` (which needs a single name) errors.
- **Where to look:** the cell deriving `sex_path` from the result columns — constrain it to a single sex concept path (e.g. the FHS annotated-sex variable). Mirrors the Python PheWAS failure (degenerate/over-broad cohort selection).

### `5_LongitudinalData` — `[.data.frame(plotdf, , x): undefined columns selected`
- The downstream pivot/plot cell selects columns by hardcoded positions (`colnames(plotdf)[-33]`, `levels = c(1:32)`) assuming ~32 exams. Current FHS lipid data is far thinner (the single "Taking lipid lowering medication…" variable across ~2 exams), so those columns don't exist.
- **Where to look:** the `plotdf` pivot/`select` cell — make the column selection relative to the actual number of exam columns. Same root cause as the Python `5_LongitudinalData` failure.

### `7_Harmonization_with_PICSURE` — `buildClause(p, ...): keys must be a non-empty character string or vector`
- One of the path vectors passed to a `lapply(..., buildClause)` is empty/NA. The most likely culprit is `copdgene_sex_var` (`copdgene_sex_df[copdgene_sex_df$name == 'gender', 'conceptPath'][1]`) returning `NA` because no COPDGene sex variable is named exactly `gender` in current data (flagged as a live-data risk during the port).
- **Where to look:** verify the COPDGene sex variable's `name` value live (`searchDictionary(session, "sex|gender")` filtered to `phs000179`) and adjust the filter; likewise confirm the orthopnea/pneumonia path vectors are non-empty. Same root cause as the Python `7_Harmonization` failure.

### `ORCHID_COVID19` — `filter(): .data[[NA_character_]] != ""`
- After installing all analysis packages, the cell "Filter out rows where bl_sex is missing" fails because the dynamic lookup `grep('bl_sex', colnames(raw_df), value=TRUE)[1]` returned `NA` — no `bl_sex` column in the result. The analysis also expects `rand_trt`, `subject_id`, etc.
- **Where to look:** `print(colnames(raw_df))` after the query and compare against the short names the analysis expects (`bl_sex`, `rand_trt`, `subject_id`, `d_covid*`); the ORCHID search may not return those variables or their path's last segment differs. Same family as the Python ORCHID `rand_trt` failure.

## Commits (R ports, this branch)
Per-notebook: `925ce5e`→`1b232c8` (1_PICSURE_API_101, incl. multi-key REQUIRE fix), `ae9c5d5`/`6274443` (2_TOPMed), `5ea72f0` (3_PheWAS), `583cb96` (5_LongitudinalData), `cdbd4e9` (6_Sickle_Cell), `df272dd` (7_Harmonization, incl. NA-safe study detection), `3f648da` (8_RECOVER, incl. REQUIRE split), `957b12d` (ORCHID), `73fbf01` (0_Export_from_UI).

## Cross-cutting fix worth noting for the Python notebooks too
**Multi-key `buildClause(c(a,b), ...)` serializes as OR.** A REQUIRE meant as "all present" (AND) must be split into one single-key clause per path under `GroupOperator$AND`. This was fixed in R `1_PICSURE_API_101` and `8_RECOVER`. The **Python** `1_PICSURE_API_101` (age+hyperten REQUIRE) and `8_RECOVER` (8-path REQUIRE) have the same latent OR-vs-AND bug and should be fixed the same way.
