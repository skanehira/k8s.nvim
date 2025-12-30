--- container_select_spec.lua - コンテナ選択メニューのテスト

local container_select = require("k8s.ui.views.container_select")

describe("container_select", function()
  describe("extract_containers", function()
    it("should extract container names from pod spec", function()
      local pod = {
        spec = {
          containers = {
            { name = "app" },
            { name = "sidecar" },
          },
        },
      }

      local containers = container_select.extract_containers(pod)

      assert.equals(2, #containers)
      assert.equals("app", containers[1])
      assert.equals("sidecar", containers[2])
    end)

    it("should return empty list when no containers", function()
      local pod = {
        spec = {
          containers = {},
        },
      }

      local containers = container_select.extract_containers(pod)

      assert.equals(0, #containers)
    end)

    it("should return empty list when spec is nil", function()
      local pod = {}

      local containers = container_select.extract_containers(pod)

      assert.equals(0, #containers)
    end)

    it("should include init containers when requested", function()
      local pod = {
        spec = {
          initContainers = {
            { name = "init-db" },
          },
          containers = {
            { name = "app" },
          },
        },
      }

      local containers = container_select.extract_containers(pod, { include_init = true })

      assert.equals(2, #containers)
      assert.equals("init-db", containers[1])
      assert.equals("app", containers[2])
    end)
  end)

  describe("needs_selection", function()
    it("should return true when multiple containers exist", function()
      local containers = { "app", "sidecar" }
      assert.is_true(container_select.needs_selection(containers))
    end)

    it("should return false when single container", function()
      local containers = { "app" }
      assert.is_false(container_select.needs_selection(containers))
    end)

    it("should return false when no containers", function()
      local containers = {}
      assert.is_false(container_select.needs_selection(containers))
    end)
  end)

  describe("get_default_container", function()
    it("should return first container when single", function()
      local containers = { "app" }
      local result = container_select.get_default_container(containers)
      assert.equals("app", result)
    end)

    it("should return first container when multiple", function()
      local containers = { "app", "sidecar" }
      local result = container_select.get_default_container(containers)
      assert.equals("app", result)
    end)

    it("should return nil when no containers", function()
      local containers = {}
      local result = container_select.get_default_container(containers)
      assert.is_nil(result)
    end)
  end)

  describe("create_menu_items", function()
    it("should create menu items from container names", function()
      local containers = { "app", "sidecar", "init-db" }

      local items = container_select.create_menu_items(containers)

      assert.equals(3, #items)
      assert.equals("app", items[1].text)
      assert.equals("app", items[1].value)
      assert.equals("sidecar", items[2].text)
      assert.equals("init-db", items[3].text)
    end)

    it("should return empty list for empty containers", function()
      local containers = {}

      local items = container_select.create_menu_items(containers)

      assert.equals(0, #items)
    end)
  end)

  describe("format_menu_title", function()
    it("should return container selection title", function()
      local title = container_select.format_menu_title()
      assert(title:find("Container"))
    end)
  end)

  describe("validate_container_name", function()
    it("should return true for valid container name", function()
      local containers = { "app", "sidecar" }
      local valid = container_select.validate_container_name(containers, "app")
      assert.is_true(valid)
    end)

    it("should return false for invalid container name", function()
      local containers = { "app", "sidecar" }
      local valid = container_select.validate_container_name(containers, "unknown")
      assert.is_false(valid)
    end)

    it("should return false for nil container name", function()
      local containers = { "app" }
      local valid = container_select.validate_container_name(containers, nil)
      assert.is_false(valid)
    end)
  end)
end)
