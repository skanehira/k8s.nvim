local parser = require("k8s.adapters.kubectl.parser")

describe("parser", function()
  describe("parse_resources", function()
    it("should parse pod list JSON", function()
      local json = [[
{
  "apiVersion": "v1",
  "kind": "PodList",
  "items": [
    {
      "metadata": {
        "name": "nginx-abc123",
        "namespace": "default",
        "creationTimestamp": "2024-12-30T10:00:00Z"
      },
      "status": {
        "phase": "Running",
        "containerStatuses": [
          {"ready": true},
          {"ready": true}
        ]
      }
    }
  ]
}
]]
      local result = parser.parse_resources(json)

      assert.is_true(result.ok)
      assert.equals(1, #result.data)
      assert.equals("nginx-abc123", result.data[1].name)
      assert.equals("default", result.data[1].namespace)
      assert.equals("Running", result.data[1].status)
      assert.equals("Pod", result.data[1].kind)
      assert.is_true(result.data[1].age:match("^%d+[smhd]$") ~= nil)
    end)

    it("should handle empty items", function()
      local json = [[
{
  "apiVersion": "v1",
  "kind": "PodList",
  "items": []
}
]]
      local result = parser.parse_resources(json)

      assert.is_true(result.ok)
      assert.equals(0, #result.data)
    end)

    it("should return error for invalid JSON", function()
      local json = "invalid json"
      local result = parser.parse_resources(json)

      assert.is_false(result.ok)
      assert.is.Not.Nil(result.error)
    end)

    it("should parse generic List kind with item kinds", function()
      -- Some kubectl versions return kind: "List" instead of "PodList"
      local json = [[
{
  "apiVersion": "v1",
  "kind": "List",
  "items": [
    {
      "apiVersion": "v1",
      "kind": "Pod",
      "metadata": {
        "name": "nginx-abc123",
        "namespace": "default",
        "creationTimestamp": "2024-12-30T10:00:00Z"
      },
      "status": {
        "phase": "Running"
      }
    }
  ]
}
]]
      local result = parser.parse_resources(json)

      assert.is_true(result.ok)
      assert.equals(1, #result.data)
      assert.equals("nginx-abc123", result.data[1].name)
      assert.equals("Pod", result.data[1].kind)
    end)

    it("should parse deployment list JSON", function()
      local json = [[
{
  "apiVersion": "apps/v1",
  "kind": "DeploymentList",
  "items": [
    {
      "metadata": {
        "name": "nginx-deploy",
        "namespace": "default",
        "creationTimestamp": "2024-12-30T10:00:00Z"
      },
      "status": {
        "replicas": 3,
        "readyReplicas": 3,
        "availableReplicas": 3
      },
      "spec": {
        "replicas": 3
      }
    }
  ]
}
]]
      local result = parser.parse_resources(json)

      assert.is_true(result.ok)
      assert.equals(1, #result.data)
      assert.equals("nginx-deploy", result.data[1].name)
      assert.equals("Deployment", result.data[1].kind)
    end)
  end)

  describe("parse_contexts", function()
    it("should parse context list", function()
      local output = "minikube\ndocker-desktop\nproduction"
      local result = parser.parse_contexts(output)

      assert.is_true(result.ok)
      assert.equals(3, #result.data)
      assert.equals("minikube", result.data[1])
      assert.equals("docker-desktop", result.data[2])
      assert.equals("production", result.data[3])
    end)

    it("should handle empty output", function()
      local output = ""
      local result = parser.parse_contexts(output)

      assert.is_true(result.ok)
      assert.equals(0, #result.data)
    end)
  end)

  describe("parse_namespaces", function()
    it("should parse namespace list JSON", function()
      local json = [[
{
  "apiVersion": "v1",
  "kind": "NamespaceList",
  "items": [
    {"metadata": {"name": "default"}},
    {"metadata": {"name": "kube-system"}},
    {"metadata": {"name": "monitoring"}}
  ]
}
]]
      local result = parser.parse_namespaces(json)

      assert.is_true(result.ok)
      assert.equals(3, #result.data)
      assert.equals("default", result.data[1])
      assert.equals("kube-system", result.data[2])
      assert.equals("monitoring", result.data[3])
    end)
  end)
end)
