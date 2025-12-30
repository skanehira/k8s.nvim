--- deps_spec.lua - 依存性コンテナのテスト

local deps = require("k8s.core.deps")

describe("deps", function()
  after_each(function()
    deps.reset()
  end)

  describe("get", function()
    it("should return default module when not overridden", function()
      local global_state = deps.get("global_state")

      assert.is_table(global_state)
      assert.is_function(global_state.get_app_state)
    end)

    it("should return overridden module when set", function()
      local mock_global_state = {
        get_app_state = function()
          return { mock = true }
        end,
      }
      deps.set("global_state", mock_global_state)

      local global_state = deps.get("global_state")

      assert.equals(mock_global_state, global_state)
    end)
  end)

  describe("set", function()
    it("should override default module", function()
      local mock = { test = true }

      deps.set("adapter", mock)

      assert.equals(mock, deps.get("adapter"))
    end)
  end)

  describe("reset", function()
    it("should clear all overrides", function()
      local mock = { test = true }
      deps.set("adapter", mock)

      deps.reset()

      assert.is_not.equals(mock, deps.get("adapter"))
    end)
  end)

  describe("with_mocks", function()
    it("should execute function with temporary mocks", function()
      local original = deps.get("global_state")
      local mock = { mocked = true }
      local captured_value = nil

      deps.with_mocks({ global_state = mock }, function()
        captured_value = deps.get("global_state")
      end)

      assert.equals(mock, captured_value)
      assert.equals(original, deps.get("global_state"))
    end)

    it("should restore mocks even on error", function()
      local original = deps.get("global_state")
      local mock = { mocked = true }

      pcall(function()
        deps.with_mocks({ global_state = mock }, function()
          error("test error")
        end)
      end)

      assert.equals(original, deps.get("global_state"))
    end)
  end)

  describe("create_mock_global_state", function()
    it("should create mock with default values", function()
      local mock = deps.create_mock_global_state()

      assert.is_function(mock.get_app_state)
      assert.is_function(mock.set_app_state)
      assert.is_function(mock.get_window)
      assert.is_function(mock.get_config)
    end)

    it("should allow setting initial state", function()
      local app_state = { current_kind = "Pod" }
      local mock = deps.create_mock_global_state({ app_state = app_state })

      assert.same(app_state, mock.get_app_state())
    end)

    it("should track state changes", function()
      local mock = deps.create_mock_global_state()
      local new_state = { current_kind = "Deployment" }

      mock.set_app_state(new_state)

      assert.same(new_state, mock.get_app_state())
    end)
  end)

  describe("create_mock_adapter", function()
    it("should create mock with all methods", function()
      local mock = deps.create_mock_adapter()

      assert.is_function(mock.delete)
      assert.is_function(mock.scale)
      assert.is_function(mock.restart)
      assert.is_function(mock.describe)
    end)

    it("should track method calls", function()
      local mock = deps.create_mock_adapter()

      mock.delete("Pod", "nginx", "default", function() end)

      assert.equals(1, #mock._calls.delete)
      assert.equals("Pod", mock._calls.delete[1].kind)
      assert.equals("nginx", mock._calls.delete[1].name)
    end)

    it("should allow custom response", function()
      local mock = deps.create_mock_adapter({
        delete = { ok = true },
      })
      local callback_result = nil

      mock.delete("Pod", "nginx", "default", function(result)
        callback_result = result
      end)

      assert.same({ ok = true }, callback_result)
    end)
  end)
end)
