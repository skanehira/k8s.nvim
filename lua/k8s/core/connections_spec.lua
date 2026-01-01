local connections = require("k8s.core.connections")

describe("connections", function()
  before_each(function()
    connections.clear()
  end)

  describe("initial state", function()
    it("should have no connections", function()
      assert.same({}, connections.get_all())
      assert.equals(0, connections.count())
    end)
  end)

  describe("add", function()
    it("should add a new connection", function()
      local conn = connections.add({
        job_id = 123,
        resource = "service/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })

      assert.equals(123, conn.job_id)
      assert.equals("service/nginx", conn.resource)
      assert.equals("default", conn.namespace)
      assert.equals(8080, conn.local_port)
      assert.equals(80, conn.remote_port)
      assert.equals(1, connections.count())
    end)

    it("should add multiple connections", function()
      connections.add({
        job_id = 1,
        resource = "service/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })
      connections.add({
        job_id = 2,
        resource = "pod/redis",
        namespace = "cache",
        local_port = 6379,
        remote_port = 6379,
      })

      assert.equals(2, connections.count())
    end)
  end)

  describe("remove", function()
    it("should remove a connection by job_id", function()
      connections.add({
        job_id = 123,
        resource = "service/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })

      local removed = connections.remove(123)
      assert.is_true(removed)
      assert.equals(0, connections.count())
    end)

    it("should return false when job_id not found", function()
      local removed = connections.remove(999)
      assert.is_false(removed)
    end)
  end)

  describe("get", function()
    it("should get a connection by job_id", function()
      connections.add({
        job_id = 123,
        resource = "service/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })

      local conn = connections.get(123)
      assert(conn)
      assert.equals(123, conn.job_id)
      assert.equals("service/nginx", conn.resource)
    end)

    it("should return nil when job_id not found", function()
      local conn = connections.get(999)
      assert.is_nil(conn)
    end)
  end)

  describe("get_all", function()
    it("should return all connections", function()
      connections.add({
        job_id = 1,
        resource = "service/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })
      connections.add({
        job_id = 2,
        resource = "pod/redis",
        namespace = "cache",
        local_port = 6379,
        remote_port = 6379,
      })

      local all = connections.get_all()
      assert.equals(2, #all)
    end)
  end)

  describe("clear", function()
    it("should remove all connections", function()
      connections.add({
        job_id = 1,
        resource = "service/nginx",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      })
      connections.add({
        job_id = 2,
        resource = "pod/redis",
        namespace = "cache",
        local_port = 6379,
        remote_port = 6379,
      })

      connections.clear()
      assert.equals(0, connections.count())
      assert.same({}, connections.get_all())
    end)
  end)

end)
