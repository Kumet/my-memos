# my-memos

Markdown ベースでメモを整理・検索するためのプライベートリポジトリです。個人用の知識ベースとして運用する前提でガイドラインをまとめています。

## 目的
- 日々のメモ・学び・アイデアを Markdown で蓄積し、検索しやすくする
- 冗長なドキュメントではなく、短くても価値のあるメモを素早く追加できるようにする
- Git を活用してバージョン管理・バックアップ・共同編集を実現する

## はじめに
1. リポジトリをクローン
   ```bash
   git clone https://github.com/Kumet/my-memos.git
   cd my-memos
   ```
2. リモート設定を確認（初回セットアップ時のみ）
   ```bash
   git remote add origin https://github.com/Kumet/my-memos.git
   git branch -M main
   git push -u origin main
   ```
   すでに `origin` が設定されている場合はこの手順は不要です。

## ディレクトリ構成のガイドライン
- `daily/` … 日次のメモ。`YYYY-MM-DD.md` 形式で保存すると検索性が高まります。
- `topics/` … 特定のテーマごとのメモ。`topic-name.md` 形式で管理します。
- `projects/` … プロジェクト単位で進捗や議事録をまとめる場所。
- `templates/` … 定型フォーマットのテンプレート。メモ作成時にコピーして使用します。
- `attachments/` … 参考資料（画像・PDF など）を保存する場合の保管場所。ファイル名にはメモのスラッグを含めると管理しやすくなります。

必要に応じてディレクトリを追加し、README に追記してください。差分がわかるように README と同時に更新しておくと運用がスムーズです。

## Markdown メモのベストプラクティス
- **1 ファイル 1 トピック** を意識し、ファイル名は簡潔かつ検索しやすいスラッグにする（例: `topics/docker-basics.md`）。
- 冒頭にフロントマターやメタ情報（タグ、作成日、更新日）を置くと、静的サイトジェネレーターや検索ツールで扱いやすくなります。
  ```markdown
  ---
  title: Docker 基本コマンド
  tags: [docker, container]
  created: 2024-04-04
  updated: 2024-04-06
  ---
  ```
- 重要なポイントはリストやテーブルで整理し、引用やコードブロックを活用して視認性を高める。
- 実行手順やコマンドは必ず検証し、結果やエラーも合わせて記録する。
- 関連メモには相互リンク（例: `See also: [[topics/docker-networking]]`）を付けるとナレッジの接続が強化される。Obsidian や Foam などのツールで可視化が可能。
- 追記や修正時は、「何を・なぜ変更したか」を冒頭に短く書くと、履歴から意図を追いやすい。

## 推奨ワークフロー
1. **メモ作成**: テンプレートをコピーし、必要事項を埋める。
2. **ローカルでプレビュー**: VS Code の Markdown プレビューや Obsidian などを使って見た目を確認。
3. **ステージング**:
   ```bash
   git status
   git add path/to/new-memo.md
   ```
4. **コミットメッセージ**は簡潔に（例: `Add memo on Docker basics`）。複数のメモを更新した場合はサマリを記載。
5. **プッシュ**:
   ```bash
   git push origin main
   ```
6. 必要に応じて Pull Request を作成し、レビューやコメントを通じて内容を深める。

### Makefile で素早くメモを追加
- `make memo NAME=topics/docker-basics TITLE="Docker Basics"` のように実行すると `templates/default-memo.md` を使って `.md` ファイルを生成します。
- `NAME` は拡張子なしでも構いません。指定したディレクトリがなければ自動作成されます。
- タイトル省略時はファイル名から自動生成されます（例: `docker-basics` → `Docker Basics`）。
- 日次メモは `make daily` で作成できます。`DATE=2024-04-06` と指定すれば任意の日付で生成可能です。

## バックアップ & 同期
- 定期的な `git pull` と `git push` でリポジトリを同期し、ローカルとリモートの齟齬を防ぐ。
- 別デバイスで編集する場合は、作業開始前に必ず `git pull` を実行しコンフリクトを回避。
- `.gitignore` を活用し、個人設定や一時ファイル（例: `.DS_Store`）は除外しておく。

## 自動化
- `.github/workflows/daily-auto-commit.yml` で日次の自動コミットを設定しています。Secrets で `PERSONAL_TOKEN` を登録すると、指定時刻に変更を検知してプッシュします。
- Lint やリンクチェックは自動化していません。必要に応じて手動で `markdownlint` やリンクチェッカーを実行し、結果を確認してからコミットしてください。

## VS Code 推奨拡張
- `Markdown All in One` … 見出しのショートカット、目次生成など Markdown 編集全般を強化。
- `Paste Image` … クリップボードの画像を自動で `attachments/` 配下へ保存し Markdown に貼り付け。
- `Markdown Link Updater` … ファイル名変更時にリンクを自動更新。
- `Spell Right` … 日本語・英語混在のスペルチェックをサポート。

## 拡張アイデア
- 静的サイトジェネレーター（例: 11ty, Astro, Docusaurus）で Web 公開し、検索を容易にする。
- Obsidian や Notion など、他ツールとの連携用スクリプトを `scripts/` フォルダにまとめる。

## ライセンス
個人メモの場合はライセンス不要ですが、外部共有する場合は `LICENSE` ファイルを追加しておくと安心です。

---

疑問点や改善案があれば Issues で管理するか、この README に追記して運用ルールを成長させていきましょう。
