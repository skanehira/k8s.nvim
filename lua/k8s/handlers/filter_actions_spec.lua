--- filter_actions_spec.lua - フィルターアクションのテスト

local filter_actions = require("k8s.handlers.filter_actions")

describe("filter_actions", function()
  describe("create_filter_action", function()
    it("should create filter action", function()
      local action = filter_actions.create_filter_action("nginx")

      assert.equals("filter", action.type)
      assert.equals("nginx", action.pattern)
    end)
  end)

  describe("create_clear_filter_action", function()
    it("should create clear filter action", function()
      local action = filter_actions.create_clear_filter_action()

      assert.equals("clear_filter", action.type)
    end)
  end)

  describe("apply_filter", function()
    it("should filter resources by name", function()
      local resources = {
        { name = "nginx-pod", namespace = "default" },
        { name = "redis-pod", namespace = "default" },
        { name = "nginx-svc", namespace = "kube-system" },
      }

      local filtered = filter_actions.apply_filter(resources, "nginx")

      assert.equals(2, #filtered)
    end)

    it("should filter case-insensitively", function()
      local resources = {
        { name = "Nginx-Pod", namespace = "default" },
        { name = "redis-pod", namespace = "default" },
      }

      local filtered = filter_actions.apply_filter(resources, "nginx")

      assert.equals(1, #filtered)
    end)

    it("should also match namespace", function()
      local resources = {
        { name = "pod1", namespace = "kube-system" },
        { name = "pod2", namespace = "default" },
      }

      local filtered = filter_actions.apply_filter(resources, "kube")

      assert.equals(1, #filtered)
    end)

    it("should return all when pattern is empty", function()
      local resources = {
        { name = "pod1", namespace = "default" },
        { name = "pod2", namespace = "default" },
      }

      local filtered = filter_actions.apply_filter(resources, "")

      assert.equals(2, #filtered)
    end)
  end)

  describe("is_filter_active", function()
    it("should return true for non-empty pattern", function()
      assert.is_true(filter_actions.is_filter_active("nginx"))
    end)

    it("should return false for empty pattern", function()
      assert.is_false(filter_actions.is_filter_active(""))
      assert.is_false(filter_actions.is_filter_active(nil))
    end)
  end)

  describe("format_filter_prompt", function()
    it("should return filter prompt", function()
      local prompt = filter_actions.format_filter_prompt()
      assert(prompt:find("Filter") or prompt:find("filter") or prompt:find("/"))
    end)
  end)

  describe("validate_filter_pattern", function()
    it("should return true for valid pattern", function()
      assert.is_true(filter_actions.validate_filter_pattern("nginx"))
      assert.is_true(filter_actions.validate_filter_pattern("nginx-pod"))
      assert.is_true(filter_actions.validate_filter_pattern(""))
    end)

    it("should return true for pattern with special chars", function()
      assert.is_true(filter_actions.validate_filter_pattern("nginx.*"))
    end)
  end)
end)
