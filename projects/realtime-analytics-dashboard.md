---
title: Untitled Memo
tags: []
created: 2025-10-25
updated: 2025-10-25
---

# Realtime Analytics Dashboard

# 指示書：realtime-analytics-dashboard（VS Code＋Codex 実装ガイド）

> 目的：**React（Vite/TypeScript）+ FastAPI + PostgreSQL + Redis + WebSocket**でリアルタイム可視化ダッシュボードを実装するための、VS Code＋Codex 前提の実装手順・チェックリスト。

---

## 0. ゴール/Definition of Done（DoD）
- `docker compose up` のワンコマンドで **バックエンド/フロント/DB/Redis** が起動し、**ブラウザでダッシュボードが動作**する。
- WebSocket で 1秒間隔の模擬メトリクス（例：CPU/メモリ/任意のセンサー値）が **リアルタイム表示**される。
- REST API で履歴メトリクス取得、JWT 認証（email+password）、基本的な RBAC（admin/user）実装。
- バックエンドは **pytest**、フロントは **Vitest**（＋必要に応じて Playwright）で基本テストが通る。
- GitHub Actions（CI）が lint/test/build を通し、main への PR マージで Docker イメージをビルド（ローカル Registry or GHCR）。
- README に **アーキ図（Mermaid）/セットアップ/API仕様/スクショ** を掲載。

---

## 1. リポジトリ構成（最終形）
```text
realtime-analytics-dashboard/
├─ src/
│  ├─ backend/              # FastAPI アプリ本体
│  │  ├─ app/
│  │  │  ├─ api/           # ルータ（/auth, /metrics など）
│  │  │  ├─ core/          # 設定, セキュリティ, 依存性
│  │  │  ├─ db/            # SQLAlchemy, セッション, CRUD
│  │  │  ├─ models/        # ORM モデル
│  │  │  ├─ schemas/       # Pydantic スキーマ
│  │  │  ├─ services/      # ドメインロジック（集計, 配信）
│  │  │  ├─ ws/            # WebSocket エンドポイント
│  │  │  └─ main.py        # FastAPI エントリ
│  │  └─ tests/            # pytest
│  ├─ frontend/             # Vite + React + TS
│  │  ├─ src/
│  │  │  ├─ components/
│  │  │  ├─ pages/
│  │  │  ├─ hooks/
│  │  │  ├─ lib/            # API/WS クライアント
│  │  │  └─ main.tsx
│  │  └─ tests/
│  └─ shared/               # 共通 DTO, 型, 定数（必要なら）
├─ deploy/
│  ├─ docker/               # Dockerfile 群
│  └─ k8s/                  # 余力で Helm/K8s マニフェスト
├─ docker-compose.yml
├─ .env.example
├─ README.md
├─ docs/
│  ├─ architecture.mmd      # Mermaid 図
│  └─ api-spec.md
└─ .github/
   └─ workflows/ci.yml
```

---

## 2. 技術選定（理由要約）
- **FastAPI**：ASGI + 型安全、Swagger 自動生成、WebSocket 連携が容易。
- **PostgreSQL**：履歴メトリクスの蓄積、時間系インデックスが安定。
- **Redis**：WS への配信バス（Pub/Sub）や突発バーストの緩衝に最適。
- **Vite + React + TypeScript**：起動/ビルド高速＆型で堅牢。
- **Tailwind**：スタイル速度重視、UI スケールしやすい。
- **GitHub Actions**：標準 CI。pytest/Vitest/ビルド/コンテナ化まで自動。

---

## 3. ユースケース/ユーザーストーリー
- **US-01**：ユーザはログインし、ダッシュボードにアクセスできる。
- **US-02**：ダッシュボードは WS を通じて 1s 毎に新規メトリクスを描画する。
- **US-03**：ユーザは期間（from/to）でメトリクス履歴を REST 経由で取得できる。
- **US-04**：管理者はユーザ作成/権限付与ができる（最低限 CLI or API）。

