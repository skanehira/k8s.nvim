--- resource_actions_spec.lua - Resource action handlers tests

local resource_actions = require("k8s.handlers.resource_actions")

describe("resource_actions", function()
  describe("module", function()
    it("should have toggle_secret function", function()
      assert.is_function(resource_actions.toggle_secret)
    end)

    it("should have stop_port_forward function", function()
      assert.is_function(resource_actions.stop_port_forward)
    end)

    it("should have start_port_forward function", function()
      assert.is_function(resource_actions.start_port_forward)
    end)

    it("should have handle_port_forward function", function()
      assert.is_function(resource_actions.handle_port_forward)
    end)

    it("should have execute function", function()
      assert.is_function(resource_actions.execute)
    end)
  end)
end)
