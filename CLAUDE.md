# CLAUDE.md

このファイルは Claude Code がこのリポジトリを扱う際のガイダンスを提供する。

## プロジェクト概要

k8s.nvim は Neovim 用の Kubernetes リソース管理プラグイン。NuiPopup ベースの UI で Pod, Deployment, Service などのリソースを一覧・詳細表示し、各種操作（logs, exec, port-forward, scale, restart, delete）を提供する。

## ビルド・テストコマンド

```bash
make test          # 全テスト実行
make lint          # luacheck によるリント
make format        # stylua によるフォーマット
```

## アーキテクチャ

### ディレクトリ構成

```
lua/k8s/
├── init.lua                 # エントリポイント、UI lifecycle、アクション実行
├── config.lua               # 設定管理
├── state/                   # 状態管理
│   ├── init.lua             # State facade
│   ├── global.lua           # グローバル状態（context, namespace, window）
│   └── view.lua             # View 状態定義と操作
├── views/                   # View 層（render, lifecycle）
│   ├── list.lua             # リスト表示
│   ├── describe.lua         # 詳細表示
│   ├── help.lua             # ヘルプ表示
│   ├── port_forward.lua     # ポートフォワード一覧
│   ├── keymaps.lua          # キーマップ定義
│   └── columns.lua          # カラム定義
├── handlers/                # ビジネスロジック
│   ├── actions.lua          # アクション定義
│   ├── resource.lua         # リソース capabilities
│   ├── watcher.lua          # kubectl watch 管理
│   ├── connections.lua      # port-forward 接続管理
│   └── notify.lua           # 通知
├── adapters/kubectl/        # kubectl アダプター
│   ├── adapter.lua          # kubectl コマンド実行
│   ├── watch_adapter.lua    # kubectl watch
│   └── parser.lua           # JSON パース
└── ui/                      # UI コンポーネント
    ├── nui/                  # NuiPopup ラッパー
    │   ├── window.lua        # ウィンドウ操作
    │   └── buffer.lua        # バッファ操作
    └── components/           # UI パーツ
```

### View Stack アーキテクチャ

画面遷移は View Stack で管理される：

```
[pod_list] → [pod_describe] → [help]
    ↑             ↑              ↑
  push          push           push
    ↓             ↓              ↓
   pop           pop            pop
```

各 View は以下の lifecycle callback を持つ：
- `on_mounted`: View が表示されたとき（watcher 開始など）
- `on_unmounted`: View が非表示になったとき（watcher 停止など）
- `render`: 状態変更時の描画

## 描画システム

### 描画フロー

```
状態変更 → state.notify() → debounced render (100ms) → view.render()
```

1. watcher がリソース変更を検知
2. `state.add_resource()` / `state.update_resource()` で状態更新
3. `state.notify()` でリスナーに通知
4. デバウンスされた `_render()` が 100ms 後に実行
5. 現在の View の `render()` が呼ばれ、バッファに描画

### 画面遷移時の描画

画面遷移（push/pop）時は特別な処理が必要：

```lua
-- 1. 中間描画を抑制
local lazyredraw_was = vim.o.lazyredraw
vim.o.lazyredraw = true

-- 2. window 操作
window.mount(new_win)

-- 3. lifecycle 処理
M._push_view_with_lifecycle(view_state)

-- 4. 即時 render（デバウンスをバイパス）
if view_state.render then
  view_state.render(view_state, new_win)
end

-- 5. 一度だけ redraw
vim.o.lazyredraw = lazyredraw_was
vim.cmd("redraw")
```

**理由**: window mount 後、デバウンスされた render が実行されるまでの間に空のバッファが見えてしまう（チラツキ）。`lazyredraw` で中間描画を抑制し、即時 render してから一度だけ `redraw` することで解決。

### pop 時の render 順序

戻る操作では、show する前に render する必要がある：

```lua
-- OK: render してから show
if prev_view.render then
  prev_view.render(prev_view, prev_win)
end
window.show(prev_win)

-- NG: 古いコンテンツが見える
window.show(prev_win)
prev_view.render(prev_view, prev_win)
```

### Window 構成

各 Window は 4 つのセクション（NuiPopup）で構成：

```
┌─────────────────────────────────┐
│ Header (context/namespace/view) │
├─────────────────────────────────┤
│ Table Header (カラムヘッダー)    │  ← list view のみ
├─────────────────────────────────┤
│ Content (リソース一覧/詳細)      │
├─────────────────────────────────┤
│ Footer (キーマップヒント)        │
└─────────────────────────────────┘
```

## 状態管理

### グローバル状態

```lua
{
  context = "minikube",           -- 現在の kubectl context
  namespace = "default",          -- 現在の namespace
  window = NuiPopup,              -- メインウィンドウ参照
  view_stack = { ViewState, ... }, -- View スタック
  config = { ... },               -- 設定
  setup_done = true,              -- setup 完了フラグ
}
```

### View 状態

```lua
-- List View
{
  type = "pod_list",
  window = NuiPopup,
  resources = { ... },
  filter = nil,
  cursor = 1,
  watcher_job_id = 123,
  on_mounted = function,
  on_unmounted = function,
  render = function,
}

-- Describe View
{
  type = "pod_describe",
  window = NuiPopup,
  resource = { ... },
  describe_output = "...",
  mask_secrets = true,  -- secret_describe のみ
  on_mounted = function,
  on_unmounted = function,
  render = function,
}
```

### 状態更新の注意点

1. **vim.deepcopy を window に使わない**: NuiPopup の内部参照が壊れる
2. **closure で状態をキャプチャしない**: 状態変更が反映されない
3. **状態更新後は notify() を呼ぶ**: リスナーに変更を通知

## キーマップ設計

キーマップはリソース種別の capabilities に基づいて動的に設定される：

```lua
-- resource.lua
capabilities_map = {
  Pod = { logs = true, exec = true, scale = false, restart = false, ... },
  Deployment = { logs = false, exec = false, scale = true, restart = true, ... },
}
```

**重要**: 使えないアクションは実行時チェックではなく、**キーマップ自体を設定しない**ことで制御する。

## テスト

テストファイルは対象ファイルと同じディレクトリに `_spec.lua` サフィックスで配置（コロケーション）：

```
lua/k8s/views/
├── list.lua
├── list_spec.lua
├── columns.lua
└── columns_spec.lua
```

### luassert 構文

```lua
-- OK
assert.is.Not.Nil(value)
assert.is_nil(value)
assert.is_true(value)
assert.equals(expected, actual)

-- NG（スネークケースは使えない）
assert.is_not_nil(value)
```

### nil チェック後のフィールドアクセス

```lua
-- OK: assert() で型を絞り込む
local conn = connections.get(123)
assert(conn)
assert.equals(123, conn.job_id)

-- NG: LSP が warning を出す
local conn = connections.get(123)
assert.is.Not.Nil(conn)
assert.equals(123, conn.job_id)  -- need-check-nil warning
```
