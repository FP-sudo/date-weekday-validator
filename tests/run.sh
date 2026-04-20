#!/usr/bin/env bash
# Self-test for validate_dates.py
# 各テストケースは固定日付（実在の曜日が確定している過去日）で組む。
# 未来日に依存するテストは guess_year() の挙動に左右されるため避ける。

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="${HERE}/../validate_dates.py"
FIX="${HERE}/fixtures"

PASS=0
FAIL=0

assert_exit() {
  local name="$1"; local expected="$2"; shift 2
  set +e
  python3 "${VALIDATOR}" "$@" >/tmp/vd_out 2>/tmp/vd_err
  local rc=$?
  set -e
  if [ "${rc}" = "${expected}" ]; then
    PASS=$((PASS + 1))
    printf "  \033[32m✓\033[0m %s (exit=%s)\n" "${name}" "${rc}"
  else
    FAIL=$((FAIL + 1))
    printf "  \033[31m✗\033[0m %s (expected %s, got %s)\n" "${name}" "${expected}" "${rc}"
    [ -s /tmp/vd_err ] && sed 's/^/      /' /tmp/vd_err
  fi
}

echo "=== date-weekday-validator self-tests ==="

# --- 正常系: 正しい曜日 → exit 0 ---
assert_exit "correct (2024-02-29 is Thu)" 0 "${FIX}/correct_2024_leap.md"
assert_exit "correct weekday-full form"   0 "${FIX}/correct_full.md"
assert_exit "no dates in file"            0 "${FIX}/no_dates.md"
assert_exit "empty file"                  0 "${FIX}/empty.md"

# --- 異常系: 誤った曜日 → exit 1 ---
assert_exit "wrong weekday"               1 "${FIX}/wrong.md"
assert_exit "invalid leap (2023-02-29)"   1 "${FIX}/invalid_leap.md"
assert_exit "multi errors same line"      1 "${FIX}/multi_error.md"

# --- argv 複数 ---
assert_exit "multi files (one bad)"       1 "${FIX}/correct_2024_leap.md" "${FIX}/wrong.md"
assert_exit "multi files (all good)"      0 "${FIX}/correct_2024_leap.md" "${FIX}/no_dates.md"

# --- argv 空 → exit 0 ---
assert_exit "no args"                     0

echo ""
echo "passed: ${PASS} / failed: ${FAIL}"
[ "${FAIL}" = "0" ]
