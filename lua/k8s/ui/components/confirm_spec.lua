local confirm = require("k8s.ui.components.confirm")

describe("confirm", function()
  describe("format_message", function()
    it("should format delete confirmation message", function()
      local msg = confirm.format_message("delete", "pod", "nginx-abc123")
      assert.equals("Delete pod/nginx-abc123?", msg)
    end)

    it("should format restart confirmation message", function()
      local msg = confirm.format_message("restart", "deployment", "my-app")
      assert.equals("Restart deployment/my-app?", msg)
    end)
  end)

  describe("parse_response", function()
    it("should return true for yes response (1)", function()
      assert.is_true(confirm.parse_response(1))
    end)

    it("should return false for no response (2)", function()
      assert.is_false(confirm.parse_response(2))
    end)

    it("should return false for cancel response (0)", function()
      assert.is_false(confirm.parse_response(0))
    end)
  end)
end)
