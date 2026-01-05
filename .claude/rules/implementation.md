# 実装ルール

## キーマップとアクションの設計原則

### リソース種別ごとのアクション制御

各リソース種別（Pod, Deployment, Service など）で利用可能なアクションは `lua/k8s/config.lua` のキーマップ定義で決定される。

**重要**: アクション実行時のcapabilityチェックではなく、**キーマップ自体を設定しない**ことで制御する。

#### 正しいアプローチ
- 各viewのキーマップ設定時に、そのリソース種別で利用可能なアクションのみをマップする
- ヘルプ画面には利用可能なアクションのみを表示する

#### 間違ったアプローチ
- すべてのキーマップを設定しておき、実行時にcapabilityをチェックする
- これはユーザーに誤解を与える（使えないキーが表示される）

### 実装箇所

1. **キーマップ定義**: `lua/k8s/config.lua`
   - `default_keymaps` でリソース種別ごとのキーマップを定義
   - `merge_keymaps()` で共通キーマップとリソース固有キーマップを結合

2. **キーマップ取得**: `lua/k8s/views/keymaps.lua`
   - `get_keymaps(view_type)` でリソース種別に応じたキーマップを返す

3. **ヘルプ表示**: `lua/k8s/views/help.lua`
   - `create_content(view_type)` でヘルプ内容を生成

### キーマップ定義の例

```lua
-- config.lua
pod_list = merge_keymaps(list_common, {
  delete = actions.delete,
  logs = actions.logs,
  exec = actions.exec,
  port_forward = actions.port_forward,
  debug = actions.debug,
}),
deployment_list = merge_keymaps(list_common, {
  delete = actions.delete,
  scale = actions.scale,
  restart = actions.restart,
  port_forward = actions.port_forward,
}),
```

### 例: Pod リストビューのキーマップ

Pod リストでは:
- `l` (logs) → 表示する（Pod は logs 可能）
- `e` (exec) → 表示する（Pod は exec 可能）
- `s` (scale) → **表示しない**（Pod は scale 不可）
- `X` (restart) → **表示しない**（Pod は restart 不可）

Deployment リストでは:
- `l` (logs) → **表示しない**（Deployment は直接 logs 不可）
- `e` (exec) → **表示しない**（Deployment は直接 exec 不可）
- `s` (scale) → 表示する（Deployment は scale 可能）
- `X` (restart) → 表示する（Deployment は restart 可能）

## State管理とオブジェクト参照

### vim.deepcopy と window オブジェクト

**問題**: `vim.deepcopy()` は NuiPopup などの window オブジェクトの内部参照を壊す。

```lua
-- NG: window オブジェクトが新しいインスタンスになり、元のNeovim windowとの紐付けが切れる
function M.get()
  return vim.deepcopy(state)  -- state.window が壊れる
end

-- OK: shallow copy で window 参照を保持
function M.get()
  local copy = {}
  for k, v in pairs(state) do
    copy[k] = v
  end
  return copy
end
```

**影響**: view stack のナビゲーション時に間違った画面が表示される等の問題が発生する。

### Closure での状態キャプチャ

**問題**: closure で namespace などの状態値をキャプチャすると、状態変更が反映されない。

```lua
-- NG: closure 作成時の namespace がずっと使われる
local ns = state.namespace
local function fetch_resources()
  kubectl.get(kind, ns)  -- ns は古い値のまま
end

-- OK: 実行時に状態から取得
local function fetch_resources()
  local current_ns = global.get().namespace
  kubectl.get(kind, current_ns)
end
```

## Terminal操作

### jobstart の buffer 要件

`vim.fn.jobstart(..., {term=true})` は**未変更バッファ**が必要。

```lua
-- NG: 現在のバッファが変更済みだとエラー
-- E5108: Vim:jobstart(...,{term=true}) requires unmodified buffer
vim.fn.jobstart(cmd, { term = true })

-- OK: 新しいタブを開いてからターミナルを起動
vim.cmd("tabnew")
vim.fn.jobstart(cmd, { term = true })
```

## View表示

### 隠れた window を再表示する際の render 順序

**問題**: `NuiPopup:show()` だけでは古いコンテンツが一瞬表示される。

```lua
-- NG: 古いコンテンツが見える
window:show()
render_content()

-- OK: render してから show
render_content()
window:show()
```
