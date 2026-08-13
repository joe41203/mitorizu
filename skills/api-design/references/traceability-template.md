# 追跡表テンプレート

`docs/mitorizu/features/<feature-slug>/traceability.md` の雛形。

**このドキュメントが「レスポンスの過不足ゼロ」を保証する。**

---

# 追跡表: <機能名>

- 機能スラッグ: `<feature-slug>`
- 作成日: YYYY-MM-DD
- 検証対象: `screens.md` / `data-model.md` / `openapi.yaml`

## 検証する不変条件

```
screens.md の表示項目  =  API レスポンスのフィールド  ⊆  テーブルのカラム + 導出値
```

- **左の等号**: 不足も過剰も許さない
- **右の包含**: レスポンスは必ずデータモデルに裏付けられる

## 1. 不足の検出 (画面 -> API)

`screens.md` の全表示項目が、いずれかの API レスポンスに含まれるか。

### SCR-002 注文一覧

| 表示項目 | 表示/非表示 | 対応する API フィールド | 判定 |
| --- | --- | --- | --- |
| 注文番号 | 表示 | `GET /orders` -> `items[].number` | OK |
| 注文日 | 表示 | `GET /orders` -> `items[].ordered_at` | OK |
| 顧客名 | 表示 | `GET /orders` -> `items[].customer.name` | OK |
| 合計金額 | 表示 | `GET /orders` -> `items[].total_amount` | OK |
| ステータス | 表示 | `GET /orders` -> `items[].status` | OK |
| (ID) | 非表示 | `GET /orders` -> `items[].id` | OK |
| (キャンセル可否) | 非表示 | `GET /orders` -> `items[].cancellable` | OK |
| 総件数 | 表示 | `GET /orders` -> `meta.total` | OK |

### SCR-003 注文詳細

(同じ構造を繰り返す)

**不足: 0件**

不足がある場合はここに列挙し、対応を決める。

| 不足項目 | 画面 | 対応 |
| --- | --- | --- |
| <項目名> | SCR-NNN | `GET /xxx` のレスポンスに追加 |

## 2. 過剰の検出 (API -> 画面)

API レスポンスの全フィールドが、いずれかの画面で使われるか。

### GET /api/v1/orders

| フィールド | 用途 (画面ID必須) | 判定 |
| --- | --- | --- |
| `items[].id` | SCR-002 詳細への遷移、キャンセルAPIのキー | OK |
| `items[].number` | SCR-002 注文番号列に表示 | OK |
| `items[].ordered_at` | SCR-002 注文日列に表示 | OK |
| `items[].status` | SCR-002 ステータスバッジ表示 | OK |
| `items[].total_amount` | SCR-002 合計金額列に表示 | OK |
| `items[].cancellable` | SCR-002 キャンセルボタンの出し分け | OK |
| `items[].customer.id` | SCR-002 顧客詳細への遷移 | OK |
| `items[].customer.name` | SCR-002 顧客名列に表示 | OK |
| `meta.total` | SCR-002 総件数表示 | OK |
| `meta.page` | SCR-002 ページネーション | OK |

### GET /api/v1/orders/{id}

(同じ構造を繰り返す)

**過剰: 0件**

過剰がある場合はここに列挙し、対応を決める。

| 過剰フィールド | API | 対応 |
| --- | --- | --- |
| `items[].internal_memo` | GET /orders | **削除** (どの画面でも使わない) |

過剰の対応は2択。ユーザーに確認する。

- **A: フィールドを削除する** (推奨)
- **B: 画面設計に用途を追記する** — どの画面で何に使うかを `screens.md` に書く

「将来使うかもしれない」「あると便利」は用途として認めない。

## 3. 出所の確認 (API -> テーブル)

API レスポンスの全フィールドが、テーブルのカラムか導出値であるか。

| フィールド | 出所 | data-model.md に存在 | 判定 |
| --- | --- | --- | --- |
| `items[].id` | `orders.id` | あり | OK |
| `items[].number` | `orders.number` | あり | OK |
| `items[].total_amount` | `orders.total_amount` | あり | OK |
| `items[].cancellable` | `orders.status` から導出 | 導出元あり | OK |
| `items[].customer.name` | `users.name` (関連) | あり | OK |
| `meta.total` | `orders` の COUNT (導出) | 導出可能 | OK |

**出所不明: 0件**

出所が無いフィールドは、以下のいずれかで対応する。

| フィールド | 対応 |
| --- | --- |
| <フィールド> | `data-model.md` にカラムを追加 / フィールドを削除 |

## 4. カラムの利用状況 (テーブル -> API)

**逆方向の確認。** どの API でも返されないカラムを洗い出す。

これは必ずしも異常ではない (内部利用のカラムは正常)。
ただし「作ったが誰も使わないカラム」の検出には有効。

| カラム | API での利用 | 判定 |
| --- | --- | --- |
| `orders.id` | GET /orders, GET /orders/{id} | 利用中 |
| `orders.number` | GET /orders, GET /orders/{id} | 利用中 |
| `orders.user_id` | 関連の解決に使用 (直接は返さない) | 内部利用 |
| `orders.created_at` | 返さない | 監査用 (正常) |
| `orders.updated_at` | 返さない | 監査用 (正常) |
| `orders.internal_flag` | **返さない・用途不明** | **要確認** |

「要確認」が出た場合、そのカラムが本当に必要かをユーザーに確認する。

## 5. 検証サマリ

| 検証 | 件数 | 状態 |
| --- | --- | --- |
| 不足 (画面にあるが API に無い) | 0 | OK |
| 過剰 (API にあるが画面で使わない) | 0 | OK |
| 出所不明 (API にあるがテーブルに無い) | 0 | OK |
| 未使用カラム (テーブルにあるが誰も使わない) | 0 | OK |

**全て0件でなければ、API 設計は完了していない。**

## 6. 権限による差分

権限によってレスポンスが変わる場合、ロールごとに検証する。

| フィールド | 一般ユーザー | 管理者 | 根拠 |
| --- | --- | --- | --- |
| `items[].total_amount` | 返す | 返す | SCR-002 全ロールで表示 |
| `items[].cost` | **返さない** | 返す | SCR-002 管理者のみ表示 |

**権限で返さないフィールドは、レスポンスから完全に除外する。**
`null` で返すと、フィールドの存在自体が情報漏洩になる場合がある。
