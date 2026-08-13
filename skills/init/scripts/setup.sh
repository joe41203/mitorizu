#!/usr/bin/env bash
# mitorizu の実行環境を準備する。
#
# 使い方:
#   setup.sh --check        現状を報告するだけ (何もインストールしない)
#   setup.sh --install-d2   d2 を .mitorizu/bin/ に導入する
#
# システムには何もインストールしない。全て .mitorizu/bin/ 配下に置く。
# アンインストールは rm -rf .mitorizu だけで済む。

set -uo pipefail

LOCAL_DIR=".mitorizu/bin"
D2_REPO="d2lang/d2"

usage() {
  cat <<'USAGE'
usage: setup.sh [--check | --install-d2]

  --check        現状を報告する (ダウンロードしない)
  --install-d2   d2 をプロジェクトローカルに導入する
USAGE
}

# OS とアーキテクチャを d2 のリリース資産名に合わせる
detect_platform() {
  local os arch
  case "$(uname -s)" in
    Darwin) os="macos" ;;
    Linux)  os="linux" ;;
    MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    *) echo "unsupported OS: $(uname -s)" >&2; return 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64)  arch="amd64" ;;
    *) echo "unsupported arch: $(uname -m)" >&2; return 1 ;;
  esac
  echo "${os}-${arch}"
}

# 最新リリースの tar.gz URL を取得する。
# GitHub API を使い、curl | sh 形式のインストーラは使わない。
fetch_d2_url() {
  local platform="$1"
  local api="https://api.github.com/repos/${D2_REPO}/releases/latest"

  curl -fsSL "$api" 2>/dev/null \
    | grep -o "https://github.com/${D2_REPO}/releases/download/[^\"]*${platform}\.tar\.gz" \
    | head -1
}

find_d2() {
  if [ -x "${LOCAL_DIR}/d2" ]; then
    echo "${LOCAL_DIR}/d2"
  elif command -v d2 >/dev/null 2>&1; then
    command -v d2
  fi
}

do_check() {
  local platform d2_path url
  platform=$(detect_platform) || return 1

  echo "環境:"
  echo "  OS/アーキテクチャ: ${platform}"
  echo "  作業ディレクトリ:  $(pwd)"
  echo ""

  echo "d2 (インフラ構成図の生成):"
  d2_path=$(find_d2)
  if [ -n "$d2_path" ]; then
    echo "  導入済み: ${d2_path}"
    echo "  バージョン: $("$d2_path" --version 2>/dev/null | head -1)"
  else
    echo "  未導入"
    url=$(fetch_d2_url "$platform")
    if [ -n "$url" ]; then
      echo "  導入する場合の取得元:"
      echo "    ${url}"
      echo "  配置先: ${LOCAL_DIR}/d2 (このプロジェクト内)"
      echo "  サイズ: 約20MB"
      echo "  システムへの影響: なし (PATH も変更しない)"
    else
      echo "  (リリース情報を取得できませんでした。ネットワークを確認してください)"
    fi
  fi
  echo ""

  echo "mermaid-cli (mermaid の構文検証):"
  if command -v mmdc >/dev/null 2>&1; then
    echo "  導入済み: $(command -v mmdc)"
  else
    echo "  未導入 (自動導入の対象外。npm が必要なため)"
    echo "  使う場合: npm install -g @mermaid-js/mermaid-cli"
  fi
  echo ""

  echo "いずれも必須ではありません。"
  echo "  d2 が無い場合:   .d2 ソースのみ生成し、SVG 生成をスキップします"
  echo "  mmdc が無い場合: mermaid の検証をスキップします"
}

do_install_d2() {
  local platform url tmp sha ver

  if [ -x "${LOCAL_DIR}/d2" ]; then
    echo "既に導入済みです: ${LOCAL_DIR}/d2"
    echo "バージョン: $("${LOCAL_DIR}/d2" --version 2>/dev/null | head -1)"
    echo "再導入する場合は rm -rf .mitorizu を実行してから再度お試しください。"
    return 0
  fi

  platform=$(detect_platform) || return 1

  echo "リリース情報を取得しています..."
  url=$(fetch_d2_url "$platform")
  if [ -z "$url" ]; then
    echo "error: ${platform} 向けの配布物が見つかりませんでした" >&2
    echo "  手動で導入する場合: brew install d2" >&2
    return 1
  fi

  echo "取得元: ${url}"
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  echo "ダウンロードしています..."
  if ! curl -fsSL "$url" -o "$tmp/d2.tar.gz"; then
    echo "error: ダウンロードに失敗しました" >&2
    return 1
  fi

  # d2 の GitHub Releases はチェックサムファイルを配布していないため、
  # ダウンロード前の突き合わせはできない。
  # 取得したものの SHA-256 を記録用に表示し、
  # 展開後に実際に動くかで健全性を確認する。
  if command -v shasum >/dev/null 2>&1; then
    sha=$(shasum -a 256 "$tmp/d2.tar.gz" | cut -d' ' -f1)
  elif command -v sha256sum >/dev/null 2>&1; then
    sha=$(sha256sum "$tmp/d2.tar.gz" | cut -d' ' -f1)
  else
    sha="(計算できませんでした)"
  fi
  echo "SHA-256: ${sha}"

  echo "展開しています..."
  if ! tar -xzf "$tmp/d2.tar.gz" -C "$tmp"; then
    echo "error: 展開に失敗しました" >&2
    return 1
  fi

  local found
  found=$(find "$tmp" -type f -name d2 -perm -u+x 2>/dev/null | head -1)
  if [ -z "$found" ]; then
    echo "error: 配布物に d2 バイナリが見つかりませんでした" >&2
    return 1
  fi

  mkdir -p "$LOCAL_DIR"
  cp "$found" "${LOCAL_DIR}/d2"
  chmod +x "${LOCAL_DIR}/d2"

  # 実際に動くかを確認する。ここが健全性の最終確認になる。
  if ! ver=$("${LOCAL_DIR}/d2" --version 2>&1 | head -1); then
    echo "error: 配置したバイナリが実行できませんでした" >&2
    rm -f "${LOCAL_DIR}/d2"
    return 1
  fi

  # .gitignore に追記する (重複は避ける)
  if [ -f .gitignore ]; then
    grep -qx '.mitorizu/' .gitignore || printf '\n.mitorizu/\n' >> .gitignore
  else
    printf '.mitorizu/\n' > .gitignore
  fi

  echo ""
  echo "d2 を導入しました。"
  echo "  バージョン: ${ver}"
  echo "  配置先:     ${LOCAL_DIR}/d2"
  echo "  SHA-256:    ${sha}"
  echo "  動作確認:   OK"
  echo ""
  echo ".gitignore に .mitorizu/ を追記しました。"
  echo "アンインストールは rm -rf .mitorizu だけです。"
}

case "${1:-}" in
  --check)      do_check ;;
  --install-d2) do_install_d2 ;;
  -h|--help)    usage ;;
  *)            usage; exit 2 ;;
esac
