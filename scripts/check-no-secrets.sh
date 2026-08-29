#!/usr/bin/env bash
#
# Guards the public repository against identifiers that must not be committed.
# 公開リポジトリにコミットしてはいけない識別子を検出する。
#
# DEVELOPMENT_TEAM is the recurring one: Xcode rewrites it automatically
# whenever the project is opened with automatic signing, so a human check is
# not enough.
# 特に DEVELOPMENT_TEAM は再発する。自動署名で Xcode を開くたびに書き戻される
# ため、人の注意だけでは防げない。
#
# Usage: ./scripts/check-no-secrets.sh

set -uo pipefail

violations=0

fail() {
  echo "::error file=$1,line=$2::$3"
  violations=$((violations + 1))
}

# --- DEVELOPMENT_TEAM must stay empty -------------------------------------
# DEVELOPMENT_TEAM は空のままにする
while IFS=: read -r file line _; do
  [ -z "$file" ] && continue
  fail "$file" "$line" "DEVELOPMENT_TEAM must stay empty in a public repository; Xcode rewrote it. Run: git checkout -- $file / 公開リポジトリでは DEVELOPMENT_TEAM を空に保ちます。Xcode が書き戻したので元に戻してください"
done < <(grep -HnE 'DEVELOPMENT_TEAM = [^"]' Cookory.xcodeproj/project.pbxproj 2>/dev/null)

# --- No credentials anywhere in the tree ----------------------------------
# 認証情報がツリーに含まれていないこと
CREDENTIAL_PATTERNS='BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|xox[baprs]-[A-Za-z0-9-]+|AKIA[0-9A-Z]{16}'

while IFS=: read -r file line _; do
  [ -z "$file" ] && continue
  fail "$file" "$line" "Possible credential committed / 認証情報らしき文字列が含まれています"
done < <(git grep -nE "$CREDENTIAL_PATTERNS" -- . ':!scripts/check-no-secrets.sh' 2>/dev/null)

# --- Result ---------------------------------------------------------------
if [ "$violations" -gt 0 ]; then
  echo ""
  echo "Secret check failed: $violations violation(s)."
  echo "機密情報チェックに失敗しました: 違反 $violations 件"
  exit 1
fi

echo "Secret check passed. / 機密情報チェックに合格しました。"
