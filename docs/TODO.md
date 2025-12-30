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

#### ヘルパー層（テスト可能）
- [x] [RED] renderer.luaのテスト作成（モック使用）
- [x] [GREEN] renderer.lua実装（純粋関数: 位置計算、行構築、ハイライト取得）

- [x] [RED] terminal.luaのテスト作成（ログ/exec用ヘルパー）
- [x] [GREEN] terminal.lua実装（コマンド構築、状態管理、バリデーション）

- [x] [RED] container_select.luaのテスト作成（コンテナ選択ロジック）
- [x] [GREEN] container_select.lua実装（コンテナ抽出、メニュー項目生成）

- [x] [RED] port_select.luaのテスト作成（ポート選択ロジック）
- [x] [GREEN] port_select.lua実装（ポート抽出、メニュー項目生成）

- [x] [REFACTOR] ヘルパー層の共通処理抽出

### フェーズ8: UI層（columns）

- [x] [RED] columns.luaのテスト作成
- [x] [GREEN] columns.lua実装（リソースタイプごとのカラム定義）
  - [x] Pods: NAME, NAMESPACE, STATUS, READY, RESTARTS, AGE
  - [x] Deployments: NAME, NAMESPACE, READY, UP-TO-DATE, AVAILABLE, AGE
  - [x] Services: NAME, NAMESPACE, TYPE, CLUSTER-IP, EXTERNAL-IP, PORTS, AGE
  - [x] ConfigMaps: NAME, NAMESPACE, DATA, AGE
  - [x] Secrets: NAME, NAMESPACE, TYPE, DATA, AGE
  - [x] Nodes: NAME, STATUS, ROLES, AGE, VERSION
  - [x] Namespaces: NAME, STATUS, AGE
- [x] [REFACTOR] カラム定義の最適化

### フェーズ9: nui.nvim統合層（実際のUI表示）

**注**: このフェーズが実際にfloat windowを表示する核心部分。
純粋関数（設定生成、状態管理）はテスト可能な形で実装済み。
実際のNuiPopup操作は後続フェーズでapp.luaが統合する。

#### window.lua（NuiPopup管理）
- [x] [RED] window.luaのテスト作成
- [x] [GREEN] window.lua実装
  - [x] create_popup_config() - セクション別のPopup設定生成
  - [x] create_window_state() - ウィンドウ状態管理
  - [x] get_center_position() - 中央配置計算
  - [x] calculate_popup_size() - サイズ計算（80%デフォルト）
  - [x] get_buffer_options() - バッファオプション取得
  - [x] get_window_options() - ウィンドウオプション取得
  - [x] validate_section() - セクション名検証

#### buffer.lua（バッファ内容管理）
- [x] [RED] buffer.luaのテスト作成
- [x] [GREEN] buffer.lua実装
  - [x] create_header_content() - ヘッダーテキスト生成
  - [x] create_footer_content() - フッターテキスト生成
  - [x] create_table_line() - テーブル行生成
  - [x] create_header_line() - テーブルヘッダー行生成
  - [x] get_highlight_range() - ハイライト範囲計算
  - [x] find_status_column_index() - ステータスカラム検索
  - [x] prepare_table_content() - テーブルコンテンツ準備

#### keymap_binder.lua（キーマップ設定）
- [x] [RED] keymap_binder.luaのテスト作成
- [x] [GREEN] keymap_binder.lua実装
  - [x] create_keymap_config() - キーマップ設定生成
  - [x] validate_keymap_definition() - 定義検証
  - [x] create_handler_wrapper() - ハンドララッパー生成
  - [x] normalize_key() - キー正規化
  - [x] create_keymaps_from_definitions() - 一括設定生成
  - [x] get_action_for_key() - キーからアクション取得

#### timer.lua（自動更新タイマー）
- [x] [RED] timer.luaのテスト作成
- [x] [GREEN] timer.lua実装
  - [x] create_timer_config() - タイマー設定生成
  - [x] validate_interval() - 間隔検証
  - [x] create_timer_state() - タイマー状態管理
  - [x] update_timer_state() - 状態更新（イミュータブル）
  - [x] should_tick() - ティック判定
  - [x] create_tick_callback() - コールバック生成（エラーハンドリング付き）
  - [x] format_interval() - 間隔フォーマット

- [x] [REFACTOR] nui.nvim統合層の整理

### フェーズ10: アクションハンドラ層

**注**: キーマップから呼ばれる実際の処理。純粋関数として実装済み。

#### handlers/resource_actions.lua
- [x] [RED] resource_actions.luaのテスト作成
- [x] [GREEN] resource_actions.lua実装
  - [x] create_describe_action() - describeアクション生成
  - [x] create_delete_action() - 削除アクション生成（確認メッセージ付き）
  - [x] create_scale_action() - スケールアクション生成
  - [x] create_restart_action() - リスタートアクション生成
  - [x] validate_*_target() - 対象リソース検証

