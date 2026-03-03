# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

k8s.nvim は Neovim 用の Kubernetes リソース管理プラグイン。NuiPopup ベースの UI で Pod, Deployment, Service などのリソースを一覧・詳細表示し、各種操作（logs, exec, port-forward, scale, restart, delete）を提供する。

## Requirements

- Neovim >= 0.10.0
- kubectl（クラスタアクセス設定済み）
- nui.nvim

## コマンド

```vim
:K8s              " ウィンドウのトグル
:K8s pods         " Pod ビューで開く
:K8s deployments  " Deployment ビューで開く
```

## ビルド・テストコマンド

```bash
make test          # 全テスト実行
make lint          # luacheck によるリント
make format        # stylua によるフォーマット

# 単一テスト実行
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile lua/k8s/path/to/file_spec.lua"
```

## アーキテクチャ

### 主要コンポーネント

- `init.lua`: エントリポイント、UI lifecycle
- `config.lua`: 設定管理、リソース種別ごとのキーマップ定義
- `state/`: 状態管理（global.lua: context/namespace/window、view.lua: View状態）
- `views/`: View層（list, describe, help, port_forward）
- `handlers/`: ビジネスロジック（render, lifecycle, actions, watcher, connections）
- `adapters/kubectl/`: kubectl コマンド実行、watch、JSONパース
- `ui/nui/`: NuiPopup ラッパー（window, buffer操作）

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

### Window 構成

各 Window は 3 つのセクション（NuiPopup）で構成：

```
┌─────────────────────────────────┐
│ Header (context/namespace/view) │
├─────────────────────────────────┤
│ Table Header (カラムヘッダー)    │  ← list view のみ
├─────────────────────────────────┤
│ Content (リソース一覧/詳細)      │
└─────────────────────────────────┘
```

キーマップはヘルプビュー（`?`キー）で確認できる。

## 描画システム

すべての描画は `handlers/render.lua` を通じて行われる：

```lua
-- Watcher更新時（デバウンス付き、100ms）
render.render({ mode = "debounced" })

-- View遷移時（即時）
render.render()
```

### 描画フロー

```
状態変更 → state.notify() → render.render({ mode = "debounced" }) → view.render()
```

1. watcher がリソース変更を検知
2. `state.add_resource()` / `state.update_resource()` で状態更新
3. `state.notify()` でリスナーに通知
4. デバウンスされた render が 100ms 後に実行
5. 現在の View の `render()` が呼ばれ、バッファに描画

### View遷移時の描画

View遷移（push/pop）時は即時描画：

```lua
-- state を更新してから render.render() を呼ぶ
state.push_view(new_view)
render.render()  -- 即時描画
```

### pop 時の render 順序

戻る操作では、show する前に render する必要がある：

```lua
-- OK: render してから show
render.render()
window.show(prev_win)

-- NG: 古いコンテンツが見える
window.show(prev_win)
render.render()
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

## テスト

テストファイルは対象ファイルと同じディレクトリに `_spec.lua` サフィックスで配置（コロケーション）。
詳細なテストルールは `.claude/rules/testing.md` を参照。

## 実装ルール

キーマップ設計、State管理、Terminal操作の詳細は `.claude/rules/implementation.md` を参照。
