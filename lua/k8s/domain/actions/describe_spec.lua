local describe_action = require("k8s.domain.actions.describe")

describe("describe", function()
  before_each(function()
    describe_action._reset()
  end)

  describe("setup", function()
    it("should store adapter for later use", function()
      local mock_adapter = {
        describe = function() end,
      }
      describe_action.setup(mock_adapter)
      -- If setup works, fetch should not error
      assert.has_no.errors(function()
        describe_action.fetch("Pod", "nginx", "default", function() end)
      end)
    end)
  end)

  describe("fetch", function()
    it("should error if setup not called", function()
      assert.has_error(function()
        describe_action.fetch("Pod", "nginx", "default", function() end)
      end, "describe.setup() must be called before fetch()")
    end)

    it("should call adapter.describe with correct arguments", function()
      local called_with = {}
      local mock_adapter = {
        describe = function(kind, name, namespace, callback)
          called_with = { kind = kind, name = name, namespace = namespace }
          callback({ ok = true, data = "describe output", error = nil })
        end,
      }
      describe_action.setup(mock_adapter)

      local done = false
      describe_action.fetch("Pod", "nginx-abc", "default", function()
        done = true
      end)

      assert.equals("Pod", called_with.kind)
      assert.equals("nginx-abc", called_with.name)
      assert.equals("default", called_with.namespace)
      assert.is_true(done)
    end)

    it("should pass through adapter result on success", function()
      local describe_output = [[
Name:         nginx-abc
Namespace:    default
Priority:     0
Node:         minikube
]]
      local mock_adapter = {
        describe = function(_, _, _, callback)
          callback({ ok = true, data = describe_output, error = nil })
        end,
      }
      describe_action.setup(mock_adapter)

      local result
      describe_action.fetch("Pod", "nginx-abc", "default", function(r)
        result = r
      end)

      assert(result)
      assert.is_true(result.ok)
      assert.equals(describe_output, result.data)
    end)

    it("should pass through adapter result on error", function()
      local mock_adapter = {
        describe = function(_, _, _, callback)
          callback({ ok = false, data = nil, error = "resource not found" })
        end,
      }
      describe_action.setup(mock_adapter)

      local result
      describe_action.fetch("Pod", "nginx-abc", "default", function(r)
        result = r
      end)

      assert(result)
      assert.is_false(result.ok)
      assert.equals("resource not found", result.error)
    end)

    it("should handle nil namespace for all namespaces", function()
      local called_with = {}
      local mock_adapter = {
        describe = function(kind, name, namespace, callback)
          called_with = { kind = kind, name = name, namespace = namespace }
          callback({ ok = true, data = "", error = nil })
        end,
      }
      describe_action.setup(mock_adapter)

      describe_action.fetch("Pod", "nginx-abc", nil, function() end)

      assert.equals("Pod", called_with.kind)
      assert.equals("nginx-abc", called_with.name)
      assert.is_nil(called_with.namespace)
    end)
  end)
end)
