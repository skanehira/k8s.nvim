local resource = require("k8s.domain.resources.resource")

describe("resource", function()
  describe("new", function()
    it("should create a resource with required fields", function()
      local r = resource.new({
        kind = "Pod",
        name = "nginx-abc123",
        namespace = "default",
        status = "Running",
        age = "5m",
        raw = { metadata = { name = "nginx-abc123" } },
      })

      assert.equals("Pod", r.kind)
      assert.equals("nginx-abc123", r.name)
      assert.equals("default", r.namespace)
      assert.equals("Running", r.status)
      assert.equals("5m", r.age)
      assert.is_table(r.raw)
    end)
  end)

  describe("capabilities", function()
    it("should return default capabilities (all false)", function()
      local caps = resource.capabilities("Unknown")

      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_false(caps.scale)
      assert.is_false(caps.restart)
      assert.is_false(caps.port_forward)
    end)

    it("should return Pod capabilities", function()
      local caps = resource.capabilities("Pod")

      assert.is_true(caps.exec)
      assert.is_true(caps.logs)
      assert.is_false(caps.scale)
      assert.is_false(caps.restart)
      assert.is_true(caps.port_forward)
    end)

    it("should return Deployment capabilities", function()
      local caps = resource.capabilities("Deployment")

      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_true(caps.scale)
      assert.is_true(caps.restart)
      assert.is_true(caps.port_forward)
    end)

    it("should return Service capabilities", function()
      local caps = resource.capabilities("Service")

      assert.is_false(caps.exec)
      assert.is_false(caps.logs)
      assert.is_false(caps.scale)
      assert.is_false(caps.restart)
      assert.is_true(caps.port_forward)
    end)
  end)

  describe("get_kind_list", function()
    it("should return list of supported resource kinds", function()
      local kinds = resource.get_kind_list()

      assert.is_table(kinds)
      assert.is_true(#kinds > 0)
      -- Check some expected kinds
      local has_pod = false
      local has_deployment = false
      for _, k in ipairs(kinds) do
        if k == "Pod" then
          has_pod = true
        end
        if k == "Deployment" then
          has_deployment = true
        end
      end
      assert.is_true(has_pod)
      assert.is_true(has_deployment)
    end)
  end)

  describe("get_api_name", function()
    it("should return API name for a kind", function()
      assert.equals("pods", resource.get_api_name("Pod"))
      assert.equals("deployments", resource.get_api_name("Deployment"))
      assert.equals("services", resource.get_api_name("Service"))
      assert.equals("configmaps", resource.get_api_name("ConfigMap"))
      assert.equals("secrets", resource.get_api_name("Secret"))
      assert.equals("nodes", resource.get_api_name("Node"))
      assert.equals("namespaces", resource.get_api_name("Namespace"))
    end)
  end)
end)
