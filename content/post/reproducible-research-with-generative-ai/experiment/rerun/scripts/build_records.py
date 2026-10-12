"""Build the stored records of the experiment's second round.

Purpose
    Writes the second round's results.csv and runs/<round>/<run_id>/ from the
    private records of its agents, with the redactions of the copies kept in
    rerun/. It gathers into one script what the working scripts of
    11 October 2026 did in several steps, so that anyone who holds the
    private records can rebuild the stored ones and compare them byte for
    byte.

Inputs (private, not kept in the repository)
    --experiment     the experiment folder: design.csv and the first round's
                     runs/<run_id>/prompt.txt
    --transcripts    the folder of the medium-effort agents' transcripts,
                     agent-<agent_id>.jsonl, which Claude Code wrote in the
                     launching session's subagents/ folder. They are private
                     because they also hold that session's context.
    --agents         a CSV with the columns run_id and agent_id, which pairs
                     each medium-effort run with its agent
    --token-totals   a CSV with the columns run_id and total_tokens: the total
                     tokens of each medium-effort agent's last request, as the
                     launching session reported them when the agent finished.
                     The transcripts do not record this total.
    --medium-runs    the folder of the medium-effort run folders, as the
                     agents saw it (the --runs of prepare_runs.py)
    --xhigh-records  the folder of the xhigh-effort runs' records, one
                     <run_id><suffix>/ per run with the agent's
                     transcript.jsonl and a summary.json whose
                     summary.total_tokens_last_request holds the total that
                     the launching session reported
    --xhigh-runs     the folder of the xhigh-effort run folders, as the agents
                     saw it
    --xhigh-suffix   the suffix of the xhigh-effort folders' names, as given
                     to prepare_runs.py
    --r-version, --rscript
                     the values given to prepare_runs.py, which rebuild the
                     prompts as they were sent
    --home           the home folder whose name is redacted (default: the
                     current user's)
    --output         a new or empty folder to write into

Outputs
    <output>/results.csv
        one row per run: the 48 medium-effort runs in launch order, then the
        xhigh-effort runs in launch order
    <output>/runs/<round>/<run_id>/
        prompt.txt       the prompt as prepared by prepare_runs.py
        response.txt     the agent's final reply
        tool_calls.json  the input of every tool call, and the first and last
                         time stamps of the transcript
        analysis.R       the script the agent left in its folder, if any

    In prompt.txt, response.txt and tool_calls.json, every backslash is
    written as '/', the home folder as C:/Users/<user> and the run's own
    folder as '<run folder>'. analysis.R is copied unchanged. The script
    stops without writing anything if an output would still name the user,
    another Windows user folder or a run folder other than the run's own,
    and it refuses to write into a folder that is not empty.

Differences from the working scripts
    The working scripts of 11 October 2026 are not kept, since they name
    local paths. This script differs from them in the following ways, and
    still writes every stored file byte for byte:

    - a tool call counts as staying in the run's folder when its input names
      the folder's full path, as the README defines it. The working script
      looked for the shorter '/runs/<run_id>';
    - thinking time is summed in milliseconds, as the transcripts record it.
      For the medium-effort runs, the working script summed seconds;
    - the prompts are rebuilt by prepare_runs.py, and analysis.R is read
      from the run's folder, where the working scripts read the copies saved
      when the runs were prepared and collected;
    - only the run's own folder is written '<run folder>', where the working
      script's second pass replaced any run's folder. The check above makes
      sure that no other run's folder is left.

Usage
    python -I build_records.py --experiment <experiment folder>
        --transcripts <session folder>/subagents --agents agents.csv
        --token-totals notification_usage.csv
        --medium-runs <medium run folders>
        --xhigh-records <xhigh records> --xhigh-runs <xhigh run folders>
        --xhigh-suffix=<suffix>
        --r-version 4.6.1 --rscript "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"
        --output <new folder>

    Then compare the new folder with rerun/, for instance with
    diff -r <new folder>/runs rerun/runs and cmp on results.csv.
"""
import argparse
import csv
import datetime as dt
import importlib.util
import io
import json
import re
import sys
from pathlib import Path

