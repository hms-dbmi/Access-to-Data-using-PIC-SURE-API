# Port BDC Python notebooks to the rewritten `picsure` adapter

**Date:** 2026-05-26
**Status:** Approved
**Branch:** `adapters_v3` (notebooks live in `NHLBI_BioData_Catalyst/python/`)

## Problem

The notebooks in `NHLBI_BioData_Catalyst/python/` target the legacy PIC-SURE
Python client (`PicSureClient` + `PicSureBdcAdapter`). The Python adapter has
been rewritten (the working tree of `pic-sure-python-adapter-hpds`) with a
completely new public API. The notebooks must be rewritten to use the new
`picsure` package.

## Canonical reference

The adapter repo ships its own example notebooks in
`pic-sure-python-adapter-hpds/notebooks/` (`0_Connect`, `1_Search`, `2_Query`,
`4_Complex_Open_Queries`, …). **These are the source of truth for idioms** —
import style, connection, facet-scoped search, query assembly, result
handling. The BDC notebook rewrites mirror them. The accurate public API was
read from the working tree (not git history); SELECT was removed and the
query-building functions were renamed/restructured.

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
  **phenotypic** filters (`buildClause` accepts `FILTER` / `ANYRECORD` /
  `REQUIRE`); there is no genomic/variant filter, so the genotype query cells
  cannot be ported yet.
- The R notebooks.
- The `8_RECOVER_executed.html` rendered artifact.

## Install + connect convention (every notebook)

Legacy used three pip installs (`pic-sure-python-client`,
`pic-sure-python-adapter-hpds`, `pic-sure-biodatacatalyst-python-adapter-hpds`)
plus `PicSureClient` / `PicSureBdcAdapter` and a hard-coded `.../picsure` URL.
This collapses to a single package and a single import, matching the reference
notebooks:

```python
!{sys.executable} -m pip install --upgrade --force-reinstall \
    git+https://github.com/hms-dbmi/pic-sure-python-adapter-hpds.git@main
```

```python
import picsure

with open("token.txt") as f:
    my_token = f.read()

session = picsure.connect(picsure.Platform.BDC_AUTHORIZED, my_token)
```

Members are accessed through the `picsure.` namespace (`picsure.buildClause`,
`picsure.PhenotypicFilterType.FILTER`, `picsure.QueryType.PARTICIPANT`, etc.),
mirroring the reference notebooks rather than using `from picsure import …`.
`picsure.Platform.BDC_AUTHORIZED` points at
`https://picsure.biodatacatalyst.nhlbi.nih.gov` — the same production host the
legacy notebooks hard-coded (the `/picsure` path is now internal).

## New query-building model (3 functions)

- `picsure.buildClause(keys, type, categories=/min=/max=)` — one filter clause.
  `type` ∈ `PhenotypicFilterType.{FILTER, ANYRECORD, REQUIRE}`.
- `picsure.buildClauseGroup([clauses], operator=GroupOperator.{AND,OR})` —
  combine clauses / nested groups.
- `picsure.buildQuery(phenotypicFilter=None, includeConcepts=())` — assemble a
  runnable `Query` from a filter tree and/or output columns.
- `session.runQuery(query, type=QueryType.{COUNT, PARTICIPANT, CROSS_COUNT, TIMESTAMP})`.

## API translation map

