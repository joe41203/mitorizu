# D2 でインフラ構成図を書く

インフラ構成図だけ D2 を使う。mermaid にはクラウドベンダーのサービスアイコンがなく、
VPC -> AZ -> Subnet の入れ子も 3 段以上で破綻するため。

- 公式: https://d2lang.com
- リポジトリ: https://github.com/d2lang/d2 (旧 `terrastruct/d2` からリネーム済み)
- アイコンカタログ: https://icons.d2lang.com
- ライセンス: MPL-2.0

## 最重要: D2 は Mermaid 記法を黙って受理する

**`d2 validate` が通っても、意図した図とは限らない。**

以下は実測で確認した挙動。

```d2
a -> b
q -.|bad| r
```

`q -.|bad| r` は Mermaid の点線エッジ記法で、D2 では無効。しかし:

```
$ d2 validate trap.d2
Success! [trap.d2] is valid D2.
$ echo $?
0
```

エラーにならない。生成された図を数えると **ノードが3個**ある。
`a` と `b` に加えて、`q -.|bad| r` という**文字列そのものが1個のノード**になっている。
期待した「q から r への点線エッジ」ではない。

LLM は Mermaid を書き慣れているため、この混入が起きやすい。
**`d2 validate` だけを検証手段にしてはいけない。**

### 対策: 3段構えで検証する

1. **`d2 validate <file>`** — 構文エラーを検出 (exit 0/1)
2. **ノード数・エッジ数の期待値チェック** — validate をすり抜けた混入を検出
3. **生成した SVG を目視** — レイアウト崩れを検出

ノード数・エッジ数の数え方 (実測で確認済み):

```bash
d2 <file>.d2 <file>.svg
echo -n "shapes: "; grep -o 'class="shape"' <file>.svg | wc -l
echo -n "edges : "; grep -oE 'marker-end' <file>.svg | wc -l
```

- **ノード数**: `class="shape"` の数。**コンテナも1個として数えられる**点に注意
- **エッジ数**: `marker-end` (矢印マーカー) の数。`class="connection"` という属性は存在しない

図を書く前に「ノードN個、エッジM個になるはず」と宣言し、生成後に突き合わせる。
食い違ったら Mermaid 記法の混入を疑う。

前述の罠ケースで実際に検出できることを確認済み:

| ケース | 期待 | 実測 shapes | 実測 edges | 判定 |
| --- | --- | --- | --- | --- |
| `a -> b` / `q -.\|bad\| r` (Mermaid混入) | 4ノード2エッジ | 3 | 1 | **不一致 = 検出成功** |
| `a -> b` / `q -> r: bad` (正しい) | 4ノード2エッジ | 4 | 2 | 一致 |

`d2 validate` は前者も exit 0 で通すため、この数値チェックが唯一の検出手段になる。

### Mermaid 記法との対応表

D2 を書くときに間違えやすい箇所。

| やりたいこと | Mermaid (誤) | D2 (正) |
| --- | --- | --- |
| 実線エッジ | `A --> B` | `A -> B` |
| ラベル付きエッジ | `A -->|label| B` | `A -> B: label` |
| 点線エッジ | `A -.-> B` | `A -> B: {style.stroke-dash: 3}` |
| 双方向 | `A <--> B` | `A <-> B` |
| グループ化 | `subgraph id["label"]` | `id: label { ... }` |
| ノードのラベル | `A[Label]` | `A: Label` |
| コメント | `%% comment` | `# comment` |

## 基本構文

### ノードとエッジ

```d2
alb: Application Load Balancer
api: API Server
db: PostgreSQL

alb -> api: HTTPS
api -> db: TCP 5432
```

### ネスト (コンテナ)

`{}` で入れ子にする。`.` でパス参照、`_` で親参照。

```d2
vpc: VPC 10.0.0.0/16 {
  az_a: ap-northeast-1a {
    public_a: Public Subnet {
      natgw: NAT Gateway
    }
    private_a: Private Subnet {
      ecs_a: ECS Task
    }
  }
  az_c: ap-northeast-1c {
    private_c: Private Subnet {
      ecs_c: ECS Task
    }
  }
}

vpc.az_a.private_a.ecs_a -> vpc.az_a.public_a.natgw
```

4階層のネストが実測で問題なく描画できることを確認済み。

### アイコン

`icon:` 属性に URL かローカルパスを指定する。

```d2
ecs: ECS Fargate {
  icon: ./icons/aws-ecs.svg
  shape: image
}
```

公式カタログ https://icons.d2lang.com から URL を取得できる。
URL 指定の場合はエンコードが必要:

```d2
deploy: {
  icon: https://icons.d2lang.com/aws%2FDeveloper%20Tools%2FAWS-CodeDeploy.svg
}
```

