--- state/init_spec.lua - State API tests

describe("state", function()
  local state

  before_each(function()
    package.loaded["k8s.state"] = nil
    package.loaded["k8s.state.global"] = nil
    package.loaded["k8s.state.view"] = nil
    state = require("k8s.state")
    state.reset()
  end)

  describe("observer pattern", function()
    it("should call listener on notify", function()
      local called = false
      state.subscribe(function()
        called = true
      end)

      state.notify()

      assert.is_true(called)
    end)

    it("should not call listener after unsubscribe", function()
      local call_count = 0
      state.subscribe(function()
        call_count = call_count + 1
      end)

      state.notify()
      state.unsubscribe()
      state.notify()

      assert.equals(1, call_count)
    end)
  end)

  describe("global state", function()
    it("should get and set context", function()
      assert.is_nil(state.get_context())

      state.set_context("my-context")

      assert.equals("my-context", state.get_context())
    end)

    it("should get and set namespace", function()
      assert.equals("default", state.get_namespace())

      state.set_namespace("kube-system")

      assert.equals("kube-system", state.get_namespace())
    end)

    it("should notify on context change", function()
      local notified = false
      state.subscribe(function()
        notified = true
      end)

      state.set_context("new-context")

      assert.is_true(notified)
    end)

    it("should notify on namespace change", function()
      local notified = false
      state.subscribe(function()
        notified = true
      end)

      state.set_namespace("new-namespace")

      assert.is_true(notified)
    end)

    it("should track setup done", function()
      assert.is_false(state.is_setup_done())

      state.set_setup_done()

      assert.is_true(state.is_setup_done())
    end)

    it("should get and set config", function()
      assert.is_nil(state.get_config())

      local config = { timeout = 5000 }
      state.set_config(config)

      assert.same(config, state.get_config())
    end)

    it("should get and set window", function()
      assert.is_nil(state.get_window())

      local mock_window = { bufnr = 1, mounted = true }
      state.set_window(mock_window)

      assert.same(mock_window, state.get_window())
    end)

    it("should clear window by setting nil", function()
      state.set_window({ bufnr = 1 })
      assert.is.Not.Nil(state.get_window())

      state.set_window(nil)

      assert.is_nil(state.get_window())
    end)
  end)

  describe("view stack", function()
    it("should push and get current view", function()
      assert.is_nil(state.get_current_view())

      local view1 = { type = "pod_list" }
      state.push_view(view1)

      local current = state.get_current_view()
      assert(current)
      assert.equals("pod_list", current.type)
    end)

    it("should pop view", function()
      state.push_view({ type = "pod_list" })
      state.push_view({ type = "pod_describe" })

      local popped = state.pop_view()

      assert(popped)
      assert.equals("pod_describe", popped.type)
      local current = state.get_current_view()
      assert(current)
      assert.equals("pod_list", current.type)
    end)

    it("should check can_pop_view", function()
      assert.is_false(state.can_pop_view())

      state.push_view({ type = "pod_list" })
      assert.is_false(state.can_pop_view())

      state.push_view({ type = "pod_describe" })
      assert.is_true(state.can_pop_view())
    end)

    it("should clear view stack", function()
      state.push_view({ type = "pod_list" })
      state.push_view({ type = "pod_describe" })

      state.clear_view_stack()

      assert.same({}, state.get_view_stack())
    end)
  end)

  describe("current view state", function()
    before_each(function()
      state.push_view({
        type = "pod_list",
        resources = {},
        filter = nil,
        cursor = 1,
      })
    end)

    it("should add resource", function()
      local resource = { name = "nginx", namespace = "default" }
      state.add_resource(resource)

      local current = state.get_current_view()
      assert(current)
      assert.equals(1, #current.resources)
      assert.equals("nginx", current.resources[1].name)
    end)

    it("should update existing resource (upsert)", function()
      state.add_resource({ name = "nginx", namespace = "default", status = "Pending" })
      state.add_resource({ name = "nginx", namespace = "default", status = "Running" })

      local current = state.get_current_view()
      assert(current)
      assert.equals(1, #current.resources)
      assert.equals("Running", current.resources[1].status)
    end)

    it("should remove resource", function()
      state.add_resource({ name = "nginx", namespace = "default" })
      state.add_resource({ name = "redis", namespace = "default" })

      state.remove_resource("nginx", "default")

      local current = state.get_current_view()
      assert(current)
      assert.equals(1, #current.resources)
      assert.equals("redis", current.resources[1].name)
    end)

    it("should clear resources", function()
      state.add_resource({ name = "nginx", namespace = "default" })
      state.add_resource({ name = "redis", namespace = "default" })

      state.clear_resources()

      local current = state.get_current_view()
      assert(current)
      assert.equals(0, #current.resources)
    end)

    it("should set filter", function()
      state.set_filter("nginx")

      local current = state.get_current_view()
      assert(current)
      assert.equals("nginx", current.filter)
      assert.equals(1, current.cursor) -- cursor resets on filter
    end)

    it("should set cursor", function()
      state.set_cursor(5)

      local current = state.get_current_view()
      assert(current)
      assert.equals(5, current.cursor)
    end)

    it("should notify on view update", function()
      local notify_count = 0
      state.subscribe(function()
        notify_count = notify_count + 1
      end)

      state.add_resource({ name = "nginx", namespace = "default" })
      state.set_filter("test")
      state.set_cursor(2)

      assert.equals(3, notify_count)
    end)

    it("should set watcher job_id", function()
      state.set_watcher_job_id(12345)

      local current = state.get_current_view()
      assert(current)
      assert.equals(12345, current.watcher_job_id)
    end)

    it("should not error when setting watcher job_id with empty stack", function()
      state.clear_view_stack()

      -- Should not throw error
      state.set_watcher_job_id(12345)

      assert.is_nil(state.get_current_view())
    end)

    it("should set mask_secrets", function()
      state.set_mask_secrets(true)

      local current = state.get_current_view()
      assert(current)
      assert.is_true(current.mask_secrets)
    end)

    it("should toggle mask_secrets", function()
      state.set_mask_secrets(true)
      state.set_mask_secrets(false)

      local current = state.get_current_view()
      assert(current)
      assert.is_false(current.mask_secrets)
    end)

    it("should notify on mask_secrets change", function()
      local notify_count = 0
      state.subscribe(function()
        notify_count = notify_count + 1
      end)

      state.set_mask_secrets(true)

      assert.equals(1, notify_count)
    end)

    it("should set view type", function()
      state.set_view_type("deployment_list")

      local current = state.get_current_view()
      assert(current)
      assert.equals("deployment_list", current.type)
    end)

    it("should not error when setting view type with empty stack", function()
      state.clear_view_stack()

      -- Should not throw error
      state.set_view_type("deployment_list")

      assert.is_nil(state.get_current_view())
    end)
  end)

  describe("namespace change", function()
    it("should clear all view resources on namespace change", function()
      state.push_view({
        type = "pod_list",
        resources = { { name = "nginx", namespace = "default" } },
      })
      state.push_view({
        type = "deployment_list",
        resources = { { name = "web", namespace = "default" } },
      })

      state.set_namespace("kube-system")

      local stack = state.get_view_stack()
      assert.equals(0, #stack[1].resources)
      assert.equals(0, #stack[2].resources)
    end)
  end)

  describe("utility functions", function()
    it("should get kind from view type", function()
      assert.equals("Pod", state.get_kind_from_view_type("pod_list"))
      assert.equals("Pod", state.get_kind_from_view_type("pod_describe"))
      assert.equals("Deployment", state.get_kind_from_view_type("deployment_list"))
      assert.is_nil(state.get_kind_from_view_type("help"))
    end)

    it("should check if list view", function()
      assert.is_true(state.is_list_view("pod_list"))
      assert.is_true(state.is_list_view("deployment_list"))
      assert.is_false(state.is_list_view("pod_describe"))
      assert.is_false(state.is_list_view("help"))
    end)

    it("should check if describe view", function()
      assert.is_true(state.is_describe_view("pod_describe"))
      assert.is_true(state.is_describe_view("secret_describe"))
      assert.is_false(state.is_describe_view("pod_list"))
      assert.is_false(state.is_describe_view("help"))
    end)
  end)
end)
