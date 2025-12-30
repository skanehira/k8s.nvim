--- navigation_spec.lua - ナビゲーションのテスト

local navigation = require("k8s.handlers.navigation")

describe("navigation", function()
  describe("create_select_action", function()
    it("should create select action", function()
      local resource = { kind = "Pod", name = "nginx" }
      local action = navigation.create_select_action(resource)

      assert.equals("select", action.type)
      assert.equals("nginx", action.resource.name)
    end)
  end)

  describe("create_back_action", function()
    it("should create back action", function()
      local action = navigation.create_back_action()

      assert.equals("back", action.type)
    end)
  end)

  describe("create_quit_action", function()
    it("should create quit action", function()
      local action = navigation.create_quit_action()

      assert.equals("quit", action.type)
    end)
  end)

  describe("can_go_back", function()
    it("should return true when stack has items", function()
      local stack = { "view1", "view2" }
      assert.is_true(navigation.can_go_back(stack))
    end)

    it("should return false when stack has one item", function()
      local stack = { "view1" }
      assert.is_false(navigation.can_go_back(stack))
    end)

    it("should return false when stack is empty", function()
      local stack = {}
      assert.is_false(navigation.can_go_back(stack))
    end)
  end)

  describe("get_cursor_resource", function()
    it("should return resource at cursor position", function()
      local resources = {
        { name = "pod1" },
        { name = "pod2" },
        { name = "pod3" },
      }
      local resource = navigation.get_cursor_resource(resources, 2)

      assert.equals("pod2", resource.name)
    end)

    it("should return nil for invalid position", function()
      local resources = { { name = "pod1" } }

      assert.is_nil(navigation.get_cursor_resource(resources, 0))
      assert.is_nil(navigation.get_cursor_resource(resources, 5))
    end)
  end)

  describe("calculate_next_cursor", function()
    it("should stay in bounds after delete", function()
      local pos = navigation.calculate_next_cursor(3, 2, "delete")
      assert.equals(2, pos)
    end)

    it("should move to last item if at end", function()
      local pos = navigation.calculate_next_cursor(2, 3, "delete")
      assert.equals(2, pos)
    end)

    it("should return 1 for empty list", function()
      local pos = navigation.calculate_next_cursor(0, 1, "delete")
      assert.equals(1, pos)
    end)
  end)
end)
