--- resource_spec.lua - リソース機能のテスト

local resource = require("k8s.handlers.resource")

describe("resource", function()
  describe("capabilities", function()
    it("should return Pod capabilities", function()
      local caps = resource.capabilities("Pod")

      assert.is_true(caps.exec)
      assert.is_true(caps.logs)
      assert.is_false(caps.scale)
      assert.is_false(caps.restart)
      assert.is_true(caps.port_forward)
      assert.is_true(caps.delete)
    end)

    it("should return Deployment capabilities", function()
      local caps = resource.capabilities("Deployment")

      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_true(caps.scale)
      assert.is_true(caps.restart)
      assert.is_true(caps.port_forward)
      assert.is_true(caps.delete)
    end)

    it("should return Service capabilities", function()
      local caps = resource.capabilities("Service")

      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_false(caps.scale)
      assert.is_false(caps.restart)
      assert.is_true(caps.port_forward)
      assert.is_true(caps.delete)
    end)

    it("should return ConfigMap capabilities", function()
      local caps = resource.capabilities("ConfigMap")

      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_false(caps.scale)
      assert.is_false(caps.restart)
      assert.is_false(caps.port_forward)
      assert.is_true(caps.delete)
    end)

    it("should return Node capabilities", function()
      local caps = resource.capabilities("Node")

      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_false(caps.scale)
      assert.is_false(caps.restart)
      assert.is_false(caps.port_forward)
      assert.is_false(caps.delete)
    end)

    it("should return default capabilities for unknown kind", function()
      ---@diagnostic disable-next-line: param-type-mismatch
      local caps = resource.capabilities("Unknown")

      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_false(caps.scale)
      assert.is_false(caps.restart)
      assert.is_false(caps.port_forward)
      assert.is_false(caps.delete)
    end)
  end)

  describe("can_perform", function()
    it("should return true when Pod can perform logs", function()
      assert.is_true(resource.can_perform("Pod", "logs"))
    end)

    it("should return false when Pod cannot scale", function()
      assert.is_false(resource.can_perform("Pod", "scale"))
    end)

    it("should return true when Deployment can scale", function()
      assert.is_true(resource.can_perform("Deployment", "scale"))
    end)

    it("should return false for unknown action", function()
      assert.is_false(resource.can_perform("Pod", "unknown_action"))
    end)
  end)
end)
