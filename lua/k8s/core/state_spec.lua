--- app_spec.lua - アプリケーションコントローラのテスト

local app = require("k8s.core.state")

describe("app", function()
  describe("create_state", function()
    it("should create initial app state", function()
      local state = app.create_state()

      assert.is_false(state.running)
      assert.is_nil(state.current_kind)
      assert.is_nil(state.current_namespace)
      assert.is_table(state.resources)
    end)
  end)

  describe("create_state with options", function()
    it("should accept initial kind", function()
      local state = app.create_state({ kind = "Pod" })

      assert.equals("Pod", state.current_kind)
    end)

    it("should accept initial namespace", function()
      local state = app.create_state({ namespace = "default" })

      assert.equals("default", state.current_namespace)
    end)
  end)

  describe("set_running", function()
    it("should set running state", function()
      local state = app.create_state()

      local new_state = app.set_running(state, true)

      assert.is_true(new_state.running)
    end)
  end)

  describe("set_kind", function()
    it("should set current kind", function()
      local state = app.create_state()

      local new_state = app.set_kind(state, "Deployment")

      assert.equals("Deployment", new_state.current_kind)
    end)

    it("should clear resources on kind change", function()
      local state = app.create_state()
      state.resources = { { name = "pod1" } }

      local new_state = app.set_kind(state, "Deployment")

      assert.equals(0, #new_state.resources)
    end)
  end)

  describe("set_namespace", function()
    it("should set current namespace", function()
      local state = app.create_state()

      local new_state = app.set_namespace(state, "kube-system")

      assert.equals("kube-system", new_state.current_namespace)
    end)

    it("should clear resources on namespace change", function()
      local state = app.create_state()
      state.resources = { { name = "pod1" } }

      local new_state = app.set_namespace(state, "kube-system")

      assert.equals(0, #new_state.resources)
    end)
  end)

  describe("set_resources", function()
    it("should set resources", function()
      local state = app.create_state()
      local resources = {
        { name = "pod1" },
        { name = "pod2" },
      }

      local new_state = app.set_resources(state, resources)

      assert.equals(2, #new_state.resources)
    end)
  end)

  describe("set_filter", function()
    it("should set filter pattern", function()
      local state = app.create_state()

      local new_state = app.set_filter(state, "nginx")

      assert.equals("nginx", new_state.filter)
    end)
  end)

  describe("set_cursor", function()
    it("should set cursor position", function()
      local state = app.create_state()

      local new_state = app.set_cursor(state, 5)

      assert.equals(5, new_state.cursor)
    end)
  end)

  describe("get_filtered_resources", function()
    it("should return filtered resources", function()
      local state = app.create_state()
      state.resources = {
        { name = "nginx-pod", namespace = "default" },
        { name = "redis-pod", namespace = "default" },
      }
      state.filter = "nginx"

      local filtered = app.get_filtered_resources(state)

      assert.equals(1, #filtered)
      assert.equals("nginx-pod", filtered[1].name)
    end)

    it("should return all when no filter", function()
      local state = app.create_state()
      state.resources = {
        { name = "nginx-pod", namespace = "default" },
        { name = "redis-pod", namespace = "default" },
      }

      local filtered = app.get_filtered_resources(state)

      assert.equals(2, #filtered)
    end)
  end)

  describe("get_current_resource", function()
    it("should return resource at cursor", function()
      local state = app.create_state()
      state.resources = {
        { name = "pod1", namespace = "default" },
        { name = "pod2", namespace = "default" },
      }
      state.cursor = 2

      local resource = app.get_current_resource(state)

      assert.equals("pod2", resource.name)
    end)

    it("should return nil for empty resources", function()
      local state = app.create_state()

      local resource = app.get_current_resource(state)

      assert.is_nil(resource)
    end)
  end)
end)
