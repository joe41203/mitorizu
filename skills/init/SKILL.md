---
name: init
description: mitorizu の実行環境を準備する。インフラ図の生成に使う d2 をプロジェクトローカルに導入し、mermaid 検証ツールの有無を確認する。導入前に必ず内容を提示して確認を取る。
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

# 実行環境の準備

mitorizu が使う外部ツールをプロジェクトローカルに導入する。

**システムには何もインストールしない。** 全て `.mitorizu/bin/` 配下に置く。
プロジェクトを削除すれば一緒に消える。

## 対象ツール

| ツール | 必須 | 用途 | 導入方法 |
| --- | --- | --- | --- |
| [d2](https://d2lang.com) | 任意 | インフラ構成図の SVG 生成 | GitHub Releases からバイナリ取得 |
| [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) | 任意 | mermaid の構文検証 | 案内のみ (npm が必要なため) |

**どちらも必須ではない。** 未導入でも設計ドキュメントは生成できる。

- d2 が無い: `.d2` ソースのみ生成し、SVG 生成をスキップする
- mmdc が無い: mermaid の検証をスキップする (図の描画は GitHub 側で行われる)

## 進め方

### Phase 1: 現状を確認する

```bash
"${CLAUDE_SKILL_DIR}/scripts/setup.sh" --check
```

このコマンドは何もインストールしない。以下を報告するだけ。

- システムに `d2` / `mmdc` があるか (PATH 上)
- プロジェクトローカル (`.mitorizu/bin/`) にあるか
- OS とアーキテクチャ
- 導入する場合のダウンロード元 URL とサイズ

結果をユーザーに提示する。

### Phase 2: 導入の可否を確認する (必須)

**確認を取らずにダウンロードしてはいけない。**

Phase 1 の結果を示した上で、AskUserQuestion で確認する。
提示する内容は以下を必ず含める。

- **何を** — d2 のバージョンとファイル名
- **どこから** — GitHub Releases の完全な URL
- **どこへ** — `.mitorizu/bin/d2` (プロジェクト配下)
- **サイズ** — 約20MB
- **システムへの影響** — なし (PATH も変更しない)

```
インフラ構成図の生成に d2 を使います。導入しますか?

  取得元: https://github.com/d2lang/d2/releases/download/v0.7.1/d2-v0.7.1-macos-arm64.tar.gz
  配置先: .mitorizu/bin/d2  (このプロジェクト内)
  サイズ: 約20MB
  影響:   システムには何もインストールしません。PATH も変更しません。

  A: 導入する (推奨)
  B: 導入しない (.d2 ソースのみ生成し、図は後から作る)
  C: 自分で入れる (brew install d2 の手順を表示)
```

**非対話実行の場合は導入しない。** 案内だけ出して終える。
ダウンロードは利用者の明示的な同意が必要なため、推奨案の自動採用の対象外とする。

### Phase 3: 導入する

同意が得られた場合のみ実行する。

```bash
"${CLAUDE_SKILL_DIR}/scripts/setup.sh" --install-d2
```

スクリプトが行うこと:

1. OS とアーキテクチャを判定する
2. GitHub API で最新リリースの URL を取得する
3. tar.gz をダウンロードする
4. **SHA-256 を計算して表示する** (記録用)
5. 展開して `.mitorizu/bin/d2` に配置する
6. **`d2 --version` を実行して動作を確認する**
7. `.gitignore` に `.mitorizu/` を追記する

**チェックサムの事前検証はできない。**
d2 の GitHub Releases はチェックサムファイルを配布していないため
(実測で確認済み)、ダウンロード前に期待値と突き合わせる方法がない。

代わりに以下で健全性を担保する。

- 取得元を GitHub Releases に固定する (`d2lang/d2` の公式配布物のみ)
- `curl | sh` 形式のインストーラを使わない (スクリプトの実行を伴わない)
- 取得後に SHA-256 を計算して表示する (記録・照合用)
- **展開したバイナリが実際に動くかを検証する** (`d2 --version`)

### Phase 4: 結果を報告する

```
d2 を導入しました。

  バージョン: v0.7.1
  配置先:     .mitorizu/bin/d2
  SHA-256:    80de85f3b0ac7d9569acac0780ed65dd994ea78969b6b230c58bbb2c6113465b
  動作確認:   d2 --version -> v0.7.1 (OK)

.gitignore に .mitorizu/ を追記しました。
```

mmdc が未導入なら、この時点で案内する。

```
mermaid の構文検証には mermaid-cli が必要です。
npm が必要なため自動導入はしません。使う場合は:

  npm install -g @mermaid-js/mermaid-cli

未導入でも設計ドキュメントは生成できます (検証をスキップするだけ)。
```

## 導入後の使われ方

`infra-diagram` スキルは以下の順で d2 を探す。

1. `.mitorizu/bin/d2` (プロジェクトローカル)
2. PATH 上の `d2` (システム)
3. どちらも無ければ `.d2` ソースのみ生成し、案内を出す

同梱の `verify-d2.sh` がこの探索を行うので、
利用者がパスを意識する必要はない。

## アンインストール

```bash
rm -rf .mitorizu
```

これだけ。システムには何も残らない。

## 参照

- `${CLAUDE_SKILL_DIR}/scripts/setup.sh` — 環境確認と導入
- `${CLAUDE_PLUGIN_ROOT}/references/conventions.md` — 共通規約