#### handlers/pod_actions.lua
- [x] [RED] pod_actions.luaのテスト作成
- [x] [GREEN] pod_actions.lua実装
  - [x] create_logs_action() - ログアクション生成
  - [x] create_exec_action() - execアクション生成
  - [x] create_port_forward_action() - ポートフォワードアクション生成
  - [x] needs_container_selection() - コンテナ選択要否判定
  - [x] get_default_container() - デフォルトコンテナ取得

#### handlers/navigation.lua
- [x] [RED] navigation.luaのテスト作成
- [x] [GREEN] navigation.lua実装
  - [x] create_select_action() - 選択アクション生成
  - [x] create_back_action() - 戻るアクション生成
  - [x] create_quit_action() - 終了アクション生成
  - [x] can_go_back() - 戻れるか判定
  - [x] get_cursor_resource() - カーソル位置リソース取得

#### handlers/filter_actions.lua
- [x] [RED] filter_actions.luaのテスト作成
- [x] [GREEN] filter_actions.lua実装
  - [x] create_filter_action() - フィルターアクション生成
  - [x] apply_filter() - フィルター適用
  - [x] is_filter_active() - フィルター有効判定

#### handlers/menu_actions.lua
- [x] [RED] menu_actions.luaのテスト作成
- [x] [GREEN] menu_actions.lua実装
  - [x] create_resource_menu_action() - リソースメニューアクション
  - [x] create_context_menu_action() - コンテキストメニューアクション
  - [x] create_namespace_menu_action() - ネームスペースメニューアクション
  - [x] get_resource_menu_items() - リソースメニュー項目取得

#### handlers/view_actions.lua
- [x] [RED] view_actions.luaのテスト作成
- [x] [GREEN] view_actions.lua実装
  - [x] create_refresh_action() - 更新アクション生成
  - [x] create_help_action() - ヘルプアクション生成
  - [x] create_toggle_secret_action() - シークレットトグルアクション生成
  - [x] toggle_help_state() - ヘルプ状態切替
  - [x] toggle_secret_state() - シークレットマスク状態切替

- [x] [REFACTOR] ハンドラの共通処理抽出

### フェーズ11: アプリケーションコントローラ

**注**: 全体を統括するメインモジュール。状態管理は純粋関数として実装済み。

#### app.lua（メインコントローラ）
- [x] [RED] app.luaのテスト作成
- [x] [GREEN] app.lua実装
  - [x] create_state() - アプリケーション状態生成
  - [x] set_running() - 実行状態設定
  - [x] set_kind() / set_namespace() - 現在のリソース設定
  - [x] set_resources() / set_filter() - データ設定
  - [x] get_filtered_resources() - フィルター適用済みリソース取得
  - [x] get_current_resource() - カーソル位置リソース取得

#### view_stack.lua（ビュースタック管理）
- [x] [RED] view_stack.luaのテスト作成
- [x] [GREEN] view_stack.lua実装
  - [x] push() - ビューをスタックに追加（イミュータブル）
  - [x] pop() - 前のビューに戻る（イミュータブル）
  - [x] current() - 現在のビュー取得
  - [x] clear() - スタッククリア
  - [x] can_pop() / peek() - スタック操作補助

#### update_loop.lua（更新ループ）
- [x] [RED] update_loop.luaのテスト作成
- [x] [GREEN] update_loop.lua実装
  - [x] create_state() - 更新ループ状態生成
  - [x] set_loading() / set_error() / set_last_update() - 状態更新
  - [x] should_update() - 更新要否判定
  - [x] get_retry_delay() - リトライ遅延計算（指数バックオフ）

- [x] [REFACTOR] コントローラ層の整理

### フェーズ12: API層（ファサード）

- [x] [RED] api.luaのテスト作成（統一API）
- [x] [GREEN] api.lua実装
  - [x] create_request() - APIリクエスト生成
  - [x] validate_request() - リクエスト検証
  - [x] get_required_params() - 必須パラメータ取得
  - [x] is_destructive_action() - 破壊的操作判定
  - [x] get_supported_actions() - サポートアクション一覧
  - [x] create_response() - レスポンス生成

- [x] [RED] health.luaのテスト作成（起動時チェック）
- [x] [GREEN] health.lua実装
  - [x] create_check_result() - チェック結果生成
  - [x] get_required_executables() - 必須コマンド一覧
  - [x] format_check_message() - チェックメッセージフォーマット
  - [x] get_health_status() - ヘルス状態判定
  - [x] format_health_report() - ヘルスレポート生成

