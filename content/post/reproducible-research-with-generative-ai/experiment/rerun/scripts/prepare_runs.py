"""Make the run folders and prompts of the experiment's second round.

Purpose
    In the second round, each run of the first round was made again by a
    Claude Code agent on Windows. Each agent worked in a folder of its own
    that held only its data file, saved as data.csv, and was sent the first
    round's prompt with the substitutions that describe the machine it ran on:

    - the run's folder for /home/user/agent_runs/<run_id>, in every prompt;
    - 'R <version> is installed' for 'R 4.3 is installed', in script prompts;
    - the quoted full path of Rscript for 'Rscript' in '(Rscript analysis.R)',
      in script prompts, since Rscript is not on the PATH under Windows.

    This script makes those folders and writes those prompts. The agents were
    then launched from one Claude Code session, which sent each one its
    prompt, as the experiment's README describes.

Inputs
    --experiment  the experiment folder, with design.csv, data.csv,
                  data_unbalanced.csv and the first round's
                  runs/<run_id>/prompt.txt
    --runs        the folder in which to make the run folders. The prompts
                  name each run's folder by its absolute path, so this must
                  be where the agents will work.
    --prompts     the folder in which to write the prompts
    --r-version   the version of R that the script prompts name
    --rscript     the full path of Rscript that the script prompts name
    --suffix      text appended to each run folder's name (optional)
    --run-ids     the runs to prepare (optional, default every run in
                  design.csv)

Outputs
    <runs>/<run_id><suffix>/data.csv   the run's data file
    <prompts>/<run_id>/prompt.txt      the prompt for the run's agent
    <prompts>/plan.csv                 each run's launch order, condition,
                                       data file and folder

    The script refuses to write into a run folder or a prompts folder that is
    not empty, so that it can never overwrite an agent's work, and it refuses
    a prompts folder that is the runs folder, lies inside it or holds it.

Usage
    With the values of the second round, the 48 runs at medium effort are
    prepared with

        python -I prepare_runs.py --experiment <experiment folder>
            --runs <medium run folders> --prompts <prompts folder>
            --r-version 4.6.1 --rscript "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"

    and the two runs at xhigh effort with the same R version and Rscript and

            --runs <xhigh run folders> --suffix=<suffix>
            --run-ids b42ac192 9d94880d

    with folders of their own in the Windows user's temporary folder. A
    suffix that starts with a hyphen is given with '='. build_records.py
    imports make_prompt() from this file to rebuild the same prompts.
"""
import argparse
import csv
import os
import shutil
import sys
from pathlib import Path

# The first round's text that each substitution replaces. The run folder's
# text depends on the run, so it is built in make_prompt().
FIRST_ROUND_FOLDER = '/home/user/agent_runs/{run_id}'
FIRST_ROUND_R = 'R 4.3 is installed'
FIRST_ROUND_RSCRIPT = '(Rscript analysis.R)'


def folder_path(path):
    """Return a folder's absolute path written with forward slashes.

    The prompts name the run folders in this form, and the transcripts are
    compared with it, so that the same folder is always the same text.
    os.path.abspath() is used because, unlike Path.resolve(), it keeps the
    letter case and the short names of the path as given.
    """
    return os.path.abspath(path).replace('\\', '/')


def refuse_unless_empty(path):
    """Stop when a path exists and is not an empty folder.

    This keeps the scripts from ever overwriting a stored record or an
    agent's work.
    """
    folder = Path(path)
    if folder.exists() and (not folder.is_dir() or any(folder.iterdir())):
        sys.exit(f'Refusing to write into {folder}: it is not an empty folder.')


def same_or_nested(first, second):
    """Return whether two folders are the same or one lies inside the other.

    The paths are compared as the system does, so that on Windows two
    spellings of one folder that differ only in case or separators match.
    """
    first, second = (os.path.normcase(os.path.abspath(path)) for path in (first, second))
    try:
        return os.path.commonpath([first, second]) in (first, second)
    except ValueError:
        # Folders on different drives share no path
        return False


def write_failed(error, left_over):
    """Return the message for a file or folder that could not be written.

    left_over says what was written before the failure and must be removed.
    The likeliest cause is Windows' limit of 259 characters on a path, which
    holds unless long paths are enabled and which a deep output folder can
    reach. The message says so, since the error alone does not.
    """
    return (f'{error}\nWindows refuses a path of 260 characters or more unless long paths are enabled, '
            f'so a shorter folder may help. Remove {left_over} before trying again.')


def ensure_empty_folder(path):
    """Create a folder, or accept an existing one only if it is empty."""
    refuse_unless_empty(path)
    Path(path).mkdir(parents=True, exist_ok=True)


def read_design(experiment):
    """Return the rows of design.csv, in launch order."""
    with open(Path(experiment, 'design.csv'), encoding='utf-8', newline='') as f:
        rows = list(csv.DictReader(f))
    return sorted(rows, key=lambda row: int(row['order']))