---

## 4. API/WS 仕様（最小スコープ）
### 認証
- `POST /auth/login`：email, password → {access_token, token_type}
- `POST /auth/refresh`：リフレッシュ（必要に応じて）

### メトリクス
- `GET /metrics?from=ISO8601&to=ISO8601&type=cpu|mem|sensorX` → 配列（時刻, 値）
- `POST /metrics`（admin or internal use）：メトリクス投入（PoC ではモック生成器）

### WebSocket（ASGI）
- `GET /ws/metrics?type=cpu|mem|sensorX` → 1s 間隔で {timestamp, value} を push

### DTO（例）
- `MetricPoint`: { timestamp: string(ISO8601), value: number, type: string }
- `MetricSeriesResponse`: { series: MetricPoint[] }

---

## 5. DB スキーマ（最小）
- **users**(id, email[unique], password_hash, role[enum:user|admin], created_at)
- **metrics**(id, type, value(float), ts(timestamptz), created_at)
- **sessions**（任意：JWT ブラックリストや監査用）

> マイグレーションは Alembic。メトリクス(ts) に **btree index** を付与。

---

## 6. 環境変数（.env.example）
```ini
# Backend
APP_ENV=local
SECRET_KEY=change-this
ACCESS_TOKEN_EXPIRE_MINUTES=60
CORS_ORIGINS=http://localhost:5173

# DB
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=radb
POSTGRES_USER=radb
POSTGRES_PASSWORD=radb

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
```

---

## 7. Docker Compose（サービス定義の粒度）
- **backend**：`uvicorn app.main:app`、依存：db, redis
- **frontend**：`vite dev`（dev 時）/ `nginx`（prod 時）
- **db**：postgres:15、初期化 SQL/ボリューム
- **redis**：redis:7
- **seed**（任意）：開発用に模擬メトリクスを Redis Pub/Sub や DB へ流す

> PoC 段階は単一ネットワークで OK。将来は `frontend` を静的配信（nginx）に分離。

---

## 8. セキュリティ/基本ポリシー
- JWT（HS256）。`/auth/login` で発行、`Authorization: Bearer`。
- CORS を環境変数で厳格管理。
- パスワードは `bcrypt` ハッシュ化。
- レート制限は将来 `slowapi` などで追加可能（現段階は省略）。

---

## 9. 観測性/運用（任意の発展）
- ログ：構造化 JSON（uvicorn, app ロガー統一）。
- メトリクス：Prometheus エンドポイント追加（余力があれば）。
- ダッシュボード：Grafana でバックエンド/WS のレイテンシを可視化（発展）。

---

## 10. パフォーマンス目標（PoC）
- WS スループット：1 room / 1Hz / 100 クライアントで安定配信。
- API P95 < 100ms（ローカル環境）
- 初期ロード < 2s（ローカル、キャッシュ無）

---

## 11. テスト戦略
- **Backend**：pytest + httpx + sqlite/in-memory。主要エンドポイント、認証、DAO。
- **Frontend**：Vitest（ユニット） + React Testing Library。E2E は余力で Playwright。
- **CI**：`lint → unit test → build` を GitHub Actions で毎 PR 実行。

---

## 12. Git 運用/規約
- ブランチ：`main`（保護）/ `feat/*` / `fix/*` / `chore/*`
- コミット：Conventional Commits（例：`feat: add ws endpoint`）
- PR テンプレート：目的/変更点/スクショ/テスト観点/リスク/ロールバック
- Issue テンプレ：バグ/機能/タスク用に3種

---

## 13. VS Code＋Codex での進め方（プロンプト雛形付き）
### 13.1 初期化（ローカル）
```bash
mkdir realtime-analytics-dashboard && cd $_
git init -b main
```

