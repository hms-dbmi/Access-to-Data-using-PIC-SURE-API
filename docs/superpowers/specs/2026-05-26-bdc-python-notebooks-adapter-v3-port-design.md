# Port BDC Python notebooks to the rewritten `picsure` adapter

**Date:** 2026-05-26
**Status:** Approved

## Problem

The notebooks in `NHLBI_BioData_Catalyst/python/` target the legacy PIC-SURE
Python client (`PicSureClient` + `PicSureBdcAdapter`). The Python adapter has
been rewritten (the `main` branch of `pic-sure-python-adapter-hpds`) with a
completely new public API. The notebooks must be rewritten to use the new
`picsure` package.

## Scope

Rewrite 9 notebooks onto the new API:

- `0_Export_from_UI.ipynb`
- `1_PICSURE_API_101.ipynb`
- `2_TOPMed_DCC_Harmonized_Variables_analysis.ipynb`
- `3_PheWAS.ipynb`
- `5_LongitudinalData.ipynb`
- `6_Sickle_Cell.ipynb`
- `7_Harmonization_with_PICSURE.ipynb`
- `8_RECOVER.ipynb`
- `ORCHID_COVID19_python.ipynb`

`Workspace_setup.ipynb` gets only its install/setup cells updated.

### Out of scope

- `4_Genomic_Queries.ipynb` — left untouched. The new adapter exposes only
  **phenotypic** filters (`createSubQuery` accepts `FILTER` / `ANYRECORD` /
  `REQUIRE` / `SELECT`); there is no genomic/variant filter, so the genotype
  query cells cannot be ported yet.
- The R notebooks.
- The `8_RECOVER_executed.html` rendered artifact.

## Install + connect convention (every notebook)

Legacy used three pip installs plus `PicSureClient` / `PicSureBdcAdapter` and a
hard-coded `.../picsure` URL. This collapses to a single package install:

```python
!{sys.executable} -m pip install --upgrade --force-reinstall \
    git+https://github.com/hms-dbmi/pic-sure-python-adapter-hpds.git@main
```

```python
import picsure
from picsure import (
    Platform, createSubQuery, buildQuery,
    PhenotypicFilterType, GroupOperator,
)

with open("token.txt") as f:
    my_token = f.read().strip()

session = picsure.connect(Platform.BDC_AUTHORIZED, my_token)
```

`Platform.BDC_AUTHORIZED` points at
`https://picsure.biodatacatalyst.nhlbi.nih.gov` (the same production host the
legacy notebooks hard-coded; the `/picsure` path is now handled internally).

## API translation map

| Legacy | New |
|---|---|
| `bdc.useDictionary().dictionary().find(term)` | `session.searchDictionary(term)` → DataFrame |
| `.dataframe()` / `.count()` / `.listPaths()` / `.varInfo()` | operate on the returned DataFrame (`.shape`, column access, etc.) |
| `bdc.useAuthPicSure().query()` | build clauses directly; no query object |
| `query.filter().add(path, "Cat")` | `createSubQuery(path, PhenotypicFilterType.FILTER, categories="Cat")` |
| `query.filter().add(path, min=, max=)` | `createSubQuery(path, PhenotypicFilterType.FILTER, min=, max=)` |
| `query.require().add([paths])` | `createSubQuery(paths, PhenotypicFilterType.REQUIRE)` |
| `query.anyof().add([paths])` | OR-group of per-path `ANYRECORD` clauses via `buildQuery([...], GroupOperator.OR)` (see nuances) |
| `query.select().add([paths])` | `createSubQuery(paths, PhenotypicFilterType.SELECT)` |
| combine filters | `buildQuery([clause, clause, ...], GroupOperator.AND)` |
| `query.getResultsDataFrame()` | `session.runQuery(query, type="participant")` |
| `query.getCount()` | `session.runQuery(query, type="count")` → `CountResult` |
| cross counts | `session.runQuery(query, type="cross_count")` |

## Translation nuances to handle explicitly

- **`anyof`**: legacy semantics = "participant has a record in *any* of the
  listed concepts." New `ANYRECORD` is per-clause (presence of any value for a
  *single* variable). Model multi-path `anyof` as an OR group of `ANYRECORD`
  clauses (`buildQuery([...], GroupOperator.OR)`) and verify the resulting
  count matches intent against live BDC.
- **`CountResult` obfuscation**: `getCount()` returned an int; the new
  `runQuery(type="count")` returns a `CountResult` carrying `value` / `margin`
  / `cap`, where small counts are obfuscated (`value` may be `None`). Cells
  that printed a count read `.value` and account for the obfuscated case.
- **Harmonized / longitudinal variables** (notebooks 2/3/5/7): these are
  ordinary concept paths, not a special API — they port via the standard
  search/query map with no genomic dependency.
- **Markdown cells**: update prose that *describes the API* (method names,
  `bdc.help()`, the filter/require/anyof explanations) to match the new code.
  Leave narrative/analysis prose unchanged.

## Verification

Performed once, after all 9 notebooks are rewritten, live against BDC:

1. Install the adapter from `main` into a scratch venv.
2. User places a valid `token.txt` in the python notebooks directory.
3. Execute each notebook end-to-end with `jupyter nbconvert --execute`.
4. A notebook passes when it runs clean to the last cell with sensible output.

Report per-notebook pass/fail with errors. Notebooks needing data access the
token lacks are flagged, not counted as failures.

## Success criteria

- All 9 notebooks import and use only the new `picsure` package.
- No remaining references to `PicSureClient` / `PicSureBdcAdapter` or the
  legacy `.filter()/.require()/.anyof()/.select()/.getResultsDataFrame()` API.
- API-describing markdown matches the new code.
- Each in-scope, token-accessible notebook executes clean against live BDC.
