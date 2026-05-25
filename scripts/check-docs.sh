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

if git ls-files 'docs/.DS_Store' '**/.DS_Store' | rg -q '.'; then
  fail ".DS_Store must not be tracked"
fi

[[ -f docs/workflows/README.md ]] || fail "docs/workflows/README.md is required"
for workflow in \
  docs/workflows/add-ai-provider.md \
  docs/workflows/add-platform-screen.md \
  docs/workflows/add-prompt.md \
  docs/workflows/add-storage-migration.md \
  docs/workflows/add-tts-provider.md; do
  [[ -f "$workflow" ]] || fail "required workflow is missing: $workflow"
done

[[ -f docs/architecture/002-system-map.md ]] || fail "docs/architecture/002-system-map.md is required"
[[ -f docs/reference/research/spikes/README.md ]] || fail "docs/reference/research/spikes/README.md is required"
[[ -f docs/review/health-ledger.md ]] || fail "docs/review/health-ledger.md is required"
rg -q "^## 最新状态摘要$" docs/review/INDEX.md || fail "docs/review/INDEX.md must include latest status summary"
rg -q "^## 2\\. Ledger$" docs/review/health-ledger.md || fail "docs/review/health-ledger.md must include ledger section"
rg -q "日期.*Commit.*Trigger.*Metrics.*Verdict.*Notes" docs/review/health-ledger.md \
  || fail "docs/review/health-ledger.md must include date/commit/trigger/metrics/verdict/notes columns"

while IFS= read -r file; do
  name="$(basename "$file")"
  [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-(feature|bug|refactor|research|chore|docs)-[a-z0-9][a-z0-9-]*\.md$ ]] \
    || fail "invalid active plan filename: $file"
  rg -q "^状态：" "$file" || fail "active plan is missing 状态: $file"
  rg -q "^类型：" "$file" || fail "active plan is missing 类型: $file"
  rg -q "^创建日期：" "$file" || fail "active plan is missing 创建日期: $file"
  rg -q "^最后更新日期：" "$file" || fail "active plan is missing 最后更新日期: $file"
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
