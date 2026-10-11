#!/usr/bin/env bash
set -euo pipefail
base_ref="$1"
head_ref="$2"
git diff --check "${base_ref}...${head_ref}"
python3 - "$base_ref" "$head_ref" <<'PYTEST'
import pathlib
import subprocess
import sys
base, head = sys.argv[1:]
raw = subprocess.check_output(["git", "diff", "--name-only", "--diff-filter=ACMR", "-z", f"{base}...{head}"])
for item in raw.split(b"\0"):
    if not item:
        continue
    path = pathlib.Path(item.decode())
    if path.suffix == ".py":
        compile(path.read_bytes(), str(path), "exec")
    elif path.suffix == ".sh":
        subprocess.run(["bash", "-n", str(path)], check=True)
print("Changed Python and shell files passed syntax validation.")
PYTEST
changed_workflows="$(git diff --name-only "${base_ref}...${head_ref}" -- .github/workflows)"
if [[ -n "$changed_workflows" ]]; then
  go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7
fi
