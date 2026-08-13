# API 設計書テンプレート

`docs/mitorizu/features/<feature-slug>/api.md` の雛形。

**この文書の目的は「どんなパスで、何を返し、何に使われるか」を一覧できること。**
OpenAPI の YAML は階層が深く用途が埋もれるため、表形式を主とする。

---

# API 設計: <機能名>

- 機能スラッグ: `<feature-slug>`
- 作成日: YYYY-MM-DD
- 対応: `requirements.md` / `screens.md` / `data-model.md`
- ベースURL: `/api/v1`

## 1. エンドポイント一覧

まず全体を1つの表で見せる。詳細は後続の節に書く。

| # | メソッド | パス | 概要 | 使う画面 | 要件ID |
| --- | --- | --- | --- | --- | --- |
| 1 | GET | `/orders` | 注文一覧 | SCR-002 | REQ-004 |
| 2 | GET | `/orders/{id}` | 注文詳細 | SCR-003 | REQ-005 |
| 3 | POST | `/orders` | 注文作成 | SCR-004 | REQ-001 |
| 4 | POST | `/orders/{id}/cancel` | 注文キャンセル | SCR-002, SCR-003 | REQ-008 |

**使う画面が空欄のエンドポイントは作らない。**

## 2. エンドポイント詳細

### 1. GET /orders — 注文一覧

- 使う画面: SCR-002 注文一覧
- 対応要件: REQ-004
- 認証: 必要
- 権限: ログインユーザー (自分の注文のみ)

#### リクエスト

| パラメータ | 位置 | 型 | 必須 | 既定 | 説明 | 対応する画面項目 |
| --- | --- | --- | --- | --- | --- | --- |
| `page` | query | integer | 任意 | 1 | ページ番号 | SCR-002 ページネーション |
| `per` | query | integer | 任意 | 20 | 1ページ件数 (最大100) | SCR-002 ページネーション |
| `status` | query | string | 任意 | - | ステータス絞り込み | SCR-002 絞り込み |

#### レスポンス (200)

**この表が本体。** 各フィールドが何に使われ、どこから来るかを示す。

| フィールド | 型 | 用途 (画面ID必須) | 出所 |
| --- | --- | --- | --- |
| `items[].id` | string | SCR-002 詳細画面への遷移、キャンセルAPIのキー | `orders.id` |
| `items[].number` | string | SCR-002 注文番号列に表示 | `orders.number` |
| `items[].ordered_at` | string(date-time) | SCR-002 注文日列に表示 | `orders.ordered_at` |
| `items[].status` | string(enum) | SCR-002 ステータスバッジに表示 | `orders.status` |
| `items[].total_amount` | integer | SCR-002 合計金額列に表示 (円・税込) | `orders.total_amount` |
| `items[].cancellable` | boolean | SCR-002 キャンセルボタンの出し分け | `orders.status` から導出 |
| `items[].customer.id` | string | SCR-002 顧客詳細への遷移 | `users.id` (関連) |
| `items[].customer.name` | string | SCR-002 顧客名列に表示 | `users.name` (関連) |
| `meta.total` | integer | SCR-002 「全N件」の表示 | `orders` の COUNT (導出) |
| `meta.page` | integer | SCR-002 ページネーション | リクエストのエコー |
| `meta.per` | integer | SCR-002 ページネーション | リクエストのエコー |

**用途に画面IDが無いフィールドは載せない。**
「将来使うかもしれない」「あると便利」は用途ではない。

顧客名を埋め込んでいるのは、一覧で N+1 リクエストを起こさないため。

#### レスポンス例

```json
{
  "items": [
    {
      "id": "01J8XZ...",
      "number": "ORD-20260814-0001",
      "ordered_at": "2026-08-14T03:21:00Z",
      "status": "pending",
      "total_amount": 12800,
      "cancellable": true,
      "customer": {
        "id": "01J8AA...",
        "name": "山田 太郎"
      }
    }
  ],
  "meta": { "total": 42, "page": 1, "per": 20 }
}
```

#### エラー

| HTTP | code | 発生条件 | 要件ID |
| --- | --- | --- | --- |
| 401 | `UNAUTHORIZED` | 未認証 | REQ-015 |

---

### 4. POST /orders/{id}/cancel — 注文キャンセル

