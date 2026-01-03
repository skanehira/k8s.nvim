---
name: add-resource
description: 新しいKubernetesリソースをk8s.nvimに追加します。情報収集、kubectl出力確認、コミット28a1ecfの差分を参照して実装を行います。
tools: Read, Grep, Glob, Edit, Write, Bash, AskUserQuestion
---

# リソース追加サブエージェント

新しい Kubernetes リソースを k8s.nvim に追加する。

## 使用タイミング

- 新しい Kubernetes リソース（CRD 含む）のサポートを追加するとき
- 例: Ingress, StatefulSet, DaemonSet, CronJob, ArgoCD Application など

## ワークフロー

### ステップ1: リソース情報の収集

ユーザーに以下を確認（AskUserQuestion を使用）:

1. **リソース名**: `kubectl get` で使用する名前（例: `ingresses`, `statefulsets`）
2. **Kind 名**: PascalCase の正式名（例: `Ingress`, `StatefulSet`）

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
- `logs`: ログ表示（通常 Pod のみ）
- `scale`: レプリカ数変更
- `restart`: 再起動（rollout restart）
- `port_forward`: ポートフォワード
- `delete`: 削除
- `filter`: フィルタリング（通常 true）
- `refresh`: 自動更新（通常 true）

**3. ステータスハイライト**（リソース固有のステータス値があるか）:
- 緑（正常）: Running, Active, Ready など
- 黄（待機）: Pending, Waiting など
- 赤（エラー）: Failed, Error など

### ステップ4: 実装

コミット 28a1ecf を参照して、以下のファイルを更新:

```bash
git show 28a1ecf
```

#### 更新が必要なファイル（10ファイル）

**1. `lua/k8s/handlers/resource.lua`**
- `K8sResourceKind` 型に追加
- `capabilities_map` にエントリ追加

```lua
---@alias K8sResourceKind "Pod"|...|"NewResource"

NewResource = {
  exec = false,
  logs = false,
  scale = false,
  restart = false,
  port_forward = false,
  delete = true,
  filter = true,
  refresh = true,
},
```

**2. `lua/k8s/views/columns.lua`**
- `column_definitions` にカラム定義追加
- `extract_row()` に行データ抽出ロジック追加
- `status_column_keys` にステータスカラム追加

```lua
NewResource = {
  { key = "name", header = "NAME" },
  { key = "namespace", header = "NAMESPACE" },
  { key = "status", header = "STATUS" },
  { key = "age", header = "AGE" },
},
```

**3. `lua/k8s/adapters/kubectl/parser.lua`**
- `get_status()` にステータス取得ロジック追加

```lua
elseif kind == "NewResource" then
  return item.status and item.status.phase or "Unknown"
```

**4. `lua/k8s/ui/components/table.lua`**
- `status_highlights` にリソース固有のステータス追加（必要な場合のみ）

```lua
local status_highlights = {
  -- 既存のステータス...
  CustomStatus = "K8sStatusRunning",  -- 必要な場合のみ
}
```

**5. `lua/k8s/state/view.lua`**
- `ViewType` エイリアスに追加
- `type_to_kind` マッピングに追加
- `list_types` に追加
- `describe_types` に追加

```lua
---@alias ViewType
---| "newresource_list"
---| "newresource_describe"

local type_to_kind = {
  newresource_list = "NewResource",
  newresource_describe = "NewResource",
}

local list_types = {
  newresource_list = true,
}

local describe_types = {
  newresource_describe = true,
}
```

**6. `lua/k8s/views/keymaps.lua`**
- `get_kind_from_view_type()` の `kind_map` に追加

```lua
local kind_map = {
  newresource = "NewResource",
}
```

**7. `lua/k8s/handlers/actions.lua`**
- `resource_types` に追加（リソースメニュー用）

```lua
local resource_types = {
  { text = "NewResources", value = "NewResource" },
}
```

**8. `lua/k8s/init.lua`**
- `command_to_kind` マッピングに追加

```lua
local command_to_kind = {
  newresources = "NewResource",
}
```

**9. `plugin/k8s.lua`**
- `subcommands` に追加（コマンド補完用）

```lua
local subcommands = {
  "newresources",
}
```

**10. `doc/k8s.txt`**
- `default_kind` の available values に追加

```
Available values: "Pod", ..., "NewResource".
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

警告があれば修正する。`@diagnostic disable` は原則禁止（詳細は fix-lsp-warnings.md を参照）。

### ステップ6: セルフレビュー

実装完了後、以下の観点でセルフレビューを行い、問題がなくなるまで修正を繰り返す:

#### 6.1 チェックリストの確認

下記チェックリストの全項目が完了しているか確認。漏れがあれば実装に戻る。

#### 6.2 コードの一貫性確認

既存リソースの実装と比較して、パターンが一致しているか確認:

```bash
# 既存の Pod 実装と新リソースの実装を比較
grep -n "Pod" lua/k8s/handlers/resource.lua lua/k8s/views/columns.lua lua/k8s/state/view.lua
grep -n "<NewResource>" lua/k8s/handlers/resource.lua lua/k8s/views/columns.lua lua/k8s/state/view.lua
```

確認ポイント:
- 命名規則の一貫性（lowercase_list, PascalCase Kind）
- capabilities の妥当性（リソースの性質に合っているか）
- カラム定義の妥当性（必要なフィールドが含まれているか）

#### 6.3 型定義の整合性確認

```bash
# K8sResourceKind が全ファイルで一致しているか
grep -r "K8sResourceKind" lua/k8s/
```

#### 6.4 動作確認

以下を実際に確認:

1. `:K8s <resource>` でリソース一覧が表示されるか
2. `R` キーでリソースメニューに表示されるか
3. カラムが正しく表示されるか
4. ステータスハイライトが正しく適用されるか
5. capabilities で許可したアクションのみキーマップに表示されるか
6. describe が正しく動作するか

#### 6.5 問題発見時のループ

問題を発見した場合:
1. 問題の原因を特定
2. 該当ステップに戻って修正
3. 再度ステップ5（LSP警告修正）から実行
4. 問題がなくなるまで繰り返す

## CRD 対応時の注意

### API グループの指定

CRD の場合、`kubectl get` に API グループが必要な場合がある:

```bash
# 例: ArgoCD Application
kubectl get applications.argoproj.io -A -o json
```

### namespace スコープ

cluster-scoped リソースの場合:
- namespace カラムは不要
- `-A` フラグなしで取得

## チェックリスト

- [ ] K8sResourceKind 型に追加
- [ ] capabilities_map にエントリ追加
- [ ] column_definitions にカラム定義追加
- [ ] extract_row() に行データ抽出ロジック追加
- [ ] status_column_keys にステータスカラム追加
- [ ] get_status() にステータス取得ロジック追加（必要な場合）
- [ ] status_highlights にステータス追加（必要な場合）
- [ ] ViewType エイリアスに追加
- [ ] type_to_kind マッピングに追加
- [ ] list_types に追加
- [ ] describe_types に追加
- [ ] kind_map に追加
- [ ] resource_types に追加
- [ ] command_to_kind マッピングに追加
- [ ] subcommands に追加
- [ ] doc/k8s.txt の available values に追加

---

**重要: 実装は必ずコミット 28a1ecf の差分を参照して、同じパターンで行うこと。**
