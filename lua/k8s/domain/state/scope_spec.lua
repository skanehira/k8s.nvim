local scope = require("k8s.domain.state.scope")

describe("scope", function()
  before_each(function()
    scope.reset()
  end)

  describe("initial state", function()
    it("should have default values", function()
      assert.equals("", scope.get_context())
      assert.equals("default", scope.get_namespace())
      assert.equals("Pod", scope.get_resource_type())
      assert.equals("", scope.get_filter())
      assert.same({}, scope.get_resources())
    end)
  end)

  describe("context", function()
    it("should set and get context", function()
      scope.set_context("minikube")
      assert.equals("minikube", scope.get_context())
    end)

    it("should clear cache when context changes", function()
      scope.set_resources({ { name = "pod1" } })
      assert.equals(1, #scope.get_resources())

      scope.set_context("production")
      assert.same({}, scope.get_resources())
    end)
  end)

  describe("namespace", function()
    it("should set and get namespace", function()
      scope.set_namespace("kube-system")
      assert.equals("kube-system", scope.get_namespace())
    end)

    it("should clear cache when namespace changes", function()
      scope.set_resources({ { name = "pod1" } })
      assert.equals(1, #scope.get_resources())

      scope.set_namespace("monitoring")
      assert.same({}, scope.get_resources())
    end)

    it("should handle nil as all namespaces", function()
      scope.set_namespace(nil)
      assert.is_nil(scope.get_namespace())
    end)
  end)

  describe("resource_type", function()
    it("should set and get resource type", function()
      scope.set_resource_type("Deployment")
      assert.equals("Deployment", scope.get_resource_type())
    end)

    it("should clear cache when resource type changes", function()
      scope.set_resources({ { name = "pod1" } })
      assert.equals(1, #scope.get_resources())

      scope.set_resource_type("Service")
      assert.same({}, scope.get_resources())
    end)
  end)

  describe("filter", function()
    it("should set and get filter", function()
      scope.set_filter("nginx")
      assert.equals("nginx", scope.get_filter())
    end)

    it("should NOT clear cache when filter changes", function()
      scope.set_resources({ { name = "pod1" } })
      assert.equals(1, #scope.get_resources())

      scope.set_filter("pod")
      assert.equals(1, #scope.get_resources())
    end)
  end)

  describe("resources", function()
    it("should set and get resources", function()
      local resources = {
        { name = "nginx", namespace = "default" },
        { name = "redis", namespace = "default" },
      }
      scope.set_resources(resources)

      local result = scope.get_resources()
      assert.equals(2, #result)
      assert.equals("nginx", result[1].name)
    end)
  end)

  describe("reset", function()
    it("should reset all state to defaults", function()
      scope.set_context("minikube")
      scope.set_namespace("kube-system")
      scope.set_resource_type("Deployment")
      scope.set_filter("nginx")
      scope.set_resources({ { name = "pod1" } })

      scope.reset()

      assert.equals("", scope.get_context())
      assert.equals("default", scope.get_namespace())
      assert.equals("Pod", scope.get_resource_type())
      assert.equals("", scope.get_filter())
      assert.same({}, scope.get_resources())
    end)
  end)
end)
