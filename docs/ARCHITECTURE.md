# k8s.nvim アーキテクチャ

## 概要

k8s.nvimは、Neovim内でKubernetesリソースを管理するためのプラグインです。
レイヤードアーキテクチャ、イミュータブルな状態管理、リアルタイムストリーミング更新を特徴としています。

## ディレクトリ構造

```
lua/k8s/
├── init.lua                    # メインAPI・ライフサイクル管理
├── plugin.lua                  # コマンド補完
├── config.lua                  # 設定管理
│
├── core/                       # コア層（ビジネスロジック）
│   ├── global_state.lua        # グローバル状態管理（シングルトン）
│   ├── state.lua               # アプリケーション状態（イミュータブル）
│   ├── view_stack.lua          # ビュースタック管理
│   ├── connections.lua         # ポートフォワード接続管理
│   ├── watcher.lua             # kubectl watch プロセス管理
│   ├── resource.lua            # リソース仕様（能力定義）
│   ├── notify.lua              # 通知メッセージ生成
│   ├── health.lua              # 依存関係チェック
│   └── deps.lua                # テスト用依存性コンテナ
│
├── handlers/                   # ハンドラー層（イベント処理）
│   ├── dispatcher.lua          # アクションディスパッチャー
│   ├── keymap.lua              # キーマップ定義・検証
│   ├── renderer.lua            # レンダリング制御
│   ├── list_handler.lua        # リスト表示のアクション
│   ├── describe_handler.lua    # 詳細表示のアクション
│   ├── menu_handler.lua        # メニューハンドラー
│   ├── port_forward_handler.lua# ポートフォワード処理
│   ├── resource_actions.lua    # リソースアクション（delete等）
│   ├── pod_actions.lua         # Pod特化アクション（logs等）
│   ├── menu_actions.lua        # メニューアイテム定義
│   ├── view_helper.lua         # ビュー初期化ヘルパー
│   └── view_restorer.lua       # ビュー復帰処理（ポリモーフィック）
│
├── infra/                      # インフラ層（外部システム連携）
│   └── kubectl/
│       ├── adapter.lua         # kubectl ラッパー（非同期）
│       ├── watch_adapter.lua   # kubectl watch ストリーミング
│       └── parser.lua          # JSON パーサー・リソース変換
│
└── ui/                         # UI層
    ├── nui/
    │   ├── window.lua          # NuiPopup ウィンドウ管理
    │   └── buffer.lua          # バッファ描画ヘルパー
    ├── components/
    │   ├── header.lua          # ヘッダーコンポーネント
    │   ├── table.lua           # テーブルコンポーネント
    │   └── secret_mask.lua     # Secret マスキング
    └── views/
        ├── resource_list.lua   # リソース一覧ビュー
        ├── columns.lua         # カラム定義
        ├── help.lua            # ヘルプビュー
        └── port_forward_list.lua # PF一覧ビュー
```

## レイヤー構成

```
┌─────────────────────────────────────────────────────────┐
│                      init.lua                           │
│                   (エントリーポイント)                    │
└─────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│   handlers/   │ │    core/      │ │     ui/       │
│ (イベント処理) │ │ (ビジネス     │ │ (表示)        │
│               │ │  ロジック)    │ │               │
└───────────────┘ └───────────────┘ └───────────────┘
        │                 │                 │
        └─────────────────┼─────────────────┘
                          ▼
                  ┌───────────────┐
                  │    infra/     │
                  │ (外部システム) │
                  └───────────────┘
```

## 状態管理

### global_state.lua（シングルトン）

プラグイン全体のグローバル状態を管理：

```lua
state = {
  setup_done: boolean,          -- セットアップ完了フラグ
  config: table,                -- ユーザー設定
  window: K8sWindow,            -- 現在のウィンドウ
  app_state: table,             -- アプリケーション状態
  view_stack: table[],          -- ビュースタック
  pf_list_connections: table[]  -- ポートフォワード接続
}
```

### state.lua（イミュータブル）

アプリケーション状態をイミュータブルに管理：

