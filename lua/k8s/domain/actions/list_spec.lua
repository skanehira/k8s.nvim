local list = require("k8s.domain.actions.list")

describe("list", function()
  before_each(function()
    list._reset()
  end)

  describe("setup", function()
    it("should store adapter for later use", function()
      local mock_adapter = {
        get_resources = function() end,
      }
      list.setup(mock_adapter)
      -- If setup works, fetch should not error
      assert.has_no.errors(function()
        list.fetch("Pod", "default", function() end)
      end)
    end)
  end)

  describe("fetch", function()
    it("should error if setup not called", function()
      assert.has_error(function()
        list.fetch("Pod", "default", function() end)
      end, "list.setup() must be called before fetch()")
    end)

    it("should call adapter.get_resources with correct arguments", function()
      local called_with = {}
      local mock_adapter = {
        get_resources = function(kind, namespace, callback)
          called_with = { kind = kind, namespace = namespace }
          callback({ ok = true, data = {}, error = nil })
        end,
      }
      list.setup(mock_adapter)

      local done = false
      list.fetch("Pod", "default", function()
        done = true
      end)

      assert.equals("Pod", called_with.kind)
      assert.equals("default", called_with.namespace)
      assert.is_true(done)
    end)

    it("should pass through adapter result on success", function()
      local resources = {
        { name = "nginx", namespace = "default", status = "Running" },
        { name = "redis", namespace = "default", status = "Running" },
      }
      local mock_adapter = {
        get_resources = function(_, _, callback)
          callback({ ok = true, data = resources, error = nil })
        end,
      }
      list.setup(mock_adapter)

      local result
      list.fetch("Pod", "default", function(r)
        result = r
      end)

      assert(result)
      assert.is_true(result.ok)
      assert.equals(2, #result.data)
    end)

    it("should pass through adapter result on error", function()
      local mock_adapter = {
        get_resources = function(_, _, callback)
          callback({ ok = false, data = nil, error = "connection refused" })
        end,
      }
      list.setup(mock_adapter)

      local result
      list.fetch("Pod", "default", function(r)
        result = r
      end)

      assert(result)
      assert.is_false(result.ok)
      assert.equals("connection refused", result.error)
    end)

    it("should handle nil namespace for all namespaces", function()
      local called_with = {}
      local mock_adapter = {
        get_resources = function(kind, namespace, callback)
          called_with = { kind = kind, namespace = namespace }
          callback({ ok = true, data = {}, error = nil })
        end,
      }
      list.setup(mock_adapter)

      list.fetch("Pod", nil, function() end)

      assert.equals("Pod", called_with.kind)
      assert.is_nil(called_with.namespace)
    end)
  end)

  describe("filter", function()
    it("should return all resources when filter is empty", function()
      local resources = {
        { name = "nginx", namespace = "default" },
        { name = "redis", namespace = "default" },
        { name = "mysql", namespace = "default" },
      }

      local filtered = list.filter(resources, "")
      assert.equals(3, #filtered)
    end)

    it("should filter resources by name", function()
      local resources = {
        { name = "nginx-abc", namespace = "default" },
        { name = "redis-xyz", namespace = "default" },
        { name = "nginx-def", namespace = "default" },
      }

      local filtered = list.filter(resources, "nginx")
      assert.equals(2, #filtered)
      assert.equals("nginx-abc", filtered[1].name)
      assert.equals("nginx-def", filtered[2].name)
    end)

    it("should filter resources case-insensitively", function()
      local resources = {
        { name = "Nginx-abc", namespace = "default" },
        { name = "redis-xyz", namespace = "default" },
        { name = "NGINX-def", namespace = "default" },
      }

      local filtered = list.filter(resources, "nginx")
      assert.equals(2, #filtered)
    end)

    it("should also filter by namespace", function()
      local resources = {
        { name = "nginx", namespace = "default" },
        { name = "redis", namespace = "kube-system" },
        { name = "mysql", namespace = "default" },
      }

      local filtered = list.filter(resources, "kube")
      assert.equals(1, #filtered)
      assert.equals("redis", filtered[1].name)
    end)

    it("should return empty list when no match", function()
      local resources = {
        { name = "nginx", namespace = "default" },
        { name = "redis", namespace = "default" },
      }

      local filtered = list.filter(resources, "postgres")
      assert.equals(0, #filtered)
    end)
  end)

  describe("sort", function()
    it("should sort resources by name alphabetically", function()
      local resources = {
        { name = "redis", namespace = "default" },
        { name = "nginx", namespace = "default" },
        { name = "mysql", namespace = "default" },
      }

      local sorted = list.sort(resources)
      assert.equals("mysql", sorted[1].name)
      assert.equals("nginx", sorted[2].name)
      assert.equals("redis", sorted[3].name)
    end)

    it("should handle empty list", function()
      local sorted = list.sort({})
      assert.equals(0, #sorted)
    end)

    it("should handle single item", function()
      local resources = {
        { name = "nginx", namespace = "default" },
      }

      local sorted = list.sort(resources)
      assert.equals(1, #sorted)
      assert.equals("nginx", sorted[1].name)
    end)

    it("should be case-insensitive", function()
      local resources = {
        { name = "Redis", namespace = "default" },
        { name = "nginx", namespace = "default" },
        { name = "MySQL", namespace = "default" },
      }

      local sorted = list.sort(resources)
      assert.equals("MySQL", sorted[1].name)
      assert.equals("nginx", sorted[2].name)
      assert.equals("Redis", sorted[3].name)
    end)

    it("should not modify original list", function()
      local resources = {
        { name = "redis", namespace = "default" },
        { name = "nginx", namespace = "default" },
      }

      local sorted = list.sort(resources)
      assert.equals("redis", resources[1].name)
      assert.equals("nginx", sorted[1].name)
    end)
  end)
end)
