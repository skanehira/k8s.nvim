--- port_forward_handler_spec.lua - ポートフォワードハンドラーのテスト

describe("port_forward_handler", function()
  local port_forward_handler

  before_each(function()
    package.loaded["k8s.handlers.port_forward_handler"] = nil
    package.loaded["k8s.app.global_state"] = nil
    port_forward_handler = require("k8s.handlers.port_forward_handler")
  end)

  it("should load module", function()
    assert.is.Not.Nil(port_forward_handler)
    assert.is.Not.Nil(port_forward_handler.handle_port_forward)
    assert.is.Not.Nil(port_forward_handler.handle_port_forward_list)
    assert.is.Not.Nil(port_forward_handler.handle_stop_port_forward)
    assert.is.Not.Nil(port_forward_handler.prompt_custom_port_forward)
  end)
end)
