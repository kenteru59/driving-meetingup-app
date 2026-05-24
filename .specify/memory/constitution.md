<!--
Sync Impact Report
- Version change: (initial template) → 1.0.0
- Modified principles: (新規制定 — 既存原則なし)
- Added sections:
  - Core Principles I–V (Spec 駆動開発 / シークレット排除 / コミット前テスト / 一次情報主義 / 言語ポリシー)
  - Additional Constraints (プラットフォーム・開発機・リポジトリ可視性)
  - Development Workflow (spec-kit 順序・ブランチ規約・PR 要件)
  - Governance (改定手順・バージョニング・違反扱い)
- Removed sections: なし
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md — "Constitution Check" は principle 名に依存しないため変更不要
  - ✅ .specify/templates/spec-template.md — 整合
  - ✅ .specify/templates/tasks-template.md — タスク ID 規約 (T<NNN>) と整合
  - ✅ .specify/templates/checklist-template.md — 整合
  - ✅ CLAUDE.md — 本憲法は CLAUDE.md から派生しており同期済み
- Deferred TODOs: なし
-->

# driving-meetingup-app Constitution

## Core Principles

### I. Spec 駆動開発 (NON-NEGOTIABLE)

`app/src/main/**` および `infra/**/*.tf`, `infra/**/*.tfvars` への新規実装・編集は、
対応する `specs/<NNN-feature>/tasks.md` の存在が前提条件である。
ワークフローは `/speckit-specify` → (`/speckit-clarify`) → `/speckit-plan` →
`/speckit-tasks` → (`/speckit-analyze`) → `/speckit-implement` の順を厳守する。
各タスクには `T<NNN>` 形式のタスク ID を付与し、PR タイトル・コミットメッセージ・
テストメソッド名・(必要時のみ) コード内コメントで同 ID を参照することで、
spec ↔ コード ↔ テストの双方向トレーサビリティを維持する。
違反は `.claude/hooks/check-spec-required.ps1` が PreToolUse で完全ブロックする。

**Rationale**: 個人開発であっても要件と設計の根拠を失うと長期メンテが破綻する。
spec を強制することで AI と人間が同じ前提で実装できる状態を維持する。

### II. シークレット・PII の完全排除 (NON-NEGOTIABLE)

本リポジトリは public (`kenteru59/driving-meetingup-app`) であり、以下を一切コミット
しない:

- ファイル名: `.env*`, `*.pem`, `*.key`, `*.jks`, `*.keystore`, `credentials.json`,
  `service-account*.json` 等
- 内容パターン: AWS / GitHub / Google / Slack / Stripe トークン、
  `-----BEGIN ... PRIVATE KEY-----` 等

実値は AWS Secrets Manager / Parameter Store / gitignored ローカル `.env` から
実行時注入し、コード内では `System.getenv("KEY_NAME")` のようにキー名参照のみとする。
`.env.example` にはキー名のみを記載してよい。
違反は `.claude/hooks/check-secrets.ps1` が PreToolUse で完全ブロックする。

**Rationale**: public リポジトリでの一度の漏洩は取り返しがつかない。検知ではなく
書き込み時点でのブロックを唯一の防衛線とする。

### III. コミット前テスト通過 (NON-NEGOTIABLE)

`app/build.gradle*` が存在する状態での `git commit` は、`./gradlew testDebugUnitTest`
が成功した場合のみ許容される。検証メカニズムは `.claude/hooks/check-commit-gate.ps1`。
`--no-verify`・`-c commit.gpgsign=false` 等の検証スキップ手段の使用を一切禁止する。
ローカルが緑にならない原因はテスト改修ではなく実装側で解決する。

**Rationale**: テストを落としたままのコミットは履歴を汚し bisect を破壊する。
ゲートを回避するくらいなら、そのコミット自体を見送る方が常に安い。

### IV. 一次情報主義 (MCP 優先)

AWS のリソース / IAM ポリシー / Well-Architected を扱う際は、`.mcp.json` の
`aws-knowledge` MCP を先に引いて現行ドキュメントを確認する。
Terraform プロバイダ・モジュールを扱う際は `terraform` MCP で Registry を引き、
最新のスキーマ・引数を確認する。
LLM の学習データのみを根拠に API 名・引数・サービス名・モジュール構文を
書き出してはならない。

