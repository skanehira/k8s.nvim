--- lifecycle_spec.lua - View lifecycle management tests

local lifecycle = require("k8s.handlers.lifecycle")

describe("lifecycle", function()
  describe("call_on_unmounted", function()
    it("should call on_unmounted callback", function()
      local called = false
      local view = {
        on_unmounted = function()
          called = true
        end,
      }

      lifecycle.call_on_unmounted(view)

      assert.is_true(called)
    end)

    it("should pass view to callback", function()
      local received_view = nil
      local view = {
        type = "pod_list",
        on_unmounted = function(v)
          received_view = v
        end,
      }

      lifecycle.call_on_unmounted(view)

      assert(received_view)
      assert.equals("pod_list", received_view.type)
    end)

    it("should handle nil view", function()
      -- Should not raise error
      lifecycle.call_on_unmounted(nil)
    end)

    it("should handle view without callback", function()
      local view = { type = "pod_list" }

      -- Should not raise error
      lifecycle.call_on_unmounted(view)
    end)
  end)

  describe("call_on_mounted", function()
    it("should call on_mounted callback", function()
      local called = false
      local view = {
        on_mounted = function()
          called = true
        end,
      }

      lifecycle.call_on_mounted(view)

      assert.is_true(called)
    end)

    it("should pass view to callback", function()
      local received_view = nil
      local view = {
        type = "pod_describe",
        on_mounted = function(v)
          received_view = v
        end,
      }

      lifecycle.call_on_mounted(view)

      assert(received_view)
      assert.equals("pod_describe", received_view.type)
    end)

    it("should handle nil view", function()
      -- Should not raise error
      lifecycle.call_on_mounted(nil)
    end)

    it("should handle view without callback", function()
      local view = { type = "pod_describe" }

      -- Should not raise error
      lifecycle.call_on_mounted(view)
    end)
  end)
end)
