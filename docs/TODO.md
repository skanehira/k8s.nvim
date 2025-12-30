# TODO: k8s.nvim

作成日: 2025-12-30
生成元: planning-tasks
設計書: docs/DESIGN.md

## 概要

Neovim内でKubernetesクラスタを管理するLuaプラグイン。k9sライクなUIでリソース一覧、describe、ログ、exec、ポートフォワードなどの操作を提供する。

## 実装タスク

### フェーズ1: 基盤構築

- [x] プロジェクト構造のセットアップ
  - [x] ディレクトリ構造作成
  - [x] .luarc.json（lua-language-server設定）
  - [x] stylua.toml（フォーマッタ設定）
  - [x] .luacheckrc（リント設定）
  - [x] テスト実行環境（Makefile）

### フェーズ2: インフラ層（kubectl adapter）

依存なし。最初に実装することでドメイン層のテストが容易になる。

- [x] [RED] parserのテスト作成（JSON→Resourceパース）
- [x] [GREEN] parser.lua実装
- [x] [REFACTOR] パーサーのエラーハンドリング改善

- [x] [RED] kubectl adapterのテスト作成（get_resources）
- [x] [GREEN] adapter.lua実装（get_resources）
- [x] [RED] adapter describeのテスト作成
- [x] [GREEN] describe実装
- [x] [RED] adapter delete/scale/restartのテスト作成
- [x] [GREEN] delete/scale/restart実装
- [x] [RED] adapter exec/logs/port_forwardのテスト作成
- [x] [GREEN] exec/logs/port_forward実装（vim.fn.termopen）
- [x] [RED] adapter get_contexts/use_context/get_namespacesのテスト作成
- [x] [GREEN] context/namespace操作実装
- [x] [REFACTOR] adapter全体の共通処理抽出

### フェーズ3: ドメイン層（Resources）

リソース定義。メタ情報（対応操作、カラム定義へのヒント）を含む。

- [x] [RED] resource基底クラスのテスト作成
- [x] [GREEN] resource.lua実装（全リソースの capabilities を含む）
- [x] ~~[RED] Podリソースのテスト作成~~ (resource.lua に統合)
- [x] ~~[GREEN] pod.lua実装~~ (resource.lua に統合)
- [x] ~~[RED] Deploymentリソースのテスト作成~~ (resource.lua に統合)
- [x] ~~[GREEN] deployment.lua実装~~ (resource.lua に統合)
- [x] ~~[GREEN] service.lua等~~ (resource.lua に統合)
- [x] [REFACTOR] リソース共通処理の抽出 → 最初から resource.lua に統合済み

### フェーズ4: ドメイン層（State）

状態管理。ScopeとConnectionsに分離。

- [x] [RED] scope.luaのテスト作成（context/namespace/cache管理）
- [x] [GREEN] scope.lua実装
- [x] ~~[RED] scope更新時のキャッシュ無効化テスト~~ (scope.lua内に統合)
- [x] ~~[GREEN] キャッシュ無効化実装~~ (scope.lua内に統合)

- [x] [RED] connections.luaのテスト作成（PF管理）
- [x] [GREEN] connections.lua実装
- [x] ~~[RED] PF追加・削除・一覧のテスト~~ (connections_spec.luaに統合)
- [x] ~~[GREEN] PF操作実装~~ (connections.luaに統合)
- [x] [REFACTOR] State全体の整理（変更不要）

### フェーズ5: ドメイン層（Actions）

ロジックを持つ操作のみ。describe, delete, scale, restart等はadapterを直接利用。

- [x] [RED] list.luaのテスト作成（リソース一覧取得）
- [x] [GREEN] list.lua実装（fetch, filter, sort）
- [x] ~~[RED] フィルタリングのテスト作成~~ (list_spec.luaに統合)
- [x] ~~[GREEN] フィルタリング実装~~ (list.luaに統合)
- [x] ~~[RED] ソート（NAME順）のテスト作成~~ (list_spec.luaに統合)
- [x] ~~[GREEN] ソート実装~~ (list.luaに統合)
- [x] [REFACTOR] setup()パターン廃止、関数引数でadapterを渡す形式に変更

