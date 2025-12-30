--- notify_spec.lua - 通知ヘルパーのテスト

local notify = require("k8s.core.notify")

describe("notify", function()
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