| Legacy | New |
|---|---|
| `bdc.useDictionary().dictionary().find(term)` | `session.searchDictionary(term)` → DataFrame |
| scope search to a study via `df[df.studyId == phs]` | idiomatically `fs = session.facets(); fs.add("dataset_id", phs)` then `searchDictionary(term, facets=fs)` (dataframe filtering on `studyId` still works) |
| `.dataframe()` / `.count()` / `.listPaths()` | operate on the returned DataFrame (`.shape[0]`, `df["conceptPath"]`, etc.) |
| dataframe col `HPDS_PATH` | `conceptPath` |
| dataframe col `columnmeta_name` | `name` |
| `bdc.useAuthPicSure().query()` | no query object; build clauses directly |
| `query.filter().add(path, "Cat")` | `picsure.buildClause(path, picsure.PhenotypicFilterType.FILTER, categories="Cat")` |
| `query.filter().add(path, min=, max=)` | `picsure.buildClause(path, picsure.PhenotypicFilterType.FILTER, min=, max=)` |
| `query.require().add([paths])` | `picsure.buildClause(paths, picsure.PhenotypicFilterType.REQUIRE)` |
| `query.anyof().add([paths])` | OR group of per-path `ANYRECORD` clauses via `picsure.buildClauseGroup([...], picsure.GroupOperator.OR)` (see nuances) |
| `query.select().add([paths])` | `picsure.buildQuery(includeConcepts=[paths])` — **SELECT is no longer a clause type** |
| combine filters | `picsure.buildClauseGroup([clause, …], operator=…)` |
| assemble & run for rows | `picsure.buildQuery(phenotypicFilter=tree, includeConcepts=[…])` then `session.runQuery(q, type=picsure.QueryType.PARTICIPANT)` |
| `query.getResultsDataFrame()` | as above → DataFrame |
| `query.getCount()` | `session.runQuery(q, type=picsure.QueryType.COUNT)` → `CountResult` |
| cross counts | `session.runQuery(q, type=picsure.QueryType.CROSS_COUNT)` |
| `resource.retrieveQueryResults(uuid)` / load saved query | `session.loadQueryByID(uuid)` then `runQuery`, or `session.runQueryByID(uuid, type=…)` |

## Translation nuances to handle explicitly

- **`select` → `includeConcepts`**: column selection is no longer a clause.
  Paths to return as output columns go in `buildQuery(includeConcepts=[…])`.
- **`anyof`**: legacy semantics = "participant has a record in *any* of the
  listed concepts." `ANYRECORD` is per-clause (presence of any value for a
  *single* variable). Model multi-path `anyof` as an OR group of `ANYRECORD`
  clauses (`buildClauseGroup([...], GroupOperator.OR)`) and verify the count
  matches intent against live BDC.
- **`CountResult`**: `getCount()` returned an int; `runQuery(type=COUNT)`
  returns a `CountResult` with `value` / `margin` / `cap` / `raw` (small counts
  obfuscated — `value` may be `None`; `raw` is the display string like
  `"610 ± 3"`). Cells that printed a count read `.value` (and handle the
  obfuscated case).
- **Search DataFrame columns**: `conceptPath`, `name`, `display`,
  `description`, `dataType`, `studyId`, `values`, `min`, `max`,
  `allowFiltering`, `meta`, `studyAcronym`. Legacy `HPDS_PATH`/`columnmeta_name`
  references map to `conceptPath`/`name`.
- **Harmonized / longitudinal variables** (notebooks 2/3/5/7): ordinary concept
  paths, not a special API — port via the standard search/query map.
- **Markdown cells**: update prose that *describes the API* (method names,
  `bdc.help()`, filter/require/anyof/select explanations) to match the new code.
  Leave narrative/analysis prose unchanged.

## Verification

Performed once, after all 9 notebooks are rewritten, live against BDC:

1. Install the adapter from `main` into a scratch venv.
2. `token.txt` is in `NHLBI_BioData_Catalyst/python/` (already placed by user).
3. Execute each notebook end-to-end with `jupyter nbconvert --execute`.
4. A notebook passes when it runs clean to the last cell with sensible output.

Report per-notebook pass/fail with errors. Notebooks needing data access the
token lacks are flagged, not counted as failures.

## Success criteria

- All 9 notebooks import and use only the new `picsure` package.
- No remaining references to `PicSureClient` / `PicSureBdcAdapter` or the legacy
  `.filter()/.require()/.anyof()/.select()/.getResultsDataFrame()` API.
- API-describing markdown matches the new code.
- Each in-scope, token-accessible notebook executes clean against live BDC.