- [x] [RED] notify.luaのテスト作成（通知ヘルパー）
- [x] [GREEN] notify.lua実装
  - [x] create_notification() - 通知生成
  - [x] format_action_message() - アクションメッセージフォーマット
  - [x] get_level_for_action() - アクション別通知レベル
  - [x] format_port_forward_message() - PFメッセージフォーマット
  - [x] format_context_switch_message() / format_namespace_switch_message()

- [x] [REFACTOR] API設計の見直し

### フェーズ13: エントリポイント

- [x] [RED] config.luaのテスト作成（設定マージ・検証）
- [x] [GREEN] config.lua実装
  - [x] get_defaults() - デフォルト設定取得
  - [x] merge() - ユーザー設定マージ（ディープマージ）
  - [x] validate() - 設定検証
  - [x] get_keymap() / get_all_keymaps() - キーマップ取得

- [x] [RED] init.luaのテスト作成（setup, toggle, open, close）
- [x] [GREEN] init.lua実装
  - [x] get_state() / is_setup_done() - 状態取得
  - [x] create_highlights() - ハイライト定義生成
  - [x] get_default_kind() - デフォルトリソース
  - [x] parse_command_args() - コマンド引数パース
  - [x] get_resource_kind_from_command() - コマンドからKind変換

- [x] [RED] plugin.luaのテスト作成（コマンド定義ヘルパー）
- [x] [GREEN] plugin.lua実装
  - [x] get_commands() - コマンド定義取得
  - [x] get_plug_mappings() - Plugマッピング取得
  - [x] get_command_completions() - 補完候補取得
  - [x] parse_command() - コマンドパース
  - [x] complete() - 補完関数

- [x] [RED] autocmd.luaのテスト作成（ライフサイクル管理）
- [x] [GREEN] autocmd.lua実装
  - [x] get_group_name() - autocmdグループ名
  - [x] get_autocmd_definitions() - autocmd定義取得
  - [x] create_cleanup_callback() - クリーンアップコールバック
  - [x] should_cleanup_on_event() - クリーンアップ要否判定

- [x] [REFACTOR] 起動時間の最適化

### フェーズ14: 統合・品質保証

- [x] [STRUCTURAL] 全体コード整理（動作変更なし）
- [x] 全テスト実行と確認（88ファイル、全パス）
- [x] lint/format/型チェックの確認（0 warnings, 0 errors）

- [x] ハイライトグループ定義（init.lua create_highlights()で実装済み）
  - [x] K8sStatusRunning（緑: Running, Completed, Active, Ready）
  - [x] K8sStatusPending（黄: Pending, Waiting, ContainerCreating）
  - [x] K8sStatusError（赤: Error, Failed, CrashLoopBackOff, Terminating）
  - [x] K8sHeader（ヘッダー用）
  - [x] K8sFooter（フッター用）
  - [x] K8sTableHeader（テーブルヘッダー用）

- [ ] E2Eテスト（主要ユーザーフロー）- 実環境で手動確認
- [ ] パフォーマンス最適化 - 必要時に実施
- [ ] doc/k8s.txt（Vimヘルプ）作成 - 必要時に実施
  - [ ] トラブルシューティング

### フェーズ15: アーキテクチャ改善

コードベースの保守性・テスタビリティを向上させるリファクタリング。

#### 状態管理の統一（完了）
- [x] scope.lua 削除（未使用）
- [x] update_loop.lua 削除（未使用）
- [x] app.lua から view_stack フィールド削除（重複）

#### Window初期化の共通化（完了）
describe_handler, port_forward_handler, menu_handler に重複する初期化コードを統一。

- [x] [RED] view_helper.lua のテスト作成
- [x] [GREEN] view_helper.lua 実装
  - [x] create_view_config() - ビュー設定生成
  - [x] validate_config() - 設定バリデーション
  - [x] create_view() - ウィンドウ作成・マウント・初期化を一括処理
  - [x] prepare_header_content() - ヘッダーコンテンツ生成
  - [x] prepare_footer_content() - フッターコンテンツ生成
- [x] [REFACTOR] 各ハンドラーを view_helper 使用に変更
  - [x] describe_handler.lua
  - [x] port_forward_handler.lua
  - [x] menu_handler.lua (handle_resource_menu, handle_help)

#### テスタビリティ向上（完了）
グローバル状態への依存を減らし、依存性注入パターンを導入。

- [x] [RED] 依存性注入パターンのテスト作成
- [x] [GREEN] deps.lua 実装
  - [x] get(name) - 依存性取得（オーバーライド優先）
  - [x] set(name, module) - 依存性オーバーライド
  - [x] reset() - オーバーライドリセット
  - [x] with_mocks(mocks, fn) - 一時的モック適用
  - [x] create_mock_global_state() - テスト用global_stateモック生成
  - [x] create_mock_adapter() - テスト用adapterモック生成
  - [x] create_mock_window() - テスト用windowモック生成
