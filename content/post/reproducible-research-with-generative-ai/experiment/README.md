# Experiment files

The data, prompts, agent outputs, scripts and records behind the post *Forty-eight
answers to one question: Reproducible research with generative AI*. The post reads
these files, and it executes every script written in the first round again when it
is knitted.

The files fall into three groups: scripts that can be run again, scripts kept as a
record of how the stored files were made, and the records themselves.

## Order of the steps

The stored files were made in this order, by the scripts named, by the agents
and, in steps 8 and 10, without a script.

1. `make_data.R` wrote `data.csv`.
2. `make_runs.R` wrote the first 32 runs to `design.csv` and each run's prompt to
   `runs/<run_id>/prompt.txt`.
3. The agents made those 32 runs on the balanced data.
4. `make_unbalanced.R` wrote `data_unbalanced.csv`, and `make_runs_followup.R`
   added 16 runs on it to `design.csv`. The agents then made those runs.
5. `extract_transcripts.py` wrote each run's `response.txt` and `tool_calls.json`.
6. `execute_scripts.R` wrote `executions.csv` and `executions_session_info.txt`.
7. `collect_results.R` wrote `results.csv`.
8. `choices_open_scripts.csv` records the analytic choices of the scripts written
   for the open request. No script writes it.
9. `check_versions.R` wrote `version_check.csv`, `version_check_session_info.txt`
   and `outputs/`.
10. The workflow `.github/workflows/reproduce-genai-experiment.yml` wrote the
    artifact `verification`, whose two files were copied by hand into
    `verification.csv` and `verification_session_info.txt`.
11. The second round followed, in `rerun/`, as described at the end of this file.

## Rebuilding the page

The page is knitted with R 4.6.1 and the packages pinned in `renv.lock` at the root
of the repository.

1. Start R in the root of the repository, which activates renv through `.Rprofile`
   (not with `--vanilla`, which skips it), and run `renv::restore()`.
2. Make pandoc available to rmarkdown. The page was last knitted with pandoc 3.10,
   the version that RStudio ships. Outside RStudio, point the environment variable
   `RSTUDIO_PANDOC` at the folder that holds `pandoc`.
3. Knit the post from the root of the repository:
   `blogdown::build_site(run_hugo = FALSE, build_rmd =
   'content/post/reproducible-research-with-generative-ai/index.en.Rmd')`.
   This takes several minutes, most of them spent executing the first round's 24
   agent scripts.
   Hugo 0.62.0 then builds the site from the knitted `index.en.html`.

The page prints its own `sessionInfo()` at the end of the section *Executing the
Scripts Again*.

## Data (can be run again)

- `spec.json`: the pilotr design specification.
- `make_data.R` writes `data.csv` from it and prints its checksum. Run it from this
  folder in an R session started in the root of the repository, so that renv's
  pilotr is used, for instance `Rscript -e "setwd('content/post/reproducible-research-with-generative-ai/experiment'); source('make_data.R')"`.
- `make_data.py` generates the same data with pilotr for Python and prints the
  checksum kept in `python_sha256.txt`. Install the version it used with
  `python -m pip install -r requirements.txt`, then run `python make_data.py` from
  this folder.
- `make_unbalanced.R` writes `data_unbalanced.csv`, the follow-up data set with 6%
  of the trials removed, in the same way as `make_data.R`.
- Run in this folder, `make_data.R` and `make_unbalanced.R` replace the stored
  files. To check them, run them in a copy of the folder and compare the results
  with `cmp`. Under R 4.6.1 and the pinned pilotr, both data files are regenerated
  byte for byte.
- `SHA256SUMS` lists the SHA-256 checksums of `spec.json`, `data.csv` and
  `data_unbalanced.csv`, which `sha256sum -c SHA256SUMS` checks from this folder.

## Runs of the first round (a record of how they were made)

- `prompts/`: the request texts and the instructions for each route.
- `make_runs.R` and `make_runs_followup.R` laid out the 48 runs in `design.csv`, in
  a random launch order, and wrote each run's prompt to `runs/<run_id>/prompt.txt`.
  They also wrote the agents' working directories under `/home/user/agent_runs`, a
  path that exists only on the machine that ran the experiment.