**Codex への指示（例）**
- *"Vite(React+TS) と FastAPI の空プロジェクトを `src/frontend`, `src/backend` に作成して。Poetry（backend）と pnpm（frontend）。Dockerfile と docker-compose も雛形を置いて、`docker compose up` で dev 環境が起動する状態にして。README の最初の章も生成して。"*

### 13.2 バックエンド基本
- 依存：fastapi, uvicorn[standard], pydantic, python-jose, passlib[bcrypt], sqlalchemy, asyncpg or psycopg, alembic, redis, httpx, pytest
- 生成指示（例）：
  - *"FastAPI のエントリ `app/main.py` を作り、`/health`, `/auth/login`, `/metrics`(GET) の最小実装と Swagger 表示を用意。Pydantic スキーマと依存注入を `core` に分割。JWT 発行処理を `core/security.py` に実装。Alembic 初期化と users/metrics テーブルを作る revision を追加。"*

### 13.3 WebSocket
- 生成指示（例）：
  - *"`/ws/metrics` の WS ルータを `ws/metrics.py` に作成。Redis Pub/Sub で `metrics:cpu` 等のチャネルを購読し、1秒ごとに受信値をブロードキャスト。テスト用に `services/generator.py` を作って、開発時のみダミーデータを publish する。"*

### 13.4 フロントエンド
- 依存：react, react-dom, typescript, vite, tailwindcss, @tanstack/react-query, zod, axios, vitest, @testing-library/react
- 生成指示（例）：
  - *"ログインページとダッシュボードページを作成。`lib/api.ts` に axios クライアント、`lib/ws.ts` に WS クライアント。`components/MetricChart.tsx` は Recharts で時系列を描画（1s 更新）。トークンは localStorage に保持し、react-query で `/metrics` 履歴を取得。"*

### 13.5 Docker/Compose
- 生成指示（例）：
  - *"backend 用 Dockerfile（Poetry キャッシュ最適化）と frontend 用 Dockerfile（ビルド→nginx 配信）を作成。`docker-compose.yml` に backend, frontend, db(Postgres), redis を定義。`depends_on`, `healthcheck` を設定。`.env.example` を読み込むように。"*

### 13.6 CI（GitHub Actions）
- 生成指示（例）：
  - *"`.github/workflows/ci.yml` を作り、Python/Node の matrix で lint・test・build を実行。main への push で Docker ビルド（GHCR publish はコメントアウトで雛形）。"*

### 13.7 README & 図
- 生成指示（例）：
  - *"`docs/architecture.mmd` に Mermaid でアーキ図を作成（frontend ⇄ backend(REST/WS) ⇄ Redis ⇄ Postgres）。`README.md` にセットアップ、.env、起動手順、スクショのセクションを雛形記述。"*

---

## 14. 受け入れチェックリスト（PR 用）
- [ ] `docker compose up` で 4 サービスがヘルシーに起動
- [ ] `/health` が 200 を返す
- [ ] `/auth/login` が JWT を返す（固定シードユーザで OK）
- [ ] `/ws/metrics?type=cpu` に接続で 1s ごとに JSON 受信
- [ ] `/metrics` で履歴が返る（from/to 指定）
- [ ] Vitest & pytest がグリーン
- [ ] README にアーキ図/スクショがある

---

## 15. リスクとその軽減
- **WS のバックプレッシャ**：Redis Pub/Sub + バッファ閾値で drop/遅延を制御。
- **CORS/認証の行き違い**：ローカルは `CORS_ORIGINS` を 1ホストに固定。
- **フロントの再接続**：WS エラー時に指数的バックオフで再接続。

---

## 16. 次の拡張（ロードマップ）
- マルチテナント、ダッシュボード編集（保存/共有）、ロール毎の可視範囲。
- TSDB（TimescaleDB）導入、集計クエリの最適化。
- 監査ログ、OpenTelemetry、CD（ECS/K8s）。

---

