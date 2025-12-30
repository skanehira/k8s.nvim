--- describe_handler_spec.lua - 詳細表示ハンドラーのテスト

describe("describe_handler", function()
  local describe_handler

  before_each(function()
    package.loaded["k8s.handlers.describe_handler"] = nil
    package.loaded["k8s.core.global_state"] = nil
    describe_handler = require("k8s.handlers.describe_handler")
  end)

  it("should load module", function()
    assert.is.Not.Nil(describe_handler)
    assert.is.Not.Nil(describe_handler.handle_describe)
    assert.is.Not.Nil(describe_handler.handle_logs)
    assert.is.Not.Nil(describe_handler.handle_logs_previous)
    assert.is.Not.Nil(describe_handler.handle_exec)
  end)
end)
