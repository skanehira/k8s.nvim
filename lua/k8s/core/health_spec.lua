--- health_spec.lua - ヘルスチェックのテスト

local health = require("k8s.core.health")

describe("health", function()
  describe("create_check_result", function()
    it("should create success result", function()
      local result = health.create_check_result(true, "kubectl found")

      assert.is_true(result.ok)
      assert.equals("kubectl found", result.message)
    end)

    it("should create failure result", function()
      local result = health.create_check_result(false, "kubectl not found")

      assert.is_false(result.ok)
      assert.equals("kubectl not found", result.message)
    end)
  end)

  describe("get_required_executables", function()
    it("should return list of required executables", function()
      local execs = health.get_required_executables()

      assert(#execs > 0)
      assert(vim.tbl_contains(execs, "kubectl"))
    end)
  end)

  describe("format_check_message", function()
    it("should format success message", function()
      local msg = health.format_check_message("kubectl", true)

      assert(msg:find("kubectl"))
      assert(msg:find("OK") or msg:find("found") or msg:find("✓"))
    end)

    it("should format failure message", function()
      local msg = health.format_check_message("kubectl", false)

      assert(msg:find("kubectl"))
      assert(msg:find("not found") or msg:find("missing") or msg:find("✗"))
    end)
  end)

  describe("get_health_status", function()
    it("should return healthy when all checks pass", function()
      local checks = {
        { ok = true, message = "kubectl found" },
      }

      local status = health.get_health_status(checks)

      assert.equals("healthy", status)
    end)

    it("should return unhealthy when any check fails", function()
      local checks = {
        { ok = true, message = "kubectl found" },
        { ok = false, message = "config not found" },
      }

      local status = health.get_health_status(checks)

      assert.equals("unhealthy", status)
    end)

    it("should return healthy for empty checks", function()
      local checks = {}

      local status = health.get_health_status(checks)

      assert.equals("healthy", status)
    end)
  end)

  describe("format_health_report", function()
    it("should format health report", function()
      local checks = {
        { ok = true, message = "kubectl found" },
      }

      local report = health.format_health_report(checks)

      assert(report:find("kubectl"))
    end)
  end)
end)
