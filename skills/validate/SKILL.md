---
name: validate
description: 生成済みの設計ドキュメント全体の整合性を検証する。画面・API・テーブルの過不足、用語のブレ、エンティティの重複、要件の追跡漏れを検出する。設計を手で修正した後や、複数機能を作った後に実行する。
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Task
---

# 設計ドキュメントの整合性検証

`docs/mitorizu/` 配下の成果物を横断的に検証する。

**このスキルは何も生成しない。** 既存のドキュメントを読んで問題を報告するだけ。
修正は利用者の判断で行う。

## いつ使うか

| 状況 | 理由 |
| --- | --- |
| 設計ドキュメントを手で修正した後 | 各スキルの検証は実行時にしか走らないため |
| 2つ目以降の機能を作った後 | 機能をまたぐ矛盾は個別スキルでは検出できない |
| 実装に着手する前 | 不整合を持ち越すと実装中に必ず表面化する |
| レビュー前 | 指摘されそうな箇所を先に潰す |

## 検証する項目

### A. 機能内の整合性 (機能ごと)

| # | 検証 | 判定基準 |
| --- | --- | --- |
| A1 | 不足 | 画面の表示項目が API レスポンスに全て含まれるか |
| A2 | 過剰 | API レスポンスの全フィールドに画面ID付きの用途があるか |
| A3 | 出所不明 | API レスポンスの全フィールドがテーブルのカラムか導出値か |
| A4 | 用途の空欄 | 全カラムに用途と参照元が書かれているか |
| A5 | 要件の追跡 | 全ての REQ-NNN が画面か API に対応しているか |
| A6 | 画面の追跡 | 全ての SCR-NNN が要件に対応しているか |

### B. 機能をまたぐ整合性 (プロジェクト全体)

| # | 検証 | 判定基準 |
| --- | --- | --- |
| B1 | 用語のブレ | 同じ概念に別名が付いていないか (User / Account / Member) |
| B2 | エンティティ重複 | 同じテーブルが複数の機能で別々に定義されていないか |
| B3 | 要件の矛盾 | 両立しない要件が存在しないか |
| B4 | 用語集の網羅 | 設計に登場する主要な名詞が `glossary.md` にあるか |
| B5 | カタログの網羅 | 全テーブルが `entities.md` に登録されているか |

### C. 形式の検証

| # | 検証 | 判定基準 |
| --- | --- | --- |
| C1 | 信頼性マーカー | 要件の全項目にマーカーが付いているか |
| C2 | EARS 記法 | 機能要件が EARS の形になっているか |
| C3 | 命名規約 | テーブル・カラムが Rails way (または既存規約) に従うか |
| C4 | mermaid | 図が構文エラーなく描画できるか |
| C5 | 要確認の集約 | `[要確認]` が README に集約されているか |

## 開始前に必ず読むもの

**成果物を書き始める前に、このプロジェクトの学習内容を読む。**
既定より優先度が高い。

```bash
cat docs/mitorizu/.feedback/overrides.md 2>/dev/null
cat docs/mitorizu/.feedback/learnings.md 2>/dev/null
```

無ければ既定で進める。あれば**そちらを優先する**。
詳細は共通規約の「フィードバックの蓄積と反映」を参照。

## 進め方

### Phase 1: 対象を洗い出す

```bash
ls docs/mitorizu/
ls docs/mitorizu/features/
```

存在しない場合は「検証対象がありません」と報告して終える。
`/mitorizu:requirements` から始めるよう案内する。

機能数が3つ以上ある場合、**機能ごとに Task サブエージェントへ委譲**して並列化する。
メインコンテキストには検出結果だけを取り込む。

### Phase 2: 機械的に検証できるものを先に処理する

以下はスクリプトで判定できる。**目視より確実で速い。**

```bash
# 用途・参照元の空欄を検出
grep -n '| *(空欄) *|' docs/mitorizu/features/*/data-model.md

# 信頼性マーカーの無い要件を検出
grep -nE '^\*\*REQ-[0-9]+' docs/mitorizu/features/*/requirements.md \
  | grep -v '\[確実\]\|\[推測\]\|\[要確認\]'

# mermaid の構文検証
find docs/mitorizu -name '*.md' -print0 \
  | xargs -0 "${CLAUDE_PLUGIN_ROOT}/scripts/check-mermaid.sh"

# テーブル名の一覧を出す (複数形かは目視で判断する)
grep -hoE '^### [a-z_]+' docs/mitorizu/features/*/data-model.md | sed 's/^### //'
```

**テーブル名が複数形かどうかは機械判定できない。**
`books` は正しく `lending` は誤りだが、正規表現では区別できない。
一覧を出して目視で確認する。不規則複数形 (`people` `children`) もあるため
機械判定を試みると誤検出が増える。

### Phase 3: 突き合わせを行う

`traceability.md` が既にあれば、**それが最新かを確認する**。
`screens.md` / `api.md` / `data-model.md` の更新日時が
`traceability.md` より新しければ、古くなっている。

