---
name: infra-diagram
description: D2 でインフラ構成図を作る。VPC やサブネットの入れ子とクラウドのアイコンを扱えるため mermaid ではなく D2 を使う。生成した SVG を Markdown から参照できる形で出力する。
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

# インフラ構成図

D2 でインフラ構成図を作る。

**インフラ図だけ mermaid ではなく D2 を使う。**
mermaid にはクラウドベンダーのサービスアイコンがなく、
VPC -> AZ -> Subnet の入れ子も3段以上で破綻するため。

**書き方と落とし穴は `${CLAUDE_PLUGIN_ROOT}/references/d2-guide.md` を必ず読むこと。**
特に「D2 は Mermaid 記法を黙って受理する」という罠は必ず把握しておく。

## 前提

`requirements.md` があること。非機能要件があればそれも読む。
無くても構成図は作れるが、可用性・性能の要件が分からないと
冗長化の要否を判断できない。

## 成果物

```
docs/mitorizu/infra/
  <name>.d2          # ソース (レビュー対象)
  <name>.svg         # 生成物
  README.md          # 図の説明と Markdown からの参照
```

## 進め方

### Phase 1: 構成の方針を決める

MVP のインフラは**小さく始める**。最初から冗長化・マイクロサービス化しない。

ユーザーに確認する (1問ずつ。重い分岐なので)。

1. **クラウドはどれか** — AWS / GCP / Azure / VPS / PaaS
2. **アプリの実行基盤** — コンテナ (ECS/Cloud Run) / PaaS (Heroku/Render) / VM
3. **可用性の要件** — 単一AZで十分か、Multi-AZ が必要か

MVP での推奨は以下。**過剰な構成を提案しない。**

| 項目 | MVP の推奨 | 理由 |
| --- | --- | --- |
| 実行基盤 | PaaS または単一コンテナ | 運用コストが低い |
| DB | マネージド (RDS/Cloud SQL) の最小構成 | バックアップと復旧を任せられる |
| 冗長化 | 単一AZ | Multi-AZ はコストが倍。要件が出てから |
| CDN | 静的アセットのみ | 動的コンテンツのキャッシュは後回し |
| キャッシュ | 使わない | 必要になってから足す |

**後から変えるのが高コストなものだけ、最初から設計に織り込む。**

| 項目 | 後付けの難易度 | MVP での扱い |
| --- | --- | --- |
| VPC の CIDR 設計 | **高** (作り直しが必要) | 最初に決める |
| DB の種類 | **高** (移行が必要) | 最初に決める |
| リージョン | **高** | 最初に決める |
| 冗長化 | 低 | 後回し可 |
| CDN | 低 | 後回し可 |
| 監視 | 低 | 後回し可 |

### Phase 2: 図を書く前に期待値を宣言する

**D2 を書く前に「ノード N 個、エッジ M 個になるはず」を宣言する。**

これは `d2 validate` をすり抜ける Mermaid 記法の混入を検出するために必須。
検証時にこの数と実際の生成結果を突き合わせる。

ノード数の数え方に注意する。**コンテナも1個として数えられる。**

```
vpc: VPC {          <- これも1個
  subnet: Subnet {  <- これも1個
    ecs: ECS Task   <- これも1個
  }
}
```
上記は shapes 3 と数えられる。

### Phase 3: D2 を書く

`${CLAUDE_PLUGIN_ROOT}/references/d2-guide.md` の構文に従う。

**Mermaid 記法を混ぜない。** 特に間違えやすいもの:

| Mermaid (誤) | D2 (正) |
| --- | --- |
| `A --> B` | `A -> B` |
| `A -->\|label\| B` | `A -> B: label` |
| `A -.-> B` | `A -> B: {style.stroke-dash: 3}` |
| `subgraph id["label"]` | `id: label { ... }` |
| `%% comment` | `# comment` |

基本形:

