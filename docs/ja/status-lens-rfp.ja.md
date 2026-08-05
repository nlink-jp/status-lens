# RFP: status-lens

> Generated: 2026-08-06
> Status: Draft

## 1. Problem Statement

外部 SaaS の障害は「自分の作業が突然失敗して初めて気づく」ことが多く、環境起因かサービス起因かの切り分けに時間を浪費する。status-lens は Statuspage.io ホストのステータスページ（既定: Claude）をプロファイルとして複数登録し、macOS メニューバーで各サービスの運転状況を常時表示・状態変化を通知する常駐アプリである。

nlink-jp の observability 系メニューバーツール群における棲み分けは明確で、コストは claude-usage-lens、マシン負荷は load-spinner、サービス稼働状況は status-lens が担う。対象ユーザーは nlink-jp（開発者本人）。

## 2. Functional Specification

### Commands / API Surface

- メニューバー常駐 GUI アプリ。CLI サブコマンドは同居しない（GUI 専用）
- 例外として `status-lens --version` のみ応答する（Homebrew cask の brew test 要件）

### Input / Output

**入力**: 各プロファイルの Statuspage API v2 `/api/v2/summary.json`（認証不要）。全有効プロファイルを並列ポーリング、既定 60 秒間隔（設定可）。

**メニューバー表示（C案: 横書き短縮ラベル + 状態記号）**:

- プロファイルごとに「短縮ラベル + 状態アイコン」を横に並べる（例: `CL✓ GH✓ DB▲`）
- 状態マッピング（色 + 形状の二重符号化、SF Symbols 使用）:

| 状態 | 記号 | 色 |
|------|------|-----|
| operational | checkmark | 緑 |
| minor | exclamationmark.triangle | 黄 |
| major | xmark | 橙 |
| critical | xmark | 赤 |
| メンテナンス中 | wrench | 青 |
| API 到達不能 | questionmark | グレー |

- 到達不能（ネットワーク断・URL 移転等）は operational と明確に区別する
- 表示モード切替: **並列表示**（全プロファイル、上記）/ **最悪値集約**（単一インジケーター + 劣化プロファイル数。例: `●2`）

**ポップオーバー（クリックで展開）**:

- プロファイル → コンポーネント別状態 → 進行中インシデント（名前・impact・最新 update・発生時刻）→ 予定メンテナンスの階層表示
- 各プロファイルのステータスページへのリンク

**通知（macOS 通知センター）**:

- 劣化時と復旧時の両方を通知。悪化方向のクロス時のみ発火（同一状態の再通知はしない）
- プロファイル単位で ON/OFF

### Configuration

- UserDefaults + 設定 UI（claude-usage-lens-gui / load-spinner と同方式、@AppStorage 系）
- プロファイル定義: 名前 / ベース URL / 短縮ラベル（2〜3 文字、編集可）/ 有効フラグ / 通知 ON/OFF
- プリセット内蔵: Claude（status.claude.com、既定 ON）・GitHub（www.githubstatus.com）。追加プロファイルは設定 UI から任意の Statuspage URL を登録
- ポーリング間隔（既定 60 秒）、表示モード（並列 / 最悪値集約）
- ログイン時自動起動（SMAppService、既定 OFF）

### External Dependencies

- Statuspage API v2（Atlassian Statuspage ホストページの公開 API）。認証・クレデンシャル不要

## 3. Design Decisions

- **Swift / AppKit NSStatusItem + SwiftUI パネル（NSPopover）**: 色付き表示はテンプレート画像（単色）では実現できないため MenuBarExtra は不使用。load-spinner・claude-usage-lens-gui で実績のある構成をそのまま踏襲する。darwin/arm64 専用、macOS 13+
- **汎用 Statuspage ウォッチャーとして設計**: Claude 専用にせず、プロファイル機構で任意の Statuspage ホストページを監視対象にできる。Claude は既定プロファイルにすぎない
- **表現は色 + 形状の二重符号化**: 色弱環境やスクリーンショット共有でも状態が伝わる。縦書きプレート案（load-spinner 方式）は試作評価の結果、高さ制約と可読性の観点で不採用（Discussion Log 参照）
- **GUI 専用（CLI サブコマンド非同居）**: 組織慣例（GUI に CLI 同居）の例外とする。スクリプトからの状態取得ニーズが生じたら将来検討
- **命名**: `-lens` シリーズ（claude-usage-lens / active-lens / sensor-lens）に倣い status-lens。APP_NAME は load-spinner の先例に従い kebab-case 維持（単一 GUI バイナリ）、Bundle ID は jp.nlink.status-lens
- **補完関係**: claude-usage-lens（コスト）・load-spinner（負荷）と同族の observability 系メニューバー GUI 群を構成する