```bash
ls -la --time-style=+%s docs/mitorizu/features/<slug>/*.md 2>/dev/null \
  || stat -f '%m %N' docs/mitorizu/features/<slug>/*.md
```

古い場合、または存在しない場合は**その場で突き合わせをやり直す**。

判定規則は `${CLAUDE_PLUGIN_ROOT}/skills/api-design/SKILL.md` の
「不足と出所不明の切り分け」に従う。**1つの問題を2箇所に計上しない。**

### Phase 4: 機能をまたぐ検証

複数機能がある場合のみ実行する。

**用語のブレの検出**:

1. 全 `requirements.md` `screens.md` `data-model.md` から名詞を集める
2. `glossary.md` の用語と照合する
3. 意味が近い別名を探す

意味の近さは機械的に判定できないため、以下のパターンを重点的に見る。

| パターン | 例 |
| --- | --- |
| 人を表す語 | User / Account / Member / Customer / Employee |
| 組織を表す語 | Organization / Company / Team / Group / Tenant |
| 品目を表す語 | Item / Product / Goods / Article |
| 記録を表す語 | Record / Log / History / Entry |
| 状態を表す語 | Status / State / Phase / Stage |

**エンティティ重複の検出**:

```bash
grep -hoE '^### [a-z_]+' docs/mitorizu/features/*/data-model.md | sort | uniq -d
```

同じテーブル名が複数機能に出てきたら、定義が一致しているかを確認する。
カラムが食い違っていれば矛盾。

### Phase 5: 報告する

**修正はしない。報告だけを行う。**
何を直すかは利用者の判断であり、勝手に書き換えると意図しない変更が混ざる。

報告は `${CLAUDE_SKILL_DIR}/references/report-format.md` の形式に従う。要点は以下。

1. **サマリを先に出す** — 検出件数を種別ごとに
2. **重大度で並べる** — 実装が止まるものを先に
3. **どのファイルの何行目か** を示す
4. **どう直せばよいか** を1行添える

```
検証結果: 5件の問題を検出しました

重大 (実装が止まる)
  1. [不足] SCR-001 の「出版年」が GET /books のレスポンスに含まれていません
     screens.md:12 / api.md:34
     -> data-model.md に books.published_year を追加し、API に載せる

  2. [出所不明] api.md の items[].borrower_name の出所が不明です
     api.md:41
     -> data-model.md に employees テーブルが存在しません

軽微 (設計の質)
  3. [過剰] books.isbn がどの画面でも使われていません
     data-model.md:18
     -> カラムを削除するか、用途を screens.md に追記する

  4. [用語] 「社員」と「ユーザー」が混在しています
     requirements.md:8 / screens.md:15
     -> glossary.md でどちらかに統一する

  5. [マーカー] REQ-012 に信頼性マーカーがありません
     requirements.md:45
     -> [確実] / [推測] / [要確認] のいずれかを付ける
```

### Phase 6: 繰り返しから学ぶ

**同じ種別の指摘が3回以上出たら、スキルの既定が実態に合っていない。**

`docs/mitorizu/.feedback/learnings.md` を読み、今回の検出と照合する。

```bash
cat docs/mitorizu/.feedback/learnings.md 2>/dev/null
```

| 判定 | 対応 |
| --- | --- |
| 初出の指摘 | 記録しない (1回では偶然かもしれない) |
| 2回目 | 記録するが対策は書かない (様子見) |
| **3回目以降** | **原因と対策を書く。次回から最初に適用する** |

```markdown
[2026-08-14] 用途の空欄が毎回20件以上検出される
  原因: 監査カラム (created_at 等) に用途を書いていなかった
  対策: data-model 実行時、監査カラムは例外として最初から扱う
  検出回数: 3回
```

**記録は利用者に確認してから行う。**
検出回数が閾値に達したことと、提案する対策を示す。

```
「用途の空欄」が3回続けて検出されています。
毎回同じ原因 (監査カラム) なので、次回から自動で例外扱いにしますか?

A: 記録する (次回から適用)
B: 記録しない (毎回確認したい)
```

### Phase 7: 次の行動を案内する

```
修正後、再度 /mitorizu:validate を実行して0件になることを確認してください。

不足・出所不明を解消するには:
  /mitorizu:data-model   カラムを追加する
  /mitorizu:api-design   API を再設計し traceability.md を更新する
```

## 検証しないこと

**このスキルの守備範囲を明確にする。** 以下は検証しない。

- **要件の妥当性** — 「この要件は本当に必要か」は人間の判断
- **設計の良し悪し** — 正規化の程度、命名の適切さなどは文脈依存
- **実装との一致** — コードは読まない (設計ドキュメント間の整合のみ)
- **性能** — インデックスの十分性などは実測が必要

これらを検証したように見せると、通ったことが安全の保証と誤解される。

## 参照

- `${CLAUDE_SKILL_DIR}/references/report-format.md` — 報告の形式
- `${CLAUDE_PLUGIN_ROOT}/references/conventions.md` — 命名規約、信頼性マーカー
- `${CLAUDE_PLUGIN_ROOT}/skills/api-design/SKILL.md` — 不足と出所不明の切り分け規則