## 17. 作業フロー（1スプリント分の目安）
1. スキャフォールド（backend/frontend/Docker/Compose/README）
2. 認証実装（固定シード + bcrypt）
3. Metrics CRUD + Alembic + REST GET
4. WS 実装 + ダミージェネレータ
5. フロント：ログイン→ダッシュボード→チャート
6. E2E/CI 整備
7. 仕上げ（README、スクショ、図）

---

### 付録A：Codex への一括プロンプト例（最初のPR用）
> 「以下を順に実装してください：
> 1) `src/backend` に FastAPI 雛形（/health, /auth/login, /metrics GET）。JWT 発行、Pydantic スキーマ、Alembic 初期化、users/metrics テーブル migration。
> 2) `src/backend/app/ws/metrics.py` に `/ws/metrics` 実装（Redis Pub/Sub）。`services/generator.py` で開発時のみダミー publish。
> 3) `src/frontend` に Vite(React+TS) 雛形。ログイン/ダッシュボード/チャート。axios/zod/react-query。WS クライアント。
> 4) `docker-compose.yml` と Dockerfile を作成（backend/frontend/db/redis）。`.env.example` から設定。
> 5) GitHub Actions で lint/test/build を回す `ci.yml` を追加。README と Mermaid 図も雛形。」

### 付録B：レビュー観点（レビュワー用）
- レイヤ分離（api/core/db/services/ws）が守られているか
- 例外処理・バリデーション
- 型/スキーマの整合性（Pydantic & Zod）
- テストの粒度（ユニット/統合）
- Docker ビルドキャッシュ最適化

---


完璧です。
uv に移行した場合の環境構築・依存管理を前提に、**Codexで使うプロンプト群（全8個）**を再構築しました。
Poetry関連をすべて uv ベース（超高速Pythonパッケージマネージャ）に置き換えています。
※uvのコマンド例は uv init, uv add, uv run, uv pip install, .python-version 管理などを前提。

⸻

✅ Codex用プロンプト一覧（uv対応）

⸻

PROMPT 1/8：DB・Alembic 基本（users / metrics 作成）

目的：PostgreSQL接続・SQLAlchemy/Alembic初期化・users/metricsテーブル構築

このプロジェクトで以下を実行して下さい（品質=Medium）:

[要件]
- backend=FastAPI(Python3.12, uv管理)
- DB=PostgreSQL, マイグレーション=Alembic
- 接続文字列: postgresql+psycopg://radb:radb@db:5432/radb
- users/metrics のスキーマを作成し、Alembicで管理

[作業]
1) uvで依存を追加:
   uv add fastapi "uvicorn[standard]" sqlalchemy psycopg[binary] alembic pydantic-settings passlib[bcrypt] python-jose[cryptography]
   uv add --dev pytest httpx

2) src/backend 配下に以下を作成:
   - app/db/session.py: engine, SessionLocal, get_db関数（syncでOK）
   - app/models/base.py: DeclarativeBase 定義
   - app/models/user.py: email(unique,index), password_hash, role(enum:user|admin)
   - app/models/metric.py: type(str,index), value(float), ts(datetime, index)

3) Alembic 初期化:
   uv run alembic init alembic
   - alembic/env.py: Base.metadataをimportしてtarget_metadataに設定
   - alembic.ini の sqlalchemy.url は環境変数読み込みに変更

4) リビジョン作成:
   uv run alembic revision -m "init users & metrics" → uv run alembic upgrade head

5) app/core/config.py: 環境変数管理 (pydantic-settings)
6) /health で DB 接続確認できるようにする

[成果物]
- users/metrics テーブル作成済み
- alembic upgrade head 成功
- README に「uvでの依存管理＋マイグレーション手順」追記


⸻

PROMPT 2/8：認証（JWT）

以下を実行して下さい（品質=Medium）:

[要件]
- HS256 JWT でログイン実装
- email/password → token 発行
- 管理者ユーザー1件を起動時にseed投入

[作業]
1) app/core/security.py:
   - create_access_token(), verify_password(), get_password_hash()