- 使う画面: SCR-002 注文一覧, SCR-003 注文詳細
- 対応要件: REQ-008
- 認証: 必要
- 権限: 注文者本人のみ

`PATCH /orders/{id}` で `status` を直接書き換えさせないのは、
不正な状態遷移を防ぐため。業務上の意味を持つ操作は専用パスにする。

#### リクエスト

| パラメータ | 位置 | 型 | 必須 | 説明 |
| --- | --- | --- | --- | --- |
| `id` | path | string | 必須 | 注文ID |
| `reason` | body | string | 任意 | キャンセル理由 (SCR-003 の入力項目) |

#### レスポンス (200)

| フィールド | 型 | 用途 (画面ID必須) | 出所 |
| --- | --- | --- | --- |
| `id` | string | SCR-002 一覧の該当行を更新 | `orders.id` |
| `status` | string(enum) | SCR-002 バッジを cancelled に更新 | `orders.status` |
| `cancellable` | boolean | SCR-002 ボタンを非活性にする | `orders.status` から導出 |
| `cancelled_at` | string(date-time) | SCR-003 キャンセル日時を表示 | `orders.cancelled_at` |

#### エラー

| HTTP | code | 発生条件 | 要件ID |
| --- | --- | --- | --- |
| 403 | `FORBIDDEN` | 他人の注文 | REQ-015 |
| 404 | `NOT_FOUND` | 注文が存在しない | - |
| 409 | `INVALID_STATE_TRANSITION` | 既にキャンセル済み / 発送済み | REQ-008 |

---

## 3. 共通仕様

### 認証

`Authorization: Bearer <token>`

### エラーレスポンスの形式

全エンドポイントで共通。

```json
{
  "code": "VALIDATION_FAILED",
  "message": "入力内容に誤りがあります",
  "details": [
    { "field": "quantity", "message": "1以上を指定してください" }
  ]
}
```

### エラーコード一覧

| HTTP | code | 意味 | 対応要件 |
| --- | --- | --- | --- |
| 400 | `BAD_REQUEST` | リクエスト形式が不正 | - |
| 401 | `UNAUTHORIZED` | 未認証 | REQ-015 |
| 403 | `FORBIDDEN` | 権限なし | REQ-015 |
| 404 | `NOT_FOUND` | リソースが存在しない | - |
| 409 | `INVALID_STATE_TRANSITION` | 不正な状態遷移 | REQ-008 |
| 422 | `VALIDATION_FAILED` | バリデーションエラー | REQ-012 |
| 422 | `OUT_OF_STOCK` | 在庫不足 | REQ-010 |

### 命名規約

| 対象 | 規約 | 例 |
| --- | --- | --- |
| パス | ケバブケース・複数形 | `/order-items` |
| JSONキー | スネークケース | `total_amount` |
| 日時 | ISO 8601 UTC | `2026-08-14T03:21:00Z` |
| 金額 | integer (最小単位) | `12800` (円) |

JSONキーをスネークケースにするのは Rails の慣習に合わせるため。
camelCase にすると変換層が必要になる。

### ページネーション

MVP では offset 方式 (`page` / `per`) を使う。
実装が単純で総件数を表示できる。数万件を超える見込みなら cursor 方式を検討する。

## 4. 設計上の決定

| 論点 | 決定 | 理由 | マーカー |
| --- | --- | --- | --- |
| API スタイル | リソース駆動 (REST) | 画面変更のたびに API が変わるのを避ける | [確実] |
| 関連データ | 画面表示に必要な分は埋め込む | 一覧での N+1 を防ぐ | [確実] |
| 状態変更 | 専用パス (`/cancel`) | PATCH での直接書き換えは不正遷移を招く | [確実] |
| バージョニング | パスに含める (`/api/v1`) | MVP では v1 のみ | [確実] |

## 5. 要確認項目

| 項目 | 内容 | 仮置きした値 | 確認すべきこと |
| --- | --- | --- | --- |
| `per` の上限 | 1ページの最大件数 | 100 | 性能上の妥当性 |

## 6. 検証

`traceability.md` で以下が全て0件であることを確認する。

| 検証 | 件数 |
| --- | --- |
| 不足 (画面にあるが API に無い) | 0 |
| 過剰 (API にあるが画面で使わない) | 0 |
| 出所不明 (API にあるがテーブルに無い) | 0 |

**0件でなければ API 設計は完了していない。**