### フェーズ6: UI層（Components）

- [x] [RED] layout.luaのテスト作成（3ウィンドウ構成）
- [x] [GREEN] layout.lua実装（NuiPopup×3）

- [x] [RED] table.luaのテスト作成（NuiLine/NuiText描画）
- [x] [GREEN] table.lua実装

- [x] [RED] header.luaのテスト作成
- [x] [GREEN] header.lua実装（Context/NS/View表示、Loading...）

- [x] [RED] menu.luaのテスト作成（telescope/NuiMenu切り替え）
- [x] [GREEN] menu.lua実装

- [x] [RED] input.luaのテスト作成（NuiInput）
- [x] [GREEN] input.lua実装

- [x] [RED] confirm.luaのテスト作成（vim.fn.confirm）
- [x] [GREEN] confirm.lua実装

- [x] [RED] filter.luaのテスト作成（vim.fn.inputコマンドライン入力）
- [x] [GREEN] filter.lua実装

- [x] [RED] secret_mask.luaのテスト作成（Secretマスク表示/トグル）
- [x] [GREEN] secret_mask.lua実装

- [x] [REFACTOR] コンポーネント間の整合性確認

### フェーズ7: UI層（Views）

#### ロジック層（テスト可能）
- [x] [RED] resource_list.luaのテスト作成
- [x] [GREEN] resource_list.lua実装
- [x] [RED] キーマップ（d, l, e, D, s, X, r, /, R, C, N, S, p, F, P, ?, q, Esc）テスト
- [x] [GREEN] キーマップ実装
- [x] [RED] 自動更新（5秒間隔）テスト
- [x] [GREEN] 自動更新実装

- [x] [RED] describe.luaのテスト作成
- [x] [GREEN] describe.lua実装（filetype=yaml）

- [x] [RED] port_forward_list.luaのテスト作成
- [x] [GREEN] port_forward_list.lua実装

- [x] [RED] help.luaのテスト作成
- [x] [GREEN] help.lua実装（フッター拡張形式）
- [x] [REFACTOR] View間の共通処理抽出（utils.lua）

#### 描画層（nui.nvim依存）
- [ ] [RED] renderer.luaのテスト作成（モック使用）
- [ ] [GREEN] renderer.lua実装
  - [ ] NuiPopupで3ウィンドウ生成（ヘッダー/コンテンツ/フッター）
  - [ ] NuiLine/NuiTextでテーブル描画
  - [ ] バッファ再利用
  - [ ] キーマップ設定
  - [ ] vim.uvタイマーで自動更新

- [ ] [RED] terminal.luaのテスト作成（ログ/exec別タブ管理）
- [ ] [GREEN] terminal.lua実装
  - [ ] 新規タブでターミナルモード起動
  - [ ] タブ名設定（[logs] pod-name, [exec] pod-name）
  - [ ] タブ閉じ時にプロセス終了
  - [ ] exec終了時にタブ自動クローズ

- [ ] [RED] container_select.luaのテスト作成（コンテナ選択メニュー）
- [ ] [GREEN] container_select.lua実装（複数コンテナ時の選択UI）

- [ ] [RED] port_select.luaのテスト作成（ポート選択メニュー）
- [ ] [GREEN] port_select.lua実装（リモートポート自動検出・選択）

- [ ] [REFACTOR] 描画層の共通処理抽出

### フェーズ8: UI層（columns）

- [ ] [RED] columns.luaのテスト作成
- [ ] [GREEN] columns.lua実装（リソースタイプごとのカラム定義）
- [ ] [REFACTOR] カラム定義の最適化

### フェーズ9: API層（ファサード）

- [ ] [RED] api.luaのテスト作成（統一API）
- [ ] [GREEN] api.lua実装（adapterを直接利用）

- [ ] [RED] health.luaのテスト作成（起動時チェック）
- [ ] [GREEN] health.lua実装
  - [ ] kubectlの存在チェック（vim.fn.executable）
  - [ ] エラー時はvim.notifyでメッセージ表示

- [ ] [RED] notify.luaのテスト作成（通知ヘルパー）
- [ ] [GREEN] notify.lua実装
  - [ ] エラー/警告/情報の統一インターフェース
  - [ ] 破壊的操作の通知

