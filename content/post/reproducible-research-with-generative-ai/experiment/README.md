# Experiment files

The data, prompts, agent outputs, scripts and records behind the post *Forty-eight
answers to one question: Reproducible research with generative AI*. The post reads
these files, and it executes every agent-written script again when it is knitted.

The files fall into three groups: scripts that can be run again, scripts kept as a
record of how the stored files were made, and the records themselves.

## Rebuilding the page

The page is knitted with R 4.6.1 and the packages pinned in `renv.lock` at the root
of the repository.

1. Start R in the root of the repository, which activates renv through `.Rprofile`
   (not with `--vanilla`, which skips it), and run `renv::restore()`.
2. Make pandoc available to rmarkdown. The page was last knitted with pandoc 3.10,
   the version that RStudio ships; outside RStudio, point the environment variable
   `RSTUDIO_PANDOC` at the folder that holds `pandoc`.
3. Knit the post from the root of the repository:
   `blogdown::build_site(run_hugo = FALSE, build_rmd = 'content/post/reproducible-research-with-generative-ai/index.en.Rmd')`.
   This takes several minutes, most of them spent executing the 24 agent scripts.
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

## Runs (a record of how they were made)

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
- `claude_code_version.txt`: the version of Claude Code that ran the agents.
- `claude_model.txt`: the model the agents ran, Claude Opus 5.5 (`claude-opus-5-5`).
  Each agent ran with the model of the session that launched it, and that session's
  commits of the experiment (b91841796 and a554ab4b0) name the model in their
  attribution lines. The session's setting for the model's reasoning was not
  recorded.

## Executions

- `run_script.R` executes one agent script in a fresh R process in the C locale,
  with no R profile, in a fresh copy of its directory. It returns the exit status,
  the RESULT line and a SHA-256 hash of the full output. The hash is taken over the
  lines of the output as `readLines()` returns them, joined by `\n` with no final
  newline, so it does not depend on the line endings a system writes and differs
  from a checksum of the output file. `run_script_with_retries()` executes a script
  again when its R process crashes, which on Windows happens occasionally.
- `execute_scripts.R` executed every script three times in the environment of the
  experiment and wrote `executions.csv`, with `executions_session_info.txt`. It is
  kept as a record: running it again replaces both files with the executions of the
  current environment. To check the stored executions, use `verify_executions.R`.
- `collect_results.R` combines the design, replies, executions and tool logs into
  `results.csv`, and flags every run that touched a path outside its own directory.
- `choices_open_scripts.csv` records the analytic choices of the eight scripts
  written for the open request.

## Rebuilding the environment of the stored executions

The stored executions ran under R 4.3.3 on Ubuntu 24.04, with lme4 1.1-35.1,
lmerTest 3.1-3 and Matrix 1.6-5, and Ubuntu 24.04 still provides these versions.

- `Dockerfile` rebuilds that environment from the Ubuntu packages, with every
  version pinned. `docker build -t genai-experiment .` followed by
  `docker run --rm genai-experiment` executes every script in it and compares each
  output with `executions.csv`, through `verify_executions.R`.
- The workflow `.github/workflows/reproduce-genai-experiment.yml` does the same on
  GitHub Actions whenever these files change. `verification.csv` is the comparison
  from one of its runs, whose address it records, and
  `verification_session_info.txt` holds the session and the Ubuntu package versions
  of the rebuilt environment.

## Locating what changed the output

- `check_versions.R` executes every script on one machine with three package
  libraries that differ only in the versions of lme4 and lmerTest: the site's renv
  library, the same with lme4 1.1-35.1, and the same with lmerTest 3.1-3 as well.
  It builds those two versions from the CRAN archive, which needs a compiler (Rtools
  on Windows); the environment variable `STORED_LIBS` can name a folder that already
  holds them. Run it from the root of the repository:
  `Rscript content/post/reproducible-research-with-generative-ai/experiment/check_versions.R`.
- It writes `version_check.csv`, with one row per execution and the versions of the
  packages the scripts load. For the last attempt at each script, its column
  `trimmed_sha256` holds a hash of the output with the spaces at the ends of lines
  removed, which the post does not use. It also writes
  `version_check_session_info.txt`, with the session of a child process in each
  library, and the full output of every script in
  `outputs/<library>/<run_id>.txt`. The outputs in `outputs/stored-lme4/` and
  `outputs/stored-lme4-lmertest/` reproduce the hashes in `executions.csv`, so they
  are also the text of the stored executions.
