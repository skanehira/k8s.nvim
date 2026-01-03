--- commands_spec.lua - CLI command handlers tests

local commands = require("k8s.commands")

describe("commands", function()
  describe("module", function()
    it("should have switch_context function", function()
      assert.is_function(commands.switch_context)
    end)

    it("should have switch_namespace function", function()
      assert.is_function(commands.switch_namespace)
    end)
  end)
end)
