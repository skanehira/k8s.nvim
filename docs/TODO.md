# TODO: k8s.nvim

作成日: 2025-12-30
生成元: planning-tasks
設計書: docs/DESIGN.md

## 概要

Neovim内でKubernetesクラスタを管理するLuaプラグイン。k9sライクなUIでリソース一覧、describe、ログ、exec、ポートフォワードなどの操作を提供する。

## 実装タスク

### フェーズ1: 基盤構築

- [ ] プロジェクト構造のセットアップ
  - [ ] ディレクトリ構造作成
  - [ ] .luarc.json（lua-language-server設定）
  - [ ] stylua.toml（フォーマッタ設定）
  - [ ] .luacheckrc（リント設定）
  - [ ] テスト実行環境（Makefile）

### フェーズ2: インフラ層（kubectl adapter）

依存なし。最初に実装することでドメイン層のテストが容易になる。

- [ ] [RED] parserのテスト作成（JSON→Resourceパース）
- [ ] [GREEN] parser.lua実装
- [ ] [REFACTOR] パーサーのエラーハンドリング改善

- [ ] [RED] kubectl adapterのテスト作成（get_resources）
- [ ] [GREEN] adapter.lua実装（get_resources）
- [ ] [RED] adapter describeのテスト作成
- [ ] [GREEN] describe実装
- [ ] [RED] adapter delete/scale/restartのテスト作成
- [ ] [GREEN] delete/scale/restart実装
- [ ] [RED] adapter exec/logs/port_forwardのテスト作成
- [ ] [GREEN] exec/logs/port_forward実装（vim.fn.termopen）
- [ ] [RED] adapter get_contexts/use_context/get_namespacesのテスト作成
- [ ] [GREEN] context/namespace操作実装
- [ ] [REFACTOR] adapter全体の共通処理抽出

### フェーズ3: ドメイン層（Ports）

インターフェース定義。LuaCATSの型のみ。

- [ ] kubectl_port.lua作成（型定義のみ）

### フェーズ4: ドメイン層（Resources）

リソース定義。メタ情報（対応操作、カラム定義へのヒント）を含む。

- [ ] [RED] resource基底クラスのテスト作成
- [ ] [GREEN] resource.lua実装
- [ ] [RED] Podリソースのテスト作成
- [ ] [GREEN] pod.lua実装（supports_exec, supports_logs等）
- [ ] [RED] Deploymentリソースのテスト作成
- [ ] [GREEN] deployment.lua実装（supports_scale, supports_restart等）
- [ ] [GREEN] service.lua, configmap.lua, secret.lua, node.lua, namespace.lua実装
- [ ] [REFACTOR] リソース共通処理の抽出

### フェーズ5: ドメイン層（State）

状態管理。ScopeとConnectionsに分離。

- [ ] [RED] scope.luaのテスト作成（context/namespace/cache管理）
- [ ] [GREEN] scope.lua実装
- [ ] [RED] scope更新時のキャッシュ無効化テスト
- [ ] [GREEN] キャッシュ無効化実装

- [ ] [RED] connections.luaのテスト作成（PF管理）
- [ ] [GREEN] connections.lua実装
- [ ] [RED] PF追加・削除・一覧のテスト
- [ ] [GREEN] PF操作実装
- [ ] [REFACTOR] State全体の整理

### フェーズ6: ドメイン層（Actions - 参照系）

- [ ] [RED] list.luaのテスト作成（リソース一覧取得）
- [ ] [GREEN] list.lua実装（KubectlPortを使用）
- [ ] [RED] フィルタリングのテスト作成
- [ ] [GREEN] フィルタリング実装
- [ ] [RED] ソート（NAME順）のテスト作成
- [ ] [GREEN] ソート実装

- [ ] [RED] describe.luaのテスト作成
- [ ] [GREEN] describe.lua実装
- [ ] [REFACTOR] 参照系アクションの共通処理抽出

### フェーズ7: ドメイン層（Actions - 変更系）

- [ ] [RED] delete.luaのテスト作成
- [ ] [GREEN] delete.lua実装

- [ ] [RED] scale.luaのテスト作成
- [ ] [GREEN] scale.lua実装

- [ ] [RED] restart.luaのテスト作成
- [ ] [GREEN] restart.lua実装
- [ ] [REFACTOR] 変更系アクションの共通処理抽出

