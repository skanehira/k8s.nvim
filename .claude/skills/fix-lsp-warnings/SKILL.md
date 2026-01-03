---
name: fix-lsp-warnings
description: builtin LSPを使用してLua/Neovimプロジェクトの警告を検出し修正します。実装後の品質チェックとして使用します。型エラー、未定義変数、重複定義などの警告を自動修正します。
---

# LSP警告修正

Neovim builtin LSP（lua_ls）を使用してLuaコードの警告を検出し、修正するスキル。

## 使用タイミング

- 実装完了後の品質チェック
- リファクタリング後の警告確認
- PRレビュー前の最終チェック

## ワークフロー

### ステップ1: LSP警告の検出

以下のコマンドでプロジェクト全体の警告を取得：

```bash
nvim --headless \
  -c "lua require('lspconfig').lua_ls.setup{}" \
  -c "edit lua/k8s/init.lua" \
  -c "sleep 3" \
  -c "lua vim.diagnostic.setqflist({open = false}); for _, d in ipairs(vim.fn.getqflist()) do print(vim.fn.bufname(d.bufnr) .. ':' .. d.lnum .. ': ' .. d.text) end" \
  -c "qa" 2>&1 | grep -v "deprecated\|stack traceback\|lspconfig\|\[string"
```

### ステップ2: 警告の分類と修正

#### よくある警告と修正方法

**1. Undefined field（未定義フィールド）**
```lua
-- 警告: Undefined field `new_timer`
render_timer = vim.uv.new_timer()

-- 修正: diagnosticを無効化
---@diagnostic disable-next-line: undefined-field
render_timer = vim.uv.new_timer()
```

**2. Duplicate defined alias（重複エイリアス）**
```lua
-- 警告: Duplicate defined alias `ViewType`
-- ファイルA
---@alias ViewType "list"|"detail"

-- ファイルB
---@alias ViewType "pod_list"|"deployment_list"

-- 修正: 一方を別名に変更
---@alias WindowLayoutType "list"|"detail"  -- ファイルAを変更
```

**3. need-check-nil（nilチェック必要）**
```lua
-- 警告: need-check-nil
local conn = connections.get(123)
conn.job_id  -- warning

-- 修正: assert()で型を絞り込む
local conn = connections.get(123)
if conn then
  conn.job_id  -- OK
end
-- または
assert(conn)
conn.job_id  -- OK
```

**4. The same file is required with different names**
```lua
-- 警告: require パスの不一致
require("k8s.state.init")  -- NG
require("k8s.state")       -- OK (init.luaは自動解決される)
```

### ステップ3: 修正の確認

修正後、再度LSPチェックを実行して警告がなくなったことを確認：

```bash
nvim --headless \
  -c "lua require('lspconfig').lua_ls.setup{}" \
  -c "edit lua/k8s/init.lua" \
  -c "sleep 3" \
  -c "lua vim.diagnostic.setqflist({open = false}); for _, d in ipairs(vim.fn.getqflist()) do print(vim.fn.bufname(d.bufnr) .. ':' .. d.lnum .. ': ' .. d.text) end" \
  -c "qa" 2>&1 | grep -v "deprecated\|stack traceback\|lspconfig\|\[string"
```

### ステップ4: テスト実行

警告修正後、テストが通ることを確認：

```bash
make test
```

## 修正時の注意点

1. **@diagnostic disable は最小限に** - 本当に必要な場合のみ使用
2. **型エイリアスは1箇所で定義** - 重複を避ける
3. **nilチェックはassert()で型を絞り込む** - LSPに型を伝える
4. **requireパスは正規のパスを使用** - init.luaは省略可能

## 自動修正できない警告

以下は手動での判断が必要：

- **意図的な設計による警告** - 設計変更が必要
- **外部ライブラリの型定義不足** - @diagnosticで抑制
- **動的な型の使用** - 適切な型注釈の追加

---

**覚えておくこと: LSP警告は潜在的なバグの兆候。安易に@diagnosticで抑制せず、根本原因を修正すること。**
