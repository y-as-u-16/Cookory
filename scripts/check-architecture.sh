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

# --- Rule 9: Data and Domain must not depend on Features -------------------
# Data・Domain は Features に依存してはならない（ARCHITECTURE.md 第9条）
#
# Single-target builds need no import, so the compiler stays silent about this
# direction. Checking import lines alone misses it entirely.
# 単一ターゲットでは import が要らないため、コンパイラはこの逆流に沈黙する。
# import 文だけを見る検査では検出できない。
if [ -d Cookory/Features ]; then
  FEATURE_TYPES=$(grep -rhoE '^(struct|enum|final class|protocol) +[A-Za-z_][A-Za-z0-9_]*' \
    Cookory/Features --include='*.swift' 2>/dev/null | awk '{print $NF}' | sort -u | paste -sd'|' -)

  if [ -n "$FEATURE_TYPES" ]; then
    for layer in Data Domain; do
      [ -d "Cookory/$layer" ] || continue
      while IFS=: read -r file line _; do
        [ -z "$file" ] && continue
        fail "$file" "$line" "$layer must not reference types defined in Features (ARCHITECTURE.md #9) / $layer 層は Features 層の型を参照できません"
      done < <(grep -rnE "\b($FEATURE_TYPES)\b" "Cookory/$layer" --include='*.swift' 2>/dev/null)
    done
  fi
fi

# --- Rule: LocalImageStorage must not hold a FileManager -------------------
# LocalImageStorage は FileManager を保持してはならない
#
# save is nonisolated and runs concurrently; FileManager instance methods are
# not thread-safe, so a shared instance corrupts writes (PR #78). The race is
# probabilistic and does not surface in tests, so guard the shape instead.
# save は nonisolated で並行に走る。FileManager のインスタンスメソッドは
# スレッドセーフではなく、共有すると書き込みが壊れる（PR #78）。競合は確率的で
# テストでは再現しないため、形を検査して守る。
STORAGE=Cookory/Data/ImageStorage/LocalImageStorage.swift

if [ -f "$STORAGE" ]; then
  while IFS=: read -r file line _; do
    [ -z "$file" ] && continue
    fail "$file" "$line" "LocalImageStorage must create a FileManager per call, not hold one (PR #78) / FileManager は呼び出しごとに作ります。保持すると並行保存で書き込みが壊れます"
  done < <(grep -HnE '(var|let) +[A-Za-z_][A-Za-z0-9_]* *: *FileManager *=|(var|let) +[A-Za-z_][A-Za-z0-9_]* *= *FileManager\(\)' "$STORAGE" 2>/dev/null)
fi

# --- Result ----------------------------------------------------------------
if [ "$violations" -gt 0 ]; then
  echo ""
  echo "Architecture check failed: $violations violation(s)."
  echo "アーキテクチャ検査に失敗しました: 違反 $violations 件"
  echo "See docs/ARCHITECTURE.md / 詳細は docs/ARCHITECTURE.md を参照してください"
  exit 1
fi

echo "Architecture check passed. / アーキテクチャ検査に合格しました。"
