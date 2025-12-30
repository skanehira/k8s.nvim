--- resource_list_spec.lua - リソース一覧Viewのテスト

local resource_list = require("k8s.ui.views.resource_list")

describe("resource_list", function()
  describe("prepare_display_data", function()
    local resources = {
      { name = "nginx-abc123", namespace = "default", status = "Running" },
      { name = "redis-def456", namespace = "default", status = "Pending" },
      { name = "mysql-ghi789", namespace = "kube-system", status = "Running" },
    }

    it("should return sorted resources when no filter", function()
      local result = resource_list.prepare_display_data(resources, "")

      assert.equals(3, #result)
      -- Sorted by name alphabetically
      assert.equals("mysql-ghi789", result[1].name)
      assert.equals("nginx-abc123", result[2].name)
      assert.equals("redis-def456", result[3].name)
    end)

    it("should filter and sort resources", function()
      local result = resource_list.prepare_display_data(resources, "nginx")

      assert.equals(1, #result)
      assert.equals("nginx-abc123", result[1].name)
    end)

    it("should filter by namespace", function()
      local result = resource_list.prepare_display_data(resources, "kube-system")

      assert.equals(1, #result)
      assert.equals("mysql-ghi789", result[1].name)
    end)

    it("should return empty array when no match", function()
      local result = resource_list.prepare_display_data(resources, "nonexistent")

      assert.equals(0, #result)
    end)
  end)

  describe("calculate_cursor_position", function()
    it("should return 1 for first item", function()
      local pos = resource_list.calculate_cursor_position(1, 10)
      assert.equals(1, pos)
    end)

    it("should preserve position when within bounds", function()
      local pos = resource_list.calculate_cursor_position(5, 10)
      assert.equals(5, pos)
    end)

    it("should clamp to last item when position exceeds count", function()
      local pos = resource_list.calculate_cursor_position(15, 10)
      assert.equals(10, pos)
    end)

    it("should return 1 when position is 0", function()
      local pos = resource_list.calculate_cursor_position(0, 10)
      assert.equals(1, pos)
    end)

    it("should return 1 when count is 0", function()
      local pos = resource_list.calculate_cursor_position(5, 0)
      assert.equals(1, pos)
    end)
  end)

  describe("can_perform_action", function()
    it("should allow exec on Pod", function()
      assert.is_true(resource_list.can_perform_action("Pod", "exec"))
    end)

    it("should not allow exec on Deployment", function()
      assert.is_false(resource_list.can_perform_action("Deployment", "exec"))
    end)

    it("should allow scale on Deployment", function()
      assert.is_true(resource_list.can_perform_action("Deployment", "scale"))
    end)

    it("should not allow scale on Pod", function()
      assert.is_false(resource_list.can_perform_action("Pod", "scale"))
    end)

    it("should allow logs on Pod", function()
      assert.is_true(resource_list.can_perform_action("Pod", "logs"))
    end)

    it("should allow port_forward on Pod", function()
      assert.is_true(resource_list.can_perform_action("Pod", "port_forward"))
    end)

    it("should allow port_forward on Service", function()
      assert.is_true(resource_list.can_perform_action("Service", "port_forward"))
    end)

    it("should allow restart on Deployment", function()
      assert.is_true(resource_list.can_perform_action("Deployment", "restart"))
    end)

    it("should not allow restart on Pod", function()
      assert.is_false(resource_list.can_perform_action("Pod", "restart"))
    end)

    it("should return false for unknown action", function()
      assert.is_false(resource_list.can_perform_action("Pod", "unknown_action"))
    end)

    it("should return false for unknown kind", function()
      assert.is_false(resource_list.can_perform_action("UnknownKind", "exec"))
    end)
  end)

  describe("get_resource_at_cursor", function()
    local resources = {
      { name = "nginx", namespace = "default" },
      { name = "redis", namespace = "default" },
      { name = "mysql", namespace = "default" },
    }

    it("should return resource at cursor position", function()
      local resource = resource_list.get_resource_at_cursor(resources, 2)
      assert(resource)
      assert.equals("redis", resource.name)
    end)

    it("should return nil for invalid position", function()
      local resource = resource_list.get_resource_at_cursor(resources, 0)
      assert.is_nil(resource)
    end)

    it("should return nil for position exceeding count", function()
      local resource = resource_list.get_resource_at_cursor(resources, 10)
      assert.is_nil(resource)
    end)

    it("should return nil for empty resources", function()
      local resource = resource_list.get_resource_at_cursor({}, 1)
      assert.is_nil(resource)
    end)
  end)

  describe("get_default_keymaps", function()
    it("should return keymap definitions", function()
      local keymaps = resource_list.get_default_keymaps()

      assert.is.Not.Nil(keymaps["<CR>"])
      assert.equals("select", keymaps["<CR>"])

      assert.is.Not.Nil(keymaps["d"])
      assert.equals("describe", keymaps["d"])

      assert.is.Not.Nil(keymaps["l"])
      assert.equals("logs", keymaps["l"])

      assert.is.Not.Nil(keymaps["e"])
      assert.equals("exec", keymaps["e"])

      assert.is.Not.Nil(keymaps["D"])
      assert.equals("delete", keymaps["D"])

      assert.is.Not.Nil(keymaps["s"])
      assert.equals("scale", keymaps["s"])

      assert.is.Not.Nil(keymaps["X"])
      assert.equals("restart", keymaps["X"])

      assert.is.Not.Nil(keymaps["r"])
      assert.equals("refresh", keymaps["r"])

      assert.is.Not.Nil(keymaps["/"])
      assert.equals("filter", keymaps["/"])

      assert.is.Not.Nil(keymaps["q"])
      assert.equals("quit", keymaps["q"])

      assert.is.Not.Nil(keymaps["?"])
      assert.equals("help", keymaps["?"])

      assert.is.Not.Nil(keymaps["<Esc>"])
      assert.equals("back", keymaps["<Esc>"])

      assert.is.Not.Nil(keymaps["R"])
      assert.equals("resource_menu", keymaps["R"])

      assert.is.Not.Nil(keymaps["C"])
      assert.equals("context_menu", keymaps["C"])

      assert.is.Not.Nil(keymaps["N"])
      assert.equals("namespace_menu", keymaps["N"])

      assert.is.Not.Nil(keymaps["p"])
      assert.equals("port_forward", keymaps["p"])

      assert.is.Not.Nil(keymaps["F"])
      assert.equals("port_forward_list", keymaps["F"])

      assert.is.Not.Nil(keymaps["P"])
      assert.equals("logs_previous", keymaps["P"])

      assert.is.Not.Nil(keymaps["S"])
      assert.equals("toggle_secret", keymaps["S"])
    end)
  end)

  describe("get_action_for_key", function()
    it("should return action name for valid key", function()
      local action = resource_list.get_action_for_key("d")
      assert.equals("describe", action)
    end)

    it("should return nil for unmapped key", function()
      local action = resource_list.get_action_for_key("z")
      assert.is_nil(action)
    end)
  end)

  describe("requires_resource_selection", function()
    it("should return true for describe action", function()
      assert.is_true(resource_list.requires_resource_selection("describe"))
    end)

    it("should return true for logs action", function()
      assert.is_true(resource_list.requires_resource_selection("logs"))
    end)

    it("should return true for exec action", function()
      assert.is_true(resource_list.requires_resource_selection("exec"))
    end)

    it("should return true for delete action", function()
      assert.is_true(resource_list.requires_resource_selection("delete"))
    end)

    it("should return true for scale action", function()
      assert.is_true(resource_list.requires_resource_selection("scale"))
    end)

    it("should return true for restart action", function()
      assert.is_true(resource_list.requires_resource_selection("restart"))
    end)

    it("should return true for port_forward action", function()
      assert.is_true(resource_list.requires_resource_selection("port_forward"))
    end)

    it("should return false for refresh action", function()
      assert.is_false(resource_list.requires_resource_selection("refresh"))
    end)

    it("should return false for filter action", function()
      assert.is_false(resource_list.requires_resource_selection("filter"))
    end)

    it("should return false for quit action", function()
      assert.is_false(resource_list.requires_resource_selection("quit"))
    end)

    it("should return false for help action", function()
      assert.is_false(resource_list.requires_resource_selection("help"))
    end)

    it("should return false for resource_menu action", function()
      assert.is_false(resource_list.requires_resource_selection("resource_menu"))
    end)

    it("should return false for context_menu action", function()
      assert.is_false(resource_list.requires_resource_selection("context_menu"))
    end)

    it("should return false for namespace_menu action", function()
      assert.is_false(resource_list.requires_resource_selection("namespace_menu"))
    end)
  end)

  describe("create_refresh_state", function()
    it("should create initial refresh state", function()
      local state = resource_list.create_refresh_state(5000)

      assert.equals(5000, state.interval)
      assert.is_false(state.is_loading)
      assert.is_nil(state.timer)
      assert.is_nil(state.last_refresh)
    end)
  end)

  describe("should_auto_refresh", function()
    it("should return true when interval has passed", function()
      local state = resource_list.create_refresh_state(5000)
      state.last_refresh = os.time() - 6 -- 6 seconds ago

      assert.is_true(resource_list.should_auto_refresh(state, os.time()))
    end)

    it("should return false when interval has not passed", function()
      local state = resource_list.create_refresh_state(5000)
      state.last_refresh = os.time() - 2 -- 2 seconds ago

      assert.is_false(resource_list.should_auto_refresh(state, os.time()))
    end)

    it("should return true when never refreshed", function()
      local state = resource_list.create_refresh_state(5000)
      -- last_refresh is nil

      assert.is_true(resource_list.should_auto_refresh(state, os.time()))
    end)

    it("should return false when currently loading", function()
      local state = resource_list.create_refresh_state(5000)
      state.is_loading = true

      assert.is_false(resource_list.should_auto_refresh(state, os.time()))
    end)
  end)

  describe("mark_refresh_start", function()
    it("should set is_loading to true", function()
      local state = resource_list.create_refresh_state(5000)

      resource_list.mark_refresh_start(state)

      assert.is_true(state.is_loading)
    end)
  end)

  describe("mark_refresh_complete", function()
    it("should set is_loading to false and update last_refresh", function()
      local state = resource_list.create_refresh_state(5000)
      state.is_loading = true
      local now = os.time()

      resource_list.mark_refresh_complete(state, now)

      assert.is_false(state.is_loading)
      assert.equals(now, state.last_refresh)
    end)
  end)
end)
