--- notify_spec.lua - 通知ユーティリティのテスト

local notify = require("k8s.handlers.notify")

describe("notify", function()
  local original_notify
  local captured_msg
  local captured_level

  before_each(function()
    original_notify = vim.notify
    captured_msg = nil
    captured_level = nil
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg, level)
      captured_msg = msg
      captured_level = level
    end
  end)

  after_each(function()
    vim.notify = original_notify
  end)

  describe("info", function()
    it("should call vim.notify with INFO level", function()
      notify.info("Test message")

      assert.equals("Test message", captured_msg)
      assert.equals(vim.log.levels.INFO, captured_level)
    end)
  end)

  describe("warn", function()
    it("should call vim.notify with WARN level", function()
      notify.warn("Warning message")

      assert.equals("Warning message", captured_msg)
      assert.equals(vim.log.levels.WARN, captured_level)
    end)
  end)

  describe("error", function()
    it("should call vim.notify with ERROR level", function()
      notify.error("Error message")

      assert.equals("Error message", captured_msg)
      assert.equals(vim.log.levels.ERROR, captured_level)
    end)
  end)

  describe("action_result", function()
    it("should show info for successful scale action", function()
      notify.action_result("scale", "Deployment", "nginx", true)

      assert.equals("Deployment 'nginx' scaled successfully", captured_msg)
      assert.equals(vim.log.levels.INFO, captured_level)
    end)

    it("should show warn for successful delete action", function()
      notify.action_result("delete", "Pod", "nginx", true)

      assert.equals("Pod 'nginx' deleted successfully", captured_msg)
      assert.equals(vim.log.levels.WARN, captured_level)
    end)

    it("should show warn for successful restart action", function()
      notify.action_result("restart", "Deployment", "nginx", true)

      assert.equals("Deployment 'nginx' restarted successfully", captured_msg)
      assert.equals(vim.log.levels.WARN, captured_level)
    end)

    it("should show error for failed action", function()
      notify.action_result("delete", "Pod", "nginx", false, "not found")

      assert.equals("Failed to delete Pod 'nginx': not found", captured_msg)
      assert.equals(vim.log.levels.ERROR, captured_level)
    end)
  end)
end)