```d2
direction: right

users: Users {
  shape: person
}

vpc: VPC 10.0.0.0/16 {
  alb: ALB
  az_a: ap-northeast-1a {
    private_a: Private Subnet {
      app: App Container
    }
  }
  db: RDS PostgreSQL
}

users -> vpc.alb: HTTPS
vpc.alb -> vpc.az_a.private_a.app
vpc.az_a.private_a.app -> vpc.db: 5432
```

### Phase 4: 検証する

**`d2 validate` だけでは不十分。** 必ず期待値と突き合わせる。

同梱のスクリプトを使う。

```bash
"${CLAUDE_SKILL_DIR}/scripts/verify-d2.sh" docs/mitorizu/infra/<name>.d2 <期待shapes> <期待edges>
```

このスクリプトは以下を行う。

1. `d2 validate` で構文検証
2. `d2 fmt` で整形 (差分ノイズを減らす)
3. SVG 生成
4. **shapes / edges を数えて期待値と突き合わせる**
5. d2 未インストールなら SVG 生成をスキップし、案内を出す

期待値と食い違ったら Mermaid 記法の混入を疑い、修正して再実行する。

期待値が分からない場合は省略できる。その場合は数を表示するだけで判定しない。

```bash
"${CLAUDE_SKILL_DIR}/scripts/verify-d2.sh" docs/mitorizu/infra/<name>.d2
```

### Phase 5: Markdown から参照できる形にする

**GitHub は D2 をネイティブレンダリングしない。**
` ```d2 ` と書いても図にならないため、SVG を生成して画像参照する。

`docs/mitorizu/infra/README.md` を作る。

```markdown
# インフラ構成

## 本番環境

![本番環境の構成](./production.svg)

構成の意図:
- ALB で HTTPS を終端し、プライベートサブネットのコンテナへ転送する
- DB はプライベートサブネットに置き、外部から直接アクセスできない
- MVP のため単一 AZ。可用性要件が出たら Multi-AZ にする

ソース: [production.d2](./production.d2)

図を再生成する:

    d2 production.d2 production.svg
```

**`.d2` と `.svg` の両方をコミットする。**
`.d2` をレビュー対象とし、`.svg` は生成物として扱う。

### Phase 6: 確認

1. `[要確認]` を一覧で再掲する
2. `docs/mitorizu/decisions.md` に確定事項を追記する
3. **`docs/mitorizu/README.md` の「6. インフラ構成」を更新する**
   - SVG への画像参照を貼る (`![](./infra/production.svg)`)
   - 構成の意図を数行で書く
   - 後から変更が高コストな決定 (リージョン、VPC CIDR、DB の種類) を表にする
   - 該当節のみを更新し、他の節には触れない
4. 後から変更が高コストな決定は ADR に記録するよう案内する

## d2 が未インストールの場合

**利用者に d2 を必須にしない。**

- `.d2` ソースは必ず出力する
- SVG 生成はスキップし、インストール手順を案内する
- `README.md` には「図の生成には d2 が必要」と注記する

```bash
brew install d2
```

ソースさえあれば後からいつでも生成できる。
同梱の `verify-d2.sh` は d2 が無い場合に exit 0 で案内だけ出す。

## 描く対象

MVP では以下を1枚に収める。分けすぎない。

- 利用者からのトラフィックの入り口 (CDN / LB)
- アプリケーションの実行基盤
- データストア (DB / オブジェクトストレージ)
- 外部サービス (決済・メール送信など)
- ネットワーク境界 (VPC / サブネット)

**書かないもの** (MVP では過剰):

- 個々の IAM ロール
- 詳細なセキュリティグループのルール
- CI/CD パイプライン (別図にする)
- 監視・ログの経路 (別図にする)

## 参照

- `${CLAUDE_PLUGIN_ROOT}/references/d2-guide.md` — D2 の構文、落とし穴、運用ルール
- `${CLAUDE_SKILL_DIR}/scripts/verify-d2.sh` — 検証スクリプト
- `${CLAUDE_PLUGIN_ROOT}/references/conventions.md` — 信頼性マーカー、対話規約
