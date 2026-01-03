--- connections_spec.lua - ポートフォワード接続管理のテスト

local connections = require("k8s.handlers.connections")

describe("connections", function()
  before_each(function()
    connections._reset()
  end)

  describe("add", function()
    it("should add a new connection", function()
      local conn = connections.add({
        job_id = 123,
        resource = "pod/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })

      assert.equals(123, conn.job_id)
      assert.equals("pod/nginx", conn.resource)
      assert.equals("default", conn.namespace)
      assert.equals(8080, conn.local_port)
      assert.equals(80, conn.remote_port)
    end)
  end)

  describe("get", function()
    it("should return connection by job_id", function()
      connections.add({
        job_id = 123,
        resource = "pod/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })

      local conn = connections.get(123)

      assert(conn)
      assert.equals(123, conn.job_id)
    end)

    it("should return nil when connection not found", function()
      local conn = connections.get(999)

      assert.is_nil(conn)
    end)
  end)

  describe("remove", function()
    it("should remove connection by job_id", function()
      connections.add({
        job_id = 123,
        resource = "pod/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })

      local removed = connections.remove(123)

      assert.is_true(removed)
      assert.is_nil(connections.get(123))
    end)

    it("should return false when connection not found", function()
      local removed = connections.remove(999)

      assert.is_false(removed)
    end)
  end)

  describe("get_all", function()
    it("should return all connections", function()
      connections.add({
        job_id = 123,
        resource = "pod/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })
      connections.add({
        job_id = 456,
        resource = "pod/redis",
        namespace = "default",
        local_port = 6379,
        remote_port = 6379,
      })

      local all = connections.get_all()

      assert.equals(2, #all)
    end)

    it("should return empty table when no connections", function()
      local all = connections.get_all()

      assert.equals(0, #all)
    end)
  end)

  describe("count", function()
    it("should return connection count", function()
      connections.add({
        job_id = 123,
        resource = "pod/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })
      connections.add({
        job_id = 456,
        resource = "pod/redis",
        namespace = "default",
        local_port = 6379,
        remote_port = 6379,
      })

      assert.equals(2, connections.count())
    end)

    it("should return 0 when no connections", function()
      assert.equals(0, connections.count())
    end)
  end)

  describe("stop_at", function()
    it("should stop connection at index", function()
      connections.add({
        job_id = 123,
        resource = "pod/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })
      connections.add({
        job_id = 456,
        resource = "pod/redis",
        namespace = "default",
        local_port = 6379,
        remote_port = 6379,
      })

      local stopped = connections.stop_at(1)

      assert.is_true(stopped)
      assert.equals(1, connections.count())
      -- First connection was removed, now redis is at index 1
      assert.equals(456, connections.get_all()[1].job_id)
    end)

    it("should return false for invalid index", function()
      assert.is_false(connections.stop_at(0))
      assert.is_false(connections.stop_at(1))
    end)
  end)
end)
