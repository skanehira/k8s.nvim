# k8s.nvim アーキテクチャ v2（設計案）

## 設計思想

### State中心アーキテクチャ

Stateを中心に据え、UIはStateの表現（projection）として設計する。

```
┌─────────────────────────────────────────────────────────┐
│                       State                             │
│  ┌─────────────────┐    ┌─────────────────┐            │
│  │  Global State   │    │   View State    │            │
│  │  - context      │    │  - resources    │            │
│  │  - namespace    │    │  - filter       │            │
│  │  - current_kind │    │  - cursor       │            │
│  └─────────────────┘    └─────────────────┘            │
│                                                         │
│                    ┌──────────┐                         │
│                    │ Listener │ ← 単一                  │
│                    └──────────┘                         │
└─────────────────────────────────────────────────────────┘
        ▲                    │
        │                    ▼
   State更新            View.render()
        ▲                    │
        │                    ▼
┌───────┴───────┐    ┌──────────────┐
│  UI操作       │    │     UI       │
│  Watcher      │    │  (NuiPopup)  │
└───────────────┘    └──────────────┘
```

### 原則

1. **単方向データフロー**: State更新 → Listener通知 → UI描画
2. **関心の分離**: State更新側はUIを知らない、UI描画側はStateのみ参照
3. **Viewごとのrender**: 各ViewタイプがそれぞれのUI描画ロジックを持つ

## State構造

### Global State

プラグイン全体で共有される状態。

```lua
GlobalState = {
  -- Kubernetes接続情報
  current_context: string,      -- 現在のコンテキスト
  current_namespace: string,    -- 現在のnamespace（全viewで共有）

  -- プラグイン設定
  setup_done: boolean,
  config: Config,

  -- View管理
  view_stack: ViewState[],      -- Viewスタック（各ViewStateを含む）
  window: K8sWindow,            -- 現在のウィンドウ参照

  -- Observer
  listener: function,           -- State変更時に呼ばれる単一のlistener
}

-- Note: current_kindは廃止。ViewState.typeから取得可能
-- 例: "pod_list" → kind = "Pod"
-- ヘルパー関数: get_kind_from_view_type(type) で変換
```

### View State

各Viewが持つ固有の状態。view_stack内に格納。

```lua
-- View Type一覧
ViewType =
  -- List系
  | "pod_list"
  | "deployment_list"
  | "service_list"
  | "configmap_list"
  | "secret_list"
  | "node_list"
  | "namespace_list"
  | "port_forward_list"
  -- Describe系
  | "pod_describe"
  | "deployment_describe"
  | "service_describe"
  | "configmap_describe"
  | "secret_describe"
  | "node_describe"
  | "namespace_describe"
  -- その他
  | "help"

ViewState = {
  -- 共通フィールド
  type: ViewType,
  window: K8sWindow,

  -- ライフサイクルコールバック
  on_mounted: function(),       -- View表示時
  on_unmounted: function(),     -- View非表示時
  render: function(),           -- UI描画関数

  -- List View固有（*_list系）
  resources: Resource[],        -- リソース一覧
  filter: string | nil,         -- フィルター文字列
  cursor: number,               -- カーソル位置
  watcher_job_id: number | nil, -- Watcher job ID

  -- Describe View固有（*_describe系）
  resource: Resource,           -- 対象リソース
  describe_output: string,      -- キャッシュされた出力
  mask_secrets: boolean,        -- Secretマスク状態（secret_describeのみ）
}
```

## State更新

### 更新関数

用途別の更新関数を提供。

```lua
-- Global State更新
state.set_context(context)
state.set_namespace(namespace)

-- View State更新（コールバック形式）
state.update_view(function(view)
  return {
    ...view,
    filter = "nginx",
  }
end)

-- リソース操作（差分更新）
state.add_resource(resource)
state.update_resource(resource)
state.remove_resource(name, namespace)
state.clear_resources()
```

### 更新トリガー

State更新のトリガーは2種類：

```
1. UI操作
   ユーザー入力 → Handler → state.update_xxx()

2. Watcher（外部システム同期）
   kubectl watch → イベント受信 → state.add/update/remove_resource()
   ※ debounceはWatcher側で行う
```