- Each agent worked in its own directory holding only the data file. The post
  describes the departures. Three script runs wrote exploratory files to the
  session's scratch folder, and one of them also read the output of a background
  command from the session's task folder. The first eight runs started in this
  folder, and their logs show no access to its files. Each agent's final reply,
  and a log of its tool calls with its starting directory and times, were
  extracted from its transcript with `extract_transcripts.py` into
  `runs/<run_id>/response.txt` and `tool_calls.json`.
  The transcripts are not kept, since they also hold the launching session's
  context. Script runs also have `analysis.R`.
- `claude_code_version.txt`: the version of Claude Code that ran the agents of the
  first round.
- `claude_model.txt`: the model the agents ran, Claude Opus 5.5 (`claude-opus-5-5`).
  Each agent ran with the model and effort level of the session that launched it,
  and that session's commits of the experiment (b91841796 and a554ab4b0) name the
  model in their attribution lines. The session's effort level was not recorded.

## Executions

- `run_script.R` executes one agent script in a fresh R process in the C locale,
  with no R profile, in a fresh copy of its directory. It returns the exit status,
  the RESULT line and a SHA-256 hash of the full output. The hash is taken over the
  lines of the output as `readLines()` returns them, joined by `\n` with no final
  newline, so it does not depend on the line endings a system writes and differs
  from a checksum of the output file. A script still running after ten minutes
  stops the execution with an error. `run_script_with_retries()` executes a script
  again when its R process crashes, which on Windows happens occasionally.
- `execute_scripts.R` executed every script of the first round three times in the
  environment of that round and wrote `executions.csv`, with
  `executions_session_info.txt`. It is kept as a record, since running it again
  replaces both files with the executions of the current environment. To check the
  stored executions, use `verify_executions.R`.
- `executions_session_info.txt` describes the R session that launched the
  executions. The scripts themselves ran in the C locale, as the `environment`
  column of `executions.csv` records.
- The stored executions were made with `run_script.R` as of commit a554ab4b0. Its
  version of 30 September 2026, which adds the choice of library, skips the R
  profile and executes a crashed script again, reproduced the same hashes in the
  rebuilt environment (`verification.csv`).
- `collect_results.R` combines the design, replies, executions and tool logs into
  `results.csv`, and flags every run that touched a path outside its own directory.
- `choices_open_scripts.csv` records, for each of the eight scripts written for the
  open request, the random effects of the model whose result the script prints,
  whether that model includes word frequency as a covariate, the interval method,
  any transformation of the response times and any exclusions. No script writes it.

## Rebuilding the environment of the first round's executions

The first round's stored executions ran under R 4.3.3 on Ubuntu 24.04, with lme4
1.1-35.1,
lmerTest 3.1-3 and Matrix 1.6-5, and Ubuntu 24.04 still provides these versions.

- `Dockerfile` rebuilds that environment from the Ubuntu packages, resolving every
  package against Ubuntu's snapshot of the archive at 20:00 UTC on 30 September
  2026, just before the recorded build, and pinning R and the packages that the
  scripts and `verify_executions.R` load by version as well.
  `verification_session_info.txt` lists the package versions of the recorded
  build. `docker build -t genai-experiment .`
  followed by `docker run --rm genai-experiment` executes every script in it and
  compares each output with `executions.csv`, through `verify_executions.R`.
- Given a file name, `verify_executions.R` also writes the comparison there, and
  the session to the same name with `_session_info.txt` in place of `.csv`. When
  the variables `GITHUB_SERVER_URL`, `GITHUB_REPOSITORY` and `GITHUB_RUN_ID` are
  set, it records the address of the workflow run too.
- The workflow `.github/workflows/reproduce-genai-experiment.yml` does the same on
  GitHub Actions whenever these files change and on the first day of each month.
  It takes about two minutes. `verification.csv` is the comparison from one of its
  runs, whose address it records, and `verification_session_info.txt` holds the
  session and the Ubuntu package versions of the rebuilt environment.

## Locating what changed the output

