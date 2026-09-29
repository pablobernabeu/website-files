"""Extracts, from each agent's transcript, its final reply and a log of its tool
calls, and writes them to runs/<run_id>/response.txt and tool_calls.json.

The transcripts are the JSON Lines files that Claude Code writes for each agent.
They also hold the session's system context, so they are not kept here. This
script is kept to show how the stored replies and logs were derived.

Usage: python3 extract_transcripts.py <mapping.tsv> <transcript_dir>
where mapping.tsv pairs each run_id with the id of its agent's transcript.
"""
import json
import os
import sys

mapping_file, transcript_dir = sys.argv[1], sys.argv[2]
mapping = dict(line.split() for line in open(mapping_file) if line.strip())

for run_id, agent in mapping.items():
    path = os.path.join(transcript_dir, agent + '.output')
    if not os.path.exists(path):
        continue
    calls, texts, stamps = [], [], []
    for line in open(path):
        record = json.loads(line)
        if 'timestamp' in record:
            stamps.append(record['timestamp'])
        message = record.get('message')
        if not isinstance(message, dict) or message.get('role') != 'assistant':
            continue
        for block in message.get('content') or []:
            if block.get('type') == 'tool_use':
                calls.append({'tool': block['name'], 'input': block.get('input')})
            elif block.get('type') == 'text' and block.get('text', '').strip():
                texts.append(block['text'])
    # An agent hands its final reply back through a tool call when it has one,
    # and otherwise ends with a text block.
    final = texts[-1] if texts else ''
    for call in calls:
        if call['tool'] == 'SubagentHandback':
            final = (call['input'] or {}).get('message', final)
    out = os.path.join('runs', run_id)
    with open(os.path.join(out, 'response.txt'), 'w') as f:
        f.write(final.rstrip('\n') + '\n')
    with open(os.path.join(out, 'tool_calls.json'), 'w') as f:
        json.dump({'started': min(stamps), 'finished': max(stamps),
                   'calls': [c for c in calls if c['tool'] != 'SubagentHandback']}, f, indent=1)
