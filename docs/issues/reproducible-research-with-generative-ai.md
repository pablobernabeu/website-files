# Issues: reproducible-research-with-generative-ai

The code audit of the post `content/post/reproducible-research-with-generative-ai/`
and its `experiment/` folder, made on 11 October 2026, and the resolution of its
findings on 12 October 2026. Paths below are relative to `experiment/`. Each
heading gives a finding's severity and says whether it was high-risk, that is,
whether it touched code or records behind the published results and so needed
the maintainer's sign-off. The maintainer signed off every change made on 12
October 2026.

Commits are named by their subject lines, which `git log --grep` finds even if
the commits are rebased.

## Open

### m14 (minor, high-risk): the unused column `trimmed_sha256`

`check_versions.R` writes this column of `version_check.csv`, and the post does not
read it. The README documents it as unused. Removing it would change the schema of
a stored record, so the maintainer chose to wait for the next regeneration of that
file rather than edit it by hand.

## Resolved

### Checks

- **V1 (major).** The workflow `reproduce-genai-experiment` ran on commit 98fb72323
  (run 38233561634, 12 October 2026) with the current `run_script.R`,
  `verify_executions.R` and the Dockerfile resolved against the Ubuntu snapshot.
  All 24 scripts printed byte-identical output, and the run's session record
  equals `verification_session_info.txt` line for line. It passed again on
  1c274cfff (run 38317272520), with the record scripts as hardened that day.
- **V2 (minor).** A library restored from `rerun/library.lock` into an empty
  folder (renv 1.2.3 with its cache off, R 4.6.1 on Windows), together with R's
  recommended packages, held all 69 locked versions. `rerun/execute_rerun.R`, run
  with only those libraries, rewrote `rerun/executions.csv` in every column but
  the seconds and its session file byte for byte. stringi 1.8.7 had to be
  installed first with `R CMD INSTALL`, since its source build outlasted renv's
  time limit, as the README now says.

### Major findings

- **M1 (high-risk).** `rerun/scripts/prepare_runs.py` and `build_records.py`
  rebuild the second round's records from the private transcripts, byte for byte.
  Commit: 'Commit the scripts that built the second round's records'.
- **M2b (high-risk).** The Docker build resolves every package against Ubuntu's
  snapshot of 30 September 2026, verified by run 38233561634. Commit: 'Resolve the
  Docker rebuild against a dated Ubuntu snapshot'.
- **M3 (high-risk).** `make_data.R`, `make_unbalanced.R`, `collect_results.R`,
  `check_versions.R` and `rerun/execute_rerun.R` take an optional output folder and
  replace the stored files only without one. Run into a scratch folder,
  `make_data.R`, `make_unbalanced.R` and `collect_results.R` rewrote their files
  byte for byte. `check_versions.R` rewrote its 72 outputs byte for byte and
  `version_check.csv` in every column but the seconds, and `execute_rerun.R`
  rewrote `rerun/executions.csv` in the same way. Commit: 'Harden the
  experiment's record scripts and list the changes since the records'.
- **M4 (high-risk).** `collect_results.R` now counts a prose run as compliant only
  when every call read its own `data.csv`, the condition the post checks. It still
  writes `results.csv` byte for byte.
- **M8 (high-risk), closed without a change.** The session records of
  `execute_scripts.R` and `rerun/execute_rerun.R` describe the parent R session,
  as the README says, and the `environment` column of each `executions.csv`
  records the versions in the child processes that ran the scripts. Recording a
  child session instead would make any regeneration differ from the stored
  records without adding information.
- **M9.** The reasons for the coding of `choices_open_scripts.csv` are not on
  record. All 40 of its values were checked against the scripts and their stored
  outputs, and the README says so, with the one judgement call (a script that
  drops rows with missing values, of which the data have none).

### Minor findings

- **m2.** `.gitattributes` keeps the prompts, runs, the second round's lockfile and
  every text record as stored, with LF, on every checkout. Commit: 'Keep the
  experiment's records byte for byte on every checkout'.
- **m5.** `check_versions.R` stops unless the archived sources of lme4 1.1-35.1
  and lmerTest 3.1-3 have the SHA-256 checksums taken from two CRAN mirrors.
  `requirements.txt` gives the hashes of pilotr 0.3.0's wheel and source archive
  on PyPI. With them, `pip install -r requirements.txt` installed the released
  wheel, which reproduced `python_sha256.txt` under Python 3.13.7.
- **m6.** The reasons for the seed and the 6% are not on record. The comments of
  `make_unbalanced.R` now say what the values do: any proportion unbalances the
  design, 6% removes 86 of the 1,440 trials and keeps every participant and word,
  and the seed, that of `spec.json`, feeds R's generator rather than pilotr's.
- **m8.** The reason for four workers is not on record. The comment in
  `check_versions.R` now says that the number sets only how many scripts run at
  once and cannot change an output.
- **m10 (high-risk).** `extract_transcripts.py` reads and writes UTF-8 with LF in
  `with` blocks and stops on a missing transcript. Its transcripts are not kept,
  so the old and new versions were compared on a synthetic transcript with
  non-ASCII text: their outputs were identical.
- **m11 (high-risk).** `make_runs.R` and `make_runs_followup.R` take the folder for
  the runs as an argument, check that run IDs are unique and that every copy
  succeeds, fix the RNG kind and write through binary connections. Run in a copy
  with a scratch folder, they rewrote `design.csv` byte for byte and all 48 prompts
  with only the folder's path changed.
- **m15 (high-risk).** `build_records.py` writes `compliant` as `TRUE` or `FALSE`,
  and `rerun/results.csv` was rebuilt with it. Commit: 'Write the compliance column
  of the second round as R's TRUE and FALSE'.
- **m16.** `check_versions.R` and `collect_results.R` lint clean. Each parses to
  the same code as before. Commit: 'Fix the remaining lints of two record scripts'.
- **m18.** The README ends with a list of changes to the stored files and to the
  scripts kept as records.

### The post's code

- **CH-06.** One helper, `batch_size_of()`, derives the size of the launch batches
  of both rounds, in the visible chunk that loads the runs.
- **CH-08.** The by-participant slope of about 9 ms is computed in the text, and a
  guard ties it to the value the replies state.
- **CH-19 (high-risk).** `last_commit()` links to a commit only when a branch of the
  remote contains it, and to master otherwise. The renv.lock link uses `repo_url`
  and `lock_file`.
- **CH-20 (high-risk).** A hidden chunk computes the standard deviations of the
  effect in closed form (18.303 and 12.893 ms, against the simulated 18.284 and
  12.894) and checks that both round to the decimal the text prints. The comment
  on the seed says that it is that of `spec.json`.
- **CH-21 (high-risk).** The Limitations write the longest prose run with
  `minutes_text()`. The two rules for minutes, one decimal for medians and single
  times and none from 10 minutes in ranges, are kept and documented.
- **CH-25.** `started` is now `first_date`, the second round's objects take the
  prefix `second_`, and `minutes_of_thinking()` is `minutes_from_seconds()`.

The rest of the findings were resolved on 11 October 2026 in the commits 'Record
the R library of the second round's executions', 'Harden the experiment's scripts
and document how its records were made', 'Strengthen the generative-AI post's
guards and remove duplicated code' and 'Record the experiment's lint settings and
fix the lints of its shared scripts'.
