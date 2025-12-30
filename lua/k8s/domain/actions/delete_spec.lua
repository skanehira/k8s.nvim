local delete = require("k8s.domain.actions.delete")

describe("delete", function()
  before_each(function()
    delete._reset()
  end)

  describe("setup", function()
    it("should store adapter for later use", function()
      local mock_adapter = {
        delete = function() end,
      }
      delete.setup(mock_adapter)
      assert.has_no.errors(function()
        delete.execute("Pod", "nginx", "default", function() end)
      end)
    end)
  end)

  describe("execute", function()
    it("should error if setup not called", function()
      assert.has_error(function()
        delete.execute("Pod", "nginx", "default", function() end)
      end, "delete.setup() must be called before execute()")
    end)

    it("should call adapter.delete with correct arguments", function()
      local called_with = {}
      local mock_adapter = {
        delete = function(kind, name, namespace, callback)
          called_with = { kind = kind, name = name, namespace = namespace }
          callback({ ok = true, data = nil, error = nil })
        end,
      }
      delete.setup(mock_adapter)

      local done = false
      delete.execute("Pod", "nginx-abc", "default", function()
        done = true
      end)

      assert.equals("Pod", called_with.kind)
      assert.equals("nginx-abc", called_with.name)
      assert.equals("default", called_with.namespace)
      assert.is_true(done)
    end)

    it("should pass through adapter result on success", function()
      local mock_adapter = {
        delete = function(_, _, _, callback)
          callback({ ok = true, data = nil, error = nil })
        end,
      }
      delete.setup(mock_adapter)

      local result
      delete.execute("Pod", "nginx-abc", "default", function(r)
        result = r
      end)

      assert(result)
      assert.is_true(result.ok)
    end)

    it("should pass through adapter result on error", function()
      local mock_adapter = {
        delete = function(_, _, _, callback)
          callback({ ok = false, data = nil, error = "forbidden" })
        end,
      }
      delete.setup(mock_adapter)

      local result
      delete.execute("Pod", "nginx-abc", "default", function(r)
        result = r
      end)

      assert(result)
      assert.is_false(result.ok)
      assert.equals("forbidden", result.error)
    end)
  end)
end)
