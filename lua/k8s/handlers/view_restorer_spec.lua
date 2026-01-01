--- view_restorer_spec.lua - ビュー復帰処理のテスト

local view_restorer = require("k8s.handlers.view_restorer")

describe("view_restorer", function()
  describe("restore", function()
    it("should call callbacks.render_footer for list view", function()
      local view = { type = "list", kind = "Pod" }
      local footer_called = false
      local callbacks = {
        render_footer = function()
          footer_called = true
        end,
        fetch_and_render = function() end,
      }
      local mock_global_state = {
        get_app_state = function()
          return { current_kind = "Pod", current_namespace = "default" }
        end,
        set_app_state = function() end,
      }

      view_restorer.restore(view, callbacks, nil, { global_state = mock_global_state })

      assert.is_true(footer_called)
    end)

    it("should call callbacks.render_footer for describe view", function()
      local view = { type = "describe", resource = { kind = "Pod" } }
      local footer_called = false
      local callbacks = {
        render_footer = function()
          footer_called = true
        end,
      }

      view_restorer.restore(view, callbacks, nil, {})

      assert.is_true(footer_called)
    end)

    it("should do nothing for unknown view type", function()
      local view = { type = "unknown" }
      local callbacks = {}

      -- Should not throw error
      view_restorer.restore(view, callbacks, nil, {})
    end)
  end)
end)
