# The Python counterpart of make_data.R. It simulates the same specification
# with pilotr's Python implementation, formats the rows as make_data.R writes
# them and prints the SHA-256 checksum of the result, which matches that of
# data.csv. The output of a run is kept in python_sha256.txt.

import hashlib
import importlib.metadata

import pilotr

data = pilotr.simulate(pilotr.load_spec('spec.json'))
lines = ['participant,item,prime,frequency,rt']
for row in data.rows:
    r = row if isinstance(row, dict) else dict(zip(data.columns, row))
    lines.append(f"P{int(r['subject']):02d},W{int(r['item']):02d},{r['prime']},"
                 f"{round(r['frequency'], 2):g},{r['rt']:g}")
csv_bytes = ('\n'.join(lines) + '\n').encode()

print(f"pilotr {importlib.metadata.version('pilotr')} (Python)")
print(hashlib.sha256(csv_bytes).hexdigest())