- `check_versions.R` executes every script on one machine with three package
  libraries that differ only in the versions of lme4 and lmerTest: the site's renv
  library, the same with lme4 1.1-35.1, and the same with lmerTest 3.1-3 as well.
  It builds those two versions from the CRAN archive, which needs a compiler (Rtools
  on Windows). The environment variable `STORED_LIBS` can name a folder that
  already holds them. Run it from the root of the repository:
  `Rscript content/post/reproducible-research-with-generative-ai/experiment/check_versions.R`.
  It deletes and replaces `outputs/`, `version_check.csv` and
  `version_check_session_info.txt` in the folder that holds it. To compare its
  results with the stored ones, copy this folder elsewhere and, from the root of
  the repository, run `Rscript <copy>/check_versions.R`.
- It writes `version_check.csv`, with one row per execution and the versions of the
  packages the scripts load. For the last attempt at each script, its column
  `trimmed_sha256` holds a hash of the output with the spaces at the ends of lines
  removed, which the post does not use. It also writes
  `version_check_session_info.txt`, with the session of a child process in each
  library, and the full output of every script in
  `outputs/<library>/<run_id>.txt`. The outputs in `outputs/stored-lme4/` and
  `outputs/stored-lme4-lmertest/` reproduce the hashes in `executions.csv`, so they
  are also the text of the stored executions.

## The second round

The folder `rerun/` holds the second round, in which the 48 runs were made again on
11 October 2026 with the effort level set to medium.

- The runs were launched as background agents of one Claude Code session in the
  Claude desktop app on Windows 11, in the order of `design.csv` and in batches of
  eight, those on the unbalanced data once most runs on the balanced data had
  finished. Each prompt is that of the first round with three substitutions: the
  run's folder for `/home/user/agent_runs/<run_id>` and, in the script route,
  `R 4.6.1` for `R 4.3` and the full path of `Rscript.exe` for `Rscript`. The effort
  level was set explicitly to medium on every agent. The transcripts record medium
  on every turn, the model `claude-opus-5-5` on every request and Claude Code
  2.1.295.
- Two runs, the prose reply `b42ac192` (specified request, balanced data) and the
  script `9d94880d` (open request, balanced data), were also run at xhigh effort
  on the same day, with the same substitutions in their prompts. They were made
  first, between 11:34 and 11:45 UTC, two at a time and in folders of their own.
- The agents ran their scripts under R 4.6.1 with lme4 2.0-1, lmerTest 3.2-1 and
  Matrix 1.7-5. No agent's tool calls named a path outside its own run folder,
  apart from that of the R program.
- `rerun/results.csv` has one row per run: the round (`medium` for the 48 runs and
  `xhigh` for the two), the run's design and launch order, the effort level, model
  and version of Claude Code that its transcript records, its start and finish
  times, its minutes from request to final reply and seconds of thinking, its
  number of tool calls, whether it stayed in its folder, the tokens of its last
  request and its result line. Its minutes run from the first to the last time
  stamp of its transcript, and its seconds of thinking (`thinking_seconds`) add up
  the thinking times that the transcript records. A run stayed in its folder
  (`compliant`) when every tool call's input named that folder. The tokens of its
  last request (`total_tokens_last_request`) are the total that the launching
  session recorded for the agent when it finished.
- `rerun/scripts/` holds two scripts that rebuild the second round's records. They
  were rewritten from the working scripts of 11 October 2026 so that every private
  input is a command-line argument. The docstring of `build_records.py` lists where
  it differs from those scripts, and none of the differences changes a stored byte.
  The scripts need Python 3.11 or later and only its standard library, and were run
  with `python -I`. Neither overwrites a file. `build_records.py` writes only into a
  new or empty folder, and `prepare_runs.py` only into new or empty run and prompt
  folders, so neither can replace the stored files.
- `rerun/scripts/prepare_runs.py` makes each run's folder, holding only its data
  file saved as `data.csv`. It writes the run's prompt, with the three substitutions
  above, to `<prompts>/<run_id>/prompt.txt`. It lists each run's order, condition,
  data file and folder in `<prompts>/plan.csv`. Its arguments are:
  - the experiment folder (`--experiment`);
  - the folder in which to make the run folders (`--runs`);
  - the folder for the prompts (`--prompts`), which must lie outside the runs folder;
  - the version of R and the full path of `Rscript` that the script prompts name
    (`--r-version`, `--rscript`);
  - optionally, a suffix for the folders' names (`--suffix`) and the runs to prepare
    (`--run-ids`).

  The second round used R 4.6.1 and `C:/Program Files/R/R-4.6.1/bin/Rscript.exe`.
  Its run folders, and those of the two runs at xhigh effort (`--run-ids b42ac192
  9d94880d`, with a suffix of their own), were in the Windows user's temporary
  folder.
