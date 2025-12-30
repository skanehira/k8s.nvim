--- pod_actions_spec.lua - Podアクションのテスト

local pod_actions = require("k8s.handlers.pod_actions")

describe("pod_actions", function()
  describe("create_logs_action", function()
    it("should create logs action config", function()
      local pod = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = pod_actions.create_logs_action(pod, "nginx-container")

      assert.equals("logs", action.type)
      assert.equals("nginx", action.pod_name)
      assert.equals("nginx-container", action.container)
    end)

    it("should support follow option", function()
      local pod = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = pod_actions.create_logs_action(pod, "app", { follow = true })

      assert.is_true(action.follow)
    end)

    it("should support previous option", function()
      local pod = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = pod_actions.create_logs_action(pod, "app", { previous = true })

      assert.is_true(action.previous)
    end)
  end)

  describe("create_exec_action", function()
    it("should create exec action config", function()
      local pod = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = pod_actions.create_exec_action(pod, "nginx-container")

      assert.equals("exec", action.type)
      assert.equals("nginx", action.pod_name)
      assert.equals("nginx-container", action.container)
    end)

    it("should use default shell command", function()
      local pod = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = pod_actions.create_exec_action(pod, "app")

      assert(action.command)
    end)

    it("should support custom command", function()
      local pod = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = pod_actions.create_exec_action(pod, "app", { command = "/bin/bash" })

      assert.equals("/bin/bash", action.command)
    end)
  end)

  describe("create_port_forward_action", function()
    it("should create port forward action config", function()
      local pod = { kind = "Pod", name = "nginx", namespace = "default" }
      local action = pod_actions.create_port_forward_action(pod, 8080, 80)

      assert.equals("port_forward", action.type)
      assert.equals("nginx", action.pod_name)
      assert.equals(8080, action.local_port)
      assert.equals(80, action.remote_port)
    end)
  end)

  describe("validate_pod_action", function()
    it("should return true for Pod kind", function()
      assert.is_true(pod_actions.validate_pod_action("Pod"))
    end)

    it("should return false for non-Pod kinds", function()
      assert.is_false(pod_actions.validate_pod_action("Deployment"))
      assert.is_false(pod_actions.validate_pod_action("Service"))
    end)
  end)

  describe("needs_container_selection", function()
    it("should return true for multiple containers", function()
      local pod = {
        raw = {
          spec = {
            containers = { { name = "app" }, { name = "sidecar" } },
          },
        },
      }
      assert.is_true(pod_actions.needs_container_selection(pod))
    end)

    it("should return false for single container", function()
      local pod = {
        raw = {
          spec = {
            containers = { { name = "app" } },
          },
        },
      }
      assert.is_false(pod_actions.needs_container_selection(pod))
    end)
  end)

  describe("get_default_container", function()
    it("should return first container name", function()
      local pod = {
        raw = {
          spec = {
            containers = { { name = "app" }, { name = "sidecar" } },
          },
        },
      }
      assert.equals("app", pod_actions.get_default_container(pod))
    end)

    it("should return nil for empty containers", function()
      local pod = { raw = { spec = { containers = {} } } }
      assert.is_nil(pod_actions.get_default_container(pod))
    end)
  end)

  describe("format_tab_name", function()
    it("should format logs tab name", function()
      local name = pod_actions.format_tab_name("logs", "nginx", "app")
      assert(name:find("logs") or name:find("Logs"))
      assert(name:find("nginx"))
    end)

    it("should format exec tab name", function()
      local name = pod_actions.format_tab_name("exec", "nginx", "app")
      assert(name:find("exec") or name:find("Exec"))
      assert(name:find("nginx"))
    end)
  end)
end)
