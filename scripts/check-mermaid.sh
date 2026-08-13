#!/usr/bin/env bash
# Markdown 内の ```mermaid ブロックを mmdc で検証する。
#
# 使い方:
#   check-mermaid.sh <file.md> [file2.md ...]
#
# mmdc (mermaid-cli) が未インストールの場合は検証をスキップして exit 0。
# 利用者に mermaid-cli を必須にしないため。
#
# 終了コード:
#   0 全ブロック合格、または mmdc 未導入でスキップ
#   1 いずれかのブロックが不正
#   2 引数エラー

set -uo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <file.md> [file2.md ...]" >&2
  exit 2
fi

if ! command -v mmdc >/dev/null 2>&1; then
  echo "mmdc が未インストールのため Mermaid の検証をスキップしました。"
  echo "  検証するには:"
  echo "    brew install mermaid-cli"
  echo "    # または npm install -g @mermaid-js/mermaid-cli"
  exit 0
fi

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

STATUS=0

for FILE in "$@"; do
  if [ ! -f "$FILE" ]; then
    echo "error: not found: $FILE" >&2
    STATUS=1
    continue
  fi

  n=0
  in_block=0
  buf=""
  found=0

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$in_block" -eq 1 ]; then
      if [ "$line" = '```' ]; then
        in_block=0
        n=$((n + 1))
        found=1
        printf '%s' "$buf" > "$TMPDIR_WORK/block.mmd"
        if ! mmdc -i "$TMPDIR_WORK/block.mmd" -o "$TMPDIR_WORK/out.svg" \
             >/dev/null 2>"$TMPDIR_WORK/err"; then
          echo "FAIL $FILE :: block_$n" >&2
          sed 's/^/    /' "$TMPDIR_WORK/err" >&2
          STATUS=1
        fi
        buf=""
      else
        buf="${buf}${line}"$'\n'
      fi
    elif [ "$line" = '```mermaid' ]; then
      in_block=1
    fi
  done < "$FILE"

  if [ "$found" -eq 1 ]; then
    echo "checked: $FILE ($n ブロック)"
  fi
done

exit "$STATUS"