RUN_FOLDER = '<run folder>'
USER = '<user>'
# A Windows user's folder, written C:/Users/<name> or, as in Git Bash,
# /c/Users/<name>. The placeholder <user> cannot match, since the name may
# not hold '<'.
USER_FOLDER = re.compile(r'(?:\b[a-z]:|/[a-z])/users/[^/\s"\'`<>]+', re.IGNORECASE)
RESULT_LINE = re.compile(r'RESULT estimate=-?[0-9.]+ lower=-?[0-9.]+ upper=-?[0-9.]+')
RESULT_NUMBERS = re.compile(r'estimate=(-?[0-9.]+) lower=(-?[0-9.]+) upper=(-?[0-9.]+)')
HANDBACK = 'SubagentHandback'
FIELDS = ['round', 'run_id', 'order', 'route', 'request', 'data', 'effort', 'model',
          'claude_code_version', 'started', 'finished', 'minutes', 'thinking_seconds', 'tool_calls',
          'compliant', 'total_tokens_last_request', 'result_line', 'estimate', 'lower', 'upper']


def load_prepare_runs():
    """Import prepare_runs.py from the folder of this script.

    python -I leaves the script's folder off the module search path, so the
    module is loaded from its file. It is shared so that the prompts are
    rebuilt by the code that made them. Python would otherwise cache the
    compiled module in a __pycache__ folder beside it, that is, inside the
    experiment folder, which this script must not write into.
    """
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(
        'prepare_runs', Path(__file__).resolve().with_name('prepare_runs.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prepare_runs = load_prepare_runs()


class Redactor:
    """The redactions of the stored records, and a check that they held."""

    def __init__(self, home, run_roots):
        """Set up the redactions for a home folder and the runs' folders.

        home is the home folder whose name is redacted, and run_roots the
        folders that hold the run folders, as the agents saw them.
        """
        home = prepare_runs.folder_path(home)
        parent, self.user_name = home.rsplit('/', 1)
        self._home = re.compile(re.escape(home + '/'), re.IGNORECASE)
        self._home_redacted = f'{parent}/{USER}/'
        self._run_roots = [self.clean(prepare_runs.folder_path(root)) for root in run_roots]

    def clean(self, text):
        r"""Write every backslash as '/' and the home folder as <user>.

        Windows paths reach the transcripts with single backslashes or,
        inside JSON and shell strings, with escaped double ones. Both are
        read as one separator, so that each path is written one way. As in
        the working scripts, this also turns escapes such as \n in commands
        into /n.
        """
        text = text.replace('\\\\', '/').replace('\\', '/')
        return self._home.sub(lambda match: self._home_redacted, text)

    def clean_obj(self, value):
        """Apply clean() to every string in a JSON value, leaving keys as they are."""
        if isinstance(value, str):
            return self.clean(value)
        if isinstance(value, list):
            return [self.clean_obj(item) for item in value]
        if isinstance(value, dict):
            return {key: self.clean_obj(item) for key, item in value.items()}
        return value

    def redact_run_folder(self, text, run_folder):
        """Write a run's own folder as '<run folder>' in text already cleaned."""
        return re.sub(re.escape(self.clean(run_folder)), RUN_FOLDER, text, flags=re.IGNORECASE)

    def check(self, name, text):
        """Stop if an output still names the user or a run folder not its own.

        The placeholder <user> is removed first, so that a user name that
        happens to be 'user' is not found in it. Any other Windows user's
        folder also stops the build, since it would show that --home is not
        the folder the agents worked under, so that the redaction missed.
        """
        if re.search(re.escape(self.user_name), text.replace(USER, ''), re.IGNORECASE):
            sys.exit(f'{name} still names the user {self.user_name!r}. Nothing was written.')
        found = USER_FOLDER.search(text)
        if found:
            sys.exit(f'{name} names the user folder {found.group()!r}. Is --home the home folder of the '
                     f'user the agents ran as? Nothing was written.')
        for root in self._run_roots:
            if re.search(re.escape(root), text, re.IGNORECASE):
                sys.exit(f'{name} names a path in {root} other than its own run folder. Nothing was written.')


def read_transcript(path):
    """Return what the stored records take from an agent's transcript.

    The transcript is Claude Code's JSON Lines record of the agent. The
    returned dict holds the text of its first user message (the prompt it
    received), the time stamps of its records, the effort levels, Claude
    Code versions and models that its records name, its total thinking time
    in milliseconds, its tool calls other than the hand-back and the message
    of its last hand-back, which is its final reply.
    """
    first_message, stamps, calls, reply = None, [], [], None
    settings = {'effort': set(), 'perTurnEffort': set(), 'version': set(), 'model': set()}
    thinking_ms = 0
    # errors='replace', as in the working scripts, so that a stray byte in a
    # tool's output cannot stop the build
    with open(path, encoding='utf-8', errors='replace') as f:
        for line in f:
            if not line.strip():
                continue
            record = json.loads(line)
            if record.get('timestamp'):
                stamps.append(record['timestamp'])
            for key in ('effort', 'perTurnEffort', 'version'):
                if record.get(key) is not None:
                    settings[key].add(str(record[key]))
            thinking_ms += record.get('thinkingDurationMs') or 0
            message = record.get('message')
            if not isinstance(message, dict):
                continue
            if record.get('type') == 'user' and first_message is None:
                content = message.get('content')
                first_message = content if isinstance(content, str) else ''.join(
                    block.get('text', '') for block in content
                    if isinstance(block, dict) and block.get('type') == 'text')
            if record.get('type') != 'assistant':
                continue
            if message.get('model'):
                settings['model'].add(message['model'])
            for block in message.get('content') or []:
                if not (isinstance(block, dict) and block.get('type') == 'tool_use'):
                    continue
                # The agents return their final reply through the hand-back
                # tool, which is not counted as a tool call of the run
                if block['name'] == HANDBACK:
                    reply = (block.get('input') or {}).get('message', '')
                else:
                    calls.append({'tool': block['name'], 'input': block.get('input')})
    return {'first_message': first_message, 'stamps': stamps, 'settings': settings,
            'thinking_ms': thinking_ms, 'calls': calls, 'reply': reply}


def only_value(values, what, run):
    """Return the one value of a set, and stop if it holds none or several."""
    if len(values) != 1:
        sys.exit(f'Run {run}: expected one {what} in the transcript, found {sorted(values)}.')
    return next(iter(values))


def build_run(round_name, design_row, transcript_path, run_folder, prompt, total_tokens, redactor):
    """Return the files of one run's record and its row of results.csv.

    run_folder is the run's folder as the agent saw it, and prompt the
    prompt as prepare_runs.py made it. The files are returned as a dict from
    their path, relative to the output folder, to their bytes.
    """
    run_id = design_row['run_id']
    transcript = read_transcript(transcript_path)
    # The medium-effort agents were sent the prompt without its final
    # newline, so the two are compared without the white space at their ends
    if (transcript['first_message'] or '').strip() != prompt.strip():
        sys.exit(f'Run {run_id}: the first message of its transcript is not the prompt rebuilt from '
                 f'--experiment, --r-version, --rscript and its folder {run_folder}. Are these the '
                 f'values used to prepare the run, with the folder as the agent saw it?')
    if transcript['reply'] is None:
        sys.exit(f'Run {run_id}: its transcript has no final reply.')

    settings = transcript['settings']
    # Claude Code records the effort of each turn (perTurnEffort) and that of
    # the session (effort). The first is what the agent ran at.
    effort = only_value(settings['perTurnEffort'] or settings['effort'], 'effort level', run_id)
    if effort != round_name:
        sys.exit(f'Run {run_id}: its transcript records effort {effort}, not {round_name}.')

    times = {stamp: dt.datetime.fromisoformat(stamp) for stamp in transcript['stamps']}
    first, last = min(times, key=times.get), max(times, key=times.get)

    reply = redactor.clean(transcript['reply'])
    result_lines = RESULT_LINE.findall(reply)
    if not result_lines:
        sys.exit(f'Run {run_id}: its reply has no RESULT line.')
    estimate, lower, upper = RESULT_NUMBERS.search(result_lines[-1]).groups()

    calls = redactor.clean_obj(transcript['calls'])
    # A run stayed in its folder when every call's input names that folder,
    # which can be checked in the stored tool_calls.json, where the folder
    # is written <run folder>
    compliant = all(RUN_FOLDER in redactor.redact_run_folder(json.dumps(call['input'], ensure_ascii=False),
                                                            run_folder)
                    for call in calls)
    tool_log = json.dumps({'started': first, 'finished': last, 'calls': calls}, indent=1, ensure_ascii=False)

    folder = f'runs/{round_name}/{run_id}'
    files = {
        f'{folder}/prompt.txt': redactor.redact_run_folder(redactor.clean(prompt), run_folder),
        f'{folder}/response.txt': redactor.redact_run_folder(reply, run_folder),
        f'{folder}/tool_calls.json': redactor.redact_run_folder(tool_log, run_folder),
    }
    files = {path: text.encode('utf-8') for path, text in files.items()}
    script = Path(run_folder, 'analysis.R')
    if script.is_file():
        files[f'{folder}/analysis.R'] = script.read_bytes()

    row = {'round': round_name, 'run_id': run_id, 'order': design_row['order'],
           'route': design_row['route'], 'request': design_row['request'], 'data': design_row['data'],
           'effort': effort,
           'model': only_value(settings['model'], 'model', run_id),
           'claude_code_version': only_value(settings['version'], 'Claude Code version', run_id),
           # The same instants as tool_calls.json, in ISO 8601 with the UTC offset
           'started': times[first].isoformat(), 'finished': times[last].isoformat(),
           'minutes': round((times[last] - times[first]).total_seconds() / 60, 2),
           'thinking_seconds': round(transcript['thinking_ms'] / 1000, 1),
           'tool_calls': len(calls), 'compliant': compliant,
           'total_tokens_last_request': total_tokens,
           'result_line': result_lines[-1], 'estimate': estimate, 'lower': lower, 'upper': upper}
    return files, row


def results_csv(rows):
    r"""Return results.csv as bytes, with \n line endings on every system.

    The csv module writes Python's own text of each value, so that the
    column compliant reads True or False.
    """
    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=FIELDS, lineterminator='\n')
    writer.writeheader()
    writer.writerows(rows)
    return out.getvalue().encode('utf-8')


def read_by_run(path, column):
    """Return one column of a CSV keyed by its run_id column."""
    with open(path, encoding='utf-8', newline='') as f:
        return {row['run_id']: row[column] for row in csv.DictReader(f)}


def xhigh_runs(records, suffix, design):
    """Return the design rows of the xhigh-effort runs, in launch order.

    They are the runs with a folder <run_id><suffix> in the records folder.
    """
    by_id = {row['run_id']: row for row in design}
    pattern = re.compile('([0-9a-f]{8})' + re.escape(suffix))
    found = []
    for folder in Path(records).iterdir():
        match = pattern.fullmatch(folder.name)
        if folder.is_dir() and match:
            if match.group(1) not in by_id:
                sys.exit(f'{folder.name}: run {match.group(1)} is not in design.csv.')
            found.append(by_id[match.group(1)])
    return sorted(found, key=lambda row: int(row['order']))


def parse_args(argv):
    """Parse the command line."""
    parser = argparse.ArgumentParser(description="Build the second round's stored records.")
    parser.add_argument('--experiment', required=True, help='the experiment folder')
    parser.add_argument('--transcripts', required=True, help="the medium-effort agents' transcripts")
    parser.add_argument('--agents', required=True, help='CSV pairing run_id with agent_id')
    parser.add_argument('--token-totals', required=True, help='CSV of run_id and total_tokens')
    parser.add_argument('--medium-runs', required=True, help='the medium-effort run folders, as the agents saw them')
    parser.add_argument('--xhigh-records', required=True, help="the xhigh-effort runs' records")
    parser.add_argument('--xhigh-runs', required=True, help='the xhigh-effort run folders, as the agents saw them')
    parser.add_argument('--xhigh-suffix', required=True, help="the suffix of the xhigh-effort folders' names")
    parser.add_argument('--r-version', required=True, help='as given to prepare_runs.py')
    parser.add_argument('--rscript', required=True, help='as given to prepare_runs.py')
    parser.add_argument('--home', default=str(Path.home()), help='the home folder whose name is redacted')
    parser.add_argument('--output', required=True, help='a new or empty folder to write into')
    return parser.parse_args(argv)


def main(argv=None):
    """Build every run's record and results.csv, check them, then write them."""
    args = parse_args(argv)
    redactor = Redactor(args.home, [args.medium_runs, args.xhigh_runs])
    design = prepare_runs.read_design(args.experiment)
    agents = read_by_run(args.agents, 'agent_id')
    totals = read_by_run(args.token_totals, 'total_tokens')
    for name, table in (('--agents', agents), ('--token-totals', totals)):
        missing = [row['run_id'] for row in design if row['run_id'] not in table]
        if missing:
            sys.exit(f'{name} has no row for {", ".join(missing)}.')

    # Each run: its round, design row, transcript, folder and token total
    runs = []
    medium_root = prepare_runs.folder_path(args.medium_runs)
    for row in design:
        runs.append(('medium', row, Path(args.transcripts, f'agent-{agents[row["run_id"]]}.jsonl'),
                     f'{medium_root}/{row["run_id"]}', totals[row['run_id']]))
    xhigh_root = prepare_runs.folder_path(args.xhigh_runs)
    for row in xhigh_runs(args.xhigh_records, args.xhigh_suffix, design):
        record = Path(args.xhigh_records, row['run_id'] + args.xhigh_suffix)
        with open(record / 'summary.json', encoding='utf-8') as f:
            total = json.load(f)['summary']['total_tokens_last_request']
        runs.append(('xhigh', row, record / 'transcript.jsonl',
                     f'{xhigh_root}/{row["run_id"]}{args.xhigh_suffix}', total))

    files, rows = {}, []
    for round_name, row, transcript, run_folder, total in runs:
        prompt = prepare_runs.make_prompt(
            prepare_runs.read_first_round_prompt(args.experiment, row['run_id']),
            row['run_id'], row['route'], run_folder, args.r_version, args.rscript)
        run_files, result = build_run(round_name, row, transcript, run_folder, prompt, total, redactor)
        files.update(run_files)
        rows.append(result)
    files['results.csv'] = results_csv(rows)

    # Every output is checked before any is written, so that a failed check
    # leaves no partial copy behind
    for path, content in files.items():
        redactor.check(path, content.decode('utf-8', errors='replace'))
    try:
        prepare_runs.ensure_empty_folder(args.output)
        for path, content in sorted(files.items()):
            target = Path(args.output, path)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
    except OSError as error:
        sys.exit(prepare_runs.write_failed(error, f'what was written in {args.output}'))
    print(f'Wrote results.csv and {len(files) - 1} files for {len(rows)} runs to {args.output}.')


if __name__ == '__main__':
    main()
