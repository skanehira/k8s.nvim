--- list_handler_spec.lua - リストハンドラーのテスト

describe("list_handler", function()
  local list_handler
  local global_state

  before_each(function()
    package.loaded["k8s.handlers.list_handler"] = nil
    package.loaded["k8s.core.global_state"] = nil
    list_handler = require("k8s.handlers.list_handler")
    global_state = require("k8s.core.global_state")
    global_state.reset()
  end)

  describe("get_current_resource", function()
    it("should return nil when app_state is nil", function()
      global_state.set_app_state(nil)
      assert.is_nil(list_handler.get_current_resource())
    end)

    it("should return nil when window is nil", function()
      global_state.set_app_state({
        current_kind = "Pod",
        resources = {},
        filter = nil,
      })
      global_state.set_window(nil)
      assert.is_nil(list_handler.get_current_resource())
    end)
  end)
end)