2) app/schemas/auth.py: LoginRequest, TokenResponse
3) app/api/auth.py: POST /auth/login 実装
4) app/dependencies/auth.py: get_current_user(Bearer検証)
5) app/db/seed.py: admin@example.com / adminpass / role=admin
6) /metrics を認証必須に変更


⸻

PROMPT 3/8：Redis × WebSocket（1Hz 配信）

以下を実装して下さい（品質=Medium）:

[要件]
- /ws/metrics?type=cpu で 1Hz 送信
- Redis Pub/Sub 経由
- DEV 時のみダミーデータを publish

[作業]
1) uv add redis
2) app/ws/metrics.py:
   - Redisから購読してクライアントへブロードキャスト
   - 切断時クリーンアップ
3) app/services/generator.py:
   - 開発モードのみバックグラウンドで1Hz publish
4) backend コンテナに REDIS_HOST/PORT 環境変数設定


⸻

PROMPT 4/8：フロント最小実装（ログイン→ダッシュボード）

以下を実装して下さい（品質=Medium）:

[要件]
- React + Vite + TS
- axios, react-query, zod, recharts
- localStorage に token 保持
- REST + WS でメトリクス表示

[作業]
1) src/frontend/src/lib/api.ts: axios設定＋Interceptor
2) src/frontend/src/lib/ws.ts: WSラッパ（再接続）
3) /login, /dashboard ページ作成
   - login → JWT 保存
   - dashboard → REST履歴取得＋WSリアルタイム
4) .env.example に FRONTEND_URL 追記


⸻

PROMPT 5/8：Docker Compose 補強

以下を実装して下さい（品質=Medium）:

[要件]
- backend, frontend, db, redis の4サービス
- healthcheckあり、.env.exampleを読み込む

[作業]
1) docker-compose.yml:
   - backend: depends_on に db/redisのhealthcheck
   - backend command: uv run alembic upgrade head → uv run uvicorn app.main:app
   - redis: healthcheck=redis-cli ping
   - db: pg_isready
2) backend Dockerfile:
   - uv を使ったキャッシュ最適化 (uv sync --frozen)


⸻

PROMPT 6/8：pre-commit 導入

以下を実装して下さい（品質=Medium）:

[要件]
- .pre-commit-config.yaml をルートに配置
- hooks: pre-commit-hooks, ruff, black, prettier, eslint
- backend の pyproject.toml で ruff/black 設定
- frontend に eslint/prettier 設定

[作業]
1) uv add -G dev black ruff pre-commit
2) ルートに .pre-commit-config.yaml
3) src/frontend/.eslintrc.json, .prettierrc, .prettierignore 作成
4) pre-commit install && pre-commit run --all-files


⸻

PROMPT 7/8：CI（GitHub Actions）

以下を実装して下さい（品質=Medium）:

[要件]
- .github/workflows/ci.yml 作成
- backend: uvで lint/test
- frontend: pnpmで prettier/eslint/vitest

[作業]
1) backend:
   - setup-python 3.12
   - pip install uv
   - uv sync --frozen
   - uv run ruff check .
   - uv run pytest
2) frontend:
   - setup-node 20
   - pnpm install
   - pnpm run lint
   - pnpm run test


⸻

PROMPT 8/8：検証チェックリスト

最後に以下を確認:

- /auth/login: 成功/失敗パターン動作確認
- /metrics: 認証必須・200 OK確認
- /ws/metrics: 1Hz配信・再接続確認
- pre-commit run --all-files → OK
- docker compose up → healthy 全通過


⸻

🧠 運用ヒント
	•	uvはCI/CDでもPoetryより軽量なので uv sync --frozen で環境固定を保ちやすい。
	•	uv run alembic upgrade head を entrypoint に仕込むと自動マイグレーション。
	•	Codexでは "このタスクは uv 環境で実行して" と毎回明記するとズレ防止になる。

⸻
