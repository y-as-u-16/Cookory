#!/usr/bin/env bash
#
# Enforces the dependency rules in docs/ARCHITECTURE.md.
# docs/ARCHITECTURE.md の依存方向ルールを機械的に検証する。
#
# A written rule that nothing checks is a rule that decays. This script is the
# executable half of the architecture document.
# 検証されない規約は必ず腐る。本スクリプトは設計書の実行可能な半身である。
#
# Usage: ./scripts/check-architecture.sh

set -uo pipefail

violations=0

fail() {
  echo "::error file=$1,line=$2::$3"
  violations=$((violations + 1))
}

# --- Rule 9 / 76: Domain must not import frameworks ------------------------
# Domain はフレームワークに依存してはならない（ARCHITECTURE.md 第9・76条）
FORBIDDEN_IN_DOMAIN='^import (SwiftUI|SwiftData|UIKit|PhotosUI|Supabase|StoreKit|Combine)$'

if [ -d Cookory/Domain ]; then
  while IFS=: read -r file line _; do
    [ -z "$file" ] && continue
    fail "$file" "$line" "Domain must not import UI/persistence frameworks (ARCHITECTURE.md #9, #76) / Domain 層はフレームワークを import できません"
  done < <(grep -rnE "$FORBIDDEN_IN_DOMAIN" Cookory/Domain --include='*.swift' 2>/dev/null)
fi

# --- Rule 10: Domain entities must not be SwiftData models -----------------
# Domain Entity に @Model を付けてはならない（ARCHITECTURE.md 第10条）
if [ -d Cookory/Domain ]; then
  while IFS=: read -r file line _; do
    [ -z "$file" ] && continue
    fail "$file" "$line" "Domain entities must not be @Model (ARCHITECTURE.md #10) / Domain Entity に @Model は使えません"
  done < <(grep -rn '@Model' Cookory/Domain --include='*.swift' 2>/dev/null)
fi

# --- Rule 7 / 28: Views must not query SwiftData directly ------------------
# View から SwiftData を直接触らない（ARCHITECTURE.md 第7・28条）
if [ -d Cookory/Features ]; then
  while IFS=: read -r file line _; do
    [ -z "$file" ] && continue
    fail "$file" "$line" "Features must not use @Query/ModelContext directly (ARCHITECTURE.md #7, #28) / Feature 層で SwiftData を直接操作しないでください"
  done < <(grep -rnE '@Query|ModelContext|FetchDescriptor' Cookory/Features --include='*.swift' 2>/dev/null)
fi

# --- Rule 5 / 74: No screen-scoped repositories ----------------------------
# 画面単位の Repository は禁止（ARCHITECTURE.md 第5・74条）
SCREEN_REPOS='(Home|Calendar|Cookbook|Memory|Search|Settings|Capture|Onboarding|DishDetail)Repository'

while IFS=: read -r file line _; do
  [ -z "$file" ] && continue
  fail "$file" "$line" "Repositories are per aggregate, not per screen (ARCHITECTURE.md #5, #74) / Repository は画面単位ではなく集約単位です"
done < <(grep -rnE "protocol +$SCREEN_REPOS" Cookory --include='*.swift' 2>/dev/null)

# --- Result ----------------------------------------------------------------
if [ "$violations" -gt 0 ]; then
  echo ""
  echo "Architecture check failed: $violations violation(s)."
  echo "アーキテクチャ検査に失敗しました: 違反 $violations 件"
  echo "See docs/ARCHITECTURE.md / 詳細は docs/ARCHITECTURE.md を参照してください"
  exit 1
fi

echo "Architecture check passed. / アーキテクチャ検査に合格しました。"
