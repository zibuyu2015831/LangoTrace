#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "check-docs: $*" >&2
  exit 1
}

[[ -L AI_ENTRY_POINT.md ]] || fail "AI_ENTRY_POINT.md must be a symlink"
[[ "$(readlink AI_ENTRY_POINT.md)" == "docs/README.md" ]] || fail "AI_ENTRY_POINT.md must point to docs/README.md"
[[ -L CLAUDE.md ]] || fail "CLAUDE.md must be a symlink"
[[ "$(readlink CLAUDE.md)" == "docs/README.md" ]] || fail "CLAUDE.md must point to docs/README.md"
[[ -L AGENTS.md ]] || fail "AGENTS.md must be a symlink"
[[ "$(readlink AGENTS.md)" == "docs/README.md" ]] || fail "AGENTS.md must point to docs/README.md"

[[ -f docs/workflows/README.md ]] || fail "docs/workflows/README.md is required"

while IFS= read -r file; do
  name="$(basename "$file")"
  [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-(feature|bug|refactor|research|chore|docs)-[a-z0-9][a-z0-9-]*\.md$ ]] \
    || fail "invalid active plan filename: $file"
done < <(find docs/plans/active -maxdepth 1 -type f -name '*.md' | sort)

while IFS= read -r file; do
  name="$(basename "$file")"
  [[ "$name" == "README.md" || "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z][a-z0-9-]*-[a-z0-9][a-z0-9-]*\.md$ ]] \
    || fail "invalid done plan filename: $file"
done < <(find docs/plans/done -maxdepth 1 -type f -name '*.md' | sort)

[[ ! -d docs/worklogs ]] || fail "docs/worklogs must not be restored"
[[ ! -d docs/superpowers ]] || fail "docs/superpowers must not be restored"
[[ ! -d docs/guidelines ]] || fail "docs/guidelines must not be restored"

while IFS= read -r file; do
  [[ "$(basename "$(dirname "$file")")" == "rounds" ]] && continue
  rg -q "代码快照|当前事实源|可作为依据|状态：" "$file" \
    || fail "review round README is missing required audit metadata: $file"
done < <(find docs/review/rounds -mindepth 2 -maxdepth 2 -type f -name README.md | sort)

if rg "TO[D]O|TB[D]|待补[充]|稍后完[善]|以后再[写]|待[定]" docs --glob '!plans/examples/*' --glob '!spec/examples/*'; then
  fail "documentation placeholder scan found entries"
fi

echo "check-docs: ok"
