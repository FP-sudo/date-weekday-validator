# date-weekday-validator

**エディタ非依存**で使える、日本語テキスト中の「日付 + 曜日」整合性チェッカー。

Cursor / VS Code / JetBrains / Vim など **どのエディタでも**、`git commit` 時 / CI / Cursor AI ルールの形で動きます。

[![Self-test](https://github.com/FP-sudo/date-weekday-validator/actions/workflows/ci.yml/badge.svg)](https://github.com/FP-sudo/date-weekday-validator/actions/workflows/ci.yml)

> Claude Code 専用の PostToolUse hook 版は [FP-sudo/date-weekday-validation-hook](https://github.com/FP-sudo/date-weekday-validation-hook) にあります。バリデータのロジックは同一です。

---

## 何を防ぐか

LLM が生成する日本語コンテンツでは **「日付と曜日のズレ」** が頻発します。例えば `(火)` と書いても実際は水曜日だった、というケース。配信事故・告知ミスの直接原因になります。

このツールは `.md` / `.html` / `.txt` / `.csv` / `.json` の中の日付+曜日を正規表現で抽出し、実曜日と突き合わせて誤りを検出します。

```
$ python3 validate_dates.py article.md
article.md:5: [日付エラー] "YYYY年M月D日(X)" → YYYY年M月D日はX曜日ではなく【Y曜日】です
```

---

## ⚡ どれを選ぶ？ 3秒ガイド

| あなたの状況 | 選ぶモード |
|---|---|
| チームで使う / OSS プロジェクト | **モード1 (pre-commit framework) + モード3 (CI)** |
| 1人で使う / 軽量に済ませたい | **モード2 (raw git hook)** |
| Cursor で AI に自覚させたい | **モード4 (Cursor Rules)** を上記に追加 |
| Claude Code ユーザー | 別リポ [`date-weekday-validation-hook`](https://github.com/FP-sudo/date-weekday-validation-hook) |

併用可能。推奨は **1 + 3 + 4** の3点セット。

---

## 🧭 モード1: pre-commit framework（最も推奨）

[pre-commit](https://pre-commit.com) を使う最も標準的な方法。エディタに依存せず、チームメンバー全員に同じ検証が配布できます。

### ステップ

```bash
# 1. pre-commit 本体をインストール（一度だけ）
pip install pre-commit
# または: brew install pre-commit

# 2. あなたのプロジェクトのルートで、設定ファイルを作成
cat > .pre-commit-config.yaml <<'EOF'
repos:
  - repo: https://github.com/FP-sudo/date-weekday-validator
    rev: v1.0.0
    hooks:
      - id: validate-dates
EOF

# 3. フックを .git/hooks/ に登録
pre-commit install
```

これで完了。以降 `git commit` する度に、ステージされた `.md`/`.html`/`.txt`/`.csv`/`.json` が自動検証されます。

### 動作イメージ

```
$ git commit -m "update announcement"
Validate Japanese date+weekday consistency...............................Failed
- hook id: validate-dates
- exit code: 1

announcement.md:3: [日付エラー] "YYYY年M月D日(X)" → YYYY年M月D日はX曜日ではなく【Y曜日】です
```

修正して再コミットすると通ります。

### バージョン更新

```bash
pre-commit autoupdate
```

---

## 🧰 モード2: raw git pre-commit（pre-commit framework なし）

「pre-commit の Python パッケージ入れたくない」という人向け。**依存ゼロ**。

### ステップ

```bash
# 1. このリポをどこかに clone
git clone https://github.com/FP-sudo/date-weekday-validator.git ~/tools/date-weekday-validator

# 2. 検証したいプロジェクトのルートに cd
cd ~/your-project

# 3. インストールスクリプトを実行
bash ~/tools/date-weekday-validator/install-local.sh
```

これで `your-project/.git/hooks/pre-commit` が設置されます。

### 注意

- **`.git/hooks/` は clone で配布されません**。チームメンバーが複数いる場合は各自が `install-local.sh` を実行する必要があります。共有配布する運用なら **モード1 を使ってください**
- 既存の pre-commit がある場合は `.bak.YYYYMMDDHHMMSS` でバックアップを取ります。統合は手動です
- 再実行しても冪等（既に設定済みならスキップ）

---

## 🤖 モード3: GitHub Actions (CI)

PR/push のたびに自動検証。**個人が install を忘れても、マージ前に必ず捕捉される**最後の砦。

### ステップ

自分のリポジトリに [`examples/.github/workflows/validate-dates.yml`](./examples/.github/workflows/validate-dates.yml) をコピーして配置するだけです:

```bash
mkdir -p .github/workflows
curl -fsSL https://raw.githubusercontent.com/FP-sudo/date-weekday-validator/main/examples/.github/workflows/validate-dates.yml \
  -o .github/workflows/validate-dates.yml
```

PR または `main` への push で自動的に走ります。

内容を確認したい場合は上記リンクから参照してください。

---

## 🧭 モード4: Cursor AI Rules（ソフト）

Cursor のエージェント/チャットに「日付を書いたら曜日を検証しろ」と教え込むルール。**実行はされませんが、AI が書き始める前の意識付け**として働きます。

### ステップ

自分のプロジェクトのルートで:

```bash
mkdir -p .cursor/rules
curl -fsSL https://raw.githubusercontent.com/FP-sudo/date-weekday-validator/main/.cursor/rules/date-weekday.mdc \
  -o .cursor/rules/date-weekday.mdc
```

Cursor は `.cursor/rules/*.mdc` を自動読み込みし、`*.md` / `*.html` / `*.txt` / `*.csv` / `*.json` を編集する際にルール内容を AI コンテキストに注入します。

> **ソフト制約**なので pre-commit の代替にはなりません。**モード1/2 と必ず併用してください**。

---

## 🧪 CLI として単独使用

任意のタイミングで手動実行もできます:

```bash
python3 validate_dates.py file1.md file2.html ...
```

- exit 0: すべて OK
- exit 1: 1つ以上エラー（stderr に一覧）

---

## 🔍 検出パターン

| パターン | 形式 |
|---|---|
| 年月日 + 曜日 | `YYYY年M月D日(曜)` / `YYYY年M月D日（曜曜日）` |
| 月日 + 曜日（年省略） | `M月D日(曜)` / `M月D日（曜曜日）` |
| YYYY/M/D + 曜日 | `YYYY/M/D(曜)` / `YYYY-M-D(曜)` |
| M/D + 曜日（年省略） | `M/D(曜)` / `M/D（曜）` |

- 曜日文字: 月・火・水・木・金・土・日
- カッコ: 半角 `()` / 全角 `（）` 両対応
- 曜日単体・フル形（「火曜」「火曜日」）両対応
- 全角数字（`２０２６年`）も検出
- 年省略時は現在の年を推定（3ヶ月以上過去なら翌年と推定）

## 📦 要件

- **Python 3.8 以上**（標準ライブラリのみ / 追加依存なし）
- **git**（pre-commit モードの場合）
- macOS / Linux / Windows (WSL)

## 🧯 既知の制限

- 全角スラッシュ `／` には未対応（LLM はほぼ半角しか出力しないため実害少）
- コードブロック内も検出対象（日付例を書いたコードが弾かれる可能性あり）

## 💬 トラブルシュート

**Q. pre-commit を走らせたら「executable bit」のエラーが出る**
A. fork したリポで `chmod +x validate_dates.py` を実行してから push してください（本家リポでは実行ビット付き）。

**Q. hook を一時的に無効化したい**
A. `git commit --no-verify` で pre-commit をスキップできます。ただし CI（モード3）が入っている場合は PR で引っかかります。

**Q. 誤検出を回避したい**
A. 正規表現を調整したい場合は fork して `validate_dates.py` の `PATTERNS` を変更してください。

## 🏗 テスト

```bash
bash tests/run.sh
```

固定 fixtures による10ケース。CI は Python 3.8 / 3.10 / 3.12 のマトリクスで実行されます。

## 📄 ライセンス

MIT