- [ ] [REFACTOR] API設計の見直し

### フェーズ10: エントリポイント

- [ ] [RED] config.luaのテスト作成（設定マージ・検証）
- [ ] [GREEN] config.lua実装
  - [ ] デフォルト設定定義
  - [ ] ユーザー設定マージ
  - [ ] キーマップカスタマイズ対応

- [ ] [RED] init.luaのテスト作成（setup, toggle, open, close）
- [ ] [GREEN] init.lua実装
  - [ ] setup() - 設定初期化
  - [ ] toggle() - UI表示切り替え
  - [ ] open() / close() - UI開閉
  - [ ] open_resource(kind) - 特定リソース表示

- [ ] [RED] plugin/k8s.luaのテスト作成
- [ ] [GREEN] plugin/k8s.lua実装
  - [ ] 遅延読み込み（初回使用時にrequire）
  - [ ] ユーザーコマンド定義
    - [ ] :K8s（トグル）
    - [ ] :K8s open / :K8s close
    - [ ] :K8s pods / :K8s deployments / :K8s services / :K8s nodes
    - [ ] :K8s context [name] / :K8s namespace [name]
    - [ ] :K8s portforwards
  - [ ] `<Plug>`マッピング定義
    - [ ] `<Plug>(k8s-toggle)`
    - [ ] `<Plug>(k8s-open)`
    - [ ] `<Plug>(k8s-close)`

- [ ] [RED] autocmd.luaのテスト作成（ライフサイクル管理）
- [ ] [GREEN] autocmd.lua実装
  - [ ] Neovim終了時（VimLeavePre）に全ポートフォワード停止
  - [ ] タブ閉じ時のプロセスクリーンアップ

- [ ] [REFACTOR] 起動時間の最適化

### フェーズ11: 統合・品質保証

- [ ] [STRUCTURAL] 全体コード整理（動作変更なし）
- [ ] 全テスト実行と確認
- [ ] lint/format/型チェックの確認

- [ ] ハイライトグループ定義
  - [ ] K8sStatusRunning（緑: Running, Completed, Active, Ready）
  - [ ] K8sStatusPending（黄: Pending, Waiting, ContainerCreating）
  - [ ] K8sStatusError（赤: Error, Failed, CrashLoopBackOff, Terminating）
  - [ ] デフォルトカラー設定
  - [ ] ユーザーカスタマイズ対応

- [ ] パフォーマンス最適化
  - [ ] 差分更新（変更行のみ再描画）
  - [ ] 大量リソース時の対応検討（1000件以上）

- [ ] doc/k8s.txt（Vimヘルプ）作成
  - [ ] インストール方法
  - [ ] 設定オプション
  - [ ] キーマップ一覧
  - [ ] コマンド一覧
  - [ ] トラブルシューティング

## 実装ノート

### アーキテクチャ変更（2025-12-30）

- **Ports層を削除**: adapterを直接利用するシンプルな設計に変更
- **Actions層を簡素化**: ロジックを持つlist.luaのみ残し、describe/delete/scale/restart等はadapterを直接呼び出し
- **list.lua**: setup()パターンを廃止し、fetch(adapter, kind, namespace, callback)形式に変更

### MUSTルール遵守事項
- TDD: RED → GREEN → REFACTOR サイクルを厳守
- Tidy First: 構造変更と動作変更を分離
- コミット: 意味のある単位でこまめにコミット

### 依存関係の順序
```
infra/kubectl（依存なし）
    ↓
domain/resources
domain/state（依存なし）
    ↓
domain/actions（listのみ、純粋関数中心）
    ↓
api.lua（domain全体、adapterに依存）
    ↓
ui/components（nui.nvimに依存）
    ↓
ui/views（components, api, stateに依存）
    ↓
init.lua, config.lua, plugin/k8s.lua
```

### 参照ドキュメント
- 設計書: docs/DESIGN.md
- nui.nvim: https://github.com/MunifTanjim/nui.nvim
- plenary.nvim: https://github.com/nvim-lua/plenary.nvim
