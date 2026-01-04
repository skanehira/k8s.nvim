---
name: add-resource
description: 新しいKubernetesリソースをk8s.nvimに追加します。registry.luaにリソース定義を追加するだけで完了します。
tools: Read, Grep, Glob, Edit, Write, Bash, AskUserQuestion
---

# リソース追加サブエージェント

新しい Kubernetes リソースを k8s.nvim に追加する。

## 概要

リソース追加は **`lua/k8s/resources/registry.lua`** に定義を追加するだけで完了する。
他のファイルは registry を参照するため、自動的に対応される。

## 使用タイミング

- 新しい Kubernetes リソース（CRD 含む）のサポートを追加するとき
- 例: NetworkPolicy, PersistentVolume, HorizontalPodAutoscaler など

## ワークフロー

### ステップ1: リソース情報の収集

ユーザーに以下を確認（AskUserQuestion を使用）:

1. **リソース名**: `kubectl get` で使用する名前（例: `networkpolicies`, `persistentvolumes`）
2. **Kind 名**: PascalCase の正式名（例: `NetworkPolicy`, `PersistentVolume`）

### ステップ2: kubectl 出力の確認

実際の出力を確認して構造を把握:

```bash
# リソース一覧の取得
kubectl get <resource> -A -o json 2>/dev/null | head -100

# 特定のリソースの詳細（あれば）
kubectl get <resource> -A -o json 2>/dev/null | jq '.items[0]' | head -100
```

CRD の場合は API グループを確認:

```bash
kubectl api-resources | grep -i <resource>
```

### ステップ3: ユーザーに設定を確認

AskUserQuestion で以下を確認:

**1. 表示カラム**（kubectl 出力から提案）:
- name, namespace は基本
- status 系フィールド（phase, conditions など）
- リソース固有のフィールド

**2. capabilities**（どのアクションを許可するか）:
- `exec`: コンテナ実行（通常 Pod のみ）
- `logs`: ログ表示（Pod, Job のみ）
- `scale`: レプリカ数変更
- `restart`: 再起動（rollout restart）
- `port_forward`: ポートフォワード
- `delete`: 削除
- `filter`: フィルタリング（通常 true）
- `refresh`: 自動更新（通常 true）

### ステップ4: 実装

#### 更新するファイル（1ファイルのみ）

**`lua/k8s/resources/registry.lua`**

既存のリソース定義を参考に、`M.resources` テーブルに新しいリソースを追加:

```lua
NewResource = {
  kind = "NewResource",
  plural = "newresources",
  display_name = "New Resources",
  capabilities = {
    exec = false,
    logs = false,
    scale = false,
    restart = false,
    port_forward = false,
    delete = true,
    filter = true,
    refresh = true,
  },
  columns = {
    { key = "name", header = "NAME" },
    { key = "namespace", header = "NAMESPACE" },
    { key = "status", header = "STATUS" },
    { key = "age", header = "AGE" },
  },
  status_column_key = "status",
  extract_status = function(item)
    return item.status and item.status.phase or "Unknown"
  end,
  extract_row = function(resource)
    local raw = resource.raw or {}
    return {
      name = resource.name,
      namespace = resource.namespace,
      status = resource.status,
      age = resource.age,
    }
  end,
},
```

#### 必要に応じて追加するファイル

複雑なデータ抽出ロジックが必要な場合のみ:

**`lua/k8s/resources/extractors.lua`**

ヘルパー関数を追加（複数リソースで共有できる場合）:

```lua
function M.extract_new_resource_field(raw)
  -- 抽出ロジック
end
```

#### ステータスハイライトの追加（必要な場合のみ）

リソース固有のステータス値がある場合:

**`lua/k8s/ui/components/table.lua`**

```lua
local status_highlights = {
  -- 既存のステータス...
  CustomStatus = "K8sStatusRunning",  -- 必要な場合のみ
}
```

### ステップ5: LSP 警告の修正

`.claude/agents/fix-lsp-warnings.md` の手順に従って LSP 警告を修正:

```bash
nvim --headless \
  -c "lua require('lspconfig').lua_ls.setup{}" \
  -c "lua local dirs = {'lua', 'plugin', 'tests'}; for _, dir in ipairs(dirs) do for _, f in ipairs(vim.fn.glob(dir .. '/**/*.lua', false, true)) do vim.fn.bufadd(f); vim.fn.bufload(vim.fn.bufnr(f)) end end" \
  -c "sleep 5" \
  -c "lua vim.diagnostic.setqflist({open = false}); for _, d in ipairs(vim.fn.getqflist()) do print(vim.fn.bufname(d.bufnr) .. ':' .. d.lnum .. ': ' .. d.text) end" \
  -c "qa" 2>&1 | grep -v "deprecated\|stack traceback\|lspconfig\|\[string"
```

警告があれば修正する。`@diagnostic disable` は原則禁止。

### ステップ6: テスト実行

registry テストを実行して、新しいリソース定義が正しいことを確認:

```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile lua/k8s/resources/registry_spec.lua" 2>&1
```

テストが失敗した場合は、以下を確認:
- 必須フィールド（kind, plural, display_name, capabilities, columns, status_column_key, extract_row）が全てあるか
- capabilities に全項目（exec, logs, scale, restart, port_forward, delete, filter, refresh）があるか
- columns の各項目に key と header があるか

### ステップ7: 動作確認

以下を実際に確認:

1. `:K8s <plural>` でリソース一覧が表示されるか
2. `R` キーでリソースメニューに表示されるか
3. カラムが正しく表示されるか
4. ステータスハイライトが正しく適用されるか
5. capabilities で許可したアクションのみキーマップに表示されるか
6. `<CR>` で describe が正しく動作するか

## CRD 対応時の注意

### API グループの指定

CRD の場合、`kubectl get` に API グループが必要な場合がある:

```bash
# 例: ArgoCD Application
kubectl get applications.argoproj.io -A -o json
```

### namespace スコープ

cluster-scoped リソースの場合:
- namespace カラムは表示しても空になる（問題なし）
- `-A` フラグなしで取得

## チェックリスト

- [ ] `registry.lua` の `M.resources` にリソース定義を追加
  - [ ] kind
  - [ ] plural
  - [ ] display_name
  - [ ] capabilities（全8項目）
  - [ ] columns
  - [ ] status_column_key
  - [ ] extract_status（オプション）
  - [ ] extract_row
- [ ] LSP 警告なし
- [ ] registry テストが通る
- [ ] 動作確認完了

## 既存リソース定義の参照

実装時は既存のリソース定義を参考にする:

```bash
# Pod の定義を確認
grep -A 40 "^  Pod = {" lua/k8s/resources/registry.lua

# Deployment の定義を確認
grep -A 40 "^  Deployment = {" lua/k8s/resources/registry.lua
```

---

**重要: リソース追加は registry.lua への追加のみで完了する。他のファイルは自動的に registry を参照する。**