**Rationale**: AWS / Terraform は API 改廃が速い。記憶ベースの実装は廃止済み
リソースや存在しない引数を産み、後で人間がデバッグするコストが大きい。

### V. 言語ポリシーの遵守

メンバー全員が日本語話者である前提に従い、以下を区別する:

- **日本語**: AI ↔ 人間 の対話、CLAUDE.md / spec.md / plan.md / tasks.md /
  README 等のドキュメント、Git コミットメッセージ、PR 本文、Issue
- **英語**: ソースコードの識別子・変数名・関数名・ファイル名、設定ファイル
  (`*.json`, `*.yml`, `*.tf` 等)、hook の stderr エラーメッセージ
  (Claude が読む技術ログ)、ライブラリ/フレームワーク由来の用語

**Rationale**: 議論・意思決定は母語で精度を上げ、コード・設定は技術慣習に揃えて
検索性とエコシステム互換性を確保する。両者を混ぜると検索もレビューも劣化する。

## Additional Constraints

- **プラットフォーム**: Android ネイティブ (Kotlin + Jetpack Compose、Gradle
  Kotlin DSL)。テストは JUnit / Compose UI Test / Robolectric を基本とし、
  詳細は各モジュール導入時の plan.md で確定する。
- **バックエンド (将来)**: AWS の低コスト構成。IaC は Terraform、配置は
  `infra/` 配下。具体構成は spec 化を経てから書く。
- **開発機**: Windows + PowerShell。hook とスクリプトは `.ps1` で書く。
  `specify` CLI は `PYTHONIOENCODING=utf-8` を付けて実行する (cp932 で Rich
  が落ちる回避)。
- **MCP サーバ**: `.mcp.json` で `aws-knowledge` (uvx, `--skip-auth` 必須) と
  `terraform` (Docker `hashicorp/terraform-mcp-server:<tag>`) を有効化する。
  バージョン更新は再現性確保のため必ずタグ固定で PR を出す。
- **Hook 改廃**: `.claude/hooks/*.ps1` の改変は本憲法と CLAUDE.md の更新を
  同一 PR に含めること。ブロック回避目的の単独改変は禁止。

## Development Workflow

- 機能着手時は `/speckit-specify` でブランチ `<NNN>-<feature-slug>` を作成し
  `specs/<NNN-feature>/` を初期化する。
- `.specify/extensions.yml` の git auto-commit フックは原則 `enabled: true` の
  まま運用する。各 step 前後のコミットで作業履歴の粒度を保つ。
- spec → plan → tasks の各成果物は本憲法の最新版に対して整合性チェックを
  受ける。違反があれば task 着手前に解消する。
- PR は対応する `specs/<NNN-feature>/` ディレクトリを含み、本文に関連
  タスク ID (`T<NNN>`) を列挙する。
- レビューは「原則違反 → リジェクト」「テンプレート違反 → リジェクト」
  「実装の良し悪し → コメントで議論」の優先順位で行う。

## Governance

本憲法は CLAUDE.md・全テンプレート (`plan-template.md`, `spec-template.md`,
`tasks-template.md`, `checklist-template.md`)・各 `.claude/skills/speckit-*` を
上位拘束する。矛盾が見つかった場合は本憲法を起点に他文書を是正する。

改定は必ず PR で行い、以下を同一 PR に含める:

1. `.specify/memory/constitution.md` の更新 (Sync Impact Report 含む)
2. 影響を受ける `CLAUDE.md` / テンプレート / hook スクリプトの同期更新
3. 改定理由と影響範囲を本文に記載

バージョニングはセマンティックに従う:

- **MAJOR**: 原則の削除、または後方非互換な再定義
- **MINOR**: 原則・セクションの追加、もしくは実質的なガイダンス拡張
- **PATCH**: 表現の修正・タイポ・非意味的な改良

違反の取扱い:

- hook (`check-secrets.ps1` / `check-spec-required.ps1` / `check-commit-gate.ps1`)
  のブロックを `--no-verify` 等で回避する行為は本憲法違反として扱う。
- ルール自体に問題があると判断したら、回避ではなく改定 PR を出す。

ランタイム参照: 実装中の作業手順・ディレクトリ規約・MCP 運用などの詳細は
`CLAUDE.md` と各 `specs/<NNN-feature>/` を参照する。

**Version**: 1.0.0 | **Ratified**: 2026-05-24 | **Last Amended**: 2026-05-24
