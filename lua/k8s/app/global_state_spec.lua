--- global_state_spec.lua - グローバル状態管理モジュールのテスト

describe("global_state", function()
  local global_state

  before_each(function()
    package.loaded["k8s.app.global_state"] = nil
    global_state = require("k8s.app.global_state")
    global_state.reset()
  end)

  describe("get/set", function()
    it("should get and set values by key", function()
      global_state.set("config", { default_kind = "Pod" })
      assert.same({ default_kind = "Pod" }, global_state.get("config"))
    end)

    it("should return nil for unset keys", function()
      assert.is_nil(global_state.get("nonexistent"))
    end)
  end)

  describe("reset", function()
    it("should reset all state to initial values", function()
      global_state.set("setup_done", true)
      global_state.set("config", { test = true })
      global_state.set("window", { bufnr = 1 })

      global_state.reset()

      assert.is_false(global_state.is_setup_done())
      assert.is_nil(global_state.get_config())
      assert.is_nil(global_state.get_window())
    end)
  end)

  describe("setup_done", function()
    it("should be false initially", function()
      assert.is_false(global_state.is_setup_done())
    end)

    it("should be true after set_setup_done", function()
      global_state.set_setup_done()
      assert.is_true(global_state.is_setup_done())
    end)
  end)

  describe("config", function()
    it("should get and set config", function()
      local config = { default_kind = "Deployment", refresh_interval = 5000 }
      global_state.set_config(config)
      assert.same(config, global_state.get_config())
    end)
  end)

  describe("window", function()
    it("should get and set window", function()
      local window = { bufnr = 123, winid = 456 }
      global_state.set_window(window)
      assert.same(window, global_state.get_window())
    end)

    it("should allow setting window to nil", function()
      global_state.set_window({ bufnr = 1 })
      global_state.set_window(nil)
      assert.is_nil(global_state.get_window())
    end)
  end)

  describe("app_state", function()
    it("should get and set app_state", function()
      local app_state = { current_kind = "Pod", current_namespace = "default" }
      global_state.set_app_state(app_state)
      assert.same(app_state, global_state.get_app_state())
    end)
  end)

  describe("timer", function()
    it("should get and set timer", function()
      local timer = { mock = "timer" }
      global_state.set_timer(timer)
      assert.same(timer, global_state.get_timer())
    end)
  end)

  describe("view_stack", function()
    it("should get and set view_stack", function()
      local view_stack = { { type = "list", kind = "Pod" } }
      global_state.set_view_stack(view_stack)
      assert.same(view_stack, global_state.get_view_stack())
    end)
  end)

  describe("pf_list_connections", function()
    it("should get and set pf_list_connections", function()
      local connections = { { job_id = 1, local_port = 8080 } }
      global_state.set_pf_list_connections(connections)
      assert.same(connections, global_state.get_pf_list_connections())
    end)
  end)
end)
