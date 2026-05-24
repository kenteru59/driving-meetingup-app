# driving-meetingup-app — AI 開発憲法

このリポジトリは **Spec 駆動開発** を前提とした個人開発 Android アプリ。AI (Claude Code) と人間が同じワークフローを共有して、要件・設計・タスク・コード・テストのトレーサビリティを常に維持する。

> このファイルは Claude Code が常に読む。違反は `.claude/hooks/` のスクリプトが PreToolUse で完全ブロックする。

---

## 言語ポリシー

メンバーは全員日本語話者。以下は **日本語** で書く / 話す:
- AI ↔ 人間 の対話
- ドキュメント (`CLAUDE.md`, `spec.md`, `plan.md`, `tasks.md`, README 等)
- Git コミットメッセージ、PR 本文、Issue

以下は **英語** で OK (技術慣習に従う):
- ソースコード (識別子、変数名、関数名、ファイル名)
- 設定ファイル (`*.json`, `*.yml`, `*.tf` 等)
- Hook の stderr エラーメッセージ (Claude が読む技術ログ)
- ライブラリ/フレームワーク由来の用語 (Compose, Lambda, Terraform module 等)

---

## プロジェクト概要

- **アプリ**: ドライブ/ミーティング系の Android ネイティブアプリ
- **クライアント**: Kotlin + Jetpack Compose / Gradle (Kotlin DSL)
- **テスト**: JUnit, Compose UI Test, Robolectric (詳細はモジュール導入時に追記)
- **バックエンド (将来)**: AWS で低コスト構成。**IaC は Terraform** (`infra/` 配下)。具体構成は spec 化してから書く。
- **リモート**: GitHub `kenteru59/driving-meetingup-app` (**public**)

---

## 絶対ルール

### 1. Spec を書かないコードは書かない
以下への新規実装・編集は、対応する `specs/<feature>/tasks.md` が存在することが前提。違反は `check-spec-required.ps1` がブロックする。
- `app/src/main/**` — Android プロダクションコード
- `infra/**/*.tf`, `infra/**/*.tfvars` — Terraform リソース定義

例外（spec 不要）:
- `app/src/test/**`, `app/src/androidTest/**` のテストコード
- `app/build.gradle*` 等のビルド設定
- `infra/README.md`, `infra/docs/**` (ドキュメント)
- `docs/**`, `.specify/**`, `.claude/**`, `.mcp.json`

### 2. シークレット・個人情報を絶対に書かない
リポジトリは **public**。以下は `check-secrets.ps1` がブロックする:
- `.env*`, `*.pem`, `*.key`, `*.jks`, `*.keystore`, `credentials.json`, `service-account*.json` 等の **ファイル名**
- AWS / GitHub / Google / Slack / Stripe トークン、`-----BEGIN ... PRIVATE KEY-----` 等の **内容パターン**

代替: `.env.example` にキー名だけ書き、実値は AWS Secrets Manager / Parameter Store / ローカル `.env`(gitignored) から実行時注入。コード内では `System.getenv("KEY_NAME")` などキー名参照のみ。

### 3. コミット前にテストを通す
`app/build.gradle*` が存在する状態で `git commit` を発行すると、`check-commit-gate.ps1` が `./gradlew testDebugUnitTest` を実行し、失敗ならブロックする。`--no-verify` は使わない（使った瞬間にゲートは効かない＝禁じ手）。

---

## Spec 駆動ワークフロー (spec-kit)

すべての新機能は以下の順で進める。Claude Code のスキル (`.claude/skills/speckit-*`) として組み込まれている。

| Step | スキル / コマンド | アウトプット |
|------|------------------|-------------|
| 0 | `/speckit-constitution` | `.specify/memory/constitution.md` (一度だけ) |
| 1 | `/speckit-specify` | `specs/<NNN-feature>/spec.md` 要件 |
| 2 | `/speckit-clarify` (任意) | 不明点の質問・解消 |
| 3 | `/speckit-plan` | `specs/<NNN-feature>/plan.md` 設計 |
| 4 | `/speckit-tasks` | `specs/<NNN-feature>/tasks.md` 実装タスク |
| 5 | `/speckit-analyze` (任意) | クロスチェック |
| 6 | `/speckit-implement` | 実装 (Spec hook がここで解錠される) |

