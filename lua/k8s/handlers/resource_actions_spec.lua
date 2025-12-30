--- resource_actions_spec.lua - リソースアクションのテスト

local resource_actions = require("k8s.handlers.resource_actions")

describe("resource_actions", function()
  describe("create_describe_action", function()
    it("should create describe action config", function()
      local resource = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = resource_actions.create_describe_action(resource)

      assert.equals("describe", action.type)
      assert.equals("Pod", action.resource.kind)
      assert.equals("nginx", action.resource.name)
    end)
  end)

  describe("create_delete_action", function()
    it("should create delete action config", function()
      local resource = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = resource_actions.create_delete_action(resource)

      assert.equals("delete", action.type)
      assert.is_true(action.requires_confirm)
    end)

    it("should include confirmation message", function()
      local resource = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = resource_actions.create_delete_action(resource)

      assert(action.confirm_message:find("nginx"))
      assert(action.confirm_message:find("Pod"))
    end)
  end)

  describe("create_scale_action", function()
    it("should create scale action config", function()
      local resource = { kind = "Deployment", name = "nginx", namespace = "default" }
      local action = resource_actions.create_scale_action(resource, 3)

      assert.equals("scale", action.type)
      assert.equals(3, action.replicas)
    end)

    it("should include current replicas if provided", function()
      local resource = { kind = "Deployment", name = "nginx", namespace = "default" }
      local action = resource_actions.create_scale_action(resource, 5, 3)

      assert.equals(5, action.replicas)
      assert.equals(3, action.current_replicas)
    end)
  end)

  describe("create_restart_action", function()
    it("should create restart action config", function()
      local resource = { kind = "Deployment", name = "nginx", namespace = "default" }
      local action = resource_actions.create_restart_action(resource)

      assert.equals("restart", action.type)
      assert.is_true(action.requires_confirm)
    end)
  end)

  describe("validate_delete_target", function()
    it("should return true for deletable resources", function()
      assert.is_true(resource_actions.validate_delete_target("Pod"))
      assert.is_true(resource_actions.validate_delete_target("Deployment"))
      assert.is_true(resource_actions.validate_delete_target("Service"))
    end)

    it("should return false for non-deletable resources", function()
      assert.is_false(resource_actions.validate_delete_target("Node"))
      assert.is_false(resource_actions.validate_delete_target("Namespace"))
    end)
  end)

  describe("validate_scale_target", function()
    it("should return true for scalable resources", function()
      assert.is_true(resource_actions.validate_scale_target("Deployment"))
    end)

    it("should return false for non-scalable resources", function()
      assert.is_false(resource_actions.validate_scale_target("Pod"))
      assert.is_false(resource_actions.validate_scale_target("Service"))
    end)
  end)

  describe("validate_restart_target", function()
    it("should return true for restartable resources", function()
      assert.is_true(resource_actions.validate_restart_target("Deployment"))
    end)

    it("should return false for non-restartable resources", function()
      assert.is_false(resource_actions.validate_restart_target("Pod"))
      assert.is_false(resource_actions.validate_restart_target("Service"))
    end)
  end)

  describe("format_action_result", function()
    it("should format success result", function()
      local result = resource_actions.format_action_result("delete", "Pod", "nginx", true)

      assert(result:find("nginx"))
      assert(result:find("deleted") or result:find("Delete"))
    end)

    it("should format failure result", function()
      local result = resource_actions.format_action_result("delete", "Pod", "nginx", false, "not found")

      assert(result:find("nginx"))
      assert(result:find("not found") or result:find("failed") or result:find("Failed"))
    end)
  end)

  describe("get_action_notification_level", function()
    it("should return warn for destructive actions", function()
      assert.equals("warn", resource_actions.get_action_notification_level("delete"))
      assert.equals("warn", resource_actions.get_action_notification_level("restart"))
    end)

    it("should return info for non-destructive actions", function()
      assert.equals("info", resource_actions.get_action_notification_level("describe"))
      assert.equals("info", resource_actions.get_action_notification_level("scale"))
    end)
  end)
end)
