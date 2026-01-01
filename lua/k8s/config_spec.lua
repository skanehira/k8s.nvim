--- config_spec.lua - 設定のテスト

local config = require("k8s.config")

describe("config", function()
  describe("get_defaults", function()
    it("should return default config", function()
      local defaults = config.get_defaults()

      assert.is_table(defaults)
      assert.is_number(defaults.refresh_interval)
      assert.is_number(defaults.timeout)
      assert.is_table(defaults.keymaps)
    end)

    it("should have reasonable refresh interval", function()
      local defaults = config.get_defaults()

      assert(defaults.refresh_interval >= 1000) -- at least 1 second
      assert(defaults.refresh_interval <= 60000) -- at most 1 minute
    end)
  end)

  describe("merge", function()
    it("should merge user config with defaults", function()
      local user_config = {
        refresh_interval = 10000,
      }

      local merged = config.merge(user_config)

      assert.equals(10000, merged.refresh_interval)
      assert.is_number(merged.timeout) -- from defaults
    end)

    it("should deep merge keymaps", function()
      local user_config = {
        keymaps = {
          describe = "D",
        },
      }

      local merged = config.merge(user_config)

      assert.equals("D", merged.keymaps.describe)
      -- Other keymaps should still exist from defaults
      assert.is_string(merged.keymaps.quit)
    end)

    it("should return defaults when user config is nil", function()
      local merged = config.merge(nil)

      assert.same(config.get_defaults(), merged)
    end)
  end)

  describe("validate", function()
    it("should return true for valid config", function()
      local cfg = config.get_defaults()

      local valid, err = config.validate(cfg)

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should return false for invalid refresh_interval", function()
      local cfg = config.get_defaults()
      cfg.refresh_interval = -1000

      local valid, err = config.validate(cfg)

      assert.is_false(valid)
      assert(err:find("refresh_interval"))
    end)

    it("should return false for invalid timeout", function()
      local cfg = config.get_defaults()
      cfg.timeout = 0

      local valid, err = config.validate(cfg)

      assert.is_false(valid)
      assert(err:find("timeout"))
    end)
  end)
end)
