--- health_spec.lua - ヘルスチェックのテスト

local health = require("k8s.core.health")

describe("health", function()
  describe("check_kubectl", function()
    it("should return boolean", function()
      local result = health.check_kubectl()

      assert.is_boolean(result)
    end)
  end)
end)
