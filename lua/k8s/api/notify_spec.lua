--- notify_spec.lua - 通知ヘルパーのテスト

local notify = require("k8s.api.notify")

describe("notify", function()
  describe("create_notification", function()
    it("should create info notification", function()
      local n = notify.create_notification("Test message", "info")

      assert.equals("Test message", n.message)
      assert.equals("info", n.level)
    end)

    it("should create warn notification", function()
      local n = notify.create_notification("Warning", "warn")

      assert.equals("warn", n.level)
    end)

    it("should create error notification", function()
      local n = notify.create_notification("Error", "error")

      assert.equals("error", n.level)
    end)

    it("should default to info level", function()
      local n = notify.create_notification("Message")

      assert.equals("info", n.level)
    end)
  end)

  describe("format_action_message", function()
    it("should format delete success message", function()
      local msg = notify.format_action_message("delete", "Pod", "nginx", true)

      assert(msg:find("nginx"))
      assert(msg:find("deleted") or msg:find("Delete"))
    end)

    it("should format delete failure message", function()
      local msg = notify.format_action_message("delete", "Pod", "nginx", false, "not found")

      assert(msg:find("nginx"))
      assert(msg:find("not found") or msg:find("Failed") or msg:find("failed"))
    end)

    it("should format scale message", function()
      local msg = notify.format_action_message("scale", "Deployment", "nginx", true)

      assert(msg:find("nginx"))
      assert(msg:find("scaled") or msg:find("Scale"))
    end)

    it("should format restart message", function()
      local msg = notify.format_action_message("restart", "Deployment", "nginx", true)

      assert(msg:find("nginx"))
      assert(msg:find("restarted") or msg:find("Restart"))
    end)
  end)

  describe("get_level_for_action", function()
    it("should return warn for delete", function()
      assert.equals("warn", notify.get_level_for_action("delete", true))
    end)

    it("should return warn for restart", function()
      assert.equals("warn", notify.get_level_for_action("restart", true))
    end)

    it("should return error for failed action", function()
      assert.equals("error", notify.get_level_for_action("delete", false))
    end)

    it("should return info for non-destructive actions", function()
      assert.equals("info", notify.get_level_for_action("scale", true))
    end)
  end)

  describe("format_port_forward_message", function()
    it("should format start message", function()
      local msg = notify.format_port_forward_message("nginx", 8080, 80, "start")

      assert(msg:find("8080"))
      assert(msg:find("80"))
      assert(msg:find("nginx"))
    end)

    it("should format stop message", function()
      local msg = notify.format_port_forward_message("nginx", 8080, 80, "stop")

      assert(msg:find("stopped") or msg:find("Stop"))
    end)
  end)

  describe("format_context_switch_message", function()
    it("should format context switch message", function()
      local msg = notify.format_context_switch_message("minikube")

      assert(msg:find("minikube"))
      assert(msg:find("context") or msg:find("Context"))
    end)
  end)

  describe("format_namespace_switch_message", function()
    it("should format namespace switch message", function()
      local msg = notify.format_namespace_switch_message("kube-system")

      assert(msg:find("kube-system", 1, true)) -- plain search for hyphenated string
      assert(msg:find("namespace") or msg:find("Namespace"))
    end)
  end)
end)
