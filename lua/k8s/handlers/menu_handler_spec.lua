--- menu_handler_spec.lua - メニューハンドラーのテスト

describe("menu_handler", function()
  local menu_handler

  before_each(function()
    package.loaded["k8s.handlers.menu_handler"] = nil
    package.loaded["k8s.app.global_state"] = nil
    menu_handler = require("k8s.handlers.menu_handler")
  end)

  it("should load module", function()
    assert.is.Not.Nil(menu_handler)
    assert.is.Not.Nil(menu_handler.handle_resource_menu)
    assert.is.Not.Nil(menu_handler.handle_context_menu)
    assert.is.Not.Nil(menu_handler.handle_namespace_menu)
    assert.is.Not.Nil(menu_handler.handle_help)
  end)
end)
