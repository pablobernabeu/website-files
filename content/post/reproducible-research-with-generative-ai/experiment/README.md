# Experiment files

The data, prompts, agent outputs and scripts behind the post *Forty-eight answers
to one question: Reproducible research with generative AI*. The post reads these
files and re-executes every agent-written script when it is built.

## Data

- `spec.json`: the pilotr design specification.
- `make_data.R` writes `data.csv` from it. `make_data.py` generates the same data
  with pilotr for Python and prints the checksum kept in `python_sha256.txt`.
- `make_unbalanced.R` writes `data_unbalanced.csv`, the follow-up data set with
  6% of the trials removed.

## Runs

- `prompts/`: the request texts and the instructions for each route.
- `make_runs.R` and `make_runs_followup.R` lay out the 48 runs in `design.csv`,
  in a random launch order, and write each run's prompt to `runs/<run_id>/prompt.txt`.
- Each agent worked in its own directory holding only the data file. Its final
  reply and a log of its tool calls, extracted from its transcript with
  `extract_transcripts.py`, are in `runs/<run_id>/response.txt` and
  `tool_calls.json`. Script runs also have `analysis.R`.
- `claude_code_version.txt`: the version of Claude Code that ran the agents.

## Analysis

- `run_script.R` executes one agent script in a fresh R process.
- `execute_scripts.R` executes every script three times and writes
  `executions.csv`, with `executions_session_info.txt`.
- `collect_results.R` combines the design, replies, executions and tool logs
  into `results.csv`.
- `choices_open_scripts.csv` records, from reading each script, the analytic
  choices of the eight scripts written for the open request.
