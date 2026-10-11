# Open issues

These are the findings of the code audit of 11 October 2026 that were not
applied. Each heading gives the finding's severity and says whether it is
high-risk, that is, whether it touches code or records behind the published
results and so needs the maintainer's sign-off. The applied findings are in the
commits of that date.

## Major findings

### M1 (major, high-risk): the scripts that built `rerun/results.csv` and `rerun/runs/` are not committed

Three Python scripts prepared the second round's prompts, collected each run's
settings, times and tool calls from its transcript and wrote the cleaned
records. Two more ran and summarised the xhigh runs. None of them is in the
repository, and copies are kept outside it, in
`%LOCALAPPDATA%\genai-experiment-preserved\2026-10-11\`. They hard-code
absolute paths that contain the Windows user name and the session ID, and the
script that writes the records deletes its output folder (`shutil.rmtree`),
which is `rerun/` itself. The README now defines the columns of
`rerun/results.csv` and says that no script here writes it.

The maintainer first chooses between redacted verbatim copies and parameterised
ones. They would then be committed as `rerun/prepare_runs.py`,
`rerun/collect_records.py` and `rerun/build_records.py`, with the paths and the
session ID as command-line arguments and with a check that stops if the output
folder already holds files in place of `shutil.rmtree`. The summary of the
xhigh runs would be folded in without its token weighting. Before committing,
run them into a scratch folder and compare the result with `rerun/results.csv`
and `rerun/runs/`. The column `compliant` is written as Python's `True`, which R
reads as text (see m15).

### M2b (major, high-risk): the Docker build takes the dependencies of the pinned packages from the live archive

`apt-get update` resolves every dependency, from the BLAS and LAPACK to nloptr
and RcppEigen, against the Ubuntu archive of the build day. An update to one of
them would therefore change the rebuilt environment without failing the build.
The monthly scheduled run of the workflow now shows such a change as a failed
comparison, but cannot prevent it.

The fix is to resolve against Ubuntu's snapshot service, for instance with
`apt-get update --snapshot 20260930T200000Z` and the same option on
`apt-get install`, installing `ca-certificates` first if the snapshot server
cannot be verified without it. The workflow must then report 24 of 24
identical, with a package list equal to `verification_session_info.txt`.
`verification.csv` stays as it is unless the maintainer chooses to refresh it.

### M3, optional part (major, high-risk): an output folder for the scripts that replace stored files

`make_data.R`, `make_unbalanced.R`, `check_versions.R` and
`rerun/execute_rerun.R` write into the folder that holds the stored files, and
the README now says to run them in a copy. Giving each an output-folder
argument would change scripts that are records of how the stored files were
made.

### M4, optional part (major, high-risk): the compliance check of the prose runs in `collect_results.R`

Line 42 checks only that a prose run called no tool but Read, as the comment
now says. Requiring that it read only its own `data.csv` would change a record
script, and the post already checks the stricter condition.

### M8, optional part (major, high-risk): session records from a child process

`executions_session_info.txt` and `rerun/executions_session_info.txt` describe
the parent R session, while `verify_executions.R` and `check_versions.R` record
a child session, as the README now explains. A helper in `run_script.R` that
records a child session with lme4, lmerTest, Matrix, emmeans and pbkrtest
attached, where installed, would make future regenerations consistent. It would
also change what a regeneration writes.

### M9, remaining part (major): who coded `choices_open_scripts.csv`, and how

The README now describes the file's columns and says that no script writes it.
Whether it was coded by hand, by whom and from what is not on record, so the
maintainer should add it there.

## Minor findings

### m2 (minor): line endings of the prompts, replies, tool logs and scripts

With `core.autocrlf=true`, the working copies of `prompts/` and `runs/` are
written with CRLF, so their bytes depend on the platform, unlike those of
`rerun/runs/`. The fix is to add `prompts/** -text`, `runs/** -text` and
`rerun/** -text` to `.gitattributes` and then rewrite the working copies from
the repository by deleting them and running `git checkout -- prompts runs
rerun`. That second step overwrites the working copies of stored records, so it
was left to the maintainer, and adding the attributes without it could make git
report those files as changed. Afterwards, `git status` must be clean and the
dry knit of the post unchanged.

### m5, remaining parts (minor): checksums of downloaded inputs

`check_versions.R` installs `lme4_1.1-35.1.tar.gz` and `lmerTest_3.1-3.tar.gz`
from the CRAN archive without checking them, and `requirements.txt` pins
pilotr 0.3.0 with neither a hash nor a Python version. Recording the tarballs'
SHA-256 checksums, and the hashes of pilotr's wheel and source archive on PyPI,
needs those files downloaded and checked, which this audit did not do. The
local Python installation of pilotr is an editable copy of its source, so it
cannot confirm which Python version reproduces `python_sha256.txt` with the
released package.

### m6, remaining part (minor): the seed and the 6% of `make_unbalanced.R`

The RNG kind is now fixed. Whether reusing the seed of `spec.json` (2026) was
deliberate, and why 6% of the trials were removed, is not on record, so the
maintainer should give the reasons in the script's comments.

### m8, remaining part (minor): four workers in `check_versions.R`

`parallel::makeCluster(4, ...)` has no stated reason, which the maintainer
should add to the comment above it.

### m10 (minor, high-risk): `extract_transcripts.py`, a record

The script opens files without an explicit encoding, leaves two read handles
open and skips a missing transcript silently. It ran on Linux, so the stored
replies are unaffected. If it is ever run again, it should use
`open(..., encoding='utf-8')` in `with` blocks and stop on a missing
transcript.

### m11 (minor, high-risk): `make_runs.R` and `make_runs_followup.R`, records

Neither checks the uniqueness of the run IDs within a layout or the result of
`file.copy()`, and both type the path `/home/user/agent_runs`. `design.csv`
holds 48 unique IDs. If the scripts are reused, they should add
`stopifnot(!anyDuplicated(design$run_id))` and wrap each `file.copy()` in
`stopifnot()`.

### m14 (minor, high-risk): the unused column `trimmed_sha256`

`check_versions.R` writes this column, and the post does not read it. Removing
it changes the schema of `version_check.csv`, so it waits for the next
regeneration of that file.

### m15 (minor, high-risk): `compliant` is written as `True` in `rerun/results.csv`

R reads the value as text, so the post converts it with `as.logical()`. The
stored file stays as it is, and a committed generator (M1) should write `TRUE`
and `FALSE`.

### m16, remaining part (minor): lints in the record scripts

`.lintr` records the house style, and `run_script.R` and `verify_executions.R`
lint clean. The brace, indentation and length lints in `check_versions.R` and
`collect_results.R` are left, since those files are records of how the stored
files were made.

### m18 (minor): no changelog

This is a one-off experiment folder, and git history records every change.
None of the applied findings changed a stored record. The README should gain a
section on changes with the first change that does, such as M2b.

### CH-06, remaining part (minor): a helper for the launch batches

The batch logic appears in the visible chunk that loads the runs and again in a
hidden chunk. A helper would hide the derivation of the batch size that the
prose reports, so the visible code was kept explicit.

### CH-08, remaining part (minor): a number typed into the prose

The sentence on the replies to the specified request types 'about 9 ms'. It
would render the same with
`` `r sprintf('%.0f', attr(participant_effects, 'stddev')[['prime_c']])` `` in
place of the 9, but that edit is to the prose, which another pass owns. Until
then, the guard `round(attr(participant_effects, 'stddev')[['prime_c']]) == 9`
protects the typed value.

### CH-19 (minor, high-risk): links to commits that may not be on master

`last_commit()` links to the last commit that changed a path, whether or not
GitHub's master contains it. A knit made before the experiment commit is
pushed, followed by `git pull --rebase`, would link to a hash that GitHub never
receives. The proposed fix keeps a hash only if `git branch -r --contains
<hash>` is not empty and falls back to master otherwise, which then requires
pushing the experiment commit before knitting. Since it changes the page's link
addresses, it needs sign-off and a real knit.

In the same section of the prose, the renv.lock link still types the
repository's address and the lockfile's path. The setup chunk now holds them as
`repo_url` and `lock_file`, so the link can become
`` `r sprintf('%s/blob/%s/renv.lock', repo_url, last_commit(lock_file))` ``.

### CH-20, remaining part (minor, high-risk): a closed form for the standard deviations of the effect

The lognormal standard deviations have a closed form, 18.303 and 12.893 ms
against the simulated 18.284 and 12.894. Replacing the simulation would change
the chunk's printed output and the sentence that says the code draws a million
of each, though not the one-decimal values in the text. Why the seed is 2026,
the seed of `spec.json`, is not on record.

### CH-21, remaining part (minor, high-risk): one rule for writing minutes

Ranges of run times drop the decimal from 10 minutes, while medians and single
times keep one, as the comment now says. Harmonising them would change rendered
numbers and Table 4. The Limitations could use
`` `r minutes_text(range_in('prose')[2])` ``, which renders the same '29', but
that is a prose edit.

### CH-25, remaining part (minor): renames that reach the prose

Renaming `started` to `first_date`, the objects ending in `_2` to the prefix
`second_`, and `minutes_of_thinking()` would change inline code in the prose,
so they wait for the prose pass. The renames of `labels`, `frequency` and the
argument `round` were not made, since none of them masks a function that the
code calls.