- `rerun/scripts/build_records.py` writes `results.csv` and `runs/` into a new or
  empty folder (`--output`). It reads these private records:
  - the medium-effort agents' transcripts (`--transcripts`);
  - a CSV that pairs each run with its agent (`--agents`);
  - a CSV of the token totals that the launching session reported (`--token-totals`);
  - the records of the two xhigh runs, each with its transcript and a `summary.json`
    that holds its token total (`--xhigh-records`);
  - the folders in which each round's agents worked, given as the agents saw them
    (`--medium-runs`, `--xhigh-runs`), and the suffix of the xhigh runs' folders
    (`--xhigh-suffix`).

  It rebuilds each prompt with the code of `prepare_runs.py`, from `--experiment`,
  `--r-version` and `--rscript`. It stops unless that prompt is the first message of
  the agent's transcript. It takes the final reply from the agent's last hand-back.
  The tool calls, times, thinking time, effort, model and Claude Code version come
  from the transcript, and `analysis.R` is copied unchanged from the run's folder.
  The outputs are redacted as described below. If an output still names the user,
  another Windows user's folder or a run folder other than the run's own, the script
  stops without writing anything. `--home` names the home folder whose name is
  redacted, and defaults to that of the user running the script.
- Run with the private records on 12 October 2026, `build_records.py` wrote
  `results.csv` and the 175 files under `runs/` byte for byte as they are stored.
  `prepare_runs.py`, run into a scratch folder, wrote prompts equal to the stored
  `prompt.txt` of all 50 runs once their folder was written as `<run folder>`. To
  repeat the check, run `build_records.py` into a new folder and compare it with
  `rerun/`, for instance with `diff -r` and `cmp`. On Windows, keep the new folder's
  path short. The longest file the script writes adds 37 characters to it, and
  Windows refuses a path of 260 characters or more unless long paths are enabled.
  The files under `runs/` are stored with `\n` line endings. Unlike the CSV files,
  they have no `-text` rule in `.gitattributes`, so a Windows checkout with
  `core.autocrlf` set turns them into `\r\n`. On Windows, therefore, compare with
  the committed files or in a checkout without that conversion.
- `rerun/runs/<round>/<run_id>/` holds the prompt as sent (`prompt.txt`), the final
  reply (`response.txt`), every tool call's input with the run's start and finish
  times (`tool_calls.json`) and, for script runs, `analysis.R`.
- As in the first round, the transcripts are not kept, since they hold the
  launching session's context. In the stored files, each run's own folder is
  written as `<run folder>` and the Windows user name in any other path as
  `<user>`. In `tool_calls.json`, every backslash is also written as `/`, so
  escapes such as `\n` in commands appear as `/n`.
- `rerun/execute_rerun.R` executes each of the 25 scripts twice with
  `run_script.R`, each time in a fresh R process in the C locale and a fresh copy
  of its folder, and writes `rerun/executions.csv` and
  `rerun/executions_session_info.txt`. A script whose R process crashed would have
  been executed again, with only its last attempt kept, but none crashed.
- `rerun/executions_session_info.txt` describes the R session that launched the
  executions. The scripts themselves ran in the C locale, as the `environment`
  column of `rerun/executions.csv` records.
- The stored executions ran in the R library the agents used, that of R 4.6.1
  started without a project profile. `rerun/library.lock`, taken from that library
  on 11 October 2026, records the versions of R, of the packages that the scripts
  and `run_script.R` load, and of their dependencies. It is an renv lockfile, which
  `renv::restore()` takes as its `lockfile` argument, with a new folder as
  `library`. Restoring a library from it has not been tested.
- To execute the scripts again in the same way, run
  `Rscript --no-init-file execute_rerun.R` from `rerun/` in a copy of the whole
  experiment folder, since it replaces both files. In the stored executions, every
  script printed identical output both times, ending with the result line its
  agent reported.
