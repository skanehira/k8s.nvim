local scale = require("k8s.domain.actions.scale")

describe("scale", function()
  before_each(function()
    scale._reset()
  end)

  describe("setup", function()
    it("should store adapter for later use", function()
      local mock_adapter = {
        scale = function() end,
      }
      scale.setup(mock_adapter)
      assert.has_no.errors(function()
        scale.execute("Deployment", "nginx", "default", 3, function() end)
      end)
    end)
  end)

  describe("execute", function()
    it("should error if setup not called", function()
      assert.has_error(function()
        scale.execute("Deployment", "nginx", "default", 3, function() end)
      end, "scale.setup() must be called before execute()")
    end)

    it("should call adapter.scale with correct arguments", function()
      local called_with = {}
      local mock_adapter = {
        scale = function(kind, name, namespace, replicas, callback)
          called_with = { kind = kind, name = name, namespace = namespace, replicas = replicas }
          callback({ ok = true, data = nil, error = nil })
        end,
      }
      scale.setup(mock_adapter)

      local done = false
      scale.execute("Deployment", "nginx-deploy", "default", 5, function()
        done = true
      end)

      assert.equals("Deployment", called_with.kind)
      assert.equals("nginx-deploy", called_with.name)
      assert.equals("default", called_with.namespace)
      assert.equals(5, called_with.replicas)
      assert.is_true(done)
    end)

    it("should pass through adapter result on success", function()
      local mock_adapter = {
        scale = function(_, _, _, _, callback)
          callback({ ok = true, data = nil, error = nil })
        end,
      }
      scale.setup(mock_adapter)

      local result
      scale.execute("Deployment", "nginx", "default", 3, function(r)
        result = r
      end)

      assert(result)
      assert.is_true(result.ok)
    end)

    it("should pass through adapter result on error", function()
      local mock_adapter = {
        scale = function(_, _, _, _, callback)
          callback({ ok = false, data = nil, error = "resource not scalable" })
        end,
      }
      scale.setup(mock_adapter)

      local result
      scale.execute("Deployment", "nginx", "default", 3, function(r)
        result = r
      end)

      assert(result)
      assert.is_false(result.ok)
      assert.equals("resource not scalable", result.error)
    end)

    it("should handle zero replicas", function()
      local called_with = {}
      local mock_adapter = {
        scale = function(_kind, _name, _namespace, replicas, callback)
          called_with = { replicas = replicas }
          callback({ ok = true, data = nil, error = nil })
        end,
      }
      scale.setup(mock_adapter)

      scale.execute("Deployment", "nginx", "default", 0, function() end)

      assert.equals(0, called_with.replicas)
    end)
  end)
end)
