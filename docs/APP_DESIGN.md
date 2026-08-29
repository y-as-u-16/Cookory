# 料理記録アプリ プロダクト設計書

## 1. 概要

### 1.1 プロダクトコンセプト

> 作った料理を撮るだけで、わが家の料理の歴史が育っていく。

本アプリは「レシピを探すアプリ」ではなく、

- 実際に作った料理
- 料理の上達
- 家族の好み
- また作りたい料理
- 日々の食卓の思い出

を写真中心に蓄積する、プライベートな料理記録アプリである。

---

## 1.2 解決したい問題

料理をしていると、次のような情報が失われやすい。

- 前に作った料理を忘れる
- 料理写真が写真アプリに埋もれる
- 家族が気に入った料理を忘れる
- 同じ料理を以前どう作ったか分からない
- 「最近これ作ってないな」が分からない
- 毎回献立をゼロから考える
- 自分がどれだけ料理してきたか実感できない

既存の料理アプリは、

> これから何を作るか

を解決するものが多い。

本アプリは、

> 今まで何を作り、何がわが家の定番になったか

を中心にする。

---

# 2. 市場ポジショニング

現在のApp Storeにはすでに、料理写真・評価・タグ・メモ・レシピURLなどを記録できる料理アルバム系アプリが存在する。

また、AIによるレシピ取り込み、献立、買い物リスト、家族共有まで提供するレシピ管理アプリも存在する。

したがって、

> 写真を保存できます

だけでは差別化にならない。

本アプリでは、個別機能ではなく以下の体験ループを差別化軸とする。

```text
作る
 ↓
写真を撮る
 ↓
数秒で記録
 ↓
料理として自動的に蓄積
 ↓
過去の同じ料理とつながる
 ↓
家族の評価・思い出が蓄積
 ↓
「また作る」きっかけになる
 ↓
再び記録
```

---

# 3. プロダクトの中核

本アプリの中核は4つ。

## 3.1 Capture

料理を極限まで簡単に記録する。

## 3.2 Cookbook

自分が実際に作った料理だけから「わが家の料理図鑑」を生成する。

## 3.3 History

同じ料理を作った履歴を時系列で残す。

## 3.4 Memory

過去の料理を再発見させる。

---

# 4. UX原則

## 4.1 入力より記録を優先する

必須入力は原則、

```text
写真
```

だけとする。

以下は任意。

- 料理名
- メモ
- 評価
- タグ
- レシピ
- 食材

ユーザーにフォーム入力を要求しすぎない。

---

## 4.2 Capture First

目標：

```text
アプリ起動
 ↓
写真撮影
 ↓
保存

5〜10秒以内
```

料理名入力画面まで完了しなくても記録自体は保存済みにする。

---

## 4.3 Record Now, Organize Later

記録するとき：

> 極限まで簡単

振り返るとき：

> 情報量を豊かに

とする。

---

# 5. ターゲットユーザー

## Primary

日常的に自炊している人。

特に、

- 夫婦
- 同棲
- 子育て家庭
- 料理が趣味
- 自炊を習慣化したい人

を主要対象とする。

---

# 6. 情報設計

主要タブは4つ。

```text
Home

Calendar

Cookbook

Memory
```

中央または目立つ位置に、

```text
＋ Record
```

を配置する。

---

# 7. Home

Homeの目的は、

> 今日記録する

ことと、

> 次に作る料理を思い出す

こと。

構成：

```text
こんばんは

今日のごはん

[ ＋ 料理を記録 ]

----------------

最近の料理

[Photo]
唐揚げ
昨日

[Photo]
鮭のホイル焼き
3日前

----------------

久しぶりにどう？

[Photo]
ハンバーグ

最後に作ったのは
83日前
```

---

# 8. Capture

アプリで最も重要な画面。

## Flow

```text
Record
 ↓
Camera / Photo Library
 ↓
Photo Preview
 ↓
即時保存
```

保存後：

```text
✓ 保存しました

料理名
[ 唐揚げ ]

評価
☆ ☆ ☆ ☆ ☆

メモ
[                    ]

[ 完了 ]
```

