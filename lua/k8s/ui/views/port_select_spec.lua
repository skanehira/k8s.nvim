--- port_select_spec.lua - ポート選択メニューのテスト

local port_select = require("k8s.ui.views.port_select")

describe("port_select", function()
  describe("extract_container_ports", function()
    it("should extract ports from pod spec", function()
      local pod = {
        spec = {
          containers = {
            {
              name = "app",
              ports = {
                { containerPort = 8080, name = "http" },
                { containerPort = 443, name = "https" },
              },
            },
          },
        },
      }

      local ports = port_select.extract_container_ports(pod)

      assert.equals(2, #ports)
      assert.equals(8080, ports[1].port)
      assert.equals("http", ports[1].name)
      assert.equals(443, ports[2].port)
    end)

    it("should extract ports from specific container", function()
      local pod = {
        spec = {
          containers = {
            {
              name = "app",
              ports = {
                { containerPort = 8080 },
              },
            },
            {
              name = "sidecar",
              ports = {
                { containerPort = 9090 },
              },
            },
          },
        },
      }

      local ports = port_select.extract_container_ports(pod, "sidecar")

      assert.equals(1, #ports)
      assert.equals(9090, ports[1].port)
    end)

    it("should return empty list when no ports defined", function()
      local pod = {
        spec = {
          containers = {
            { name = "app" },
          },
        },
      }

      local ports = port_select.extract_container_ports(pod)

      assert.equals(0, #ports)
    end)

    it("should return empty list when spec is nil", function()
      local pod = {}

      local ports = port_select.extract_container_ports(pod)

      assert.equals(0, #ports)
    end)
  end)

  describe("needs_selection", function()
    it("should return true when multiple ports exist", function()
      local ports = {
        { port = 8080, name = "http" },
        { port = 443, name = "https" },
      }
      assert.is_true(port_select.needs_selection(ports))
    end)

    it("should return false when single port", function()
      local ports = {
        { port = 8080 },
      }
      assert.is_false(port_select.needs_selection(ports))
    end)

    it("should return false when no ports", function()
      local ports = {}
      assert.is_false(port_select.needs_selection(ports))
    end)
  end)

  describe("get_default_port", function()
    it("should return first port when available", function()
      local ports = {
        { port = 8080, name = "http" },
        { port = 443, name = "https" },
      }

      local result = port_select.get_default_port(ports)

      assert.equals(8080, result)
    end)

    it("should return nil when no ports", function()
      local ports = {}

      local result = port_select.get_default_port(ports)

      assert.is_nil(result)
    end)
  end)

  describe("create_menu_items", function()
    it("should create menu items with port and name", function()
      local ports = {
        { port = 8080, name = "http" },
        { port = 443, name = "https" },
      }

      local items = port_select.create_menu_items(ports)

      assert.equals(2, #items)
      assert(items[1].text:find("8080"))
      assert(items[1].text:find("http"))
      assert.equals(8080, items[1].value)
    end)

    it("should create menu items without name", function()
      local ports = {
        { port = 8080 },
      }

      local items = port_select.create_menu_items(ports)

      assert.equals(1, #items)
      assert(items[1].text:find("8080"))
      assert.equals(8080, items[1].value)
    end)

    it("should return empty list for empty ports", function()
      local items = port_select.create_menu_items({})
      assert.equals(0, #items)
    end)
  end)

  describe("format_menu_title", function()
    it("should return port selection title", function()
      local title = port_select.format_menu_title()
      assert(title:find("Port") or title:find("port"))
    end)
  end)

  describe("validate_port", function()
    it("should return true for valid port number", function()
      assert.is_true(port_select.validate_port(8080))
      assert.is_true(port_select.validate_port(1))
      assert.is_true(port_select.validate_port(65535))
    end)

    it("should return false for invalid port number", function()
      assert.is_false(port_select.validate_port(0))
      assert.is_false(port_select.validate_port(-1))
      assert.is_false(port_select.validate_port(65536))
    end)

    it("should return false for nil", function()
      assert.is_false(port_select.validate_port(nil))
    end)

    it("should return false for non-number", function()
      assert.is_false(port_select.validate_port("8080"))
    end)
  end)

  describe("format_port_display", function()
    it("should format port with name", function()
      local display = port_select.format_port_display(8080, "http")
      assert(display:find("8080"))
      assert(display:find("http"))
    end)

    it("should format port without name", function()
      local display = port_select.format_port_display(8080)
      assert(display:find("8080"))
    end)
  end)
end)