**Out of scope**:

- Statuspage 以外のステータスページ形式（status.io、instatus、独自 HTML 等）
- 稼働率履歴の蓄積・グラフ表示
- 独自エンドポイントの死活監視（ヘルスチェック）
- クロスプラットフォーム対応（macOS 専用）

## 4. Development Plan

### Phase 1: Core

- Statuspage API クライアント（summary.json の取得・strict decode）
- プロファイルモデル + プリセット
- 状態集約・最悪値算出・ラベル短縮の純粋関数 + ユニットテスト
- メニューバー表示（C案・並列 / 最悪値集約の 2 モード）
- ポーリングループ（App Nap 対策込み）

### Phase 2: Features

- ポップオーバー詳細（コンポーネント / インシデント / メンテナンス階層）
- macOS 通知（劣化 / 復旧、クロス時のみ発火）
- 設定 UI（プロファイル CRUD・間隔・表示モード・通知トグル）
- SMAppService ログイン項目

### Phase 3: Release

- アプリアイコン、README.md / README.ja.md、CHANGELOG.md、AGENTS.md
- 署名 + notarize + staple、GitHub Release、homebrew-tap cask
- util-series submodule 統合、org profile / web カタログ反映、check-org.sh

各 Phase は独立してレビュー可能。

## 5. Required API Scopes / Permissions

None（認証不要の公開 API のみ。macOS 側は通知権限のユーザー許諾のみ）

## 6. Series Placement

Series: util-series
Reason: claude-usage-lens-gui / load-spinner と同族の observability 系メニューバー常駐 GUI。汎用ユーティリティであり特定外部サービスのクライアント（cli-series）でも実験（lab-series）でもない。

## 7. External Platform Constraints

- Statuspage API v2 は無認証・CDN 配信。60 秒間隔のポーリングは問題にならない
- **URL は移転しうる**: status.anthropic.com → status.claude.com の移転実績あり。HTTP リダイレクトへの追従を必須とし、恒久リダイレクト検知時はポップオーバー等で気づけるようにする
- **コンポーネント構成は運営側で予告なく変わる**: コンポーネント名・数をハードコードせず、レスポンス駆動で描画する
- 全体 indicator は none / minor / major / critical の 4 段階 + メンテナンス。コンポーネント status は operational / degraded_performance / partial_outage / major_outage / under_maintenance
- タイムスタンプは UTC → 表示はローカル TZ に変換
- **App Nap**: LSUIElement 常駐アプリはウィンドウ非表示時に App Nap でタイマーが凍結する（claude-usage-lens-gui v0.1.7 の実績）。`ProcessInfo.beginActivity` をアプリ寿命で保持する

---

## Discussion Log

- 2026-08-06: 発端は「コストは claude-usage-lens、サービス運転状況は本ツール」という棲み分け構想。status.anthropic.com が status.claude.com へ移転済みであることを API 実測で確認
- **専用 vs 汎用**: Statuspage API は全ホストページ共通スキーマであるため、Claude 専用ではなく汎用 + プロファイル選択方式に決定
- **ツール名**: -lens シリーズ命名に倣い status-lens に決定（service-lens / statuspage-lens は不採用）
- **監視モデル**: 複数プロファイル同時監視とし、表示モードとして並列表示 / 最悪値集約を切替可能に。「ラベルが無いと訳がわからなくなる」との指摘から表現方法を重点検討
- **メニューバー表現の変遷**: (1) 横書き案 A（ラベル+色ドット）/ B（着色ラベル）/ C（ラベル+形状記号）/ D（正常時畳み込み）を比較 → (2) 横幅節約のため load-spinner 方式の縦書きプレート（V1 色プレート / V2 着色文字）を検討 → (3) V1+C 複合（記号をプレートに埋込 → 隣に正立配置）を試作 → (4) 最終的に**横書きの C案（ラベル + 形状記号、色併用）を採用**。縦書きはメニューバー高 22pt での高さ制約と可読性の観点で不採用
- **通知**: 劣化・復旧の両方（悪化クロス時のみ発火、プロファイル単位トグル）
- **CLI 同居**: GUI 専用とし --version 応答のみ（組織慣例の例外として明示的に判断）
- **設定保存**: UserDefaults + 設定 UI（TOML ファイルは GUI との二重管理になるため不採用）