### フェーズ8: ドメイン層（Actions - 接続系）

- [ ] [RED] exec.luaのテスト作成
- [ ] [GREEN] exec.lua実装（シェル自動判定含む）

- [ ] [RED] logs.luaのテスト作成
- [ ] [GREEN] logs.lua実装（-f, --timestamps, -p対応）

- [ ] [RED] port_forward.luaのテスト作成
- [ ] [GREEN] port_forward.lua実装
- [ ] [RED] PFライフサイクル（開始・停止・クリーンアップ）テスト
- [ ] [GREEN] ライフサイクル実装
- [ ] [REFACTOR] 接続系アクションの共通処理抽出

### フェーズ9: UI層（Components）

- [ ] [RED] layout.luaのテスト作成（3ウィンドウ構成）
- [ ] [GREEN] layout.lua実装（NuiPopup×3）

- [ ] [RED] table.luaのテスト作成（NuiLine/NuiText描画）
- [ ] [GREEN] table.lua実装

- [ ] [RED] header.luaのテスト作成
- [ ] [GREEN] header.lua実装（Context/NS/View表示、Loading...）

- [ ] [RED] menu.luaのテスト作成（telescope/NuiMenu切り替え）
- [ ] [GREEN] menu.lua実装

- [ ] [RED] input.luaのテスト作成（NuiInput）
- [ ] [GREEN] input.lua実装

- [ ] [RED] confirm.luaのテスト作成（vim.fn.confirm）
- [ ] [GREEN] confirm.lua実装
- [ ] [REFACTOR] コンポーネント間の整合性確認

### フェーズ10: UI層（Views）

- [ ] [RED] resource_list.luaのテスト作成
- [ ] [GREEN] resource_list.lua実装
- [ ] [RED] キーマップ（d, l, e, D, s, X, r, /, R, C, N, S, p, F, P, ?, q, Esc）テスト
- [ ] [GREEN] キーマップ実装
- [ ] [RED] 自動更新（5秒間隔）テスト
- [ ] [GREEN] 自動更新実装

- [ ] [RED] describe.luaのテスト作成
- [ ] [GREEN] describe.lua実装（filetype=yaml）

- [ ] [RED] port_forward_list.luaのテスト作成
- [ ] [GREEN] port_forward_list.lua実装

- [ ] [RED] help.luaのテスト作成
- [ ] [GREEN] help.lua実装（フッター拡張形式）
- [ ] [REFACTOR] View間の共通処理抽出

### フェーズ11: UI層（columns）

- [ ] [RED] columns.luaのテスト作成
- [ ] [GREEN] columns.lua実装（リソースタイプごとのカラム定義）
- [ ] [REFACTOR] カラム定義の最適化

### フェーズ12: API層（ファサード）

- [ ] [RED] api.luaのテスト作成（統一API）
- [ ] [GREEN] api.lua実装
- [ ] [REFACTOR] API設計の見直し

### フェーズ13: エントリポイント

- [ ] [RED] config.luaのテスト作成（設定マージ・検証）
- [ ] [GREEN] config.lua実装

- [ ] [RED] init.luaのテスト作成（setup, toggle, open, close）
- [ ] [GREEN] init.lua実装

- [ ] plugin/k8s.lua実装（遅延読み込み、コマンド定義）
- [ ] [REFACTOR] 起動時間の最適化

### フェーズ14: 統合・品質保証

- [ ] [STRUCTURAL] 全体コード整理（動作変更なし）
- [ ] 全テスト実行と確認
- [ ] lint/format/型チェックの確認
- [ ] ハイライトグループ定義（K8sStatus*）
- [ ] doc/k8s.txt（Vimヘルプ）作成

## 実装ノート

### MUSTルール遵守事項
- TDD: RED → GREEN → REFACTOR サイクルを厳守
- Tidy First: 構造変更と動作変更を分離
- コミット: 意味のある単位でこまめにコミット

### 依存関係の順序
```
infra/kubectl（依存なし）
    ↓
domain/ports（型定義のみ）
    ↓
domain/resources（portsに依存）
domain/state（依存なし）
    ↓
domain/actions（ports, resources, stateに依存）
    ↓
api.lua（domain全体に依存）
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
