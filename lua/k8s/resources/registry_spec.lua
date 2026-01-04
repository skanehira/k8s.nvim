--- registry_spec.lua - Tests for resource registry

describe("k8s.resources.registry", function()
  local registry

  before_each(function()
    registry = require("k8s.resources.registry")
  end)

  describe("resources", function()
    it("all resources have required fields", function()
      local required_fields = {
        "kind",
        "plural",
        "display_name",
        "capabilities",
        "columns",
        "status_column_key",
        "extract_row",
      }

      for kind, def in pairs(registry.resources) do
        for _, field in ipairs(required_fields) do
          assert(def[field], string.format("%s is missing field: %s", kind, field))
        end
      end
    end)

    it("all resources have required capabilities", function()
      local required_caps = {
        "exec",
        "logs",
        "scale",
        "restart",
        "port_forward",
        "delete",
        "filter",
        "refresh",
      }

      for kind, def in pairs(registry.resources) do
        for _, cap in ipairs(required_caps) do
          assert(
            type(def.capabilities[cap]) == "boolean",
            string.format("%s.capabilities.%s must be boolean", kind, cap)
          )
        end
      end
    end)

    it("all resources have at least one column", function()
      for kind, def in pairs(registry.resources) do
        assert(#def.columns > 0, string.format("%s must have at least one column", kind))
      end
    end)

    it("all columns have key and header", function()
      for kind, def in pairs(registry.resources) do
        for i, col in ipairs(def.columns) do
          assert(col.key, string.format("%s column %d is missing key", kind, i))
          assert(col.header, string.format("%s column %d is missing header", kind, i))
        end
      end
    end)
  end)

  describe("get", function()
    it("returns definition for existing kind", function()
      local def = registry.get("Pod")
      assert(def)
      assert.equals("Pod", def.kind)
      assert.equals("pods", def.plural)
    end)

    it("returns nil for non-existing kind", function()
      local def = registry.get("NonExistent")
      assert.is_nil(def)
    end)
  end)

  describe("all_kinds", function()
    it("returns sorted list of kinds", function()
      local kinds = registry.all_kinds()
      assert(#kinds > 0)

      -- Check sorted order
      for i = 2, #kinds do
        assert(kinds[i - 1] < kinds[i], "kinds should be sorted alphabetically")
      end
    end)

    it("includes known kinds", function()
      local kinds = registry.all_kinds()
      local kind_set = {}
      for _, k in ipairs(kinds) do
        kind_set[k] = true
      end

      assert.is_true(kind_set["Pod"])
      assert.is_true(kind_set["Deployment"])
      assert.is_true(kind_set["Service"])
    end)
  end)

  describe("capabilities", function()
    it("returns capabilities for Pod", function()
      local caps = registry.capabilities("Pod")
      assert.is_true(caps.exec)
      assert.is_true(caps.logs)
      assert.is_false(caps.scale)
      assert.is_false(caps.restart)
      assert.is_true(caps.port_forward)
      assert.is_true(caps.delete)
    end)

    it("returns capabilities for Deployment", function()
      local caps = registry.capabilities("Deployment")
      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_true(caps.scale)
      assert.is_true(caps.restart)
      assert.is_true(caps.port_forward)
      assert.is_true(caps.delete)
    end)

    it("returns default capabilities for unknown kind", function()
      local caps = registry.capabilities("UnknownKind")
      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_true(caps.filter)
      assert.is_true(caps.refresh)
    end)
  end)

  describe("can_perform", function()
    it("returns true for allowed actions", function()
      assert.is_true(registry.can_perform("Pod", "exec"))
      assert.is_true(registry.can_perform("Pod", "logs"))
      assert.is_true(registry.can_perform("Deployment", "scale"))
      assert.is_true(registry.can_perform("Deployment", "restart"))
    end)

    it("returns false for disallowed actions", function()
      assert.is_false(registry.can_perform("Pod", "scale"))
      assert.is_false(registry.can_perform("Pod", "restart"))
      assert.is_false(registry.can_perform("Deployment", "exec"))
      assert.is_false(registry.can_perform("Deployment", "logs"))
    end)
  end)

  describe("get_menu_items", function()
    it("returns sorted menu items", function()
      local items = registry.get_menu_items()
      assert(#items > 0)

      -- Check sorted by text
      for i = 2, #items do
        assert(items[i - 1].text < items[i].text, "items should be sorted by text")
      end
    end)

    it("items have text and value", function()
      local items = registry.get_menu_items()
      for _, item in ipairs(items) do
        assert(item.text, "menu item should have text")
        assert(item.value, "menu item should have value")
      end
    end)
  end)

  describe("get_subcommands", function()
    it("includes base commands", function()
      local cmds = registry.get_subcommands()
      local cmd_set = {}
      for _, c in ipairs(cmds) do
        cmd_set[c] = true
      end

      assert.is_true(cmd_set["open"])
      assert.is_true(cmd_set["close"])
      assert.is_true(cmd_set["context"])
      assert.is_true(cmd_set["namespace"])
    end)

    it("includes resource plurals", function()
      local cmds = registry.get_subcommands()
      local cmd_set = {}
      for _, c in ipairs(cmds) do
        cmd_set[c] = true
      end

      assert.is_true(cmd_set["pods"])
      assert.is_true(cmd_set["deployments"])
      assert.is_true(cmd_set["services"])
    end)

    it("returns sorted list", function()
      local cmds = registry.get_subcommands()
      for i = 2, #cmds do
        assert(cmds[i - 1] < cmds[i], "subcommands should be sorted")
      end
    end)
  end)

  describe("get_kind_from_plural", function()
    it("returns kind for known plurals", function()
      assert.equals("Pod", registry.get_kind_from_plural("pods"))
      assert.equals("Deployment", registry.get_kind_from_plural("deployments"))
      assert.equals("Service", registry.get_kind_from_plural("services"))
      assert.equals("Ingress", registry.get_kind_from_plural("ingresses"))
    end)

    it("returns nil for unknown plural", function()
      assert.is_nil(registry.get_kind_from_plural("unknowns"))
    end)
  end)

  describe("get_plural_from_kind", function()
    it("returns plural for known kinds", function()
      assert.equals("pods", registry.get_plural_from_kind("Pod"))
      assert.equals("deployments", registry.get_plural_from_kind("Deployment"))
      assert.equals("services", registry.get_plural_from_kind("Service"))
      assert.equals("ingresses", registry.get_plural_from_kind("Ingress"))
    end)

    it("returns default plural for unknown kind", function()
      assert.equals("unknowns", registry.get_plural_from_kind("Unknown"))
    end)
  end)

  describe("get_columns", function()
    it("returns columns for Pod", function()
      local cols = registry.get_columns("Pod")
      assert(#cols >= 4)

      local col_keys = {}
      for _, col in ipairs(cols) do
        col_keys[col.key] = true
      end

      assert.is_true(col_keys["name"])
      assert.is_true(col_keys["namespace"])
      assert.is_true(col_keys["status"])
    end)

    it("returns default columns for unknown kind", function()
      local cols = registry.get_columns("UnknownKind")
      assert(#cols >= 4)
    end)
  end)

  describe("get_status_column_key", function()
    it("returns status column key", function()
      assert.equals("status", registry.get_status_column_key("Pod"))
      assert.equals("ready", registry.get_status_column_key("Deployment"))
      assert.equals("type", registry.get_status_column_key("Service"))
    end)

    it("returns default for unknown kind", function()
      assert.equals("status", registry.get_status_column_key("UnknownKind"))
    end)
  end)

  describe("extract_status", function()
    it("extracts Deployment status", function()
      local item = {
        spec = { replicas = 3 },
        status = { readyReplicas = 2 },
      }
      assert.equals("2/3", registry.extract_status(item, "Deployment"))
    end)

    it("extracts Node status", function()
      local item = {
        status = {
          conditions = {
            { type = "Ready", status = "True" },
          },
        },
      }
      assert.equals("Ready", registry.extract_status(item, "Node"))
    end)

    it("returns Unknown for unknown kind", function()
      assert.equals("Unknown", registry.extract_status({}, "UnknownKind"))
    end)
  end)

  describe("extract_row", function()
    it("extracts Pod row", function()
      local resource = {
        kind = "Pod",
        name = "test-pod",
        namespace = "default",
        status = "Running",
        age = "1d",
        raw = {
          status = {
            containerStatuses = {
              { ready = true, restartCount = 5 },
            },
          },
        },
      }
      local row = registry.extract_row(resource)
      assert.equals("test-pod", row.name)
      assert.equals("default", row.namespace)
      assert.equals("Running", row.status)
      assert.equals("1d", row.age)
      assert.equals("1/1", row.ready)
      assert.equals(5, row.restarts)
    end)

    it("extracts Deployment row", function()
      local resource = {
        kind = "Deployment",
        name = "test-deploy",
        namespace = "default",
        status = "2/3",
        age = "2d",
        raw = {
          spec = { replicas = 3 },
          status = {
            readyReplicas = 2,
            updatedReplicas = 2,
            availableReplicas = 2,
          },
        },
      }
      local row = registry.extract_row(resource)
      assert.equals("test-deploy", row.name)
      assert.equals("2/3", row.ready)
      assert.equals(2, row.up_to_date)
      assert.equals(2, row.available)
    end)

    it("returns default row for unknown kind", function()
      local resource = {
        kind = "UnknownKind",
        name = "test",
        namespace = "default",
        status = "Active",
        age = "1h",
      }
      local row = registry.extract_row(resource)
      assert.equals("test", row.name)
      assert.equals("default", row.namespace)
      assert.equals("Active", row.status)
      assert.equals("1h", row.age)
    end)
  end)
end)
