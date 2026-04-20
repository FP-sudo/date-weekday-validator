#!/usr/bin/env python3
"""
日本語テキスト中の日付+曜日パターンを検証する CLI / pre-commit ツール。

使い方:
  python3 validate_dates.py file1.md file2.html ...

- 曜日が正しい → exit 0
- 曜日が間違っている or 無効な日付 → exit 1, stderr にエラー一覧
- 対象拡張子は argv レベルでは絞らない（呼び出し側で .md/.html/.txt/.csv/.json を指定する想定）

検出パターン:
  - YYYY年M月D日(曜)  YYYY年M月D日（曜曜日）
  - M月D日(曜)        M月D日（曜曜日）          ← 年省略
  - YYYY/M/D(曜)      YYYY-M-D(曜)
  - M/D(曜)                                     ← 年省略
"""

from __future__ import annotations

import re
import sys
from datetime import date

WEEKDAYS_JA = {
    0: '月', 1: '火', 2: '水', 3: '木', 4: '金', 5: '土', 6: '日',
}

PATTERNS = [
    re.compile(
        r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日\s*[（(]\s*([月火水木金土日])\s*(?:曜日?)?\s*[）)]'
    ),
    re.compile(
        r'(?<!\d)(\d{1,2})\s*月\s*(\d{1,2})\s*日\s*[（(]\s*([月火水木金土日])\s*(?:曜日?)?\s*[）)]'
    ),
    re.compile(
        r'(\d{4})\s*[/\-]\s*(\d{1,2})\s*[/\-]\s*(\d{1,2})\s*[（(]\s*([月火水木金土日])\s*(?:曜日?)?\s*[）)]'
    ),
    re.compile(
        r'(?<!\d)(\d{1,2})\s*/\s*(\d{1,2})\s*[（(]\s*([月火水木金土日])\s*(?:曜日?)?\s*[）)]'
    ),
]


def guess_year(month: int, day: int) -> int:
    today = date.today()
    candidate = today.year
    try:
        d = date(candidate, month, day)
        if (today - d).days > 90:
            candidate += 1
    except ValueError:
        pass
    return candidate


def check_weekday(year: int, month: int, day: int, weekday_ja: str,
                  file_path: str, line_num: int, matched: str) -> str | None:
    try:
        d = date(year, month, day)
        correct = WEEKDAYS_JA[d.weekday()]
        if weekday_ja != correct:
            return (
                f'{file_path}:{line_num}: [日付エラー] "{matched}" → '
                f'{year}年{month}月{day}日は{weekday_ja}曜日ではなく【{correct}曜日】です'
            )
    except ValueError:
        return (
            f'{file_path}:{line_num}: [日付エラー] "{matched}" → '
            f'無効な日付です（{year}/{month}/{day}）'
        )
    return None


def validate_file(file_path: str) -> list[str]:
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except (OSError, UnicodeDecodeError):
        return []

    errors: list[str] = []
    for line_num, line in enumerate(content.split('\n'), 1):
        for m in PATTERNS[0].finditer(line):
            y, mo, d, w = int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4)
            err = check_weekday(y, mo, d, w, file_path, line_num, m.group(0))
            if err:
                errors.append(err)

        for m in PATTERNS[1].finditer(line):
            if PATTERNS[0].search(line[max(0, m.start() - 5):m.end()]):
                continue
            mo, d, w = int(m.group(1)), int(m.group(2)), m.group(3)
            y = guess_year(mo, d)
            err = check_weekday(y, mo, d, w, file_path, line_num, m.group(0))
            if err:
                errors.append(err)

        for m in PATTERNS[2].finditer(line):
            y, mo, d, w = int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4)
            err = check_weekday(y, mo, d, w, file_path, line_num, m.group(0))
            if err:
                errors.append(err)

        for m in PATTERNS[3].finditer(line):
            if PATTERNS[2].search(line[max(0, m.start() - 5):m.end()]):
                continue
            mo, d, w = int(m.group(1)), int(m.group(2)), m.group(3)
            y = guess_year(mo, d)
            err = check_weekday(y, mo, d, w, file_path, line_num, m.group(0))
            if err:
                errors.append(err)

    return errors


def main(argv: list[str]) -> int:
    paths = argv[1:]
    if not paths:
        return 0

    all_errors: list[str] = []
    for path in paths:
        all_errors.extend(validate_file(path))

    if all_errors:
        sys.stderr.write('\n'.join(all_errors) + '\n')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
