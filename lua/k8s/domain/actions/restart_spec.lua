local restart = require("k8s.domain.actions.restart")

describe("restart", function()
  before_each(function()
    restart._reset()
  end)

  describe("setup", function()
    it("should store adapter for later use", function()
      local mock_adapter = {
        restart = function() end,
      }
      restart.setup(mock_adapter)
      assert.has_no.errors(function()
        restart.execute("Deployment", "nginx", "default", function() end)
      end)
    end)
  end)

  describe("execute", function()
    it("should error if setup not called", function()
      assert.has_error(function()
        restart.execute("Deployment", "nginx", "default", function() end)
      end, "restart.setup() must be called before execute()")
    end)

    it("should call adapter.restart with correct arguments", function()
      local called_with = {}
      local mock_adapter = {
        restart = function(kind, name, namespace, callback)
          called_with = { kind = kind, name = name, namespace = namespace }
          callback({ ok = true, data = nil, error = nil })
        end,
      }
      restart.setup(mock_adapter)

      local done = false
      restart.execute("Deployment", "nginx-deploy", "default", function()
        done = true
      end)

      assert.equals("Deployment", called_with.kind)
      assert.equals("nginx-deploy", called_with.name)
      assert.equals("default", called_with.namespace)
      assert.is_true(done)
    end)

    it("should pass through adapter result on success", function()
      local mock_adapter = {
        restart = function(_, _, _, callback)
          callback({ ok = true, data = nil, error = nil })
        end,
      }
      restart.setup(mock_adapter)

      local result
      restart.execute("Deployment", "nginx", "default", function(r)
        result = r
      end)

      assert(result)
      assert.is_true(result.ok)
    end)

    it("should pass through adapter result on error", function()
      local mock_adapter = {
        restart = function(_, _, _, callback)
          callback({ ok = false, data = nil, error = "resource not restartable" })
        end,
      }
      restart.setup(mock_adapter)

      local result
      restart.execute("Deployment", "nginx", "default", function(r)
        result = r
      end)

      assert(result)
      assert.is_false(result.ok)
      assert.equals("resource not restartable", result.error)
    end)
  end)
end)