**アイコンはリポジトリ内にローカル配置することを推奨する。**
理由は次項。

## 運用ルール

### 1. アイコンはローカルに置く

アイコンは**ビルド時に取得され base64 で SVG に埋め込まれる**。
つまり出力 SVG は自己完結し閲覧時にネットワーク不要だが、**ビルド時はネットワーク必須**。

オフラインや制限環境では `failed to bundle remote images` で失敗する。
CI を安定させるため、使うアイコンは `icons/` に落としてから `icon: ./icons/*.svg` で参照する。

### 2. 出力は SVG に統一する

**PNG 出力は Chromium の自動ダウンロードが必要**で、CI が壊れる。

```
D2 needs to install Chromium v149... Continue? (y/N)
```

SVG なら追加依存なしで出力できる。PNG がどうしても必要なら Playwright を事前導入する。

### 3. レイアウトエンジンは dagre か elk

同梱されているのはこの2つ。既定は dagre。

```bash
d2 --layout=elk input.d2 output.svg
```

**TALA は proprietary かつ有料**。無ライセンスでは透かし付きレンダリングになるため、
生成する図が TALA を前提にしてはいけない。
TALA 限定機能 (`top`/`left` の位置固定、`near` のオブジェクト指定、
コンテナ毎の `direction`) は使わない。

### 4. dagre の制約に注意

**dagre は親コンテナから子への接続が機能しない。**
構成図で踏みやすい。以下は期待通りに描画されない:

```d2
vpc: VPC {
  subnet: Subnet
}
vpc -> vpc.subnet    # dagre では機能しない
```

コンテナ間の接続は、末端ノード同士で結ぶか、`--layout=elk` を使う。

### 5. GitHub ではレンダリングされない

GitHub の Markdown が公式サポートする図は Mermaid のみ。
` ```d2 ` と書いても図にならない。

`.d2` ソースと生成した `.svg` の**両方をコミット**し、Markdown から画像参照する:

```markdown
![インフラ構成図](./mitorizu-infra.svg)
```

`.d2` をレビュー対象とし、`.svg` は生成物として扱う。

### 6. d2 fmt で整形を正規化する

```bash
d2 fmt <file>.d2
```

差分ノイズが減り、PR のレビューがしやすくなる。生成後に必ず実行する。

## 生成フロー

```bash
# 1. 期待値を宣言してから書く (ノードN個、エッジM個)
# 2. 構文検証
d2 validate infra.d2 || exit 1

# 3. 整形
d2 fmt infra.d2

# 4. SVG 生成
d2 infra.d2 infra.svg

# 5. ノード数の突き合わせ (Mermaid記法混入の検出)
grep -o 'class="shape"' infra.svg | wc -l
```

## d2 が未インストールの場合

プラグイン利用者に d2 を必須にしない。

- `d2` コマンドの有無を検出する (`command -v d2`)
- 無ければ `.d2` ソースのみ出力し、SVG 生成はスキップする
- Markdown には「SVG 生成には d2 が必要」という注記と、インストール手順を書く

```bash
brew install d2
```

ソースさえあれば後からいつでも生成できる。

## 完全な例

```d2
direction: right

users: Users {
  shape: person
}

cf: CloudFront
s3: S3 (static)

vpc: VPC 10.0.0.0/16 {
  alb: ALB

  az_a: ap-northeast-1a {
    private_a: Private Subnet {
      ecs_a: ECS Task
    }
  }

  az_c: ap-northeast-1c {
    private_c: Private Subnet {
      ecs_c: ECS Task
    }
  }

  rds: RDS PostgreSQL (Multi-AZ)
}

users -> cf: HTTPS
cf -> s3: static assets
cf -> vpc.alb: /api/*
vpc.alb -> vpc.az_a.private_a.ecs_a
vpc.alb -> vpc.az_c.private_c.ecs_c
vpc.az_a.private_a.ecs_a -> vpc.rds
vpc.az_c.private_c.ecs_c -> vpc.rds
```

**期待値: shapes 12、edges 7** (実測で確認済み)。

shapes の内訳はコンテナを含む全12個:
`users` `cf` `s3` `vpc` `alb` `az_a` `private_a` `ecs_a` `az_c` `private_c` `ecs_c` `rds`。
コンテナ (`vpc` `az_a` `private_a` `az_c` `private_c`) も1個として数えられるため、
「末端ノードだけ」で数えると合わない。

検証コマンド:

```bash
d2 validate example.d2                                   # exit 0
d2 example.d2 example.svg                                # 約90ms
grep -o 'class="shape"' example.svg | wc -l              # 12
grep -oE 'marker-end' example.svg | wc -l                # 7
d2 --layout=elk example.d2 example-elk.svg               # elk でも描画可
```

dagre と elk の両方で描画できることを確認済み。