def data_file_for(data):
    """Return the name of the data file that a run's data condition used."""
    return 'data_unbalanced.csv' if data == 'unbalanced' else 'data.csv'


def read_first_round_prompt(experiment, run_id):
    r"""Return the first round's prompt of a run, with \n line endings.

    The file is read in text mode, which turns \r\n into \n, because a
    Windows checkout of the repository may hold it with \r\n endings, and
    the prompts of the second round were written and sent with \n.
    """
    with open(Path(experiment, 'runs', run_id, 'prompt.txt'), encoding='utf-8') as f:
        return f.read()


def make_prompt(original, run_id, route, run_folder, r_version, rscript):
    """Return a first-round prompt adapted to the run's folder and machine.

    original is the first round's prompt, run_folder the run's folder as
    folder_path() writes it, and route 'prose' or 'script'. The substitutions
    are applied in the order in which the second round applied them. Raises
    ValueError when a prompt lacks the text a substitution replaces, since
    the prompt would then not describe the machine the agent ran on.
    """
    substitutions = [(FIRST_ROUND_FOLDER.format(run_id=run_id), run_folder)]
    if route == 'script':
        substitutions += [(FIRST_ROUND_R, f'R {r_version} is installed'),
                          (FIRST_ROUND_RSCRIPT, f'("{rscript}" analysis.R)')]
    prompt = original
    for old, new in substitutions:
        if old not in prompt:
            raise ValueError(f'The prompt of run {run_id} does not contain {old!r}.')
        prompt = prompt.replace(old, new)
    return prompt


def parse_args(argv):
    """Parse the command line."""
    parser = argparse.ArgumentParser(
        description="Make the second round's run folders and prompts.")
    parser.add_argument('--experiment', required=True, help='the experiment folder')
    parser.add_argument('--runs', required=True, help='the folder in which to make the run folders')
    parser.add_argument('--prompts', required=True, help='the folder in which to write the prompts')
    parser.add_argument('--r-version', required=True, help='the version of R the script prompts name')
    parser.add_argument('--rscript', required=True, help='the full path of Rscript the script prompts name')
    parser.add_argument('--suffix', default='', help="text appended to each run folder's name")
    parser.add_argument('--run-ids', nargs='+', help='the runs to prepare (default: all)')
    return parser.parse_args(argv)


def main(argv=None):
    """Prepare every run, check its folders, then write them."""
    args = parse_args(argv)
    design = read_design(args.experiment)
    if args.run_ids:
        unknown = set(args.run_ids) - {row['run_id'] for row in design}
        if unknown:
            sys.exit(f'Not in design.csv: {", ".join(sorted(unknown))}')
        design = [row for row in design if row['run_id'] in args.run_ids]

    runs = folder_path(args.runs)
    # A run folder must hold only its data file, so the prompts are kept out
    # of the runs folder, where an agent could come across them. Kept apart,
    # a prompt folder and a run folder can also never be the same folder.
    if same_or_nested(args.prompts, runs):
        sys.exit('The prompts folder must not be the runs folder, lie inside it or hold it.')
    # Every prompt is made and every folder checked before anything is
    # written, so that a prompt that cannot be adapted or a folder in use
    # leaves no half-prepared runs behind
    prepared = []
    for row in design:
        run_folder = f'{runs}/{row["run_id"]}{args.suffix}'
        prompt = make_prompt(read_first_round_prompt(args.experiment, row['run_id']),
                             row['run_id'], row['route'], run_folder, args.r_version, args.rscript)
        prepared.append((row, run_folder, prompt))
    for target in [args.prompts] + [run_folder for _, run_folder, _ in prepared]:
        refuse_unless_empty(target)

    try:
        write_runs(prepared, args.experiment, args.prompts)
    except OSError as error:
        sys.exit(write_failed(error, f'{args.prompts} and the run folders made in {runs}'))
    print(f'Prepared {len(prepared)} runs in {runs}.')


def write_runs(prepared, experiment, prompts):
    """Make the run folders and write the prompts and the plan.

    prepared holds each run's design row, folder and prompt, as main() made
    them, and the folders have been checked to be new or empty.
    """
    ensure_empty_folder(prompts)
    plan = []
    for row, run_folder, prompt in prepared:
        ensure_empty_folder(run_folder)
        # Each agent found its data as data.csv, as in the first round
        shutil.copyfile(Path(experiment, data_file_for(row['data'])), Path(run_folder, 'data.csv'))
        Path(prompts, row['run_id']).mkdir()
        with open(Path(prompts, row['run_id'], 'prompt.txt'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(prompt)
        plan.append({'order': row['order'], 'run_id': row['run_id'], 'route': row['route'],
                     'request': row['request'], 'data': row['data'],
                     'data_file': data_file_for(row['data']), 'run_folder': run_folder})

    with open(Path(prompts, 'plan.csv'), 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(plan[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(plan)


if __name__ == '__main__':
    main()
