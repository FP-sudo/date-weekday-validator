# date-weekday-validator

**エディタ非依存**で使える、日本語テキスト中の「日付 + 曜日」整合性チェッカー。

Cursor / VS Code / JetBrains / Vim など **どのエディタでも**、`git commit` 時 / CI / Cursor AI ルールの形で動きます。

> Claude Code 専用の PostToolUse hook 版は [FP-sudo/date-weekday-validation-hook](https://github.com/FP-sudo/date-weekday-validation-hook) にあります。中身のバリデータは同じロジックです。

## 何を防ぐか

LLM と人間が共通して苦手なのが「日付と曜日を正しく組み合わせる」こと。

例えば `(火)` と書いても実際は水曜日だった、というケース。メルマガ、告知、契約書などで**配信事故の直接原因**になります。

このツールは：

- `.md` / `.html` / `.txt` / `.csv` / `.json` の中の日付+曜日を正規表現で抽出
- Python の `datetime` で実曜日を計算
- 一致しなければ **exit 1** で停止、`ファイル名:行番号` 付きでエラー出力

## 4つの導入モード

| モード | 対象ユーザー | 検証タイミング | 強制力 |
|---|---|---|---|
| **pre-commit framework** | Cursor / VS Code / JetBrains など全エディタユーザー | `git commit` 時 | 強制（commit を止める）|
| **raw git pre-commit** | pre-commit framework 未導入の人 | `git commit` 時 | 強制 |
| **GitHub Actions** | チーム開発 / OSS | PR / push 時 | 強制（CI 失敗）|
| **Cursor AI Rules** | Cursor ユーザー | AI が書く前 | ソフト（AI への注意喚起）|

4つは**併用可能**。推奨は「pre-commit framework + GitHub Actions + Cursor AI Rules」の3点セット。

---

## モード1: pre-commit framework

一番簡単。`pre-commit` ツール: https://pre-commit.com/

自分のプロジェクトの `.pre-commit-config.yaml` に以下を追加：

```yaml
repos:
  - repo: https://github.com/FP-sudo/date-weekday-validator
    rev: v1.0.0
    hooks:
      - id: validate-dates
```

そして：

```bash
pip install pre-commit   # 未導入なら
pre-commit install       # .git/hooks/pre-commit を設置
```

以降、`git commit` すると対象拡張子のステージ済みファイルが自動検証されます。

---

## モード2: raw git pre-commit（pre-commit framework なし）

pre-commit framework を使いたくない場合の軽量版：

```bash
git clone https://github.com/FP-sudo/date-weekday-validator.git /tmp/validator
cd path/to/your-repo
bash /tmp/validator/install-local.sh
```

これで `your-repo/.git/hooks/pre-commit` が設置されます。

- 既存の pre-commit がある場合はタイムスタンプ付きでバックアップ
- 再実行は冪等（既に設定済みならスキップ）
- **注意**: `.git/hooks/` は clone で持ち運ばれません。チームメンバー各自が実行する必要あり

---

## モード3: GitHub Actions (CI)

`.github/workflows/validate-dates.yml` を自分のリポジトリに作成：

```yaml
name: Validate dates

on:
  pull_request:
  push:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Clone validator
        run: git clone --depth 1 https://github.com/FP-sudo/date-weekday-validator.git /tmp/validator
      - name: Find changed files
        id: files
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            BASE="origin/${{ github.base_ref }}"
          else
            BASE="HEAD^"
          fi
          FILES=$(git diff --name-only --diff-filter=ACMR "${BASE}..HEAD" \
            | grep -E '\.(md|html|txt|csv|json)$' || true)
          {
            echo "list<<FILES_EOF"
            echo "${FILES}"
            echo "FILES_EOF"
          } >> "$GITHUB_OUTPUT"
      - name: Run validator
        if: steps.files.outputs.list != ''
        run: echo "${{ steps.files.outputs.list }}" | xargs python3 /tmp/validator/validate_dates.py
```

そのままコピー可能な版は `examples/.github/workflows/validate-dates.yml` にもあります。

---

## モード4: Cursor AI Rules（ソフト）

Cursor のエージェント/チャットに「日付を書いたら曜日を検証しろ」と教え込むルール。実行はされませんが、**生成前の注意喚起**として有効です。

```bash
# 自分のプロジェクトに配置
mkdir -p .cursor/rules
curl -fsSL https://raw.githubusercontent.com/FP-sudo/date-weekday-validator/main/.cursor/rules/date-weekday.mdc \
  > .cursor/rules/date-weekday.mdc
```

Cursor は `.cursor/rules/*.mdc` を自動読み込みし、glob 条件に合うファイル編集時に該当ルールを AI コンテキストに注入します。

---

## 検出パターン

| パターン | 形式 |
|---|---|
| 年月日 + 曜日 | `YYYY年M月D日(曜)` / `YYYY年M月D日（曜曜日）` |
| 月日 + 曜日（年省略） | `M月D日(曜)` / `M月D日（曜曜日）` |
| YYYY/M/D + 曜日 | `YYYY/M/D(曜)` / `YYYY-M-D(曜)` |
| M/D + 曜日（年省略） | `M/D(曜)` / `M/D（曜）` |

- 曜日文字: 月・火・水・木・金・土・日
- カッコ: 半角 `()` / 全角 `（）` 両対応
- 曜日単体（「火」）・フル形（「火曜」「火曜日」）両対応
- 全角数字（`２０２６年`）も検出
- 年省略時は現在の年を推定（3ヶ月以上過去なら翌年と推定）
- 対象拡張子: `.md` / `.html` / `.txt` / `.csv` / `.json`

### 既知の制限

- 全角スラッシュ `／` には未対応（LLM はほぼ半角しか出力しないため実害少）
- コードブロック内も検出対象（日付例を書いたコードが弾かれる可能性）→ 許容して回避するには一時無効化

## 要件

- **Python 3.8 以上**（標準ライブラリのみ / 追加パッケージ不要）
- **git**（pre-commit モードの場合）
- macOS / Linux / Windows (WSL)

## CLI として単独使用

CI 以外でも、任意のタイミングで手動実行できます：

```bash
python3 validate_dates.py file1.md file2.html ...
```

- exit 0: すべて OK
- exit 1: 1つ以上エラーあり（stderr に一覧）

## テスト

```bash
bash tests/run.sh
```

固定 fixtures による10ケースのスモークテスト。GitHub Actions で Python 3.8 / 3.10 / 3.12 の3系統で実行されます。

## ライセンス

MIT