- [x] [REFACTOR] テストのセットアップ簡素化（モックファクトリ提供）

#### コールバック構造の明確化（完了）
callbacksオブジェクトの型定義と整理。

- [x] [RED] コールバック型定義のテスト作成
- [x] [GREEN] LuaCATS型注釈でCallbacks型を定義
  - [x] @class K8sCallbacks - ハンドラーに渡されるコールバック
  - [x] @class K8sHandlers - キーマップにバインドされるハンドラー
  - [x] validate_callbacks() - コールバック検証関数
  - [x] get_callback_requirements() - ハンドラー別要件取得
- [x] [REFACTOR] dispatcher.luaで型を使用

#### View Stackのポリモーフィズム化（完了）
handle_back() の条件分岐を削減。各viewに復帰処理を持たせる。

- [x] [RED] view type別 restore 関数のテスト作成
- [x] [GREEN] view_restorer.lua 実装
  - [x] get_restorer(view_type) - ビュータイプ別リストア関数取得
  - [x] get_footer_params(view, app_state) - フッターパラメータ取得
  - [x] needs_refetch(view, app_state) - 再フェッチ要否判定
  - [x] restore(view, callbacks, cursor, deps) - ポリモーフィック復帰処理
  - [x] restorers.list / describe / help / port_forward_list - 各ビュー固有の復帰ロジック
- [x] [REFACTOR] handle_back() を view_restorer.restore() 呼び出しに簡素化（75行→45行）

## 実装ノート

### アーキテクチャ変更（2025-12-30）

- **Ports層を削除**: adapterを直接利用するシンプルな設計に変更
- **Actions層を簡素化**: ロジックを持つlist.luaのみ残し、describe/delete/scale/restart等はadapterを直接呼び出し
- **list.lua**: setup()パターンを廃止し、fetch(adapter, kind, namespace, callback)形式に変更

### 追加アーキテクチャ（2025-12-30 更新）

- **nui.nvim統合層を追加**: window.lua, buffer.lua, keymap_binder.lua, timer.lua
- **アクションハンドラ層を追加**: キーマップから呼ばれる実際の処理
- **アプリケーションコントローラを追加**: app.lua, view_stack.lua, update_loop.lua

### レイヤー構成（更新版）

```
┌─────────────────────────────────────────────────────────────┐
│                    plugin/k8s.lua                           │
│                    (コマンド定義)                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                      init.lua                               │
│                 (Public API: setup, open, close)            │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                      app.lua                                │
│              (メインコントローラ)                            │
│  - view_stack.lua (ビュー管理)                              │
│  - update_loop.lua (更新ループ)                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 アクションハンドラ層                         │
│  handlers/resource_actions.lua (delete, scale, restart)     │
│  handlers/pod_actions.lua (logs, exec, port_forward)        │
│  handlers/navigation.lua (select, back, quit)               │
│  handlers/filter_actions.lua (filter, clear_filter)         │
│  handlers/menu_actions.lua (resource, context, namespace)   │
│  handlers/view_actions.lua (refresh, help, toggle_secret)   │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                  nui.nvim統合層                              │
│  window.lua (NuiPopup管理)                                  │
│  buffer.lua (バッファ描画)                                   │
│  keymap_binder.lua (キーマップ設定)                          │
│  timer.lua (自動更新タイマー)                                │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                      api.lua                                │
│                   (ファサード)                               │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                    ドメイン層                                │
│  domain/resources (リソース定義)                             │
│  domain/state (scope, connections)                          │
│  domain/actions (list)                                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                    UI層（ロジック）                          │
│  ui/views (resource_list, describe, help等のロジック)        │
│  ui/components (layout, table, header等のロジック)           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                    インフラ層                                │
│  infra/kubectl/adapter.lua (kubectl実行)                    │
└─────────────────────────────────────────────────────────────┘
```

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
ui/views, ui/components（ロジックのみ）
    ↓
api.lua（domain全体、adapterに依存）
    ↓
nui.nvim統合層（window, buffer, keymap_binder, timer）
    ↓
アクションハンドラ層（api, nui.nvim統合層に依存）
    ↓
app.lua（全体統括）
    ↓
init.lua, config.lua, plugin/k8s.lua
```

### 参照ドキュメント
- 設計書: docs/DESIGN.md
- nui.nvim: https://github.com/MunifTanjim/nui.nvim
- plenary.nvim: https://github.com/nvim-lua/plenary.nvim
