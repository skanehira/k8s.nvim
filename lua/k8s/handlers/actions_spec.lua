--- actions_spec.lua - アクション定義のテスト

local actions = require("k8s.handlers.actions")

describe("actions", function()
  describe("format_result", function()
    it("should format success delete message", function()
      local msg = actions.format_result("delete", "Pod", "nginx", true)

      assert.equals("Pod 'nginx' deleted successfully", msg)
    end)

    it("should format success scale message", function()
      local msg = actions.format_result("scale", "Deployment", "nginx", true)

      assert.equals("Deployment 'nginx' scaled successfully", msg)
    end)

    it("should format error message", function()
      local msg = actions.format_result("delete", "Pod", "nginx", false, "not found")

      assert.equals("Failed to delete Pod 'nginx': not found", msg)
    end)
  end)

  describe("can_delete", function()
    it("should return true for Pod", function()
      assert.is_true(actions.can_delete("Pod"))
    end)

    it("should return false for Node", function()
      assert.is_false(actions.can_delete("Node"))
    end)
  end)

  describe("can_scale", function()
    it("should return true for Deployment", function()
      assert.is_true(actions.can_scale("Deployment"))
    end)

    it("should return false for Pod", function()
      assert.is_false(actions.can_scale("Pod"))
    end)
  end)

  describe("can_restart", function()
    it("should return true for Deployment", function()
      assert.is_true(actions.can_restart("Deployment"))
    end)

    it("should return false for Pod", function()
      assert.is_false(actions.can_restart("Pod"))
    end)
  end)

  describe("is_pod", function()
    it("should return true for Pod", function()
      assert.is_true(actions.is_pod("Pod"))
    end)

    it("should return false for Deployment", function()
      assert.is_false(actions.is_pod("Deployment"))
    end)
  end)

  describe("needs_container_selection", function()
    it("should return true when pod has multiple containers", function()
      local pod = {
        raw = {
          spec = {
            containers = {
              { name = "nginx" },
              { name = "sidecar" },
            },
          },
        },
      }

      assert.is_true(actions.needs_container_selection(pod))
    end)

    it("should return false when pod has single container", function()
      local pod = {
        raw = {
          spec = {
            containers = {
              { name = "nginx" },
            },
          },
        },
      }

      assert.is_false(actions.needs_container_selection(pod))
    end)

    it("should return false when pod has no spec", function()
      local pod = { raw = {} }

      assert.is_false(actions.needs_container_selection(pod))
    end)
  end)

  describe("get_default_container", function()
    it("should return first container name", function()
      local pod = {
        raw = {
          spec = {
            containers = {
              { name = "nginx" },
              { name = "sidecar" },
            },
          },
        },
      }

      assert.equals("nginx", actions.get_default_container(pod))
    end)

    it("should return nil when no containers", function()
      local pod = { raw = { spec = { containers = {} } } }

      assert.is_nil(actions.get_default_container(pod))
    end)
  end)

  describe("get_containers", function()
    it("should return all container names", function()
      local pod = {
        raw = {
          spec = {
            containers = {
              { name = "nginx" },
              { name = "sidecar" },
              { name = "logger" },
            },
          },
        },
      }

      local containers = actions.get_containers(pod)

      assert.equals(3, #containers)
      assert.equals("nginx", containers[1])
      assert.equals("sidecar", containers[2])
      assert.equals("logger", containers[3])
    end)

    it("should return empty table when no containers", function()
      local pod = { raw = {} }

      local containers = actions.get_containers(pod)

      assert.equals(0, #containers)
    end)
  end)

  describe("get_container_ports", function()
    it("should return all container ports", function()
      local pod = {
        kind = "Pod",
        raw = {
          spec = {
            containers = {
              {
                name = "nginx",
                ports = {
                  { containerPort = 80, protocol = "TCP" },
                  { containerPort = 443, protocol = "TCP", name = "https" },
                },
              },
              {
                name = "sidecar",
                ports = {
                  { containerPort = 8080 },
                },
              },
            },
          },
        },
      }

      local ports = actions.get_container_ports(pod)

      assert.equals(3, #ports)
      assert.equals(80, ports[1].port)
      assert.equals("nginx", ports[1].container)
      assert.equals("TCP", ports[1].protocol)
      assert.equals(443, ports[2].port)
      assert.equals("https", ports[2].name)
      assert.equals(8080, ports[3].port)
      assert.equals("sidecar", ports[3].container)
    end)

    it("should return empty table when no ports", function()
      local pod = {
        raw = {
          spec = {
            containers = {
              { name = "nginx" },
            },
          },
        },
      }

      local ports = actions.get_container_ports(pod)

      assert.equals(0, #ports)
    end)
  end)

  describe("format_tab_name", function()
    it("should format logs tab name", function()
      local name = actions.format_tab_name("logs", "nginx-abc123", "nginx")

      assert.equals("[Logs] nginx-abc123:nginx", name)
    end)

    it("should format exec tab name", function()
      local name = actions.format_tab_name("exec", "nginx-abc123", "nginx")

      assert.equals("[Exec] nginx-abc123:nginx", name)
    end)
  end)

  describe("get_resource_menu_items", function()
    it("should return resource menu items", function()
      local items = actions.get_resource_menu_items()

      assert(#items > 0)
      -- Check first item
      assert.equals("Pods", items[1].text)
      assert.equals("Pod", items[1].value)
    end)
  end)

  describe("get_menu_title", function()
    it("should return correct title for resource menu", function()
      assert.equals("Select Resource Type", actions.get_menu_title("resource"))
    end)

    it("should return correct title for context menu", function()
      assert.equals("Select Context", actions.get_menu_title("context"))
    end)

    it("should return correct title for namespace menu", function()
      assert.equals("Select Namespace", actions.get_menu_title("namespace"))
    end)

    it("should return correct title for container menu", function()
      assert.equals("Select Container", actions.get_menu_title("container"))
    end)
  end)
end)