ここで画面を閉じても写真は保存済み。

PhotosPickerはSwiftUI向けの標準写真選択APIを提供し、選択した項目はTransferableとして取得できる。

---

# 9. Calendar

写真中心のカレンダー。

```text
August 2026

Mon Tue Wed Thu Fri Sat Sun

                1   2
                ○   ○

 3   4   5   6   7   8   9
 ○       ○   ○       ○
```

料理が存在する日には、

- サムネイル
- インジケーター

を表示する。

日付選択後：

```text
August 29

Dinner

[Photo]

唐揚げ
★★★★★

「片栗粉多め」
```

---

# 10. Cookbook

ユーザーが実際に作った料理だけを並べる。

```text
My Cookbook

[ Search ]

----------------

よく作る

唐揚げ
12回

カレー
9回

ハンバーグ
8回
```

ソート：

- 最近作った
- よく作る
- 最近作っていない
- お気に入り
- 名前順

---

# 11. Dish Detail

本アプリの重要な差別化画面。

```text
唐揚げ

[最新写真]

12回作りました

最終
2026/08/29

----------------

History

2026/08/29
[Photo]
★★★★★
片栗粉多め

2026/07/14
[Photo]
★★★★☆
少し味濃かった

2026/06/03
[Photo]
★★★★☆
二度揚げ
```

これにより単なる写真保存ではなく、

> 料理ごとの成長履歴

として成立させる。

---

# 12. Memory

過去の記録を再利用する。

## 12.1 One Year Ago

```text
1年前の今日

[Photo]

夏野菜カレー

2025/08/29
```

---

## 12.2 Recently Not Cooked

```text
最近作ってない料理

[Photo]

ハンバーグ

最後に作ったのは
92日前
```

---

## 12.3 Seasonal Memory

```text
去年の夏によく作った料理

冷やし中華
夏野菜カレー
冷しゃぶ
```

---

# 13. Family Feature

クラウド対応後の主要機能。

Householdという概念を追加する。

```text
Household

├── User A
└── User B
```

料理に対して、

```text
♡ おいしかった

🔥 また作って

⭐ お気に入り
```

を送れる。

---

# 14. 「また作って」

家族側：

```text
唐揚げ

[ また作って ]
```

料理する側：

```text
家族からのリクエスト

唐揚げ       3
ハンバーグ   2
カレー       1
```

AI献立とは異なり、

> 家族が本当に食べたいもの

を次の料理候補にする。

---

# 15. Monthly Story

月末に自動生成。

```text
August 2026

28 meals

12 different dishes

Most Cooked
唐揚げ ×4

New Dishes
5

Family Favorite
ハンバーグ
```

料理写真をグリッド化する。

共有形式：

```text
1:1

4:5

9:16
```

を想定。

Instagram Stories等へ共有できるようにする。

これはアプリ内部にSNSを作らず、外部SNSをGrowth Loopとして利用するための機能。

---

# 16. Smart Capture

初期リリース必須ではない。

将来的に写真から、

- 料理名候補
- カテゴリ
- 食材
- タグ

を推定する。

例：

```text
Photo

 ↓

「鶏の唐揚げですか？」

[はい]
```

ユーザーがAIチャットを開く設計にはしない。

AIは、

> 入力作業を減らす裏方

として使用する。

2026年のFoundation Models frameworkは画像を含むマルチモーダル入力を扱えるため、対応OS/端末ではオンデバイス解析を検討できる。

---

# 17. Search

MVP：

```text
料理名
メモ
```

将来：

```text
タグ
食材
カテゴリ
期間
```

Smart Search：

```text
最近作ってない魚料理

去年の夏の麺料理

家族がお気に入りの料理
```

---

# 18. MVP

最初のApp Storeリリースに含める。

## 必須

- 料理写真登録
- Photo Library取り込み
- Home
- Timeline
- Calendar
- Meal Detail
- Cookbook
- Dish Detail
- Dish History
- 料理名検索
- 編集
- 削除
- データExport
- Settings

---

# 19. MVPに含めないもの

初期版では以下を作らない。

