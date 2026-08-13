# mitorizu

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue)](https://code.claude.com/docs/en/plugins)

**要件定義から設計成果物までを、対話のラリーで組み立てる Claude Code プラグイン。**

空リポジトリから MVP を作るまでの設計を、対話しながら進めます。
要件定義書・画面設計・ER図・テーブル定義・API設計・インフラ構成図を生成し、
最後に**それらの整合性を機械的に検証**します。

見取図 (みとりず) は、細部の施工図ではなく全体を大づかみに把握するための図です。

## 何が違うか

仕様駆動開発のツールは既にいくつもあります
([spec-kit](https://github.com/github/spec-kit) /
[OpenSpec](https://github.com/Fission-AI/OpenSpec) /
[tsumiki](https://github.com/classmethod/tsumiki) など)。
mitorizu が埋めるのは、**要件定義とスキーマ/API 設計の接続部**です。

### 1. カラムの「用途」まで書く

型と制約だけを並べた定義書は、スキーマの写しでしかありません。
mitorizu は各カラムに**用途と参照元**を必須列として持たせます。

| カラム | 型 | 用途 | 参照元 |
| --- | --- | --- | --- |
| `status` | string | 注文の進行状態。バッジ表示とキャンセル可否の判定 | SCR-002(表示), SCR-002(内部) |
| `total_amount` | integer | 注文時点で確定した合計金額。商品価格が変わっても不変 | SCR-002(表示) |

**参照元が書けないカラムは作りません。**

### 2. API レスポンスの過不足を検証する

画面・API・テーブルの3方向を突き合わせ、**不足と過剰の両方**を検出します。

```
screens.md の表示項目 = API レスポンス ⊆ テーブルのカラム + 導出値
```

- **不足**: 画面に表示するが API が返さない -> 画面が描画できない
- **過剰**: API が返すがどの画面でも使わない -> 不要なクエリ・情報漏洩・消せないフィールド

レスポンスの各フィールドには**画面IDを含む用途**が必須です。

| フィールド | 型 | 用途 | 出所 |
| --- | --- | --- | --- |
| `items[].id` | string | SCR-002 詳細への遷移、キャンセルAPIのキー | `orders.id` |
| `items[].cancellable` | boolean | SCR-002 キャンセルボタンの出し分け | `orders.status` から導出 |

### 3. 一気に決めず、ラリーで固める

3〜5問のまとまりで質問し、各ラウンドで**現在地**と**AIの解釈**を提示します。

```
[フェーズ 2/5: データモデル]
確定済み: 認証はメール+パスワード / 多言語対応なし / 想定10万ユーザー
未決: エンティティの粒度、履歴保持の要否
```

1問ずつでは全体像を見失い、一括ドラフトでは AI の独走を許すためです。

### 4. AI の推測を可視化する

全項目に信頼性マーカーを付けます。

| マーカー | 意味 | 対応 |
| --- | --- | --- |
| `[確実]` | 回答・既存コードに明示的な根拠がある | 確認不要 |
| `[推測]` | 一般的な慣行からの補完 | 目視で流す |
| `[要確認]` | 判断材料が不足し仮置きした | **必ず確認する** |

`[要確認]` は各フェーズ末と README に集約されるので、確認すべき箇所だけを追えます。

## インストール

```
/plugin marketplace add https://github.com/joe41203/mitorizu.git
/plugin install mitorizu@mitorizu
```

## 使い方

空リポジトリで、以下の順に実行します。**順序に意味があります。**

```
/mitorizu:requirements     要件定義 + データフロー図
/mitorizu:screens          画面設計 (表示項目を定義)
/mitorizu:data-model       ER図 + テーブル定義 + DDL
/mitorizu:api-design       API 設計 + 3方向の突き合わせ
/mitorizu:infra-diagram    インフラ構成図 (D2)
/mitorizu:docs-index       全成果物の README を生成
```

画面設計 -> データモデル -> API設計 の順で進めることで、
レスポンスの過不足を機械的に検出できます。

## 生成される成果物

```
docs/mitorizu/
  README.md                   全成果物の目次と要約 (これ1枚で全体が分かる)
  glossary.md                 用語集 (ユビキタス言語)
  entities.md                 エンティティカタログ
  decisions.md                確定事項のスナップショット
  adr/                        アーキテクチャ決定記録
  features/<機能>/
    requirements.md           要件定義書 (EARS 記法)
    interview.md              ヒアリング記録
    screens.md                画面設計 (表示項目・操作・遷移)
    dataflow.md               データフロー図 (mermaid)
    data-model.md             ER図 + テーブル定義 + DDL
    api.md                    API 設計 (パス・レスポンス・用途)
    traceability.md           画面 -> API -> テーブル の追跡表
  infra/
    production.d2             インフラ構成図のソース
    production.svg            生成された図
```

## 設計上の選択

| 項目 | 選択 | 理由 |
| --- | --- | --- |
| 要件の記法 | EARS | 曖昧さを排し、そのまま受入基準に変換できる |
| 命名規約 | Rails way (既定) | 既存スキーマがあればそちらを優先 |
| API スタイル | リソース駆動 (REST) | 画面変更のたびに API が変わるのを避ける |
| API 設計書 | Markdown の表 | OpenAPI の YAML は階層が深く用途が埋もれる |
| 通常の図 | mermaid | GitHub でそのまま描画される |
| インフラ図 | D2 | クラウドのアイコンと VPC の入れ子が必要 |

### なぜインフラ図だけ D2 か

mermaid にはクラウドベンダーのサービスアイコンがなく、
VPC -> AZ -> Subnet の入れ子も3段以上で破綻するためです。

D2 には注意点があります。**Mermaid 記法をエラーにせず黙って受理します。**

```d2
a -> b
q -.|bad| r     # Mermaid の点線記法。D2 では無効
```

`d2 validate` は exit 0 を返しますが、実際には `q -.|bad| r` という
**文字列1個のノード**になります。同梱の `verify-d2.sh` が
ノード数・エッジ数を突き合わせてこれを検出します。

## 必要なもの

| ツール | 必須 | 用途 |
| --- | --- | --- |
| Claude Code | 必須 | プラグインの実行 |
| [d2](https://d2lang.com) | 任意 | インフラ図の SVG 生成 |

d2 が無くても `.d2` ソースは生成されます。後から `brew install d2` で図にできます。

## 参考にしたもの

- [classmethod/tsumiki](https://github.com/classmethod/tsumiki) — 信頼性マーカー、サブエージェント委譲によるコンテキスト節約、Plugin への移行
- [AWS Kiro](https://kiro.dev/docs/specs/) — EARS 記法
- [claude-code-requirements-builder](https://github.com/rizethereum/claude-code-requirements-builder) — 段階的な質問による要件抽出
- [github/spec-kit](https://github.com/github/spec-kit) — 原則を先に固定してから仕様を書く構成

## ライセンス

[MIT](./LICENSE)
