#!/usr/bin/env bash
# D2 ファイルを検証し、SVG を生成する。
#
# 使い方:
#   verify-d2.sh <file.d2> [期待ノード数] [期待エッジ数]
#
# d2 validate は Mermaid 記法を黙って受理するため、
# ノード数・エッジ数の突き合わせを併用する。
# 期待値を省略した場合は数を表示するだけで判定しない。

set -uo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <file.d2> [expected_shapes] [expected_edges]" >&2
  exit 2
fi

SRC="$1"
EXPECTED_SHAPES="${2:-}"
EXPECTED_EDGES="${3:-}"

if [ ! -f "$SRC" ]; then
  echo "error: not found: $SRC" >&2
  exit 2
fi

# d2 を探す。プロジェクトローカルを優先する。
# /mitorizu:init で導入した場合は .mitorizu/bin/ に置かれる。
if [ -x ".mitorizu/bin/d2" ]; then
  D2=".mitorizu/bin/d2"
elif command -v d2 >/dev/null 2>&1; then
  D2="d2"
else
  echo "d2 が見つからないため SVG 生成をスキップしました。"
  echo "  .d2 ソースはそのまま利用できます。図が必要になったら:"
  echo "    /mitorizu:init          プロジェクトローカルに導入する (推奨)"
  echo "    brew install d2         システムに導入する"
  echo "  導入後: d2 $SRC ${SRC%.d2}.svg"
  exit 0
fi

OUT="${SRC%.d2}.svg"

# 1. 構文検証
if ! "$D2" validate "$SRC"; then
  echo "FAIL: 構文エラー" >&2
  exit 1
fi

# 2. 整形 (差分ノイズを減らす)
"$D2" fmt "$SRC" >/dev/null 2>&1 || true

# 3. SVG 生成
if ! "$D2" "$SRC" "$OUT" >/dev/null 2>&1; then
  echo "FAIL: レンダリングに失敗しました" >&2
  exit 1
fi

# 4. ノード数・エッジ数の突き合わせ
#    d2 validate をすり抜ける Mermaid 記法の混入を検出する
SHAPES=$(grep -o 'class="shape"' "$OUT" | wc -l | tr -d ' ')
EDGES=$(grep -oE 'marker-end' "$OUT" | wc -l | tr -d ' ')

echo "生成: $OUT"
echo "  shapes: $SHAPES"
echo "  edges : $EDGES"

STATUS=0

if [ -n "$EXPECTED_SHAPES" ] && [ "$SHAPES" != "$EXPECTED_SHAPES" ]; then
  echo "FAIL: ノード数が期待値と異なります (期待 $EXPECTED_SHAPES / 実際 $SHAPES)" >&2
  echo "  Mermaid 記法の混入を疑ってください。" >&2
  echo "  例: 'A -->|label| B' は D2 では 'A -> B: label' と書きます。" >&2
  STATUS=1
fi

if [ -n "$EXPECTED_EDGES" ] && [ "$EDGES" != "$EXPECTED_EDGES" ]; then
  echo "FAIL: エッジ数が期待値と異なります (期待 $EXPECTED_EDGES / 実際 $EDGES)" >&2
  STATUS=1
fi

if [ "$STATUS" -eq 0 ] && [ -n "$EXPECTED_SHAPES" ]; then
  echo "OK: 期待値と一致しました"
fi

exit "$STATUS"
