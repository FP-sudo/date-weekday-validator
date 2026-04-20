#!/usr/bin/env bash
# Install validate_dates.py as a raw git pre-commit hook in the CURRENT git repo.
# Use this if you don't want to adopt the pre-commit framework.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が必要です" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git が必要です" >&2; exit 1; }

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "${GIT_ROOT}" ]; then
  echo "ERROR: git リポジトリ内で実行してください" >&2
  exit 1
fi

HOOKS_DIR="${GIT_ROOT}/.git/hooks"
VALIDATOR_DST="${HOOKS_DIR}/validate_dates.py"
PRECOMMIT="${HOOKS_DIR}/pre-commit"

mkdir -p "${HOOKS_DIR}"

cp "${SCRIPT_DIR}/validate_dates.py" "${VALIDATOR_DST}"
chmod +x "${VALIDATOR_DST}"
echo "✓ Validator copied to ${VALIDATOR_DST}"

if [ -f "${PRECOMMIT}" ]; then
  if grep -q "validate_dates.py" "${PRECOMMIT}" 2>/dev/null; then
    echo "✓ Already wired into ${PRECOMMIT} (skipped)"
    exit 0
  fi
  BACKUP="${PRECOMMIT}.bak.$(date +%Y%m%d%H%M%S)"
  cp "${PRECOMMIT}" "${BACKUP}"
  echo "✓ Existing pre-commit backed up to ${BACKUP}"
  echo "⚠  手動でバックアップと統合してください。" >&2
fi

cat > "${PRECOMMIT}" <<'EOF'
#!/usr/bin/env bash
# date-weekday-validator pre-commit hook
set -euo pipefail
HOOK_DIR="$(dirname "$0")"
FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(md|html|txt|csv|json)$' || true)
if [ -z "${FILES}" ]; then
  exit 0
fi
echo "${FILES}" | xargs python3 "${HOOK_DIR}/validate_dates.py"
EOF
chmod +x "${PRECOMMIT}"

echo "✓ pre-commit hook installed at ${PRECOMMIT}"
echo ""
echo "これ以降、${GIT_ROOT} で git commit すると対象拡張子の変更が検証されます。"
