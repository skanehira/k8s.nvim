--- navigation_spec.lua - Navigation menu handlers tests

local navigation = require("k8s.handlers.navigation")

describe("navigation", function()
  describe("module", function()
    it("should have show_help function", function()
      assert.is_function(navigation.show_help)
    end)

    it("should have show_resource_menu function", function()
      assert.is_function(navigation.show_resource_menu)
    end)

    it("should have show_context_menu function", function()
      assert.is_function(navigation.show_context_menu)
    end)

    it("should have show_namespace_menu function", function()
      assert.is_function(navigation.show_namespace_menu)
    end)
  end)
end)