- Supabase
- Firebase
- ログイン
- 家族共有
- AIレシピ生成
- レシピ検索
- SNS
- フォロー
- 公開投稿
- 冷蔵庫管理
- 買い物リスト
- 栄養管理
- カロリー管理
- 献立AI
- AIチャット

---

# 20. Phase 1.1 — Retention

MVP利用状況を確認した後、

- 最近作っていない料理
- 1年前の今日
- 月間サマリー
- Cooking Count
- お気に入り
- Widget

を追加。

---

# 21. Phase 1.2 — Smart Capture

追加：

- 写真から料理名候補
- 自動タグ
- 自動カテゴリ
- 自動食材候補

---

# 22. Phase 2 — Cloud

Supabase導入。

追加：

- Auth
- Database
- Storage
- Sync
- Backup

SupabaseはSwiftからDatabase/Auth/Storageを利用できるため、将来的な家族共有基盤として利用可能。

---

# 23. Phase 2.1 — Family

追加：

- Household
- Household Member
- Reaction
- Dish Request
- Shared Cookbook
- Shared Memory

---

# 24. Phase 3 — Recipe

実際にユーザー需要が確認できた場合のみ追加。

```text
Dish
 ↓
Recipe?
```

RecipeはDishに対してOptional。

アプリの中心Entityにしない。

---

# 25. Product Metrics

## North Star Metric

```text
Weekly Recorded Meals
```

1週間に何回記録されたか。

---

## Activation

```text
First Meal Saved Rate
```

---

## Retention

```text
D1
D7
D30
```

---

## Engagement

```text
Meals Per Week

Cookbook Open Rate

Dish History Open Rate

Memory Open Rate
```

---

## Quality

```text
Capture → Save Time
```

目標：

```text
Median < 10 sec
```

---

# 26. MVP検証

最初は実際の家庭内ユーザーに2〜4週間使用してもらう。

見るべきポイント：

- 料理するたびに写真を撮るか
- 写真保存が面倒ではないか
- 料理名を入力するか
- Calendarを見るか
- Cookbookを見るか
- 過去のDish Historyを見るか
- 「最近作ってない」が便利か
- Memoryを欲しいと思うか

特に、

```text
写真は毎回撮る

しかし

料理名は入力しない
```

となった場合は、

Smart Captureを優先する。

---

# 27. Monetization

MVPは基本無料を推奨。

Core機能：

- Capture
- Calendar
- Cookbook
- History
- Search

は無料。

将来のPremium候補：

- Cloud Backup
- Family Sharing
- AI
- Advanced Memory
- Advanced Statistics
- Premium Theme

課金はアプリ起動直後ではなく、

```text
Family共有を使う

↓

Premium説明
```

のようなContextual Paywallにする。

---

# 28. App Store戦略

カテゴリ：

```text
Food & Drink
```

候補キーワード：

```text
料理記録
料理日記
自炊記録
ごはん記録
料理写真
料理アルバム
献立記録
料理メモ
食事記録
```

---

# 29. App Store Screenshot

## 1

```text
作った料理を、
写真で残そう。
```

## 2

```text
撮るだけ。
数秒で記録。
```

## 3

```text
あなたの料理図鑑が
自然に育つ。
```

## 4

```text
同じ料理の
上達まで残せる。
```

## 5

```text
久しぶりの料理を
思い出せる。
```

## 6

```text
家族の
「また作って」が届く。
```

---

# 30. Product Principle

本アプリの最重要原則。

> 記録するときは極限までシンプルに。
>
> 振り返るときは驚くほど豊かに。

入力項目を増やすことで価値を作らない。

長期間利用することで、

```text
Photo
 ↓
Record
 ↓
Dish History
 ↓
Cookbook
 ↓
Memory
 ↓
Family History
```

へデータ価値が増えていくアプリを目指す。

---

# 31. Long-term Vision

最終的には、

```text
2026
二人暮らしを始めて
最初に作った料理

2028
家族のお気に入りになった料理

2030
何十回も作った
わが家の定番料理
```

のように、

単なる料理管理ツールではなく、

> 家族の食卓の歴史

を残すプロダクトにする。
