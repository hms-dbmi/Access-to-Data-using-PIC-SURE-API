# PIC-SURE Demos

This folder holds **use-case-specific example notebooks** written for a particular audience or question, such as a live demo for a research group, a walkthrough for collaborating teams, or a worked example produced in response to a help desk ticket.

They are shared publicly because the code is often useful to more than the person who originally asked for it. If a pattern here answers your question, feel free to copy it.

## How this folder differs from the rest of the repository

The other top-level folders in this repository (`NHLBI_BioData_Catalyst/`, `NCATS_Genomic_Information_Commons/`, `NIH_Undiagnosed_Diseases_Network/`, `AIM-AHEAD/`, `CDC_National_Health_and_Nutrition_Examination_Survey/`) contain the **maintained tutorial series** for each PIC-SURE-backed project — a numbered, parallel set of Python and R notebooks that are kept current as the platform and API evolve. **Start there if you are new to the PIC-SURE API.**

This folder is different in a few ways worth knowing before you rely on anything in it:

- **Written for a specific moment.** Each notebook targets the studies, variables, and API version that were current when it was written, for the audience it was written for. It is a snapshot, not a living document.
- **Not on a maintenance schedule.** These notebooks are not re-verified against the live platform on a regular cadence. Code that ran cleanly on its demo date may need adjustment — variables get renamed, studies get updated, and the API changes.
- **Not exhaustive.** A demo shows one path through a problem, chosen for that audience. It is not a complete reference for the functionality it touches.

## What you need to run these

- A **PIC-SURE account** with access to the platform the notebook targets, plus authorization for the studies it queries. Some notebooks use data you may not be approved for; the code will still be readable, but it will not run without access.
- A **personal security token**, saved as `token.txt` next to the notebook you are running. Get it from the platform UI under **Prepare for Analysis → Copy**. Tokens are personal, **never commit a token to source control**.
- The PIC-SURE API client for the language the notebook uses. Each notebook installs its own dependencies in a setup cell.

## Contents

| Notebook | Language | Audience / origin | Last run rate | Summary |
|---|---|---|---|---|
| [BDC_Demo_to_Yale_Lab_2026.ipynb](BDC_Demo_to_Yale_Lab_2026.ipynb) | Python | Live demo for a Yale research lab | September 8, 2026 | End-to-end introduction to the PIC-SURE API on *NHLBI BioData Catalyst®*: connecting with a security token, searching the variable dictionary (with facets), reading concept paths, building categorical / continuous / `REQUIRE` filters into clause groups, running count and participant-level queries, and picking up a cohort built in the web UI by its query ID. Uses the Framingham tutorial study. |

## Adding a demo to this folder

If you are on the team and want to add one:

1. Give the notebook a descriptive name that captures **who it was for and when** (e.g. `BDC_Demo_to_Yale_Lab_2026.ipynb`), so it stays interpretable after the context is forgotten.
2. Add a row to the table above with its language, audience, and a one-line summary.
3. Open the notebook with a markdown cell stating its purpose, the platform and studies it queries, and the date it was last run successfully.
4. Prefer a tutorial or open-access study for demonstration data where possible, so readers without specialized access can follow along.
5. Clear or review cell outputs before committing, and confirm no token, participant-level data, or other sensitive output is left in the notebook.

## Contact

For questions about the PIC-SURE API or the platforms these notebooks use, please contact the Avillach Lab by submitting a helpdesk ticket: https://hms-dbmi.atlassian.net/servicedesk/customer/portal/5 
