--- render_spec.lua - Centralized rendering manager tests

local render = require("k8s.handlers.render")

describe("render", function()
  describe("module", function()
    it("should have render function", function()
      assert.is_function(render.render)
    end)
  end)

  describe("render", function()
    it("should accept mode option", function()
      -- Should not error when called with mode option
      assert.has.no.errors(function()
        render.render({ mode = "immediate" })
      end)
    end)

    it("should accept debounced mode option", function()
      -- Should not error when called with debounced mode
      assert.has.no.errors(function()
        render.render({ mode = "debounced" })
      end)
    end)

    it("should default to immediate mode", function()
      -- Should not error when called without options
      assert.has.no.errors(function()
        render.render()
      end)
    end)
  end)
end)