```lua
app_state = {
  running: boolean,
  current_kind: string,         -- "Pod", "Deployment" 等
  current_namespace: string,    -- "default" or "All Namespaces"
  current_context: string|nil,
  resources: Resource[],        -- キャッシュされたリソース
  filter: string|nil,           -- フィルター文字列
  cursor: number,               -- カーソル位置
  mask_secrets: boolean         -- Secret マスク状態
}
```

**イミュータブル操作**:
- `set_kind(state, kind)` → 新しいstate返却
- `set_namespace(state, namespace)` → 新しいstate返却
- `add_resource(state, resource)` → upsert操作
- `update_resource(state, resource)` → 既存リソース更新
- `remove_resource(state, name, namespace)` → リソース削除

### view_stack.lua（ナビゲーション）

ビュー間のナビゲーションをスタックで管理：

```lua
view_stack = [
  {
    type: "list",           -- ビュータイプ
    kind: "Pod",            -- リソース種類
    window: K8sWindow,      -- ウィンドウ参照
    parent_cursor: number   -- 親ビューでのカーソル位置
  },
  {
    type: "describe",
    resource: Resource,
    window: K8sWindow,
    describe_output: string,
    parent_cursor: number
  }
]
```

## データフロー

### UIオープン〜リソース表示

```
:K8s pods
    │
    ▼
init.lua: M.open()
    ├── health.check_kubectl()           # kubectl確認
    ├── window.create_list_view()        # ウィンドウ作成
    ├── global_state.set_window()        # 状態保存
    ├── view_stack.push()                # スタックに追加
    └── watcher.start()                  # watchストリーミング開始
            │
            ▼
        kubectl get Pod --watch --output-watch-events -o json
            │
            ▼ (イベント受信)
        on_event(type, resource)
            │
            ▼
        state.add_resource() / update_resource() / remove_resource()
            │
            ▼
        debounced_render()               # 100msデバウンス
            │
            ▼
        resource_list_view.render()      # UI更新
```

### ユーザーアクション（describe例）

```
User: d キー押下
    │
    ▼
keymap handler
    │
    ▼
dispatcher.dispatch("describe")
    │
    ▼
describe_handler.handle_describe()
    ├── list_handler.get_current_resource()  # 選択中リソース取得
    ├── view_helper.create_view()            # 新ビュー作成
    │       ├── view_stack.push()            # スタックに追加
    │       └── window.hide(prev)            # 前ウィンドウ非表示
    └── adapter.describe()                   # kubectl describe
            │
            ▼ (非同期)
        window.set_lines()                   # 結果表示
```

### Back操作

```
User: <C-h> キー押下
    │
    ▼
list_handler.handle_back()
    ├── view_stack.pop()                     # スタックから削除
    ├── window.show(prev_view.window)        # 前ウィンドウ表示
    ├── view_restorer.restore()              # ビュー復帰
    │       └── (list) watcher.start()       # watcher再開
    └── window.unmount(current.window)       # 現ウィンドウ削除
```

## UIコンポーネント構造

### List View

```
┌─────────────────────────────────────────────┐
│ Context: xxx | Namespace: default | View: P │ ← header (1行)
├─────────────────────────────────────────────┤
│ NAME        STATUS    RESTARTS   AGE        │ ← table_header (1行)
├─────────────────────────────────────────────┤
│ nginx-xxx   Running   0          2d         │
│ redis-xxx   Pending   1          5m         │ ← content (動的)
│ ...                                         │
├─────────────────────────────────────────────┤
│ [d]escribe [l]ogs [D]elete [/]filter...    │ ← footer (1行)
└─────────────────────────────────────────────┘
```

### K8sWindow構造

```lua
K8sWindow = {
  header: NuiPopup,         -- ヘッダー
  table_header: NuiPopup,   -- テーブルヘッダー（listのみ）
  content: NuiPopup,        -- コンテンツ
  footer: NuiPopup,         -- フッター
  mounted: boolean,
  size: { width, height },
  view_type: "list" | "detail"
}
```

## Watcherシステム

### 概要

kubectl watchによるリアルタイム更新：

```
watcher.start(kind, namespace, callbacks)
    │
    ▼
watch_adapter.watch()
    │
    ▼
vim.fn.jobstart("kubectl get Pod --watch --output-watch-events -o json")
    │
    ├── on_stdout: JSONパース → callbacks.on_event(type, resource)
    ├── on_stderr: callbacks.on_error(msg)
    └── on_exit: callbacks.on_exit()
```

