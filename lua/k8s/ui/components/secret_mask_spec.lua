--- secret_mask_spec.lua - Secretマスクコンポーネントのテスト

local secret_mask = require("k8s.ui.components.secret_mask")

describe("secret_mask", function()
  describe("inject_secret_values", function()
    it("should inject actual values into Data section", function()
      local lines = {
        "Name:         my-secret",
        "Namespace:    default",
        "Data",
        "====",
        "username:  5 bytes",
        "password:  10 bytes",
        "Events:  <none>",
      }
      local secret_data = {
        username = "admin",
        password = "secret123",
      }

      local result = secret_mask.inject_secret_values(lines, secret_data)

      assert.equals("Name:         my-secret", result[1])
      assert.equals("Data", result[3])
      assert.equals("username:  admin", result[5])
      assert.equals("password:  secret123", result[6])
      assert.equals("Events:  <none>", result[7])
    end)

    it("should handle keys with underscores and hyphens preserving alignment", function()
      local lines = {
        "Data",
        "====",
        "github_app_id:               7 bytes",
        "github-app-key:              20 bytes",
      }
      local secret_data = {
        github_app_id = "1234567",
        ["github-app-key"] = "abcdefghij1234567890",
      }

      local result = secret_mask.inject_secret_values(lines, secret_data)

      -- Preserves original spacing after colon
      assert.equals("github_app_id:               1234567", result[3])
      assert.equals("github-app-key:              abcdefghij1234567890", result[4])
    end)

    it("should return original lines when secret_data is nil", function()
      local lines = {
        "Data",
        "username:  5 bytes",
      }

      local result = secret_mask.inject_secret_values(lines, {})

      assert.same(lines, result)
    end)

    it("should return original lines when secret_data is empty", function()
      local lines = {
        "Data",
        "username:  5 bytes",
      }

      local result = secret_mask.inject_secret_values(lines, {})

      assert.same(lines, result)
    end)

    it("should handle multiline values with YAML block style preserving alignment", function()
      local lines = {
        "Data",
        "====",
        "private_key:  100 bytes",
      }
      local secret_data = {
        private_key = "line1\nline2\nline3",
      }

      local result = secret_mask.inject_secret_values(lines, secret_data)

      -- prefix is "private_key:  " (14 chars)
      assert.equals("private_key:  |", result[3])
      assert.equals("              line1", result[4])
      assert.equals("              line2", result[5])
      assert.equals("              line3", result[6])
    end)

    it("should preserve order of keys from describe output", function()
      local lines = {
        "Data",
        "====",
        "key_z:  1 bytes",
        "key_a:  1 bytes",
        "key_m:  1 bytes",
      }
      local secret_data = {
        key_z = "Z",
        key_a = "A",
        key_m = "M",
      }

      local result = secret_mask.inject_secret_values(lines, secret_data)

      assert.equals("key_z:  Z", result[3])
      assert.equals("key_a:  A", result[4])
      assert.equals("key_m:  M", result[5])
    end)
  end)
end)