## Observer Pattern

### 単一Listener

```lua
-- State Module
local listener = nil

function state.subscribe(fn)
  listener = fn
end

function state.notify()
  if listener then
    listener()
  end
end

-- 使用側
state.subscribe(function()
  local view = state.get_current_view()
  if view and view.render then
    view.render()
  end
end)
```

### 更新フロー

```
state.set_filter("nginx")
    │
    ├── View State更新
    │
    ├── state.notify()
    │       │
    │       ▼
    │   listener()
    │       │
    │       ▼
    │   current_view.render()
    │       │
    │       ▼
    │   UI更新（header, content, footer）
    │
    └── 完了
```

## View ライフサイクル

### ライフサイクルフロー

```
View作成・表示
    │
    ├── view_stack.push(new_view)
    │
    ├── prev_view.on_unmounted()
    │   └── Watcher停止（list viewの場合）
    │
    ├── new_view.on_mounted()
    │   └── Watcher開始（list viewの場合）
    │
    └── new_view.render()

Back操作
    │
    ├── current_view.on_unmounted()
    │
    ├── view_stack.pop()
    │
    ├── prev_view.on_mounted()
    │   └── Watcher再開（list viewの場合）
    │
    └── prev_view.render()
```

### on_mounted / on_unmounted

```lua
-- List Viewの場合
list_view = {
  type = "list",
  kind = "Pod",

  on_mounted = function()
    watcher.start(self.kind, global_state.namespace, {
      on_event = function(type, resource)
        if type == "ADDED" then
          state.add_resource(resource)
        elseif type == "MODIFIED" then
          state.update_resource(resource)
        elseif type == "DELETED" then
          state.remove_resource(resource.name, resource.namespace)
        end
      end,
    })
  end,

  on_unmounted = function()
    watcher.stop(self.watcher_job_id)
  end,

  render = function()
    -- header, table_header, content, footer を描画
  end,
}

-- Describe Viewの場合
describe_view = {
  type = "describe",

  on_mounted = function()
    -- Watcher不要
  end,

  on_unmounted = function()
    -- クリーンアップ不要
  end,

  render = function()
    -- describe内容を描画
  end,
}
```

## Watcher と State同期

### リアルタイム同期

```
kubectl watch (外部システム)
    │
    ▼
┌─────────────────────────────────────────┐
│  Watcher (debounce: 100ms)              │
│                                          │
│  on_stdout → parse JSON → on_event      │
└─────────────────────────────────────────┘
    │
    ▼
state.add_resource() / update_resource() / remove_resource()
    │
    ▼
state.notify() → listener → view.render()
```

### 注意点

- Watcherからのイベントはdebounceしてからstate更新
- namespace変更時は全スタックのresourcesをクリア
- アクティブviewのみwatcherが動作

## namespace変更の影響

```
namespace変更
    │
    ├── global_state.namespace = new_namespace
    │
    ├── 全view_stackのresourcesをクリア
    │   for view in view_stack:
    │     if view.type == "list":
    │       view.resources = []
    │
    ├── current_view.on_unmounted()  -- 古いwatcher停止
    │
    ├── current_view.on_mounted()    -- 新しいwatcher開始
    │
    └── state.notify() → render
```

## ディレクトリ構造（案）

```
lua/k8s/
├── init.lua                 # エントリーポイント
├── config.lua               # 設定
│
├── state/                   # State管理（新規）
│   ├── init.lua             # State API（subscribe/notify等）
│   ├── global.lua           # Global State管理
│   └── view.lua             # View State管理
│
├── views/                   # View定義（再構成）
│   ├── list.lua             # List View（state + render）
│   ├── describe.lua         # Describe View
│   ├── help.lua             # Help View
│   └── port_forward.lua     # Port Forward List View
│
├── handlers/                # イベントハンドラー
│   ├── keymap.lua           # キーマップ
│   ├── actions/             # アクション（サブディレクトリ化）
│   │   ├── describe.lua
│   │   ├── delete.lua
│   │   ├── scale.lua
│   │   └── ...
│   └── watcher.lua          # Watcher管理
│
├── adapters/                # 外部システム連携
│   └── kubectl/
│       ├── client.lua       # kubectl実行クライアント
│       ├── watch.lua        # kubectl watchストリーミング
│       └── parser.lua       # レスポンスパーサー
│
└── ui/                      # UI層（維持）
    ├── nui/
    │   ├── window.lua
    │   └── buffer.lua
    └── components/
        ├── table.lua
        └── ...
```

