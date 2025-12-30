---
paths:
  - "**/*_spec.lua"
---

# テストルール

## luassert の構文

luassertでは `is_not_nil` のようなスネークケース形式は使えない。
正しい構文はドット区切りのチェーンパターン:

```lua
-- NG
assert.is_not_nil(value)
assert.is_not_false(value)

-- OK
assert.is.Not.Nil(value)
assert.is.Not.False(value)
assert.is_nil(value)      -- nilチェックはOK
assert.is_true(value)
assert.is_false(value)
```

## nil チェック後のフィールドアクセス

`assert.is.Not.Nil`はLSPに型を伝えない。nilでないことを確認した後にフィールドにアクセスする場合は `assert()` を使う:

```lua
-- NG: LSPが need-check-nil 警告を出す
local conn = connections.get(123)
assert.is.Not.Nil(conn)
assert.equals(123, conn.job_id)  -- warning: need-check-nil

-- OK: assert()で型を絞り込む
local conn = connections.get(123)
assert(conn)
assert.equals(123, conn.job_id)  -- OK
```

## テストファイル配置

テストファイルは対象ファイルと同じディレクトリに `_spec.lua` サフィックスで配置する（コロケーション）:

```
lua/k8s/domain/state/
├── scope.lua
├── scope_spec.lua
├── connections.lua
└── connections_spec.lua
```
