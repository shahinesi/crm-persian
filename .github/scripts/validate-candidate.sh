#!/usr/bin/env bash
set -euo pipefail
base_ref="$1"
head_ref="$2"
git diff --check "${base_ref}...${head_ref}" -- . ':(exclude)crm/locale/*.po'
po_diff_check_output="$(git diff --check "${base_ref}...${head_ref}" -- 'crm/locale/*.po' 2>&1 || true)"
if [[ -n "$po_diff_check_output" ]]; then
  unexpected_po_diff_check="$(printf '%s\n' "$po_diff_check_output" | awk '
    /^crm\/locale\/[^:]+\.po:[0-9]+: new blank line at EOF\.$/ { next }
    { print; found = 1 }
    END { if (!found) exit 0 }
  ')"
  if [[ -n "$unexpected_po_diff_check" ]]; then
    printf '%s\n' "$unexpected_po_diff_check" >&2
    exit 1
  fi
  echo "Ignoring only known upstream PO-catalog blank lines at EOF; other PO whitespace errors remain fatal."
fi
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