## 図解：完全なデータフロー

```
┌─────────────────────────────────────────────────────────────────┐
│                         User                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
       ┌─────────────┐                 ┌─────────────┐
       │  Keypress   │                 │   :K8s cmd  │
       └──────┬──────┘                 └──────┬──────┘
              │                               │
              ▼                               ▼
       ┌─────────────────────────────────────────────┐
       │               Handlers                       │
       │  (keymap.lua, actions/*.lua)                │
       └──────────────────┬──────────────────────────┘
                          │
                          ▼
       ┌─────────────────────────────────────────────┐
       │                 State                        │
       │  ┌─────────────┐    ┌─────────────┐         │
       │  │Global State │    │ View State  │         │
       │  └─────────────┘    └─────────────┘         │
       │                                              │
       │         state.notify() → listener           │
       └──────────────────┬──────────────────────────┘
                          │
                          ▼
       ┌─────────────────────────────────────────────┐
       │            current_view.render()             │
       │  (views/list.lua, views/describe.lua, ...)  │
       └──────────────────┬──────────────────────────┘
                          │
                          ▼
       ┌─────────────────────────────────────────────┐
       │                 UI Layer                     │
       │  (ui/nui/window.lua, ui/components/...)     │
       └─────────────────────────────────────────────┘
                          │
                          ▼
       ┌─────────────────────────────────────────────┐
       │              NuiPopup Windows               │
       └─────────────────────────────────────────────┘


       ┌─────────────────────────────────────────────┐
       │              kubectl watch                   │
       │        (外部システム - Kubernetes)           │
       └──────────────────┬──────────────────────────┘
                          │ (ストリーミング)
                          ▼
       ┌─────────────────────────────────────────────┐
       │    Watcher (handlers/watcher.lua)           │
       │    - debounce 100ms                          │
       │    - JSON parse                              │
       └──────────────────┬──────────────────────────┘
                          │
                          ▼
       ┌─────────────────────────────────────────────┐
       │   state.add/update/remove_resource()        │
       │              ↓                               │
       │        state.notify()                        │
       │              ↓                               │
       │      current_view.render()                   │
       └─────────────────────────────────────────────┘
```

## 移行方針

フルリライトで実装。既存コードは参照用に残す。

### 準備

```bash
# 既存コードをoldディレクトリに移動（参照用）
mkdir -p old
mv lua old/
mv plugin old/
```

### 実装順序（案）

1. **Phase 1: State基盤**
   - `state/init.lua` - State API（subscribe/notify）
   - `state/global.lua` - Global State管理
   - `state/view.lua` - View State管理
   - テスト作成

2. **Phase 2: UI基盤**
   - `ui/nui/window.lua` - ウィンドウ管理（old/から移植）
   - `ui/nui/buffer.lua` - バッファ操作（old/から移植）
   - `ui/components/` - コンポーネント（old/から移植）

3. **Phase 3: Adapters**
   - `adapters/kubectl/client.lua` - kubectl実行（old/から移植）
   - `adapters/kubectl/watch.lua` - watchストリーミング（old/から移植）
   - `adapters/kubectl/parser.lua` - パーサー（old/から移植）

4. **Phase 4: View定義**
   - `views/list.lua` - List View（render, on_mounted, on_unmounted）
   - `views/describe.lua` - Describe View
   - `views/help.lua` - Help View
   - `views/port_forward.lua` - Port Forward List View

5. **Phase 5: Handlers**
   - `handlers/keymap.lua` - キーマップ
   - `handlers/watcher.lua` - Watcher管理
   - `handlers/actions/` - 各アクション

6. **Phase 6: エントリーポイント**
   - `init.lua` - プラグインAPI
   - `plugin/k8s.lua` - Vimコマンド登録

7. **Phase 7: クリーンアップ**
   - old/ディレクトリ削除
   - ドキュメント更新
