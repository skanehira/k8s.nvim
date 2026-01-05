---
name: add-resource
description: 新しいKubernetesリソースをk8s.nvimに追加します。registry.luaにリソース定義を追加し、config.luaにキーマップを追加します。
tools: Read, Grep, Glob, Edit, Write, Bash, AskUserQuestion
---

# リソース追加サブエージェント

新しい Kubernetes リソースを k8s.nvim に追加する。

## 概要

リソース追加には以下のファイルを更新する:
1. **`lua/k8s/resources/registry.lua`** - リソース定義（カラム、抽出ロジック）
2. **`lua/k8s/config.lua`** - キーマップ定義（利用可能なアクション）

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

**2. 利用可能なアクション**（どのキーマップを設定するか）:
- `exec`: コンテナ実行（通常 Pod のみ）
- `logs`: ログ表示（Pod, Job のみ）
- `scale`: レプリカ数変更
- `restart`: 再起動（rollout restart）
- `port_forward`: ポートフォワード
- `delete`: 削除
- `debug`: デバッグコンテナ起動（Pod のみ）

### ステップ4: 実装

#### 4.1 registry.lua にリソース定義を追加

**`lua/k8s/resources/registry.lua`**

既存のリソース定義を参考に、`M.resources` テーブルに新しいリソースを追加:

```lua
NewResource = {
  kind = "NewResource",
  plural = "newresources",
  display_name = "New Resources",
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

#### 4.2 config.lua にキーマップを追加

**`lua/k8s/config.lua`**

`default_keymaps` テーブルに新しいリソースのキーマップを追加:

```lua
-- 新しいリソースのリストビュー
newresource_list = merge_keymaps(list_common, {
  delete = actions.delete,
  -- 必要に応じて他のアクションを追加
  -- port_forward = actions.port_forward,
}),
```

**アクションの選択**:
- `list_common` は全リストビューで共通のキーマップ（select, describe, filter, refresh など）
- `actions` から利用可能なアクションを選択して追加
- 利用できないアクションは追加しない（キーマップに表示されなくなる）

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
- 必須フィールド（kind, plural, display_name, columns, status_column_key, extract_row）が全てあるか
- columns の各項目に key と header があるか

### ステップ7: 動作確認

以下を実際に確認:

1. `:K8s <plural>` でリソース一覧が表示されるか
2. `<C-r>` キーでリソースメニューに表示されるか
3. カラムが正しく表示されるか
4. ステータスハイライトが正しく適用されるか
5. `?` でヘルプを表示し、設定したアクションのみ表示されるか
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
  - [ ] columns
  - [ ] status_column_key
  - [ ] extract_status（オプション）
  - [ ] extract_row
- [ ] `config.lua` の `default_keymaps` にキーマップを追加
  - [ ] `<kind>_list` キーで定義
  - [ ] `merge_keymaps(list_common, { ... })` を使用
  - [ ] 必要なアクションのみ追加
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

# Pod のキーマップ定義を確認
grep -A 10 "pod_list = " lua/k8s/config.lua

# Deployment のキーマップ定義を確認
grep -A 10 "deployment_list = " lua/k8s/config.lua
```

---

**重要: リソース追加には registry.lua と config.lua の2ファイルを更新する。registry.lua でリソース定義を追加し、config.lua でキーマップを追加することで、利用可能なアクションが決まる。**