トレーサビリティ: 各タスクには **タスクID** (例 `T012`) が付き、PR / コミット / テスト名 / コード内コメント (必要時のみ) で同じ ID を使って双方向に辿れるようにする。

---

## ディレクトリ規約

```
.
├── .claude/
│   ├── settings.json          # チーム共通 (hooks 含む / コミット対象)
│   ├── settings.local.json    # 個人設定 (gitignored)
│   ├── skills/speckit-*/      # spec-kit が生成
│   └── hooks/*.ps1            # 強制ルール本体
├── .specify/                  # spec-kit テンプレ・スクリプト
├── specs/<NNN-feature>/       # 機能ごとのスペック
│   ├── spec.md
│   ├── plan.md
│   ├── tasks.md
│   └── traceability.md        # spec ↔ コード ↔ テスト の対応表
├── app/                       # Android アプリモジュール (Phase B で作成)
│   ├── build.gradle.kts
│   └── src/{main,test,androidTest}/
├── infra/                     # AWS 構成 (Terraform / 後フェーズで作成)
│   ├── main.tf, providers.tf, variables.tf
│   └── modules/<module>/...
├── .mcp.json                  # MCP サーバ設定 (チーム共有)
├── CLAUDE.md                  # このファイル
└── .gitignore
```

---

## Hooks (完全ブロック)

`.claude/settings.json` で以下を設定:

| イベント | マッチャ | スクリプト | 役割 |
|---------|---------|-----------|------|
| PreToolUse | `Write\|Edit\|MultiEdit` | `check-secrets.ps1` | シークレット/PIIの混入を阻止 |
| PreToolUse | `Write\|Edit\|MultiEdit` | `check-spec-required.ps1` | spec 無しでの `app/src/main/**` と `infra/**/*.tf` 書き込みを阻止 |
| PreToolUse | `Bash` | `check-commit-gate.ps1` | `git commit` 前にテスト実行 |

ブロックされた時は、メッセージに従って正しい手順を踏むこと。**ブロック回避を目的に hook を無効化・--no-verify する行為は禁止**。本当にルールがおかしいなら CLAUDE.md と hook を改定する PR を出す。

---

## MCP サーバ (正しい一次情報を引きに行く)

`.mcp.json` で 2 つの MCP サーバを有効化済み (`.claude/settings.json` の `enabledMcpjsonServers` で許可済み)。

| 名前 | 用途 | 起動 | 認証 |
|------|------|------|------|
| `aws-knowledge` | AWS 公式ドキュメント / Well-Architected / Blog / Builder Center の検索 | `uvx mcp-proxy-for-aws@latest --skip-auth` (リモート Managed) | 不要 (※`--skip-auth` 必須。これが無いと SigV4 署名で AWS 認証要求) |
| `terraform` | Terraform Registry (プロバイダ・モジュール) 検索、HCP 操作 | Docker `hashicorp/terraform-mcp-server:0.5.2` | Registry 用途は不要 |

**運用ルール:**
- AWS リソース / IAM ポリシー / Well-Architected を扱う時は、**まず `aws-knowledge` MCP** で現行ドキュメントを引く。記憶だけで書かない (古い API・廃止サービス・存在しないリソース名を避けるため)。
- Terraform プロバイダ・モジュール (例: `aws_lambda_function` の最新引数) を扱う時は、**まず `terraform` MCP** で Registry を引く。
- MCP は読み取り専用。書き込み権限のあるツール (AWS CLI 等) を MCP 経由で追加する場合は別途承認プロセスを置く。
- バージョン更新: `0.5.2` → 新バージョンへの上げは PR で行う (再現性のためタグ固定)。

---

## Windows / PowerShell 前提

開発機は Windows + PowerShell。Bash も使えるが、hook やスクリプトは PowerShell で書く (`.ps1`)。`specify` CLI は `PYTHONIOENCODING=utf-8` を付けて実行する (cp932 で Rich が落ちる回避)。

---

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->