### イベントタイプ

- `ADDED`: リソース追加（初回の既存リソースもADDED）
- `MODIFIED`: リソース更新
- `DELETED`: リソース削除

### デバウンス処理

頻繁なイベントによるUI更新を100msでデバウンス：

```lua
local DEBOUNCE_MS = 100
local render_timer = nil

local function debounced_render()
  if render_timer then
    render_timer:stop()
  end
  render_timer = vim.uv.new_timer()
  render_timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    -- UI更新処理
  end))
end
```

## キーマップシステム

### 定義構造

```lua
-- keymap.lua
footer_keymaps = {
  list = {
    { key = "d", action = "describe" },
    { key = "D", action = "delete" },
    { key = "/", action = "filter" },
    -- ...
  },
  describe = {
    { key = "<C-h>", action = "back" },
    { key = "S", action = "toggle_secret" },
    -- ...
  }
}

view_allowed_actions = {
  list = { describe = true, delete = true, ... },
  describe = { back = true, toggle_secret = true, ... }
}
```

### リソース能力フィルタリング

```lua
-- resource.lua
capabilities_map = {
  Pod = { exec = true, logs = true, scale = false, ... },
  Deployment = { exec = false, logs = false, scale = true, ... },
  -- ...
}
```

キーマップ設定時にリソース能力でフィルタリング：
- Podでは `logs` キー表示
- Deploymentでは `scale` キー表示

## ビュースタック遷移例

```
:K8s pods
    │
    └─ stack = [{ type="list", kind="Pod" }]

d (describe)
    │
    └─ stack = [
         { type="list", kind="Pod" },
         { type="describe", resource=pod1 }
       ]

R → Deployments選択
    │
    └─ stack = [
         { type="list", kind="Pod" },
         { type="describe", resource=pod1 },
         { type="list", kind="Deployment" }
       ]

<C-h> (back)
    │
    └─ stack = [
         { type="list", kind="Pod" },
         { type="describe", resource=pod1 }
       ]

<C-h> (back)
    │
    └─ stack = [{ type="list", kind="Pod" }]
```

## 設計パターン

| パターン | 実装箇所 | 目的 |
|---------|---------|------|
| Immutable State | state.lua | 予測可能な状態変化 |
| Event-Driven | watcher + callbacks | リアルタイム更新 |
| Lazy Loading | dispatcher.lua | 起動速度向上 |
| View Stack | view_stack.lua | ナビゲーション管理 |
| Polymorphism | view_restorer.lua | ビュー型別処理 |
| Dependency Injection | deps.lua | テスト容易性 |
| Callback Injection | dispatcher callbacks | 循環参照回避 |
| Debouncing | init.lua | 頻繁な更新の抑制 |

## 外部依存

### Neovim API

- `vim.system()` - 非同期コマンド実行
- `vim.fn.jobstart()` - ジョブ管理
- `vim.ui.input()` / `vim.ui.select()` - ユーザー入力
- `vim.notify()` - 通知
- `vim.json.decode()` / `vim.json.encode()` - JSON処理
- `vim.base64.decode()` - Base64デコード

### 外部プラグイン

- **nui.nvim** - UIコンポーネント（NuiPopup）

## テストアーキテクチャ

### コロケーション

テストファイルは対象ファイルと同じディレクトリに配置：

```
lua/k8s/core/
├── state.lua
├── state_spec.lua      ← 同じディレクトリ
├── global_state.lua
└── global_state_spec.lua
```

### モック支援

```lua
-- deps.lua
M.with_mocks({
  global_state = mock_global_state,
  adapter = mock_adapter,
}, function()
  -- テストコード
end)
```

## 課題・改善点

### 現在の課題

1. **Watcherライフサイクル**: list → describe移動時にwatcherが停止しない
2. **on_unmountedの欠如**: ビュー遷移時のクリーンアップフェーズがない

### 改善計画

- `on_mounted` / `on_unmounted` コールバックをview_stack entryに追加
- ビュー遷移時に適切にwatcher停止/開始を行う
